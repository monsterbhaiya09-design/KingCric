import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:kingcric/models/match.dart';
import 'package:kingcric/services/providers/cricapi_provider.dart';
import 'package:kingcric/utils/constants.dart';

/// SQUAD C — CricAPI provider tests. HTTP is fully mocked (MockClient),
/// so no real network or quota is used. The provider gates on
/// `isConfigured`, so run with
/// `flutter test --dart-define=CRIC_API_KEY=test`.
/// Without the define, the provider tests skip instead of failing.

bool get _keyConfigured => AppConstants.hasApiKey;

Map<String, dynamic> _matchEntry({
  required String id,
  required String status,
  bool matchStarted = false,
  bool matchEnded = false,
  List<Map<String, dynamic>> score = const [],
  String matchType = 'T20',
}) =>
    {
      'id': id,
      'teams': ['India', 'Pakistan'],
      'matchType': matchType,
      'series': 'Asia Cup',
      'venue': 'Dubai',
      'dateTimeGMT': '2026-10-25T10:00:00',
      'status': status,
      'matchStarted': matchStarted,
      'matchEnded': matchEnded,
      'score': score,
    };

Map<String, dynamic> _scoreRow(String inning, int r, int w, double o) => {
      'inning': inning,
      'r': r,
      'w': w,
      'o': o,
    };

Map<String, dynamic> _scorecardEnvelope({
  String status = 'Match scheduled',
  String matchWinner = '',
  List<Map<String, dynamic>> score = const [],
}) =>
    {
      'status': 'success',
      'info': {'hitsLeft': 99, 'hitsToday': 1},
      'data': {
        'id': 'sc-1',
        'teams': ['India', 'Pakistan'],
        'matchType': 'T20',
        'series': 'Asia Cup',
        'venue': 'Dubai',
        'dateTimeGMT': '2026-10-25T10:00:00',
        'status': status,
        'matchStarted': true,
        'matchEnded': matchWinner.isNotEmpty,
        'matchWinner': matchWinner,
        'score': score,
        'scorecard': [
          {
            'inning': 'India Inning 1',
            'total': 182,
            'wickets': 6,
            'overs': 20.0,
            'batting': [
              {
                'batter': 'Virat Kohli',
                'r': 72,
                'b': 48,
                '4s': 8,
                '6s': 2,
                'dismissal': 'c Babar b Shaheen',
              },
              {
                'batter': 'Rohit Sharma',
                'r': 45,
                'b': 30,
                '4s': 5,
                '6s': 1,
                'dismissal': '',
              },
            ],
            'bowling': [
              {
                'bowler': 'Shaheen Afridi',
                'o': 4.0,
                'm': 0,
                'r': 38,
                'w': 2,
                'eco': 9.5,
                'wd': 1,
                'nb': 0,
              },
            ],
            'extras': {'r': 5, 'wd': 3, 'nb': 1, 'b': 1},
            'fallofwickets': [
              {'name': 'Rohit Sharma', 'score': 96, 'over': '11.2'},
            ],
          },
        ],
      },
    };

void main() {
  // ---------- (1) fetchMatches: live + recent, real hasScores ----------
  test('fetchMatches hits currentMatches and resolves live via hasScores',
      skip: !_keyConfigured, () async {
    final seenPaths = <String>[];
    final client = MockClient((req) async {
      seenPaths.add(req.url.path);
      return http.Response(
          jsonEncode({
            'status': 'success',
            'info': {'hitsLeft': 99, 'hitsToday': 1},
            'data': [
              // In-progress: "need" text, scores on the board.
              _matchEntry(
                id: 'live-1',
                status: 'India need 24 runs in 18 balls',
                matchStarted: true,
                score: [
                  _scoreRow('Pakistan Inning 1', 160, 7, 20.0),
                  _scoreRow('India Inning 1', 137, 3, 17.0),
                ],
              ),
              // Stale label + scores = live, not upcoming.
              _matchEntry(
                id: 'live-2',
                status: 'Match scheduled',
                matchStarted: true,
                score: [_scoreRow('India Inning 1', 48, 1, 6.0)],
              ),
              // Genuinely not started: no scores.
              _matchEntry(
                id: 'up-1',
                status: 'Match scheduled',
                score: [],
              ),
            ],
          }),
          200);
    });
    final p = CricApiProvider(client: client);
    final matches = await p.fetchMatches();
    expect(matches, isNotNull);
    expect(matches!.length, 3);
    expect(seenPaths, ['/v1/currentMatches']);
    final byId = {for (final m in matches) m.id: m};
    expect(byId['live-1']!.status, MatchStatus.live);
    expect(byId['live-1']!.isEffectivelyLive, isTrue);
    expect(byId['live-2']!.status, MatchStatus.live);
    expect(byId['up-1']!.status, MatchStatus.upcoming);
    expect(byId['up-1']!.isEffectivelyLive, isFalse);
    // Source tag: real provider data must never masquerade as demo.
    expect(matches.every((m) => m.source == 'CricAPI'), isTrue);
  });

  test('fetchMatches returns null on provider failure (no mock inside)',
      skip: !_keyConfigured, () async {
    final client = MockClient((req) async => http.Response(
        jsonEncode({'status': 'failure', 'message': 'bad key'}), 200));
    final p = CricApiProvider(client: client);
    expect(await p.fetchMatches(), isNull);
  });

  // ---------- (2) fetchUpcoming: paginated, not-started only ----------
  test('fetchUpcoming paginates and never leaks live/completed in',
      skip: !_keyConfigured, () async {
    final seenOffsets = <String>[];
    final client = MockClient((req) async {
      final offset = req.url.queryParameters['offset'] ?? '?';
      seenOffsets.add(offset);
      final data = offset == '0'
          ? [
              for (var i = 0; i < 25; i++)
                _matchEntry(id: 'up-$i', status: 'Match scheduled'),
              // Live + completed entries in the fixtures feed: must
              // be dropped, never shown under Upcoming.
              _matchEntry(
                id: 'leak-live',
                status: 'India need 10 runs',
                matchStarted: true,
                score: [_scoreRow('India Inning 1', 120, 2, 15.0)],
              ),
              _matchEntry(
                id: 'leak-done',
                status: 'India won by 5 wickets',
                matchEnded: true,
                score: [_scoreRow('India Inning 1', 180, 5, 20.0)],
              ),
            ]
          : [
              _matchEntry(id: 'up-25', status: 'Match scheduled'),
              _matchEntry(id: 'up-26', status: 'Match scheduled'),
            ];
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
    expect(upcoming!.length, 27);
    expect(seenOffsets, ['0', '25']);
    final ids = upcoming.map((m) => m.id).toSet();
    expect(ids.contains('leak-live'), isFalse);
    expect(ids.contains('leak-done'), isFalse);
    expect(upcoming.every((m) => m.status == MatchStatus.upcoming), isTrue);
    expect(upcoming.every((m) => !m.isEffectivelyLive), isTrue);
  });

  test('fetchUpcoming caps at 5 pages even if server keeps paging',
      skip: !_keyConfigured, () async {
    var calls = 0;
    final client = MockClient((req) async {
      calls++;
      // Every page full of NEW ids: without the cap this never ends.
      final data = [
        for (var i = 0; i < 25; i++)
          _matchEntry(id: 'up-${calls}_$i', status: 'Match scheduled'),
      ];
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
    expect(upcoming!.length, 125);
    expect(calls, 5);
  });

  // ---------- (3) fetchScorecard: list id, full innings ----------
  test('fetchScorecard uses the list id and returns full innings',
      skip: !_keyConfigured, () async {
    String? askedId;
    final client = MockClient((req) async {
      if (req.url.path.contains('cricketScore')) {
        askedId = req.url.queryParameters['id'];
        return http.Response(jsonEncode(_scorecardEnvelope()), 200);
      }
      return http.Response('{"status":"failure"}', 200);
    });
    final p = CricApiProvider(client: client);
    final detail = await p.fetchScorecard('sc-1');
    expect(askedId, 'sc-1');
    expect(detail, isNotNull);
    expect(detail!.innings.length, 1);
    final inn = detail.innings.single;
    expect(inn.team, 'India');
    expect(inn.total, 182);
    expect(inn.batting.length, 2);
    expect(inn.batting[0].playerName, 'Virat Kohli');
    expect(inn.batting[0].runs, 72);
    expect(inn.batting[1].notOut, isTrue);
    expect(inn.bowling.length, 1);
    expect(inn.bowling[0].playerName, 'Shaheen Afridi');
    expect(inn.bowling[0].wickets, 2);
    expect(inn.extrasRuns, 5);
    expect(inn.fallOfWickets.length, 1);
  });

  test('fetchScorecard: stale label + innings = live, winner = completed',
      skip: !_keyConfigured, () async {
    final client = MockClient((req) async => http.Response(
        jsonEncode(_scorecardEnvelope(
            status: 'Match scheduled', matchWinner: '')), 200));
    final p = CricApiProvider(client: client);
    final live = await p.fetchScorecard('sc-1');
    // Envelope says "Match scheduled" but full innings exist: live.
    expect(live!.status, MatchStatus.live);

    final client2 = MockClient((req) async => http.Response(
        jsonEncode(_scorecardEnvelope(
            status: 'Match scheduled', matchWinner: 'India')), 200));
    final p2 = CricApiProvider(client: client2);
    final done = await p2.fetchScorecard('sc-1');
    expect(done!.status, MatchStatus.completed);
    expect(done.result, 'India won');
  });

  // ---------- (4) fetchPlayer: numeric id only, guarded resolve ----------
  test('fetchPlayer calls players_info with the numeric id',
      skip: !_keyConfigured, () async {
    final seen = <Uri>[];
    final client = MockClient((req) async {
      seen.add(req.url);
      return http.Response(
          jsonEncode({
            'status': 'success',
            'info': {'hitsLeft': 98},
            'data': {
              'id': '253802',
              'name': 'Virat Kohli',
              'country': 'India',
              'role': 'Batter',
              'battingStyle': 'Right-hand bat',
              'bowlingStyle': 'Right-arm medium',
              'stats': [],
            },
          }),
          200);
    });
    final p = CricApiProvider(client: client);
    final player = await p.fetchPlayer('253802');
    expect(player, isNotNull);
    expect(player!.name, 'Virat Kohli');
    expect(player.source, 'cricapi');
    expect(seen.length, 1);
    expect(seen.single.path, contains('players_info'));
    expect(seen.single.queryParameters['id'], '253802');
  });

  test('fetchPlayer with a name resolves first, never sends name as id',
      skip: !_keyConfigured, () async {
    final seen = <Uri>[];
    final client = MockClient((req) async {
      seen.add(req.url);
      if (req.url.path.contains('players_info')) {
        return http.Response(
            jsonEncode({
              'status': 'success',
              'info': {'hitsLeft': 98},
              'data': {
                'id': '253802',
                'name': 'Virat Kohli',
                'country': 'India',
                'role': 'Batter',
                'stats': [],
              },
            }),
            200);
      }
      // /players?search= returns the matching entry.
      return http.Response(
          jsonEncode({
            'status': 'success',
            'info': {'hitsLeft': 99},
            'data': [
              {'id': '253802', 'name': 'Virat Kohli'},
            ],
          }),
          200);
    });
    final p = CricApiProvider(client: client);
    final player = await p.fetchPlayer('Virat Kohli');
    expect(player, isNotNull);
    // The id= param on players_info is numeric, never the name.
    final infoCall = seen.firstWhere((u) => u.path.contains('players_info'));
    expect(infoCall.queryParameters['id'], '253802');
  });

  test('resolvePlayerId returns null when search ignores the name',
      skip: !_keyConfigured, () async {
    var infoCalls = 0;
    final client = MockClient((req) async {
      if (req.url.path.contains('players_info')) infoCalls++;
      return http.Response(
          jsonEncode({
            'status': 'success',
            'info': {'hitsLeft': 99},
            'data': [
              {'id': '999', 'name': 'Someone Else Entirely'},
            ],
          }),
          200);
    });
    final p = CricApiProvider(client: client);
    expect(await p.resolvePlayerId('Virat Kohli'), isNull);
    // No wrong-player id => fetchPlayer must not call players_info.
    expect(await p.fetchPlayer('Virat Kohli'), isNull);
    expect(infoCalls, 0);
  });

  // ---------- (5) Quota: info.hitsLeft + 429 ----------
  test('quota: 429 sets quotaExhausted and blocks the next call',
      skip: !_keyConfigured, () async {
    var calls = 0;
    final client = MockClient((req) async {
      calls++;
      return http.Response('Too Many Requests', 429);
    });
    final p = CricApiProvider(client: client);
    expect(await p.fetchMatches(), isNull);
    expect(p.quotaExhausted, isTrue);
    expect(p.serverHitsLeft, 0);
    expect(await p.fetchMatches(), isNull);
    expect(await p.fetchUpcoming(), isNull);
    expect(await p.fetchScorecard('x'), isNull);
    expect(calls, 1); // everything after the 429 is blocked locally
  });

  test('quota: info.hitsLeft is read on every response',
      skip: !_keyConfigured, () async {
    final client = MockClient((req) async => http.Response(
        jsonEncode({
          'status': 'success',
          'info': {'hitsLeft': 42, 'hitsToday': 58},
          'data': [],
        }),
        200));
    final p = CricApiProvider(client: client);
    await p.fetchMatches();
    expect(p.serverHitsLeft, 42);
    expect(p.quotaExhausted, isFalse);
  });

  test('quota: failure message mentioning limit marks quota exhausted',
      skip: !_keyConfigured, () async {
    final client = MockClient((req) async => http.Response(
        jsonEncode({
          'status': 'failure',
          'message': 'Daily quota limit exceeded',
          'info': {'hitsLeft': 5},
        }),
        200));
    final p = CricApiProvider(client: client);
    expect(await p.fetchMatches(), isNull);
    expect(p.quotaExhausted, isTrue);
    expect(p.serverHitsLeft, 0);
  });
}
