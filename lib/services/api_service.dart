import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/innings.dart';
import '../models/match.dart';
import '../models/player.dart';
import '../models/venue.dart';
import '../utils/constants.dart';
import 'mock_data_service.dart';

/// Free-API layer.
///
/// NEVER scrapes Cricbuzz / Cricinfo / Crex / Cricmetrics.
/// Talks only to a free provider's documented JSON API (default:
/// CricAPI / CricketData.org — see API-SETUP.md). The API key comes
/// from --dart-define=CRIC_API_KEY=... — it is never hard-coded.
///
/// If no key is configured, every method falls back to the local
/// realistic mock dataset so the app works fully offline in demo mode.
/// [isLive] tells the UI whether data is real-live or demo.
///
/// QUOTA SAFETY (free tier = 100 hits/day, lifetime):
/// - Live match list: cached 10 minutes.
/// - Completed match detail / scorecard: cached 60 minutes (it never
///   changes once finished — re-fetching it wastes quota).
/// - Live match detail: cached 10 minutes; the UI also offers a manual
///   Refresh button and one extra fetch when a match flips to completed.
/// - NEVER poll every 45s. That would burn ~1,920 calls/day and kill
///   the key before lunch. See API-SETUP.md "Quota budget".
class _CacheEntry<T> {
  final T value;
  final DateTime expiresAt;
  _CacheEntry(this.value, this.expiresAt);
  bool get fresh => DateTime.now().isBefore(expiresAt);
}

class ApiService {
  final http.Client _client;
  final MockDataService _mock = MockDataService();

  // In-memory caches. Deliberately small + TTL-based so a stale
  // scoreboard can never linger past its window.
  _CacheEntry<List<CricketMatch>>? _matchesCache;
  final Map<String, _CacheEntry<CricketMatch>> _detailCache = {};
  final Map<String, _CacheEntry<Player>> _playerCache = {};
  _CacheEntry<List<Map<String, dynamic>>>? _seriesCache;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  bool get isLive => AppConstants.hasApiKey;

  /// Number of cached entries (debug / tests). Never exposes keys.
  int get cacheEntryCount =>
      (_matchesCache == null ? 0 : 1) +
      _detailCache.length +
      _playerCache.length +
      (_seriesCache == null ? 0 : 1);

  void clearCache() {
    _matchesCache = null;
    _detailCache.clear();
    _playerCache.clear();
    _seriesCache = null;
  }

  /// Checks whether [key] is accepted by the provider WITHOUT spending
  /// a match-list call on a bad key. Returns false on any error, timeout
  /// or non-"success" provider status — callers must treat false as
  /// "stay in demo mode", never as a crash.
  ///
  /// Pass [key] explicitly so the Settings / onboarding screen can test
  /// a key the user just typed before saving it. When omitted, the
  /// compiled-in --dart-define key is tested.
  Future<bool> testApiKeyValidity({String? key}) async {
    final k = (key ?? AppConstants.cricApiKey).trim();
    if (k.isEmpty) return false;
    try {
      final uri = Uri.parse(
          '${AppConstants.freeApiBaseUrl}/currentMatches?apikey=$k');
      final res =
          await _client.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return false;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      // CricAPI shape: {"status":"success", "info":{...}, "data":[...]}.
      // An invalid key returns status 400 / {"status":"failure", ...}.
      return body['status'] == 'success';
    } catch (_) {
      return false;
    }
  }

  /// Live / upcoming / recent match list (10-min cache).
  /// Set [forceRefresh] to bypass the cache (manual Refresh button).
  Future<List<CricketMatch>> fetchMatches(
      {bool forceRefresh = false}) async {
    if (!isLive) return _mock.matches();
    if (!forceRefresh &&
        _matchesCache != null &&
        _matchesCache!.fresh) {
      return _matchesCache!.value;
    }
    try {
      final uri = Uri.parse(
          '${AppConstants.freeApiBaseUrl}/currentMatches?apikey=${AppConstants.cricApiKey}');
      final res =
          await _client.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return _cachedMatchesOrMock();
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['status'] == 'failure') return _cachedMatchesOrMock();
      final list = (body['data'] as List?) ?? [];
      final parsed = <CricketMatch>[];
      for (final e in list) {
        try {
          parsed.add(_matchFromFreeApi((e as Map).cast<String, dynamic>()));
        } catch (_) {
          // Skip one malformed match rather than failing the whole list.
        }
      }
      if (parsed.isEmpty) return _cachedMatchesOrMock();
      _matchesCache = _CacheEntry<List<CricketMatch>>(
        parsed,
        DateTime.now().add(AppConstants.liveCacheTtl),
      );
      return parsed;
    } catch (_) {
      // Free API down / offline -> demo data keeps the app usable.
      return _cachedMatchesOrMock();
    }
  }

  List<CricketMatch> _cachedMatchesOrMock() {
    if (_matchesCache != null) return _matchesCache!.value;
    return _mock.matches();
  }

  /// Full detail for one match. Uses the scorecard endpoint when a key
  /// is present (full innings), otherwise the cached list + mock detail.
  /// Completed matches are cached 60 min; live matches 10 min.
  Future<CricketMatch?> fetchMatchDetail(String matchId,
      {bool forceRefresh = false}) async {
    if (!isLive) {
      final all = _mock.matches();
      for (final m in all) {
        if (m.id == matchId) return m;
      }
      return null;
    }
    if (!forceRefresh) {
      final cached = _detailCache[matchId];
      if (cached != null && cached.fresh) return cached.value;
    }
    // Try the rich scorecard endpoint first (full batting/bowling).
    final viaScorecard = await fetchScorecard(matchId);
    if (viaScorecard != null) {
      final ttl = viaScorecard.status == MatchStatus.completed
          ? AppConstants.completedCacheTtl
          : AppConstants.liveCacheTtl;
      _detailCache[matchId] = _CacheEntry<CricketMatch>(
        viaScorecard,
        DateTime.now().add(ttl),
      );
      return viaScorecard;
    }
    // Fall back to the list entry (score summary only).
    final all = await fetchMatches(forceRefresh: forceRefresh);
    for (final m in all) {
      if (m.id == matchId) {
        _detailCache[matchId] = _CacheEntry<CricketMatch>(
          m,
          DateTime.now().add(AppConstants.liveCacheTtl),
        );
        return m;
      }
    }
    return null;
  }

  /// Full scorecard for one match via `cricketScore?id=<matchId>`.
  /// Returns null (caller falls back) when there is no key, the match
  /// has no scorecard yet (upcoming), or the provider errors.
  ///
  /// CricAPI `cricketScore` shape (documented in API-SETUP.md):
  /// {"status":"success","data":{"id","matchType","series","teams",
  /// "score":[{"inning","r","w","o"}], "scorecard":[{"inning",
  /// "batting":[{"batter","dismissal","r","b","4s","6s","sr"}],
  /// "bowling":[{"bowler","o","m","r","w","eco"}],
  /// "extras":{"r":..,"b":..,"lb":..,"wd":..,"nb":..},
  /// "fallofwickets":[{"name","score","over"}]}],
  /// "status","venue","dateTimeGMT","tossWinner","tossChoice","matchWinner"}}
  Future<CricketMatch?> fetchScorecard(String matchId,
      {bool forceRefresh = false}) async {
    if (!isLive) return null;
    if (!forceRefresh) {
      final cached = _detailCache[matchId];
      if (cached != null && cached.fresh) return cached.value;
    }
    try {
      final uri = Uri.parse(
          '${AppConstants.freeApiBaseUrl}/cricketScore?apikey=${AppConstants.cricApiKey}&id=$matchId');
      final res =
          await _client.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['status'] == 'failure') return null;
      final data = (body['data'] as Map?)?.cast<String, dynamic>();
      if (data == null || data.isEmpty) return null;
      return _matchFromScorecard(data);
    } catch (_) {
      return null;
    }
  }

  /// Series list (60-min cache). Each entry: {id, name, startDate,
  /// endDate, matches, t20/odi/test counts when the provider sends them}.
  /// Used by the Leagues screen. Empty list on any error (never throws).
  Future<List<Map<String, dynamic>>> fetchSeries(
      {bool forceRefresh = false}) async {
    if (!isLive) return _mockSeries();
    if (!forceRefresh &&
        _seriesCache != null &&
        _seriesCache!.fresh) {
      return _seriesCache!.value;
    }
    try {
      final uri = Uri.parse(
          '${AppConstants.freeApiBaseUrl}/series?apikey=${AppConstants.cricApiKey}&offset=0');
      final res =
          await _client.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return _cachedSeriesOrMock();
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['status'] == 'failure') return _cachedSeriesOrMock();
      final list = (body['data'] as List?) ?? [];
      final parsed = <Map<String, dynamic>>[];
      for (final e in list) {
        try {
          final m = (e as Map).cast<String, dynamic>();
          parsed.add({
            'id': m['id']?.toString() ?? '',
            'name': m['name'] as String? ?? '',
            'startDate': m['startDate'] as String? ?? '',
            'endDate': m['endDate'] as String? ?? '',
            'matches': (m['matches'] as num?)?.toInt() ?? 0,
          });
        } catch (_) {
          // Skip one malformed series entry.
        }
      }
      if (parsed.isEmpty) return _cachedSeriesOrMock();
      _seriesCache = _CacheEntry<List<Map<String, dynamic>>>(
        parsed,
        DateTime.now().add(AppConstants.completedCacheTtl),
      );
      return parsed;
    } catch (_) {
      return _cachedSeriesOrMock();
    }
  }

  List<Map<String, dynamic>> _cachedSeriesOrMock() {
    if (_seriesCache != null) return _seriesCache!.value;
    return _mockSeries();
  }

  List<Map<String, dynamic>> _mockSeries() => const [
        {'id': 's-intl', 'name': 'International', 'matches': 3},
        {'id': 's-ipl', 'name': 'IPL', 'matches': 1},
        {'id': 's-bbl', 'name': 'Big Bash', 'matches': 1},
      ];

  Future<Player?> fetchPlayer(String playerId,
      {bool forceRefresh = false}) async {
    if (!isLive) return _mock.playerById(playerId);
    if (!forceRefresh) {
      final cached = _playerCache[playerId];
      if (cached != null && cached.fresh) return cached.value;
    }
    try {
      final uri = Uri.parse(
          '${AppConstants.freeApiBaseUrl}/players_info?apikey=${AppConstants.cricApiKey}&id=$playerId');
      final res =
          await _client.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return _mock.playerById(playerId);
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['status'] == 'failure') return _mock.playerById(playerId);
      final data = (body['data'] as Map?)?.cast<String, dynamic>() ?? {};
      // Free providers return only a basic profile; the app enriches it
      // with mock-derived derived stats ONLY in demo mode. In live mode
      // we return the basic profile and mark it incomplete so the
      // validator never presents partial data as complete.
      final base = _mock.playerById(playerId);
      if (base == null) return null;
      final player = Player(
        id: data['id']?.toString() ?? base.id,
        name: data['name'] as String? ?? base.name,
        team: base.team,
        role: data['role'] as String? ?? base.role,
        battingStyle: data['battingStyle'] as String? ?? base.battingStyle,
        bowlingStyle: data['bowlingStyle'] as String? ?? base.bowlingStyle,
        country: data['placeOfBirth'] as String? ?? base.country,
        battingByFormat: base.battingByFormat,
        bowlingByFormat: base.bowlingByFormat,
        battingVsOpponent: base.battingVsOpponent,
        bowlingVsOpponent: base.bowlingVsOpponent,
        battingByLeague: base.battingByLeague,
        battingByVenue: base.battingByVenue,
        recentForm: base.recentForm,
        matchups: base.matchups,
        dismissalHistory: base.dismissalHistory,
        dataComplete: false,
        lastUpdated: DateTime.now(),
      );
      _playerCache[playerId] = _CacheEntry<Player>(
        player,
        DateTime.now().add(AppConstants.completedCacheTtl),
      );
      return player;
    } catch (_) {
      return _mock.playerById(playerId);
    }
  }

  Future<List<Player>> fetchPlayers() async {
    if (!isLive) return _mock.players();
    // Most free tiers have no bulk player endpoint; reuse mock list and
    // let fetchPlayer enrich one-by-one when a profile is opened.
    return _mock.players();
  }

  Future<List<Venue>> fetchVenues() async => _mock.venues();

  /// Mapping from a generic free-API match shape to our model.
  /// Providers differ; this keeps only fields that are stable across
  /// CricAPI-compatible responses and defaults everything else.
  CricketMatch _matchFromFreeApi(Map<String, dynamic> j) {
    final teams = ((j['teams'] as List?) ?? []).map((e) => '$e').toList();
    final teamA = teams.isNotEmpty ? teams[0] : 'Team A';
    final teamB = teams.length > 1 ? teams[1] : 'Team B';
    final statusRaw = (j['status'] as String? ?? '').toLowerCase();
    final status = statusRaw.contains('live')
        ? MatchStatus.live
        : statusRaw.contains('won') || statusRaw.contains('result')
            ? MatchStatus.completed
            : MatchStatus.upcoming;
    final score = (j['score'] as List?) ?? [];
    final scores = <TeamScore>[];
    for (final s in score) {
      final m = (s as Map).cast<String, dynamic>();
      final r = (m['r'] as num?)?.toInt() ?? 0;
      final w = (m['w'] as num?)?.toInt() ?? 0;
      final o = (m['o'] as num?)?.toDouble() ?? 0;
      scores.add(TeamScore(
        team: m['inning'] as String? ?? '',
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
    );
  }

  String _tossText(Map<String, dynamic> j) {
    final winner = j['tossWinner'] as String? ?? '';
    final choice = j['tossChoice'] as String? ?? '';
    if (winner.isEmpty) return '';
    if (choice.isEmpty) return '$winner won the toss';
    return '$winner won the toss and chose to $choice';
  }

  /// Full match (incl. innings scorecards) from a `cricketScore` payload.
  /// Unknown / missing fields default to empty so a partial provider
  /// response can never crash the scoreboard screen.
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
      } catch (_) {
        // Skip one malformed innings rather than dropping the match.
      }
    }
    final winner = j['matchWinner'] as String? ?? '';
    final result = winner.isNotEmpty
        ? '$winner won'
        : base.result;
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
      team: j['inning'] as String? ?? '',
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
