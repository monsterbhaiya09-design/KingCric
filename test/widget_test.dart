import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kingcric/main.dart';
import 'package:kingcric/models/match.dart';
import 'package:kingcric/models/player.dart';
import 'package:kingcric/services/api_service.dart';
import 'package:kingcric/services/auto_update_service.dart';
import 'package:kingcric/services/mock_data_service.dart';
import 'package:kingcric/services/prediction_engine.dart';
import 'package:kingcric/services/providers/cricket_provider.dart';
import 'package:kingcric/utils/strings.dart';

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
  Future<CricketMatch?> fetchScorecard(String matchId) async => null;
  @override
  Future<List<Map<String, dynamic>>?> fetchSeries() async => null;
  @override
  Future<Player?> fetchPlayer(String playerId) async => null;
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
}
