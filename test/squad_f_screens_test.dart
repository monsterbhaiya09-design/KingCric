import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kingcric/models/innings.dart';
import 'package:kingcric/models/match.dart';
import 'package:kingcric/models/player.dart';
import 'package:kingcric/models/prediction.dart';
import 'package:kingcric/screens/favourites_screen.dart';
import 'package:kingcric/screens/player_profile_screen.dart';
import 'package:kingcric/screens/leagues_screen.dart';
import 'package:kingcric/screens/stats_screen.dart';
import 'package:kingcric/utils/strings.dart';
import 'package:kingcric/widgets/h2h_card.dart';
import 'package:kingcric/widgets/player_card.dart';
import 'package:kingcric/widgets/prediction_card.dart';
import 'package:kingcric/widgets/squad_player_card.dart';

Widget _wrap(Widget child) => ChangeNotifierProvider<LanguageProvider>(
      create: (_) => LanguageProvider(),
      child: MaterialApp(home: child),
    );

const _noStats = Player(
  id: 'p-nostats',
  name: 'No Stats Player',
  team: 'Nowhere',
);

const _partial = Player(
  id: 'p-partial',
  name: 'Partial Provider Player',
  team: 'India',
  source: 'cricapi',
  dataComplete: false,
);

const _demo = Player(
  id: 'p-demo',
  name: 'Demo Player',
  team: 'India',
  source: 'demo',
);

const _real = Player(
  id: 'p-real',
  name: 'Real Player',
  team: 'India',
  source: 'cricsheet',
  sourceMatches: 420,
  dataComplete: true,
);

void main() {
  group('Squad F: source labels are by provenance', () {
    testWidgets('PlayerCard: partial provider profile says Partial, not Demo',
        (tester) async {
      await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: PlayerCard(player: _partial))));
      await tester.pump();
      expect(find.text('Partial'), findsOneWidget);
      expect(find.text('Demo'), findsNothing);
    });

    testWidgets('PlayerCard: demo still says Demo, cricsheet says Real',
        (tester) async {
      await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: PlayerCard(player: _demo))));
      await tester.pump();
      expect(find.text('Demo'), findsOneWidget);

      await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: PlayerCard(player: _real))));
      await tester.pump();
      expect(find.text('Real • Cricsheet'), findsOneWidget);
    });

    testWidgets('SquadPlayerCard: partial says Partial, not Demo',
        (tester) async {
      await tester.pumpWidget(_wrap(const Scaffold(
        body: SquadPlayerCard(
            player: _partial, opponent: 'Pakistan', format: 'T20'),
      )));
      await tester.pump();
      expect(find.text('Partial'), findsOneWidget);
      expect(find.text('Demo'), findsNothing);
    });

    testWidgets('SquadPlayerCard: no-stats player shows honest empty line',
        (tester) async {
      await tester.pumpWidget(_wrap(const Scaffold(
        body: SquadPlayerCard(
            player: _noStats, opponent: 'Pakistan', format: 'T20'),
      )));
      await tester.pump();
      expect(find.text('Stats not available for this player yet.'),
          findsOneWidget);
      expect(find.textContaining('0 runs'), findsNothing);
    });
  });

  group('Squad F: no fake numbers', () {
    testWidgets('PredictionCard with hasData=false shows no number',
        (tester) async {
      const pred = Prediction(
        playerId: 'p-x',
        playerName: 'No Data Player',
        opponent: 'Pakistan',
        venueId: '',
        format: 'T20',
        score: 50,
        recentFormScore: 0,
        vsOpponentScore: 0,
        venueScore: 0,
        matchupScore: 0,
        pitchScore: 0,
        explanationEn: '',
        explanationHi: '',
        hasData: false,
      );
      await tester.pumpWidget(_wrap(const Scaffold(
        body: PredictionCard(prediction: pred),
      )));
      await tester.pump();
      expect(find.text('Not enough data to predict.'), findsOneWidget);
      // No donut number, no verdict pill for a no-signal prediction.
      expect(find.text('50'), findsNothing);
      expect(find.text('Risky'), findsNothing);
    });

    testWidgets('H2HCard total=0 is an empty state, not a 0-0 result',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: H2HCard(
                teamA: 'Pakistan',
                teamB: 'Sri Lanka',
                winsA: 0,
                winsB: 0,
                total: 0),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('No head-to-head matches in the loaded data yet.'),
          findsOneWidget);
      expect(find.textContaining('0 — 0'), findsNothing);
    });

    testWidgets('Profile with zero matches never shows 0.0 Avg/SR',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const Scaffold(body: PlayerProfileScreen(player: _noStats)),
      ));
      await tester.pump();
      expect(find.text('0.0'), findsNothing);
      // Hero + Overall grid use the dash for undefined rates.
      expect(find.text('—'), findsWidgets);
    });

    testWidgets('Profile demo player shows Demo source line, never Complete',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const Scaffold(body: PlayerProfileScreen(player: _demo)),
      ));
      await tester.pump();
      // FINAL MERGE: Squad S moved the source line into the About
      // section at the bottom — scroll there before asserting.
      await tester.fling(
          find.byType(ListView), const Offset(0, -5000), 10000);
      await tester.pumpAndSettle();
      expect(find.textContaining('Demo data'), findsOneWidget);
      expect(find.text('Complete'), findsNothing);
    });
  });

  group('Squad F: Leagues points table (pure)', () {
    CricketMatch match({
      required String id,
      required String result,
      List<Innings> innings = const [],
    }) =>
        CricketMatch(
          id: id,
          teamA: 'India',
          teamB: 'Pakistan',
          startTime: DateTime.utc(2025, 1, 1),
          status: MatchStatus.completed,
          result: result,
          innings: innings,
        );

    test('Win = 2 pts, no-result = 1 pt each', () {
      final table = computePointsTable([
        match(id: 'm1', result: 'India won by 5 wickets'),
        match(id: 'm2', result: 'No result'),
      ]);
      expect(table['India']!.p, 2);
      expect(table['India']!.w, 1);
      expect(table['India']!.pts, 3); // 2 + 1
      expect(table['Pakistan']!.l, 1);
      expect(table['Pakistan']!.nr, 1);
      expect(table['Pakistan']!.pts, 1);
    });

    test('NRR is null without innings, computed from cricket-overs balls',
        () {
      final noInn = computePointsTable([
        match(id: 'm1', result: 'India won by 5 wickets'),
      ]);
      expect(noInn['India']!.nrr, isNull);

      // 19.3 overs = 117 balls, NOT 19.3 * 6 = 115.8.
      final withInn = computePointsTable([
        match(
          id: 'm1',
          result: 'India won by 5 wickets',
          innings: [
            const Innings(team: 'India', total: 180, overs: 20),
            const Innings(team: 'Pakistan', total: 170, overs: 19.3),
          ],
        ),
      ]);
      final nrr = withInn['India']!.nrr!;
      // 180/120*6 - 170/117*6 = 9.0 - 8.7179 = 0.2820…
      expect(nrr, closeTo(0.282, 0.001));
      expect(withInn['Pakistan']!.nrr!, closeTo(-0.282, 0.001));
    });

    test('cricketOversToBalls treats the fraction as balls', () {
      expect(cricketOversToBalls(19.3), 117);
      expect(cricketOversToBalls(3.2), 20);
      expect(cricketOversToBalls(20), 120);
      expect(cricketOversToBalls(0), 0);
    });
  });

  group('Squad F: secondary screens render with real/mock data', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('Stats screen renders boards + honest Demo source line',
        (tester) async {
      await tester.pumpWidget(
          const MaterialApp(home: StatsScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Stats & Rankings'), findsOneWidget);
      expect(find.textContaining('Demo data'), findsOneWidget);
      expect(find.text('Most Runs'), findsOneWidget);
      // Bowling boards are below the fold (lazy ListView) — drag
      // the ListView itself (scrollUntilVisible is ambiguous: the
      // screen also has horizontal chip scrollers).
      for (var i = 0;
          i < 10 && find.text('Most Wickets').evaluate().isEmpty;
          i++) {
        await tester.drag(find.byType(ListView), const Offset(0, -600));
        await tester.pump();
      }
      expect(find.text('Most Wickets'), findsOneWidget);
    });

    testWidgets('Favourites renders master switch + empty banner, no crash',
        (tester) async {
      await tester.pumpWidget(
          const MaterialApp(home: FavouritesScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Favourites'), findsOneWidget);
      expect(find.text('Match notifications'), findsOneWidget);
      expect(find.textContaining('No favourites yet'), findsOneWidget);
      // Event toggles exist and are gated by the master switch.
      expect(find.text('Wickets'), findsOneWidget);
      expect(find.text('Sixes'), findsOneWidget);
    });
  });
}
