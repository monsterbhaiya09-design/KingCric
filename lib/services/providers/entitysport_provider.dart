import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/match.dart';
import '../../models/player.dart';
import '../../utils/constants.dart';
import 'cricket_provider.dart';

/// TERTIARY provider: EntitySport (rest.entitysport.com/v2).
/// Auth: `?token=` query param.
/// Free offer: a FREE DEV TOKEN for testing (published on EntitySport's
/// own docs). It covers a few completed competitions + sample responses
/// per API — NOT full live coverage, NOT player search / profile / stats.
/// Full live coverage is paid (Starter $150/mo+), which we do NOT use.
/// The dev/sample token is NEVER hard-coded here: pass your own token
/// via --dart-define=ENTITYSPORT_API_KEY=... (get one from the
/// EntitySport dashboard / docs). Without a token this provider is
/// skipped entirely.
///
/// Documented endpoints used (token in query):
/// - GET /matches?token= (+ /matches/{id}/live, /matches/{id}/info)
/// - GET /players/{id}/stats?token= (paid plans; dev token excludes it
///   — returns null, orchestrator keeps curated profile)
/// - GET /competitions?token= (series list)
/// Response envelope: {status:"ok", response:{items:[...]}} or {data:...}.
class EntitySportProvider implements CricketProvider {
  final http.Client _client;
  int _hits = 0;

  EntitySportProvider({http.Client? client})
      : _client = client ?? http.Client();

  @override
  String get name => 'EntitySport';

  @override
  bool get isConfigured => AppConstants.entitySportApiKey.isNotEmpty;

  @override
  int get dailyCap => AppConstants.entitySportDailyCap;

  @override
  int get hitsToday => _hits;

  bool get _capped => _hits >= dailyCap;

  Uri _uri(String path) => Uri.parse(
      '${AppConstants.entitySportBaseUrl}$path?token=${AppConstants.entitySportApiKey}');

  Future<Map<String, dynamic>?> _getJson(Uri uri) async {
    if (!isConfigured || _capped) return null;
    _hits++;
    try {
      final res = await _client
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return null;
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (_) {
      return null;
    }
  }

  List<Map<String, dynamic>> _items(Map<String, dynamic> body) {
    final response = body['response'];
    if (response is Map) {
      final items = response['items'];
      if (items is List) {
        return items.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
      }
      return [response.cast<String, dynamic>()];
    }
    for (final key in ['data', 'matches', 'items']) {
      final v = body[key];
      if (v is List) {
        return v.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
      }
      if (v is Map) return [v.cast<String, dynamic>()];
    }
    return [];
  }

  CricketMatch? _matchFromGeneric(Map<String, dynamic> m) {
    // EntitySport namings: teama/teamb or teams, title "A vs B".
    final teama = (m['teama'] as Map?)?.cast<String, dynamic>();
    final teamb = (m['teamb'] as Map?)?.cast<String, dynamic>();
    String home = ProviderParsing.toStr(teama?['short_name'] ?? teama?['name']);
    String away = ProviderParsing.toStr(teamb?['short_name'] ?? teamb?['name']);
    if (home.isEmpty || away.isEmpty) {
      final title = ProviderParsing.toStr(m['title'] ?? m['name'] ?? '');
      final parts = title.split(' vs ');
      if (parts.length == 2) {
        home = parts[0].trim();
        away = parts[1].trim();
      }
    }
    if (home.isEmpty || away.isEmpty) return null;
    home = ProviderParsing.titleCaseTeam(home);
    away = ProviderParsing.titleCaseTeam(away);
    final statusRaw = ProviderParsing.toStr(
        m['status_str'] ?? m['status'] ?? m['match_status'] ?? '');
    final status = ProviderParsing.statusFromText(statusRaw);
    // Scores: nested {teama:{scores...}, teamb:{...}} or flat.
    int runsOf(Map<String, dynamic>? team) {
      if (team == null) return 0;
      final scores = team['scores'];
      if (scores is String) return ProviderParsing.parseScoreString(scores).$1;
      if (scores is Map) {
        return ProviderParsing.toInt(
            scores.cast<String, dynamic>()['runs']);
      }
      return ProviderParsing.toInt(team['runs']);
    }

    int wktsOf(Map<String, dynamic>? team) {
      if (team == null) return 0;
      final scores = team['scores'];
      if (scores is String) return ProviderParsing.parseScoreString(scores).$2;
      if (scores is Map) {
        return ProviderParsing.toInt(
            scores.cast<String, dynamic>()['wickets']);
      }
      return ProviderParsing.toInt(team['wickets']);
    }

    return CricketMatch(
      id: ProviderParsing.toStr(m['match_id'] ?? m['id'] ?? ''),
      teamA: home,
      teamB: away,
      format: ProviderParsing.toStr(m['format_str'] ?? m['format'] ?? 'T20'),
      league: ProviderParsing.toStr(
          (m['competition'] as Map?)?.cast<String, dynamic>()['title'] ??
              m['series'] ??
              'International'),
      venueName: ProviderParsing.toStr(
          (m['venue'] as Map?)?.cast<String, dynamic>()['name'] ?? m['venue'] ?? ''),
      startTime: DateTime.tryParse(ProviderParsing.toStr(
              m['date_start'] ?? m['start_time'] ?? m['date'] ?? '')) ??
          DateTime.now(),
      status: status,
      scores: [
        TeamScore(
            team: home, runs: runsOf(teama), wickets: wktsOf(teama),
            batted: runsOf(teama) > 0),
        TeamScore(
            team: away, runs: runsOf(teamb), wickets: wktsOf(teamb),
            batted: runsOf(teamb) > 0),
      ],
      result: ProviderParsing.toStr(m['result'] ?? statusRaw),
      lastUpdated: DateTime.now(),
    );
  }

  @override
  Future<bool> testKey() async {
    if (!isConfigured) return false;
    final body = await _getJson(_uri('/matches'));
    return body != null;
  }

  @override
  @override
  Future<List<CricketMatch>?> fetchMatches() async {
    final body = await _getJson(_uri('/matches'));
    if (body == null) return null;
    final parsed =
        _items(body).map(_matchFromGeneric).whereType<CricketMatch>().toList();
    return parsed.isEmpty ? null : parsed;
  }

  // No dedicated fixtures endpoint used: /matches covers it.
  // (Implements requires an explicit override; base default is
  // not inherited through `implements`.)
  @override
  Future<List<CricketMatch>?> fetchUpcoming() async => null;

  @override
  Future<CricketMatch?> fetchScorecard(String matchId) async {
    final body = await _getJson(_uri('/matches/$matchId/info'));
    if (body == null) return null;
    final items = _items(body);
    if (items.isEmpty) return null;
    return _matchFromGeneric(items.first);
  }

  @override
  Future<List<Map<String, dynamic>>?> fetchSeries() async {
    final body = await _getJson(_uri('/competitions'));
    if (body == null) return null;
    final parsed = <Map<String, dynamic>>[];
    for (final c in _items(body)) {
      final name = ProviderParsing.toStr(c['title'] ?? c['name']);
      if (name.isEmpty) continue;
      parsed.add({
        'id': ProviderParsing.toStr(c['cid'] ?? c['id'] ?? ''),
        'name': name,
        'startDate': '',
        'endDate': '',
        'matches': 0,
      });
    }
    return parsed.isEmpty ? null : parsed;
  }

  @override
  Future<Player?> fetchPlayer(String playerId) async {
    // Dev token explicitly excludes player search/profile/stats.
    // Return null so the orchestrator keeps the curated profile.
    return null;
  }
}
