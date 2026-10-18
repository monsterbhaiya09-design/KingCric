/// KingCric constants. No paid keys. No scraped data.
/// Free API keys are passed at run time via --dart-define=...=...
/// Example: flutter run --dart-define=CRIC_API_KEY=YOUR_FREE_KEY
///   --dart-define=ELITESPORT_API_KEY=... --dart-define=ENTITYSPORT_API_KEY=...
class AppConstants {
  static const String appName = 'KingCric';
  static const String tagline = 'Har Ball, Har Stat, King Jaisa.';

  /// Base URL of the primary free cricket API (CricAPI-compatible shape).
  /// The ApiService never scrapes Cricbuzz / Cricinfo / Crex / Cricmetrics.
  /// Plug any free provider here by implementing the same JSON shape.
  static const String freeApiBaseUrl = 'https://api.cricapi.com/v1';

  /// Passed via --dart-define. Empty means "mock mode" (works offline).
  static const String cricApiKey = String.fromEnvironment(
    'CRIC_API_KEY',
    defaultValue: '',
  );

  static bool get hasApiKey => cricApiKey.isNotEmpty;

  // ---- Multi-source providers (all optional, all free tiers) ----
  // Each provider is skipped when its key is empty / not configured.
  // No key is ever hard-coded. See API-SETUP.md for signup steps.

  /// CricAPI / CricketData.org — primary. Lifetime free, 100 hits/day.
  static const String cricApiBaseUrl = 'https://api.cricapi.com/v1';

  /// SportScore — keyless backstop. Free, no key, ~10,000 req/24h/IP.
  /// Free tier REQUIRES a visible "Powered by SportScore" attribution
  /// wherever its data is rendered (see API-SETUP.md §2).
  static const String sportScoreBaseUrl = 'https://sportscore.com/api/widget';
  static const String sportScoreAttribution = 'Powered by SportScore';

  /// TheSportsDB — free test key "123" is their documented public test
  /// key (see thesportsdb.com/docs). A personal key can be passed via
  /// --dart-define=SPORTSDB_API_KEY=... (free registration, ~500/day
  /// reported). Never commit a personal key.
  static const String sportsDbApiKey = String.fromEnvironment(
    'SPORTSDB_API_KEY',
    defaultValue: '123',
  );
  static const String sportsDbBaseUrl =
      'https://www.thesportsdb.com/api/v1/json';

  /// EliteSport API — free plan, key in `x-api-key` header.
  /// VERIFY the base URL against the EliteSport dashboard/docs before
  /// trusting this provider in production: the endpoint paths
  /// (/matches/live, /matches/{id}/scorecard, ...) are documented on
  /// elitesportapi.com, but the host below is our best-known value.
  /// A wrong host only makes this provider return null (fallback works).
  static const String eliteSportApiKey = String.fromEnvironment(
    'ELITESPORT_API_KEY',
    defaultValue: '',
  );
  static const String eliteSportBaseUrl = 'https://api.elitesportapi.com/v1';

  /// EntitySport — free dev token for testing (sample completed
  /// competitions only; full live coverage is paid). The sample dev
  /// token is published on EntitySport's own docs — it is NOT hard-coded
  /// here. Pass your own token via --dart-define=ENTITYSPORT_API_KEY=...
  static const String entitySportApiKey = String.fromEnvironment(
    'ENTITYSPORT_API_KEY',
    defaultValue: '',
  );
  static const String entitySportBaseUrl = 'https://rest.entitysport.com/v2';

  /// True when at least one provider can run. SportScore +
  /// TheSportsDB (test key) are keyless backstops, so this is always
  /// true — the app never has zero providers.
  static bool get hasAnyProvider => true;

  /// QUOTA-SAFE polling (free tiers: CricAPI 100 hits/day lifetime).
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

  /// Per-provider daily self-imposed caps (below the provider limits,
  /// so one buggy loop can never burn a whole quota).
  static const int cricApiDailyCap = 90; // provider limit 100
  static const int sportScoreDailyCap = 500; // provider ~10,000/IP
  static const int sportsDbDailyCap = 400; // reported ~500/day
  static const int eliteSportDailyCap = 90; // testing tier: stay low
  static const int entitySportDailyCap = 90; // dev token: stay low

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

  /// AdMob banner unit id, via --dart-define=ADMOB_BANNER_UNIT_ID=....
  /// Empty (default) = NO ads configured. The UI must render NOTHING
  /// in that case — never a visible "Ad placeholder" box in release
  /// (V3 bug fix). The old placeholder-banner behaviour is gone.
  static const String admobBannerAdUnitId = String.fromEnvironment(
    'ADMOB_BANNER_UNIT_ID',
    defaultValue: '',
  );
  static bool get hasAds => admobBannerAdUnitId.isNotEmpty;
}
