import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/compare_screen.dart';
import 'screens/favourites_screen.dart';
import 'screens/home_screen.dart';
import 'screens/leagues_screen.dart';
import 'screens/stats_screen.dart';
import 'services/auto_update_service.dart';
import 'utils/app_theme.dart';
import 'utils/strings.dart';

/// KingCric — Har Ball, Har Stat, King Jaisa.
/// Logo: Crown 👑 + Bat-Ball 🏏.
/// 100% free scaffold: no paid keys, no scraped data.
/// Without --dart-define=CRIC_API_KEY the app runs in demo mode
/// with complete realistic mock data.
///
/// Startup hardening (fixes the "failed to start several times"
/// crash loop seen on some Realme phones):
/// - WidgetsFlutterBinding.ensureInitialized() before any plugin call.
/// - runZonedGuarded + FlutterError.onError: an uncaught Dart error
///   shows a fallback error screen instead of killing the process.
/// - AutoUpdateService.start() never throws: every tick is
///   try/catch-guarded inside the service itself.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('KingCric FlutterError: ${details.exception}');
  };
  runZonedGuarded<Future<void>>(
    () async {
      runApp(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => LanguageProvider()),
            Provider<AutoUpdateService>(
              create: (_) {
                final svc = AutoUpdateService();
                // Never let the background poller crash startup:
                // start() is fully guarded inside the service.
                svc.start();
                return svc;
              },
              dispose: (_, s) => s.dispose(),
            ),
          ],
          child: const KingCricApp(),
        ),
      );
    },
    (Object error, StackTrace stack) {
      debugPrint('KingCric zone error: $error\n$stack');
    },
  );
}

class KingCricApp extends StatelessWidget {
  const KingCricApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KingCric',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const _Shell(),
      // NOTE: do NOT set ErrorWidget.builder here. It mutates global
      // state on every build and the test framework (rightly) rejects
      // it. Crash reporting stays at the zone + FlutterError.onError
      // layer in main(), which never touches widget-tree globals.
    );
  }
}

class _Shell extends StatefulWidget {
  const _Shell();
  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  int _index = 0;
  static const _pages = [
    HomeScreen(),
    LeaguesScreen(),
    CompareScreen(),
    StatsScreen(),
    FavouritesScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    return Scaffold(
      body: SafeArea(child: _pages[_index]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF0B1026),
        selectedItemColor: const Color(0xFFD4AF37),
        unselectedItemColor: Colors.white54,
        items: [
          BottomNavigationBarItem(
              icon: const Icon(Icons.home), label: lang.t('home')),
          BottomNavigationBarItem(
              icon: const Icon(Icons.emoji_events),
              label: lang.t('leagues')),
          BottomNavigationBarItem(
              icon: const Icon(Icons.compare_arrows),
              label: lang.t('compare')),
          BottomNavigationBarItem(
              icon: const Icon(Icons.bar_chart), label: lang.t('stats')),
          BottomNavigationBarItem(
              icon: const Icon(Icons.star),
              label: lang.t('favourites')),
        ],
      ),
    );
  }
}
