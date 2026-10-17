/// KingCric constants. No paid keys. No scraped data.
/// Free API key is passed at run time via --dart-define=CRIC_API_KEY=...
/// Example: flutter run --dart-define=CRIC_API_KEY=YOUR_FREE_KEY
class AppConstants {
  static const String appName = 'KingCric';
  static const String tagline = 'Har Ball, Har Stat, King Jaisa.';

  /// Base URL of the free cricket API (CricAPI-compatible shape).
  /// The ApiService never scrapes Cricbuzz / Cricinfo / Crex / Cricmetrics.
  /// Plug any free provider here by implementing the same JSON shape.
  static const String freeApiBaseUrl = 'https://api.cricapi.com/v1';

  /// Passed via --dart-define. Empty means "mock mode" (works offline).
  static const String cricApiKey = String.fromEnvironment(
    'CRIC_API_KEY',
    defaultValue: '',
  );

  static bool get hasApiKey => cricApiKey.isNotEmpty;

  /// Free-tier friendly polling: live matches fast, finished matches
  /// fetched once immediately, everything else backed off.
  static const Duration livePollInterval = Duration(seconds: 45);
  static const Duration finishedPollInterval = Duration(minutes: 5);
  static const Duration idlePollInterval = Duration(minutes: 15);

  static const List<String> formats = ['Test', 'ODI', 'T20', 'T10'];
  static const List<String> leagues = [
    'International',
    'IPL',
    'PSL',
    'Big Bash',
    'T10 League',
    'Ranji Trophy',
    'Syed Mushtaq Ali',
    'Vijay Hazare',
    "Women's",
    'U19',
  ];

  /// AdMob placeholder. Real ad unit ids go here ONLY after creating a
  /// free AdMob account. Until then the app shows a clearly-labelled
  /// placeholder banner so the layout is testable without ads.
  static const String admobBannerAdUnitId = '';
  static bool get hasAds => admobBannerAdUnitId.isNotEmpty;
}
