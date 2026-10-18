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

  /// QUOTA-SAFE polling (free tier = 100 hits/day, lifetime).
  /// NEVER poll every 45s: that burns ~1,920 calls/day and kills the
  /// key before lunch. Live list refreshes every 10 min, idle every
  /// 15 min, plus one manual Refresh and one extra fetch when a match
  /// flips to completed. See API-SETUP.md "Quota budget".
  static const Duration livePollInterval = Duration(minutes: 10);
  static const Duration finishedPollInterval = Duration(minutes: 5);
  static const Duration idlePollInterval = Duration(minutes: 15);

  /// Cache TTLs (ApiService). Completed data never changes, so it is
  /// cached far longer than live data — re-fetching a finished
  /// scorecard is pure quota waste.
  static const Duration liveCacheTtl = Duration(minutes: 10);
  static const Duration completedCacheTtl = Duration(hours: 1);

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
