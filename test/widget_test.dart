import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kingcric/main.dart';
import 'package:kingcric/services/auto_update_service.dart';
import 'package:kingcric/services/mock_data_service.dart';
import 'package:kingcric/services/prediction_engine.dart';
import 'package:kingcric/utils/strings.dart';

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
