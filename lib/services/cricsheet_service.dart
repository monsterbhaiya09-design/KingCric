import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/match.dart';
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
  /// Over number within the innings (0-based), taken from the raw
  /// over object. -1 when the source did not carry one — grouping
  /// must never invent over boundaries from ball counts alone.
  final int overNumber;
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
    this.overNumber = -1,
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

  /// FULL-ARCHIVE aggregates (Squad D): compact per-player totals
  /// precomputed from the whole Cricsheet archive
  /// (assets/cricsheet_stats.json, 2001-2026, 9,943 internationals)
  /// by tools/aggregate_cricsheet.py. Null when the asset is absent
  /// — every query then falls back to the bundled sample, exactly
  /// as before. Aggregates are NEVER summed with sample totals for
  /// the same player: the archive is a superset of the sample, so
  /// summing would double-count every sampled match. When an
  /// aggregate exists for a player it REPLACES the sample scope;
  /// the sample is used only when no aggregate exists.
  final CricsheetAggregate? aggregate;

  /// DELTA (Squad D): finished matches that ended AFTER the base
  /// asset was generated, converted from their final scorecards
  /// (see [applyFinishedMatch]). Totals shown = base + delta.
  /// Persisted via SharedPreferences (see [persistDelta] /
  /// [loadPersistedDelta]) — ApiService's caches are in-memory
  /// only and die on restart, so an in-memory-only delta would be
  /// lost. Never faked: a match with no scorecard stays pending.
  CricsheetDelta delta;

  CricsheetService(this.matches,
      {this.aggregate, CricsheetDelta? delta})
      : delta = delta ?? CricsheetDelta.empty();

  /// Empty service — every query returns null / []. Never throws.
  CricsheetService.empty()
      : matches = const [],
        aggregate = null,
        delta = CricsheetDelta.empty();

  int get matchCount => matches.length;

  static const String assetPath = 'assets/cricsheet_sample.json';

  /// Full-archive aggregate asset (see tools/aggregate_cricsheet.py).
  static const String aggregateAssetPath = 'assets/cricsheet_stats.json';
  static const String sourceLabel = 'cricsheet';

  /// Honest coverage label for UI (merge step renders it, screens
  /// are another squad's files): full-archive range + match count
  /// when aggregates loaded, otherwise the sample-only truth.
  bool get hasFullAggregates =>
      aggregate != null && aggregate!.matchCount > 0;
  int get aggregateMatchCount => aggregate?.matchCount ?? 0;
  String get aggregateCoverageLabel {
    final a = aggregate;
    if (a == null || a.matchCount == 0) {
      return 'Sample • $matchCount matches (2025–2026)';
    }
    return 'Full archive ${a.yearMin}–${a.yearMax} • '
        '${a.matchCount} matches';
  }

  /// Delta bookkeeping for UI / merge wiring.
  int get deltaMatchCount => delta.matches.length;
  Set<String> get pendingDeltaMatchIds => delta.pendingIds;

  /// App-wide cache for the bundled asset: the 25 MB asset is
  /// parsed ONCE per app run, no matter how many ApiService
  /// instances screens create. A caller-supplied bundle bypasses
  /// the cache (test isolation). Never throws: returns an empty
  /// service when the asset is missing or malformed.
  static Future<CricsheetService>? _bundledCache;

  /// Load the bundled sample asset + the full-archive aggregate
  /// asset. Never throws: returns an empty service when the sample
  /// is missing or malformed; a missing aggregate just means
  /// sample-only totals (see [hasFullAggregates]).
  static Future<CricsheetService> loadBundled({AssetBundle? bundle}) async {
    if (bundle != null) {
      try {
        final svc = parse(await bundle.loadString(assetPath));
        CricsheetAggregate? agg;
        try {
          agg = CricsheetAggregate.parse(
              await bundle.loadString(aggregateAssetPath));
        } catch (_) {}
        return CricsheetService(svc.matches, aggregate: agg);
      } catch (_) {
        return CricsheetService.empty();
      }
    }
    _bundledCache ??= (() async {
      try {
        final svc = parse(await rootBundle.loadString(assetPath));
        CricsheetAggregate? agg;
        try {
          agg = CricsheetAggregate.parse(
              await rootBundle.loadString(aggregateAssetPath));
        } catch (_) {}
        return CricsheetService(svc.matches, aggregate: agg);
      } catch (_) {
        return CricsheetService.empty();
      }
    })();
    return _bundledCache!;
  }

  // ---- Delta persistence + application (Squad D) -------------------

  static const String _deltaPrefsKey = 'kingcric_cricsheet_delta_v1';

  /// Persist the delta (processed match ids + per-match increments
  /// + pending ids) on-device. Call after every successful
  /// [applyFinishedMatch]. Never throws.
  Future<void> persistDelta() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_deltaPrefsKey, jsonEncode(delta.toJson()));
    } catch (_) {}
  }

  /// Load the persisted delta into this service (merge step calls
  /// this once after [loadBundled]). Drops delta matches the new
  /// base already absorbed (see [pruneDeltaAbsorbedByBase]).
  /// Never throws.
  Future<void> loadPersistedDelta() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_deltaPrefsKey);
      if (raw == null || raw.isEmpty) return;
      delta = CricsheetDelta.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
      pruneDeltaAbsorbedByBase();
    } catch (_) {}
  }

  /// Base-regeneration absorption: when the app ships a newer
  /// aggregate asset, every delta match dated on/before the new
  /// base's coverageEnd is already inside the base — keeping its
  /// delta would double-count it. Drop those delta matches (and
  /// their pending entries). Matches after coverageEnd stay.
  /// No-op when no aggregate / no coverageEnd is loaded.
  void pruneDeltaAbsorbedByBase() {
    final end = aggregate?.coverageEnd ?? '';
    if (end.isEmpty) return;
    delta.matches.removeWhere((_, m) =>
        m.date.isNotEmpty && m.date.compareTo(end) <= 0);
    delta.pending.removeWhere((_, d) => d.isNotEmpty && d.compareTo(end) <= 0);
  }

  /// Convert a FINISHED match's final scorecard into per-player
  /// delta increments, on top of the bundled aggregates.
  /// Dedupe: a match id already in [delta] is NEVER counted twice
  /// — repeat calls (finish event + manual refresh, app restarts
  /// via persisted delta) return [DeltaApplyResult.alreadyProcessed]
  /// with totals unchanged. A finished match with no innings
  /// (scorecard unavailable from every provider) is recorded as
  /// PENDING ([pendingDeltaMatchIds]) and returns
  /// [DeltaApplyResult.noScorecard] — never faked, never counted.
  /// Caller persists via [persistDelta] after [applied].
  DeltaApplyResult applyFinishedMatch(CricketMatch detail) {
    if (delta.matches.containsKey(detail.id)) {
      return DeltaApplyResult.alreadyProcessed;
    }
    if (detail.innings.isEmpty) {
      delta.pending[detail.id] = detail.startTime.year >= 2000
          ? detail.startTime.toIso8601String().substring(0, 10)
          : '';
      return DeltaApplyResult.noScorecard;
    }
    final format = normalizeFormat(detail.format);
    final venue = detail.venueName;
    final league =
        detail.league.trim().isNotEmpty ? detail.league : 'International';
    final batAcc = <String, Map<String, _DeltaBatAcc>>{};
    final bowlAcc = <String, Map<String, _DeltaBowlAcc>>{};
    final batSeen = <String>{}; // "$player|$scope" match-counted once
    final bowlSeen = <String>{};

    _DeltaBatAcc batFor(String player, String scope) {
      final m = batAcc[player] ??= {};
      return m[scope] ??= _DeltaBatAcc();
    }

    _DeltaBowlAcc bowlFor(String player, String scope) {
      final m = bowlAcc[player] ??= {};
      return m[scope] ??= _DeltaBowlAcc();
    }

    for (var ii = 0; ii < detail.innings.length; ii++) {
      final inn = detail.innings[ii];
      final batTeam = inn.team;
      final bowlTeam =
          batTeam == detail.teamA ? detail.teamB : detail.teamA;
      final batScopes = <String>[
        'all',
        'fmt:$format',
        'opp:$bowlTeam',
        if (venue.isNotEmpty) 'ven:$venue',
        'lg:$league',
      ];
      final bowlScopes = <String>[
        'all',
        'fmt:$format',
        'opp:$batTeam',
        if (venue.isNotEmpty) 'ven:$venue',
        'lg:$league',
      ];
      for (final b in inn.batting) {
        if (b.playerName.trim().isEmpty) continue;
        for (final s in batScopes) {
          final a = batFor(b.playerName, s);
          if (batSeen.add('${b.playerName}|$s')) a.matches += 1;
          a.innings += 1;
          a.innRuns[ii] = (a.innRuns[ii] ?? 0) + b.runs;
          a.runs += b.runs;
          a.balls += b.balls;
          a.fours += b.fours;
          a.sixes += b.sixes;
          if (!b.notOut) a.dismissals += 1;
        }
      }
      for (final bw in inn.bowling) {
        if (bw.playerName.trim().isEmpty) continue;
        final balls = _oversToBalls(bw.overs);
        if (balls <= 0 && bw.wickets <= 0) continue;
        for (final s in bowlScopes) {
          final a = bowlFor(bw.playerName, s);
          if (bowlSeen.add('${bw.playerName}|$s')) a.matches += 1;
          a.innings += 1;
          a.balls += balls;
          a.runs += bw.runsConceded;
          a.wickets += bw.wickets;
          a.innWkts[ii] = (a.innWkts[ii] ?? 0) + bw.wickets;
          a.innRuns[ii] = (a.innRuns[ii] ?? 0) + bw.runsConceded;
        }
      }
    }

    Map<String, Map<String, List<int>>> emitBat(
        Map<String, Map<String, _DeltaBatAcc>> acc) {
      final out = <String, Map<String, List<int>>>{};
      for (final e in acc.entries) {
        final scopes = <String, List<int>>{};
        for (final s in e.value.entries) {
          scopes[s.key] = s.value.emit();
        }
        if (scopes.isNotEmpty) out[e.key] = scopes;
      }
      return out;
    }

    Map<String, Map<String, List<int>>> emitBowl(
        Map<String, Map<String, _DeltaBowlAcc>> acc) {
      final out = <String, Map<String, List<int>>>{};
      for (final e in acc.entries) {
        final scopes = <String, List<int>>{};
        for (final s in e.value.entries) {
          scopes[s.key] = s.value.emit();
        }
        if (scopes.isNotEmpty) out[e.key] = scopes;
      }
      return out;
    }

    // Store under the raw scorecard name AND the resolved short
    // name when different, so profile lookups (which resolve to
    // shorts) find the delta. Lookups pick ONE key (see
    // [_deltaKeyFor]), so dual storage never double-counts.
    Map<String, Map<String, List<int>>> dualKey(
        Map<String, Map<String, List<int>>> m) {
      final out = Map<String, Map<String, List<int>>>.of(m);
      for (final name in m.keys.toList()) {
        final short = resolveShortName(name);
        if (short != null && short != name) out[short] = m[name]!;
      }
      return out;
    }

    delta.matches[detail.id] = CricsheetDeltaMatch(
      matchId: detail.id,
      date: detail.startTime.year >= 2000
          ? detail.startTime.toIso8601String().substring(0, 10)
          : '',
      format: format,
      venue: venue,
      league: league,
      teamA: detail.teamA,
      teamB: detail.teamB,
      bat: dualKey(emitBat(batAcc)),
      bowl: dualKey(emitBowl(bowlAcc)),
    );
    delta.pending.remove(detail.id);
    return DeltaApplyResult.applied;
  }

  /// Cricket-notation overs (4.2 = 4 overs, 2 balls) -> ball count.
  /// A fractional part that rounds to 6 carries into the next over.
  static int _oversToBalls(double overs) {
    if (overs <= 0) return 0;
    var whole = overs.floor();
    var balls = ((overs - whole) * 10).round();
    if (balls >= 6) {
      whole += 1;
      balls -= 6;
    }
    return whole * 6 + balls;
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
                overNumber: (over['over'] as num?)?.toInt() ?? -1,
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
  /// Provider full names that do NOT match any key exactly are
  /// resolved by [_resolveName] (Squad DATA v6): normalised exact
  /// match, token-set equality ("Muhammad Waseem" ->
  /// "Waseem Muhammad"), then last-name + first-initial + middle
  /// tokens ("Rahul Chopra" -> "R Chopra", "Max O'Dowd" ->
  /// "MP O'Dowd", "Bas de Leede" -> "B de Leede"), with team
  /// disambiguation when [resolveShortNameForTeam] is used.
  /// Returns null when unknown. The last-name fallback stays
  /// restricted to [_identities] — over 8,331 names it would
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
    // Provider-name resolution over the full key space.
    final resolved = _resolveName(q);
    if (resolved != null) return resolved;
    // Last-name fallback, SINGLE-TOKEN queries only: "Kohli" ->
    // "V Kohli" (identities only). A multi-token query that
    // _resolveName left unresolved is ambiguous or unknown by
    // judgement (e.g. "Arun Sharma" over several Sharmas) and
    // must stay null — falling back here used to return an
    // arbitrary same-last-name identity ("RG Sharma").
    if (!q.contains(' ')) {
      final last = q.toLowerCase();
      for (final e in _identities.entries) {
        if (e.key.toLowerCase().endsWith(last)) return e.key;
      }
    }
    return null;
  }

  /// Resolve a provider name -> Cricsheet short name, requiring the
  /// player to belong to [team] (base-name equality, as in
  /// [_sameTeam]). A name that matches only another team's player
  /// returns null — a wrong-team player is never returned. Use this
  /// whenever the calling context knows the player's team (squad
  /// members, XI lookups); [resolveShortName] without a team
  /// returns null for ambiguous names instead of guessing.
  String? resolveShortNameForTeam(String query, String team) {
    final q = query.trim();
    if (q.isEmpty) return null;
    if (_identities.containsKey(q)) {
      final t = _teamOf(q);
      if (t.isEmpty || _sameTeam(t, team)) return q;
      return null;
    }
    for (final e in _identities.entries) {
      if (e.value.id == q ||
          e.value.displayName.toLowerCase() == q.toLowerCase()) {
        final t = _teamOf(e.key);
        if (t.isEmpty || _sameTeam(t, team)) return e.key;
        return null;
      }
    }
    return _resolveName(q, team: team);
  }

  /// Normalised name form for resolution: lowercase, apostrophes /
  /// periods removed, hyphens split, whitespace collapsed.
  /// "O'Dowd" -> "odowd" on both sides, so provider and Cricsheet
  /// spellings compare equal.
  static String _normName(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r"[’'.]"), '')
      .replaceAll('-', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static bool _tokensEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Provider-name -> Cricsheet key over the union of aggregate
  /// keys and sample short names. Steps, in order:
  /// 1. normalised exact match;
  /// 2. token-multiset equality (handles swapped token order);
  /// 3. last token + first initial + middle tokens equal.
  /// With [team] given, candidates from other teams are dropped;
  /// if none remain, null (never a wrong-team player). Without a
  /// team, more than one candidate is ambiguous -> null. With a
  /// team and several same-team candidates, the tie-break is:
  /// shortest first token ("B de Leede" over "BFW de Leede" for
  /// "Bas de Leede"), then most career matches, then name.
  /// Trailing parentheticals ("(c)", "(wk)") are ignored.
  String? _resolveName(String query, {String? team}) {
    final cleaned =
        query.replaceAll(RegExp(r'\s*\([^)]*\)'), ' ').trim();
    if (cleaned.isEmpty) return null;
    final idx = _nameIndex;
    final nq = _normName(cleaned);
    if (nq.isEmpty) return null;
    String? teamOf(String key) => idx.teamByKey[key];
    bool teamOk(String key) {
      if (team == null) return true;
      final t = teamOf(key);
      return t != null && t.isNotEmpty && _sameTeam(t, team);
    }

    // 1. Normalised exact match.
    final exact = idx.exact[nq];
    if (exact != null) {
      if (team == null || teamOk(exact)) return exact;
      return null;
    }
    final qt = nq.split(' ');
    if (qt.length < 2) return null;
    final qSorted = [...qt]..sort();
    // 2. Token-multiset equality.
    for (final e in idx.exact.entries) {
      final kt = e.key.split(' ');
      if (kt.length != qt.length) continue;
      final kSorted = [...kt]..sort();
      if (!_tokensEqual(kSorted, qSorted)) continue;
      if (team == null || teamOk(e.value)) return e.value;
      return null;
    }
    // 3. Last token + first initial + middle tokens.
    final last = qt.last;
    final firstInit = qt.first[0];
    final qMid = qt.sublist(1, qt.length - 1)..sort();
    final passing = <_NameCandidate>[];
    for (final c in idx.byLast[last] ?? const <_NameCandidate>[]) {
      final kt = _normName(c.key).split(' ');
      if (kt.length < 2) continue;
      if (kt.first[0] != firstInit) continue;
      final kMid = kt.sublist(1, kt.length - 1)..sort();
      if (!_tokensEqual(kMid, qMid)) continue;
      passing.add(c);
    }
    if (passing.isEmpty) return null;
    if (team != null) {
      final pool =
          passing.where((c) => teamOk(c.key)).toList();
      if (pool.isEmpty) return null;
      if (pool.length == 1) return pool.single.key;
      pool.sort((a, b) {
        final fa = _normName(a.key).split(' ').first.length;
        final fb = _normName(b.key).split(' ').first.length;
        if (fa != fb) return fa.compareTo(fb);
        if (a.matches != b.matches) {
          return b.matches.compareTo(a.matches);
        }
        return a.key.compareTo(b.key);
      });
      return pool.first.key;
    }
    return passing.length == 1 ? passing.single.key : null;
  }

  _NameIndex? _nameIndexCache;
  _NameIndex get _nameIndex => _nameIndexCache ??= _buildNameIndex();

  _NameIndex _buildNameIndex() {
    final exact = <String, String>{};
    final byLast = <String, List<_NameCandidate>>{};
    final teamByKey = <String, String>{};
    void add(String key, String team, int matches) {
      final n = _normName(key);
      if (exact.containsKey(n)) return;
      exact[n] = key;
      teamByKey[key] = team;
      final toks = n.split(' ');
      if (toks.length < 2) return;
      final list = byLast[toks.last] ??= <_NameCandidate>[];
      if (!list.any((c) => c.key == key)) {
        list.add(_NameCandidate(key, team, matches));
      }
    }

    final agg = aggregate;
    if (agg != null) {
      for (final e in agg.players.entries) {
        final batAll = e.value.bat['all'];
        final bowlAll = e.value.bowl['all'];
        final m = batAll != null && batAll.isNotEmpty
            ? batAll[0]
            : (bowlAll != null && bowlAll.isNotEmpty ? bowlAll[0] : 0);
        add(e.key, e.value.team, m);
      }
    }
    for (final s in _index.knownShorts) {
      add(s, _teamOf(s), _index.playerXiMatches[s]?.length ?? 0);
    }
    return _NameIndex(exact, byLast, teamByKey);
  }

  /// Aggregate squad membership for one team: Cricsheet keys of
  /// players whose aggregate team matches [team], ranked by career
  /// XI matches (descending), capped at [limit]. This is the
  /// aggregate-side complement to [squadForTeams] (which ranks
  /// from the sample index): it covers associate teams thinly
  /// represented in the 420-match sample but fully present in the
  /// 9,943-match archive. Callers that need full [Player] objects
  /// map these keys through [playerByShortName].
  List<String> aggregateSquadKeysForTeam(String team, {int limit = 50}) {
    final agg = aggregate;
    if (agg == null) return const [];
    final keys = agg.players.entries
        .where((e) => _sameTeam(e.value.team, team))
        .toList();
    keys.sort((a, b) {
      final am = a.value.bat['all'];
      final bm = b.value.bat['all'];
      final av = am != null && am.isNotEmpty ? am[0] : 0;
      final bv = bm != null && bm.isNotEmpty ? bm[0] : 0;
      if (av != bv) return bv.compareTo(av);
      return a.key.compareTo(b.key);
    });
    return keys.take(limit).map((e) => e.key).toList();
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

  // ---- Aggregate + delta scope conversion (Squad D) ---------------

  /// Aggregate bat array [matches, innings, runs, balls, fours,
  /// sixes, dismissals, fifties, hundreds, highest] -> BattingStats.
  /// Average = runs / dismissals; never dismissed with innings =
  /// runs (mirrors the sample index's convention), never a fake 0.
  static BattingStats _battingFromBatScope(List<int> a) {
    int at(int i) => i < a.length ? a[i] : 0;
    final runs = at(2);
    final balls = at(3);
    final dismissals = at(6);
    return BattingStats(
      matches: at(0),
      innings: at(1),
      runs: runs,
      balls: balls,
      fours: at(4),
      sixes: at(5),
      fifties: at(7),
      hundreds: at(8),
      average: dismissals > 0
          ? runs / dismissals
          : (at(1) > 0 ? runs.toDouble() : 0),
      strikeRate: balls > 0 ? runs * 100 / balls : 0,
      highest: at(9),
    );
  }

  /// Aggregate bowl array [matches, innings, wickets, balls,
  /// runsConceded, fiveWickets, bestWkts, bestRuns] -> BowlingStats.
  static BowlingStats _bowlingFromBowlScope(List<int> a) {
    int at(int i) => i < a.length ? a[i] : 0;
    final wkts = at(2);
    final balls = at(3);
    final rc = at(4);
    return BowlingStats(
      matches: at(0),
      innings: at(1),
      wickets: wkts,
      balls: balls,
      runsConceded: rc,
      economy: balls > 0 ? rc * 6 / balls : 0,
      average: wkts > 0 ? rc / wkts : 0,
      strikeRate: wkts > 0 ? balls / wkts : 0,
      fiveWickets: at(5),
      best: wkts > 0 ? '${at(6)}/${at(7)}' : '-',
    );
  }

  /// Merge two bowling blocks (base + delta). Best = more wickets,
  /// tie -> fewer runs; '-' never beats a real figure.
  static BowlingStats _mergeBowling(BowlingStats a, BowlingStats b) {
    var best = a.best;
    if (b.best != '-' && b.best.isNotEmpty) {
      if (a.best == '-' || a.best.isEmpty) {
        best = b.best;
      } else {
        final aw = int.tryParse(a.best.split('/').first) ?? 0;
        final bw = int.tryParse(b.best.split('/').first) ?? 0;
        final ar = int.tryParse(a.best.split('/').last) ?? 0;
        final br = int.tryParse(b.best.split('/').last) ?? 0;
        if (bw > aw || (bw == aw && br < ar)) best = b.best;
      }
    }
    final balls = a.balls + b.balls;
    final rc = a.runsConceded + b.runsConceded;
    final wkts = a.wickets + b.wickets;
    return BowlingStats(
      matches: a.matches + b.matches,
      innings: a.innings + b.innings,
      wickets: wkts,
      balls: balls,
      runsConceded: rc,
      economy: balls > 0 ? rc * 6 / balls : 0,
      average: wkts > 0 ? rc / wkts : 0,
      strikeRate: wkts > 0 ? balls / wkts : 0,
      fiveWickets: a.fiveWickets + b.fiveWickets,
      best: best,
    );
  }

  /// Delta lookup key for a short name: the short itself, else the
  /// identity display name (scorecards use full names), else null.
  /// Only ONE key is ever used, so dual-key storage at apply time
  /// can never double-count.
  String? _deltaKeyFor(String shortName) {
    if (delta.matches.values
        .any((m) => m.bat.containsKey(shortName) || m.bowl.containsKey(shortName))) {
      return shortName;
    }
    final display = _identityFor(shortName)?.displayName;
    if (display != null &&
        delta.matches.values.any(
            (m) => m.bat.containsKey(display) || m.bowl.containsKey(display))) {
      return display;
    }
    return null;
  }

  bool _deltaHasPlayer(String shortName) => _deltaKeyFor(shortName) != null;

  /// Delta scopes summed across all delta matches for one player:
  /// {scope -> bat array} and {scope -> bowl array}. Empty when the
  /// player has no delta matches. Sums are over DISTINCT match ids
  /// (delta.matches is keyed by id), so a repeated finish event
  /// can never inflate them — dedupe lives in apply, not here.
  ({Map<String, List<int>> bat, Map<String, List<int>> bowl})
      _deltaScopesFor(String shortName) {
    final key = _deltaKeyFor(shortName);
    final bat = <String, List<int>>{};
    final bowl = <String, List<int>>{};
    if (key == null) return (bat: bat, bowl: bowl);
    void add(Map<String, List<int>> acc, String scope, List<int> arr) {
      final cur = acc[scope];
      if (cur == null) {
        acc[scope] = List<int>.of(arr);
        return;
      }
      for (var i = 0; i < arr.length && i < cur.length; i++) {
        // Index 9 (highest) / bowl best indices are maxima, not sums.
        if (i == 9) {
          if (arr[i] > cur[i]) cur[i] = arr[i];
        } else {
          cur[i] += arr[i];
        }
      }
    }

    for (final m in delta.matches.values) {
      final b = m.bat[key];
      if (b != null) {
        for (final e in b.entries) {
          add(bat, e.key, e.value);
        }
      }
      final w = m.bowl[key];
      if (w != null) {
        for (final e in w.entries) {
          add(bowl, e.key, e.value);
        }
      }
    }
    // Bowling best (indices 6/7) cannot be summed: recompute from
    // per-match best figures is impossible from sums alone, so the
    // merged best below is derived in [_mergeDeltaBowling] from
    // per-match entries, not from these sums. To keep this helper
    // honest, bowl sums carry bestWkts/bestRuns as maxima.
    for (final e in bowl.entries) {
      // Recompute maxima across matches for indices 6/7.
      var bw = 0;
      var br = 0;
      for (final m in delta.matches.values) {
        final arr = m.bowl[key]?[e.key];
        if (arr == null || arr.length < 8) continue;
        if (arr[6] > bw || (arr[6] == bw && arr[7] < br)) {
          bw = arr[6];
          br = arr[7];
        }
      }
      if (e.value.length >= 8) {
        e.value[6] = bw;
        e.value[7] = br;
      }
    }
    return (bat: bat, bowl: bowl);
  }

  /// Delta matches a player appeared in (batted or bowled), for
  /// [Player.sourceMatches] when aggregates are present.
  int _deltaMatchCountFor(String shortName) {
    final key = _deltaKeyFor(shortName);
    if (key == null) return 0;
    var n = 0;
    for (final m in delta.matches.values) {
      if (m.bat.containsKey(key) || m.bowl.containsKey(key)) n += 1;
    }
    return n;
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
    // Provider names reach this entry point too (scorecard XI
    // rows, squad builders): resolve them to the Cricsheet key
    // first, so a provider name never silently yields null while
    // the player is in the data. Already-short names resolve to
    // themselves, so resolved lookups are unaffected.
    shortName = resolveShortName(shortName) ?? shortName;
    final idx = _index;
    final aggPlayer = aggregate?.players[shortName];
    final inSample = idx.knownShorts.contains(shortName);
    // A player known ONLY via the full archive or via delta is
    // still real — the old sample-only gate returned null for
    // ~8,000 archive players. Absent everywhere -> null, never fake.
    if (!inSample && aggPlayer == null && !_deltaHasPlayer(shortName)) {
      return null;
    }
    final ident = _identityFor(shortName);
    final team = inSample ? _teamOf(shortName) : (aggPlayer?.team ?? '');

    final battingByFormat = <String, BattingStats>{};
    final bowlingByFormat = <String, BowlingStats>{};
    final battingVsOpponent = <String, BattingStats>{};
    final bowlingVsOpponent = <String, BowlingStats>{};
    final battingByVenue = <String, BattingStats>{};
    final battingByLeague = <String, BattingStats>{};

    if (aggPlayer != null) {
      // FULL ARCHIVE base: replaces sample scopes for this player
      // (the archive is a superset of the sample — summing both
      // would double-count every sampled match).
      for (final fmt in ['Test', 'ODI', 'T20', 'T10']) {
        final bat = aggPlayer.bat['fmt:$fmt'];
        if (bat != null) battingByFormat[fmt] = _battingFromBatScope(bat);
        final bowl = aggPlayer.bowl['fmt:$fmt'];
        if (bowl != null) {
          bowlingByFormat[fmt] = _bowlingFromBowlScope(bowl);
        }
      }
      for (final e in aggPlayer.bat.entries) {
        if (e.key.startsWith('opp:')) {
          battingVsOpponent[e.key.substring(4)] = _battingFromBatScope(e.value);
        } else if (e.key.startsWith('ven:')) {
          battingByVenue[e.key.substring(4)] = _battingFromBatScope(e.value);
        } else if (e.key.startsWith('lg:')) {
          battingByLeague[e.key.substring(3)] = _battingFromBatScope(e.value);
        }
      }
      for (final e in aggPlayer.bowl.entries) {
        if (e.key.startsWith('opp:')) {
          bowlingVsOpponent[e.key.substring(4)] =
              _bowlingFromBowlScope(e.value);
        }
      }
    } else if (inSample) {
      // SAMPLE fallback (unchanged logic): only when the player
      // has no full-archive aggregate at all.
      final batMap = idx.bat[shortName] ?? {};
      final bowlMap = idx.bowl[shortName] ?? {};
      for (final fmt in ['Test', 'ODI', 'T20', 'T10']) {
        final bat = batMap['fmt:$fmt'];
        if (bat != null &&
            (bat.innings.isNotEmpty || bat.matches.isNotEmpty)) {
          battingByFormat[fmt] = _battingFromAgg(bat);
        }
        final bowl = bowlMap['fmt:$fmt'];
        if (bowl != null && bowl.innings.isNotEmpty) {
          bowlingByFormat[fmt] = _bowlingFromAgg(bowl);
        }
      }
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
      for (final venue in idx.venues) {
        if (venue.isEmpty) continue;
        final bat = batMap['ven:$venue'];
        if (bat != null && bat.innings.isNotEmpty) {
          battingByVenue[venue] = _battingFromAgg(bat);
        }
      }
      for (final league in idx.leagues) {
        final bat = batMap['lg:$league'];
        if (bat != null && bat.innings.isNotEmpty) {
          battingByLeague[league] = _battingFromAgg(bat);
        }
      }
    }

    // DELTA on top of whichever base (aggregate or sample):
    // finished matches since the base was generated. Pure addition
    // of per-scope blocks — re-running it recomputes the same
    // totals, so it can never double-count.
    final dScopes = _deltaScopesFor(shortName);
    for (final e in dScopes.bat.entries) {
      final s = _battingFromBatScope(e.value);
      if (e.key.startsWith('fmt:')) {
        final f = e.key.substring(4);
        battingByFormat[f] = battingByFormat.containsKey(f)
            ? battingByFormat[f]! + s
            : s;
      } else if (e.key.startsWith('opp:')) {
        final o = e.key.substring(4);
        battingVsOpponent[o] = battingVsOpponent.containsKey(o)
            ? battingVsOpponent[o]! + s
            : s;
      } else if (e.key.startsWith('ven:')) {
        final v = e.key.substring(4);
        battingByVenue[v] = battingByVenue.containsKey(v)
            ? battingByVenue[v]! + s
            : s;
      } else if (e.key.startsWith('lg:')) {
        final l = e.key.substring(3);
        battingByLeague[l] = battingByLeague.containsKey(l)
            ? battingByLeague[l]! + s
            : s;
      }
    }
    for (final e in dScopes.bowl.entries) {
      final s = _bowlingFromBowlScope(e.value);
      if (e.key.startsWith('fmt:')) {
        final f = e.key.substring(4);
        bowlingByFormat[f] = bowlingByFormat.containsKey(f)
            ? _mergeBowling(bowlingByFormat[f]!, s)
            : s;
      } else if (e.key.startsWith('opp:')) {
        final o = e.key.substring(4);
        bowlingVsOpponent[o] = bowlingVsOpponent.containsKey(o)
            ? _mergeBowling(bowlingVsOpponent[o]!, s)
            : s;
      }
    }

    // Role: curated when known, otherwise inferred from what the
    // player actually did in the data — never guessed from a name.
    String role;
    if (ident != null) {
      role = ident.role;
    } else {
      final batted = battingByFormat.values
          .any((s) => s.balls > 0 || s.innings > 0);
      final bowled =
          bowlingByFormat.values.any((s) => s.balls > 0);
      role = bowled && batted
          ? 'All-rounder'
          : bowled
              ? 'Bowler'
              : 'Batter';
    }

    final baseMatches = aggPlayer != null
        ? (aggPlayer.bat['all']?.firstOrNull ?? 0)
        : (idx.playerXiMatches[shortName]?.length ?? 0);
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
      sourceMatches: baseMatches + _deltaMatchCountFor(shortName),
    );
  }

  /// Bowler-vs-batter matchup: balls / runs / bowler-credited
  /// dismissals for one pair across all loaded matches.
  /// Full-archive pair first (superset of the sample), then sample.
  Matchup matchup(
      {required String bowler, required String batter}) {
    final bowlerShort = resolveShortName(bowler) ?? bowler;
    final batterShort = resolveShortName(batter) ?? batter;
    final aggPair =
        aggregate?.players[bowlerShort]?.pairs[batterShort];
    if (aggPair != null && aggPair.length >= 4) {
      return Matchup(
        bowlerId: _identities[bowlerShort]?.id ??
            'cs-${bowlerShort.replaceAll(' ', '_')}',
        bowlerName:
            _identities[bowlerShort]?.displayName ?? bowlerShort,
        batterId: _identities[batterShort]?.id ??
            'cs-${batterShort.replaceAll(' ', '_')}',
        batterName:
            _identities[batterShort]?.displayName ?? batterShort,
        matches: aggPair[0],
        balls: aggPair[1],
        runs: aggPair[2],
        dismissals: aggPair[3],
      );
    }
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
  /// Full-archive pairs first when any exist for this batter
  /// (pairs live under the BOWLER in the aggregate), else sample.
  List<Matchup> matchupsForBatter(String batter) {
    final batterShort = resolveShortName(batter) ?? batter;
    final agg = aggregate;
    if (agg != null) {
      final out = <Matchup>[];
      for (final e in agg.players.entries) {
        final pair = e.value.pairs[batterShort];
        if (pair != null && pair.length >= 4 && pair[1] > 0) {
          out.add(matchup(bowler: e.key, batter: batterShort));
        }
      }
      if (out.isNotEmpty) {
        out.sort((a, b) => b.balls.compareTo(a.balls));
        return out.take(6).toList();
      }
    }
    final batterShort2 = batterShort;
    final out = <Matchup>[];
    for (final e in _index.pairs.entries) {
      final pair = e.value[batterShort2];
      if (pair != null && pair.balls > 0) {
        out.add(matchup(bowler: e.key, batter: batterShort2));
      }
    }
    out.sort((a, b) => b.balls.compareTo(a.balls));
    return out.take(6).toList();
  }

  /// "c X b Y — N times" lines, plus one "Never dismissed by Z"
  /// line for the bowler with most balls and zero dismissals
  /// (min 12 balls), when one exists.
  /// Full-archive lines first when present for this batter
  /// (wholesale — aggregate and sample lines use different name
  /// forms and must never be mixed for one batter), else sample.
  List<String> dismissalHistoryFor(String batter) {
    final batterShort = resolveShortName(batter) ?? batter;
    final aggPlayer = aggregate?.players[batterShort];
    if (aggPlayer != null && aggPlayer.dis.isNotEmpty) {
      final lines = aggPlayer.dis.entries
          .map((e) => '${e.key} — ${e.value} time${e.value == 1 ? '' : 's'}')
          .toList()
        ..sort();
      String? best;
      var bestBalls = 0;
      for (final e in aggregate!.players.entries) {
        final pair = e.value.pairs[batterShort];
        if (pair != null &&
            pair.length >= 4 &&
            pair[3] == 0 &&
            pair[1] > bestBalls) {
          best = e.key;
          bestBalls = pair[1];
        }
      }
      if (best != null && bestBalls >= 12) {
        final name = _identities[best]?.displayName ?? best;
        lines.add('Not dismissed by $name in $bestBalls balls');
      }
      return lines;
    }
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

  /// Archive team names (from the aggregate players' teams and
  /// the H2H index keys), for mapping a provider team name to its
  /// Cricsheet form. Null when the archive knows no such team.
  Set<String>? _aggregateTeamsCache;
  Set<String> get _aggregateTeams {
    if (_aggregateTeamsCache != null) return _aggregateTeamsCache!;
    final teams = <String>{};
    final agg = aggregate;
    if (agg != null) {
      for (final e in agg.players.values) {
        if (e.team.isNotEmpty) teams.add(e.team);
      }
      for (final k in agg.h2h.keys) {
        final parts = k.split('|');
        if (parts.length >= 2) {
          teams.add(parts[0]);
          teams.add(parts[1]);
        }
      }
    }
    return _aggregateTeamsCache = teams;
  }

  String? _aggregateTeamKey(String teamName) {
    final base = _baseTeamName(teamName);
    final teams = _aggregateTeams;
    if (teams.contains(base)) return base;
    for (final t in teams) {
      if (_sameTeam(t, base)) return t;
    }
    return null;
  }

  /// Team H2H: {matches, teamAWins, teamBWins, noResult}.
  /// Optional [format] restricts to one format ('ODI', 'T20',
  /// ...). Optional [gender] restricts to men's / women's
  /// meetings — pass it whenever the calling match knows its
  /// gender, otherwise men's and women's meetings are pooled
  /// (legacy behaviour, kept for callers without match context).
  /// AGGREGATE FIRST (Squad DATA v6): the full-archive H2H index
  /// answers from 9,943 matches; the old sample loop (420
  /// matches) runs only when the index has no entry — e.g. a team
  /// the archive does not know, or a meeting newer than the base.
  /// Aggregate and sample are NEVER summed (the archive is the
  /// sample's superset).
  Map<String, int> teamH2H(String teamA, String teamB,
      {String? format, String? gender}) {
    final agg = aggregate;
    if (agg != null && agg.h2h.isNotEmpty) {
      final a = _aggregateTeamKey(teamA);
      final b = _aggregateTeamKey(teamB);
      if (a != null && b != null) {
        final sorted = [a, b]..sort();
        final fmt = format == null ? 'ALL' : normalizeFormat(format);
        final gen = gender ?? 'ALL';
        final v = agg.h2h['${sorted[0]}|${sorted[1]}|$fmt|$gen'];
        if (v != null && v.length >= 4) {
          // Index wins are stored for the sorted-first team.
          final aIsFirst = _sameTeam(a, sorted[0]);
          return {
            'matches': v[0],
            'teamAWins': aIsFirst ? v[1] : v[2],
            'teamBWins': aIsFirst ? v[2] : v[1],
            'noResult': v[3],
          };
        }
        // Key missing: fall through to the sample loop, which can
        // still catch meetings newer than the archive base.
      }
    }
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

  /// Best aggregate venue entry for [venueName]: exact match
  /// first, else the highest Jaccard token overlap over the venue
  /// index (>= 0.5; ties break by more matches, then name).
  /// Jaccard (not the sample's containment rule) is used so
  /// "ICC Academy Ground, Dubai" matches "ICC Academy, Dubai"
  /// (3/4) ahead of "ICC Academy Ground No 2, Dubai" (4/6) —
  /// the No 2 ground is a different ground, not the same venue.
  /// Returns the venue key + entry, or null when nothing matches.
  MapEntry<String, CricsheetAggVenue>? _findAggregateVenue(
      String venueName) {
    final agg = aggregate;
    if (agg == null || agg.venues.isEmpty) return null;
    if (agg.venues.containsKey(venueName)) {
      return MapEntry(venueName, agg.venues[venueName]!);
    }
    final qNorm = _normVenue(venueName);
    if (qNorm.isEmpty) return null;
    for (final e in agg.venues.entries) {
      if (_normVenue(e.key) == qNorm) return e;
    }
    final qToks = qNorm.split(' ').toSet();
    MapEntry<String, CricsheetAggVenue>? best;
    var bestScore = 0.0;
    var bestMatches = -1;
    for (final e in agg.venues.entries) {
      final vToks = _normVenue(e.key).split(' ').toSet();
      final inter = qToks.intersection(vToks).length;
      final union = qToks.union(vToks).length;
      if (union == 0) continue;
      final score = inter / union;
      if (score < 0.5) continue;
      if (score > bestScore ||
          (score == bestScore && e.value.matches > bestMatches)) {
        best = e;
        bestScore = score;
        bestMatches = e.value.matches;
      }
    }
    return best;
  }

  /// Venue stats computed from bundled matches at [venueName]
  /// (fuzzy match: "Rawalpindi Cricket Stadium, Rawalpindi" matches
  /// the dataset's "Rawalpindi Cricket Stadium"). Null when no
  /// bundled match was played there. Pitch / weather are NOT in
  /// Cricsheet — the Venue tab keeps "Not available from free
  /// providers yet" for those, never faked.
  /// AGGREGATE FIRST (Squad DATA v6): the full-archive venue
  /// index answers from 9,943 matches (the old sample loop said
  /// "Matches at venue 1" for grounds with dozens of archive
  /// matches). The sample loop runs only when the index has no
  /// entry. Aggregate and sample are NEVER summed.
  VenueStats? venueStats(String venueName, {String? gender}) {
    final agg = aggregate;
    if (agg != null && agg.venues.isNotEmpty) {
      final found = _findAggregateVenue(venueName);
      if (found != null) {
        final entry = found.value;
        final totals =
            gender != null ? entry.byGender[gender] : null;
        if (gender == null || totals != null) {
          final t = totals ?? entry;
          return VenueStats(
            venue: entry.venue,
            city: entry.city,
            matches: t.matches,
            avgFirstInnings: t.avgFirst,
            avgSecondInnings: t.avgSecond,
            highestTotal: t.highest,
            batFirstWinPct: t.batFirstWinPct,
          );
        }
        // Venue exists only for the other gender: fall through to
        // the sample loop, which can only add newer meetings.
      }
    }
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

  /// One player's record AT one venue, for the Venue tab's
  /// "players at this venue" section (Squad DATA v6 — the service
  /// method; the tab UI belongs to another squad). Batting and
  /// bowling lines keep SEPARATE match counts (a player may bat
  /// without bowling at a venue and vice versa); nothing is
  /// averaged across the two. Base = full-archive ven: scope for
  /// the resolved venue key; finished-match deltas dated after
  /// the base add their ven: scopes on top (same base+delta rule
  /// as profiles — deltas are never part of the base, so adding
  /// them cannot double-count). Null when the player has no
  /// innings at the venue in either source, or when the player /
  /// venue cannot be resolved — never zero-filled. The venue
  /// scope pick is exact-then-fuzzy over the player's OWN
  /// ven: scopes (base and delta alike), because per-match
  /// Cricsheet venue strings ("ICC Academy") need not equal the
  /// venue-index key ("ICC Academy, Dubai").
  PlayerVenueStats? playerVenueStats(String player, String venue,
      {String? team}) {
    final short = team == null
        ? resolveShortName(player)
        : resolveShortNameForTeam(player, team);
    if (short == null) return null;
    final found = _findAggregateVenue(venue);
    if (found == null) return null;
    final venueKey = found.key;
    final aggPlayer = aggregate?.players[short];
    // Per-player ven: scopes use the Cricsheet venue string of
    // each match, which need not equal the venue-index key: the
    // index key "ICC Academy, Dubai" and a player's scope
    // "ven:ICC Academy" are the same ground. So the pick is exact
    // first, then the best Jaccard match (>= 0.5) over THAT
    // PLAYER's own ven: scopes — never a global venue merge.
    List<int>? pick(Map<String, List<int>> scopes) {
      final exact = scopes['ven:$venueKey'];
      if (exact != null) return exact;
      String? bestKey;
      var bestScore = 0.0;
      final qToks = _normVenue(venueKey).split(' ').toSet();
      for (final k in scopes.keys) {
        if (!k.startsWith('ven:')) continue;
        final vToks = _normVenue(k.substring(4)).split(' ').toSet();
        final inter = qToks.intersection(vToks).length;
        final union = qToks.union(vToks).length;
        if (union == 0) continue;
        final score = inter / union;
        if (score >= 0.5 && score > bestScore) {
          bestScore = score;
          bestKey = k;
        }
      }
      return bestKey == null ? null : scopes[bestKey];
    }

    List<int>? bat =
        aggPlayer == null ? null : pick(aggPlayer.bat);
    List<int>? bowl =
        aggPlayer == null ? null : pick(aggPlayer.bowl);
    final d = _deltaScopesFor(short);
    final dBat = pick(d.bat);
    final dBowl = pick(d.bowl);
    List<int>? add(List<int>? a, List<int>? b) {
      if (a == null) return b;
      if (b == null) return a;
      final out = List<int>.of(a);
      for (var i = 0; i < b.length && i < out.length; i++) {
        if (i == 9) {
          if (b[i] > out[i]) out[i] = b[i];
        } else {
          out[i] += b[i];
        }
      }
      return out;
    }

    bat = add(bat, dBat);
    bowl = add(bowl, dBowl);
    if (bat == null && bowl == null) return null;
    int at(List<int>? a, int i) =>
        a != null && i < a.length ? a[i] : 0;
    final runs = at(bat, 2);
    final balls = at(bat, 3);
    final dismissals = at(bat, 6);
    final wkts = at(bowl, 2);
    final bowlBalls = at(bowl, 3);
    final rc = at(bowl, 4);
    return PlayerVenueStats(
      shortName: short,
      team: aggPlayer?.team ?? _teamOf(short),
      battingMatches: at(bat, 0),
      runs: runs,
      balls: balls,
      average: dismissals > 0
          ? runs / dismissals
          : (at(bat, 1) > 0 ? runs.toDouble() : 0),
      strikeRate: balls > 0 ? runs * 100 / balls : 0,
      bowlingMatches: at(bowl, 0),
      wickets: wkts,
      economy: bowlBalls > 0 ? rc * 6 / bowlBalls : 0,
    );
  }

  /// Venue records for a list of players (e.g. one team's squad
  /// members). Unresolvable players and players with no innings
  /// at the venue are skipped silently — the caller renders only
  /// returned rows, never invented ones. Pass [team] when all
  /// names belong to one team (wrong-team lookalikes are then
  /// excluded by [resolveShortNameForTeam]).
  List<PlayerVenueStats> venuePlayers(List<String> players,
      String venue,
      {String? team}) {
    final out = <PlayerVenueStats>[];
    for (final p in players) {
      final s = playerVenueStats(p, venue, team: team);
      if (s != null) out.add(s);
    }
    return out;
  }

  /// Top batters / bowlers at a venue from the aggregate venue
  /// index (all-gender top 10s, truncated to [limit]). Empty
  /// when the venue is not in the index. Teams come from the
  /// aggregate players map ('' when the short is unknown there).
  VenueLeaders topPlayersAtVenue(String venue, {int limit = 10}) {
    final found = _findAggregateVenue(venue);
    if (found == null) {
      return const VenueLeaders(batters: [], bowlers: []);
    }
    VenueTopPlayer toPlayer(VenueTopEntry e, bool batting) =>
        VenueTopPlayer(
          shortName: e.short,
          team: aggregate?.players[e.short]?.team ?? '',
          runs: batting ? e.value : 0,
          wickets: batting ? 0 : e.value,
          matches: e.matches,
        );
    return VenueLeaders(
      batters: found.value.topBatters
          .take(limit)
          .map((e) => toPlayer(e, true))
          .toList(),
      bowlers: found.value.topBowlers
          .take(limit)
          .map((e) => toPlayer(e, false))
          .toList(),
    );
  }

  /// Ball-level data for ONE bundled match between [teamA] and
  /// [teamB], for visual-live widgets (ball-outcome strip, over
  /// summaries). Everything is DERIVED from the bundled match's
  /// real deliveries — grouping by the source over number, never
  /// reconstructed from totals, and never synthesised.
  ///
  /// Matching is strict so a widget can never show another
  /// match's balls as this match's: with [date] given, only a
  /// bundled match on the same UTC calendar day qualifies, and if
  /// MORE than one qualifies (e.g. a men+women double-header) the
  /// result is EMPTY — ambiguous beats wrong. Without [date], the
  /// latest meeting is used and labelled with its date. No match
  /// -> empty [MatchBallData] with [MatchBallData.hasBallData]
  /// false; callers render an honest no-data state, never a strip
  /// of invented balls. [format] uses the same normalisation as
  /// [teamH2H] (IT20 -> T20, ODM -> ODI).
  MatchBallData ballDataForTeams(String teamA, String teamB,
      {String? format, DateTime? date}) {
    const empty = MatchBallData.empty(source: 'cricsheet');
    final fmt = format == null ? null : normalizeFormat(format);
    final candidates = matches.where((m) {
      if (fmt != null && m.format != fmt) return false;
      return m.teams.any((t) => _sameTeam(t, teamA)) &&
          m.teams.any((t) => _sameTeam(t, teamB));
    }).toList();
    if (candidates.isEmpty) return empty;
    CricsheetMatch? picked;
    if (date != null) {
      final d = date.toUtc();
      final day =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final onDay = candidates.where((m) => m.date == day).toList();
      if (onDay.length != 1) return empty;
      picked = onDay.single;
    } else {
      candidates.sort((a, b) => b.date.compareTo(a.date));
      picked = candidates.first;
    }
    return MatchBallData.fromDeliveries(
      teamA: teamA,
      teamB: teamB,
      format: picked.format,
      matchDate: picked.date,
      source: 'cricsheet',
      deliveries: picked.deliveries,
    );
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

/// FULL-ARCHIVE aggregate player (Squad D): compact totals from
/// tools/aggregate_cricsheet.py. Scope arrays mirror the script:
/// bat [matches, innings, runs, balls, fours, sixes, dismissals,
/// fifties, hundreds, highest]; bowl [matches, innings, wickets,
/// balls, runsConceded, fiveWickets, bestWkts, bestRuns].
/// Scope keys: "all", "fmt:<fmt>", "opp:<team>", "ven:<venue>",
/// "lg:<league>". Pairs live under the BOWLER: {batterShort:
/// [matches, balls, runs, dismissals]} (balls >= 12 only — one-off
/// pairs are noise; totals are unaffected).
class CricsheetAggPlayer {
  final String team;
  final Map<String, List<int>> bat;
  final Map<String, List<int>> bowl;
  final Map<String, int> dis;
  final Map<String, List<int>> pairs;

  const CricsheetAggPlayer({
    required this.team,
    required this.bat,
    required this.bowl,
    required this.dis,
    required this.pairs,
  });

  factory CricsheetAggPlayer.fromJson(Map<String, dynamic> j) {
    Map<String, List<int>> scopes(Object? v) {
      final out = <String, List<int>>{};
      if (v is Map) {
        for (final e in v.entries) {
          final l = e.value;
          if (l is List) {
            out['${e.key}'] =
                l.map((x) => (x as num?)?.toInt() ?? 0).toList();
          }
        }
      }
      return out;
    }

    final dis = <String, int>{};
    final d = j['dis'];
    if (d is Map) {
      for (final e in d.entries) {
        dis['${e.key}'] = (e.value as num?)?.toInt() ?? 0;
      }
    }
    return CricsheetAggPlayer(
      team: '${j['team'] ?? ''}',
      bat: scopes(j['bat']),
      bowl: scopes(j['bowl']),
      dis: dis,
      pairs: scopes(j['pairs']),
    );
  }
}

/// Venue totals from the full-archive venue index
/// (tools/aggregate_cricsheet.py). Same definitions as the sample
/// [VenueStats]: innings totals summed from deliveries, bat-first
/// win = winner == first-innings batting team.
class CricsheetAggVenueTotals {
  final int matches;
  final double avgFirst;
  final double avgSecond;
  final int highest;
  final double batFirstWinPct;
  const CricsheetAggVenueTotals({
    required this.matches,
    required this.avgFirst,
    required this.avgSecond,
    required this.highest,
    required this.batFirstWinPct,
  });

  factory CricsheetAggVenueTotals.fromJson(Map<String, dynamic> j) {
    double d(Object? v) => (v as num?)?.toDouble() ?? 0;
    int i(Object? v) => (v as num?)?.toInt() ?? 0;
    return CricsheetAggVenueTotals(
      matches: i(j['matches']),
      avgFirst: d(j['avgFirst']),
      avgSecond: d(j['avgSecond']),
      highest: i(j['highest']),
      batFirstWinPct: d(j['batFirstWinPct']),
    );
  }
}

/// One top-player line from the venue index: [short, value, matches]
/// where value is runs (batters) or wickets (bowlers).
class VenueTopEntry {
  final String short;
  final int value;
  final int matches;
  const VenueTopEntry({
    required this.short,
    required this.value,
    required this.matches,
  });
}

/// One venue from the full-archive venue index. Totals are
/// all-gender; [byGender] carries the male/female totals splits
/// when the venue hosted that gender. Top players are all-gender
/// (player ven: scopes carry no gender split).
class CricsheetAggVenue extends CricsheetAggVenueTotals {
  final String venue;
  final String city;
  final List<VenueTopEntry> topBatters;
  final List<VenueTopEntry> topBowlers;
  final Map<String, CricsheetAggVenueTotals> byGender;
  const CricsheetAggVenue({
    required this.venue,
    required this.city,
    required super.matches,
    required super.avgFirst,
    required super.avgSecond,
    required super.highest,
    required super.batFirstWinPct,
    required this.topBatters,
    required this.topBowlers,
    required this.byGender,
  });

  factory CricsheetAggVenue.fromJson(String venue, Map<String, dynamic> j) {
    List<VenueTopEntry> tops(Object? v) {
      final out = <VenueTopEntry>[];
      if (v is List) {
        for (final e in v) {
          if (e is List && e.length >= 3) {
            out.add(VenueTopEntry(
              short: '${e[0]}',
              value: (e[1] as num?)?.toInt() ?? 0,
              matches: (e[2] as num?)?.toInt() ?? 0,
            ));
          }
        }
      }
      return out;
    }

    final byGender = <String, CricsheetAggVenueTotals>{};
    final bg = j['byGender'];
    if (bg is Map) {
      for (final e in bg.entries) {
        if (e.value is Map<String, dynamic>) {
          byGender['${e.key}'] =
              CricsheetAggVenueTotals.fromJson(e.value);
        }
      }
    }
    final t = CricsheetAggVenueTotals.fromJson(j);
    return CricsheetAggVenue(
      venue: venue,
      city: '${j['city'] ?? ''}',
      matches: t.matches,
      avgFirst: t.avgFirst,
      avgSecond: t.avgSecond,
      highest: t.highest,
      batFirstWinPct: t.batFirstWinPct,
      topBatters: tops(j['topBatters']),
      topBowlers: tops(j['topBowlers']),
      byGender: byGender,
    );
  }
}

/// FULL-ARCHIVE aggregate document (assets/cricsheet_stats.json).
/// Never throws on parse: malformed input yields an empty aggregate
/// and callers fall back to the sample.
class CricsheetAggregate {
  final int matchCount;
  final String yearMin;
  final String yearMax;

  /// Latest match date in the base (yyyy-mm-dd). Delta pruning
  /// drops finished-match deltas dated <= this: a regenerated base
  /// already contains them.
  final String coverageEnd;
  final Map<String, CricsheetAggPlayer> players;

  /// H2H index (tools/aggregate_cricsheet.py): key
  /// "teamA|teamB|fmt|gender" with teamA/teamB SORTED
  /// alphabetically, so value[1] is always the sorted-first
  /// team's wins. Value: [matches, firstWins, secondWins,
  /// noResult]. fmt is Test/ODI/T20/T10 or ALL; gender is
  /// male/female or ALL. Empty when the asset predates the index.
  final Map<String, List<int>> h2h;

  /// Venue index (tools/aggregate_cricsheet.py): venue string ->
  /// entry. Empty when the asset predates the index.
  final Map<String, CricsheetAggVenue> venues;

  const CricsheetAggregate({
    required this.matchCount,
    required this.yearMin,
    required this.yearMax,
    required this.coverageEnd,
    required this.players,
    this.h2h = const {},
    this.venues = const {},
  });

  factory CricsheetAggregate.parse(String jsonText) {
    try {
      final decoded = jsonDecode(jsonText);
      if (decoded is! Map<String, dynamic>) {
        return const CricsheetAggregate(
            matchCount: 0,
            yearMin: '',
            yearMax: '',
            coverageEnd: '',
            players: {});
      }
      final meta = decoded['meta'];
      final metaMap = meta is Map<String, dynamic> ? meta : {};
      final raw = decoded['players'];
      final players = <String, CricsheetAggPlayer>{};
      if (raw is Map) {
        for (final e in raw.entries) {
          if (e.value is Map<String, dynamic>) {
            players['${e.key}'] =
                CricsheetAggPlayer.fromJson(e.value);
          }
        }
      }
      final h2h = <String, List<int>>{};
      final rawH2h = decoded['h2h'];
      if (rawH2h is Map) {
        for (final e in rawH2h.entries) {
          if (e.value is List) {
            // Explicit <int> type argument: through a dynamic
            // receiver, .map().toList() would otherwise produce
            // List<dynamic>, which fails the List<int> check.
            h2h['${e.key}'] = (e.value as List)
                .map<int>((x) => (x as num?)?.toInt() ?? 0)
                .toList();
          }
        }
      }
      final venues = <String, CricsheetAggVenue>{};
      final rawVenues = decoded['venues'];
      if (rawVenues is Map) {
        for (final e in rawVenues.entries) {
          if (e.value is Map<String, dynamic>) {
            venues['${e.key}'] =
                CricsheetAggVenue.fromJson('${e.key}', e.value);
          }
        }
      }
      return CricsheetAggregate(
        matchCount: (metaMap['matches'] as num?)?.toInt() ?? 0,
        yearMin: '${metaMap['yearMin'] ?? ''}',
        yearMax: '${metaMap['yearMax'] ?? ''}',
        coverageEnd: '${metaMap['coverageEnd'] ?? ''}',
        players: players,
        h2h: h2h,
        venues: venues,
      );
    } catch (_) {
      return const CricsheetAggregate(
          matchCount: 0,
          yearMin: '',
          yearMax: '',
          coverageEnd: '',
          players: {});
    }
  }
}

/// Outcome of [CricsheetService.applyFinishedMatch].
enum DeltaApplyResult {
  /// Scorecard converted and counted (caller persists via
  /// [CricsheetService.persistDelta]).
  applied,

  /// This match id was already counted — totals unchanged.
  alreadyProcessed,

  /// No innings in the detail: recorded as pending, never counted,
  /// never faked.
  noScorecard,
}

/// One finished match's delta increments, keyed by player name as
/// it appears in the scorecard (plus the resolved short name when
/// different — see [CricsheetService.applyFinishedMatch]).
/// Scope arrays use the same layout as [CricsheetAggPlayer].
class CricsheetDeltaMatch {
  final String matchId;
  final String date; // yyyy-mm-dd, '' when unknown
  final String format;
  final String venue;
  final String league;
  final String teamA;
  final String teamB;
  final Map<String, Map<String, List<int>>> bat;
  final Map<String, Map<String, List<int>>> bowl;

  const CricsheetDeltaMatch({
    required this.matchId,
    required this.date,
    required this.format,
    required this.venue,
    required this.league,
    required this.teamA,
    required this.teamB,
    required this.bat,
    required this.bowl,
  });

  Map<String, dynamic> toJson() => {
        'matchId': matchId,
        'date': date,
        'format': format,
        'venue': venue,
        'league': league,
        'teamA': teamA,
        'teamB': teamB,
        'bat': bat,
        'bowl': bowl,
      };

  factory CricsheetDeltaMatch.fromJson(Map<String, dynamic> j) {
    Map<String, Map<String, List<int>>> scopes(Object? v) {
      final out = <String, Map<String, List<int>>>{};
      if (v is Map) {
        for (final pe in v.entries) {
          final sm = <String, List<int>>{};
          final sv = pe.value;
          if (sv is Map) {
            for (final se in sv.entries) {
              final l = se.value;
              if (l is List) {
                sm['${se.key}'] =
                    l.map((x) => (x as num?)?.toInt() ?? 0).toList();
              }
            }
          }
          out['${pe.key}'] = sm;
        }
      }
      return out;
    }

    return CricsheetDeltaMatch(
      matchId: '${j['matchId'] ?? ''}',
      date: '${j['date'] ?? ''}',
      format: '${j['format'] ?? ''}',
      venue: '${j['venue'] ?? ''}',
      league: '${j['league'] ?? ''}',
      teamA: '${j['teamA'] ?? ''}',
      teamB: '${j['teamB'] ?? ''}',
      bat: scopes(j['bat']),
      bowl: scopes(j['bowl']),
    );
  }
}

/// The delta store: finished matches since the base asset, keyed by
/// match id (dedupe lives here — one entry per id, ever), plus
/// pending ids (match id -> date first seen, '' when unknown) for
/// finished matches whose scorecard never arrived.
class CricsheetDelta {
  final Map<String, CricsheetDeltaMatch> matches;
  final Map<String, String> pending;

  CricsheetDelta({required this.matches, required this.pending});

  factory CricsheetDelta.empty() =>
      CricsheetDelta(matches: {}, pending: {});

  bool get isEmpty => matches.isEmpty && pending.isEmpty;
  Set<String> get processedIds => matches.keys.toSet();
  Set<String> get pendingIds => pending.keys.toSet();

  Map<String, dynamic> toJson() => {
        'version': 1,
        'matches': matches.map((k, v) => MapEntry(k, v.toJson())),
        'pending': pending,
      };

  factory CricsheetDelta.fromJson(Map<String, dynamic> j) {
    final matches = <String, CricsheetDeltaMatch>{};
    final raw = j['matches'];
    if (raw is Map) {
      for (final e in raw.entries) {
        if (e.value is Map<String, dynamic>) {
          matches['${e.key}'] =
              CricsheetDeltaMatch.fromJson(e.value);
        }
      }
    }
    final pending = <String, String>{};
    final pr = j['pending'];
    if (pr is Map) {
      for (final e in pr.entries) {
        pending['${e.key}'] = '${e.value ?? ''}';
      }
    }
    return CricsheetDelta(matches: matches, pending: pending);
  }
}

/// Per-scope batting accumulator for one delta match.
class _DeltaBatAcc {
  int matches = 0;
  int innings = 0;
  int runs = 0;
  int balls = 0;
  int fours = 0;
  int sixes = 0;
  int dismissals = 0;
  final Map<int, int> innRuns = {};

  List<int> emit() {
    var fifties = 0;
    var hundreds = 0;
    var highest = 0;
    for (final r in innRuns.values) {
      if (r >= 100) {
        hundreds += 1;
      } else if (r >= 50) {
        fifties += 1;
      }
      if (r > highest) highest = r;
    }
    return [
      matches,
      innings,
      runs,
      balls,
      fours,
      sixes,
      dismissals,
      fifties,
      hundreds,
      highest,
    ];
  }
}

/// Per-scope bowling accumulator for one delta match.
class _DeltaBowlAcc {
  int matches = 0;
  int innings = 0;
  int wickets = 0;
  int balls = 0;
  int runs = 0;
  final Map<int, int> innWkts = {};
  final Map<int, int> innRuns = {};

  List<int> emit() {
    var five = 0;
    var bestW = 0;
    var bestR = 0;
    for (final e in innWkts.entries) {
      if (e.value >= 5) five += 1;
      final r = innRuns[e.key] ?? 0;
      if (e.value > bestW || (e.value == bestW && r < bestR)) {
        bestW = e.value;
        bestR = r;
      }
    }
    return [matches, innings, wickets, balls, runs, five, bestW, bestR];
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

/// One player's record at one venue (see [CricsheetService.
/// playerVenueStats]). Batting and bowling match counts are kept
/// separate — a player who only batted (or only bowled) at a venue
/// has 0 on the other line, never a merged count.
class PlayerVenueStats {
  final String shortName;
  final String team;
  final int battingMatches;
  final int runs;
  final int balls;
  final double average;
  final double strikeRate;
  final int bowlingMatches;
  final int wickets;
  final double economy;
  const PlayerVenueStats({
    required this.shortName,
    required this.team,
    required this.battingMatches,
    required this.runs,
    required this.balls,
    required this.average,
    required this.strikeRate,
    required this.bowlingMatches,
    required this.wickets,
    required this.economy,
  });
}

/// One line of a venue leaderboard: runs is set for batters,
/// wickets for bowlers, the other is 0.
class VenueTopPlayer {
  final String shortName;
  final String team;
  final int runs;
  final int wickets;
  final int matches;
  const VenueTopPlayer({
    required this.shortName,
    required this.team,
    required this.runs,
    required this.wickets,
    required this.matches,
  });
}

/// Venue leaderboard pair (see [CricsheetService.topPlayersAtVenue]).
class VenueLeaders {
  final List<VenueTopPlayer> batters;
  final List<VenueTopPlayer> bowlers;
  const VenueLeaders({required this.batters, required this.bowlers});
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

/// One candidate for provider-name resolution: the Cricsheet key,
/// its team (aggregate team, else first sample team), and its
/// career XI-match count (tie-break only).
class _NameCandidate {
  final String key;
  final String team;
  final int matches;
  const _NameCandidate(this.key, this.team, this.matches);
}

/// Lazily built name-resolution index over the union of aggregate
/// keys and sample short names. [exact] maps a normalised name to
/// its key; [byLast] maps a normalised last token to candidates.
class _NameIndex {
  final Map<String, String> exact;
  final Map<String, List<_NameCandidate>> byLast;
  final Map<String, String> teamByKey;
  const _NameIndex(this.exact, this.byLast, this.teamByKey);
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

/// FINAL D — Ball-level data for visual-live widgets. These types
/// carry ONLY what a source actually supplied: a ball outcome per
/// real delivery, grouped into over summaries by the source over
/// number. Nothing here is ever synthesised from totals — a
/// totals-only payload yields an empty [MatchBallData] with
/// [MatchBallData.hasBallData] false, and widgets must render an
/// honest no-data state for it.
///
/// Display [BallOutcome.label]: 'W' when a wicket fell, 'Wd' for a
/// wide, 'Nb' for a no-ball, otherwise the runs digit. The label is
/// a display derivation from the delivery's own fields, not new
/// data: wides/no-balls that also conceded runs still show 'Wd' /
/// 'Nb' (the run count stays in [BallOutcome.runs]).
class BallOutcome {
  final int inningsIndex;
  final int overNumber;
  final int ballIndex;

  /// 1-based position of this delivery within its over, counting
  /// every delivery (wides / no-balls included) in source order.
  final String batter;
  final String bowler;
  final int runs;
  final int batterRuns;
  final bool isWide;
  final bool isNoBall;
  final bool isWicket;
  final String? wicketKind;
  final String? playerOut;

  const BallOutcome({
    required this.inningsIndex,
    required this.overNumber,
    required this.ballIndex,
    required this.batter,
    required this.bowler,
    required this.runs,
    required this.batterRuns,
    this.isWide = false,
    this.isNoBall = false,
    this.isWicket = false,
    this.wicketKind,
    this.playerOut,
  });

  bool get isLegalBall => !isWide && !isNoBall;

  String get label {
    if (isWicket) return 'W';
    if (isWide) return 'Wd';
    if (isNoBall) return 'Nb';
    return '$runs';
  }
}

/// One over's worth of real deliveries, in source order.
class OverSummary {
  final int inningsIndex;
  final int overNumber;
  final String battingTeam;
  final String bowler;
  final List<BallOutcome> balls;

  const OverSummary({
    required this.inningsIndex,
    required this.overNumber,
    required this.battingTeam,
    required this.bowler,
    required this.balls,
  });

  int get runs => balls.fold(0, (acc, b) => acc + b.runs);
  int get wickets => balls.where((b) => b.isWicket).length;
  int get legalBalls => balls.where((b) => b.isLegalBall).length;
}

/// Ball-level data for one match, from one named source.
/// [hasBallData] is false for totals-only payloads — widgets must
/// treat that as "no ball strip", never as an empty innings.
class MatchBallData {
  final String teamA;
  final String teamB;
  final String format;
  final String matchDate;
  final String source;
  final List<OverSummary> overs;

  const MatchBallData({
    this.teamA = '',
    this.teamB = '',
    this.format = '',
    this.matchDate = '',
    this.source = '',
    this.overs = const [],
  });

  const MatchBallData.empty({this.source = ''})
      : teamA = '',
        teamB = '',
        format = '',
        matchDate = '',
        overs = const [];

  bool get hasBallData => overs.any((o) => o.balls.isNotEmpty);

  List<BallOutcome> get balls =>
      overs.expand((o) => o.balls).toList(growable: false);

  List<OverSummary> oversForInnings(int inningsIndex) =>
      overs.where((o) => o.inningsIndex == inningsIndex).toList();

  /// Build from Cricsheet deliveries: group by (innings, source
  /// over number) in first-seen order. Deliveries with an unknown
  /// over number (-1) stay together in one bucket rather than
  /// being split by invented boundaries.
  factory MatchBallData.fromDeliveries({
    required String teamA,
    required String teamB,
    required String format,
    required String matchDate,
    required String source,
    required List<CricsheetDelivery> deliveries,
  }) {
    final grouped = <String, List<CricsheetDelivery>>{};
    final order = <String>[];
    for (final d in deliveries) {
      final key = '${d.inningsIndex}|${d.overNumber}';
      if (!grouped.containsKey(key)) {
        grouped[key] = [];
        order.add(key);
      }
      grouped[key]!.add(d);
    }
    final overs = <OverSummary>[];
    for (final key in order) {
      final ds = grouped[key]!;
      final first = ds.first;
      final balls = <BallOutcome>[];
      for (var i = 0; i < ds.length; i++) {
        final d = ds[i];
        balls.add(BallOutcome(
          inningsIndex: d.inningsIndex,
          overNumber: d.overNumber,
          ballIndex: i + 1,
          batter: d.batter,
          bowler: d.bowler,
          runs: d.totalRuns,
          batterRuns: d.batterRuns,
          isWide: d.isWide,
          isNoBall: d.isNoBall,
          isWicket: d.isWicket,
          wicketKind: d.wicketKind,
          playerOut: d.playerOut,
        ));
      }
      overs.add(OverSummary(
        inningsIndex: first.inningsIndex,
        overNumber: first.overNumber,
        battingTeam: first.battingTeam,
        bowler: first.bowler,
        balls: balls,
      ));
    }
    return MatchBallData(
      teamA: teamA,
      teamB: teamB,
      format: format,
      matchDate: matchDate,
      source: source,
      overs: overs,
    );
  }
}
