import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:kingcric/models/match.dart';
import 'package:kingcric/models/player.dart';
import 'package:kingcric/services/api_service.dart';
import 'package:kingcric/services/providers/cricapi_provider.dart';
import 'package:kingcric/services/providers/cricket_provider.dart';
import 'package:kingcric/utils/constants.dart';

/// FIX-7 tests. The CricAPI tests need a (dummy) key because the
/// provider gates on `isConfigured`: run with
/// `flutter test --dart-define=CRIC_API_KEY=test`. The HTTP layer is
/// fully mocked (MockClient), so no real network or quota is used.
/// Without the define, those tests skip instead of failing.

bool get _keyConfigured => AppConstants.hasApiKey;

Map<String, dynamic> _upcomingEntry(int i, {String league = 'Asia Cup'}) => {
      'id': 'fix7-m-$i',
      'teams': ['India', 'Pakistan'],
      'matchType': 'T20',
      'series': league,
      'venue': 'Dubai',
      'dateTimeGMT': '2026-10-25T10:00:00',
      'status': 'Match scheduled',
      'matchStarted': false,
      'matchEnded': false,
      'score': [],
    };

CricketMatch _m(String id, String teamA, String teamB,
    {String league = 'Asia Cup',
    String format = 'T20',
    String source = 'CricAPI',
    DateTime? start}) {
  return CricketMatch(
    id: id,
    teamA: teamA,
    teamB: teamB,
    format: format,
    league: league,
    startTime: start ?? DateTime(2026, 10, 24, 14, 30),
    status: MatchStatus.upcoming,
    source: source,
  );
}

void main() {
  // ---------- Fix 1: pagination ----------
  test('fetchUpcoming paginates: 25 + 2 across offset 0 and 25',
      skip: !_keyConfigured, () async {
    final seenOffsets = <String>[];
    final client = MockClient((req) async {
      final offset = req.url.queryParameters['offset'] ?? '?';
      seenOffsets.add(offset);
      final n = offset == '0' ? 25 : 2;
      final start = offset == '0' ? 0 : 25;
      final data = [
        for (var i = start; i < start + n; i++) _upcomingEntry(i),
      ];
      return http.Response(
          jsonEncode({
            'status': 'success',
            'info': {'hitsLeft': 99, 'hitsToday': 1},
            'data': data,
          }),
          200);
    });
    final p = CricApiProvider(client: client);
    final upcoming = await p.fetchUpcoming();
    expect(upcoming, isNotNull);
    expect(upcoming!.length, 27);
    expect(seenOffsets, ['0', '25']);
  });

  test('fetchUpcoming stops when server ignores offset (0 new entries)',
      skip: !_keyConfigured, () async {
    var calls = 0;
    final client = MockClient((req) async {
      calls++;
      final data = [for (var i = 0; i < 25; i++) _upcomingEntry(i)];
      return http.Response(
          jsonEncode({
            'status': 'success',
            'info': {'hitsLeft': 99},
            'data': data,
          }),
          200);
    });
    final p = CricApiProvider(client: client);
    final upcoming = await p.fetchUpcoming();
    expect(upcoming, isNotNull);
    expect(upcoming!.length, 25); // no duplicates from offset loop
    expect(calls, 2); // page 1 full + page 2 all-dupes -> stop
  });

  // ---------- Fix 7/2: server-side quota ----------
  test('quota: info.hitsLeft 0 marks quotaExhausted and stops calls',
      skip: !_keyConfigured, () async {
    var calls = 0;
    final client = MockClient((req) async {
      calls++;
      return http.Response(
          jsonEncode({
            'status': 'success',
            'info': {'hitsLeft': 0, 'hitsToday': 100},
            'data': [],
          }),
          200);
    });
    final p = CricApiProvider(client: client);
    expect(await p.fetchMatches(), isNull);
    expect(p.quotaExhausted, isTrue);
    expect(p.serverHitsLeft, 0);
    expect(await p.fetchUpcoming(), isNull);
    expect(calls, 1); // second call blocked locally, no HTTP
  });

  test('quotaState is keyMissing when no key is compiled in', () {
    final api = ApiService(providers: []);
    if (!_keyConfigured) {
      expect(api.quotaState, QuotaState.keyMissing);
    } else {
      // Key present (test run with --dart-define): never keyMissing.
      expect(api.quotaState, isNot(QuotaState.keyMissing));
    }
  });

  // ---------- Fix 3: player identity ----------
  test('resolvePlayerId returns numeric id only on a name match',
      skip: !_keyConfigured, () async {
    final client = MockClient((req) async {
      if (req.url.path.contains('/players') &&
          !req.url.path.contains('players_info')) {
        // Server returns an unrelated page (search param ignored).
        return http.Response(
            jsonEncode({
              'status': 'success',
              'info': {'hitsLeft': 99},
              'data': [
                {'id': '111', 'name': 'Some Other Player'},
              ],
            }),
            200);
      }
      return http.Response('{"status":"failure"}', 200);
    });
    final p = CricApiProvider(client: client);
    expect(await p.resolvePlayerId('Virat Kohli'), isNull);
  });

  test('fetchPlayer resolves a name, then reads players_info by id',
      skip: !_keyConfigured, () async {
    final client = MockClient((req) async {
      if (req.url.path.contains('players_info')) {
        expect(req.url.queryParameters['id'], '253802');
        return http.Response(
            jsonEncode({
              'status': 'success',
              'info': {'hitsLeft': 98},
              'data': {
                'id': '253802',
                'name': 'Virat Kohli',
                'role': 'Batter',
                'battingStyle': 'Right-hand bat',
                'bowlingStyle': 'Right-arm medium',
                'country': 'India',
                'stats': [
                  {
                    'fn': 'batting',
                    'matchtype': 'test',
                    'stat': 'runs',
                    'value': '9230',
                  },
                  {
                    'fn': 'batting',
                    'matchtype': 'test',
                    'stat': 'm',
                    'value': '123',
                  },
                ],
              },
            }),
            200);
      }
      if (req.url.path.contains('/players')) {
        return http.Response(
            jsonEncode({
              'status': 'success',
              'info': {'hitsLeft': 99},
              'data': [
                {'id': '253802', 'name': 'Virat Kohli'},
              ],
            }),
            200);
      }
      return http.Response('{"status":"failure"}', 200);
    });
    final p = CricApiProvider(client: client);
    expect(await p.resolvePlayerId('Virat Kohli'), '253802');
    final player = await p.fetchPlayer('Virat Kohli');
    expect(player, isNotNull);
    expect(player!.name, 'Virat Kohli');
    expect(player.id, '253802');
    expect(player.source, 'cricapi');
    expect(player.battingByFormat['Test']!.runs, 9230);
    expect(player.battingByFormat['Test']!.matches, 123);
  });

  test('parseStats handles the nested-map stats shape', () {
    final parsed = CricApiProvider.parseStats({
      'test': {
        'batting': {'matches': 123, 'runs': 9230, 'average': 46.85},
        'bowling': {'matches': 123, 'wickets': 0, 'runs': 0},
      },
      'odi': {
        'batting': {'matches': 10, 'runs': 500},
      },
    });
    expect(parsed.batting['Test']!.runs, 9230);
    expect(parsed.batting['Test']!.average, 46.85);
    expect(parsed.batting['ODI']!.runs, 500);
  });

  // ---------- Fix 5: dedupe ----------
  test('dedupe: same teams + day + format, DIFFERENT leagues kept',
      () {
    final a = _m('prov-1', 'India', 'Pakistan', league: 'Asia Cup');
    final b = _m('prov-2', 'India', 'Pakistan', league: 'World Cup');
    final merged = ApiService.mergeMatches([
      [a, b]
    ], providerNames: ['CricAPI']);
    expect(merged.length, 2);
  });

  test('dedupe: same fixture from 2 providers merges to 1', () {
    final a = _m('cricapi-uuid', 'India', 'Pakistan', league: 'Asia Cup');
    final b = _m('sportscore-99', 'India', 'Pakistan', league: 'Asia Cup');
    final merged = ApiService.mergeMatches([
      [a],
      [b]
    ], providerNames: [
      'CricAPI',
      'SportScore'
    ]);
    expect(merged.length, 1);
  });

  test('dedupe: empty-league entry folds into same fixture with league',
      () {
    final a = _m('cricapi-uuid', 'India', 'Pakistan', league: 'Asia Cup');
    final b = _m('tdb-1', 'India', 'Pakistan', league: '');
    final merged = ApiService.mergeMatches([
      [a],
      [b]
    ], providerNames: [
      'CricAPI',
      'TheSportsDB'
    ]);
    expect(merged.length, 1);
    expect(merged.single.league, 'Asia Cup');
  });

  test('dedupe: same provider, same key, SAME id merges (page overlap)',
      () {
    final a = _m('same-id', 'India', 'Pakistan');
    final b = _m('same-id', 'India', 'Pakistan');
    final merged = ApiService.mergeMatches([
      [a, b]
    ], providerNames: ['CricAPI']);
    expect(merged.length, 1);
  });

  // ---------- Fix 3 (orchestrator): name -> id -> fetch ----------
  test('ApiService.fetchPlayer resolves a name via the provider', () async {
    final fake = _ResolveFakeProvider();
    final api = ApiService(
        providers: [fake], loadCricsheetSample: false, cricsheet: null);
    final player = await api.fetchPlayer('Some Player');
    expect(player, isNotNull);
    expect(player!.name, 'Some Player');
    expect(fake.fetchIds, ['123']);
    // Second call for the same name reuses the cached id (no
    // second resolution).
    await api.fetchPlayer('Some Player');
    expect(fake.resolveCalls, 1);
  });
}

/// Fake provider whose resolvePlayerId maps one name to '123'.
class _ResolveFakeProvider implements CricketProvider {
  @override
  String get name => 'ResolveFake';
  @override
  bool get isConfigured => true;
  @override
  int get dailyCap => 90;
  @override
  int get hitsToday => 0;
  @override
  int? get serverHitsLeft => null;
  @override
  bool get quotaExhausted => false;
  int resolveCalls = 0;
  final List<String> fetchIds = [];

  @override
  Future<List<CricketMatch>?> fetchMatches() async => null;
  @override
  Future<List<CricketMatch>?> fetchUpcoming() async => null;
  @override
  Future<CricketMatch?> fetchScorecard(String matchId) async => null;
  @override
  Future<List<Map<String, dynamic>>?> fetchSeries() async => null;
  @override
  Future<bool> testKey() async => true;

  @override
  Future<String?> resolvePlayerId(String name) async {
    resolveCalls++;
    if (name == 'Some Player') return '123';
    return null;
  }

  @override
  Future<Player?> fetchPlayer(String playerId) async {
    fetchIds.add(playerId);
    if (playerId == '123') {
      return const Player(id: '123', name: 'Some Player', team: 'India');
    }
    return null;
  }
}
