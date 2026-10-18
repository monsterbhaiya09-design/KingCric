import 'innings.dart';

enum MatchStatus { live, upcoming, completed }

class TeamScore {
  final String team;
  final int runs;
  final int wickets;
  final double overs;
  final bool batted;

  const TeamScore({
    required this.team,
    this.runs = 0,
    this.wickets = 0,
    this.overs = 0,
    this.batted = false,
  });

  factory TeamScore.fromJson(Map<String, dynamic> j) => TeamScore(
        team: j['team'] as String? ?? '',
        runs: (j['runs'] as num?)?.toInt() ?? 0,
        wickets: (j['wickets'] as num?)?.toInt() ?? 0,
        overs: (j['overs'] as num?)?.toDouble() ?? 0,
        batted: j['batted'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'team': team,
        'runs': runs,
        'wickets': wickets,
        'overs': overs,
        'batted': batted,
      };

  String get display =>
      batted ? '$runs/$wickets (${overs.toStringAsFixed(1)} ov)' : 'Yet to bat';

  /// A score row counts as REAL data only when the side actually
  /// batted and something happened. Backstops emit a 0/0
  /// placeholder row for the side yet to bat — counting that as a
  /// "score" let a placeholder copy outrank a live copy in merges
  /// and stole its (foreign) id, so /cricketScore failed.
  bool get isMeaningful =>
      batted && (runs > 0 || wickets > 0 || overs > 0);
}

/// Pure merge / dedupe rules for match lists (Squad E). The
/// orchestrator (ApiService) owns fetching and caching; it must call
/// these helpers instead of re-implementing richness / dedupe, so
/// every merge in the app uses ONE definition of "richer" and ONE
/// definition of "same fixture".
class MatchMerge {
  static String _normTeam(String s) => s.trim().toLowerCase();

  static String _normLeague(String s) {
    final l = s.trim().toLowerCase();
    // '' (provider sent no league), 'International' and the generic
    // 'Cricket' label mean the same bucket: an empty/generic-league
    // entry folds into the same fixture reported with a league by
    // another provider. (The old ApiService bucketing treated
    // 'Cricket' as empty too; keep that rule here so there is ONE
    // definition of league compatibility.)
    if (l.isEmpty || l == 'international' || l == 'cricket') {
      return 'international';
    }
    return l;
  }

  /// Dedupe key: (teams, calendar day, format, league). Team order
  /// is sorted so a provider that lists teams swapped still merges.
  /// Day is UTC — providers report GMT dates; local timezones must
  /// never split one fixture across two days.
  static String dedupeKey(CricketMatch m) {
    final teams = [m.teamA, m.teamB].map(_normTeam).toList()..sort();
    final d = m.startTime.toUtc();
    final day =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return '${teams.join(' ~ ')}|$day|'
        '${m.format.trim().toLowerCase()}|${_normLeague(m.league)}';
  }

  /// League compatibility for merging: equal after normalisation,
  /// or either side sent no league (empty folds in). Two different
  /// non-empty leagues are DIFFERENT fixtures and must stay separate.
  static bool leaguesCompatible(CricketMatch a, CricketMatch b) {
    final la = a.league.trim();
    final lb = b.league.trim();
    if (la.isEmpty || lb.isEmpty) return true;
    return _normLeague(a.league) == _normLeague(b.league);
  }

  /// Should [a] and [b] be merged into ONE card? Same teams / day /
  /// format + compatible league, EXCEPT two distinct entries from
  /// the SAME provider with different ids — that is a real
  /// double-header / men+women / two-series pair, never merge it.
  /// Same id (or unknown source) merges as before.
  ///
  /// [providerA]/[providerB] override the per-match [CricketMatch.source]
  /// when the caller knows the supplying provider per LIST (the
  /// orchestrator passes providerNames for its per-provider lists;
  /// Home's already-merged lists pass none and fall back to the
  /// per-match source). Without the override, two entries whose
  /// source fields are both 'CricAPI' but which came from different
  /// provider lists would be treated as same-provider and never
  /// merged — the override is what makes cross-list merges work.
  static bool mergeCandidates(CricketMatch a, CricketMatch b,
      {String? providerA, String? providerB}) {
    final teamsA = [a.teamA, a.teamB].map(_normTeam).toList()..sort();
    final teamsB = [b.teamA, b.teamB].map(_normTeam).toList()..sort();
    if (teamsA.join('|') != teamsB.join('|')) return false;
    final da = a.startTime.toUtc();
    final db = b.startTime.toUtc();
    if (da.year != db.year || da.month != db.month || da.day != db.day) {
      return false;
    }
    if (a.format.trim().toLowerCase() !=
        b.format.trim().toLowerCase()) {
      return false;
    }
    if (!leaguesCompatible(a, b)) return false;
    final pa = providerA ?? a.source;
    final pb = providerB ?? b.source;
    final sameProvider = pa.isNotEmpty && pa == pb;
    final bothIds = a.id.isNotEmpty && b.id.isNotEmpty;
    if (sameProvider && bothIds && a.id != b.id) return false;
    return true;
  }

  /// Meaningful scores only — placeholder 0/0 rows never count.
  static int meaningfulScoreCount(CricketMatch m) =>
      m.scores.where((s) => s.isMeaningful).length;

  /// Richness: full scorecard dominates (innings = 100), then
  /// meaningful scores (x10 each), then status
  /// (completed +10, effectively-live +5), minus one per
  /// placeholder 0/0 row (junk rows are evidence of a less
  /// complete copy). A backstop copy with a placeholder row can
  /// never outrank a live CricAPI copy again.
  static int richness(CricketMatch m) {
    var r = meaningfulScoreCount(m) * 10;
    if (m.innings.isNotEmpty) r += 100;
    if (m.isCompleted) r += 10;
    if (m.isEffectivelyLive) r += 5;
    r -= m.scores.where((s) => s.batted && !s.isMeaningful).length;
    return r;
  }

  /// The richer of the two; ties prefer a non-demo source, then [a]
  /// (first seen). Deterministic — same inputs always pick the same
  /// copy, so merges never flip-flop between refreshes.
  static CricketMatch pickRicher(CricketMatch a, CricketMatch b) {
    final ra = richness(a);
    final rb = richness(b);
    if (ra != rb) return ra > rb ? a : b;
    final aDemo = a.source.trim().toLowerCase() == 'demo' ||
        a.source.trim().toLowerCase() == 'mock';
    final bDemo = b.source.trim().toLowerCase() == 'demo' ||
        b.source.trim().toLowerCase() == 'mock';
    if (aDemo != bDemo) return aDemo ? b : a;
    return a;
  }
}

class CricketMatch {
  final String id;
  final String teamA;
  final String teamB;
  final String format; // Test, ODI, T20, T10
  final String league; // International, IPL, PSL, Big Bash, ...
  final String venueId;
  final String venueName;
  final DateTime startTime;
  final MatchStatus status;
  final List<TeamScore> scores;
  final String result;
  final String toss;
  final List<String> squadA;
  final List<String> squadB;
  final List<Innings> innings;
  final List<String> commentary;
  final String currentBatter;
  final String currentBowler;
  final String lastBall;
  final int teamAWinsH2H;
  final int teamBWinsH2H;
  final int totalH2H;
  final DateTime? lastUpdated;
  // V2: match context for full scoreboard header.
  final String umpires;
  final String matchReferee;
  final String pitchReport;
  /// Which provider supplied this match ('CricAPI', 'SportScore',
  /// 'demo', ...). Rendered as a tiny per-card source label so demo
  /// data can never masquerade as real. '' = unknown (older cache).
  final String source;

  const CricketMatch({
    required this.id,
    required this.teamA,
    required this.teamB,
    this.format = 'T20',
    this.league = 'International',
    this.venueId = '',
    this.venueName = '',
    required this.startTime,
    this.status = MatchStatus.upcoming,
    this.scores = const [],
    this.result = '',
    this.toss = '',
    this.squadA = const [],
    this.squadB = const [],
    this.innings = const [],
    this.commentary = const [],
    this.currentBatter = '',
    this.currentBowler = '',
    this.lastBall = '',
    this.teamAWinsH2H = 0,
    this.teamBWinsH2H = 0,
    this.totalH2H = 0,
    this.lastUpdated,
    this.umpires = '',
    this.matchReferee = '',
    this.pitchReport = '',
    this.source = '',
  });

  String get title => '$teamA vs $teamB';
  bool get isLive => status == MatchStatus.live;

  /// ONE status truth (Squad E): a match is completed when its
  /// [status] says so OR its [result] carries a terminal RESULT
  /// phrase. The phrase list mirrors
  /// ProviderParsing.resolveStatus — the two must never drift
  /// apart, or the same match is "completed" in one place and
  /// "upcoming" in another. "Won the toss" is NEVER terminal:
  /// "X won the toss and elected to bat" describes a match that
  /// has just started.
  bool get isCompleted =>
      status == MatchStatus.completed || isTerminalResult(result);

  /// Terminal RESULT phrases. Keep in sync with
  /// ProviderParsing.resolveStatus.
  static const List<String> terminalResultPhrases = [
    'won by',
    'won the match',
    'result',
    'finished',
    'completed',
    'match ended',
    'match drawn',
    'drawn',
    'no result',
    'abandoned',
  ];

  /// True when [result] carries a terminal result phrase.
  /// Never true for toss text ("won the toss ...").
  static bool isTerminalResult(String result) {
    final lower = result.toLowerCase();
    return terminalResultPhrases.any(lower.contains);
  }

  /// Defense-in-depth for the Live tab (V3 bug): if a provider ever
  /// mislabels an in-progress match as upcoming, the scores on the
  /// board still prove it is live — unless the result says someone
  /// won. The Home filter uses this, not the raw [status], so a
  /// live match can never again hide under Upcoming.
  bool get isEffectivelyLive {
    // A terminal result beats even a stale status == live.
    if (isTerminalResult(result)) return false;
    if (status == MatchStatus.live) return true;
    if (status != MatchStatus.upcoming) return false;
    return scores.any((s) => s.isMeaningful);
  }

  TeamScore? scoreOf(String team) {
    for (final s in scores) {
      if (s.team == team) return s;
    }
    return null;
  }

  factory CricketMatch.fromJson(Map<String, dynamic> j) {
    MatchStatus st = MatchStatus.upcoming;
    switch (j['status'] as String?) {
      case 'live':
        st = MatchStatus.live;
        break;
      case 'completed':
        st = MatchStatus.completed;
        break;
      default:
        st = MatchStatus.upcoming;
    }
    return CricketMatch(
      id: j['id'] as String? ?? '',
      teamA: j['teamA'] as String? ?? '',
      teamB: j['teamB'] as String? ?? '',
      format: j['format'] as String? ?? 'T20',
      league: j['league'] as String? ?? 'International',
      venueId: j['venueId'] as String? ?? '',
      venueName: j['venueName'] as String? ?? '',
      startTime: j['startTime'] == null
          ? DateTime.now()
          : DateTime.tryParse(j['startTime'] as String) ?? DateTime.now(),
      status: st,
      scores: ((j['scores'] as List?) ?? [])
          .map((e) => TeamScore.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      result: j['result'] as String? ?? '',
      toss: j['toss'] as String? ?? '',
      squadA: ((j['squadA'] as List?) ?? []).map((e) => '$e').toList(),
      squadB: ((j['squadB'] as List?) ?? []).map((e) => '$e').toList(),
      innings: ((j['innings'] as List?) ?? [])
          .map((e) => Innings.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      commentary:
          ((j['commentary'] as List?) ?? []).map((e) => '$e').toList(),
      currentBatter: j['currentBatter'] as String? ?? '',
      currentBowler: j['currentBowler'] as String? ?? '',
      lastBall: j['lastBall'] as String? ?? '',
      teamAWinsH2H: (j['teamAWinsH2H'] as num?)?.toInt() ?? 0,
      teamBWinsH2H: (j['teamBWinsH2H'] as num?)?.toInt() ?? 0,
      totalH2H: (j['totalH2H'] as num?)?.toInt() ?? 0,
      umpires: j['umpires'] as String? ?? '',
      matchReferee: j['matchReferee'] as String? ?? '',
      pitchReport: j['pitchReport'] as String? ?? '',
      source: j['source'] as String? ?? '',
      lastUpdated: j['lastUpdated'] == null
          ? null
          : DateTime.tryParse(j['lastUpdated'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'teamA': teamA,
        'teamB': teamB,
        'format': format,
        'league': league,
        'venueId': venueId,
        'venueName': venueName,
        'startTime': startTime.toIso8601String(),
        'status': status.name,
        'scores': scores.map((e) => e.toJson()).toList(),
        'result': result,
        'toss': toss,
        'squadA': squadA,
        'squadB': squadB,
        'innings': innings.map((e) => e.toJson()).toList(),
        'commentary': commentary,
        'currentBatter': currentBatter,
        'currentBowler': currentBowler,
        'lastBall': lastBall,
        'teamAWinsH2H': teamAWinsH2H,
        'teamBWinsH2H': teamBWinsH2H,
        'totalH2H': totalH2H,
        'umpires': umpires,
        'matchReferee': matchReferee,
        'pitchReport': pitchReport,
        'source': source,
        'lastUpdated': lastUpdated?.toIso8601String(),
      };
}
