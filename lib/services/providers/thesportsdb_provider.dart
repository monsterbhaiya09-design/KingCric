import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/match.dart';
import '../../models/player.dart';
import '../../utils/constants.dart';
import 'cricket_provider.dart';

/// METADATA provider: TheSportsDB (thesportsdb.com).
/// Free JSON sports API. Free test key "123" is their documented
/// public test key; a personal key (free registration, ~500 calls/day
/// reported) can be passed via --dart-define=SPORTSDB_API_KEY=...
/// Premium ($9/mo) adds 2-min livescores + V2 — NOT used; we stay free.
///
/// What it is good for: schedules / fixtures, results, team badges,
/// logos, player images + bios, league lists, venues.
/// What it is NOT: real-time ball-by-ball. Free livescore is delayed,
/// so this provider is a metadata + schedule backstop, never the
/// primary live-score source.
///
/// Documented V1 endpoints used:
/// - livescore.php?s=Cricket (live events)
/// - eventsnextleague.php?id=<leagueId> / eventslastleague.php
/// - search_all_leagues.php?s=Cricket (series/league list)
/// - lookupplayer.php?id= / searchplayers.php?p=
/// - lookupteam.php?id= (badges)
class TheSportsDbProvider implements CricketProvider {
  final http.Client _client;
  int _hits = 0;

  TheSportsDbProvider({http.Client? client})
      : _client = client ?? http.Client();

  @override
  String get name => 'TheSportsDB';

  @override
  bool get isConfigured => true; // test key "123" always available

  @override
  int get dailyCap => AppConstants.sportsDbDailyCap;

  @override
  int get hitsToday => _hits;

  bool get _capped => _hits >= dailyCap;

  Uri _uri(String endpoint) => Uri.parse(
      '${AppConstants.sportsDbBaseUrl}/${AppConstants.sportsDbApiKey}/$endpoint');

  Future<Map<String, dynamic>?> _getJson(Uri uri) async {
    if (_capped) return null;
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

  List<Map<String, dynamic>> _events(Map<String, dynamic> body) {
    for (final key in ['events', 'teams', 'players']) {
      final v = body[key];
      if (v is List) {
        return v.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
      }
    }
    return [];
  }

  CricketMatch? _matchFromEvent(Map<String, dynamic> e) {
    final home = ProviderParsing.toStr(e['strHomeTeam']);
    final away = ProviderParsing.toStr(e['strAwayTeam']);
    if (home.isEmpty || away.isEmpty) return null;
    final statusRaw = ProviderParsing.toStr(
        e['strStatus'] ?? e['strProgress'] ?? '');
    final status = ProviderParsing.statusFromText(statusRaw);
    final homeScore = ProviderParsing.parseScoreString(e['intHomeScore']);
    final awayScore = ProviderParsing.parseScoreString(e['intAwayScore']);
    final dateStr = ProviderParsing.toStr(e['dateEvent']);
    final timeStr = ProviderParsing.toStr(e['strTime']);
    DateTime start = DateTime.now();
    if (dateStr.isNotEmpty) {
      start = DateTime.tryParse(
              timeStr.isNotEmpty ? '$dateStr $timeStr' : dateStr) ??
          start;
    }
    return CricketMatch(
      id: ProviderParsing.toStr(e['idEvent']),
      teamA: home,
      teamB: away,
      format: ProviderParsing.toStr(e['strSport'] ?? 'Cricket') == 'Cricket'
          ? 'T20'
          : ProviderParsing.toStr(e['strSport'] ?? 'T20'),
      league: ProviderParsing.toStr(e['strLeague'] ?? 'International'),
      venueName: ProviderParsing.toStr(e['strVenue'] ?? ''),
      startTime: start,
      status: status,
      scores: [
        TeamScore(
            team: home,
            runs: homeScore.$1,
            wickets: homeScore.$2,
            batted: homeScore.$1 > 0),
        TeamScore(
            team: away,
            runs: awayScore.$1,
            wickets: awayScore.$2,
            batted: awayScore.$1 > 0),
      ],
      result: statusRaw,
      lastUpdated: DateTime.now(),
    );
  }

  @override
  Future<bool> testKey() async {
    final body =
        await _getJson(_uri('search_all_leagues.php?s=Cricket'));
    return body != null;
  }

  @override
  Future<List<CricketMatch>?> fetchMatches() async {
    if (_capped) return null;
    // Live first, then next fixtures as a schedule backstop.
    final live = await _getJson(_uri('livescore.php?s=Cricket'));
    final parsed = <CricketMatch>[];
    if (live != null) {
      for (final e in _events(live)) {
        final m = _matchFromEvent(e);
        if (m != null) parsed.add(m);
      }
    }
    if (parsed.isNotEmpty) return parsed;
    // No live events: return upcoming fixtures from a generic search.
    final next =
        await _getJson(_uri('searchevents.php?e=Cricket'));
    if (next != null) {
      for (final e in _events(next)) {
        final m = _matchFromEvent(e);
        if (m != null) parsed.add(m);
      }
    }
    return parsed.isEmpty ? null : parsed;
  }

  @override
  Future<CricketMatch?> fetchScorecard(String matchId) async {
    // TheSportsDB has no full innings scorecard (batting/bowling) in
    // the free V1 API. Null -> orchestrator uses CricAPI / cache.
    return null;
  }

  @override
  Future<List<Map<String, dynamic>>?> fetchSeries() async {
    if (_capped) return null;
    final body =
        await _getJson(_uri('search_all_leagues.php?s=Cricket'));
    if (body == null) return null;
    final leagues = _events(body);
    final parsed = <Map<String, dynamic>>[];
    for (final l in leagues) {
      final name = ProviderParsing.toStr(l['strLeague']);
      if (name.isEmpty) continue;
      parsed.add({
        'id': ProviderParsing.toStr(l['idLeague']),
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
    if (_capped) return null;
    // playerId is our internal id; TheSportsDB needs its own numeric
    // id or a name search. Try lookup by id, then fall back to null
    // (orchestrator keeps the curated profile).
    final body = await _getJson(_uri('lookupplayer.php?id=$playerId'));
    if (body == null) return null;
    final players = _events(body);
    if (players.isEmpty) return null;
    final p = players.first;
    final name = ProviderParsing.toStr(p['strPlayer']);
    if (name.isEmpty) return null;
    return Player(
      id: playerId,
      name: name,
      team: ProviderParsing.toStr(p['strTeam'] ?? ''),
      role: ProviderParsing.toStr(p['strPosition'] ?? 'Batter'),
      country: ProviderParsing.toStr(p['strNationality'] ?? ''),
      dataComplete: false,
      lastUpdated: DateTime.now(),
    );
  }
}
