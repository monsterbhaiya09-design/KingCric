import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:kingcric/models/match.dart';
import 'package:kingcric/models/player.dart';
import 'package:kingcric/screens/player_profile_screen.dart';
import 'package:kingcric/utils/app_theme.dart';
import 'package:kingcric/utils/strings.dart';
import 'package:kingcric/widgets/empty_state.dart';
import 'package:kingcric/widgets/match_card.dart';
import 'package:kingcric/widgets/premium_widgets.dart';

/// FIX UX — premium redesign tests: thin gold accents (never thick
/// outlines), no blank Batting/Bowling rows, Title Case format
/// labels, profile tables that fit the viewport.

void main() {
  group('DisplayText', () {
    test('format codes render uppercase', () {
      expect(DisplayText.formatLabel('odi'), 'ODI');
      expect(DisplayText.formatLabel('t20'), 'T20');
      expect(DisplayText.formatLabel('t10'), 'T10');
      expect(DisplayText.formatLabel('test'), 'Test');
      expect(DisplayText.formatLabel('ODI'), 'ODI');
    });

    test('title case never corrupts acronyms or mixed names', () {
      expect(DisplayText.titleCase('bulgaria women'), 'Bulgaria Women');
      expect(DisplayText.titleCase('namibia cricket ground, windhoek'),
          'Namibia Cricket Ground, Windhoek');
      expect(DisplayText.titleCase('IPL'), 'IPL');
      expect(DisplayText.titleCase('McCullum'), 'McCullum');
    });
  });

  group('Theme accents are thin, not chunky', () {
    test('premium card border is a 1px hairline, low gold alpha', () {
      final d = AppTheme.premiumCard();
      final border = d.border as Border;
      expect(border.top.width, 1.0);
      expect(border.top.color.a, lessThanOrEqualTo(0.25));
      expect(d.boxShadow!.length, 1);
    });

    test('hero card border is 1px, not the old 1.4px gold frame', () {
      final d = AppTheme.heroCard();
      final border = d.border as Border;
      expect(border.top.width, 1.0);
      expect(border.top.color.a, lessThanOrEqualTo(0.35));
    });
  });

  CricketMatch liveMatch({String batter = '', String bowler = ''}) {
    return CricketMatch(
      id: 'ux-1',
      teamA: 'Namibia',
      teamB: 'Ireland',
      format: 'odi',
      league: 'international',
      venueName: 'namibia cricket ground, windhoek',
      startTime: DateTime.now(),
      status: MatchStatus.live,
      scores: const [
        TeamScore(team: 'Namibia', runs: 321, wickets: 6, overs: 50, batted: true),
      ],
      currentBatter: batter,
      currentBowler: bowler,
      source: 'CricAPI',
    );
  }

  group('KingMatchCard', () {
    testWidgets('no blank Batting/Bowling rows when names missing',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: KingMatchCard(match: liveMatch(), onTap: () {}),
        ),
      ));
      await tester.pump();
      expect(find.textContaining('Batting:'), findsNothing);
      expect(find.textContaining('Bowling:'), findsNothing);
    });

    testWidgets('batter-only shows Batting, never a blank Bowling row',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: KingMatchCard(
              match: liveMatch(batter: 'JN Frylinck 45*'), onTap: () {}),
        ),
      ));
      await tester.pump();
      expect(find.textContaining('Batting: JN Frylinck'), findsOneWidget);
      expect(find.textContaining('Bowling:'), findsNothing);
    });

    testWidgets('format renders ODI and venue gets an icon, not emoji',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: KingMatchCard(match: liveMatch(), onTap: () {}),
        ),
      ));
      await tester.pump();
      expect(find.textContaining('ODI'), findsWidgets);
      expect(find.textContaining('odi'), findsNothing);
      expect(find.byIcon(Icons.location_on_outlined), findsOneWidget);
      expect(find.textContaining('📍'), findsNothing);
    });
  });

  group('PlayerProfileScreen tables', () {
    const player = Player(
      id: 'ux-p1',
      name: 'MG Erasmus',
      team: 'Namibia',
      battingByFormat: {
        'odi': BattingStats(
            matches: 3, runs: 92, average: 30.7, strikeRate: 83.3, highest: 68),
        't20': BattingStats(
            matches: 10, runs: 271, average: 38.7, strikeRate: 135.1, highest: 88),
      },
      bowlingByFormat: {
        'odi': BowlingStats(matches: 3, wickets: 1, average: 95.0),
      },
      source: 'cricsheet',
      sourceMatches: 13,
    );

    testWidgets('format chips and table cells use ODI, never raw odi',
        (tester) async {
      // Tall viewport so the lazy ListView builds the whole
      // profile (avoids scrollUntilVisible duplicate matches).
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(ChangeNotifierProvider<LanguageProvider>(
        create: (_) => LanguageProvider(),
        child: const MaterialApp(
          home: Scaffold(body: PlayerProfileScreen(player: player)),
        ),
      ));
      await tester.pumpAndSettle();
      // Chips + table FORMAT cells both render the display label.
      expect(find.text('ODI'), findsWidgets);
      expect(find.text('odi'), findsNothing);
      // Key numbers render (no mid-digit clipping assertion possible
      // in a unit test, but the narrowed columns keep them on screen).
      expect(find.text('92'), findsWidgets);
      expect(find.text('271'), findsWidgets);
    });
  });

  group('EmptyState', () {
    testWidgets('renders icon + one action, no emoji decoration',
        (tester) async {
      var tapped = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: EmptyState(
            icon: Icons.sports_cricket,
            message: 'No live matches right now.',
            actionLabel: 'Refresh',
            onAction: () => tapped = true,
          ),
        ),
      ));
      await tester.pump();
      expect(find.byIcon(Icons.sports_cricket), findsOneWidget);
      expect(find.text('Refresh'), findsOneWidget);
      await tester.tap(find.text('Refresh'));
      expect(tapped, isTrue);
    });
  });
}
