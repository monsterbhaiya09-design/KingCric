import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:kingcric/screens/home_screen.dart';
import 'package:kingcric/services/cricsheet_service.dart';
import 'package:kingcric/utils/strings.dart';

/// MERGE v6 tests — things only the merge itself could prove:
/// (1) the Home CTA row no longer overflows at a 390dp phone width
/// (the pre-merge test-font overflow in match_card.dart:235);
/// (2) the Venue tab's new players section has real data to show
/// for the 2026-10-25 phone case (ICC Academy Ground, Dubai) from
/// the regenerated full-archive asset.
Widget wrap(Widget c) => ChangeNotifierProvider<LanguageProvider>(
      create: (_) => LanguageProvider(),
      child: MaterialApp(home: Scaffold(body: c)),
    );

void main() {
  late CricsheetService cs;
  setUpAll(() async {
    cs = await CricsheetService.loadBundled();
  });

  testWidgets('MERGE v6: Home CTA row fits at 390dp phone width',
      (t) async {
    t.view.devicePixelRatio = 1.0;
    t.view.physicalSize = const Size(390, 844);
    addTearDown(t.view.reset);
    await t.pumpWidget(wrap(const HomeScreen()));
    await t.pumpAndSettle();
    expect(find.text('Tap for FULL scorecard'), findsWidgets);
  });

  test('MERGE v6: venue player data exists for ICC Academy Ground',
      () {
    final waseem = cs.playerVenueStats(
        'Waseem Muhammad', 'ICC Academy Ground, Dubai',
        team: 'United Arab Emirates');
    expect(waseem, isNotNull,
        reason: 'Waseem Muhammad must have ICC Academy numbers');
    expect(
        waseem!.battingMatches > 0 || waseem.bowlingMatches > 0, isTrue);
    final leaders =
        cs.topPlayersAtVenue('ICC Academy Ground, Dubai', limit: 5);
    expect(leaders.batters, isNotEmpty,
        reason: 'venue leaders must exist for the Venue tab section');
    expect(leaders.batters.first.runs, greaterThan(0));
  });

  test('MERGE v6: squad member venue lookup resolves via own team',
      () {
    // The Venue tab passes each squad player's OWN team string, so
    // a provider name like "UAE" never has to match the Cricsheet
    // team string for the row to appear.
    final chopra = cs.playerVenueStats(
        'R Chopra', 'ICC Academy Ground, Dubai',
        team: 'United Arab Emirates');
    expect(chopra, isNotNull);
  });
}
