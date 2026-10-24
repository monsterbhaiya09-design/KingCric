import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../models/innings.dart';
import '../../models/match.dart';
import '../../models/player.dart';
import '../../utils/constants.dart';
import 'cricket_provider.dart';
import '../cricsheet_service.dart';

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
      // SQUAD SC: the documented shape is a Map, but a single-match
      // list shape must not kill the whole fetch — take its first
      // Map element instead (see _scorecardData).
      final data = _scorecardData(body['data']);
      if (data == null || data.isEmpty) return null;
      _log('fetchScorecard', received: 1, dropped: 0, kept: 1);
      // SQUAD SC: a parse failure inside the innings must degrade to
      // the totals-only base match (the orchestrator turns totals
      // into a labelled partial scorecard) — never to null. A live
      // match with runs on the board must never lose its scorecard
      // because one innings row had an unexpected type.
      try {
        return _matchFromScorecard(data);
      } catch (_) {
        try {
          return _matchFromFreeApi(data);
        } catch (_) {
          return null;
        }
      }
    } catch (_) {
      return null;
    }
  }

  /// Tolerant extraction of the scorecard data block. The documented
  /// shape is a Map; a single-match list shape yields its first Map
  /// element; anything else yields null.
  static Map<String, dynamic>? _scorecardData(Object? raw) {
    if (raw is Map) return raw.cast<String, dynamic>();
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) return e.cast<String, dynamic>();
      }
    }
    return null;
  }

  /// A player-name field that may be a plain string OR a nested
  /// object ({"id": ..., "name": ...}). Returns '' when neither
  /// yields a name — never throws, never renders a Map as text.
  static String _playerName(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v is Map) {
        final n = v['name'];
        if (n != null && '$n'.trim().isNotEmpty) return '$n'.trim();
      } else if (v != null && '$v'.trim().isNotEmpty) {
        return '$v'.trim();
      }
    }
    return '';
  }

  /// A dismissal that may be a string ("c X b Y", "not out", "") or
  /// a nested object ({"text": ...}). Never throws.
  static String _dismissalText(Object? v) {
    if (v == null) return '';
    if (v is Map) {
      for (final k in ['text', 'dismissal', 'how', 'type']) {
        final x = v[k];
        if (x != null && '$x'.trim().isNotEmpty) return '$x'.trim();
      }
      return '';
    }
    return '$v'.trim();
  }

  /// FINAL D — Ball-level data from a /cricketScore payload, ONLY
  /// where the payload actually carries per-ball events. The
  /// scorecard shape the provider parses (batting / bowling totals)
  /// carries NO per-ball array, so the normal result is an empty
  /// [MatchBallData] with [MatchBallData.hasBallData] false — that
  /// is the honest answer for a totals-only payload, and widgets
  /// must render no ball strip for it. If a future payload DOES
  /// carry per-ball lists (under 'balls', 'ballByBall',
  /// 'commentary', or 'overs' -> 'deliveries'), they are parsed
  /// tolerantly; events without an over number are dropped rather
  /// than placed by guesswork. Per-over runs are NEVER rebuilt
  /// from bowling totals. Quota handling is identical to
  /// [fetchScorecard] (one hit, _updateQuota, 429 via [_get]).
  Future<MatchBallData> fetchBallData(String matchId) async {
    const empty = MatchBallData.empty(source: 'CricAPI');
    if (!isConfigured || _capped) return empty;
    final uri = Uri.parse(
        '${AppConstants.cricApiBaseUrl}/cricketScore?apikey=<redacted>&id=$matchId');
    final res = await _get(uri);
    if (res == null || res.statusCode != 200) return empty;
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      _updateQuota(body);
      if (body['status'] == 'failure') return empty;
      final data = (body['data'] as Map?)?.cast<String, dynamic>();
      if (data == null || data.isEmpty) return empty;
      final rawInnings = (data['scorecard'] as List?) ?? [];
      final overs = <OverSummary>[];
      var inningsIndex = 0;
      for (final raw in rawInnings) {
        final inn = (raw as Map).cast<String, dynamic>();
        final events = <_RawBall>[];
        for (final key in ['balls', 'ballByBall', 'commentary']) {
          final list = inn[key] as List?;
          if (list == null) continue;
          for (final e in list) {
            if (e is Map) {
              final parsed = _parseBallEvent(e.cast());
              if (parsed != null) events.add(parsed);
            }
          }
        }
        final oversRaw = inn['overs'] as List?;
        if (oversRaw != null) {
          for (final o in oversRaw) {
            if (o is! Map) continue;
            final dList = o['deliveries'] as List?;
            if (dList == null) continue;
            for (final e in dList) {
              if (e is Map) {
                final parsed = _parseBallEvent(e.cast());
                if (parsed != null) events.add(parsed);
              }
            }
          }
        }
        // Group by over number, in first-seen order; events with
        // no over number were already dropped by _parseBallEvent.
        final grouped = <int, List<_RawBall>>{};
        final order = <int>[];
        for (final e in events) {
          if (!grouped.containsKey(e.over)) {
            grouped[e.over] = [];
            order.add(e.over);
          }
          grouped[e.over]!.add(e);
        }
        for (final over in order) {
          final es = grouped[over]!;
          final balls = <BallOutcome>[];
          for (var i = 0; i < es.length; i++) {
            final e = es[i];
            balls.add(BallOutcome(
              inningsIndex: inningsIndex,
              overNumber: over,
              ballIndex: e.ball ?? i + 1,
              batter: e.batter,
              bowler: e.bowler,
              runs: e.runs,
              batterRuns: e.batterRuns,
              isWide: e.isWide,
              isNoBall: e.isNoBall,
              isWicket: e.isWicket,
              wicketKind: e.wicketKind,
              playerOut: e.playerOut,
            ));
          }
          overs.add(OverSummary(
            inningsIndex: inningsIndex,
            overNumber: over,
            battingTeam: '',
            bowler: balls.isEmpty ? '' : balls.first.bowler,
            balls: balls,
          ));
        }
        inningsIndex += 1;
      }
      return MatchBallData(
        source: 'CricAPI',
        overs: overs,
      );
    } catch (_) {
      return empty;
    }
  }

  /// One parsed per-ball event, or null when the event carries no
  /// usable over number (placement must never be guessed).
  _RawBall? _parseBallEvent(Map<String, dynamic> m) {
    final over = _parseOverNumber(m['over'] ?? m['overNumber']);
    if (over == null) return null;
    final ball = (m['ball'] as num?)?.toInt() ??
        (m['ballNumber'] as num?)?.toInt() ??
        (m['delivery'] as num?)?.toInt();
    final runs = (m['runs'] as num?)?.toInt() ??
        (m['r'] as num?)?.toInt() ??
        (m['total'] as num?)?.toInt() ??
        0;
    final batterRuns = (m['batterRuns'] as num?)?.toInt() ??
        (m['batsmanRuns'] as num?)?.toInt() ??
        runs;
    final extras = (m['extras'] as Map?)?.cast<String, dynamic>() ?? {};
    final isWide = m['wide'] == true ||
        m['isWide'] == true ||
        (extras['wides'] as num?) != null &&
            (extras['wides'] as num) > 0;
    final isNoBall = m['noBall'] == true ||
        m['isNoBall'] == true ||
        (extras['noballs'] as num?) != null &&
            (extras['noballs'] as num) > 0;
    final playerOut = (m['playerOut'] as String?) ??
        (m['player_out'] as String?) ??
        (m['dismissedBatter'] as String?);
    final dismissal = (m['dismissal'] as String?) ?? '';
    final isWicket = m['wicket'] == true ||
        m['isWicket'] == true ||
        (playerOut != null && playerOut.isNotEmpty) ||
        dismissal.isNotEmpty;
    return _RawBall(
      over: over,
      ball: ball,
      batter: (m['batter'] as String?) ??
          (m['batsman'] as String?) ??
          (m['striker'] as String?) ??
          '',
      bowler: (m['bowler'] as String?) ?? '',
      runs: runs,
      batterRuns: batterRuns,
      isWide: isWide,
      isNoBall: isNoBall,
      isWicket: isWicket,
      wicketKind: (m['wicketKind'] as String?) ??
          (m['kind'] as String?) ??
          (dismissal.isNotEmpty ? dismissal : null),
      playerOut: playerOut,
    );
  }

  /// Over numbers arrive as an int, a double, or "12.3"-style
  /// strings. Returns the whole-over part, or null when unparseable.
  int? _parseOverNumber(Object? v) {
    if (v is num) return v.toInt();
    if (v is String) {
      final head = v.split('.').first;
      return int.tryParse(head);
    }
    return null;
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
          if (have == want) {
            _log('resolvePlayerId',
                received: list.length, dropped: 0, kept: 1);
            return id;
          }
          if (containsMatch == null &&
              (have.contains(want) || want.contains(have))) {
            containsMatch = id;
          }
        } catch (_) {}
      }
      _log('resolvePlayerId',
          received: list.length,
          dropped: 0,
          kept: containsMatch == null ? 0 : 1);
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
      if (data.isEmpty) {
        _log('fetchPlayer', received: 0, dropped: 0, kept: 0);
        return null;
      }
      _log('fetchPlayer', received: 1, dropped: 0, kept: 1);
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
    // SQUAD SC: tolerant — teams/score rows may carry numbers as
    // strings or miss fields. A malformed row is skipped (or falls
    // back to the teams list by position), never allowed to throw
    // the whole match away: a live match with totals must keep them.
    final teamsRaw = j['teams'];
    final teams = teamsRaw is List
        ? teamsRaw.map((e) => '$e').toList()
        : <String>[];
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

    final scoreRaw = j['score'];
    final scoreList = scoreRaw is List ? scoreRaw : const [];
    final hasScores = scoreList.any((s) {
      if (s is! Map) return false;
      final m = s.cast<String, dynamic>();
      final r = ProviderParsing.toInt(m['r']);
      final w = ProviderParsing.toInt(m['w']);
      final o = ProviderParsing.toDouble(m['o']);
      return r > 0 || w > 0 || o > 0;
    });
    // V3 BUG FIX: status text alone misclassifies in-progress matches
    // ("...need 88 runs in 78 balls" has no "live"/"won"). Resolve from
    // matchStarted/matchEnded + scores + status text together.
    final status = ProviderParsing.resolveStatus(
      raw: ProviderParsing.toStr(j['status']),
      matchStarted: asBool(j['matchStarted']),
      matchEnded: asBool(j['matchEnded']),
      hasScores: hasScores,
    );
    final scores = <TeamScore>[];
    for (var i = 0; i < scoreList.length; i++) {
      final s = scoreList[i];
      if (s is! Map) continue;
      final m = s.cast<String, dynamic>();
      final r = ProviderParsing.toInt(m['r']);
      final w = ProviderParsing.toInt(m['w']);
      final o = ProviderParsing.toDouble(m['o']);
      scores.add(TeamScore(
        // V3 BUG FIX: `inning` can be a comma-joined pair
        // ("Bulgaria Women,Sweden Women Inning 2") or lowercase
        // ("bulgaria women Inning 1"). Clean to ONE title-cased team.
        team: _scoreTeam(m, i, teams, teamA, teamB),
        runs: r,
        wickets: w,
        overs: o,
        batted: true,
      ));
    }
    return CricketMatch(
      id: ProviderParsing.toStr(j['id'] ?? j['matchId']),
      teamA: teamA,
      teamB: teamB,
      format: ProviderParsing.toStr(j['matchType'], 'T20'),
      league: ProviderParsing.toStr(j['series'], 'International'),
      venueName: ProviderParsing.toStr(j['venue']),
      startTime: DateTime.tryParse(ProviderParsing.toStr(j['dateTimeGMT'])) ??
          DateTime.now(),
      status: status,
      scores: scores,
      result: ProviderParsing.toStr(j['status']),
      toss: _tossText(j),
      lastUpdated: DateTime.now(),
      source: 'CricAPI',
    );
  }

  /// Team name for one score row. An unresolvable inning label must
  /// not produce a blank team row — fall back to the teams list by
  /// position (score rows arrive in batting order).
  static String _scoreTeam(Map<String, dynamic> m, int index,
      List<String> teams, String teamA, String teamB) {
    final cleaned = ProviderParsing.cleanTeamName(
        ProviderParsing.toStr(m['inning']), [teamA, teamB]);
    if (cleaned.isNotEmpty) return cleaned;
    if (index < teams.length) {
      return ProviderParsing.titleCaseTeam(teams[index]);
    }
    return '';
  }

  String _tossText(Map<String, dynamic> j) {
    final winner = ProviderParsing.toStr(j['tossWinner']);
    final choice = ProviderParsing.toStr(j['tossChoice']);
    if (winner.isEmpty) return '';
    if (choice.isEmpty) return '$winner won the toss';
    return '$winner won the toss and chose to $choice';
  }

  CricketMatch _matchFromScorecard(Map<String, dynamic> j) {
    final base = _matchFromFreeApi(j);
    // SQUAD SC: scorecard key variants — 'scorecard' (documented),
    // 'scoreCard', or a bare 'innings' list; a Map value is treated
    // as an innings map (values in order). Never let a key variant
    // produce zero innings for a match that HAS a scorecard.
    final rawCard = j['scorecard'] ?? j['scoreCard'] ?? j['innings'];
    final rawInnings = <Object?>[];
    if (rawCard is List) {
      rawInnings.addAll(rawCard);
    } else if (rawCard is Map) {
      rawInnings.addAll(rawCard.values);
    }
    final innings = <Innings>[];
    var inningsNumber = 0;
    for (final raw in rawInnings) {
      if (raw is! Map) continue;
      inningsNumber += 1;
      try {
        innings.add(_inningsFromScorecard(
          raw.cast<String, dynamic>(),
          inningsNumber,
        ));
      } catch (_) {}
    }
    final winner = ProviderParsing.toStr(j['matchWinner']);
    final result = winner.isNotEmpty ? '$winner won' : base.result;
    // SQUAD C: the envelope status is not the whole truth. A live
    // scorecard can carry a stale "Match scheduled" label (and no
    // `score` array), so base.status may say upcoming even though
    // full innings exist. Innings data is scores too: a declared
    // winner = completed, innings with real data and no winner =
    // live. Never let a scorecard with innings parse as upcoming.
    var status = base.status;
    if (winner.isNotEmpty) {
      status = MatchStatus.completed;
    } else if (status == MatchStatus.upcoming &&
        innings.any((i) =>
            i.total > 0 ||
            i.batting.any((b) => b.balls > 0 || b.runs > 0))) {
      status = MatchStatus.live;
    }
    // SQUAD SC: derive the Live tab's Batting:/Bowling: rows from
    // the latest innings. No free payload names a "current" batter
    // or bowler — that is why those rows were ALWAYS blank for real
    // matches (only mock data set them). Derivation, documented:
    // batters = not-out batters of the latest innings ("Name
    // (runs*)"); bowler = the bowler with the most overs in the
    // latest innings (best available proxy for the current bowler).
    // Both come from real scorecard rows, never invented names.
    var currentBatter = '';
    var currentBowler = '';
    if (innings.isNotEmpty) {
      final current = innings.last;
      final notOut = current.batting
          .where((b) => b.notOut && b.playerName.isNotEmpty)
          .toList();
      if (notOut.isNotEmpty) {
        currentBatter = notOut
            .map((b) => '${b.playerName} (${b.runs}*)')
            .join(' • ');
      }
      BowlingEntry? top;
      for (final b in current.bowling) {
        if (b.playerName.isEmpty) continue;
        if (top == null || b.overs > top.overs) top = b;
      }
      if (top != null) currentBowler = top.playerName;
    }
    return CricketMatch(
      id: base.id,
      teamA: base.teamA,
      teamB: base.teamB,
      format: base.format,
      league: base.league,
      venueName: base.venueName,
      startTime: base.startTime,
      status: status,
      scores: base.scores,
      result: result,
      toss: base.toss,
      innings: innings,
      currentBatter: currentBatter,
      currentBowler: currentBowler,
      lastUpdated: DateTime.now(),
      source: base.source,
    );
  }

  Innings _inningsFromScorecard(
      Map<String, dynamic> j, int inningsNumber) {
    // SQUAD SC: every field is coerced, never cast. The old code
    // used `as String?` / `as num?` throughout, so ONE variant row
    // (nested batter object, numeric FOW over, string economy)
    // threw, the per-innings catch dropped the WHOLE innings, and a
    // live match with a full scorecard rendered an empty tab.
    // Malformed rows are skipped; the innings itself survives.
    final battingRaw = j['batting'] is List ? j['batting'] as List : const [];
    final bowlingRaw = j['bowling'] is List ? j['bowling'] as List : const [];
    final batting = <BattingEntry>[];
    for (final b in battingRaw) {
      if (b is! Map) continue;
      final m = b.cast<String, dynamic>();
      final name = _playerName(m, const ['batter', 'batsman', 'name', 'player']);
      if (name.isEmpty) continue;
      final dismissal = _dismissalText(m['dismissal']);
      batting.add(BattingEntry(
        playerId: name,
        playerName: name,
        runs: ProviderParsing.toInt(m['r'] ?? m['runs']),
        balls: ProviderParsing.toInt(m['b'] ?? m['balls']),
        fours: ProviderParsing.toInt(m['4s'] ?? m['fours']),
        sixes: ProviderParsing.toInt(m['6s'] ?? m['sixes']),
        dismissal: dismissal.isEmpty ? 'not out' : dismissal,
        notOut: dismissal.isEmpty ||
            dismissal.toLowerCase().contains('not out'),
      ));
    }
    final bowling = <BowlingEntry>[];
    for (final b in bowlingRaw) {
      if (b is! Map) continue;
      final m = b.cast<String, dynamic>();
      final name = _playerName(m, const ['bowler', 'name', 'player']);
      if (name.isEmpty) continue;
      final overs = ProviderParsing.toDouble(m['o'] ?? m['overs']);
      final runs = ProviderParsing.toInt(m['r'] ?? m['runs']);
      final wickets = ProviderParsing.toInt(m['w'] ?? m['wickets']);
      bowling.add(BowlingEntry(
        playerId: name,
        playerName: name,
        overs: overs,
        maidens: ProviderParsing.toInt(m['m'] ?? m['maidens']),
        runsConceded: runs,
        wickets: wickets,
        economy: ProviderParsing.toDouble(m['eco'] ?? m['economy'],
            overs > 0 ? runs / overs : 0),
        wides: ProviderParsing.toInt(m['wd'] ?? m['wides']),
        noBalls: ProviderParsing.toInt(m['nb'] ?? m['noBalls']),
      ));
    }
    final extrasRaw = j['extras'];
    final extras = extrasRaw is Map
        ? extrasRaw.cast<String, dynamic>()
        : <String, dynamic>{};
    final extrasRuns =
        ProviderParsing.toInt(extras['r'] ?? extras['runs']);
    final extrasParts = <String>[];
    for (final key in ['b', 'lb', 'wd', 'nb', 'pen']) {
      final v = ProviderParsing.toInt(extras[key]);
      if (v > 0) extrasParts.add('${key.toUpperCase()} $v');
    }
    final fowRaw =
        j['fallofwickets'] is List ? j['fallofwickets'] as List : const [];
    final fow = <String>[];
    for (final f in fowRaw) {
      if (f is! Map) continue;
      final m = f.cast<String, dynamic>();
      final name = ProviderParsing.toStr(m['name'] ?? m['batter'] ?? m['player']);
      final score = ProviderParsing.toInt(m['score'] ?? m['runs']);
      final over = ProviderParsing.toStr(m['over'] ?? m['overNumber']);
      if (name.isNotEmpty) fow.add('$score-$name ($over ov)');
    }
    final yetToBatRaw = j['yetToBat'] ?? j['didNotBat'];
    final yetToBat = yetToBatRaw is List
        ? yetToBatRaw
            .map((e) => ProviderParsing.toStr(e))
            .where((s) => s.isNotEmpty)
            .toList()
        : const <String>[];
    final partnershipsRaw = j['partnerships'];
    final partnerships = partnershipsRaw is List
        ? partnershipsRaw
            .map((e) => ProviderParsing.toStr(e))
            .where((s) => s.isNotEmpty)
            .toList()
        : const <String>[];
    final total = ProviderParsing.toInt(j['total'],
        batting.fold<int>(0, (acc, b) => acc + b.runs) + extrasRuns);
    final wickets = ProviderParsing.toInt(
        j['wickets'], batting.where((b) => !b.notOut).length);
    return Innings(
      team: ProviderParsing.cleanTeamName(
          ProviderParsing.toStr(j['inning'] ?? j['team']), null),
      inningsNumber: inningsNumber,
      total: total,
      wickets: wickets,
      overs: ProviderParsing.toDouble(j['overs']),
      batting: batting,
      bowling: bowling,
      fallOfWickets: fow,
      extrasRuns: extrasRuns,
      extrasText:
          extrasParts.isEmpty ? '' : '${extrasParts.join(', ')} ($extrasRuns)',
      yetToBat: yetToBat,
      partnerships: partnerships,
    );
  }
}

/// Parsed per-ball event before grouping into overs. Private to
/// the provider: widgets only ever see [BallOutcome] /
/// [OverSummary] via [MatchBallData].
class _RawBall {
  final int over;
  final int? ball;
  final String batter;
  final String bowler;
  final int runs;
  final int batterRuns;
  final bool isWide;
  final bool isNoBall;
  final bool isWicket;
  final String? wicketKind;
  final String? playerOut;

  const _RawBall({
    required this.over,
    required this.ball,
    required this.batter,
    required this.bowler,
    required this.runs,
    required this.batterRuns,
    required this.isWide,
    required this.isNoBall,
    required this.isWicket,
    required this.wicketKind,
    required this.playerOut,
  });
}
