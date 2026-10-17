# KingCric — Code Review 2 (READ-ONLY, lib/ only)

**Scope:** `lib/` — main.dart providers, auto_update_service, favourites (SharedPreferences), home_screen, prediction_engine, mock_data, plus models, utils, widgets, all other screens.
**Method:** Read every file in `lib/`. No edits made to source or APKs. No run/analyze executed (other workers are building).
**Date:** 2026-10-17

## Verdict

**SAFE TO SHIP for demo/mock sideload, with the 5 fixes below applied before Play Store.**

- No uncaught startup-exception path found in Dart. `main()` is hardened (`ensureInitialized`, `runZonedGuarded`, `FlutterError.onError`), all async loads are try/catch + `mounted` guarded, all models default to 0/'' on bad JSON.
- No install-blocker lives in `lib/`. Install failures seen so far (parsing, `isn't compatible`, missing `uses-sdk`, missing `libdartjni.so`) are packaging / native-lib issues, not Dart code. Nothing in `lib/` can cause `INSTALL_FAILED_*` or a PackageManager parse failure.
- The remaining Dart risks are user-triggered UI assertions / leaks / refetch churn, not startup crash loops. Fix the Top 5 before Play Store; none should block a demo sideload.

## What is already good (do not regress)

- `lib/main.dart` — `WidgetsFlutterBinding.ensureInitialized()` before any plugin call; `runZonedGuarded` + `FlutterError.onError` (no `ErrorWidget.builder` global mutation); `AutoUpdateService.start()` called inside Provider `create`, guarded inside the service.
- `lib/services/auto_update_service.dart` — `tick()` never throws (outer try/catch), timer creation try/catch, unverified data never replaces verified data, match-finish path validates via `CompletenessValidator`.
- `lib/services/api_service.dart` — 15s timeouts, outer try/catch → mock fallback, per-match try/catch so one malformed match cannot kill the list, no hard-coded key (`--dart-define` only), no scraping.
- `lib/screens/favourites_screen.dart` — `_prefsOrNull()` try/catch + in-memory fallback for `MissingPluginException`, persistence best-effort, `mounted` checks.
- `lib/screens/home_screen.dart` — `_load()` try/catch + `mounted` check.
- `lib/services/prediction_engine.dart` — empty-form guard, `baseline <= 0` guard, all sub-scores clamped 0–100, weights sum to 1.0.
- `lib/models/*` — every `fromJson` uses `??` defaults; division-by-zero guarded (`BattingStats.operator +`, `Matchup.ballsPerDismissal`, `BattingEntry.strikeRate`, `H2HCard` total==0 case).
- `lib/widgets/player_card.dart` — `player.name.isNotEmpty ? name[0] : '?'` guarded.
- `lib/utils/strings.dart` — all current keys have both `en` and `hi`; `LanguageProvider` is a plain `ChangeNotifier`.

## Top 5 risks (fix before Play Store)

### 1. MEDIUM — `CompareScreen` Dropdown can throw on stale value
**File:** `lib/screens/compare_screen.dart` — `_picker()`
**Risk:** `DropdownButton<String>(value: _aId / _bId)` with `items: _players`. If `_players` reloads and the stored `_aId`/`_bId` is no longer in the list (e.g. live-mode list changes, or list is empty on first build), Flutter throws `There should be exactly one item with [DropdownButton]'s value` — a hard UI crash, user-triggered.
**Evidence:** `initState` does `ApiService().fetchPlayers().then(...)` with no `catchError` and no validation that the stored IDs still exist. Current mock list is static (6 players), so this does not fire in demo mode — it fires the moment the player list becomes dynamic.
**Fix:** Before building the Dropdown, coerce: `if (_aId != null && !_players.any((p) => p.id == _aId)) _aId = null;` (same for `_bId`). Add `catchError` to the `fetchPlayers().then()` chain. Consider `DropdownButtonFormField` with a `hint` for the null state.

### 2. MEDIUM — `H2HCard` progress bar can assert if wins exceed total
**File:** `lib/widgets/h2h_card.dart`
**Risk:** `frac = total == 0 ? 0.5 : winsA / total` is passed raw to `LinearProgressIndicator(value: frac)`, which asserts `0.0 <= value <= 1.0` in debug and mis-renders in release. Mock data is consistent (12/18 = 0.66), but live data with `winsA + winsB > total` (draws/no-results counted differently, or two sources disagreeing) gives `frac > 1.0` → assertion / crash in debug, broken bar in release.
**Fix:** `final frac = total == 0 ? 0.5 : (winsA / total).clamp(0.0, 1.0);`

### 3. LOW — `PredictionCard` progress ring can assert on NaN / out-of-range score
**File:** `lib/widgets/prediction_card.dart`
**Risk:** `CircularProgressIndicator(value: prediction.score / 100)` requires `0.0..1.0` (or null). `PredictionEngine` clamps every sub-score, so `score` is 0–100 for all current callers (pitch defaults to 55). But `score` is built via `double.parse(total.toStringAsFixed(1))` — if any input is `NaN` (e.g. a future caller passes `pitchBattingFriendliness: double.nan`, or a `NaN` average leaks from JSON), `total` becomes `NaN` and `value` becomes `NaN` → assertion.
**Fix:** Clamp at the widget boundary: `value: (prediction.score / 100).clamp(0.0, 1.0)` and guard `NaN`: `value: prediction.score.isNaN ? 0 : ...`. Also clamp `pitchBattingFriendliness` with `isNaN` check inside `PredictionEngine.predict()`.

### 4. LOW — `FutureBuilder` futures recreated on every build (refetch churn + flicker)
**Files:** `home_screen.dart` (`FutureBuilder(future: _api.fetchPlayers())`), `leagues_screen.dart`, `stats_screen.dart`, `match_detail_screen.dart` (`_squadTab`, `_predictionTab`), `favourites_screen.dart` (`FutureBuilder(future: ApiService().fetchPlayers())`).
**Risk:** Not a crash, but every `setState` (search typing in Home, chip selection in Leagues, favourite toggle in Favourites, tab switch in MatchDetail) creates a **new** Future → refetch + spinner flicker + redundant network calls. In live mode this multiplies free-API quota burn (the 100 hits/day limit) and can feel like the UI never settles. In the worst case, a `FutureBuilder` whose future completes synchronously while the parent is rebuilding can trigger repeated rebuilds.
**Fix:** Hoist each future to a `late final` / state field created once in `initState` (e.g. `late final Future<List<Player>> _playersFuture;`), and only recreate it on explicit refresh (pull-to-refresh / retry button). Cache the player list in a single shared service instead of `ApiService()` per screen.

### 5. LOW — `AutoUpdateService` re-entrancy, listener fan-out, and resource leaks
**File:** `lib/services/auto_update_service.dart`
**Risks:**
- **Overlapping ticks:** `Timer.periodic(45s)` + immediate unawaited `tick()` with no re-entrancy guard. If a fetch takes >45s (slow network), two `_tickInner()` runs mutate `_lastKnown` concurrently. Dart is single-threaded so this is not a data race, but it can double-fire the match-finished path.
- **One bad listener kills the rest:** `for (final fn in _listeners) { fn(detail); }` is not per-listener try/catch. If one listener throws, later listeners never run (the outer `tick()` catch swallows it, so the app does not crash, but updates are silently lost).
- **`http.Client` never closed:** `ApiService` holds a `http.Client` with no `close()` / dispose path. Minor leak; on long sessions it holds a connection pool.
- **`lastPoll` never updated:** Field is initialised to `DateTime.now()` and never reassigned in `tick()`, so any "Last updated …" UI driven by it is stale.
- **`_listeners` never removed:** No `removeFinishedListener`; listeners accumulate if screens re-subscribe.
**Fix:** Add `_ticking` bool guard in `tick()`; wrap each listener call in its own try/catch; call `_api.close()` / add `dispose()` to `ApiService` and wire it in `AutoUpdateService.dispose()`; set `lastPoll = DateTime.now()` at end of successful `_tickInner()`; add `removeFinishedListener`.

## Other findings (not Top 5, fix opportunistically)

- **Leak — `MatchDetailScreen` TabController never disposed.** `lib/screens/match_detail_screen.dart` creates `_tabs = TabController(length: 4, vsync: this)` in `initState` with `SingleTickerProviderStateMixin` but has no `dispose()`. Add `@override void dispose() { _tabs.dispose(); super.dispose(); }`. Not a crash, but a ticker leak on every match-detail open.
- **Leak / staleness — `_Shell` keeps all 5 tab screens alive.** `lib/main.dart` builds `_pages` as `static const` list including `FavouritesScreen()`. All five screens are instantiated at once; `FavouritesScreen.initState` fires `SharedPreferences` on app start even if the user never opens that tab. Harmless with the current fallback, but it means prefs is touched on every launch. Consider lazy tab bodies (`IndexedStack` with lazy builders) if startup time matters.
- **Zone handler is log-only.** `main()`'s `runZonedGuarded` error handler only `debugPrint`s. If an error escapes before `runApp`, the user sees a black screen with no fallback UI. Consider a `FlutterError.onError` → error-screen route or at minimum a `WidgetsBinding` post-frame error banner for release builds. Current behaviour is acceptable for demo (zone + `FlutterError` prevents process death) but not ideal for Play Store.
- **`Team.fromJson` null-cast.** `lib/models/team.dart`: `((j['winsVs'] as Map?) ?? {}).map((k, v) => MapEntry(k.toString(), (v as num).toInt()))` throws if any value is `null`. `Team.fromJson` has no call sites in current UI (dead code path), so no live risk — but guard it (`(v as num?)?.toInt() ?? 0`) before live mode uses it.
- **`Player.fromJson` nested null-cast.** `lib/models/player.dart` `batMap`/`bowlMap`: `(v as Map).cast<...>()` throws if any value in the map is `null`. Same status as `Team`: no call sites in current UI (`ApiService` uses constructors + mock data), so no live risk — guard before live mode uses `fromJson` on real API payloads.
- **`Strings.t` force-unwrap.** `lib/utils/strings.dart`: `map['hi']!` / `map['en']!` throws if a future key adds only one language. All current keys have both. Guard with `map['hi'] ?? map['en'] ?? key`.
- **`ApiService.fetchPlayer` mixes mock stats into live profiles.** In live mode it returns a `Player` whose `battingByFormat` / `battingVsOpponent` / etc. come from mock data, with `dataComplete: false`. The UI shows "Verifying…" for this case, which is correct labelling, but any consumer that ignores `dataComplete` would treat mock stats as real. Keep the flag check at every display site; do not drop the flag when enriching live profiles.
- **`CompletenessValidator.isPlayerComplete` 24h staleness.** `MockDataService._now` is `static final` at class load, so after 24h of continuous uptime all mock players flip to incomplete. App restarts reset it. Not a real-world issue (apps restart), but do not rely on wall-clock staleness for demo data.
- **`CompareScreen` unhandled Future.** `initState` `fetchPlayers().then(...)` has no `catchError`. `ApiService.fetchPlayers()` currently never throws (returns mock), but a future refactor that lets it throw would surface as a zone error. Add `.then(...).catchError((_) {})` or `try/catch` with `await`.
- **No large asset loads.** No `Image.asset`, `rootBundle.load`, or font loading in `lib/` — no asset-load crash path. Logo is emoji (`👑🏏`) in `HomeScreen`/`LanguageToggle`, not an asset file, so a missing image asset cannot crash startup.

## Install-blocker assessment (lib/ only)

None. `lib/` contains no manifest, no native code, no Gradle config, and no plugin registration. The install failures observed (parsing, `isn't compatible`, missing `uses-sdk`, missing `libdartjni.so`) are all in `android/` / packaging / signing, which are outside this review's scope. The Dart code is compatible with any correctly packaged APK: it uses only `provider`, `http`, `shared_preferences`, and Flutter core — all standard, all already in `pubspec`.

## What to fix before Play Store (priority order)

1. CompareScreen Dropdown stale-value guard + `catchError`.
2. H2HCard `frac` clamp.
3. PredictionCard `NaN`/range clamp + `PredictionEngine` `NaN` guard on pitch input.
4. Hoist `FutureBuilder` futures to `initState` (stop per-build refetch / quota burn).
5. AutoUpdateService re-entrancy guard + per-listener try/catch + `http.Client` close + `lastPoll` update + `removeFinishedListener`.
6. Opportunistic: `MatchDetailScreen` TabController `dispose()`, `Team`/`Player.fromJson` null guards, `Strings.t` fallback, zone-handler fallback UI.

## Files reviewed

- `lib/main.dart`, `lib/utils/{app_theme,constants,strings}.dart`
- `lib/services/{api_service,auto_update_service,completeness_validator,mock_data_service,prediction_engine}.dart`
- `lib/screens/{home,compare,favourites,leagues,match_detail,player_profile,stats}_screen.dart`
- `lib/models/{player,match,innings,prediction,team,venue}.dart`
- `lib/widgets/{h2h_card,language_toggle,player_card,prediction_card,stat_card}.dart`
