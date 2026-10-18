import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:kingcric/models/match.dart';
import 'package:kingcric/screens/home_screen.dart';
import 'package:kingcric/utils/app_theme.dart';
import 'package:kingcric/utils/strings.dart';
import 'package:kingcric/widgets/match_card.dart';

CricketMatch _match({
  String source = 'CricAPI',
  MatchStatus status = MatchStatus.live,
  String result = '',
  List<TeamScore> scores = const [],
}) =>
    CricketMatch(
      id: 'm1',
      teamA: 'Pakistan',
      teamB: 'Sri Lanka',
      format: 'ODI',
      league: 'International',
      venueName: 'Rawalpindi Cricket Stadium, Rawalpindi',
      startTime: DateTime(2026, 11, 8, 11, 30),
      status: status,
      result: result,
      scores: scores,
      source: source,
    );

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: child),
    );

void main() {
  group('Squad B: KingMatchCard source label', () {
    testWidgets('CricAPI card shows Source: CricAPI', (tester) async {
      await tester.pumpWidget(_wrap(KingMatchCard(
        match: _match(source: 'CricAPI'),
        onTap: () {},
      )));
      expect(find.text('Source: CricAPI'), findsOneWidget);
    });

    testWidgets('Demo card shows Source: Demo in amber', (tester) async {
      await tester.pumpWidget(_wrap(KingMatchCard(
        match: _match(source: 'demo'),
        onTap: () {},
      )));
      final text =
          tester.widget<Text>(find.text('Source: Demo'));
      expect(text.style?.color, AppTheme.amber);
    });

    testWidgets('empty source shows Source: Unknown, never blank',
        (tester) async {
      await tester.pumpWidget(_wrap(KingMatchCard(
        match: _match(source: ''),
        onTap: () {},
      )));
      expect(find.text('Source: Unknown'), findsOneWidget);
    });

    testWidgets('merged source shows Source: Live APIs', (tester) async {
      await tester.pumpWidget(_wrap(KingMatchCard(
        match: _match(source: 'merged'),
        onTap: () {},
      )));
      expect(find.text('Source: Live APIs'), findsOneWidget);
    });
  });

  group('Squad B: KingMatchCard CTA honesty', () {
    testWidgets('upcoming card promises details, not a scorecard',
        (tester) async {
      await tester.pumpWidget(_wrap(KingMatchCard(
        match: _match(status: MatchStatus.upcoming),
        onTap: () {},
      )));
      expect(find.text('Tap for match details'), findsOneWidget);
      expect(find.text('Details →'), findsOneWidget);
      expect(find.text('Tap for FULL scorecard'), findsNothing);
      expect(find.text('Scorecard →'), findsNothing);
      // Upcoming shows no score rows.
      expect(find.textContaining('Yet to bat'), findsNothing);
    });

    testWidgets('live card shows LIVE pill + scorecard CTA + scores',
        (tester) async {
      await tester.pumpWidget(_wrap(KingMatchCard(
        match: _match(
          status: MatchStatus.live,
          scores: const [
            TeamScore(team: 'Pakistan', runs: 120, wickets: 2, overs: 20, batted: true),
          ],
        ),
        onTap: () {},
      )));
      expect(find.text('LIVE'), findsOneWidget);
      expect(find.text('Tap for FULL scorecard'), findsOneWidget);
      expect(find.text('120/2 (20.0 ov)'), findsOneWidget);
    });

    testWidgets('completed card shows RESULT pill + result line',
        (tester) async {
      await tester.pumpWidget(_wrap(KingMatchCard(
        match: _match(
          status: MatchStatus.completed,
          result: 'Pakistan won by 5 wickets',
        ),
        onTap: () {},
      )));
      expect(find.text('RESULT'), findsOneWidget);
      expect(find.text('Pakistan won by 5 wickets'), findsOneWidget);
      expect(find.text('Tap for FULL scorecard'), findsOneWidget);
    });
  });

  group('Squad B: HomeScreen first frame', () {
    testWidgets('header, tabs, search and matches section render',
        (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<LanguageProvider>(
          create: (_) => LanguageProvider(),
          child: const MaterialApp(home: Scaffold(body: HomeScreen())),
        ),
      );
      // First frame only: _load is in flight, no network dependence.
      expect(find.text('KingCric'), findsOneWidget);
      // Selected tab carries the checkmark prefix.
      expect(find.text('✓ Live'), findsOneWidget);
      expect(find.text('Upcoming'), findsWidgets);
      expect(find.text('Finished'), findsWidgets);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Matches'), findsOneWidget);
    });
  });
}
