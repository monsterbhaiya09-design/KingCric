import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/match.dart';
import '../../models/player.dart';
import '../../utils/constants.dart';
import 'cricket_provider.dart';

/// SECONDARY provider: EliteSport API (elitesportapi.com).
/// Free plan, key in `x-api-key` header. Documented endpoints:
/// GET /matches/live, /matches/{id}/scorecard,
/// /matches/{id}/commentary, /players/{id}, /fixtures,
/// /series/{series_id}. Coverage: Test/ODI/T20I, IPL + major T20 leagues.
///
/// HONEST STATUS: the endpoint PATHS are documented on the provider
/// site, but the exact API host is VERIFY-from-dashboard (see
/// API-SETUP.md). If the host is wrong, every call returns null and
/// the orchestrator falls through — this provider can never break the
/// app. Free tier is testing-only; paid plans are $199+/mo, which we
/// do NOT use. Keep [dailyCap] low.
class EliteSportProvider implements CricketProvider {
  final http.Client _client;
  int _hits = 0;

  EliteSportProvider({http.Client? client})
      : _client = client ?? http.Client();

  @override
  String get name => 'EliteSport';

  @override
  bool get isConfigured => AppConstants.eliteSportApiKey.isNotEmpty;

  @override
  int get dailyCap => AppConstants.eliteSportDailyCap;

  @override
  int get hitsToday => _hits;

  bool get _capped => _hits >= dailyCap;

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'x-api-key': AppConstants.eliteSportApiKey,
      };

  Future<Map<String, dynamic>?> _getJson(String path) async {
    if (!isConfigured || _capped) return null;
    _hits++;
    try {
      final res = await _client
          .get(Uri.parse('${AppConstants.eliteSportBaseUrl}$path'),
              headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return null;
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is List) return {'data': decoded};
      return null;
    } catch (_) {
      return null;
    }
  }

  List<Map<String, dynamic>> _list(Map<String, dynamic> body) {
    for (final key in ['data', 'matches', 'results', 'items']) {
      final v = body[key];
      if (v is List) {
        return v.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
      }
    }
    return [];
  }

  CricketMatch? _matchFromGeneric(Map<String, dynamic> m) {
    final home = ProviderParsing.toStr(
        m['home_team'] ?? m['homeTeam'] ?? m['teamA'] ?? m['teama']);
    final away = ProviderParsing.toStr(
        m['away_team'] ?? m['awayTeam'] ?? m['teamB'] ?? m['teamb']);
    if (home.isEmpty || away.isEmpty) return null;
    final statusRaw =
        ProviderParsing.toStr(m['status'] ?? m['match_status'] ?? '');
    final status = ProviderParsing.statusFromText(statusRaw);
    // Score may be nested {home:{runs,wickets,overs}, away:{...}} or
    // flat strings "192/6".
    Map<String, dynamic>? scoreMap;
    final s = m['score'];
    if (s is Map) scoreMap = s.cast<String, dynamic>();
    int homeRuns = 0, homeWkts = 0, awayRuns = 0, awayWkts = 0;
    double homeOvers = 0, awayOvers = 0;
    if (scoreMap != null) {
      final h = scoreMap['home'];
      final a = scoreMap['away'];
      if (h is Map) {
        final hm = h.cast<String, dynamic>();
        homeRuns = ProviderParsing.toInt(hm['runs'] ?? hm['r']);
        homeWkts = ProviderParsing.toInt(hm['wickets'] ?? hm['w']);
        homeOvers = ProviderParsing.toDouble(hm['overs'] ?? hm['o']);
      } else if (h != null) {
        final p = ProviderParsing.parseScoreString(h);
        homeRuns = p.$1;
        homeWkts = p.$2;
      }
      if (a is Map) {
        final am = a.cast<String, dynamic>();
        awayRuns = ProviderParsing.toInt(am['runs'] ?? am['r']);
        awayWkts = ProviderParsing.toInt(am['wickets'] ?? am['w']);
        awayOvers = ProviderParsing.toDouble(am['overs'] ?? am['o']);
      } else if (a != null) {
        final p = ProviderParsing.parseScoreString(a);
        awayRuns = p.$1;
        awayWkts = p.$2;
      }
    }
    return CricketMatch(
      id: ProviderParsing.toStr(m['id'] ?? m['match_id'] ?? m['matchId']),
      teamA: home,
      teamB: away,
      format: ProviderParsing.toStr(m['format'] ?? m['match_type'] ?? 'T20'),
      league: ProviderParsing.toStr(
          m['series'] ?? m['league'] ?? m['competition'] ?? 'International'),
      venueName: ProviderParsing.toStr(m['venue'] ?? ''),
      startTime: DateTime.tryParse(ProviderParsing.toStr(
              m['start_time'] ?? m['date'] ?? m['scheduled_at'] ?? '')) ??
          DateTime.now(),
      status: status,
      scores: [
        TeamScore(
            team: home,
            runs: homeRuns,
            wickets: homeWkts,
            overs: homeOvers,
            batted: homeRuns > 0),
        TeamScore(
            team: away,
            runs: awayRuns,
            wickets: awayWkts,
            overs: awayOvers,
            batted: awayRuns > 0),
      ],
      result: statusRaw,
      lastUpdated: DateTime.now(),
    );
  }

  @override
  Future<bool> testKey() async {
    if (!isConfigured) return false;
    final body = await _getJson('/matches/live');
    return body != null;
  }

  @override
  Future<List<CricketMatch>?> fetchMatches() async {
    final body = await _getJson('/matches/live');
    if (body == null) return null;
    final parsed =
        _list(body).map(_matchFromGeneric).whereType<CricketMatch>().toList();
    if (parsed.isNotEmpty) return parsed;
    // No live matches: try fixtures for upcoming.
    final fix = await _getJson('/fixtures');
    if (fix == null) return null;
    final parsedFix =
        _list(fix).map(_matchFromGeneric).whereType<CricketMatch>().toList();
    return parsedFix.isEmpty ? null : parsedFix;
  }

  @override
  Future<CricketMatch?> fetchScorecard(String matchId) async {
    // Full innings parsing needs the provider's exact scorecard shape;
    // until it is verified against a live response, return the match
    // summary from the scorecard endpoint if it parses as a match,
    // otherwise null (orchestrator uses CricAPI / cache).
    final body = await _getJson('/matches/$matchId/scorecard');
    if (body == null) return null;
    final data = (body['data'] as Map?)?.cast<String, dynamic>() ?? body;
    return _matchFromGeneric(data);
  }

  @override
  Future<List<Map<String, dynamic>>?> fetchSeries() async {
    // No series-list endpoint documented; series detail needs an id.
    return null;
  }

  @override
  Future<Player?> fetchPlayer(String playerId) async {
    final body = await _getJson('/players/$playerId');
    if (body == null) return null;
    final data = (body['data'] as Map?)?.cast<String, dynamic>() ?? body;
    final name = ProviderParsing.toStr(data['name'] ?? data['full_name']);
    if (name.isEmpty) return null;
    return Player(
      id: playerId,
      name: name,
      team: ProviderParsing.toStr(data['team'] ?? ''),
      role: ProviderParsing.toStr(data['role'] ?? data['playing_role'] ?? 'Batter'),
      battingStyle:
          ProviderParsing.toStr(data['batting_style'] ?? data['battingStyle'] ?? ''),
      bowlingStyle:
          ProviderParsing.toStr(data['bowling_style'] ?? data['bowlingStyle'] ?? ''),
      dataComplete: false,
      lastUpdated: DateTime.now(),
    );
  }
}
