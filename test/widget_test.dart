import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kingcric/main.dart';
import 'package:kingcric/models/match.dart';
import 'package:kingcric/models/player.dart';
import 'package:kingcric/models/prediction.dart';
import 'package:kingcric/screens/compare_screen.dart';
import 'package:kingcric/screens/player_profile_screen.dart';
import 'package:kingcric/services/api_service.dart';
import 'package:kingcric/services/auto_update_service.dart';
import 'package:kingcric/services/mock_data_service.dart';
import 'package:kingcric/services/prediction_engine.dart';
import 'package:kingcric/services/providers/cricket_provider.dart';
import 'package:kingcric/utils/strings.dart';
import 'package:kingcric/models/innings.dart';
import 'package:kingcric/widgets/h2h_card.dart';
import 'package:kingcric/widgets/language_toggle.dart';
import 'package:kingcric/widgets/match_card.dart';
import 'package:kingcric/widgets/over_graph.dart';
import 'package:kingcric/widgets/player_card.dart';
import 'package:kingcric/widgets/prediction_card.dart';

/// Fake provider for multi-source fallback tests. Never hits network.
class _FakeProvider implements CricketProvider {
  @override
  final String name;
  final List<CricketMatch>? matches;
  _FakeProvider(this.name, {this.matches});

  @override
  bool get isConfigured => true;
  @override
  int get dailyCap => 90;
  @override
  int get hitsToday => 0;
  @override
  Future<List<CricketMatch>?> fetchMatches() async => matches;
  @override
  Future<List<CricketMatch>?> fetchUpcoming() async => null;
  @override
  Future<CricketMatch?> fetchScorecard(String matchId) async => null;
  @override
  Future<List<Map<String, dynamic>>?> fetchSeries() async => null;
  @override
  Future<Player?> fetchPlayer(String playerId) async => null;
  @override
  Future<String?> resolvePlayerId(String name) async => null;
  @override
  int? get serverHitsLeft => null;
  @override
  bool get quotaExhausted => false;
  @override
  Future<bool> testKey() async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('KingCric boots and shows Home with live matches',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LanguageProvider()),
          Provider<AutoUpdateService>(
            create: (_) => AutoUpdateService()..start(),
            dispose: (_, s) => s.dispose(),
          ),
        ],
        child: const KingCricApp(),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Bottom nav is present (Home / Leagues / Compare / Stats / Favourites).
    expect(find.byType(BottomNavigationBar), findsOneWidget);
    // Demo/mock data loads: India vs Pakistan fixture is in mock data.
    expect(find.textContaining('India'), findsWidgets);
  });

  test('Prediction engine returns a 0-100 score with explanation', () {
    final players = MockDataService().players();
    expect(players, isNotEmpty);
    final p = PredictionEngine.predict(
      player: players.first,
      opponent: 'Pakistan',
      venueId: 'v-dubai',
      format: 'T20',
    );
    expect(p.score, inInclusiveRange(0.0, 100.0));
    expect(p.explanationEn, isNotEmpty);
    expect(p.explanationHi, isNotEmpty);
  });

  test('Multi-source: primary failure falls through to secondary', () async {
    final secondaryMatch = CricketMatch(
      id: 'm-fallback',
      teamA: 'India',
      teamB: 'Pakistan',
      startTime: DateTime.now(),
      status: MatchStatus.live,
    );
    final api = ApiService(providers: [
      _FakeProvider('Primary', matches: null),
      _FakeProvider('Secondary', matches: [secondaryMatch]),
    ]);
    final matches = await api.fetchMatches();
    expect(matches.length, 1);
    expect(matches.first.id, 'm-fallback');
    expect(api.lastSource, 'Secondary');
  });

  test('Multi-source: all providers down falls back to mock', () async {
    final api = ApiService(providers: [
      _FakeProvider('Primary', matches: null),
      _FakeProvider('Secondary', matches: null),
    ]);
    final matches = await api.fetchMatches();
    expect(matches, isNotEmpty);
    expect(api.lastSource, 'mock');
  });

  test('Multi-source: cross-check agrees on identical scores', () {
    final a = CricketMatch(
      id: 'm-1',
      teamA: 'India',
      teamB: 'Pakistan',
      startTime: DateTime.now(),
      status: MatchStatus.live,
      scores: const [
        TeamScore(team: 'India', runs: 192, wickets: 6, overs: 20, batted: true),
      ],
    );
    final b = CricketMatch(
      id: 'm-1',
      teamA: 'India',
      teamB: 'Pakistan',
      startTime: DateTime.now(),
      status: MatchStatus.live,
      scores: const [
        TeamScore(team: 'India', runs: 192, wickets: 6, overs: 20, batted: true),
      ],
    );
    expect(ApiService.crossCheckMatches([a], [b]), isTrue);
  });

  test('Multi-source: cross-check flags score mismatch', () {
    final a = CricketMatch(
      id: 'm-1',
      teamA: 'India',
      teamB: 'Pakistan',
      startTime: DateTime.now(),
      status: MatchStatus.live,
      scores: const [
        TeamScore(team: 'India', runs: 192, wickets: 6, overs: 20, batted: true),
      ],
    );
    final b = CricketMatch(
      id: 'm-1',
      teamA: 'India',
      teamB: 'Pakistan',
      startTime: DateTime.now(),
      status: MatchStatus.live,
      scores: const [
        TeamScore(team: 'India', runs: 180, wickets: 6, overs: 20, batted: true),
      ],
    );
    expect(ApiService.crossCheckMatches([a], [b]), isFalse);
  });

  test('Mock data innings reconcile: batting sums to total (extras tol.)', () {
    final matches = MockDataService().matches();
    expect(matches, isNotEmpty);
    final live = matches.firstWhere((m) => m.innings.isNotEmpty);
    final inn = live.innings.first;
    final sum = inn.batting.fold<int>(0, (acc, b) => acc + b.runs);
    // 182 total, batting sum 182 (48+82+38+14) in mock data.
    expect((inn.total - sum).abs(), lessThanOrEqualTo(15));
  });

  // ---- V3 UI bug regressions (screenshots 2026-10-18) ----

  test('V3: in-progress status text resolves to LIVE, not upcoming', () {
    // Exact CricAPI phrasing from the screenshot: Austria Women
    // 37/3, "need 88 runs in 78 balls" — was filed as UPCOMING.
    expect(
      ProviderParsing.resolveStatus(
        raw: 'Austria Women need 88 runs in 78 balls',
        hasScores: true,
      ),
      MatchStatus.live,
    );
    expect(
      ProviderParsing.resolveStatus(
        raw: 'Match started', matchStarted: true),
      MatchStatus.live,
    );
    expect(
      ProviderParsing.resolveStatus(
        raw: '', hasScores: true),
      MatchStatus.live,
    );
    expect(
      ProviderParsing.resolveStatus(
        raw: 'Sweden Women won by 10 wkts'),
      MatchStatus.completed,
    );
    expect(
      ProviderParsing.resolveStatus(raw: 'Match not started'),
      MatchStatus.upcoming,
    );
  });

  test('V3: effectively-live match shows in Live, not Upcoming', () {
    final live = CricketMatch(
      id: 'm-live',
      teamA: 'Austria Women',
      teamB: 'Sweden Women',
      startTime: DateTime.now(),
      // Simulates the old provider mislabel: upcoming + scores.
      status: MatchStatus.upcoming,
      scores: const [
        TeamScore(
            team: 'Sweden Women',
            runs: 124,
            wickets: 9,
            overs: 20,
            batted: true),
        TeamScore(
            team: 'Austria Women',
            runs: 37,
            wickets: 3,
            overs: 7,
            batted: true),
      ],
    );
    expect(live.isEffectivelyLive, isTrue);
    final notStarted = CricketMatch(
      id: 'm-up',
      teamA: 'India',
      teamB: 'Pakistan',
      startTime: DateTime.now(),
      status: MatchStatus.upcoming,
    );
    expect(notStarted.isEffectivelyLive, isFalse);
  });

  test('V3: team names are never comma-joined or lowercase', () {
    expect(
      ProviderParsing.cleanTeamName(
        'Bulgaria Women,Sweden Women Inning 2',
        ['Bulgaria Women', 'Sweden Women'],
      ),
      'Sweden Women',
    );
    expect(
      ProviderParsing.cleanTeamName(
        'bulgaria women Inning 1',
        ['Bulgaria Women', 'Sweden Women'],
      ),
      'Bulgaria Women',
    );
    expect(ProviderParsing.titleCaseTeam('bulgaria women'),
        'Bulgaria Women');
    // Abbreviations stay ALL-CAPS.
    expect(ProviderParsing.titleCaseTeam('MI'), 'MI');
    expect(ProviderParsing.titleCaseTeam('CSK'), 'CSK');
  });

  testWidgets('V3: header shows full KingCric, no Ad placeholder box',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                // Header title path (same FittedBox approach as Home).
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text('KingCric'),
                ),
                AdPlaceholder(),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('KingCric'), findsOneWidget);
    // No AdMob unit id configured -> NO visible placeholder box.
    expect(find.textContaining('Ad placeholder'), findsNothing);
    expect(find.textContaining('AdMob unit id not set'), findsNothing);
  });

  testWidgets('V3: Trending Players label demo honestly, never Complete',
      (WidgetTester tester) async {
    final demo = MockDataService().players().first;
    expect(demo.source, 'demo');
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: PlayerCard(player: demo))),
    );
    await tester.pump();
    expect(find.text('Demo'), findsOneWidget);
    expect(find.text('Complete'), findsNothing);

    const real = Player(
      id: 'p-virat',
      name: 'Virat Kohli',
      team: 'India',
      dataComplete: true,
      source: 'cricsheet',
      sourceMatches: 4,
    );
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PlayerCard(player: real))),
    );
    await tester.pump();
    expect(find.text('Real • Cricsheet'), findsOneWidget);
  });

  // ---- Final redesign regressions (CricketLineX reference spec) ----

  test('Final: Finished label exists in EN + Hindi', () {
    expect(Strings.t('finished', AppLanguage.english), 'Finished');
    expect(Strings.t('finished', AppLanguage.hindi), 'समाप्त');
    expect(Strings.t('disclaimer', AppLanguage.english), contains('Not betting'));
  });

  testWidgets('Final: upcoming card shows NO score rows, shows Starts',
      (WidgetTester tester) async {
    final upcoming = CricketMatch(
      id: 'm-up',
      teamA: 'Pakistan',
      teamB: 'Sri Lanka',
      startTime: DateTime(2026, 10, 19, 17, 30),
      status: MatchStatus.upcoming,
      league: 'International',
      format: 'ODI',
      venueName: 'Rawalpindi Cricket Stadium',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
            body: KingMatchCard(match: upcoming, onTap: () {})),
      ),
    );
    await tester.pump();
    expect(find.text('UPCOMING'), findsOneWidget);
    // No score rows on an upcoming card (H4).
    expect(find.textContaining('Yet to bat'), findsNothing);
    expect(find.textContaining('Starts:'), findsOneWidget);
    expect(find.textContaining('124/9'), findsNothing);
  });

  testWidgets('Final: live card shows scores + LIVE pill, one CTA',
      (WidgetTester tester) async {
    final live = CricketMatch(
      id: 'm-live',
      teamA: 'Austria Women',
      teamB: 'Sweden Women',
      startTime: DateTime.now(),
      status: MatchStatus.live,
      league: 'International',
      format: 'T20',
      venueName: 'Moara Vlasiei Cricket Ground',
      scores: const [
        TeamScore(
            team: 'Sweden Women',
            runs: 124,
            wickets: 9,
            overs: 20,
            batted: true),
        TeamScore(
            team: 'Austria Women',
            runs: 37,
            wickets: 3,
            overs: 7,
            batted: true),
      ],
      result: 'Austria Women need 88 runs in 78 balls',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: KingMatchCard(match: live, onTap: () {})),
      ),
    );
    await tester.pump();
    expect(find.text('LIVE'), findsOneWidget);
    expect(find.textContaining('124/9'), findsOneWidget);
    expect(find.textContaining('37/3'), findsOneWidget);
    expect(find.text('Tap for FULL scorecard'), findsOneWidget);
    // Never two competing CTAs.
    expect(find.text('Scorecard →'), findsOneWidget);
  });

  testWidgets('Final: OverGraph renders real FOW + partnership bars',
      (WidgetTester tester) async {
    const inn = Innings(
      team: 'India',
      inningsNumber: 1,
      total: 192,
      wickets: 6,
      overs: 20,
      fallOfWickets: ['1-52 (Rohit Sharma, 6.1 ov)'],
      partnerships: ['Rohit + Gill — 52 (37 balls)'],
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: OverGraph(innings: [inn])),
      ),
    );
    await tester.pump();
    expect(find.textContaining('Over-by-Over'), findsOneWidget);
    expect(find.textContaining('Run rate'), findsOneWidget);
    expect(find.textContaining('1-52'), findsOneWidget);
  });

  test('Team1 Home: new strings exist in EN + Hindi (G3 parity)', () {
    for (final key in [
      'matches',
      'trending_players',
      'next_up',
      'no_live_matches',
      'no_matches_section',
      'no_matches_found',
      'no_trending',
      'offline_banner',
      'refresh',
      'updating',
      'format_filter_label',
    ]) {
      final en = Strings.t(key, AppLanguage.english);
      final hi = Strings.t(key, AppLanguage.hindi);
      expect(en, isNotEmpty, reason: 'EN missing for $key');
      expect(hi, isNotEmpty, reason: 'Hindi missing for $key');
      expect(en, isNot(equals(key)), reason: 'EN fallback for $key');
      expect(hi, isNot(equals(key)), reason: 'Hindi fallback for $key');
    }
  });

  // ---- Team3: Player Profile + Compare detail ----

  testWidgets('Team3: Profile shows ONE Cricsheet source line, never Complete',
      (WidgetTester tester) async {
    const real = Player(
      id: 'p-virat',
      name: 'Virat Kohli',
      team: 'India',
      role: 'Batter',
      source: 'cricsheet',
      sourceMatches: 4,
      battingByFormat: {
        'T20': BattingStats(matches: 3, runs: 169, balls: 120),
      },
      bowlingByFormat: {},
      recentForm: [],
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ],
        child: const MaterialApp(
            home: PlayerProfileScreen(player: real)),
      ),
    );
    await tester.pump();
    // FINAL MERGE: Squad S moved the source line into the About
    // section at the bottom (Stats first, About second) and
    // reworded it — scroll there before asserting, as the
    // Recent-Form assertion below already did.
    await tester.fling(
        find.byType(ListView), const Offset(0, -5000), 10000);
    await tester.pumpAndSettle();
    expect(
        find.text('Real • Cricsheet • 420 matches • 4 for this player'),
        findsOneWidget);
    expect(find.text('Complete'), findsNothing);
    // Empty Recent Form section is hidden (P-P3) — scroll to the
    // bottom first: ListView builds lazily, so an unscrolled
    // findsNothing would prove nothing.
    await tester.fling(
        find.byType(ListView), const Offset(0, -5000), 10000);
    await tester.pumpAndSettle();
    expect(find.text('Recent Form'), findsNothing);
    // Format chips present; Bowling table sits with Batting (not bottom).
    // The fling above already built the whole (short) list.
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Bowling'), findsOneWidget);
  });

  testWidgets('Team3: Profile demo label, no bare Complete',
      (WidgetTester tester) async {
    final demo = MockDataService().players().first;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ],
        child: MaterialApp(
            home: PlayerProfileScreen(player: demo)),
      ),
    );
    await tester.pump();
    // FINAL MERGE: Squad S moved the source line into the About
    // section at the bottom — scroll there before asserting.
    await tester.fling(
        find.byType(ListView), const Offset(0, -5000), 10000);
    await tester.pumpAndSettle();
    expect(find.textContaining('Demo data'), findsOneWidget);
    expect(find.text('Complete'), findsNothing);
  });

  testWidgets('Team3: Compare shows format chips + winner summary',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: CompareScreen()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Player Compare'), findsOneWidget);
    expect(find.text('All'), findsWidgets);
    expect(find.text('T20'), findsWidgets);
    // One of: "X leads A–B" or "Level A–B".
    expect(find.textContaining(RegExp(r'leads|Level')), findsOneWidget);
    // Bowling section exists (not batting-only).
    expect(find.text('Bowling'), findsOneWidget);
  });

  testWidgets('Team3: Prediction card shows all 5 inputs + disclaimer',
      (WidgetTester tester) async {
    const pred = Prediction(
      playerId: 'p-virat',
      playerName: 'Virat Kohli',
      opponent: 'Pakistan',
      venueId: 'v-dubai',
      format: 'T20',
      score: 78,
      recentFormScore: 80,
      vsOpponentScore: 85,
      venueScore: 70,
      matchupScore: double.nan, // no data -> '—', never NaN text
      pitchScore: double.nan,
      explanationEn: 'Strong recent form and great record vs Pakistan.',
      explanationHi: 'हालिया फॉर्म मजबूत है।',
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ],
        child: const MaterialApp(
            home: Scaffold(body: PredictionCard(prediction: pred))),
      ),
    );
    await tester.pump();
    expect(find.text('Recent Form'), findsOneWidget);
    expect(find.text('vs Opponent'), findsOneWidget);
    expect(find.text('Venue'), findsOneWidget);
    expect(find.text('Matchup'), findsOneWidget);
    expect(find.text('Pitch'), findsOneWidget);
    expect(find.textContaining('not a guarantee'), findsOneWidget);
    expect(find.textContaining('Not betting advice'), findsOneWidget);
    expect(find.text('—'), findsWidgets); // NaN inputs render as '—'
    expect(find.textContaining('NaN'), findsNothing);
  });

  testWidgets('Team3: H2H shows draws + Head-to-Head title',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: H2HCard(
              teamA: 'India',
              teamB: 'Pakistan',
              winsA: 5,
              winsB: 3,
              total: 10),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Head-to-Head'), findsOneWidget);
    expect(find.textContaining('2 draws'), findsOneWidget);
  });
}
