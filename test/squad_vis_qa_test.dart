import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:kingcric/models/match.dart';
import 'package:kingcric/screens/home_screen.dart';
import 'package:kingcric/screens/match_detail_screen.dart';
import 'package:kingcric/screens/player_profile_screen.dart';
import 'package:kingcric/services/cricsheet_service.dart';
import 'package:kingcric/services/mock_data_service.dart';
import 'package:kingcric/utils/strings.dart';
import 'package:kingcric/widgets/premium_widgets.dart';
import 'package:kingcric/widgets/stat_card.dart';

/// FIX VIS — widget tests for the bugs found by real visual QA of
/// the v1.0.0+4 web build. Each test reproduces the observed
/// symptom and fails on the pre-fix layout.
Widget _wrap(Widget child) => ChangeNotifierProvider<LanguageProvider>(
      create: (_) => LanguageProvider(),
      child: MaterialApp(home: child),
    );

CricketMatch _liveMatch() => CricketMatch(
      id: 'm-vis',
      teamA: 'India',
      teamB: 'Pakistan',
      startTime: DateTime(2026, 10, 19, 17, 30),
      status: MatchStatus.live,
      league: 'International',
      format: 'ODI',
      venueName: 'Dubai International Stadium',
      scores: const [],
    );

Finder _heroTitle() => find.byWidgetPredicate((w) =>
    w is Text &&
    w.data == 'India vs Pakistan' &&
    w.style?.fontSize == 23);

void main() {
  // Warm the parse-once Cricsheet cache in real async (same
  // pattern as match_centric_test.dart): warming it inside a
  // test's fake async deadlocks the ball-data / squad loads.
  setUpAll(() async {
    await CricsheetService.loadBundled();
  });

  test('VIS date: last-updated label carries date + time', () {
    expect(DisplayText.lastUpdatedLabel(DateTime(2026, 10, 24, 17, 5)),
        '24 Oct 2026, 17:05');
  });

  testWidgets('VIS 1: header never clips scrolled content',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 1200);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_wrap(MatchDetailScreen(match: _liveMatch())));
    await tester.pumpAndSettle();
    final tabBarBottom = tester.getRect(find.byType(TabBar)).bottom;
    final topAtRest = tester.getRect(_heroTitle()).top;
    expect(topAtRest, greaterThanOrEqualTo(tabBarBottom),
        reason: 'hero title must start below the tab bar');
    // Scroll down hard, then all the way back to the top: the
    // first card must come back fully visible, never stranded
    // half-hidden behind the fixed header.
    await tester.drag(find.byType(ListView).first, const Offset(0, -1500));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, 1500));
    await tester.pumpAndSettle();
    final heroBox = tester.getRect(_heroTitle());
    expect(heroBox.top, greaterThanOrEqualTo(tabBarBottom),
        reason: 'after scroll-back the hero title must sit below '
            'the tab bar, not under it');
    expect(heroBox.top, greaterThanOrEqualTo(0));
    expect(heroBox.bottom,
        lessThanOrEqualTo(tester.view.physicalSize.height));
  });

  testWidgets('VIS 2: ball-by-ball loading resolves to no-data',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 1200);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_wrap(MatchDetailScreen(match: _liveMatch())));
    // pumpAndSettle advances the 12s ball-data timeout in fake
    // async, so a stuck loader cannot hide behind "still
    // waiting" here.
    await tester.pumpAndSettle();
    expect(find.text('Loading ball-by-ball…'), findsNothing,
        reason: 'the loading placeholder must resolve, never stick');
    expect(find.textContaining('Ball-by-ball not available'),
        findsWidgets,
        reason: 'no ball data must land on an honest no-data state');
  });

  testWidgets('VIS 3: profile stat cards hug their content',
      (tester) async {
    final player = MockDataService().players().first;
    await tester.pumpWidget(_wrap(PlayerProfileScreen(player: player)));
    await tester.pumpAndSettle();
    final card = find.byType(StatCard).first;
    expect(card, findsOneWidget);
    final height = tester.getSize(card).height;
    // Content is ~110px tall; the old aspect-ratio grid grew
    // cells to 220-380px on wide screens. 160 is a generous cap.
    expect(height, lessThan(160),
        reason: 'stat cards must not stretch into tall blank areas');
    expect(height, greaterThan(50));
  });

  testWidgets('VIS 4: wide viewport renders a centered column',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_wrap(MatchDetailScreen(match: _liveMatch())));
    await tester.pumpAndSettle();
    final listBox = tester.getRect(find.byType(ListView).first);
    expect(listBox.width, lessThanOrEqualTo(710),
        reason: 'content column must cap at ~700dp on wide screens');
    expect(listBox.left, greaterThan(100),
        reason: 'the capped column must be centered, not left-hugging');
  });

  testWidgets('VIS 5a: Home separates live-feed vs history labels',
      (tester) async {
    // Layer wording lives in the mock_mode string itself (the
    // key-missing banner renders it verbatim): the live feed is
    // demo data, the player history is real Cricsheet — never a
    // bare "Demo data" that reads as if everything were fake.
    expect(Strings.t('mock_mode', AppLanguage.english),
        contains('Demo data'));
    expect(Strings.t('mock_mode', AppLanguage.english),
        contains('Cricsheet'));
    // Home pump: the date rule holds whenever a Last-updated
    // line renders. (Banner presence itself is key-mode
    // dependent: with a key compiled in, Home is not in
    // key-missing demo mode, so the banners legitimately
    // differ — the string contract above is mode-independent.)
    await tester.pumpWidget(_wrap(const Scaffold(body: HomeScreen())));
    await tester.pumpAndSettle();
    final lastUpdated = find.textContaining('Last updated');
    if (lastUpdated.evaluate().isNotEmpty) {
      expect(find.textContaining(RegExp(r'Last updated.*\d{4}')),
          findsWidgets,
          reason: 'Last updated must carry a date, not a bare time');
    }
  });

  testWidgets('VIS 5b: Squad tab labels its layer as history',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 4000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final match = CricketMatch(
      id: 'm-vis-squad',
      teamA: 'India',
      teamB: 'Pakistan',
      format: 'ODI',
      startTime: DateTime(2026, 10, 19, 17, 30),
      status: MatchStatus.upcoming,
      league: 'International',
    );
    await tester.pumpWidget(_wrap(MatchDetailScreen(match: match)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Squad'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Squad history'), findsWidgets);
  });
}
