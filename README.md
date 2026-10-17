# KingCric 👑🏏

**Har Ball, Har Stat, King Jaisa.**

Full-version cricket analytics app — inspired by Virat Kohli (King Kohli).
Live ball-by-ball scores, deep player analytics (overall + vs opponent +
format-wise + venue + leagues), bowler-vs-batter matchups, H2H,
player compare, predictions, favourites + notifications, Hindi + English.

Logo: **Crown + Bat-Ball**.

## 100% FREE model

- No paid keys. No paid SDKs. No scraped data.
- **Never** scrapes Cricbuzz / Cricinfo / Crex / Cricmetrics. The app talks
  only to a free provider's documented JSON API (CricAPI-compatible shape).
- Without a key the app runs in **demo mode** with complete realistic mock
  data (India vs Pakistan T20, IPL, Big Bash, Virat / Rohit / Babar /
  Shaheen / Bumrah / Suryakumar) so every screen works offline.
- Monetization: AdMob placeholder (`AdPlaceholder` widget). Add a real
  AdMob unit id only after creating a free AdMob account — until then the
  app shows a clearly-labelled placeholder, never a fake ad.

## How to run

Prerequisite: Flutter SDK 3.x (free) — https://flutter.dev/docs/get-started/install

```bash
cd kingcric
flutter pub get

# Demo mode (no key, mock data):
flutter run

# Live mode with a FREE CricAPI key (get one free at cricapi.com):
flutter run --dart-define=CRIC_API_KEY=YOUR_FREE_KEY
```

Android first. The same code builds for iOS later (`flutter build ipa`).

## How the data pipeline works

| Concern | Implementation |
|---|---|
| Live scores | `ApiService.fetchMatches()` — free API, falls back to mock |
| Auto-update | `AutoUpdateService` polls live matches every 45s; on match-finish it fetches the final scorecard, validates it, and fires `onMatchFinished` so derived stats recalculate immediately |
| Completeness | `CompletenessValidator` — two sources must agree on core facts; innings totals must reconcile; a profile is "complete" only with overall + format + recent form + fresh timestamp. Wrong data is never shown as fact |
| Prediction | `PredictionEngine` — weighted model: recent form 30% + vs opponent 25% + venue 20% + matchup 15% + pitch 10% → 0–100 score + "Likely / Risky / Unlikely" + bilingual explanation. Phase 2 can swap in an ML model behind the same `predict()` interface |
| Language | `LanguageProvider` — Hindi ⇄ English toggle on every screen |

## Project structure

```
lib/
  main.dart                 # MaterialApp, King theme, bottom nav, providers
  models/                   # player, match, innings, team, venue, prediction
  services/
    api_service.dart        # free-API layer + mock fallback (no scraping)
    mock_data_service.dart  # complete realistic demo dataset
    auto_update_service.dart# polling + match-finish recalculation
    completeness_validator.dart
    prediction_engine.dart  # weighted 30/25/20/15/10 model
  screens/                  # home, match_detail, player_profile, compare,
                            # leagues, stats, favourites
  widgets/                  # stat_card, player_card, prediction_card,
                            # h2h_card, language_toggle (+ ad placeholder)
  utils/                    # app_theme (dark navy + gold), strings (HI/EN),
                            # constants (free API config, polling intervals)
```

## Play Store note

Publishing on Google Play requires a **Google Developer account:
$25 one-time fee (~₹2,100)** — charged by Google, not by this app.
There is no way around that fee for Play Store listing. Until then,
distribute the free APK directly (`flutter build apk --release`).

## What needs a real free API key to go live

1. A free key from a free cricket API provider (e.g. CricAPI free tier).
   Pass it with `--dart-define=CRIC_API_KEY=...`.
2. Verify the provider's JSON shape against `ApiService._matchFromFreeApi`
   — free providers differ slightly; the mapping is isolated in that one
   method on purpose.
3. For background updates when the app is closed: wire
   `AutoUpdateService` logic into WorkManager / a Firebase Function
   (free tier) — the in-app polling already covers the foreground case.
4. For real push notifications: add Firebase Cloud Messaging (free tier).
5. For real ads: create a free AdMob account and set the banner unit id
   in `AppConstants.admobBannerAdUnitId`.

## Status

FULL VERSION scaffold: all screens + models + services + prediction +
validation + auto-update are implemented with real logic. Mock data is
complete and internally consistent. Not yet connected to a live paid
feed — by design (free model).
