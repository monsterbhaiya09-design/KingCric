import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../models/match.dart';
import '../../models/player.dart';
import '../../utils/constants.dart';
import 'cricket_provider.dart';

/// BACKSTOP provider: SportScore (sportscore.com).
/// Free, NO API key, CORS-open, ~10,000 req/24h/IP.
/// Public endpoints live under /api/widget/ and cover cricket live
/// scores, fixtures, standings, top scorers, player stats.
/// FREE-TIER CONDITION: every surface rendering SportScore data must
/// show a visible "Powered by SportScore" attribution
/// (see API-SETUP.md §2). The constant
/// [AppConstants.sportScoreAttribution] carries that text.
///
/// Exact widget path shapes are not pinned here on purpose: the
/// provider tries the documented candidate paths and returns null when
/// none answers with a parseable list, so a path change can never
/// break the app — the orchestrator just falls through to the next
/// provider / cache / mock.
class SportScoreProvider implements CricketProvider {
  final http.Client _client;
  int _hits = 0;

  SportScoreProvider({http.Client? client})
      : _client = client ?? http.Client();

  @override
  String get name => 'SportScore';

  @override
  bool get isConfigured => true; // keyless

  @override
  int get dailyCap => AppConstants.sportScoreDailyCap;

  @override
  int get hitsToday => _hits;

  bool get _capped => _hits >= dailyCap;

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
      if (decoded is List) return {'data': decoded};
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Extract a list of match-ish maps from any envelope shape.
  List<Map<String, dynamic>> _matchList(Map<String, dynamic> body) {
    for (final key in ['data', 'matches', 'events', 'results', 'items']) {
      final v = body[key];
      if (v is List) {
        return v.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
      }
    }
    return [];
  }

  CricketMatch? _matchFromGeneric(Map<String, dynamic> m) {
    // Accept many field namings; require two team names to count.
    final home = ProviderParsing.titleCaseTeam(ProviderParsing.toStr(
        m['home_team'] ?? m['homeTeam'] ?? m['teamA'] ?? m['team1'] ?? ''));
    final away = ProviderParsing.titleCaseTeam(ProviderParsing.toStr(
        m['away_team'] ?? m['awayTeam'] ?? m['teamB'] ?? m['team2'] ?? ''));
    if (home.isEmpty || away.isEmpty) return null;
    final statusRaw = ProviderParsing.toStr(
        m['status'] ?? m['state'] ?? m['match_status'] ?? '');
    // Scores: {home: "192/6", away: ...} or score {home, away} or flat.
    final scoreMap = (m['score'] as Map?)?.cast<String, dynamic>();
    final homeScore = ProviderParsing.parseScoreString(
        scoreMap?['home'] ?? m['home_score'] ?? m['homeScore']);
    final awayScore = ProviderParsing.parseScoreString(
        scoreMap?['away'] ?? m['away_score'] ?? m['awayScore']);
    // MAIN-CORE FIX: resolve with the REAL hasScores. The old
    // statusFromText always passed hasScores=false, so a live
    // backstop match with a non-keyword status ("1st innings")
    // was parsed as upcoming and only rescued at display time by
    // isEffectivelyLive — its status field stayed wrong for the
    // merge, the pill and the TTL. Scores + no result = live.
    final status = ProviderParsing.resolveStatus(
      raw: statusRaw,
      hasScores: ProviderParsing.scoresPresent(
              runs: homeScore.$1,
              wickets: homeScore.$2,
              overs: ProviderParsing.toDouble(m['home_overs'])) ||
          ProviderParsing.scoresPresent(
              runs: awayScore.$1,
              wickets: awayScore.$2,
              overs: ProviderParsing.toDouble(m['away_overs'])),
    );
    final scores = <TeamScore>[];
    if (homeScore.$1 > 0 || status != MatchStatus.upcoming) {
      scores.add(TeamScore(
          team: home,
          runs: homeScore.$1,
          wickets: homeScore.$2,
          overs: ProviderParsing.toDouble(m['home_overs']),
          batted: homeScore.$1 > 0));
    }
    if (awayScore.$1 > 0 || status != MatchStatus.upcoming) {
      scores.add(TeamScore(
          team: away,
          runs: awayScore.$1,
          wickets: awayScore.$2,
          overs: ProviderParsing.toDouble(m['away_overs']),
          batted: awayScore.$1 > 0));
    }
    return CricketMatch(
      id: ProviderParsing.toStr(
          m['id'] ?? m['match_id'] ?? m['matchId'] ?? '$home-$away'),
      teamA: home,
      teamB: away,
      format: ProviderParsing.toStr(m['format'] ?? m['match_type'] ?? 'T20'),
      league: ProviderParsing.toStr(
          m['league'] ?? m['competition'] ?? m['tournament'] ?? 'International'),
      venueName: ProviderParsing.toStr(m['venue'] ?? m['stadium'] ?? ''),
      startTime: DateTime.tryParse(ProviderParsing.toStr(
              m['start_time'] ?? m['date'] ?? m['kickoff'] ?? '')) ??
          DateTime.now(),
      status: status,
      scores: scores,
      result: ProviderParsing.toStr(m['status'] ?? ''),
      lastUpdated: DateTime.now(),
      source: 'SportScore',
    );
  }

  @override
  Future<bool> testKey() async {
    // Keyless: true when any candidate endpoint answers.
    final r = await fetchMatches();
    return r != null;
  }

  @override
  @override
  Future<List<CricketMatch>?> fetchMatches() async {
    if (_capped) return null;
    // Candidate widget paths (first parseable win). All are under the
    // documented /api/widget/ prefix.
    for (final path in [
      'cricket/matches',
      'cricket/live',
      'matches?sport=cricket',
    ]) {
      final body = await _getJson(
          Uri.parse('${AppConstants.sportScoreBaseUrl}/$path'));
      if (body == null) continue;
      final received = _matchList(body);
      final parsed = received
          .map(_matchFromGeneric)
          .whereType<CricketMatch>()
          .toList();
      debugPrint('KingCric [SportScore] fetchMatches: path=$path received=${received.length} dropped=${received.length - parsed.length} kept=${parsed.length}');
      if (parsed.isNotEmpty) return parsed;
    }
    return null;
  }

  // No stable fixtures endpoint: fetchMatches already covers
  // fixtures via its candidate paths.
  // (Implements requires an explicit override; base default is
  // not inherited through `implements`.)
  @override
  Future<List<CricketMatch>?> fetchUpcoming() async => null;

  @override
  Future<CricketMatch?> fetchScorecard(String matchId) async {
    // SportScore has no documented full innings scorecard in the
    // widget API; score summaries come via fetchMatches. Returning
    // null lets the orchestrator use CricAPI / cached detail.
    return null;
  }

  @override
  Future<List<Map<String, dynamic>>?> fetchSeries() async {
    // Widget API exposes standings / leagues per sport; no stable
    // series list to map. Null -> orchestrator falls back.
    return null;
  }

  @override
  /// FIX-7: no name->id lookup, no server quota reporting.
  @override
  Future<String?> resolvePlayerId(String name) async => null;

  @override
  int? get serverHitsLeft => null;

  @override
  bool get quotaExhausted => false;

  @override
  Future<Player?> fetchPlayer(String playerId) async {
    if (_capped) return null;
    final body = await _getJson(Uri.parse(
        '${AppConstants.sportScoreBaseUrl}/cricket/player/$playerId'));
    if (body == null) return null;
    final data = (body['data'] as Map?)?.cast<String, dynamic>() ?? body;
    final name = ProviderParsing.toStr(data['name'] ?? data['player_name']);
    if (name.isEmpty) return null;
    return Player(
      id: playerId,
      name: name,
      team: ProviderParsing.toStr(data['team'] ?? ''),
      role: ProviderParsing.toStr(data['position'] ?? data['role'] ?? 'Batter'),
      dataComplete: false,
      source: 'sportscore',
      lastUpdated: DateTime.now(),
    );
  }
}
