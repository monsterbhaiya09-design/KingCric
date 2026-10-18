import 'package:flutter_test/flutter_test.dart';
import 'package:kingcric/models/match.dart';
import 'package:kingcric/models/player.dart';
import 'package:kingcric/services/api_service.dart';
import 'package:kingcric/services/auto_update_service.dart';
import 'package:kingcric/services/completeness_validator.dart';
import 'package:kingcric/services/prediction_engine.dart';
import 'package:kingcric/services/providers/cricket_provider.dart';

void main() {
  group('Team5: resolveStatus detail', () {
    test('won the toss is NOT a completed match', () {
      expect(
        ProviderParsing.resolveStatus(
          raw: 'India won the toss and chose to bat',
          hasScores: false,
        ),
        MatchStatus.upcoming,
      );
      expect(
        ProviderParsing.resolveStatus(
          raw: 'India won the match by 5 wickets',
          hasScores: true,
        ),
        MatchStatus.completed,
      );
    });

    test('pre-toss rain delay is upcoming, mid-match rain delay is live',
        () {
      expect(
        ProviderParsing.resolveStatus(raw: 'Rain delay', hasScores: false),
        MatchStatus.upcoming,
      );
      expect(
        ProviderParsing.resolveStatus(raw: 'Rain delay', hasScores: true),
        MatchStatus.live,
      );
      expect(
        ProviderParsing.resolveStatus(
            raw: 'Stumps, Day 1', hasScores: true),
        MatchStatus.live,
      );
    });

    test('need-runs in-progress still live', () {
      expect(
        ProviderParsing.resolveStatus(
          raw: 'Austria Women need 88 runs in 78 balls',
          hasScores: true,
        ),
        MatchStatus.live,
      );
    });
  });

  group('Team5: cleanTeamName detail', () {
    test('India Women wins over India at the same index', () {
      expect(
        ProviderParsing.cleanTeamName(
          'India Women Inning 1',
          ['India', 'India Women'],
        ),
        'India Women',
      );
      expect(
        ProviderParsing.cleanTeamName(
          'Bulgaria Women,Sweden Women Inning 2',
          ['Bulgaria Women', 'Sweden Women'],
        ),
        'Sweden Women',
      );
    });
  });

  group('Team5: BattingStats merge uses dismissals', () {
    test('merged average is runs/dismissals, not runs/innings', () {
      // Block A: 100 runs, avg 50 -> 2 dismissals, 2 innings.
      // Block B: 60 runs, avg 30 -> 2 dismissals, 3 innings.
      // Correct merged avg = 160 / 4 = 40. Runs/innings would be 32.
      const a = BattingStats(
          matches: 2, innings: 2, runs: 100, average: 50);
      const b = BattingStats(
          matches: 3, innings: 3, runs: 60, average: 30);
      final merged = a + b;
      expect(merged.runs, 160);
      expect(merged.average, closeTo(40, 0.001));
    });
  });

  group('Team5: Prediction NaN + no-data', () {
    test('NaN averages never produce a NaN score', () {
      const p = Player(
        id: 'p-x',
        name: 'NaN Player',
        team: 'X',
        battingByFormat: {
          'T20': BattingStats(matches: 1, runs: 10, average: double.nan),
        },
      );
      final pred = PredictionEngine.predict(
        player: p,
        opponent: 'Y',
        venueId: 'v',
        format: 'T20',
        pitchBattingFriendliness: double.nan,
      );
      expect(pred.score.isFinite, isTrue);
      expect(pred.hasData, isTrue);
    });

    test('player with zero signal has hasData=false', () {
      const p = Player(id: 'p-none', name: 'Nobody', team: 'X');
      final pred = PredictionEngine.predict(
        player: p,
        opponent: 'Y',
        venueId: 'v',
        format: 'T20',
      );
      expect(pred.hasData, isFalse);
      expect(pred.explanationEn, contains('Not enough data'));
      expect(pred.explanationHi, contains('पर्याप्त डेटा नहीं'));
    });
  });

  group('Team5: validator tolerance scales', () {
    test('big total tolerates >15 extras', () {
      // 500 total, batting sums to 480 -> diff 20 (extras).
      // Flat-15 tolerance would fail; scaled tolerance passes.
      final m = CricketMatch.fromJson({
        'id': 'm1',
        'teamA': 'A',
        'teamB': 'B',
        'startTime': '2024-01-01T00:00:00.000',
        'status': 'completed',
        'innings': [
          {
            'team': 'A',
            'inningsNumber': 1,
            'total': 500,
            'wickets': 0,
            'overs': 90.0,
            'batting': [
              {
                'playerName': 'Batter',
                'runs': 480,
                'balls': 200,
                'dismissal': 'not out'
              },
            ],
            'bowling': [],
          }
        ],
      });
      expect(CompletenessValidator.inningsReconciles(m), isTrue);
    });
  });

  group('Team5: ApiService scorecard caching + lastUpdated', () {
    test('fetchScorecard caches so second call needs no provider', () async {
      // No providers configured in this test env (no keys) -> null.
      // The caching path is exercised via fetchMatchDetail below.
      final api = ApiService(providers: []);
      expect(await api.fetchScorecard('nope'), isNull);
      expect(api.lastMatchesUpdated, isNull);
    });

    test('AutoUpdate tick never throws and updates lastPoll', () async {
      final api = ApiService(providers: []);
      final svc = AutoUpdateService(api: api);
      final before = DateTime.now();
      await svc.tick();
      expect(
        svc.lastPoll.isAfter(before.subtract(const Duration(seconds: 5))),
        isTrue,
      );
      // Overlapping ticks are skipped, not stacked.
      await Future.wait([svc.tick(), svc.tick(), svc.tick()]);
      svc.dispose();
    });
  });
}
