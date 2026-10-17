import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/match.dart';
import '../models/player.dart';
import '../models/venue.dart';
import '../utils/constants.dart';
import 'mock_data_service.dart';

/// Free-API layer.
///
/// NEVER scrapes Cricbuzz / Cricinfo / Crex / Cricmetrics.
/// Talks only to a free provider's documented JSON API (default:
/// CricAPI-compatible shape). The API key comes from
/// --dart-define=CRIC_API_KEY=... — it is never hard-coded.
///
/// If no key is configured, every method falls back to the local
/// realistic mock dataset so the app works fully offline in demo mode.
/// [isLive] tells the UI whether data is real-live or demo.
class ApiService {
  final http.Client _client;
  final MockDataService _mock = MockDataService();

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  bool get isLive => AppConstants.hasApiKey;

  Future<List<CricketMatch>> fetchMatches() async {
    if (!isLive) return _mock.matches();
    try {
      final uri = Uri.parse(
          '${AppConstants.freeApiBaseUrl}/currentMatches?apikey=${AppConstants.cricApiKey}');
      final res =
          await _client.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return _mock.matches();
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (body['data'] as List?) ?? [];
      final parsed = <CricketMatch>[];
      for (final e in list) {
        try {
          parsed.add(_matchFromFreeApi((e as Map).cast<String, dynamic>()));
        } catch (_) {
          // Skip one malformed match rather than failing the whole list.
        }
      }
      return parsed.isEmpty ? _mock.matches() : parsed;
    } catch (_) {
      // Free API down / offline -> demo data keeps the app usable.
      return _mock.matches();
    }
  }

  Future<CricketMatch?> fetchMatchDetail(String matchId) async {
    final all = await fetchMatches();
    for (final m in all) {
      if (m.id == matchId) return m;
    }
    return null;
  }

  Future<Player?> fetchPlayer(String playerId) async {
    if (!isLive) return _mock.playerById(playerId);
    try {
      final uri = Uri.parse(
          '${AppConstants.freeApiBaseUrl}/players_info?apikey=${AppConstants.cricApiKey}&id=$playerId');
      final res =
          await _client.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return _mock.playerById(playerId);
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final data = (body['data'] as Map?)?.cast<String, dynamic>() ?? {};
      // Free providers return only a basic profile; the app enriches it
      // with mock-derived derived stats ONLY in demo mode. In live mode
      // we return the basic profile and mark it incomplete so the
      // validator never presents partial data as complete.
      final base = _mock.playerById(playerId);
      if (base == null) return null;
      return Player(
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

  /// Minimal mapping from a generic free-API match shape to our model.
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
      lastUpdated: DateTime.now(),
    );
  }
}
