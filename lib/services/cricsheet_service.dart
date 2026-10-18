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
/// SCOPE HONESTY: the bundled asset is a SUBSET (420 real
/// internationals, Sep 2025 -> Oct 2026 — verified by counting
/// matches by year; FIX7's "2024-01" claim was wrong, see
/// CRICSHEET-WIRING.md). 303 T20 / 92 ODI / 25 Test; 263 male /
/// 157 female.
/// Stats built from it are REAL calculations over those matches,
/// labelled `source: 'cricsheet'` with `sourceMatches` = matches in
/// the dataset — never presented as a full career. The full dataset
/// is the Cricsheet all_json.zip download (see CRICSHEET-DATA.md
/// "Full dataset"). When more matches are loaded, the same code
/// recomputes everything — no rework.
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

  /// 'male' / 'female' from info.gender. CRICSHEET-WIRING: the
  /// dataset mixes men's and women's matches under the SAME team
  /// names ("Pakistan"), so every squad / H2H / venue query must
  /// filter by gender — otherwise a men's squad fills up with
  /// women's players and stars (Babar) get pushed out of the top 20.
  final String gender;

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
    this.gender = 'male',
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

  /// App-wide cache for the bundled asset: the 25 MB asset is
  /// parsed ONCE per app run, no matter how many ApiService
  /// instances screens create. A caller-supplied bundle bypasses
  /// the cache (test isolation). Never throws: returns an empty
  /// service when the asset is missing or malformed.
  static Future<CricsheetService>? _bundledCache;

  /// Load the bundled sample asset. Never throws: returns an empty
  /// service when the asset is missing or malformed.
  static Future<CricsheetService> loadBundled({AssetBundle? bundle}) async {
    if (bundle != null) {
      try {
        return parse(await bundle.loadString(assetPath));
      } catch (_) {
        return CricsheetService.empty();
      }
    }
    _bundledCache ??= (() async {
      try {
        return parse(await rootBundle.loadString(assetPath));
      } catch (_) {
        return CricsheetService.empty();
      }
    })();
    return _bundledCache!;
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
      gender: '${info['gender'] ?? 'male'}',
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
  /// KingCric id ("p-virat"), and — CRICSHEET-WIRING fix — ANY short
  /// name present in the loaded dataset ("K Mendis") plus the
  /// 'cs-...' ids squadForTeams assigns. Previously only the 44
  /// hard-coded [_identities] resolved, so the other ~1,800 players
  /// in the 420-match dataset were invisible to every query.
  /// Returns null when unknown. The last-name fallback stays
  /// restricted to [_identities] — over 1,847 names it would
  /// otherwise pick the wrong player.
  String? resolveShortName(String query) {
    final q = query.trim();
    if (q.isEmpty) return null;
    if (_identities.containsKey(q)) return q;
    if (q.startsWith('cs-')) {
      final unescaped = q.substring(3).replaceAll('_', ' ');
      if (_index.knownShorts.contains(unescaped)) return unescaped;
    }
    for (final e in _identities.entries) {
      if (e.value.id == q) return e.key;
      if (e.value.displayName.toLowerCase() == q.toLowerCase()) {
        return e.key;
      }
    }
    // Exact short name anywhere in the loaded dataset.
    if (_index.knownShorts.contains(q)) return q;
    // Last-name fallback: "Kohli" -> "V Kohli" (identities only).
    final last = q.split(' ').last.toLowerCase();
    for (final e in _identities.entries) {
      if (e.key.toLowerCase().endsWith(last)) return e.key;
    }
    return null;
  }

  _Identity? _identityFor(String shortName) => _identities[shortName];

  /// First team (dataset order) the player appeared for.
  String _teamOf(String shortName) =>
      _index.playerTeams[shortName]?.firstOrNull ?? '';

  /// Short name for a [Player] built by this service: 'cs-...' ids
  /// unescape to the short name; `p-*` ids / display names resolve
  /// through [resolveShortName]. Null when the player is not a
  /// Cricsheet player (mock / scorecard-only rows).
  String? shortNameForPlayer(Player p) {
    if (p.id.startsWith('cs-')) {
      final unescaped = p.id.substring(3).replaceAll('_', ' ');
      if (_index.knownShorts.contains(unescaped)) return unescaped;
      return null;
    }
    return resolveShortName(p.name) ?? resolveShortName(p.id);
  }

  // ---- One-pass index -------------------------------------------------

  /// All per-player aggregates, built in ONE pass over the deliveries.
  /// The old code rescanned every delivery per player per scope
  /// (format x opponent x venue x league) — building a 40-player
  /// squad that way is ~200M operations and hangs the UI. Every
  /// query below reads from this index; it is built lazily once.
  _CsIndex? _indexCache;
  _CsIndex get _index => _indexCache ??= _buildIndex();

  _CsIndex _buildIndex() {
    final idx = _CsIndex();
    _BatAgg batAgg(String p, String k) =>
        (idx.bat[p] ??= {})[k] ??= _BatAgg();
    _BowlAgg bowlAgg(String p, String k) =>
        (idx.bowl[p] ??= {})[k] ??= _BowlAgg();

    for (var mi = 0; mi < matches.length; mi++) {
      final m = matches[mi];
      final fmt = m.format;
      final lg = leagueForEvent(m.eventName);
      final ven = m.venue;
      idx.venues.add(ven);
      idx.leagues.add(lg);
      // XI membership: teams (first-seen order), recency, XI matches.
      for (final e in m.playersByTeam.entries) {
        final team = e.key;
        final opp = m.teams.firstWhere((t) => t != team, orElse: () => '');
        for (final short in e.value) {
          final teams = idx.playerTeams[short] ??= [];
          if (!teams.contains(team)) teams.add(team);
          idx.playerGenders.putIfAbsent(short, () => {}).add(m.gender);
          idx.playerXiMatches.putIfAbsent(short, () => {}).add(mi);
          if (idx.playerLastDate[short] == null ||
              m.date.compareTo(idx.playerLastDate[short]!) > 0) {
            idx.playerLastDate[short] = m.date;
            idx.playerLastMatch[short] = mi;
          }
          idx.knownShorts.add(short);
          for (final k in ['all', 'fmt:$fmt', 'opp:$opp', 'ven:$ven', 'lg:$lg']) {
            batAgg(short, k).matches.add(mi);
          }
        }
      }
      for (final d in m.deliveries) {
        final key = '$mi:${d.inningsIndex}';
        final batKeys = [
          'all',
          'fmt:$fmt',
          'opp:${d.bowlingTeam}',
          'ven:$ven',
          'lg:$lg',
        ];
        final bowlKeys = [
          'all',
          'fmt:$fmt',
          'opp:${d.battingTeam}',
          'ven:$ven',
          'lg:$lg',
        ];
        // Batting.
        final b = d.batter;
        idx.knownShorts.add(b);
        for (final k in batKeys) {
          final a = batAgg(b, k);
          a.matches.add(mi);
          a.innings.add(key);
          a.inningsRuns[key] =
              (a.inningsRuns[key] ?? 0) + d.batterRuns;
          if (!d.isWide) a.balls += 1;
          a.runs += d.batterRuns;
          if (d.batterRuns == 4) a.fours += 1;
          if (d.batterRuns == 6) a.sixes += 1;
          if (d.isWicket && d.playerOut == b) a.dismissedInnings.add(key);
        }
        // Dismissed without facing (e.g. run out at non-striker's end).
        if (d.isWicket && d.playerOut != null && d.playerOut != b) {
          final o = d.playerOut!;
          idx.knownShorts.add(o);
          for (final k in batKeys) {
            final a = batAgg(o, k);
            a.matches.add(mi);
            a.innings.add(key);
            a.inningsRuns[key] ??= 0;
            a.dismissedInnings.add(key);
          }
        }
        // Bowling (byes / leg-byes are not charged to the bowler).
        final bw = d.bowler;
        idx.knownShorts.add(bw);
        final charged = d.totalRuns - d.byes - d.legByes;
        for (final k in bowlKeys) {
          final a = bowlAgg(bw, k);
          a.matches.add(mi);
          a.innings.add(key);
          if (d.isLegalBall) a.balls += 1;
          a.runsConceded += charged;
          a.perInningsRuns[key] =
              (a.perInningsRuns[key] ?? 0) + charged;
          if (d.isWicket &&
              bowlerCreditedKinds.contains(d.wicketKind)) {
            a.wickets += 1;
            a.perInningsWkts[key] = (a.perInningsWkts[key] ?? 0) + 1;
          }
        }
        // Recent form.
        final fb = (idx.form[b] ??= {})[mi] ??= _FormAgg();
        fb.batted = true;
        fb.runs += d.batterRuns;
        if (!d.isWide) fb.balls += 1;
        final fw = (idx.form[bw] ??= {})[mi] ??= _FormAgg();
        if (d.isWicket && bowlerCreditedKinds.contains(d.wicketKind)) {
          fw.wkts += 1;
        }
        // Bowler-vs-batter pair.
        final pair = (idx.pairs[bw] ??= {})[b] ??= _PairAgg();
        pair.matches.add(mi);
        if (!d.isWide) pair.balls += 1;
        pair.runs += charged;
        if (d.isWicket &&
            d.playerOut == b &&
            bowlerCreditedKinds.contains(d.wicketKind)) {
          pair.dismissals += 1;
        }
        // Dismissal history for the batter.
        final bb = (idx.bowlerBallsVs[b] ??= {});
        if (!d.isWide) bb[bw] = (bb[bw] ?? 0) + 1;
        if (d.isWicket && d.playerOut == b) {
          final kind = d.wicketKind ?? '';
          final bowlerName = _identities[bw]?.displayName ?? bw;
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
            final f = d.fielders.isEmpty ? '' : ' ${d.fielders.first}';
            line = 'c$f b $bowlerName';
          } else {
            line = '$kind b $bowlerName';
          }
          final counts = (idx.dismissalCounts[b] ??= {});
          counts[line] = (counts[line] ?? 0) + 1;
          if (bowlerCreditedKinds.contains(kind)) {
            final bd = (idx.bowlerDismissalsVs[b] ??= {});
            bd[bw] = (bd[bw] ?? 0) + 1;
          }
        }
      }
    }
    // Per-team squads, most recent first.
    for (final e in idx.playerTeams.entries) {
      for (final team in e.value) {
        (idx.teamPlayers[team] ??= []).add(e.key);
      }
    }
    // Squad ranking: most-established first — appearances desc,
    // recency desc as tie-break. Pure recency drops stars who
    // missed the last SAMPLED series (the bundled asset is a
    // monthly stratified sample, not every match — e.g. Babar
    // missed Pakistan's last sampled series and fell out of a
    // recency-only top 20). Appearances-first keeps the team's
    // real core squad; every listed player still has REAL stats.
    for (final list in idx.teamPlayers.values) {
      list.sort((a, b2) {
        final ca = idx.playerXiMatches[a]?.length ?? 0;
        final cb = idx.playerXiMatches[b2]?.length ?? 0;
        final c = cb.compareTo(ca);
        if (c != 0) return c;
        final da = idx.playerLastDate[a] ?? '';
        final db = idx.playerLastDate[b2] ?? '';
        final d = db.compareTo(da);
        return d != 0 ? d : a.compareTo(b2);
      });
    }
    return idx;
  }

  BattingStats _battingFromAgg(_BatAgg a) {
    var fifties = 0;
    var hundreds = 0;
    var highest = 0;
    for (final r in a.inningsRuns.values) {
      if (r >= 100) {
        hundreds += 1;
      } else if (r >= 50) {
        fifties += 1;
      }
      if (r > highest) highest = r;
    }
    return BattingStats(
      matches: a.matches.length,
      innings: a.innings.length,
      runs: a.runs,
      balls: a.balls,
      fifties: fifties,
      hundreds: hundreds,
      fours: a.fours,
      sixes: a.sixes,
      average: a.dismissedInnings.isNotEmpty
          ? a.runs / a.dismissedInnings.length
          : (a.innings.isNotEmpty ? a.runs.toDouble() : 0),
      strikeRate: a.balls > 0 ? a.runs * 100 / a.balls : 0,
      highest: highest,
    );
  }

  BowlingStats _bowlingFromAgg(_BowlAgg a) {
    var fiveWickets = 0;
    var bestWkts = 0;
    var bestRuns = 0;
    for (final e in a.perInningsWkts.entries) {
      if (e.value >= 5) fiveWickets += 1;
      final r = a.perInningsRuns[e.key] ?? 0;
      if (e.value > bestWkts ||
          (e.value == bestWkts && r < bestRuns)) {
        bestWkts = e.value;
        bestRuns = r;
      }
    }
    return BowlingStats(
      matches: a.matches.length,
      innings: a.innings.length,
      wickets: a.wickets,
      balls: a.balls,
      runsConceded: a.runsConceded,
      economy: a.balls > 0 ? a.runsConceded * 6 / a.balls : 0,
      average: a.wickets > 0 ? a.runsConceded / a.wickets : 0,
      strikeRate: a.wickets > 0 ? a.balls / a.wickets : 0,
      fiveWickets: fiveWickets,
      best: bestWkts > 0 ? '$bestWkts/$bestRuns' : '-',
    );
  }

  /// Team-name equality for H2H / squad lookups: compare BASE
  /// names (a trailing " Women" / " Men" suffix is stripped —
  /// Cricsheet stores "Pakistan" for both genders and separates
  /// them with [CricsheetMatch.gender], while providers write
  /// "Pakistan Women"). Gender separation happens via the
  /// [gender] parameter, never by name — "Pakistan Women" must NOT
  /// silently match the men's "Pakistan" squad.
  static String _baseTeamName(String name) {
    var n = name.trim();
    final lower = n.toLowerCase();
    for (final suffix in [' women', ' men']) {
      if (lower.endsWith(suffix)) {
        n = n.substring(0, n.length - suffix.length).trim();
        break;
      }
    }
    return n;
  }

  static bool _sameTeam(String a, String b) =>
      _baseTeamName(a).toLowerCase() ==
      _baseTeamName(b).toLowerCase();

  /// Gender inferred from a provider team name: 'female' when the
  /// name ends in " Women", otherwise 'male' (providers write bare
  /// names for men's teams). An explicit [gender] argument always
  /// wins over inference.
  static String _genderForTeam(String teamName, String? gender) {
    if (gender != null) return gender;
    return teamName.trim().toLowerCase().endsWith(' women')
        ? 'female'
        : 'male';
  }

  /// Cricsheet team key for a provider team name, or null when the
  /// dataset has no such team (franchise sides, leagues outside
  /// the bundled internationals). Callers fall back to mock /
  /// scorecard data — never invent a squad.
  String? _findTeamKey(String teamName) {
    final base = _baseTeamName(teamName);
    if (_index.teamPlayers.containsKey(base)) return base;
    for (final k in _index.teamPlayers.keys) {
      if (_sameTeam(k, base)) return k;
    }
    return null;
  }

  // ---- Public queries --------------------------------------------------

  /// Full player profile calculated from ball-by-ball data.
  /// Returns null when the player has no data in the loaded matches.
  Player? playerById(String idOrName) {
    final short = resolveShortName(idOrName);
    if (short == null) return null;
    return playerByShortName(short);
  }

  Player? playerByShortName(String shortName) {
    final idx = _index;
    // CRICSHEET-WIRING: any name in the dataset builds a profile —
    // the old code returned null for everyone outside the 44-name
    // identity map. Display name is the full name when known,
    // otherwise the Cricsheet short name as-is (never invented).
    if (!idx.knownShorts.contains(shortName)) return null;
    final ident = _identityFor(shortName);
    final team = _teamOf(shortName);
    final batMap = idx.bat[shortName] ?? {};
    final bowlMap = idx.bowl[shortName] ?? {};

    final battingByFormat = <String, BattingStats>{};
    final bowlingByFormat = <String, BowlingStats>{};
    for (final fmt in ['Test', 'ODI', 'T20', 'T10']) {
      final bat = batMap['fmt:$fmt'];
      // WIRING correctness fix: `matches` is now scope-aware (XI
      // matches IN this format). The old per-scope accumulator
      // added EVERY XI match to every format, inflating
      // battingOverall().matches across formats.
      if (bat != null &&
          (bat.innings.isNotEmpty || bat.matches.isNotEmpty)) {
        battingByFormat[fmt] = _battingFromAgg(bat);
      }
      final bowl = bowlMap['fmt:$fmt'];
      if (bowl != null && bowl.innings.isNotEmpty) {
        bowlingByFormat[fmt] = _bowlingFromAgg(bowl);
      }
    }
    final battingVsOpponent = <String, BattingStats>{};
    final bowlingVsOpponent = <String, BowlingStats>{};
    final opponents = <String>{};
    for (final m in matches) {
      for (final t in m.teams) {
        if (t != team) opponents.add(t);
      }
    }
    for (final opp in opponents) {
      final bat = batMap['opp:$opp'];
      if (bat != null && bat.innings.isNotEmpty) {
        battingVsOpponent[opp] = _battingFromAgg(bat);
      }
      final bowl = bowlMap['opp:$opp'];
      if (bowl != null && bowl.innings.isNotEmpty) {
        bowlingVsOpponent[opp] = _bowlingFromAgg(bowl);
      }
    }
    final battingByVenue = <String, BattingStats>{};
    for (final venue in idx.venues) {
      if (venue.isEmpty) continue;
      final bat = batMap['ven:$venue'];
      if (bat != null && bat.innings.isNotEmpty) {
        battingByVenue[venue] = _battingFromAgg(bat);
      }
    }
    final battingByLeague = <String, BattingStats>{};
    for (final league in idx.leagues) {
      final bat = batMap['lg:$league'];
      if (bat != null && bat.innings.isNotEmpty) {
        battingByLeague[league] = _battingFromAgg(bat);
      }
    }

    // Role: curated when known, otherwise inferred from what the
    // player actually did in the data — never guessed from a name.
    String role;
    if (ident != null) {
      role = ident.role;
    } else {
      final batted = (batMap['all']?.balls ?? 0) > 0 ||
          (batMap['all']?.innings.isNotEmpty ?? false);
      final bowled = (bowlMap['all']?.balls ?? 0) > 0;
      role = bowled && batted
          ? 'All-rounder'
          : bowled
              ? 'Bowler'
              : 'Batter';
    }

    return Player(
      id: ident?.id ?? 'cs-${shortName.replaceAll(' ', '_')}',
      name: ident?.displayName ?? shortName,
      team: team,
      role: role,
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
      sourceMatches: idx.playerXiMatches[shortName]?.length ?? 0,
    );
  }

  /// Bowler-vs-batter matchup: balls / runs / bowler-credited
  /// dismissals for one pair across all loaded matches.
  Matchup matchup(
      {required String bowler, required String batter}) {
    final bowlerShort = resolveShortName(bowler) ?? bowler;
    final batterShort = resolveShortName(batter) ?? batter;
    final pair = _index.pairs[bowlerShort]?[batterShort];
    return Matchup(
      bowlerId: _identities[bowlerShort]?.id ??
          'cs-${bowlerShort.replaceAll(' ', '_')}',
      bowlerName:
          _identities[bowlerShort]?.displayName ?? bowlerShort,
      batterId: _identities[batterShort]?.id ??
          'cs-${batterShort.replaceAll(' ', '_')}',
      batterName:
          _identities[batterShort]?.displayName ?? batterShort,
      matches: pair?.matches.length ?? 0,
      balls: pair?.balls ?? 0,
      runs: pair?.runs ?? 0,
      dismissals: pair?.dismissals ?? 0,
    );
  }

  /// All matchups for one batter (vs every bowler who bowled to them),
  /// most balls first. Used for the profile "Bowler vs Batter" section.
  List<Matchup> matchupsForBatter(String batter) {
    final batterShort = resolveShortName(batter) ?? batter;
    final out = <Matchup>[];
    for (final e in _index.pairs.entries) {
      final pair = e.value[batterShort];
      if (pair != null && pair.balls > 0) {
        out.add(matchup(bowler: e.key, batter: batterShort));
      }
    }
    out.sort((a, b) => b.balls.compareTo(a.balls));
    return out.take(6).toList();
  }

  /// "c X b Y — N times" lines, plus one "Never dismissed by Z"
  /// line for the bowler with most balls and zero dismissals
  /// (min 12 balls), when one exists.
  List<String> dismissalHistoryFor(String batter) {
    final batterShort = resolveShortName(batter) ?? batter;
    final idx = _index;
    final counts = idx.dismissalCounts[batterShort] ?? {};
    final bowlerBalls = idx.bowlerBallsVs[batterShort] ?? {};
    final bowlerDismissals = idx.bowlerDismissalsVs[batterShort] ?? {};
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
    final formMap = _index.form[short];
    if (formMap == null) return [];
    final entries = <FormEntry>[];
    final sorted = formMap.keys
        .map((i) => matches[i])
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    for (final m in sorted) {
      final fa = formMap[m.index]!;
      if (!fa.batted && fa.wkts == 0) continue;
      final opp = m.teams.firstWhere((t) => t != team, orElse: () => '');
      String result = 'NR';
      if (m.winner.isNotEmpty) {
        result = m.winner == team ? 'W' : 'L';
      }
      entries.add(FormEntry(
        matchLabel: m.teams.join(' vs '),
        opponent: opp,
        format: m.format,
        runs: fa.runs,
        balls: fa.balls,
        wickets: fa.wkts,
        result: result,
      ));
      if (entries.length >= 5) break;
    }
    return entries;
  }

  /// Team H2H: {matches, teamAWins, teamBWins, noResult}.
  /// Optional [format] restricts to one format ('ODI', 'T20',
  /// ...). Optional [gender] restricts to men's / women's
  /// meetings — pass it whenever the calling match knows its
  /// gender, otherwise men's and women's meetings are pooled
  /// (legacy behaviour, kept for callers without match context).
  Map<String, int> teamH2H(String teamA, String teamB,
      {String? format, String? gender}) {
    var played = 0;
    var aWins = 0;
    var bWins = 0;
    final fmt = format == null ? null : normalizeFormat(format);
    for (final m in matches) {
      if (fmt != null && m.format != fmt) continue;
      if (gender != null && m.gender != gender) continue;
      final hasA = m.teams.any((t) => _sameTeam(t, teamA));
      final hasB = m.teams.any((t) => _sameTeam(t, teamB));
      if (!hasA || !hasB) continue;
      played += 1;
      if (m.winner.isNotEmpty && _sameTeam(m.winner, teamA)) aWins += 1;
      if (m.winner.isNotEmpty && _sameTeam(m.winner, teamB)) bWins += 1;
    }
    return {
      'matches': played,
      'teamAWins': aWins,
      'teamBWins': bWins,
      'noResult': played - aWins - bWins,
    };
  }

  /// H2H with the format (and gender) of the current match — the
  /// Venue & H2H tab calls this. Same result shape as [teamH2H].
  Map<String, int> teamHeadToHead(String teamA, String teamB,
          {String? format, String? gender}) =>
      teamH2H(teamA, teamB, format: format, gender: gender);

  /// Squad for both teams of a match, from the bundled Cricsheet
  /// dataset — players who appeared for that team, ranked by
  /// appearances IN THE MATCH'S FORMAT first (then overall
  /// appearances, then recency), capped at [limit] per team.
  /// Format-aware ranking matters because the dataset skews T20
  /// (303 T20 / 92 ODI / 25 Test): ranking by total appearances
  /// would fill an ODI squad with T20I regulars and drop ODI-only
  /// stars (Kohli plays only ODIs now — 3 sampled matches, all
  /// ODI). Every player is a FULL
  /// [Player] with REAL computed stats (overall + this-format +
  /// vs-opponent + recent form). Keyed by the team names passed
  /// in, so callers can look up by match team name. Empty list
  /// for a team the dataset has no players for (franchise sides,
  /// leagues outside the bundled internationals) — callers fall
  /// back to mock / scorecard data, never invent a squad.
  /// [format] is accepted for API stability; membership is by
  /// recency across formats (a squad is the team's recent XI pool,
  /// and per-format splits live on each [Player]).
  Map<String, List<Player>> squadForTeams(String teamA, String teamB,
      {String? format,
      String? opponent,
      int limit = 20,
      String? gender}) {
    final out = <String, List<Player>>{};
    final fmt = format == null ? null : normalizeFormat(format);
    for (final team in [teamA, teamB]) {
      final key = _findTeamKey(team);
      final g = _genderForTeam(team, gender);
      final shorts = key == null
          ? const <String>[]
          : _index.teamPlayers[key] ?? const <String>[];
      // Gender filter: a men's squad must not contain women's
      // players (and vice versa) — the dataset stores both under
      // the same team name.
      final filtered = shorts
          .where((s) => (_index.playerGenders[s] ?? {}).contains(g))
          .toList();
      // Format-aware ranking: appearances in THIS format first,
      // then overall appearances, then recency. teamPlayers is
      // pre-sorted by overall appearances; re-sort per call so a
      // T20I-heavy pool does not crowd out ODI/Test specialists.
      if (fmt != null) {
        int fmtApps(String s) =>
            _index.bat[s]?['fmt:$fmt']?.matches.length ?? 0;
        filtered.sort((a, b2) {
          final c = fmtApps(b2).compareTo(fmtApps(a));
          if (c != 0) return c;
          final oa = _index.playerXiMatches[a]?.length ?? 0;
          final ob = _index.playerXiMatches[b2]?.length ?? 0;
          final d = ob.compareTo(oa);
          if (d != 0) return d;
          return a.compareTo(b2);
        });
      }
      out[team] = filtered
          .take(limit)
          .map(playerByShortName)
          .whereType<Player>()
          .toList();
    }
    return out;
  }

  /// Venue stats computed from bundled matches at [venueName]
  /// (fuzzy match: "Rawalpindi Cricket Stadium, Rawalpindi" matches
  /// the dataset's "Rawalpindi Cricket Stadium"). Null when no
  /// bundled match was played there. Pitch / weather are NOT in
  /// Cricsheet — the Venue tab keeps "Not available from free
  /// providers yet" for those, never faked.
  VenueStats? venueStats(String venueName, {String? gender}) {
    final matched = matches
        .where((m) =>
            _venueMatches(m.venue, venueName) &&
            (gender == null || m.gender == gender))
        .toList();
    if (matched.isEmpty) return null;
    var firstSum = 0;
    var firstCount = 0;
    var secondSum = 0;
    var secondCount = 0;
    var highest = 0;
    var batFirstWins = 0;
    var decided = 0;
    String city = '';
    for (final m in matched) {
      if (city.isEmpty) city = m.city;
      final totals = <int, int>{};
      String? firstBattingTeam;
      for (final d in m.deliveries) {
        totals[d.inningsIndex] =
            (totals[d.inningsIndex] ?? 0) + d.totalRuns;
        if (d.inningsIndex == 0) firstBattingTeam ??= d.battingTeam;
      }
      final first = totals[0];
      if (first != null) {
        firstSum += first;
        firstCount += 1;
        if (first > highest) highest = first;
      }
      final second = totals[1];
      if (second != null) {
        secondSum += second;
        secondCount += 1;
        if (second > highest) highest = second;
      }
      if (m.winner.isNotEmpty && firstBattingTeam != null) {
        decided += 1;
        if (_sameTeam(m.winner, firstBattingTeam)) batFirstWins += 1;
      }
    }
    return VenueStats(
      venue: matched.first.venue,
      city: city,
      matches: matched.length,
      avgFirstInnings:
          firstCount > 0 ? firstSum / firstCount : 0,
      avgSecondInnings:
          secondCount > 0 ? secondSum / secondCount : 0,
      highestTotal: highest,
      batFirstWinPct: decided > 0 ? batFirstWins * 100 / decided : 0,
    );
  }

  static String _normVenue(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static bool _venueMatches(String venue, String query) {
    final a = _normVenue(venue);
    final b = _normVenue(query);
    if (a.isEmpty || b.isEmpty) return false;
    if (a == b || a.contains(b) || b.contains(a)) return true;
    final at = a.split(' ').toSet();
    final bt = b.split(' ').toSet();
    final inter = at.intersection(bt).length;
    final minLen = at.length < bt.length ? at.length : bt.length;
    return minLen > 0 && inter / minLen >= 0.75;
  }

  /// Cross-squad bowler-vs-batter matchups from Cricsheet:
  /// bowler in one squad, batter in the other only (same-team
  /// pairs are not head-to-head). Sorted dismissals desc, then
  /// balls desc. Used by the Venue & H2H tab — the old path read
  /// matchups off mock players' stored lists, which were empty
  /// for real matches.
  List<Matchup> crossSquadMatchups(
      List<Player> squadA, List<Player> squadB,
      {int limit = 5}) {
    final a = squadA
        .map(shortNameForPlayer)
        .whereType<String>()
        .toSet();
    final b = squadB
        .map(shortNameForPlayer)
        .whereType<String>()
        .toSet();
    if (a.isEmpty || b.isEmpty) return [];
    final out = <Matchup>[];
    for (final bowler in {...a, ...b}) {
      for (final batter in {...a, ...b}) {
        if (bowler == batter) continue;
        final cross = (a.contains(bowler) && b.contains(batter)) ||
            (b.contains(bowler) && a.contains(batter));
        if (!cross) continue;
        final m = matchup(bowler: bowler, batter: batter);
        if (m.dismissals > 0 || m.balls >= 12) out.add(m);
      }
    }
    out.sort((x, y) {
      final d = y.dismissals.compareTo(x.dismissals);
      return d != 0 ? d : y.balls.compareTo(x.balls);
    });
    return out.take(limit).toList();
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

/// Venue stats computed from bundled Cricsheet matches.
/// All numbers are REAL counts over the matched matches — never
/// invented. Pitch / weather are not in Cricsheet and are not here.
class VenueStats {
  final String venue;
  final String city;
  final int matches;
  final double avgFirstInnings;
  final double avgSecondInnings;
  final int highestTotal;
  final double batFirstWinPct;
  const VenueStats({
    required this.venue,
    required this.city,
    required this.matches,
    required this.avgFirstInnings,
    required this.avgSecondInnings,
    required this.highestTotal,
    required this.batFirstWinPct,
  });
}

/// One-pass index over the loaded matches. Split keys:
/// 'all', 'fmt:<Format>', 'opp:<Team>', 'ven:<Venue>', 'lg:<League>'.
class _CsIndex {
  final Map<String, Map<String, _BatAgg>> bat = {};
  final Map<String, Map<String, _BowlAgg>> bowl = {};
  final Map<String, Map<int, _FormAgg>> form = {};
  final Map<String, Map<String, _PairAgg>> pairs = {};
  final Map<String, Map<String, int>> dismissalCounts = {};
  final Map<String, Map<String, int>> bowlerBallsVs = {};
  final Map<String, Map<String, int>> bowlerDismissalsVs = {};
  final Map<String, List<String>> playerTeams = {};
  final Map<String, Set<String>> playerGenders = {};
  final Map<String, Set<int>> playerXiMatches = {};
  final Map<String, String> playerLastDate = {};
  final Map<String, int> playerLastMatch = {};
  final Map<String, List<String>> teamPlayers = {};
  final Set<String> knownShorts = {};
  final Set<String> venues = {};
  final Set<String> leagues = {};
}

class _BatAgg {
  /// Match indices where the player batted OR was in the XI
  /// (scope-aware: only matches in this split).
  final Set<int> matches = {};
  final Set<String> innings = {};
  final Map<String, int> inningsRuns = {};
  final Set<String> dismissedInnings = {};
  int runs = 0;
  int balls = 0;
  int fours = 0;
  int sixes = 0;
}

class _BowlAgg {
  final Set<int> matches = {};
  final Set<String> innings = {};
  int balls = 0;
  int runsConceded = 0;
  int wickets = 0;
  final Map<String, int> perInningsWkts = {};
  final Map<String, int> perInningsRuns = {};
}

class _FormAgg {
  bool batted = false;
  int runs = 0;
  int balls = 0;
  int wkts = 0;
}

class _PairAgg {
  int balls = 0;
  int runs = 0;
  int dismissals = 0;
  final Set<int> matches = {};
}
