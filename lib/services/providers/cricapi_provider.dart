import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../models/innings.dart';
import '../../models/match.dart';
import '../../models/player.dart';
import '../../utils/constants.dart';
import 'cricket_provider.dart';

/// PRIMARY provider: CricAPI / CricketData.org.
/// Base: https://api.cricapi.com/v1 — `?apikey=` query param.
/// Lifetime free tier: 100 hits/day, no card. Covers live scores,
/// ball-by-ball, full scorecards, player profiles, series, squads.
/// Envelope: {"status":"success","info":{...},"data":[...]}.
/// Moved verbatim from the old single-provider ApiService so behaviour
/// is unchanged; the orchestrator now calls this via the interface.
///
/// FIX-7 changes (see FIX7.md):
/// - fetchUpcoming / fetchSeries PAGINATE (offset loop, capped pages)
///   instead of fetching only `offset=0` page 1.
/// - Server-side quota is read from every response's `info` block
///   (`hitsLeft` / `hitsToday`); the provider stops calling once the
///   server says the quota is exhausted. In-memory counters alone are
///   NOT trusted — the server counts hits from every session.
/// - fetchPlayer takes the provider's NUMERIC player id (never a
///   display name). [resolvePlayerId] maps a name to that id, and
///   the old `_mock.playerById` hard-gate (which returned null for
///   every player outside 6 mock ids) is GONE.
/// - Every fetch debug-logs received / dropped / kept counts (never
///   the key) so a future "half matches" report is diagnosable.
class CricApiProvider implements CricketProvider {
  final http.Client _client;
  int _hits = 0;

  /// Server-side quota from the last response's `info` block.
  int? _serverHitsLeft;
  int? _serverHitsToday;
  bool _quotaError = false;

  CricApiProvider({http.Client? client}) : _client = client ?? http.Client();

  @override
  String get name => 'CricAPI';

  @override
  bool get isConfigured => AppConstants.cricApiKey.isNotEmpty;

  @override
  int get dailyCap => AppConstants.cricApiDailyCap;

  @override
  int get hitsToday => _hits;

  @override
  int? get serverHitsLeft => _serverHitsLeft;

  @override
  bool get quotaExhausted => _quotaError || _serverHitsLeft == 0;

  bool get _capped => _hits >= dailyCap || quotaExhausted;

  /// Page step for offset pagination. The server's real page size is
  /// not documented publicly; stepping by 25 is safe either way —
  /// overlapping pages are deduped by id, and the loop also stops
  /// when a page adds zero NEW entries (server ignoring `offset`).
  static const int _pageSize = 25;

  /// Hard quota guard: pagination never fetches more than this many
  /// pages per call (fixtures: 5, series: 3). Upcoming is cached
  /// 60 min by the orchestrator, so worst case is ~5 hits/hour.
  static const int _maxUpcomingPages = 5;
  static const int _maxSeriesPages = 3;

  void _log(String method,
      {required int received, required int dropped, required int kept}) {
    debugPrint(
        'KingCric [CricAPI] $method: received=$received dropped=$dropped kept=$kept');
  }

  /// Read the server-side quota out of a response envelope. Never
  /// throws, never logs the key. A `failure` status whose message
  /// mentions quota / credits / limit marks the quota exhausted.
  void _updateQuota(Map<String, dynamic> body) {
    try {
      final info = (body['info'] as Map?)?.cast<String, dynamic>();
      if (info != null) {
        final left = info['hitsLeft'];
        if (left is num) _serverHitsLeft = left.toInt();
        final today = info['hitsToday'];
        if (today is num) _serverHitsToday = today.toInt();
      }
      if (body['status'] == 'failure') {
        final msg = '${body['message'] ?? body['error'] ?? ''}'.toLowerCase();
        if (msg.contains('quota') ||
            msg.contains('credit') ||
            msg.contains('limit') ||
            msg.contains('exceed')) {
          _quotaError = true;
          _serverHitsLeft = 0;
        }
      }
    } catch (_) {}
  }

  /// Exposed for tests: server-side hits today as last reported.
  int? get serverHitsToday => _serverHitsToday;

  Future<http.Response?> _get(Uri uri) async {
    if (_capped) return null;
    _hits++;
    try {
      final res = await _client.get(uri).timeout(const Duration(seconds: 15));
      // MAIN-CORE FIX: HTTP 429 = server-side rate/quota cut-off.
      // The body is not a normal envelope, so no fetch method would
      // call _updateQuota — without this, a 429 never set
      // quotaExhausted, the Home quota banner never appeared, and
      // the app silently degraded to demo/backstop data.
      if (res.statusCode == 429) {
        _quotaError = true;
        _serverHitsLeft = 0;
      }
      return res;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> testKey() async {
    final k = AppConstants.cricApiKey.trim();
    if (k.isEmpty) return false;
    try {
      final uri = Uri.parse(
          '${AppConstants.cricApiBaseUrl}/currentMatches?apikey=$k');
      final res = await _client.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return false;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      _updateQuota(body);
      return body['status'] == 'success';
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<CricketMatch>?> fetchMatches() async {
    if (!isConfigured || _capped) return null;
    final uri = Uri.parse(
        '${AppConstants.cricApiBaseUrl}/currentMatches?apikey=${AppConstants.cricApiKey}');
    final res = await _get(uri);
    if (res == null || res.statusCode != 200) return null;
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      _updateQuota(body);
      if (body['status'] == 'failure') return null;
      final list = (body['data'] as List?) ?? [];
      final parsed = <CricketMatch>[];
      var dropped = 0;
      for (final e in list) {
        try {
          parsed.add(_matchFromFreeApi((e as Map).cast<String, dynamic>()));
        } catch (_) {
          dropped++;
        }
      }
      _log('fetchMatches',
          received: list.length, dropped: dropped, kept: parsed.length);
      return parsed.isEmpty ? null : parsed;
    } catch (_) {
      return null;
    }
  }

  /// Upcoming fixtures via /v1/matches (the endpoint /currentMatches
  /// never returns). PAGINATED: loops `offset = 0, 25, 50, ...` until
  /// a short page, a page with zero NEW entries, or the page cap.
  /// The old code fetched only `offset=0` page 1, so every fixture
  /// beyond page 1 was unreachable — the "Upcoming half / only 24th"
  /// bug. Called at most once per hour by the orchestrator (60-min
  /// upcoming cache) so this costs a few CricAPI hits/hour, not one
  /// per refresh.
  @override
  Future<List<CricketMatch>?> fetchUpcoming() async {
    if (!isConfigured || _capped) return null;
    final seenIds = <String>{};
    final parsed = <CricketMatch>[];
    var totalReceived = 0;
    var totalDropped = 0;
    for (var page = 0; page < _maxUpcomingPages; page++) {
      if (_capped) break;
      final offset = page * _pageSize;
      final uri = Uri.parse(
          '${AppConstants.cricApiBaseUrl}/matches?apikey=${AppConstants.cricApiKey}&offset=$offset');
      final res = await _get(uri);
      if (res == null || res.statusCode != 200) break;
      try {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        _updateQuota(body);
        if (body['status'] == 'failure') break;
        final list = (body['data'] as List?) ?? [];
        totalReceived += list.length;
        var newInPage = 0;
        for (final e in list) {
          try {
            final m =
                _matchFromFreeApi((e as Map).cast<String, dynamic>());
            // Keep only genuinely not-started fixtures. Anything with
            // scores / a result is a live/completed match that belongs
            // in the main list, not Upcoming.
            if (m.status == MatchStatus.upcoming &&
                !m.isEffectivelyLive) {
              // Pagination overlap (server page size > step, or
              // server ignoring offset): same id twice = one entry.
              if (m.id.isNotEmpty && !seenIds.add(m.id)) {
                totalDropped++;
                continue;
              }
              parsed.add(m);
              newInPage++;
            }
          } catch (_) {
            totalDropped++;
          }
        }
        // Short page = last page. Zero NEW entries = server ignored
        // `offset` (would loop the same page forever) — stop.
        if (list.length < _pageSize || newInPage == 0) break;
      } catch (_) {
        break;
      }
    }
    _log('fetchUpcoming',
        received: totalReceived, dropped: totalDropped, kept: parsed.length);
    return parsed.isEmpty ? null : parsed;
  }

  @override
  Future<CricketMatch?> fetchScorecard(String matchId) async {
    if (!isConfigured || _capped) return null;
    final uri = Uri.parse(
        '${AppConstants.cricApiBaseUrl}/cricketScore?apikey=${AppConstants.cricApiKey}&id=$matchId');
    final res = await _get(uri);
    if (res == null || res.statusCode != 200) return null;
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      _updateQuota(body);
      if (body['status'] == 'failure') return null;
      final data = (body['data'] as Map?)?.cast<String, dynamic>();
      if (data == null || data.isEmpty) return null;
      _log('fetchScorecard', received: 1, dropped: 0, kept: 1);
      return _matchFromScorecard(data);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Map<String, dynamic>>?> fetchSeries() async {
    if (!isConfigured || _capped) return null;
    final seenIds = <String>{};
    final parsed = <Map<String, dynamic>>[];
    var totalReceived = 0;
    for (var page = 0; page < _maxSeriesPages; page++) {
      if (_capped) break;
      final offset = page * _pageSize;
      final uri = Uri.parse(
          '${AppConstants.cricApiBaseUrl}/series?apikey=${AppConstants.cricApiKey}&offset=$offset');
      final res = await _get(uri);
      if (res == null || res.statusCode != 200) break;
      try {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        _updateQuota(body);
        if (body['status'] == 'failure') break;
        final list = (body['data'] as List?) ?? [];
        totalReceived += list.length;
        var newInPage = 0;
        for (final e in list) {
          try {
            final m = (e as Map).cast<String, dynamic>();
            final id = m['id']?.toString() ?? '';
            if (id.isNotEmpty && !seenIds.add(id)) continue;
            parsed.add({
              'id': id,
              'name': m['name'] as String? ?? '',
              'startDate': m['startDate'] as String? ?? '',
              'endDate': m['endDate'] as String? ?? '',
              'matches': (m['matches'] as num?)?.toInt() ?? 0,
            });
            newInPage++;
          } catch (_) {}
        }
        if (list.length < _pageSize || newInPage == 0) break;
      } catch (_) {
        break;
      }
    }
    _log('fetchSeries',
        received: totalReceived, dropped: 0, kept: parsed.length);
    return parsed.isEmpty ? null : parsed;
  }

  /// Map a display name to CricAPI's NUMERIC player id.
  ///
  /// The `search` query param is NOT confirmed in public CricAPI v1
  /// docs — it is sent best-effort, and the response is SCANNED: an
  /// id is returned ONLY when a returned entry's name actually
  /// matches [name] (exact, then contains). A non-matching page (e.g.
  /// the server ignoring `search` and returning page 1 of all
  /// players) yields null, never a wrong player. Costs 1 hit.
  @override
  Future<String?> resolvePlayerId(String name) async {
    if (!isConfigured || _capped) return null;
    final query = name.trim();
    if (query.isEmpty) return null;
    final uri = Uri.parse(
        '${AppConstants.cricApiBaseUrl}/players?apikey=${AppConstants.cricApiKey}&offset=0&search=${Uri.encodeQueryComponent(query)}');
    final res = await _get(uri);
    if (res == null || res.statusCode != 200) return null;
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      _updateQuota(body);
      if (body['status'] == 'failure') return null;
      final list = (body['data'] as List?) ?? [];
      String norm(String s) =>
          s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      final want = norm(query);
      String? containsMatch;
      for (final e in list) {
        try {
          final m = (e as Map).cast<String, dynamic>();
          final id = m['id']?.toString() ?? '';
          final pname = '${m['name'] ?? ''}';
          if (id.isEmpty || pname.isEmpty) continue;
          final have = norm(pname);
          if (have == want) return id;
          if (containsMatch == null &&
              (have.contains(want) || want.contains(have))) {
            containsMatch = id;
          }
        } catch (_) {}
      }
      return containsMatch;
    } catch (_) {
      return null;
    }
  }

  /// Player profile by the provider's NUMERIC id (see
  /// [resolvePlayerId] for name -> id). The old implementation took a
  /// display name, passed it to `players_info?id=` (which needs a
  /// numeric id), and then hard-gated on `_mock.playerById` — so
  /// every player outside 6 mock ids returned null even when the API
  /// answered. Both defects are gone: numeric ids only, no mock gate.
  ///
  /// The response's `stats` block (when present) is parsed
  /// tolerantly into per-format batting/bowling stats — its exact
  /// shape varies, so unknown shapes yield identity-only data
  /// (dataComplete=false) rather than a crash or invented numbers.
  @override
  Future<Player?> fetchPlayer(String playerId) async {
    if (!isConfigured || _capped) return null;
    final raw = playerId.trim();
    if (raw.isEmpty) return null;
    String numericId;
    if (RegExp(r'^\d+$').hasMatch(raw)) {
      numericId = raw;
    } else {
      // Defensive: a caller that still passes a name gets resolved
      // instead of being sent verbatim to `id=` (which could never
      // match). The orchestrator resolves first, so this is a
      // fallback, not the main path.
      final resolved = await resolvePlayerId(raw);
      if (resolved == null) return null;
      numericId = resolved;
    }
    final uri = Uri.parse(
        '${AppConstants.cricApiBaseUrl}/players_info?apikey=${AppConstants.cricApiKey}&id=$numericId');
    final res = await _get(uri);
    if (res == null || res.statusCode != 200) return null;
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      _updateQuota(body);
      if (body['status'] == 'failure') return null;
      final data = (body['data'] as Map?)?.cast<String, dynamic>() ?? {};
      if (data.isEmpty) return null;
      return _playerFromInfo(data, numericId);
    } catch (_) {
      return null;
    }
  }

  /// Build a [Player] from a `players_info` data block. Identity
  /// fields are read directly; `stats` is parsed by [_parseStats]
  /// and may contribute per-format tables. Never throws, never
  /// invents stats: no parseable stats => identity-only profile
  /// with dataComplete=false.
  static Player _playerFromInfo(
      Map<String, dynamic> data, String fallbackId) {
    final name = data['name'] as String? ?? '';
    final country = data['country'] as String? ?? '';
    final stats = _parseStats(data['stats']);
    final hasStats =
        stats.batting.isNotEmpty || stats.bowling.isNotEmpty;
    return Player(
      id: data['id']?.toString() ?? fallbackId,
      name: name,
      team: country,
      role: data['role'] as String? ?? 'Batter',
      battingStyle: data['battingStyle'] as String? ?? '',
      bowlingStyle: data['bowlingStyle'] as String? ?? '',
      country: country,
      battingByFormat: stats.batting,
      bowlingByFormat: stats.bowling,
      dataComplete: hasStats,
      // Honest source: identity + any stats came from CricAPI.
      // dataComplete is true ONLY when real per-format stats parsed.
      source: 'cricapi',
      lastUpdated: DateTime.now(),
    );
  }

  /// Parse the `stats` block of a `players_info` response into
  /// per-format batting / bowling tables.
  ///
  /// The block's shape is not pinned by public docs, so this handles
  /// the shapes seen in the wild:
  /// - a list of `{fn: 'batting', matchtype: 'test', stat: 'runs',
  ///   value: '123'}` rows;
  /// - a map `{test: {batting: {runs: ...}, bowling: {...}}}`;
  /// - a list of per-format maps `{matchtype: 'odi', batting: {...}}`.
  /// Unknown keys / shapes are ignored. Exposed as a static so unit
  /// tests can pin the mapping without a network call.
  static ({Map<String, BattingStats> batting, Map<String, BowlingStats> bowling})
      parseStats(Object? stats) => _parseStats(stats);

  static ({Map<String, BattingStats> batting, Map<String, BowlingStats> bowling})
      _parseStats(Object? stats) {
    // (format, fn) -> stat-name -> numeric value (best kept as string).
    final acc = <String, Map<String, double>>{};
    final best = <String, String>{};
    void put(String format, String fn, String stat, Object? value) {
      final key = '$format|$fn';
      final normStat = _normStatName(stat);
      if (normStat == null) return;
      if (normStat == 'best') {
        best[key] = '$value';
        return;
      }
      final num? v = value is num
          ? value
          : double.tryParse('$value'.replaceAll(RegExp(r'[^0-9.\-]'), ''));
      if (v == null) return;
      acc.putIfAbsent(key, () => {})[normStat] = v.toDouble();
    }

    void walk(Object? node, String format, String fn) {
      if (node is List) {
        for (final e in node) {
          walk(e, format, fn);
        }
        return;
      }
      if (node is! Map) return;
      final m = node.cast<String, dynamic>();
      // Row shape: {fn, matchtype, stat, value}.
      if (m.containsKey('stat') && m.containsKey('value')) {
        final f = _normFormat('${m['matchtype'] ?? m['format'] ?? format}');
        final func = _normFn('${m['fn'] ?? m['type'] ?? fn}');
        if (f != null && func != null) {
          put(f, func, '${m['stat']}', m['value']);
        }
        return;
      }
      // Per-format / per-function nesting: keys name a format or fn.
      for (final e in m.entries) {
        final key = e.key;
        final asFormat = _normFormat(key);
        final asFn = _normFn(key);
        if (asFormat != null) {
          walk(e.value, asFormat, fn);
        } else if (asFn != null) {
          walk(e.value, format, asFn);
        } else if (e.value is Map || e.value is List) {
          walk(e.value, format, fn);
        } else {
          // Leaf stat under the current (format, fn) context.
          if (format.isNotEmpty && fn.isNotEmpty) {
            put(format, fn, key, e.value);
          }
        }
      }
    }

    walk(stats, '', '');
    final batting = <String, BattingStats>{};
    final bowling = <String, BowlingStats>{};
    for (final e in acc.entries) {
      final parts = e.key.split('|');
      if (parts.length != 2) continue;
      final format = parts[0];
      final fn = parts[1];
      final s = e.value;
      if (fn == 'batting') {
        final runs = s['runs'] ?? 0;
        final balls = s['balls'] ?? 0;
        batting[format] = BattingStats(
          matches: (s['matches'] ?? 0).toInt(),
          innings: (s['innings'] ?? 0).toInt(),
          runs: runs.toInt(),
          balls: balls.toInt(),
          fifties: (s['fifties'] ?? 0).toInt(),
          hundreds: (s['hundreds'] ?? 0).toInt(),
          fours: (s['fours'] ?? 0).toInt(),
          sixes: (s['sixes'] ?? 0).toInt(),
          average: s['average'] ?? 0,
          strikeRate: s['strikeRate'] ??
              (balls > 0 ? runs * 100 / balls : 0),
          highest: (s['highest'] ?? 0).toInt(),
        );
      } else if (fn == 'bowling') {
        final runs = s['runsConceded'] ?? s['runs'] ?? 0;
        final wkts = s['wickets'] ?? 0;
        final balls = s['balls'] ?? 0;
        bowling[format] = BowlingStats(
          matches: (s['matches'] ?? 0).toInt(),
          innings: (s['innings'] ?? 0).toInt(),
          wickets: wkts.toInt(),
          balls: balls.toInt(),
          runsConceded: runs.toInt(),
          economy: s['economy'] ??
              (balls > 0 ? runs * 6 / balls : 0),
          average: s['average'] ?? (wkts > 0 ? runs / wkts : 0),
          strikeRate: s['strikeRate'] ?? (wkts > 0 ? balls / wkts : 0),
          fiveWickets: (s['fiveWickets'] ?? 0).toInt(),
          best: best[e.key] ?? '-',
        );
      }
    }
    return (batting: batting, bowling: bowling);
  }

  static String? _normStatName(String raw) {
    switch (raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')) {
      case 'm':
      case 'mat':
      case 'matches':
        return 'matches';
      case 'inn':
      case 'innings':
        return 'innings';
      case 'r':
      case 'runs':
        return 'runs';
      case 'b':
      case 'balls':
      case 'bf':
      case 'ballsfaced':
        return 'balls';
      case '100s':
      case '100':
      case 'hundreds':
        return 'hundreds';
      case '50s':
      case '50':
      case 'fifties':
        return 'fifties';
      case '4s':
      case 'fours':
        return 'fours';
      case '6s':
      case 'sixes':
        return 'sixes';
      case 'ave':
      case 'avg':
      case 'average':
      case 'battingaverage':
        return 'average';
      case 'sr':
      case 'strikerate':
        return 'strikeRate';
      case 'hs':
      case 'highest':
      case 'highestscore':
        return 'highest';
      case 'wkts':
      case 'w':
      case 'wickets':
        return 'wickets';
      case 'econ':
      case 'economy':
      case 'economyrate':
        return 'economy';
      case 'best':
      case 'bestbowling':
      case 'bbi':
      case 'bestinningbowling':
        return 'best';
      case '5w':
      case '5wkt':
      case 'fivewickets':
      case 'fivewicketsininn':
        return 'fiveWickets';
      case 'runsconceded':
        return 'runsConceded';
      default:
        return null;
    }
  }

  static String? _normFormat(String raw) {
    switch (raw.toLowerCase().trim()) {
      case 'test':
      case 'tests':
      case 'mdm':
        return 'Test';
      case 'odi':
      case 'odis':
      case 'odm':
        return 'ODI';
      case 't20':
      case 't20i':
      case 't20is':
      case 'it20':
        return 'T20';
      case 't10':
        return 'T10';
      default:
        return null;
    }
  }

  static String? _normFn(String raw) {
    switch (raw.toLowerCase().trim()) {
      case 'batting':
      case 'bat':
        return 'batting';
      case 'bowling':
      case 'bowl':
        return 'bowling';
      default:
        return null;
    }
  }

  CricketMatch _matchFromFreeApi(Map<String, dynamic> j) {
    final teams = ((j['teams'] as List?) ?? []).map((e) => '$e').toList();
    final teamA = ProviderParsing.titleCaseTeam(
        teams.isNotEmpty ? teams[0] : 'Team A');
    final teamB = ProviderParsing.titleCaseTeam(
        teams.length > 1 ? teams[1] : 'Team B');
    // CricAPI booleans may arrive as bool or "true"/"false" strings.
    bool? asBool(Object? v) {
      if (v is bool) return v;
      if (v is String) {
        if (v.toLowerCase() == 'true') return true;
        if (v.toLowerCase() == 'false') return false;
      }
      return null;
    }

    final score = (j['score'] as List?) ?? [];
    final hasScores = score.any((s) {
      final m = (s as Map).cast<String, dynamic>();
      final r = (m['r'] as num?)?.toInt() ?? 0;
      final w = (m['w'] as num?)?.toInt() ?? 0;
      final o = (m['o'] as num?)?.toDouble() ?? 0;
      return r > 0 || w > 0 || o > 0;
    });
    // V3 BUG FIX: status text alone misclassifies in-progress matches
    // ("...need 88 runs in 78 balls" has no "live"/"won"). Resolve from
    // matchStarted/matchEnded + scores + status text together.
    final status = ProviderParsing.resolveStatus(
      raw: j['status'] as String? ?? '',
      matchStarted: asBool(j['matchStarted']),
      matchEnded: asBool(j['matchEnded']),
      hasScores: hasScores,
    );
    final scores = <TeamScore>[];
    for (final s in score) {
      final m = (s as Map).cast<String, dynamic>();
      final r = (m['r'] as num?)?.toInt() ?? 0;
      final w = (m['w'] as num?)?.toInt() ?? 0;
      final o = (m['o'] as num?)?.toDouble() ?? 0;
      scores.add(TeamScore(
        // V3 BUG FIX: `inning` can be a comma-joined pair
        // ("Bulgaria Women,Sweden Women Inning 2") or lowercase
        // ("bulgaria women Inning 1"). Clean to ONE title-cased team.
        team: ProviderParsing.cleanTeamName(
            m['inning'] as String? ?? '', [teamA, teamB]),
        runs: r,
        wickets: w,
        overs: o,
        batted: true,
      ));
    }
    return CricketMatch(
      id: j['id']?.toString() ?? j['matchId']?.toString() ?? '',
      teamA: teamA,
      teamB: teamB,
      format: j['matchType'] as String? ?? 'T20',
      league: j['series'] as String? ?? 'International',
      venueName: j['venue'] as String? ?? '',
      startTime: DateTime.tryParse(j['dateTimeGMT'] as String? ?? '') ??
          DateTime.now(),
      status: status,
      scores: scores,
      result: j['status'] as String? ?? '',
      toss: _tossText(j),
      lastUpdated: DateTime.now(),
      source: 'CricAPI',
    );
  }

  String _tossText(Map<String, dynamic> j) {
    final winner = j['tossWinner'] as String? ?? '';
    final choice = j['tossChoice'] as String? ?? '';
    if (winner.isEmpty) return '';
    if (choice.isEmpty) return '$winner won the toss';
    return '$winner won the toss and chose to $choice';
  }

  CricketMatch _matchFromScorecard(Map<String, dynamic> j) {
    final base = _matchFromFreeApi(j);
    final rawInnings = (j['scorecard'] as List?) ?? [];
    final innings = <Innings>[];
    var inningsNumber = 0;
    for (final raw in rawInnings) {
      inningsNumber += 1;
      try {
        innings.add(_inningsFromScorecard(
          (raw as Map).cast<String, dynamic>(),
          inningsNumber,
        ));
      } catch (_) {}
    }
    final winner = j['matchWinner'] as String? ?? '';
    final result = winner.isNotEmpty ? '$winner won' : base.result;
    return CricketMatch(
      id: base.id,
      teamA: base.teamA,
      teamB: base.teamB,
      format: base.format,
      league: base.league,
      venueName: base.venueName,
      startTime: base.startTime,
      status: base.status,
      scores: base.scores,
      result: result,
      toss: base.toss,
      innings: innings,
      lastUpdated: DateTime.now(),
      source: base.source,
    );
  }

  Innings _inningsFromScorecard(
      Map<String, dynamic> j, int inningsNumber) {
    final battingRaw = (j['batting'] as List?) ?? [];
    final bowlingRaw = (j['bowling'] as List?) ?? [];
    final batting = <BattingEntry>[];
    for (final b in battingRaw) {
      final m = (b as Map).cast<String, dynamic>();
      final dismissal = (m['dismissal'] as String? ?? '').trim();
      batting.add(BattingEntry(
        playerId: m['batter'] as String? ?? '',
        playerName: m['batter'] as String? ?? '',
        runs: (m['r'] as num?)?.toInt() ?? 0,
        balls: (m['b'] as num?)?.toInt() ?? 0,
        fours: (m['4s'] as num?)?.toInt() ?? 0,
        sixes: (m['6s'] as num?)?.toInt() ?? 0,
        dismissal: dismissal.isEmpty ? 'not out' : dismissal,
        notOut: dismissal.isEmpty ||
            dismissal.toLowerCase().contains('not out'),
      ));
    }
    final bowling = <BowlingEntry>[];
    for (final b in bowlingRaw) {
      final m = (b as Map).cast<String, dynamic>();
      final overs = (m['o'] as num?)?.toDouble() ?? 0;
      final runs = (m['r'] as num?)?.toInt() ?? 0;
      final wickets = (m['w'] as num?)?.toInt() ?? 0;
      bowling.add(BowlingEntry(
        playerId: m['bowler'] as String? ?? '',
        playerName: m['bowler'] as String? ?? '',
        overs: overs,
        maidens: (m['m'] as num?)?.toInt() ?? 0,
        runsConceded: runs,
        wickets: wickets,
        economy: (m['eco'] as num?)?.toDouble() ??
            (overs > 0 ? runs / overs : 0),
        wides: (m['wd'] as num?)?.toInt() ?? 0,
        noBalls: (m['nb'] as num?)?.toInt() ?? 0,
      ));
    }
    final extras = (j['extras'] as Map?)?.cast<String, dynamic>() ?? {};
    final extrasRuns = (extras['r'] as num?)?.toInt() ?? 0;
    final extrasParts = <String>[];
    for (final key in ['b', 'lb', 'wd', 'nb', 'pen']) {
      final v = (extras[key] as num?)?.toInt() ?? 0;
      if (v > 0) extrasParts.add('${key.toUpperCase()} $v');
    }
    final fowRaw = (j['fallofwickets'] as List?) ?? [];
    final fow = <String>[];
    for (final f in fowRaw) {
      final m = (f as Map).cast<String, dynamic>();
      final name = m['name'] as String? ?? '';
      final score = (m['score'] as num?)?.toInt() ?? 0;
      final over = m['over'] as String? ?? '';
      if (name.isNotEmpty) fow.add('$score-$name ($over ov)');
    }
    final total = (j['total'] as num?)?.toInt() ??
        batting.fold<int>(0, (acc, b) => acc + b.runs) + extrasRuns;
    final wickets = (j['wickets'] as num?)?.toInt() ??
        batting.where((b) => !b.notOut).length;
    return Innings(
      team: ProviderParsing.cleanTeamName(
          j['inning'] as String? ?? '', null),
      inningsNumber: inningsNumber,
      total: total,
      wickets: wickets,
      overs: (j['overs'] as num?)?.toDouble() ?? 0,
      batting: batting,
      bowling: bowling,
      fallOfWickets: fow,
      extrasRuns: extrasRuns,
      extrasText:
          extrasParts.isEmpty ? '' : '${extrasParts.join(', ')} ($extrasRuns)',
    );
  }
}
