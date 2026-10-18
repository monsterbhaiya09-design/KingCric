import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:kingcric/models/match.dart';
import 'package:kingcric/models/player.dart';
import 'package:kingcric/screens/match_detail_screen.dart';
import 'package:kingcric/services/cricsheet_service.dart';
import 'package:kingcric/services/mock_data_service.dart';
import 'package:kingcric/utils/strings.dart';
import 'package:kingcric/widgets/squad_player_card.dart';

Widget _wrap(Widget child) => ChangeNotifierProvider<LanguageProvider>(
      create: (_) => LanguageProvider(),
      child: MaterialApp(home: child),
    );

void main() {
  // MERGE-LEAD: warm the parse-once Cricsheet cache ONCE in setUpAll
  // (real zone, before any test's fake-async starts). Do NOT warm it
  // with tester.runAsync inside a test: runAsync deadlocks when a
  // previous test pumped MatchDetailScreen, and the Squad / Venue
  // tab's asset-load future then never completes. setUpAll warm-up
  // makes every test await an already-completed future.
  setUpAll(() async {
    await CricsheetService.loadBundled();
  });

  final players = MockDataService().players();
  final virat = players.firstWhere((p) => p.id == 'p-virat');

  test('Match-centric: SquadPlayerCard shows format + vs-opponent + form',
      () {
    // Virat: T20 4188 runs, vs Pakistan 492 runs, recent form non-empty.
    expect(virat.battingInFormat('T20').runs, 4188);
    expect(virat.battingVs('Pakistan').runs, 492);
    expect(virat.recentForm, isNotEmpty);
  });

  testWidgets('Match-centric: SquadPlayerCard renders match context',
      (tester) async {
    await tester.pumpWidget(_wrap(Scaffold(
      body: SquadPlayerCard(
          player: virat, opponent: 'Pakistan', format: 'T20'),
    )));
    await tester.pump();
    expect(find.text('Virat Kohli'), findsOneWidget);
    expect(find.textContaining('Batting (T20): 4188 runs'), findsOneWidget);
    expect(find.textContaining('vs Pakistan: 492 runs'), findsOneWidget);
    expect(find.text('Recent form (last 5)'), findsOneWidget);
    expect(find.text('Tap for full profile'), findsOneWidget);
  });

  testWidgets('Match-centric: SquadPlayerCard never shows fake zeros',
      (tester) async {
    const empty = Player(id: 'p-x', name: 'Unknown Player', team: 'India');
    await tester.pumpWidget(_wrap(const Scaffold(
      body: SquadPlayerCard(
          player: empty, opponent: 'Pakistan', format: 'T20'),
    )));
    await tester.pump();
    expect(find.text('Stats not available for this player yet.'),
        findsOneWidget);
    expect(find.textContaining('0 runs'), findsNothing);
  });

  test('Match-centric: topPlayerMatchups keeps cross-squad pairs only', () {
    final squadA = players.where((p) => p.team == 'India').toList();
    final squadB = players.where((p) => p.team == 'Pakistan').toList();
    expect(squadA, isNotEmpty);
    expect(squadB, isNotEmpty);
    final top = topPlayerMatchups(squadA, squadB);
    expect(top, isNotEmpty);
    // Rohit vs Shaheen: 3 dismissals — the top cross-squad pair.
    expect(top.first.dismissals, 3);
    expect(top.first.batterName, 'Rohit Sharma');
    // Same-team pair (Virat vs Bumrah, both India) must NOT appear.
    final sameTeam = top.where((m) =>
        m.bowlerName == 'Jasprit Bumrah' &&
        m.batterName == 'Virat Kohli');
    expect(sameTeam, isEmpty);
  });

  test('Match-centric: new strings exist in EN + Hindi', () {
    for (final key in [
      'home_players_hint',
      'venue_h2h',
      'venue_stats',
      'player_matchups',
      'scorecard_empty',
      'retry',
      'squad_source_official',
      'squad_source_team',
      'squad_source_scorecard',
      'no_squad_data',
      'venue_no_data',
      'no_matchups_data',
      'not_enough_data',
    ]) {
      expect(Strings.t(key, AppLanguage.english), isNot(equals(key)),
          reason: 'EN missing for $key');
      expect(Strings.t(key, AppLanguage.hindi), isNot(equals(key)),
          reason: 'Hindi missing for $key');
    }
  });

  testWidgets('Match-centric: empty scorecard shows honest empty + Retry',
      (tester) async {
    final match = CricketMatch(
      id: 'm-empty',
      teamA: 'India',
      teamB: 'Pakistan',
      startTime: DateTime(2026, 10, 19, 17, 30),
      status: MatchStatus.upcoming,
      league: 'International',
      venueName: 'Dubai International Stadium',
    );
    await tester.pumpWidget(_wrap(MatchDetailScreen(match: match)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scorecard'));
    await tester.pumpAndSettle();
    expect(find.text('Scorecard not available yet.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets(
      'Match-centric: Squad tab resolves squads from team when ids empty',
      (tester) async {
    final match = CricketMatch(
      id: 'm-squad',
      teamA: 'India',
      teamB: 'Pakistan',
      format: 'ODI',
      startTime: DateTime(2026, 10, 19, 17, 30),
      status: MatchStatus.upcoming,
      league: 'International',
      // No squadA / squadB ids — squads must come from Cricsheet.
      // ODI format: Kohli plays ODIs (he retired from T20Is), so a
      // format-aware Cricsheet squad includes him.
    );
    // Tall viewport so both squad sections build without scrolling
    // (scrollUntilVisible is ambiguous with TabBarView + ListViews).
    // devicePixelRatio MUST be 1.0: physicalSize is in pixels, and
    // the default ratio 3.0 would shrink the logical width to ~267px.
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 4000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    // Cricsheet cache is warmed once in setUpAll (see top of file)
    // — no per-test runAsync warm-up (it deadlocks after a previous
    // test pumped this screen).
    await tester.pumpWidget(_wrap(MatchDetailScreen(match: match)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Squad'));
    await tester.pumpAndSettle();
    // Cricsheet-first squad label on the visible (India) section.
    // The ListView lazily builds only what fits the viewport, so
    // the Pakistan section is built only after scrolling to it —
    // an exact "2 labels" count would fail even when both sections
    // are Cricsheet-sourced. The unit test in
    // cricsheet_wiring_test.dart proves both squads resolve from
    // Cricsheet; here we prove the tab renders them (India first,
    // then Pakistan after scrolling) and the old mock team-filter
    // label appears NOWHERE for teams Cricsheet covers.
    expect(find.textContaining('calculated from ball-by-ball'),
        findsWidgets);
    expect(find.textContaining('from available player data'), findsNothing);
    expect(find.text('Virat Kohli'), findsOneWidget);
    // Drag the Squad ListView down to the Pakistan section. Do NOT
    // use scrollUntilVisible here: it evaluates the finder
    // mid-scroll, when the ListView transiently holds two copies
    // of the target card, and throws "Too many elements".
    await tester.drag(find.byType(ListView).first, const Offset(0, -6000));
    await tester.pumpAndSettle();
    expect(find.text('Babar Azam'), findsOneWidget);
    expect(find.textContaining('from available player data'), findsNothing);
  });

  testWidgets('Match-centric: Venue & H2H tab shows venue + H2H + matchups',
      (tester) async {
    final match = MockDataService().matches().first;
    // Tall viewport so the whole Venue tab builds without scrolling.
    // devicePixelRatio MUST be 1.0 (see Squad test above).
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 4000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    // Cricsheet cache is warmed once in setUpAll (see top of file)
    // — no per-test runAsync warm-up (it deadlocks after a previous
    // test pumped this screen).
    await tester.pumpWidget(_wrap(MatchDetailScreen(match: match)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Venue & H2H'));
    await tester.pumpAndSettle();
    expect(find.text('Head-to-Head'), findsOneWidget);
    expect(find.textContaining('Top Player Matchups'), findsOneWidget);
  });
}
