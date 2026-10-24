import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:kingcric/models/match.dart';
import 'package:kingcric/services/api_service.dart';
import 'package:kingcric/services/cricsheet_service.dart';
import 'package:kingcric/services/providers/cricapi_provider.dart';
import 'package:kingcric/utils/constants.dart';

/// FINAL D — Data depth, no fakes. Ball-level data is derived ONLY
/// from deliveries a source actually supplied (Cricsheet bundled
/// matches, or a CricAPI payload that carries per-ball events).
/// Totals-only payloads yield empty + hasBallData false — never
/// synthesised balls. Run CricAPI tests with
/// `flutter test --dart-define=CRIC_API_KEY=<redacted> otherwise they skip.

bool get _keyConfigured => AppConstants.hasApiKey;

CricsheetDelivery _d({
  required int innings,
  required int over,
  required String batter,
  required String bowler,
  int batterRuns = 0,
  int total = 0,
  int wides = 0,
  int noBalls = 0,
  String? wicketKind,
  String? playerOut,
}) =>
    CricsheetDelivery(
      matchIndex: 0,
      inningsIndex: innings,
      battingTeam: 'India',
      bowlingTeam: 'Pakistan',
      batter: batter,
      bowler: bowler,
      nonStriker: 'Partner',
      batterRuns: batterRuns,
      extrasRuns: total - batterRuns,
      totalRuns: total,
      wides: wides,
      noBalls: noBalls,
      byes: 0,
      legByes: 0,
      overNumber: over,
      actualDelivery: '$over',
      wicketKind: wicketKind,
      playerOut: playerOut,
    );

CricsheetMatch _csMatch({
  required String date,
  String matchType = 'IT20',
  required List<CricsheetDelivery> deliveries,
}) =>
    CricsheetMatch(
      index: 0,
      dates: [date],
      venue: 'Dubai',
      city: 'Dubai',
      matchType: matchType,
      eventName: 'Asia Cup',
      teams: ['India', 'Pakistan'],
      winner: 'India',
      tossWinner: 'India',
      tossDecision: 'bat',
      playersByTeam: const {},
      deliveries: deliveries,
    );

List<CricsheetDelivery> _twoOvers() => [
      _d(innings: 0, over: 0, batter: 'Rohit', bowler: 'Shaheen',
          batterRuns: 0, total: 0),
      _d(innings: 0, over: 0, batter: 'Rohit', bowler: 'Shaheen',
          batterRuns: 1, total: 1),
      _d(innings: 0, over: 0, batter: 'Rohit', bowler: 'Shaheen',
          batterRuns: 4, total: 4),
      _d(innings: 0, over: 0, batter: 'Rohit', bowler: 'Shaheen',
          batterRuns: 0, total: 0,
          wicketKind: 'bowled', playerOut: 'Rohit'),
      _d(innings: 0, over: 1, batter: 'Virat', bowler: 'Shaheen',
          batterRuns: 0, total: 1, wides: 1),
      _d(innings: 0, over: 1, batter: 'Virat', bowler: 'Shaheen',
          batterRuns: 2, total: 2),
    ];

Map<String, dynamic> _cricScoreEnvelope({
  List<Map<String, dynamic>> scorecard = const [],
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
        'status': 'India need 10 runs',
        'matchStarted': true,
        'matchEnded': false,
        'score': [
          {'inning': 'India Inning 1', 'r': 8, 'w': 1, 'o': 1.2},
        ],
        'scorecard': scorecard,
      },
    };

void main() {
  group('Cricsheet ball data (derived from real deliveries)', () {
    test('over summaries + labels from deliveries only', () {
      final cs = CricsheetService(
          [_csMatch(date: '2024-03-05', deliveries: _twoOvers())]);
      final data = cs.ballDataForTeams('India', 'Pakistan',
          format: 'T20', date: DateTime.utc(2024, 3, 5, 10));
      expect(data.hasBallData, isTrue);
      expect(data.source, 'cricsheet');
      expect(data.matchDate, '2024-03-05');
      expect(data.overs.length, 2);
      expect(data.overs[0].runs, 5);
      expect(data.overs[0].wickets, 1);
      expect(data.overs[0].legalBalls, 4);
      expect(data.overs[0].balls.map((b) => b.label).toList(),
          ['0', '1', '4', 'W']);
      expect(data.overs[1].runs, 3);
      expect(data.overs[1].balls.map((b) => b.label).toList(), ['Wd', '2']);
      expect(data.overs[1].legalBalls, 1);
      expect(data.balls.length, 6);
      expect(data.oversForInnings(0).length, 2);
      expect(data.oversForInnings(1), isEmpty);
    });

    test('no-ball label + wicket on a delivery', () {
      final cs = CricsheetService([
        _csMatch(date: '2024-03-05', deliveries: [
          _d(innings: 0, over: 0, batter: 'A', bowler: 'B',
              batterRuns: 0, total: 1, noBalls: 1),
        ]),
      ]);
      final data = cs.ballDataForTeams('India', 'Pakistan',
          format: 'T20', date: DateTime.utc(2024, 3, 5));
      expect(data.balls.single.label, 'Nb');
      expect(data.balls.single.isLegalBall, isFalse);
    });

    test('date mismatch -> empty, never another match', () {
      final cs = CricsheetService(
          [_csMatch(date: '2024-03-05', deliveries: _twoOvers())]);
      final data = cs.ballDataForTeams('India', 'Pakistan',
          format: 'T20', date: DateTime.utc(2024, 3, 6));
      expect(data.hasBallData, isFalse);
      expect(data.balls, isEmpty);
    });

    test('same-day ambiguity (men+women double-header) -> empty', () {
      final cs = CricsheetService([
        _csMatch(date: '2024-03-05', deliveries: _twoOvers()),
        _csMatch(date: '2024-03-05', deliveries: _twoOvers()),
      ]);
      final data = cs.ballDataForTeams('India', 'Pakistan',
          format: 'T20', date: DateTime.utc(2024, 3, 5));
      expect(data.hasBallData, isFalse);
    });

    test('format mismatch / unknown teams -> empty', () {
      final cs = CricsheetService(
          [_csMatch(date: '2024-03-05', deliveries: _twoOvers())]);
      expect(
          cs
              .ballDataForTeams('India', 'Pakistan',
                  format: 'ODI', date: DateTime.utc(2024, 3, 5))
              .hasBallData,
          isFalse);
      expect(
          cs
              .ballDataForTeams('Australia', 'England',
                  format: 'T20', date: DateTime.utc(2024, 3, 5))
              .hasBallData,
          isFalse);
      expect(CricsheetService.empty()
          .ballDataForTeams('India', 'Pakistan')
          .hasBallData, isFalse);
    });
  });

  group('CricAPI ball data', () {
    test('totals-only scorecard -> empty, hasBallData false', () async {
      final provider = CricApiProvider(
          client: MockClient((_) async => http.Response(
              jsonEncode(_cricScoreEnvelope(scorecard: [
                {
                  'inning': 'India Inning 1',
                  'batting': [
                    {'batter': 'Rohit', 'r': 8, 'b': 6, '4s': 1, '6s': 0,
                     'dismissal': ''},
                  ],
                  'bowling': [
                    {'bowler': 'Shaheen', 'o': 1.2, 'm': 0, 'r': 8,
                     'w': 1, 'eco': 6.0, 'wd': 0, 'nb': 0},
                  ],
                  'extras': {'r': 0},
                  'total': 8,
                  'wickets': 1,
                  'overs': 1.2,
                },
              ])),
              200)));
      final data = await provider.fetchBallData('sc-1');
      expect(data.hasBallData, isFalse);
      expect(data.balls, isEmpty);
      expect(data.source, 'CricAPI');
    }, skip: _keyConfigured ? null : 'CricAPI key not compiled in');

    test('payload WITH per-ball events -> parsed, never synthesised',
        () async {
      final provider = CricApiProvider(
          client: MockClient((_) async => http.Response(
              jsonEncode(_cricScoreEnvelope(scorecard: [
                {
                  'inning': 'India Inning 1',
                  'batting': const [],
                  'bowling': const [],
                  'balls': [
                    {'over': 0, 'ball': 1, 'batter': 'Rohit',
                     'bowler': 'Shaheen', 'runs': 4},
                    {'over': 0, 'ball': 2, 'batter': 'Rohit',
                     'bowler': 'Shaheen', 'runs': 0, 'wicket': true,
                     'playerOut': 'Rohit'},
                    {'over': 1, 'ball': 1, 'batter': 'Virat',
                     'bowler': 'Shaheen', 'runs': 6},
                    // No over number -> dropped, never guessed.
                    {'ball': 2, 'batter': 'Virat',
                     'bowler': 'Shaheen', 'runs': 4},
                  ],
                },
              ])),
              200)));
      final data = await provider.fetchBallData('sc-1');
      expect(data.hasBallData, isTrue);
      expect(data.overs.length, 2);
      expect(data.overs[0].runs, 4);
      expect(data.overs[0].wickets, 1);
      expect(data.overs[0].balls.map((b) => b.label).toList(), ['4', 'W']);
      expect(data.overs[1].runs, 6);
      expect(data.balls.length, 3);
    }, skip: _keyConfigured ? null : 'CricAPI key not compiled in');

    test('429 -> empty + quotaExhausted, exactly one HTTP call',
        () async {
      var calls = 0;
      final provider = CricApiProvider(
          client: MockClient((_) async {
        calls += 1;
        return http.Response('rate limited', 429);
      }));
      final data = await provider.fetchBallData('sc-1');
      expect(data.hasBallData, isFalse);
      expect(provider.quotaExhausted, isTrue);
      expect(calls, 1);
    }, skip: _keyConfigured ? null : 'CricAPI key not compiled in');
  });

  group('ApiService.fetchBallData orchestration', () {
    test('CricAPI totals-only falls through to Cricsheet, labelled',
        () async {
      final api = ApiService(
        providers: [
          CricApiProvider(
              client: MockClient((_) async => http.Response(
                  jsonEncode(_cricScoreEnvelope(scorecard: const [])),
                  200))),
        ],
        cricsheet: CricsheetService(
            [_csMatch(date: '2024-03-05', deliveries: _twoOvers())]),
        loadCricsheetSample: false,
      );
      final match = CricketMatch(
        id: 'sc-1',
        teamA: 'India',
        teamB: 'Pakistan',
        format: 'T20',
        startTime: DateTime.utc(2024, 3, 5, 10),
      );
      final data = await api.fetchBallData(match);
      expect(data.hasBallData, isTrue);
      expect(data.source, 'cricsheet');
      expect(data.overs.length, 2);
    }, skip: _keyConfigured ? null : 'CricAPI key not compiled in');

    test('nothing anywhere -> empty, never throws', () async {
      final api = ApiService(
        providers: const [],
        cricsheet: CricsheetService.empty(),
        loadCricsheetSample: false,
      );
      final match = CricketMatch(
        id: 'x',
        teamA: 'India',
        teamB: 'Pakistan',
        startTime: DateTime.utc(2024, 3, 5),
      );
      final data = await api.fetchBallData(match);
      expect(data.hasBallData, isFalse);
    });
  });
}
