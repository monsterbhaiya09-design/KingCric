// SQUAD SC — live-scorecard regression tests.
//
// The bug (proven by 2026-10-24 user screenshots, Namibia vs
// Ireland live): Home Live shows a CricAPI match with real totals
// (Namibia 321/6, 50.0 ov, Innings Break) but the Match Detail
// Scorecard tab says "Scorecard not available yet" and Retry does
// nothing. These tests replay that shape with mocked payloads:
// totals-only currentMatches + a /cricketScore that returns
// nothing, fails, or arrives in a variant shape must NEVER yield
// an empty scorecard tab.
//
// Run with: flutter test test/squad_sc_scorecard_test.dart
//   --dart-define=CRIC_API_KEY=test   (CricApiProvider is key-gated)
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kingcric/models/match.dart';
import 'package:kingcric/models/innings.dart';
import 'package:kingcric/models/player.dart';
import 'package:kingcric/services/api_service.dart';
import 'package:kingcric/services/providers/cricapi_provider.dart';
import 'package:kingcric/services/providers/cricket_provider.dart';
import 'package:kingcric/utils/constants.dart';

// ------------------------------------------------------------------
// Fixtures — the exact bug shape: NAM 321/6 (50.0 ov), Innings Break,
// second innings not started, so the list payload carries ONE score
// row and the scorecard endpoint may carry nothing at all.
// ------------------------------------------------------------------

Map<String, dynamic> _listMatch({
  String id = 'nam-ire-1',
  List<Map<String, dynamic>>? score,
}) =>
    {
      'id': id,
      'teams': ['Namibia', 'Ireland'],
      'matchType': 'odi',
      'series': 'International',
      'venue': 'Windhoek',
      'dateTimeGMT': '2026-10-24T13:00:00.000Z',
      'status': 'Innings Break',
      'matchStarted': true,
      'matchEnded': false,
      'score': score ??
          [
            {'inning': 'Namibia Inning 1', 'r': 321, 'w': 6, 'o': 50.0},
          ],
    };

Map<String, dynamic> _fullScorecard({
  String id = 'nam-ire-1',
  bool weird = false,
}) {
  final batting = weird
      ? [
          {
            'batter': {'id': 'p1', 'name': 'Jan Nicol Loftie-Eaton'},
            'r': '80',
            'b': 50,
            '4s': 6,
            '6s': 3,
            'dismissal': '',
          },
          {
            'batter': 'MG Erasmus',
            'r': 45,
            'b': 30,
            '4s': 4,
            '6s': 1,
            'dismissal': 'c Adair b McBrine',
          },
        ]
      : [
          {
            'batter': 'Jan Nicol Loftie-Eaton',
            'r': 80,
            'b': 50,
            '4s': 6,
            '6s': 3,
            'dismissal': '',
          },
          {
            'batter': 'MG Erasmus',
            'r': 45,
            'b': 30,
            '4s': 4,
            '6s': 1,
            'dismissal': 'c Adair b McBrine',
          },
        ];
  final bowling = weird
      ? [
          {
            'bowler': 'Mark Adair',
            'o': 10,
            'm': 0,
            'r': 55,
            'w': 2,
            'eco': '5.50',
            'wd': 1,
            'nb': 0,
          },
        ]
      : [
          {
            'bowler': 'Mark Adair',
            'o': 10,
            'm': 0,
            'r': 55,
            'w': 2,
            'eco': 5.5,
            'wd': 1,
            'nb': 0,
          },
        ];
  return {
    ..._listMatch(id: id),
    'scorecard': [
      {
        'inning': 'Namibia Inning 1',
        'total': weird ? '321' : 321,
        'wickets': 6,
        'overs': 50.0,
        'batting': batting,
        'bowling': bowling,
        'extras': {'r': weird ? '12' : 12, 'wd': 5, 'nb': 1},
        'fallofwickets': [
          {
            'name': 'MG Erasmus',
            'score': 120,
            // Numeric over — the old `as String?` cast threw here
            // and dropped the whole innings.
            'over': weird ? 18.2 : '18.2',
          },
        ],
      },
    ],
  };
}

/// Builds a CricAPI MockClient. [scorecard] answers /cricketScore;
/// null means the endpoint fails for every id.
MockClient _cricClient({
  http.Response Function(Uri url)? scorecard,
  Map<String, dynamic>? listOverride,
}) {
  return MockClient((request) async {
    final url = request.url;
    if (url.path.contains('currentMatches')) {
      return http.Response(
        jsonEncode({
          'status': 'success',
          'info': {'hitsLeft': 99},
          'data': [listOverride ?? _listMatch()],
        }),
        200,
      );
    }
    if (url.path.contains('cricketScore')) {
      if (scorecard != null) return scorecard(url);
      return http.Response(jsonEncode({'status': 'failure'}), 200);
    }
    return http.Response('not found', 404);
  });
}

http.Response _envelope(Object? data) => http.Response(
      jsonEncode({
        'status': 'success',
        'info': {'hitsLeft': 99},
        'data': data,
      }),
      200,
    );

class _FakeProvider implements CricketProvider {
  @override
  final String name;
  List<CricketMatch>? matches;

  _FakeProvider(this.name, {this.matches});

  @override
  bool get isConfigured => true;
  @override
  int get dailyCap => 90;
  @override
  int get hitsToday => 0;
  @override
  Future<List<CricketMatch>?> fetchMatches() async => matches;
  @override
  Future<List<CricketMatch>?> fetchUpcoming() async => null;
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

CricketMatch _fakeForeignCopy() => CricketMatch(
      id: 'ss-999',
      teamA: 'Namibia',
      teamB: 'Ireland',
      format: 'odi',
      league: 'International',
      startTime: DateTime.parse('2026-10-24T13:00:00.000Z'),
      status: MatchStatus.live,
      scores: const [
        TeamScore(team: 'Namibia', runs: 321, wickets: 6, overs: 50, batted: true),
        TeamScore(team: 'Ireland', runs: 120, wickets: 2, overs: 20, batted: true),
      ],
      source: 'SportScore',
    );

void main() {
  final keyConfigured = AppConstants.hasApiKey;

  group('Squad SC — live match must never show an empty scorecard', () {
    test(
      'totals-only list + empty cricketScore -> partial scorecard',
      () async {
        final service = ApiService(
          providers: [
            CricApiProvider(
              client: _cricClient(
                scorecard: (_) => _envelope({}),
              ),
            ),
          ],
          loadCricsheetSample: false,
        );
        final detail = await service.fetchMatchDetail('nam-ire-1');
        expect(detail, isNotNull);
        expect(detail!.innings, hasLength(1));
        expect(detail.innings.first.total, 321);
        expect(detail.innings.first.wickets, 6);
        expect(detail.innings.first.overs, 50.0);
        expect(detail.innings.first.didNotBatNote, contains('Partial'));
      },
      skip: !keyConfigured,
    );

    test(
      'totals-only list + cricketScore status failure -> partial',
      () async {
        final service = ApiService(
          providers: [
            CricApiProvider(client: _cricClient()),
          ],
          loadCricsheetSample: false,
        );
        final detail = await service.fetchMatchDetail('nam-ire-1');
        expect(detail, isNotNull);
        expect(detail!.innings, hasLength(1));
        expect(detail.innings.first.total, 321);
        expect(detail.innings.first.didNotBatNote, contains('Partial'));
      },
      skip: !keyConfigured,
    );

    test(
      'full cricketScore -> full innings + derived batter/bowler',
      () async {
        final service = ApiService(
          providers: [
            CricApiProvider(
              client: _cricClient(
                scorecard: (_) => _envelope(_fullScorecard()),
              ),
            ),
          ],
          loadCricsheetSample: false,
        );
        final detail = await service.fetchMatchDetail('nam-ire-1');
        expect(detail, isNotNull);
        expect(detail!.innings, hasLength(1));
        expect(detail.innings.first.batting, hasLength(2));
        expect(detail.innings.first.bowling, hasLength(1));
        expect(detail.innings.first.didNotBatNote, isEmpty);
        // Live tab rows were ALWAYS blank for real matches (only
        // mock data set them). They must now come from real rows.
        expect(detail.currentBatter, contains('Loftie-Eaton (80*)'));
        expect(detail.currentBowler, 'Mark Adair');
      },
      skip: !keyConfigured,
    );

    test(
      'weird shape (string numbers, nested batter, numeric FOW over, '
      'string eco) still parses',
      () async {
        final service = ApiService(
          providers: [
            CricApiProvider(
              client: _cricClient(
                scorecard: (_) => _envelope(_fullScorecard(weird: true)),
              ),
            ),
          ],
          loadCricsheetSample: false,
        );
        final detail = await service.fetchMatchDetail('nam-ire-1');
        expect(detail, isNotNull);
        expect(detail!.innings, hasLength(1));
        final inn = detail.innings.first;
        expect(inn.total, 321);
        expect(inn.batting.first.playerName, 'Jan Nicol Loftie-Eaton');
        expect(inn.batting.first.runs, 80);
        expect(inn.bowling.first.economy, closeTo(5.5, 0.01));
        expect(inn.fallOfWickets, hasLength(1));
        expect(inn.fallOfWickets.first, contains('18.2'));
      },
      skip: !keyConfigured,
    );

    test(
      'data as a single-match LIST (not a Map) still parses',
      () async {
        final service = ApiService(
          providers: [
            CricApiProvider(
              client: _cricClient(
                scorecard: (_) => _envelope([_fullScorecard()]),
              ),
            ),
          ],
          loadCricsheetSample: false,
        );
        final detail = await service.fetchMatchDetail('nam-ire-1');
        expect(detail, isNotNull);
        expect(detail!.innings, hasLength(1));
        expect(detail.innings.first.batting, hasLength(2));
      },
      skip: !keyConfigured,
    );

    test(
      'foreign id (backstop copy won the merge) -> same-fixture '
      'fallback provider tried, full innings returned',
      () async {
        final service = ApiService(
          providers: [
            CricApiProvider(
              client: _cricClient(
                listOverride: _listMatch(id: 'cric-1'),
                scorecard: (url) {
                  final id = url.queryParameters['id'];
                  if (id == 'cric-1') {
                    return _envelope(_fullScorecard(id: 'cric-1'));
                  }
                  return http.Response(
                    jsonEncode({'status': 'failure'}),
                    200,
                  );
                },
              ),
            ),
            _FakeProvider('SportScore', matches: [_fakeForeignCopy()]),
          ],
          loadCricsheetSample: false,
        );
        // The fake copy (2 meaningful scores) wins the merge over
        // the CricAPI copy (1), so the card id is the foreign one.
        final all = await service.fetchMatches();
        expect(all, isNotEmpty);
        expect(all.first.id, 'ss-999');
        final detail = await service.fetchMatchDetail('ss-999');
        expect(detail, isNotNull);
        expect(detail!.innings, isNotEmpty);
        expect(detail.innings.first.batting, hasLength(2));
      },
      skip: !keyConfigured,
    );

    test(
      'cricketScore 429 -> fetchMatchDetail still returns partial '
      'from the list, not null',
      () async {
        final fake = _FakeProvider('SportScore', matches: [
          CricketMatch(
            id: 'nam-ire-1',
            teamA: 'Namibia',
            teamB: 'Ireland',
            format: 'odi',
            league: 'International',
            startTime: DateTime.parse('2026-10-24T13:00:00.000Z'),
            status: MatchStatus.live,
            scores: const [
              TeamScore(
                  team: 'Namibia', runs: 321, wickets: 6, overs: 50, batted: true),
            ],
            source: 'SportScore',
          ),
        ]);
        final service = ApiService(
          providers: [
            CricApiProvider(
              client: _cricClient(
                scorecard: (_) => http.Response('rate limited', 429),
              ),
            ),
            fake,
          ],
          loadCricsheetSample: false,
        );
        final detail = await service.fetchMatchDetail('nam-ire-1');
        expect(detail, isNotNull);
        expect(detail!.innings, hasLength(1));
        expect(detail.innings.first.total, 321);
        expect(detail.innings.first.didNotBatNote, contains('Partial'));
      },
      skip: !keyConfigured,
    );

    test('withPartialScorecard leaves full and not-started matches alone',
        () {
      final full = CricketMatch(
        id: 'x',
        teamA: 'A',
        teamB: 'B',
        startTime: DateTime.now(),
        status: MatchStatus.live,
        scores: const [
          TeamScore(team: 'A', runs: 100, wickets: 2, overs: 10, batted: true),
        ],
        innings: const [
          Innings(team: 'A', inningsNumber: 1, total: 100, wickets: 2, overs: 10),
        ],
      );
      expect(identical(ApiService.withPartialScorecard(full), full), isTrue);

      final notStarted = CricketMatch(
        id: 'y',
        teamA: 'A',
        teamB: 'B',
        startTime: DateTime.now(),
        status: MatchStatus.upcoming,
      );
      expect(
          ApiService.withPartialScorecard(notStarted).innings, isEmpty);
    });
  });
}
