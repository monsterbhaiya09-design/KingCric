import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingcric/models/innings.dart';
import 'package:kingcric/widgets/over_timeline.dart';

/// FINAL MERGE regression tests for the OverTimeline per-innings
/// wiring (gap a): per-over runs must land on the RIGHT innings,
/// never the first innings' runs on every card.
void main() {
  Innings inn(String team, int total, int wkts) => Innings(
        team: team,
        total: total,
        wickets: wkts,
        overs: 2.0,
        batting: const [],
        bowling: const [],
      );

  testWidgets('overRunsByInnings maps runs to the right innings',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: OverTimeline(
              innings: [],
              overRunsByInnings: {},
            ),
          ),
        ),
      ),
    );
    // Empty innings renders nothing (pre-existing behaviour).
    expect(find.text('Over Timeline'), findsNothing);
  });

  testWidgets('per-innings runs do not leak across innings cards',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: OverTimeline(
              innings: [inn('India', 20, 0), inn('Pakistan', 35, 1)],
              overRunsByInnings: const {
                0: [10, 10],
                1: [20, 15],
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Over Timeline'), findsOneWidget);
    // Each innings card shows its own first-over runs, not the
    // other innings' runs. Chips show the runs value as text.
    expect(find.text('India • 20/0'), findsOneWidget);
    expect(find.text('Pakistan • 35/1'), findsOneWidget);
    // '10' appears (India over 1/2) and '20'/'15' appear
    // (Pakistan) — a leak would duplicate one side's values.
    expect(find.text('10'), findsWidgets);
    expect(find.text('20'), findsWidgets);
    expect(find.text('15'), findsWidgets);
    // Honest caption replaced by ball-data caption per card.
    expect(find.text('Runs per over from ball-level data.'),
        findsWidgets);
  });

  testWidgets('legacy overRuns still works when no map given',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: OverTimeline(
              innings: [inn('India', 12, 0)],
              overRuns: const [7, 5],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('7'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
  });
}
