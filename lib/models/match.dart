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
  bool get isCompleted => status == MatchStatus.completed;

  /// Defense-in-depth for the Live tab (V3 bug): if a provider ever
  /// mislabels an in-progress match as upcoming, the scores on the
  /// board still prove it is live — unless the result says someone
  /// won. The Home filter uses this, not the raw [status], so a
  /// live match can never again hide under Upcoming.
  bool get isEffectivelyLive {
    if (status == MatchStatus.live) return true;
    if (status != MatchStatus.upcoming) return false;
    final won = result.toLowerCase().contains('won by') ||
        result.toLowerCase().contains('won the');
    if (won) return false;
    return scores.any((s) => s.batted && (s.runs > 0 || s.wickets > 0));
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
