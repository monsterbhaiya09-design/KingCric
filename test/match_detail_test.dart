import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:kingcric/models/innings.dart';
import 'package:kingcric/models/match.dart';
import 'package:kingcric/screens/match_detail_screen.dart';
import 'package:kingcric/services/cricsheet_service.dart';
import 'package:kingcric/services/mock_data_service.dart';
import 'package:kingcric/utils/strings.dart';

// TEAM 2 — Match Detail smallest-details tests.
// Pure helpers are top-level in match_detail_screen.dart so they are
// unit-testable without pumping the whole screen.

void main() {
  // MERGE-LEAD: warm the parse-once Cricsheet cache ONCE in setUpAll
  // (real zone, before any test's fake-async starts). Do NOT warm it
  // with tester.runAsync inside a test: runAsync deadlocks when a
  // previous test pumped MatchDetailScreen (its initState fires
  // provider work), and the Squad tab's asset-load future then never
  // completes — the Squad test hung 100s+ and the whole file failed
  // on shutdown. setUpAll warm-up makes every test await an
  // already-completed future, so no test needs runAsync.
  setUpAll(() async {
    await CricsheetService.loadBundled();
  });

  group('cricket overs conversion', () {
    test('3.2 overs = 20 balls, not 3.2*6 = 19.2', () {
      expect(ballsFromCricketOvers(3.2), 20);
      expect(ballsFromCricketOvers(4.0), 24);
      expect(ballsFromCricketOvers(0.0), 0);
      expect(ballsFromCricketOvers(19.5), 119);
    });
    test('formatCricketOvers keeps the balls part', () {
      expect(formatCricketOvers(4.0), '4');
      expect(formatCricketOvers(3.2), '3.2');
      expect(formatCricketOvers(0.0), '0');
    });
    test('displayEconomy agrees with the O column', () {
      // 3.2 overs (20 balls), 28 runs -> 28*6/20 = 8.40.
      // Stored economy is deliberately wrong (9.99) to prove the
      // recompute wins; the UI must never show a stale Econ.
      const b = BowlingEntry(
        playerId: 'p-x',
        playerName: 'X Bowler',
        overs: 3.2,
        runsConceded: 28,
        wickets: 1,
        economy: 9.99,
      );
      expect(displayEconomy(b), closeTo(8.4, 0.001));
    });
    test('displayEconomy falls back when overs are 0 (no NaN)', () {
      const b = BowlingEntry(
        playerId: 'p-x',
        playerName: 'X Bowler',
        overs: 0,
        runsConceded: 0,
        wickets: 0,
        economy: 0,
      );
      expect(displayEconomy(b), 0);
      expect(displayEconomy(b).isNaN, isFalse);
    });
  });

  group('FOW + dismissal labels', () {
    test('stripFowPrefix removes the embedded "N-" number', () {
      expect(stripFowPrefix('1-52 (Rohit Sharma, 6.1 ov)'),
          '52 (Rohit Sharma, 6.1 ov)');
      expect(stripFowPrefix('52 (Rohit, 6.1 ov)'), '52 (Rohit, 6.1 ov)');
    });
    test('dismissalLabel shows "not out" for a not-out batter', () {
      const notOut = BattingEntry(
        playerId: 'p-v',
        playerName: 'V Kohli',
        runs: 68,
        balls: 45,
        dismissal: '',
        notOut: true,
      );
      expect(dismissalLabel(notOut), 'not out');
      const out = BattingEntry(
        playerId: 'p-r',
        playerName: 'R Sharma',
        runs: 48,
        balls: 30,
        dismissal: 'c Babar Azam b Shaheen Afridi',
      );
      expect(dismissalLabel(out), 'c Babar Azam b Shaheen Afridi');
    });
  });

  group('MatchDetailScreen widget details', () {
    CricketMatch demoMatch() {
      final matches = MockDataService().matches();
      return matches.firstWhere(
        (m) => m.innings.isNotEmpty,
        orElse: () => matches.first,
      );
    }

    Widget wrap(Widget child) {
      return ChangeNotifierProvider(
        create: (_) => LanguageProvider(),
        child: MaterialApp(home: child),
      );
    }

    /// Drag the visible tab's list until [finder] is built.
    ///
    /// Deliberately NOT [WidgetTester.scrollUntilVisible]: that helper
    /// requires exactly one matching widget AND exactly one
    /// Scrollable, but this screen has a PageView + ListViews and the
    /// same FOW text can exist in two tabs (Live OverGraph + Scorecard),
    /// so it throws "Bad state: Too many elements". Dragging the single
    /// TabBarView and polling [Finder.evaluate] works with 0..n matches.
    ///
    /// Steps are SMALL (250px): a big drag can leapfrog a short section
    /// (e.g. the FOW card) entirely, so the target is never built.
    Future<void> dragUntilBuilt(
        WidgetTester tester, Finder finder) async {
      for (var i = 0; i < 40 && finder.evaluate().isEmpty; i++) {
        await tester.drag(find.byType(TabBarView), const Offset(0, -250));
        await tester.pump();
      }
    }

    testWidgets('FOW row shows the number ONCE (circle only)',
        (tester) async {
      await tester.pumpWidget(wrap(MatchDetailScreen(match: demoMatch())));
      await tester.pump();
      // Open the Scorecard tab (tab index 1).
      await tester.tap(find.text('Scorecard'));
      await tester.pumpAndSettle();
      // The raw "1-52" string must NOT appear: the circle carries
      // the number, the row shows "52 (Rohit Sharma, 6.1 ov)".
      expect(find.textContaining('1-52'), findsNothing);
      // ListView builds lazily: drag the FOW section into view
      // before asserting on it.
      await dragUntilBuilt(
          tester, find.textContaining('52 (Rohit Sharma, 6.1 ov)'));
      expect(find.textContaining('52 (Rohit Sharma, 6.1 ov)'),
          findsWidgets);
    });

    testWidgets('Squad tab splits Team A / Team B sections',
        (tester) async {
      final match = demoMatch();
      // Cricsheet cache is warmed once in setUpAll (see top of file)
      // — no per-test runAsync warm-up (it deadlocks after a previous
      // test pumped this screen).
      await tester.pumpWidget(wrap(MatchDetailScreen(match: match)));
      await tester.pump();
      await tester.tap(find.text('Squad'));
      await tester.pumpAndSettle();
      expect(find.textContaining('${match.teamA} — Squad'), findsOneWidget);
      // ListView builds lazily: drag the Team B section into view.
      await dragUntilBuilt(
          tester, find.textContaining('${match.teamB} — Squad'));
      expect(find.textContaining('${match.teamB} — Squad'), findsOneWidget);
    });

    testWidgets('Bowling O column shows cricket overs, not truncated',
        (tester) async {
      // A bowler with 3.2 overs must show "3.2", never "3".
      final match = CricketMatch(
        id: 'm-test',
        teamA: 'India',
        teamB: 'Pakistan',
        format: 'T20',
        league: 'International',
        startTime: DateTime(2026, 10, 18),
        status: MatchStatus.completed,
        innings: const [
          Innings(
            team: 'India',
            inningsNumber: 1,
            total: 150,
            wickets: 5,
            overs: 20.0,
            batting: [
              BattingEntry(
                  playerId: 'p-a',
                  playerName: 'A Batter',
                  runs: 50,
                  balls: 30,
                  dismissal: 'b X Bowler'),
            ],
            bowling: [
              BowlingEntry(
                  playerId: 'p-x',
                  playerName: 'X Bowler',
                  overs: 3.2,
                  runsConceded: 28,
                  wickets: 1,
                  economy: 9.99),
            ],
          ),
        ],
      );
      await tester.pumpWidget(wrap(MatchDetailScreen(match: match)));
      await tester.pump();
      await tester.tap(find.text('Scorecard'));
      await tester.pumpAndSettle();
      expect(find.text('3.2'), findsWidgets);
      // Recomputed economy 8.40 must appear, stale 9.99 must not.
      expect(find.text('8.40'), findsWidgets);
      expect(find.text('9.99'), findsNothing);
    });
  });
}
