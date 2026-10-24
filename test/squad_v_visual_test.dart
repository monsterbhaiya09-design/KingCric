import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingcric/models/innings.dart';
import 'package:kingcric/widgets/ball_strip.dart';
import 'package:kingcric/widgets/milestone_tracker.dart';
import 'package:kingcric/widgets/over_timeline.dart';

Widget wrap(Widget child) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)));

Innings mockInnings() => const Innings(
      team: 'India',
      total: 182,
      wickets: 3,
      overs: 17.3,
      batting: [
        BattingEntry(
            playerId: 'p1', playerName: 'Virat Kohli', runs: 82, balls: 54),
        BattingEntry(
            playerId: 'p2', playerName: 'Rohit Sharma', runs: 120, balls: 88),
        BattingEntry(
            playerId: 'p3', playerName: 'Surya Kumar', runs: 10, balls: 8),
      ],
      bowling: [
        BowlingEntry(
            playerId: 'b1', playerName: 'Shaheen Afridi', wickets: 4),
        BowlingEntry(playerId: 'b2', playerName: 'Bumrah', wickets: 1),
      ],
      fallOfWickets: ['1-52 (Rohit Sharma, 6.1 ov)', '2-130 (Surya, 12.4 ov)'],
      partnerships: ['Virat + Surya — 68 (42 balls)'],
    );

void main() {
  group('BallStrip', () {
    test('normaliseOutcome accepts real tokens, rejects junk', () {
      expect(BallStrip.normaliseOutcome('4'), '4');
      expect(BallStrip.normaliseOutcome('W'), 'W');
      expect(BallStrip.normaliseOutcome('Wd'), 'Wd');
      expect(BallStrip.normaliseOutcome('abc'), isNull);
      expect(BallStrip.normaliseOutcome(''), isNull);
    });

    testWidgets('renders real balls, never invents when none',
        (tester) async {
      await tester.pumpWidget(
          wrap(const BallStrip(balls: ['0', '1', '4', 'W', '6'])));
      expect(find.text('4'), findsOneWidget);
      expect(find.text('W'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
      await tester.pumpWidget(wrap(const BallStrip(balls: null)));
      expect(find.text('Ball-by-ball not available from free provider.'),
          findsOneWidget);
    });

    testWidgets('shows at most the last over', (tester) async {
      await tester.pumpWidget(wrap(const BallStrip(
          balls: ['1', '1', '1', '1', '1', '1', '1', '4'])));
      // 8 balls in, only 6 chips: the last '4' must be present and
      // exactly 6 ball chips render (find by widget type count via
      // the '4' chip plus five '1' chips).
      expect(find.text('4'), findsOneWidget);
      expect(find.text('1'), findsNWidgets(5));
    });
  });

  group('computeMilestones', () {
    test('batter 82 -> 100 progress, 120 reached, 10 ignored', () {
      final ms = computeMilestones([mockInnings()]);
      final virat =
          ms.where((m) => m.label.contains('Virat Kohli')).toList();
      expect(virat, hasLength(1));
      expect(virat.single.progress, closeTo(0.82, 0.001));
      expect(virat.single.reached, isFalse);
      final rohit =
          ms.where((m) => m.label.contains('Rohit Sharma')).toList();
      expect(rohit.single.reached, isTrue);
      expect(ms.any((m) => m.label.contains('Surya Kumar')), isFalse);
    });

    test('bowler 4 wkts -> 5, partnership 68 -> 100', () {
      final ms = computeMilestones([mockInnings()]);
      final shaheen =
          ms.where((m) => m.label.contains('Shaheen Afridi')).toList();
      expect(shaheen.single.progress, closeTo(0.8, 0.001));
      final part = ms.where((m) => m.label.contains('Partnership')).toList();
      expect(part.single.progress, closeTo(0.68, 0.001));
      expect(ms.any((m) => m.label.contains('Bumrah')), isFalse);
    });

    test('unparseable partnership skipped, empty innings -> none', () {
      const inn = Innings(team: 'X', partnerships: ['no numbers here']);
      expect(computeMilestones([inn]), isEmpty);
      expect(computeMilestones([]), isEmpty);
    });
  });

  group('OverTimeline', () {
    test('parseWicketOvers maps 6.1 ov to over 6', () {
      expect(
          OverTimeline.parseWicketOvers(
              ['1-52 (Rohit Sharma, 6.1 ov)', '2-130 (Surya, 12.4 ov)']),
          {6, 12});
      expect(OverTimeline.parseWicketOvers(['1-52', 'junk']), isEmpty);
    });

    test('splitOvers uses cricket overs, not decimals', () {
      expect(OverTimeline.splitOvers(17.3), (whole: 17, balls: 3));
      expect(OverTimeline.splitOvers(20.0), (whole: 20, balls: 0));
    });

    testWidgets('honest caption without per-over runs', (tester) async {
      await tester.pumpWidget(
          wrap(OverTimeline(innings: [mockInnings()])));
      expect(
          find.text(
              'Per-over runs not provided by free providers — wickets shown from fall of wickets.'),
          findsOneWidget);
      // Wicket markers for overs 7 (6.1) and 13 (12.4) render.
      expect(find.text('W'), findsNWidgets(2));
    });

    testWidgets('supplied per-over runs render', (tester) async {
      await tester.pumpWidget(wrap(OverTimeline(
        innings: [mockInnings()],
        overRuns: List.filled(18, 7),
      )));
      expect(find.text('Runs per over from ball-level data.'),
          findsOneWidget);
    });
  });

  group('MilestoneTracker widget', () {
    testWidgets('renders milestones and honest empty', (tester) async {
      await tester.pumpWidget(
          wrap(MilestoneTracker(innings: [mockInnings()])));
      expect(find.textContaining('Virat Kohli'), findsWidgets);
      await tester.pumpWidget(wrap(const MilestoneTracker(innings: [
        Innings(team: 'X', total: 10, wickets: 0, overs: 2.0),
      ])));
      expect(find.text('No milestones in reach yet in this innings.'),
          findsOneWidget);
    });
  });
}
