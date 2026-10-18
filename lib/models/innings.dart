/// One innings of a match: batting card + bowling card.
class BattingEntry {
  final String playerId;
  final String playerName;
  final int runs;
  final int balls;
  final int fours;
  final int sixes;
  final String dismissal; // e.g. "c Rizwan b Shaheen" or "not out"
  final bool notOut;

  const BattingEntry({
    required this.playerId,
    required this.playerName,
    this.runs = 0,
    this.balls = 0,
    this.fours = 0,
    this.sixes = 0,
    this.dismissal = '',
    this.notOut = false,
  });

  double get strikeRate => balls == 0 ? 0 : runs * 100 / balls;

  factory BattingEntry.fromJson(Map<String, dynamic> j) => BattingEntry(
        playerId: j['playerId'] as String? ?? '',
        playerName: j['playerName'] as String? ?? '',
        runs: (j['runs'] as num?)?.toInt() ?? 0,
        balls: (j['balls'] as num?)?.toInt() ?? 0,
        fours: (j['fours'] as num?)?.toInt() ?? 0,
        sixes: (j['sixes'] as num?)?.toInt() ?? 0,
        dismissal: j['dismissal'] as String? ?? '',
        notOut: j['notOut'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'playerId': playerId,
        'playerName': playerName,
        'runs': runs,
        'balls': balls,
        'fours': fours,
        'sixes': sixes,
        'dismissal': dismissal,
        'notOut': notOut,
      };
}

class BowlingEntry {
  final String playerId;
  final String playerName;
  final double overs;
  final int maidens;
  final int runsConceded;
  final int wickets;
  final double economy;
  final int wides;
  final int noBalls;

  const BowlingEntry({
    required this.playerId,
    required this.playerName,
    this.overs = 0,
    this.maidens = 0,
    this.runsConceded = 0,
    this.wickets = 0,
    this.economy = 0,
    this.wides = 0,
    this.noBalls = 0,
  });

  factory BowlingEntry.fromJson(Map<String, dynamic> j) => BowlingEntry(
        playerId: j['playerId'] as String? ?? '',
        playerName: j['playerName'] as String? ?? '',
        overs: (j['overs'] as num?)?.toDouble() ?? 0,
        maidens: (j['maidens'] as num?)?.toInt() ?? 0,
        runsConceded: (j['runsConceded'] as num?)?.toInt() ?? 0,
        wickets: (j['wickets'] as num?)?.toInt() ?? 0,
        economy: (j['economy'] as num?)?.toDouble() ?? 0,
        wides: (j['wides'] as num?)?.toInt() ?? 0,
        noBalls: (j['noBalls'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'playerId': playerId,
        'playerName': playerName,
        'overs': overs,
        'maidens': maidens,
        'runsConceded': runsConceded,
        'wickets': wickets,
        'economy': economy,
        'wides': wides,
        'noBalls': noBalls,
      };
}

class Innings {
  final String team;
  final int inningsNumber;
  final int total;
  final int wickets;
  final double overs;
  final List<BattingEntry> batting;
  final List<BowlingEntry> bowling;
  final List<String> fallOfWickets;
  // V2 full scoreboard fields — all optional with defaults so old
  // JSON / tests keep working.
  final int extrasRuns;
  final String extrasText; // e.g. "Wd 3, Nb 1, B 1 (5)"
  final List<String> yetToBat;
  final List<String> partnerships; // e.g. "Virat + Surya 68 (42 balls)"
  final String didNotBatNote;

  const Innings({
    required this.team,
    this.inningsNumber = 1,
    this.total = 0,
    this.wickets = 0,
    this.overs = 0,
    this.batting = const [],
    this.bowling = const [],
    this.fallOfWickets = const [],
    this.extrasRuns = 0,
    this.extrasText = '',
    this.yetToBat = const [],
    this.partnerships = const [],
    this.didNotBatNote = '',
  });

  factory Innings.fromJson(Map<String, dynamic> j) => Innings(
        team: j['team'] as String? ?? '',
        inningsNumber: (j['inningsNumber'] as num?)?.toInt() ?? 1,
        total: (j['total'] as num?)?.toInt() ?? 0,
        wickets: (j['wickets'] as num?)?.toInt() ?? 0,
        overs: (j['overs'] as num?)?.toDouble() ?? 0,
        batting: ((j['batting'] as List?) ?? [])
            .map((e) =>
                BattingEntry.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        bowling: ((j['bowling'] as List?) ?? [])
            .map((e) =>
                BowlingEntry.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        fallOfWickets:
            ((j['fallOfWickets'] as List?) ?? []).map((e) => '$e').toList(),
        extrasRuns: (j['extrasRuns'] as num?)?.toInt() ?? 0,
        extrasText: j['extrasText'] as String? ?? '',
        yetToBat: ((j['yetToBat'] as List?) ?? []).map((e) => '$e').toList(),
        partnerships:
            ((j['partnerships'] as List?) ?? []).map((e) => '$e').toList(),
        didNotBatNote: j['didNotBatNote'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'team': team,
        'inningsNumber': inningsNumber,
        'total': total,
        'wickets': wickets,
        'overs': overs,
        'batting': batting.map((e) => e.toJson()).toList(),
        'bowling': bowling.map((e) => e.toJson()).toList(),
        'fallOfWickets': fallOfWickets,
        'extrasRuns': extrasRuns,
        'extrasText': extrasText,
        'yetToBat': yetToBat,
        'partnerships': partnerships,
        'didNotBatNote': didNotBatNote,
      };
}
