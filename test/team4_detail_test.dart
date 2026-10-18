import 'package:flutter_test/flutter_test.dart';
import 'package:kingcric/models/innings.dart';
import 'package:kingcric/models/match.dart';
import 'package:kingcric/screens/leagues_screen.dart';

CricketMatch _match({
  required String a,
  required String b,
  required String result,
  List<Innings> innings = const [],
}) =>
    CricketMatch(
      id: '$a-$b-$result',
      teamA: a,
      teamB: b,
      startTime: DateTime(2026, 10, 18),
      status: MatchStatus.completed,
      result: result,
      innings: innings,
    );

void main() {
  group('cricketOversToBalls', () {
    test('19.3 overs = 117 balls (fraction is balls, not decimal)', () {
      expect(cricketOversToBalls(19.3), 117);
    });
    test('20.0 overs = 120 balls, 0 = 0', () {
      expect(cricketOversToBalls(20.0), 120);
      expect(cricketOversToBalls(0), 0);
    });
  });

  group('computePointsTable', () {
    test('win = 2 pts, loss = 0, no-result = 1 pt each + NR counted', () {
      final table = computePointsTable([
        _match(a: 'India', b: 'Pakistan', result: 'India won by 5 wkts'),
        _match(a: 'India', b: 'Australia', result: 'No result'),
      ]);
      expect(table['India']!.pts, 3);
      expect(table['India']!.w, 1);
      expect(table['India']!.nr, 1);
      expect(table['Pakistan']!.pts, 0);
      expect(table['Pakistan']!.l, 1);
      expect(table['Australia']!.pts, 1);
      expect(table['Australia']!.nr, 1);
    });

    test('tied match counts as no-result, not as a win for either side', () {
      final table = computePointsTable([
        _match(a: 'India', b: 'Pakistan', result: 'Match tied'),
      ]);
      expect(table['India']!.nr, 1);
      expect(table['India']!.w, 0);
      expect(table['Pakistan']!.nr, 1);
    });

    test('NRR from innings totals/overs; null when no innings data', () {
      final withInnings = computePointsTable([
        _match(
          a: 'India',
          b: 'Pakistan',
          result: 'India won by 20 runs',
          innings: [
            const Innings(team: 'India', total: 160, overs: 20.0),
            const Innings(team: 'Pakistan', total: 140, overs: 20.0),
          ],
        ),
      ]);
      // India: 8.00 - 7.00 = +1.00; Pakistan: -1.00.
      expect(withInnings['India']!.nrr, closeTo(1.0, 0.001));
      expect(withInnings['Pakistan']!.nrr, closeTo(-1.0, 0.001));

      final noInnings = computePointsTable([
        _match(a: 'India', b: 'Pakistan', result: 'India won by 5 wkts'),
      ]);
      expect(noInnings['India']!.nrr, isNull);
    });

    test('live/upcoming matches do not enter the table', () {
      final table = computePointsTable([
        CricketMatch(
          id: 'live-1',
          teamA: 'India',
          teamB: 'Pakistan',
          startTime: DateTime(2026, 10, 18),
          status: MatchStatus.live,
        ),
      ]);
      expect(table, isEmpty);
    });
  });
}
