/// Full player model: batting + bowling, format-wise, vs opponent,
/// venue records, recent form, dismissal history. Every numeric field
/// defaults to 0 so incomplete upstream data can never crash the UI —
/// the validator (see completeness_validator.dart) decides whether a
/// profile is complete enough to show at all.
class BattingStats {
  final int matches;
  final int innings;
  final int runs;
  final int balls;
  final int fifties;
  final int hundreds;
  final int fours;
  final int sixes;
  final double average;
  final double strikeRate;
  final int highest;

  const BattingStats({
    this.matches = 0,
    this.innings = 0,
    this.runs = 0,
    this.balls = 0,
    this.fifties = 0,
    this.hundreds = 0,
    this.fours = 0,
    this.sixes = 0,
    this.average = 0,
    this.strikeRate = 0,
    this.highest = 0,
  });

  factory BattingStats.fromJson(Map<String, dynamic> j) => BattingStats(
        matches: (j['matches'] as num?)?.toInt() ?? 0,
        innings: (j['innings'] as num?)?.toInt() ?? 0,
        runs: (j['runs'] as num?)?.toInt() ?? 0,
        balls: (j['balls'] as num?)?.toInt() ?? 0,
        fifties: (j['fifties'] as num?)?.toInt() ?? 0,
        hundreds: (j['hundreds'] as num?)?.toInt() ?? 0,
        fours: (j['fours'] as num?)?.toInt() ?? 0,
        sixes: (j['sixes'] as num?)?.toInt() ?? 0,
        average: (j['average'] as num?)?.toDouble() ?? 0,
        strikeRate: (j['strikeRate'] as num?)?.toDouble() ?? 0,
        highest: (j['highest'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'matches': matches,
        'innings': innings,
        'runs': runs,
        'balls': balls,
        'fifties': fifties,
        'hundreds': hundreds,
        'fours': fours,
        'sixes': sixes,
        'average': average,
        'strikeRate': strikeRate,
        'highest': highest,
      };

  /// Merge two stat blocks (e.g. T20 + ODI combined view).
  ///
  /// Cricket average = runs / dismissals, NOT runs / innings. The
  /// block does not store dismissals, so they are recovered from
  /// each block as runs / average (average > 0). Never-dismissed
  /// blocks (average == runs, or 0 runs) contribute 0 dismissals.
  BattingStats operator +(BattingStats o) {
    final b = balls + o.balls;
    final inn = innings + o.innings;
    final totalRuns = runs + o.runs;
    double dismissalsFor(BattingStats s) {
      if (s.runs <= 0) return 0;
      if (s.average <= 0) return 0;
      return s.runs / s.average;
    }

    final dismissals = dismissalsFor(this) + dismissalsFor(o);
    final mergedAverage =
        dismissals <= 0 ? totalRuns.toDouble() : totalRuns / dismissals;
    return BattingStats(
      matches: matches + o.matches,
      innings: inn,
      runs: totalRuns,
      balls: b,
      fifties: fifties + o.fifties,
      hundreds: hundreds + o.hundreds,
      fours: fours + o.fours,
      sixes: sixes + o.sixes,
      average: mergedAverage,
      strikeRate: b == 0 ? 0 : totalRuns * 100 / b,
      highest: highest > o.highest ? highest : o.highest,
    );
  }
}

class BowlingStats {
  final int matches;
  final int innings;
  final int wickets;
  final int balls;
  final int runsConceded;
  final double economy;
  final double average;
  final double strikeRate;
  final int fiveWickets;
  final String best;

  const BowlingStats({
    this.matches = 0,
    this.innings = 0,
    this.wickets = 0,
    this.balls = 0,
    this.runsConceded = 0,
    this.economy = 0,
    this.average = 0,
    this.strikeRate = 0,
    this.fiveWickets = 0,
    this.best = '-',
  });

  factory BowlingStats.fromJson(Map<String, dynamic> j) => BowlingStats(
        matches: (j['matches'] as num?)?.toInt() ?? 0,
        innings: (j['innings'] as num?)?.toInt() ?? 0,
        wickets: (j['wickets'] as num?)?.toInt() ?? 0,
        balls: (j['balls'] as num?)?.toInt() ?? 0,
        runsConceded: (j['runsConceded'] as num?)?.toInt() ?? 0,
        economy: (j['economy'] as num?)?.toDouble() ?? 0,
        average: (j['average'] as num?)?.toDouble() ?? 0,
        strikeRate: (j['strikeRate'] as num?)?.toDouble() ?? 0,
        fiveWickets: (j['fiveWickets'] as num?)?.toInt() ?? 0,
        best: j['best'] as String? ?? '-',
      );

  Map<String, dynamic> toJson() => {
        'matches': matches,
        'innings': innings,
        'wickets': wickets,
        'balls': balls,
        'runsConceded': runsConceded,
        'economy': economy,
        'average': average,
        'strikeRate': strikeRate,
        'fiveWickets': fiveWickets,
        'best': best,
      };
}

/// One entry of recent form: last-N matches, most recent first.
class FormEntry {
  final String matchLabel;
  final String opponent;
  final String format;
  final int runs;
  final int balls;
  final int wickets;
  final String result; // W / L / NR

  const FormEntry({
    required this.matchLabel,
    required this.opponent,
    required this.format,
    this.runs = 0,
    this.balls = 0,
    this.wickets = 0,
    this.result = 'NR',
  });

  factory FormEntry.fromJson(Map<String, dynamic> j) => FormEntry(
        matchLabel: j['matchLabel'] as String? ?? '',
        opponent: j['opponent'] as String? ?? '',
        format: j['format'] as String? ?? '',
        runs: (j['runs'] as num?)?.toInt() ?? 0,
        balls: (j['balls'] as num?)?.toInt() ?? 0,
        wickets: (j['wickets'] as num?)?.toInt() ?? 0,
        result: j['result'] as String? ?? 'NR',
      );

  Map<String, dynamic> toJson() => {
        'matchLabel': matchLabel,
        'opponent': opponent,
        'format': format,
        'runs': runs,
        'balls': balls,
        'wickets': wickets,
        'result': result,
      };
}

/// Bowler-vs-batter matchup: how often this bowler dismissed this batter.
class Matchup {
  final String bowlerId;
  final String bowlerName;
  final String batterId;
  final String batterName;
  final int matches;
  final int balls;
  final int runs;
  final int dismissals;

  const Matchup({
    required this.bowlerId,
    required this.bowlerName,
    required this.batterId,
    required this.batterName,
    this.matches = 0,
    this.balls = 0,
    this.runs = 0,
    this.dismissals = 0,
  });

  double get strikeRate => balls == 0 ? 0 : runs * 100 / balls;
  double get ballsPerDismissal =>
      dismissals == 0 ? 0 : balls / dismissals;

  factory Matchup.fromJson(Map<String, dynamic> j) => Matchup(
        bowlerId: j['bowlerId'] as String? ?? '',
        bowlerName: j['bowlerName'] as String? ?? '',
        batterId: j['batterId'] as String? ?? '',
        batterName: j['batterName'] as String? ?? '',
        matches: (j['matches'] as num?)?.toInt() ?? 0,
        balls: (j['balls'] as num?)?.toInt() ?? 0,
        runs: (j['runs'] as num?)?.toInt() ?? 0,
        dismissals: (j['dismissals'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'bowlerId': bowlerId,
        'bowlerName': bowlerName,
        'batterId': batterId,
        'batterName': batterName,
        'matches': matches,
        'balls': balls,
        'runs': runs,
        'dismissals': dismissals,
      };
}

class Player {
  final String id;
  final String name;
  final String team;
  final String role; // Batter / Bowler / All-rounder / Wicketkeeper
  final String battingStyle;
  final String bowlingStyle;
  final String country;

  /// Format -> stats. Keys: Test, ODI, T20, T10.
  final Map<String, BattingStats> battingByFormat;
  final Map<String, BowlingStats> bowlingByFormat;

  /// Opponent team name -> stats vs that opponent (all formats combined).
  final Map<String, BattingStats> battingVsOpponent;
  final Map<String, BowlingStats> bowlingVsOpponent;

  /// League name -> batting stats in that league.
  final Map<String, BattingStats> battingByLeague;

  /// Venue id -> batting stats at that venue.
  final Map<String, BattingStats> battingByVenue;

  final List<FormEntry> recentForm;
  final List<Matchup> matchups; // as batter vs named bowlers
  final List<String> dismissalHistory; // human-readable lines
  final bool dataComplete;
  final DateTime? lastUpdated;

  /// Where this profile's stats were calculated from.
  /// '' = curated demo / provider basic profile (labelled as such).
  /// 'cricsheet' = REAL stats calculated from Cricsheet open
  /// ball-by-ball data (see CricsheetService). [sourceMatches] is how
  /// many matches in the loaded dataset back the numbers — never
  /// present sample-scope stats as a full career.
  final String source;
  final int sourceMatches;

  const Player({
    required this.id,
    required this.name,
    required this.team,
    this.role = 'Batter',
    this.battingStyle = '',
    this.bowlingStyle = '',
    this.country = '',
    this.battingByFormat = const {},
    this.bowlingByFormat = const {},
    this.battingVsOpponent = const {},
    this.bowlingVsOpponent = const {},
    this.battingByLeague = const {},
    this.battingByVenue = const {},
    this.recentForm = const [],
    this.matchups = const [],
    this.dismissalHistory = const [],
    this.dataComplete = false,
    this.lastUpdated,
    this.source = '',
    this.sourceMatches = 0,
  });

  BattingStats battingOverall() => battingByFormat.values
      .fold(const BattingStats(), (a, b) => a + b);

  /// V2: total wickets across formats (sum, best ignored).
  BowlingStats bowlingOverall() {
    var wkts = 0;
    var matches = 0;
    for (final s in bowlingByFormat.values) {
      wkts += s.wickets;
      matches += s.matches;
    }
    return BowlingStats(wickets: wkts, matches: matches);
  }

  BattingStats battingInFormat(String format) =>
      battingByFormat[format] ?? const BattingStats();

  BattingStats battingVs(String opponent) =>
      battingVsOpponent[opponent] ?? const BattingStats();

  factory Player.fromJson(Map<String, dynamic> j) {
    Map<String, BattingStats> batMap(dynamic m) => (m as Map?)
            ?.map((k, v) => MapEntry(
                k.toString(),
                BattingStats.fromJson(
                    (v as Map).cast<String, dynamic>()))) ??
        {};
    Map<String, BowlingStats> bowlMap(dynamic m) => (m as Map?)
            ?.map((k, v) => MapEntry(
                k.toString(),
                BowlingStats.fromJson(
                    (v as Map).cast<String, dynamic>()))) ??
        {};
    return Player(
      id: j['id'] as String? ?? '',
      name: j['name'] as String? ?? '',
      team: j['team'] as String? ?? '',
      role: j['role'] as String? ?? 'Batter',
      battingStyle: j['battingStyle'] as String? ?? '',
      bowlingStyle: j['bowlingStyle'] as String? ?? '',
      country: j['country'] as String? ?? '',
      battingByFormat: batMap(j['battingByFormat']),
      bowlingByFormat: bowlMap(j['bowlingByFormat']),
      battingVsOpponent: batMap(j['battingVsOpponent']),
      bowlingVsOpponent: bowlMap(j['bowlingVsOpponent']),
      battingByLeague: batMap(j['battingByLeague']),
      battingByVenue: batMap(j['battingByVenue']),
      recentForm: ((j['recentForm'] as List?) ?? [])
          .map((e) => FormEntry.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      matchups: ((j['matchups'] as List?) ?? [])
          .map((e) => Matchup.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      dismissalHistory:
          ((j['dismissalHistory'] as List?) ?? []).map((e) => '$e').toList(),
      dataComplete: j['dataComplete'] as bool? ?? false,
      lastUpdated: j['lastUpdated'] == null
          ? null
          : DateTime.tryParse(j['lastUpdated'] as String),
      source: j['source'] as String? ?? '',
      sourceMatches: (j['sourceMatches'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'team': team,
        'role': role,
        'battingStyle': battingStyle,
        'bowlingStyle': bowlingStyle,
        'country': country,
        'battingByFormat':
            battingByFormat.map((k, v) => MapEntry(k, v.toJson())),
        'bowlingByFormat':
            bowlingByFormat.map((k, v) => MapEntry(k, v.toJson())),
        'battingVsOpponent':
            battingVsOpponent.map((k, v) => MapEntry(k, v.toJson())),
        'bowlingVsOpponent':
            bowlingVsOpponent.map((k, v) => MapEntry(k, v.toJson())),
        'battingByLeague':
            battingByLeague.map((k, v) => MapEntry(k, v.toJson())),
        'battingByVenue':
            battingByVenue.map((k, v) => MapEntry(k, v.toJson())),
        'recentForm': recentForm.map((e) => e.toJson()).toList(),
        'matchups': matchups.map((e) => e.toJson()).toList(),
        'dismissalHistory': dismissalHistory,
        'dataComplete': dataComplete,
        'lastUpdated': lastUpdated?.toIso8601String(),
        'source': source,
        'sourceMatches': sourceMatches,
      };

  Player copyWith({bool? dataComplete, DateTime? lastUpdated}) => Player(
        id: id,
        name: name,
        team: team,
        role: role,
        battingStyle: battingStyle,
        bowlingStyle: bowlingStyle,
        country: country,
        battingByFormat: battingByFormat,
        bowlingByFormat: bowlingByFormat,
        battingVsOpponent: battingVsOpponent,
        bowlingVsOpponent: bowlingVsOpponent,
        battingByLeague: battingByLeague,
        battingByVenue: battingByVenue,
        recentForm: recentForm,
        matchups: matchups,
        dismissalHistory: dismissalHistory,
        dataComplete: dataComplete ?? this.dataComplete,
        lastUpdated: lastUpdated ?? this.lastUpdated,
        source: source,
        sourceMatches: sourceMatches,
      );
}
