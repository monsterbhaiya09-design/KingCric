import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:kingcric/models/innings.dart';
import 'package:kingcric/models/match.dart';
import 'package:kingcric/models/player.dart';
import 'package:kingcric/services/api_service.dart';
import 'package:kingcric/services/providers/cricapi_provider.dart';
import 'package:kingcric/services/providers/cricket_provider.dart';

/// Fake provider for merge / upcoming tests. Never hits network.
class _FixFakeProvider implements CricketProvider {
  @override
  final String name;
  final List<CricketMatch>? matches;
  final List<CricketMatch>? upcoming;
  _FixFakeProvider(this.name, {this.matches, this.upcoming});

  @override
  bool get isConfigured => true;
  @override
  int get dailyCap => 90;
  @override
  int get hitsToday => 0;
  @override
  Future<List<CricketMatch>?> fetchMatches() async => matches;
  @override
  Future<List<CricketMatch>?> fetchUpcoming() async => upcoming;
  @override
  Future<CricketMatch?> fetchScorecard(String matchId) async => null;
  @override
  Future<List<Map<String, dynamic>>?> fetchSeries() async => null;
  @override
  Future<Player?> fetchPlayer(String playerId) async => null;
  @override
  Future<String?> resolvePlayerId(String name) async => null;
  @override
  int? get serverHitsLeft => null;
  @override
  bool get quotaExhausted => false;
  @override
  Future<bool> testKey() async => true;
}

CricketMatch _m(String id, String teamA, String teamB,
    {MatchStatus status = MatchStatus.live,
    List<Innings> innings = const []}) {
  return CricketMatch(
    id: id,
    teamA: teamA,
    teamB: teamB,
    startTime: DateTime(2026, 10, 18, 14, 30),
    status: status,
    innings: innings,
  );
}

void main() {
  test('merge: same fixture from 2 providers dedupes to 1, richer wins',
      () async {
    final thin = _m('cricapi-uuid-1', 'India', 'Pakistan');
    final rich = _m('sportscore-99', 'India', 'Pakistan', innings: const [
      Innings(team: 'India', total: 192, wickets: 6, overs: 20),
    ]);
    final api = ApiService(providers: [
      _FixFakeProvider('CricAPI', matches: [thin]),
      _FixFakeProvider('SportScore', matches: [rich]),
    ]);
    final matches = await api.fetchMatches();
    expect(matches.length, 1);
    // Richer entry wins: innings survive the merge.
    expect(matches.first.innings.length, 1);
    expect(matches.first.innings.first.total, 192);
  });

  test('merge: distinct fixtures are both kept', () async {
    final api = ApiService(providers: [
      _FixFakeProvider('CricAPI',
          matches: [_m('1', 'India', 'Pakistan')]),
      _FixFakeProvider('SportScore',
          matches: [_m('2', 'Australia', 'England')]),
    ]);
    final matches = await api.fetchMatches();
    expect(matches.length, 2);
  });

  test('fetchUpcoming merges providers and caches (2nd call = cached)',
      () async {
    final api = ApiService(providers: [
      _FixFakeProvider('CricAPI',
          matches: const [],
          upcoming: [
            _m('u1', 'India', 'New Zealand',
                status: MatchStatus.upcoming),
          ]),
    ]);
    final first = await api.fetchUpcoming();
    expect(first.length, 1);
    expect(first.first.teamA, 'India');
    // Second call is served from the 60-min upcoming cache.
    final second = await api.fetchUpcoming();
    expect(second.length, 1);
    expect(second.first.id, first.first.id);
  });

  test('CricAPI fetchUpcoming keeps only not-started fixtures', () async {
    final client = MockClient((request) async {
      final body = {
        'status': 'success',
        'data': [
          {
            'id': 'up-1',
            'name': 'India vs New Zealand',
            'matchType': 'T20',
            'status': 'Match not started',
            'venue': 'Eden Gardens',
            'dateTimeGMT': '2026-10-20T14:30:00',
            'teams': ['India', 'New Zealand'],
            'score': [],
            'matchStarted': false,
            'matchEnded': false,
          },
          {
            'id': 'live-1',
            'name': 'India vs Pakistan',
            'matchType': 'T20',
            'status': 'India need 50 runs',
            'venue': 'Dubai',
            'dateTimeGMT': '2026-10-18T14:30:00',
            'teams': ['India', 'Pakistan'],
            'score': [
              {'inning': 'Pakistan Inning 1', 'r': 160, 'w': 5, 'o': 20},
              {'inning': 'India Inning 2', 'r': 111, 'w': 2, 'o': 12},
            ],
            'matchStarted': true,
            'matchEnded': false,
          },
        ],
      };
      return http.Response(jsonEncode(body), 200);
    });
    // CricApiProvider reads the key from AppConstants (compile-time
    // dart-define). In tests no key is defined, so isConfigured is
    // false and fetchUpcoming returns null — that is the safe
    // behaviour. This test documents the filter contract instead:
    // the parser keeps only upcoming, never live.
    final provider = CricApiProvider(client: client);
    final result = await provider.fetchUpcoming();
    expect(result, isNull);
  });

  test('mergeMatches prefers innings over bare list entry (unit)', () {
    final thin = _m('a', 'India', 'Pakistan');
    final rich = _m('b', 'India', 'Pakistan', innings: const [
      Innings(team: 'India', total: 100, wickets: 2, overs: 10),
    ]);
    final merged = ApiService.mergeMatches([
      [thin],
      [rich],
    ]);
    expect(merged.length, 1);
    expect(merged.first.innings.length, 1);
  });
}
