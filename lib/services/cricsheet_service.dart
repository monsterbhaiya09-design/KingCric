import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/player.dart';

/// Cricsheet open-data service — REAL player stats calculated from
/// ball-by-ball data, never scraped, never hard-coded.
///
/// Cricsheet (cricsheet.org) publishes ball-by-ball match data as open
/// data in JSON v1.3.0: `meta`, `info`, `innings`. Every delivery is
/// `{batter, bowler, non_striker, runs: {batter, extras, total},
/// extras: {wides, noballs, byes, legbyes, penalty},
/// wickets: [{kind, player_out, fielders: [{name}]}]}`.
/// See CRICSHEET-DATA.md for the full format, downloads, and licence
/// note. NEVER scrape Cricbuzz / Cricinfo / Cricmetrics.
///
/// What this service computes from deliveries:
/// - career: runs / balls / average / SR / 50s / 100s / highest
/// - splits: by format, vs opponent, by venue, by league/event
/// - bowling: wickets / economy / average / SR / best / 5-fors
/// - bowler-vs-batter matchups (balls, runs, bowler-credited dismissals)
/// - dismissal history ("c X b Y — N times", "never dismissed by Z")
/// - recent form (last 5 matches, most recent first)
/// - team H2H, partnerships, fall of wickets
///
/// SCOPE HONESTY: the bundled asset is a SAMPLE subset (4 T20
/// internationals). Stats built from it are REAL calculations over
/// those matches, labelled `source: 'cricsheet'` with
/// `sourceMatches` = matches in the dataset — never presented as a
/// full career. The full dataset is the Cricsheet all_json.zip
/// download (see CRICSHEET-DATA.md "Full dataset"). When more matches
/// are loaded, the same code recomputes everything — no rework.
class CricsheetDelivery {
  final int matchIndex;
  final int inningsIndex;
  final String battingTeam;
  final String bowlingTeam;
  final String batter;
  final String bowler;
  final String nonStriker;
  final int batterRuns;
  final int extrasRuns;
  final int totalRuns;
  final int wides;
  final int noBalls;
  final int byes;
  final int legByes;
  final String actualDelivery;
  final String? wicketKind;
  final String? playerOut;
  final List<String> fielders;

  const CricsheetDelivery({
    required this.matchIndex,
    required this.inningsIndex,
    required this.battingTeam,
    required this.bowlingTeam,
    required this.batter,
    required this.bowler,
    required this.nonStriker,
    required this.batterRuns,
    required this.extrasRuns,
    required this.totalRuns,
    required this.wides,
    required this.noBalls,
    required this.byes,
    required this.legByes,
    required this.actualDelivery,
    this.wicketKind,
    this.playerOut,
    this.fielders = const [],
  });

  bool get isWide => wides > 0;
  bool get isNoBall => noBalls > 0;
  bool get isLegalBall => !isWide && !isNoBall;
  bool get isWicket => wicketKind != null && playerOut != null;
}

class CricsheetMatch {
  final int index;
  final List<String> dates;
  final String venue;
  final String city;
  final String matchType;
  final String eventName;
  final List<String> teams;
  final String winner;
  final String tossWinner;
  final String tossDecision;
  final Map<String, List<String>> playersByTeam;
  final List<CricsheetDelivery> deliveries;

  const CricsheetMatch({
    required this.index,
    required this.dates,
    required this.venue,
    required this.city,
    required this.matchType,
    required this.eventName,
    required this.teams,
    required this.winner,
    required this.tossWinner,
    required this.tossDecision,
    required this.playersByTeam,
    required this.deliveries,
  });

  String get date => dates.isEmpty ? '' : dates.first;
  String get format => CricsheetService.normalizeFormat(matchType);
}

/// Cricsheet short name -> KingCric identity. Cricsheet uses scorecard
/// names ("V Kohli", "RG Sharma"); the app uses full names + `p-*` ids.
class _Identity {
  final String id;
  final String displayName;
  final String role;
  const _Identity(this.id, this.displayName, this.role);
}

class CricsheetService {
  final List<CricsheetMatch> matches;

  CricsheetService(this.matches);

  /// Empty service — every query returns null / []. Never throws.
  CricsheetService.empty() : matches = const [];

  int get matchCount => matches.length;

  static const String assetPath = 'assets/cricsheet_sample.json';
  static const String sourceLabel = 'cricsheet';

  /// Load the bundled sample asset. Never throws: returns an empty
  /// service when the asset is missing or malformed.
  static Future<CricsheetService> loadBundled({AssetBundle? bundle}) async {
    try {
      final b = bundle ?? rootBundle;
      final text = await b.loadString(assetPath);
      return parse(text);
    } catch (_) {
      return CricsheetService.empty();
    }
  }

  /// Parse a Cricsheet JSON document: either a single match object
  /// (`{meta, info, innings}`) or a wrapper (`{matches: [...]}` — the
  /// bundled sample shape). Never throws.
  static CricsheetService parse(String jsonText) {
    try {
      final decoded = jsonDecode(jsonText);
      if (decoded is Map<String, dynamic>) {
        final list = decoded['matches'];
        if (list is List) {
          return CricsheetService(_parseMatches(list));
        }
        // A bare object is a match only if it has innings; '{}' etc.
        // must yield an empty service, not a phantom match.
        if (decoded.containsKey('innings')) {
          return CricsheetService([_parseMatch(decoded, 0)]);
        }
        return CricsheetService.empty();
      }
      if (decoded is List) {
        return CricsheetService(_parseMatches(decoded));
      }
    } catch (_) {}
    return CricsheetService.empty();
  }

  static List<CricsheetMatch> _parseMatches(List<dynamic> list) {
    final out = <CricsheetMatch>[];
    for (var i = 0; i < list.length; i++) {
      try {
        if (list[i] is Map<String, dynamic> &&
            (list[i] as Map<String, dynamic>).containsKey('innings')) {
          out.add(_parseMatch(list[i] as Map<String, dynamic>, i));
        }
      } catch (_) {}
    }
    return out;
  }

  static CricsheetMatch _parseMatch(Map<String, dynamic> j, int index) {
    final info = (j['info'] as Map?)?.cast<String, dynamic>() ?? {};
    final teams = ((info['teams'] as List?) ?? [])
        .map((e) => '$e')
        .toList();
    final playersByTeam = <String, List<String>>{};
    final playersRaw = (info['players'] as Map?)?.cast<String, dynamic>() ?? {};
    for (final e in playersRaw.entries) {
      playersByTeam[e.key] = ((e.value as List?) ?? []).map((p) => '$p').toList();
    }
    final outcome = (info['outcome'] as Map?)?.cast<String, dynamic>() ?? {};
    final toss = (info['toss'] as Map?)?.cast<String, dynamic>() ?? {};
    final event = (info['event'] as Map?)?.cast<String, dynamic>() ?? {};
    final deliveries = <CricsheetDelivery>[];
    final inningsRaw = (j['innings'] as List?) ?? [];
    for (var ii = 0; ii < inningsRaw.length; ii++) {
      try {
        final inn = (inningsRaw[ii] as Map).cast<String, dynamic>();
        final battingTeam = '${inn['team'] ?? ''}';
        final bowlingTeam = teams.firstWhere(
          (t) => t != battingTeam,
          orElse: () => '',
        );
        final overs = (inn['overs'] as List?) ?? [];
        for (final overRaw in overs) {
          final over = (overRaw as Map).cast<String, dynamic>();
          final dList = (over['deliveries'] as List?) ?? [];
          for (final dRaw in dList) {
            try {
              final d = (dRaw as Map).cast<String, dynamic>();
              final runs = (d['runs'] as Map?)?.cast<String, dynamic>() ?? {};
              final extras =
                  (d['extras'] as Map?)?.cast<String, dynamic>() ?? {};
              String? kind;
              String? out;
              final fielders = <String>[];
              final wkts = (d['wickets'] as List?) ?? [];
              if (wkts.isNotEmpty) {
                final w = (wkts.first as Map).cast<String, dynamic>();
                kind = '${w['kind'] ?? ''}';
                out = '${w['player_out'] ?? ''}';
                for (final f in (w['fielders'] as List?) ?? []) {
                  fielders.add('${(f as Map)['name'] ?? ''}');
                }
              }
              deliveries.add(CricsheetDelivery(
                matchIndex: index,
                inningsIndex: ii,
                battingTeam: battingTeam,
                bowlingTeam: bowlingTeam,
                batter: '${d['batter'] ?? ''}',
                bowler: '${d['bowler'] ?? ''}',
                nonStriker: '${d['non_striker'] ?? ''}',
                batterRuns: _int(runs['batter']),
                extrasRuns: _int(runs['extras']),
                totalRuns: _int(runs['total']),
                wides: _int(extras['wides']),
                noBalls: _int(extras['noballs']),
                byes: _int(extras['byes']),
                legByes: _int(extras['legbyes']),
                actualDelivery: '${d['actual_delivery'] ?? ''}',
                wicketKind: kind,
                playerOut: out,
                fielders: fielders,
              ));
            } catch (_) {}
          }
        }
      } catch (_) {}
    }
    return CricsheetMatch(
      index: index,
      dates: ((info['dates'] as List?) ?? []).map((e) => '$e').toList(),
      venue: '${info['venue'] ?? ''}',
      city: '${info['city'] ?? ''}',
      matchType: '${info['match_type'] ?? ''}',
      eventName: '${event['name'] ?? ''}',
      teams: teams,
      winner: '${outcome['winner'] ?? ''}',
      tossWinner: '${toss['winner'] ?? ''}',
      tossDecision: '${toss['decision'] ?? ''}',
      playersByTeam: playersByTeam,
      deliveries: deliveries,
    );
  }

  static int _int(Object? v) {
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  /// IT20 -> T20, ODM -> ODI, MDM -> Test (multi-day). Unknown -> raw.
  static String normalizeFormat(String raw) {
    switch (raw.trim()) {
      case 'IT20':
      case 'T20':
        return 'T20';
      case 'ODM':
      case 'ODI':
        return 'ODI';
      case 'MDM':
      case 'Test':
        return 'Test';
      case 'T10':
        return 'T10';
      default:
        return raw.isEmpty ? 'T20' : raw;
    }
  }

  /// Event name -> league bucket for `battingByLeague`.
  static String leagueForEvent(String event) {
    final e = event.toLowerCase();
    if (e.contains('ipl') || e.contains('indian premier')) return 'IPL';
    if (e.contains('psl') || e.contains('pakistan super')) return 'PSL';
    if (e.contains('big bash')) return 'Big Bash';
    if (e.contains('t10')) return 'T10 League';
    if (e.contains('ranji')) return 'Ranji Trophy';
    if (e.contains('syed mushtaq')) return 'Syed Mushtaq Ali';
    if (e.contains('vijay hazare')) return 'Vijay Hazare';
    return 'International';
  }

  /// Wicket kinds credited to the bowler (run out / retired hurt /
  /// obstructing the field are NOT the bowler's wicket).
  static const bowlerCreditedKinds = {
    'bowled',
    'caught',
    'caught and bowled',
    'lbw',
    'stumped',
    'hit wicket',
    'handled the ball',
  };

  // ---- Identity ------------------------------------------------------

  static const Map<String, _Identity> _identities = {
    'V Kohli': _Identity('p-virat', 'Virat Kohli', 'Batter'),
    'RG Sharma': _Identity('p-rohit', 'Rohit Sharma', 'Batter'),
    'Babar Azam': _Identity('p-babar', 'Babar Azam', 'Batter'),
    'Shaheen Shah Afridi':
        _Identity('p-shaheen', 'Shaheen Afridi', 'Bowler'),
    'JJ Bumrah': _Identity('p-bumrah', 'Jasprit Bumrah', 'Bowler'),
    'SA Yadav': _Identity('p-surya', 'Suryakumar Yadav', 'Batter'),
    'S Gill': _Identity('p-gill', 'Shubman Gill', 'Batter'),
    'HH Pandya': _Identity('p-hardik', 'Hardik Pandya', 'All-rounder'),
    'RR Pant': _Identity('p-pant', 'Rishabh Pant', 'Wicketkeeper'),
    'AR Patel': _Identity('p-axar', 'Axar Patel', 'All-rounder'),
    'K Yadav': _Identity('p-kuldeep', 'Kuldeep Yadav', 'Bowler'),
    'A Singh': _Identity('p-arshdeep', 'Arshdeep Singh', 'Bowler'),
    'R Jadeja': _Identity('p-jadeja', 'Ravindra Jadeja', 'All-rounder'),
    'Mohammad Rizwan':
        _Identity('p-rizwan', 'Mohammad Rizwan', 'Wicketkeeper'),
    'Fakhar Zaman': _Identity('p-fakhar', 'Fakhar Zaman', 'Batter'),
    'Iftikhar Ahmed': _Identity('p-iftikhar', 'Iftikhar Ahmed', 'Batter'),
    'Shadab Khan': _Identity('p-shadab', 'Shadab Khan', 'All-rounder'),
    'Imad Wasim': _Identity('p-imad', 'Imad Wasim', 'All-rounder'),
    'Naseem Shah': _Identity('p-naseem', 'Naseem Shah', 'Bowler'),
    'Haris Rauf': _Identity('p-haris', 'Haris Rauf', 'Bowler'),
    'Usman Khan': _Identity('p-usman', 'Usman Khan', 'Batter'),
    'Abrar Ahmed': _Identity('p-abrar', 'Abrar Ahmed', 'Bowler'),
    'DA Warner': _Identity('p-warner', 'David Warner', 'Batter'),
    'TM Head': _Identity('p-head', 'Travis Head', 'Batter'),
    'MR Marsh': _Identity('p-marsh', 'Mitchell Marsh', 'All-rounder'),
    'GJ Maxwell': _Identity('p-maxwell', 'Glenn Maxwell', 'All-rounder'),
    'MP Stoinis': _Identity('p-stoinis', 'Marcus Stoinis', 'All-rounder'),
    'TH David': _Identity('p-david', 'Tim David', 'Batter'),
    'MS Wade': _Identity('p-wade', 'Matthew Wade', 'Wicketkeeper'),
    'PJ Cummins': _Identity('p-cummins', 'Pat Cummins', 'Bowler'),
    'M Starc': _Identity('p-starc', 'Mitchell Starc', 'Bowler'),
    'A Zampa': _Identity('p-zampa', 'Adam Zampa', 'Bowler'),
    'JR Hazlewood': _Identity('p-hazlewood', 'Josh Hazlewood', 'Bowler'),
    'PD Salt': _Identity('p-salt', 'Phil Salt', 'Wicketkeeper'),
    'JM Bairstow': _Identity('p-bairstow', 'Jonny Bairstow', 'Wicketkeeper'),
    'HC Brook': _Identity('p-brook', 'Harry Brook', 'Batter'),
    'JC Buttler': _Identity('p-buttler', 'Jos Buttler', 'Wicketkeeper'),
    'LS Livingstone':
        _Identity('p-livingstone', 'Liam Livingstone', 'All-rounder'),
    'MM Ali': _Identity('p-moeen', 'Moeen Ali', 'All-rounder'),
    'SM Curran': _Identity('p-curran', 'Sam Curran', 'All-rounder'),
    'AU Rashid': _Identity('p-rashid', 'Adil Rashid', 'Bowler'),
    'CJ Jordan': _Identity('p-jordan', 'Chris Jordan', 'Bowler'),
    'RJW Topley': _Identity('p-topley', 'Reece Topley', 'Bowler'),
    'MA Wood': _Identity('p-wood', 'Mark Wood', 'Bowler'),
  };

  /// Resolve any name form -> Cricsheet short name.
  /// Accepts: Cricsheet name ("V Kohli"), full name ("Virat Kohli"),
  /// KingCric id ("p-virat"). Returns null when unknown.
  String? resolveShortName(String query) {
    final q = query.trim();
    if (q.isEmpty) return null;
    if (_identities.containsKey(q)) return q;
    for (final e in _identities.entries) {
      if (e.value.id == q) return e.key;
      if (e.value.displayName.toLowerCase() == q.toLowerCase()) {
        return e.key;
      }
    }
    // Last-name fallback: "Kohli" -> "V Kohli".
    final last = q.split(' ').last.toLowerCase();
    for (final e in _identities.entries) {
      if (e.key.toLowerCase().endsWith(last)) return e.key;
    }
    return null;
  }

  _Identity? _identityFor(String shortName) => _identities[shortName];

  String _teamOf(String shortName) {
    for (final m in matches) {
      for (final e in m.playersByTeam.entries) {
        if (e.value.contains(shortName)) return e.key;
      }
    }
    return '';
  }

  // ---- Aggregations ---------------------------------------------------

  /// Per-(player) accumulator over one scope (format / opponent /
  /// venue / league / overall). Built fresh per query — the dataset
  /// is small (sample) and the code stays obviously correct; for a
  /// full all_json.zip load, cache the result in the caller.
  _BatAcc _batAcc(String shortName, bool Function(CricsheetMatch m,
          CricsheetDelivery d, String opponent, String venue)
      scope) {
    final acc = _BatAcc();
    final inningsRuns = <String, int>{};
    final inningsDismissed = <String, int>{};
    final inningsSeen = <String>{};
    final matchesSeen = <int>{};
    for (final m in matches) {
      for (final d in m.deliveries) {
        if (d.batter != shortName) continue;
        final opp = d.bowlingTeam;
        if (!scope(m, d, opp, m.venue)) continue;
        matchesSeen.add(m.index);
        final key = '${m.index}:${d.inningsIndex}';
        inningsSeen.add(key);
        if (!d.isWide) {
          acc.balls += 1;
          inningsRuns[key] = (inningsRuns[key] ?? 0) + d.batterRuns;
        } else {
          inningsRuns[key] = inningsRuns[key] ?? 0;
        }
        acc.runs += d.batterRuns;
        if (d.batterRuns == 4) acc.fours += 1;
        if (d.batterRuns == 6) acc.sixes += 1;
        if (d.isWicket && d.playerOut == shortName) {
          inningsDismissed[key] = 1;
        }
      }
      // Dismissed without facing (e.g. run out at non-striker's end).
      for (final d in m.deliveries) {
        if (d.isWicket && d.playerOut == shortName && d.batter != shortName) {
          final opp = d.bowlingTeam;
          if (!scope(m, d, opp, m.venue)) continue;
          matchesSeen.add(m.index);
          final key = '${m.index}:${d.inningsIndex}';
          inningsSeen.add(key);
          inningsRuns[key] = inningsRuns[key] ?? 0;
          inningsDismissed[key] = 1;
        }
      }
    }
    acc.matches = matchesSeen.length;
    acc.innings = inningsSeen.length;
    acc.dismissals = inningsDismissed.values.fold(0, (a, b) => a + b);
    for (final r in inningsRuns.values) {
      if (r >= 100) acc.hundreds += 1;
      if (r >= 50 && r < 100) acc.fifties += 1;
      if (r > acc.highest) acc.highest = r;
    }
    // Matches where the player was in the XI but did not bat still
    // count as a match played (for career matches).
    for (final m in matches) {
      if (m.playersByTeam.values.any((xi) => xi.contains(shortName))) {
        matchesSeen.add(m.index);
      }
    }
    acc.matches = matchesSeen.length;
    return acc;
  }

  _BowlAcc _bowlAcc(String shortName, bool Function(CricsheetMatch m,
          CricsheetDelivery d, String opponent, String venue)
      scope) {
    final acc = _BowlAcc();
    final perInningsWkts = <String, int>{};
    final perInningsRuns = <String, int>{};
    final inningsSeen = <String>{};
    final matchesSeen = <int>{};
    for (final m in matches) {
      for (final d in m.deliveries) {
        if (d.bowler != shortName) continue;
        final opp = d.battingTeam;
        if (!scope(m, d, opp, m.venue)) continue;
        matchesSeen.add(m.index);
        final key = '${m.index}:${d.inningsIndex}';
        inningsSeen.add(key);
        if (d.isLegalBall) acc.balls += 1;
        // Byes / leg-byes are not charged to the bowler.
        acc.runsConceded += d.totalRuns - d.byes - d.legByes;
        if (d.isWicket &&
            d.playerOut != null &&
            bowlerCreditedKinds.contains(d.wicketKind)) {
          acc.wickets += 1;
          perInningsWkts[key] = (perInningsWkts[key] ?? 0) + 1;
        }
        perInningsRuns[key] =
            (perInningsRuns[key] ?? 0) + (d.totalRuns - d.byes - d.legByes);
      }
    }
    acc.matches = matchesSeen.length;
    acc.innings = inningsSeen.length;
    for (final e in perInningsWkts.entries) {
      if (e.value >= 5) acc.fiveWickets += 1;
      final r = perInningsRuns[e.key] ?? 0;
      if (e.value > acc.bestWkts ||
          (e.value == acc.bestWkts && r < acc.bestRuns)) {
        acc.bestWkts = e.value;
        acc.bestRuns = r;
      }
    }
    return acc;
  }

  BattingStats _toBatting(_BatAcc a) => BattingStats(
        matches: a.matches,
        innings: a.innings,
        runs: a.runs,
        balls: a.balls,
        fifties: a.fifties,
        hundreds: a.hundreds,
        fours: a.fours,
        sixes: a.sixes,
        average: a.dismissals > 0
            ? a.runs / a.dismissals
            : (a.innings > 0 ? a.runs.toDouble() : 0),
        strikeRate: a.balls > 0 ? a.runs * 100 / a.balls : 0,
        highest: a.highest,
      );

  BowlingStats _toBowling(_BowlAcc a) => BowlingStats(
        matches: a.matches,
        innings: a.innings,
        wickets: a.wickets,
        balls: a.balls,
        runsConceded: a.runsConceded,
        economy: a.balls > 0 ? a.runsConceded * 6 / a.balls : 0,
        average: a.wickets > 0 ? a.runsConceded / a.wickets : 0,
        strikeRate: a.wickets > 0 ? a.balls / a.wickets : 0,
        fiveWickets: a.fiveWickets,
        best: a.bestWkts > 0 ? '${a.bestWkts}/${a.bestRuns}' : '-',
      );

  // ---- Public queries --------------------------------------------------

  /// Full player profile calculated from ball-by-ball data.
  /// Returns null when the player has no data in the loaded matches.
  Player? playerById(String idOrName) {
    final short = resolveShortName(idOrName);
    if (short == null) return null;
    return playerByShortName(short);
  }

  Player? playerByShortName(String shortName) {
    final ident = _identityFor(shortName);
    if (ident == null) return null;
    final team = _teamOf(shortName);
    final played = matches.any((m) =>
        m.playersByTeam.values.any((xi) => xi.contains(shortName)) ||
        m.deliveries.any(
            (d) => d.batter == shortName || d.bowler == shortName));
    if (!played) return null;

    final battingByFormat = <String, BattingStats>{};
    final bowlingByFormat = <String, BowlingStats>{};
    for (final fmt in ['Test', 'ODI', 'T20', 'T10']) {
      final bat = _batAcc(
          shortName, (m, d, o, v) => m.format == fmt);
      if (bat.innings > 0 || bat.matches > 0) {
        battingByFormat[fmt] = _toBatting(bat);
      }
      final bowl = _bowlAcc(
          shortName, (m, d, o, v) => m.format == fmt);
      if (bowl.innings > 0) bowlingByFormat[fmt] = _toBowling(bowl);
    }
    // If the player never batted, keep an empty-but-present map so
    // the profile still shows bowling. (BattingStats defaults to 0.)
    final battingVsOpponent = <String, BattingStats>{};
    final bowlingVsOpponent = <String, BowlingStats>{};
    final opponents = <String>{};
    for (final m in matches) {
      for (final t in m.teams) {
        if (t != team) opponents.add(t);
      }
    }
    for (final opp in opponents) {
      final bat = _batAcc(
          shortName, (m, d, o, v) => o == opp);
      if (bat.innings > 0) battingVsOpponent[opp] = _toBatting(bat);
      final bowl = _bowlAcc(
          shortName, (m, d, o, v) => o == opp);
      if (bowl.innings > 0) bowlingVsOpponent[opp] = _toBowling(bowl);
    }
    final battingByVenue = <String, BattingStats>{};
    for (final m in matches) {
      if (m.venue.isEmpty) continue;
      final bat = _batAcc(
          shortName, (mm, d, o, v) => v == m.venue);
      if (bat.innings > 0) battingByVenue[m.venue] = _toBatting(bat);
    }
    final battingByLeague = <String, BattingStats>{};
    for (final m in matches) {
      final league = leagueForEvent(m.eventName);
      final bat = _batAcc(shortName,
          (mm, d, o, v) => leagueForEvent(mm.eventName) == league);
      if (bat.innings > 0) battingByLeague[league] = _toBatting(bat);
    }

    final playedMatches = matches
        .where((m) => m.playersByTeam.values
            .any((xi) => xi.contains(shortName)))
        .toList();

    return Player(
      id: ident.id,
      name: ident.displayName,
      team: team,
      role: ident.role,
      battingStyle: '',
      bowlingStyle: '',
      country: team,
      battingByFormat: battingByFormat,
      bowlingByFormat: bowlingByFormat,
      battingVsOpponent: battingVsOpponent,
      bowlingVsOpponent: bowlingVsOpponent,
      battingByLeague: battingByLeague,
      battingByVenue: battingByVenue,
      recentForm: recentFormFor(shortName),
      matchups: matchupsForBatter(shortName),
      dismissalHistory: dismissalHistoryFor(shortName),
      dataComplete: true,
      lastUpdated: DateTime.now(),
      source: sourceLabel,
      sourceMatches: playedMatches.length,
    );
  }

  /// Bowler-vs-batter matchup: balls / runs / bowler-credited
  /// dismissals for one pair across all loaded matches.
  Matchup matchup(
      {required String bowler, required String batter}) {
    final bowlerShort = resolveShortName(bowler) ?? bowler;
    final batterShort = resolveShortName(batter) ?? batter;
    var balls = 0;
    var runs = 0;
    var dismissals = 0;
    final matchesSeen = <int>{};
    for (final m in matches) {
      var seen = false;
      for (final d in m.deliveries) {
        if (d.bowler != bowlerShort || d.batter != batterShort) continue;
        seen = true;
        if (!d.isWide) balls += 1;
        runs += d.totalRuns - d.byes - d.legByes;
        if (d.isWicket &&
            d.playerOut == batterShort &&
            bowlerCreditedKinds.contains(d.wicketKind)) {
          dismissals += 1;
        }
      }
      if (seen) matchesSeen.add(m.index);
    }
    return Matchup(
      bowlerId: _identities[bowlerShort]?.id ?? bowlerShort,
      bowlerName:
          _identities[bowlerShort]?.displayName ?? bowlerShort,
      batterId: _identities[batterShort]?.id ?? batterShort,
      batterName:
          _identities[batterShort]?.displayName ?? batterShort,
      matches: matchesSeen.length,
      balls: balls,
      runs: runs,
      dismissals: dismissals,
    );
  }

  /// All matchups for one batter (vs every bowler who bowled to them),
  /// most balls first. Used for the profile "Bowler vs Batter" section.
  List<Matchup> matchupsForBatter(String batter) {
    final batterShort = resolveShortName(batter) ?? batter;
    final bowlers = <String>{};
    for (final m in matches) {
      for (final d in m.deliveries) {
        if (d.batter == batterShort) bowlers.add(d.bowler);
      }
    }
    final out = bowlers
        .map((b) => matchup(bowler: b, batter: batterShort))
        .where((x) => x.balls > 0)
        .toList();
    out.sort((a, b) => b.balls.compareTo(a.balls));
    return out.take(6).toList();
  }

  /// "c X b Y — N times" lines, most frequent first, plus one
  /// "Never dismissed by Z" line for the bowler with most balls and
  /// zero dismissals (min 12 balls), when one exists.
  List<String> dismissalHistoryFor(String batter) {
    final batterShort = resolveShortName(batter) ?? batter;
    final counts = <String, int>{};
    final bowlerBalls = <String, int>{};
    final bowlerDismissals = <String, int>{};
    for (final m in matches) {
      for (final d in m.deliveries) {
        if (d.batter != batterShort) continue;
        if (!d.isWide) {
          bowlerBalls[d.bowler] = (bowlerBalls[d.bowler] ?? 0) + 1;
        }
        if (d.isWicket && d.playerOut == batterShort) {
          final kind = d.wicketKind ?? '';
          final bowlerName =
              _identities[d.bowler]?.displayName ?? d.bowler;
          String line;
          if (kind == 'run out') {
            final f = d.fielders.isEmpty
                ? ''
                : ' (${d.fielders.join(' / ')})';
            line = 'run out$f';
          } else if (kind == 'bowled') {
            line = 'b $bowlerName';
          } else if (kind == 'lbw') {
            line = 'lbw b $bowlerName';
          } else if (kind == 'stumped') {
            final f = d.fielders.isEmpty ? '' : ' ${d.fielders.first}';
            line = 'st$f b $bowlerName';
          } else if (kind == 'caught') {
            final f = d.fielders.isEmpty
                ? ''
                : ' ${d.fielders.first}';
            line = 'c$f b $bowlerName';
          } else {
            line = '$kind b $bowlerName';
          }
          counts[line] = (counts[line] ?? 0) + 1;
          if (bowlerCreditedKinds.contains(kind)) {
            bowlerDismissals[d.bowler] =
                (bowlerDismissals[d.bowler] ?? 0) + 1;
          }
        }
      }
    }
    final lines = counts.entries
        .map((e) => '${e.key} — ${e.value} time${e.value == 1 ? '' : 's'}')
        .toList();
    lines.sort();
    // Never-dismissed line.
    String? best;
    var bestBalls = 0;
    for (final e in bowlerBalls.entries) {
      if ((bowlerDismissals[e.key] ?? 0) == 0 && e.value > bestBalls) {
        best = e.key;
        bestBalls = e.value;
      }
    }
    if (best != null && bestBalls >= 12) {
      final name = _identities[best]?.displayName ?? best;
      lines.add('Not dismissed by $name in $bestBalls balls');
    }
    return lines;
  }

  /// Last 5 matches for one player, most recent first.
  List<FormEntry> recentFormFor(String player) {
    final short = resolveShortName(player) ?? player;
    final team = _teamOf(short);
    final entries = <FormEntry>[];
    final sorted = [...matches]
      ..sort((a, b) => b.date.compareTo(a.date));
    for (final m in sorted) {
      final inXi = m.playersByTeam.values.any((xi) => xi.contains(short));
      if (!inXi) continue;
      var runs = 0;
      var balls = 0;
      var wkts = 0;
      var batted = false;
      for (final d in m.deliveries) {
        if (d.batter == short) {
          batted = true;
          runs += d.batterRuns;
          if (!d.isWide) balls += 1;
        }
        if (d.bowler == short &&
            d.isWicket &&
            bowlerCreditedKinds.contains(d.wicketKind)) {
          wkts += 1;
        }
      }
      if (!batted && wkts == 0) continue;
      final opp = m.teams.firstWhere((t) => t != team, orElse: () => '');
      String result = 'NR';
      if (m.winner.isNotEmpty) {
        result = m.winner == team ? 'W' : 'L';
      }
      entries.add(FormEntry(
        matchLabel: m.teams.join(' vs '),
        opponent: opp,
        format: m.format,
        runs: runs,
        balls: balls,
        wickets: wkts,
        result: result,
      ));
      if (entries.length >= 5) break;
    }
    return entries;
  }

  /// Team H2H: {matches, teamAWins, teamBWins, noResult}.
  Map<String, int> teamH2H(String teamA, String teamB) {
    var played = 0;
    var aWins = 0;
    var bWins = 0;
    for (final m in matches) {
      if (!m.teams.contains(teamA) || !m.teams.contains(teamB)) continue;
      played += 1;
      if (m.winner == teamA) aWins += 1;
      if (m.winner == teamB) bWins += 1;
    }
    return {
      'matches': played,
      'teamAWins': aWins,
      'teamBWins': bWins,
      'noResult': played - aWins - bWins,
    };
  }

  /// Partnerships for one innings: "A + B — R (balls)", biggest first.
  List<String> partnerships(int matchIndex, int inningsIndex) {
    final m = matches.firstWhere((x) => x.index == matchIndex,
        orElse: () => const CricsheetMatch(
            index: -1,
            dates: [],
            venue: '',
            city: '',
            matchType: '',
            eventName: '',
            teams: [],
            winner: '',
            tossWinner: '',
            tossDecision: '',
            playersByTeam: {},
            deliveries: []));
    final acc = <String, int>{};
    final balls = <String, int>{};
    String? pairKey;
    for (final d in m.deliveries.where((x) => x.inningsIndex == inningsIndex)) {
      final key = _pairKey(d.batter, d.nonStriker);
      if (pairKey != key) pairKey = key;
      acc[key] = (acc[key] ?? 0) + d.totalRuns;
      balls[key] = (balls[key] ?? 0) + (d.isWide ? 0 : 1);
      if (d.isWicket) pairKey = null;
    }
    final lines = acc.entries
        .map((e) => '${e.key} — ${e.value} (${balls[e.key] ?? 0} balls)')
        .toList();
    lines.sort((a, b) {
      final ra = int.tryParse(a.split('—').last.split('(').first.trim()) ?? 0;
      final rb = int.tryParse(b.split('—').last.split('(').first.trim()) ?? 0;
      return rb.compareTo(ra);
    });
    return lines;
  }

  static String _pairKey(String a, String b) {
    final names = [a, b]..sort();
    return '${names[0]} + ${names[1]}';
  }

  /// Fall of wickets for one innings: "1-52 (Batter, 6.1 ov)".
  List<String> fallOfWickets(int matchIndex, int inningsIndex) {
    final m = matches.firstWhere((x) => x.index == matchIndex,
        orElse: () => const CricsheetMatch(
            index: -1,
            dates: [],
            venue: '',
            city: '',
            matchType: '',
            eventName: '',
            teams: [],
            winner: '',
            tossWinner: '',
            tossDecision: '',
            playersByTeam: {},
            deliveries: []));
    final out = <String>[];
    var total = 0;
    var wkts = 0;
    for (final d in m.deliveries.where((x) => x.inningsIndex == inningsIndex)) {
      total += d.totalRuns;
      if (d.isWicket && d.playerOut != null) {
        wkts += 1;
        out.add('$wkts-$total (${d.playerOut}, ${d.actualDelivery} ov)');
      }
    }
    return out;
  }
}

class _BatAcc {
  int matches = 0;
  int innings = 0;
  int runs = 0;
  int balls = 0;
  int fifties = 0;
  int hundreds = 0;
  int fours = 0;
  int sixes = 0;
  int dismissals = 0;
  int highest = 0;
}

class _BowlAcc {
  int matches = 0;
  int innings = 0;
  int wickets = 0;
  int balls = 0;
  int runsConceded = 0;
  int fiveWickets = 0;
  int bestWkts = 0;
  int bestRuns = 0;
}
