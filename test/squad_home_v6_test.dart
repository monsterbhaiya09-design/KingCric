import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:kingcric/screens/home_screen.dart';
import 'package:kingcric/services/cricsheet_service.dart';
import 'package:kingcric/utils/strings.dart';
import 'package:kingcric/widgets/match_card.dart';

/// FIX HOME v6 — slim Home header so the first match card starts
/// much higher on a phone screen. The pre-fix header stacked a
/// large hero card + full search bar + filter rows + freshness row
/// + format chips before the first card (~40% of a phone screen,
/// ~548dp to the first card in a no-key test env with banners).
/// These tests pin the slim result: first card clearly higher,
/// hero/search heights bounded, and every control still present.
///
/// NOTE on viewport: tests run at 500x800, not 390 wide, because
/// pumping Home at 390 triggers a PRE-EXISTING RenderFlex
/// overflow in match_card.dart:235 (out of scope for this squad —
/// match_card.dart is untouched). Header heights are
/// width-independent after this fix (single-line tagline, fixed
/// search/tab/chip heights), so the measurement is valid.
Widget _wrap(Widget child) => ChangeNotifierProvider<LanguageProvider>(
      create: (_) => LanguageProvider(),
      child: MaterialApp(home: Scaffold(body: child)),
    );

void main() {
  setUpAll(() async {
    await CricsheetService.loadBundled();
  });

  testWidgets('HOME v6: first match card starts clearly higher',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(500, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_wrap(const HomeScreen()));
    await tester.pumpAndSettle();
    final cards = find.byType(KingMatchCard);
    expect(cards, findsWidgets,
        reason: 'Home must still show match cards');
    final firstTop = tester.getRect(cards.first).top;
    // Pre-fix this was 547.85dp in this same no-key test env
    // (two state banners stack above the cards there; on a real
    // phone with a key there are fewer, so the absolute number
    // is env-dependent — what matters is the fixed header stack
    // above the banners shrank by ~90dp). Post-fix: 458dp.
    // Bound sits between the two with margin on both sides.
    expect(firstTop, lessThan(480),
        reason: 'first match card top ($firstTop) must sit clearly '
            'higher than the pre-fix 547.85dp');
    expect(firstTop, greaterThan(0));
  });

  testWidgets('HOME v6: hero and search are compact but present',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(500, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_wrap(const HomeScreen()));
    await tester.pumpAndSettle();
    // Search bar still exists and is compact (was ~56dp tall).
    final search = find.byType(TextField);
    expect(search, findsOneWidget);
    expect(tester.getRect(search).height, lessThanOrEqualTo(44),
        reason: 'search bar must be compact, not full-height');
    // Hero title still present (text unchanged, just smaller).
    expect(find.text('KingCric'), findsWidgets);
  });

  testWidgets('HOME v6: every header control still exists',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(500, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_wrap(const HomeScreen()));
    await tester.pumpAndSettle();
    // Status filter tabs (labels carry a check on selection).
    expect(find.textContaining('Live'), findsWidgets);
    expect(find.text('Upcoming'), findsWidgets);
    expect(find.text('Finished'), findsWidgets);
    // Format chips.
    for (final f in ['Test', 'ODI', 'T20', 'T10']) {
      expect(find.text(f), findsWidgets, reason: 'chip $f must exist');
    }
    // Manual refresh + language toggle + search hint.
    expect(find.text('Refresh'), findsWidgets);
    expect(find.text('EN'), findsWidgets);
    expect(find.byType(TextField), findsOneWidget);
  });
}
