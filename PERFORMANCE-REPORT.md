# KingCric — Performance + 60fps Audit (READ-ONLY)

**Role:** Performance Engineer (Google-style team). **No code was edited** — this file is findings + fix snippets only. Other teams own the edits.
**Date:** 2026-10-18. **Scope:** `lib/` (9,484 lines, 41 Dart files) + `pubspec.yaml` + `assets/`.
**Verification run (this audit):** `flutter analyze` → **1 warning + 4 infos, 0 errors** (warning: duplicate `dart:async` import in `lib/services/api_service.dart:3`; infos: `prefer_const_*` in `test/team5_data_detail_test.dart` only). `flutter test` → **53 passed, 4 failed** (failures are pre-existing widget tests in `match_detail_test.dart` ×2 + `widget_test.dart` ×2 — FOW-number-once, Squad split, OverGraph, Cricsheet source line — NOT caused by this audit; see §8).

**Headline verdict:** No P0 that blocks 60fps at *current* data scale (tens of matches, ~36 players, 147 KB Cricsheet sample). The app is fast today because the dataset is small. **Five P0s are scale cliffs**: they are cheap now and will jank / OOM / burn battery the moment the dataset grows (full `all_json.zip`, hundreds of matches, real API lists). Fix the P0s before shipping the full-dataset build.

---

## 1. Top 10 P0 Performance Fixes (do these first)

| # | Fix | File(s) | Why it matters |
|---|-----|---------|----------------|
| P0-1 | Move Cricsheet JSON parse + all aggregations off the UI isolate with `compute()`; cache aggregation results per player/scope | `lib/services/cricsheet_service.dart` | `parse()` + `_batAcc`/`_bowlAcc`/`profile()` are synchronous loops over **every delivery of every match, per query**. Sample (4 matches) is trivial; full `all_json.zip` (thousands of matches, ~1M deliveries) will block the UI thread for seconds → dropped frames / ANR. |
| P0-2 | Memoise per-build derived lists: compute `_visible`, `_nextUpcoming`, Stats leaderboards, Leagues points table, Compare rows **once per state change**, not once per `build()` | `home_screen.dart`, `stats_screen.dart`, `leagues_screen.dart`, `compare_screen.dart`, `match_detail_screen.dart` | Every `build()` currently re-runs `where` + `sort` (+ `RegExp` + `toLowerCase`) over the full list. `Home._visible` is evaluated **twice per build** (`isEmpty` + `for`). Stats does **10 sorts** per build. Any parent rebuild (language toggle, timer tick, keyboard) re-pays the full cost. |
| P0-3 | Replace eager `ListView(children: [...for...])` with `ListView.builder` / `SliverList` for all unbounded lists (Home matches, Trending, Stats sections, Favourites players/teams, MatchDetail scorecard/commentary, PlayerProfile tables, Leagues) | All screens (see §3) | `ListView(children:)` builds **every** row up front — including off-screen scorecard rows, 10 Stats leaderboards, full commentary. `ListView.builder` builds only visible rows. This is the single biggest 60fps lever for long lists. |
| P0-4 | Kill per-keystroke full rebuilds: debounce search `onChanged` (≈300 ms) and move filtering off `build()` into a debounced setter | `home_screen.dart:208` | Every keystroke calls `setState` → full `build()` → `_visible` re-filter + re-sort + rebuild of every card + `context.watch<LanguageProvider>` re-evaluation. Typing "Virat" = 5 full rebuilds. |
| P0-5 | Stop `context.watch<LanguageProvider>()` at the top of every `build()` from rebuilding entire screens; scope `watch` to the small widgets that actually render text, or use `select()` | `home_screen.dart:140,435`, `match_detail_screen.dart:142`, `player_profile_screen.dart:28`, `main.dart:96` | `watch` marks the **whole** `State.build` dirty on every language change — correct for language, but it also means any `LanguageProvider.notifyListeners()` rebuilds the entire Home/MatchDetail/Player tree, including all the per-build sorts in P0-2. Keep `watch` leaf-level. |
| P0-6 | Close `http.Client` instances (or share one singleton client) — 5 providers each create their own `http.Client()` and never close it | `providers/*.dart` (5 files) | Each `Client()` holds a connection pool. Five unclosed clients × app lifetime = leaked sockets, higher memory, and (on Android) kept-alive radios → battery drain. Share one client or `close()` on dispose. |
| P0-7 | Hoist `RegExp` construction out of `build()` / hot loops — compile once as `static final` | `compare_screen.dart:255`, `match_detail_screen.dart:65`, `over_graph.dart:144` (local `RegExp(...)` per call) | `RegExp(...)` compiles the pattern **every time it runs**. `match_detail` strips the FOW prefix per row; `compare` parses "best" per build. `over_graph.dart:21-22` already shows the correct pattern (`static final`). Copy it everywhere. |
| P0-8 | Remove the duplicate `import 'dart:async'` (analyze warning) and the duplicate `ApiService()` constructions per screen — inject one shared `ApiService` via `Provider` | `api_service.dart:3`, all screens (`ApiService()` in `initState`, `_tappableRow`, `fetchPlayers` on tap) | Duplicate import is trivial but signals the real issue: every screen constructs its **own** `ApiService`, each with its **own** caches, in-flight maps, and `CricsheetService` load. Cache hit-rate collapses (each service loads the 147 KB sample separately) and memory multiplies. One shared instance = one cache, one Cricsheet parse. |
| P0-9 | Fix `AutoUpdateService` timer + `UpdateFeed` listener leaks: `Timer.periodic` is created in `Provider(create:)` and disposed via `Provider(dispose:)` — verify dispose actually runs on app exit / hot-restart, and never start a second timer on rebuild | `main.dart:47`, `auto_update_service.dart:84`, `smooth_update.dart:209` | A leaked 10-min `Timer` is cheap; a **duplicated** timer (double `start()` after a provider rebuild) doubles polling → doubles quota burn + battery. `start()` calls `stop()` first (good) but there is no guard against two `AutoUpdateService` instances (see P0-8). |
| P0-10 | Pre-compute `CricsheetService` identity / team lookups into `Map`s once at parse time instead of linear scans per query | `cricsheet_service.dart:380-400, 420-465, 560-615, 770-785` | `_identityFor` / `_teamOf` / `_batAcc` / `_bowlAcc` / `profile()` scan **all matches × all deliveries** per player, per scope (format × opponent × venue × league). Cost is `O(players × scopes × deliveries)`. With the full dataset this is the profile-screen jank source. Build `Map<shortName, _Identity>` + per-player delivery indexes once. |

---

## 2. Findings per file

### 2.1 `lib/main.dart` — GOOD, one nit
- ✅ `runZonedGuarded` + `FlutterError.onError` — startup hardening is correct.
- ✅ `_pages` is `static const` — tab widgets are not re-allocated per build. Only `_pages[_index]` is in the tree, so the other 4 tabs cost no build time. Good.
- ✅ `Provider<AutoUpdateService>(dispose:)` — dispose wired.
- ⚠️ P2: `_ShellState.build` uses `context.watch<LanguageProvider>()` → every language change rebuilds the `Scaffold` + `BottomNavigationBar` + current page. Acceptable (language is rare), but see P0-5 for the screen-level pattern.

### 2.2 `lib/screens/home_screen.dart` (495 lines) — highest rebuild cost
- **P0-2 (P0):** `_visible` getter does `where` + `where` (search, 5× `toLowerCase` per match) + `where` (format) + `sort` on **every access**, and `build()` accesses it **twice** (`_visible.isEmpty` + `for (final m in _visible)`). `_nextUpcoming` does another `where` + `sort`. Fix: compute once in `_load()` / filter setters into `_visibleCache`, rebuild only when `_matches` / `_filter` / `_query` / `_formatFilter` changes.
- **P0-4 (P0):** Search `TextField.onChanged: (v) => setState(() => _query = v)` — no debounce. Fix: `Timer(Duration(milliseconds: 300), ...)` debounce + `TextEditingController` listener disposed already (good).
- ✅ GOOD: `_playersFuture` cached once in `initState` (comment G5 is accurate — the old FutureBuilder-per-build bug is fixed). `_load()` guards `_loadingMatches` and only shows the full spinner on first load (stale-while-revalidate done right).
- ⚠️ P1: `ListView(children: [...])` with `for (final m in _visible) KingMatchCard` + `Column` of trending `PlayerCard`s — all rows built eagerly. For 100+ live matches this is the first visible jank. Fix: `ListView.builder` with `itemCount = _visible.length + headerCount`, or `CustomScrollView` + `SliverList` + `SliverToBoxAdapter` for headers.
- ⚠️ P1: `context.watch<LanguageProvider>()` in both `build()` (line 140) and `_FilterTabs.build` (435) — the whole Home rebuilds on language change (correct) but also re-runs P0-2 sorts. Acceptable once P0-2 is memoised.
- ⚠️ P2: `DateTime.now()` in `build()` for `_startsLine` / "Last updated" — rebuild-dependent clock. Harmless at this scale; prefer passing a snapshot `DateTime` from state.

### 2.3 `lib/screens/match_detail_screen.dart` (1,070 lines — largest file)
- ✅ GOOD: `TabController` created once in `initState`, disposed in `dispose()`. `_playersFuture` cached once (comment is accurate). `FutureBuilder(future: _playersFuture)` in `_squadTab` + `_predictionTab` reuses the same future — no re-fire.
- **P0-2 (P0):** `_predictionTab` runs `PredictionEngine.predict(...)` for **every squad player** on **every build** of that tab (plus `sort`). Prediction is pure math over small inputs, but it re-runs on any parent rebuild (language, timer). Fix: memoise `List<Prediction>` per `(match.id, squadIds, venueId, format)`; recompute only when inputs change.
- **P0-7 (P0):** `RegExp(r'^\s*\d+\s*-\s*')` constructed per FOW row in `stripFowPrefix` (line 65). Fix: `static final _fowPrefix = RegExp(...)`.
- **P1:** Scorecard is `ListView(children: [... for inn ... _battingTable, _bowlingTable, _fallOfWickets, ...])` — every batting row, bowling row, FOW row, partnership row, yet-to-bat chip is built eagerly, even for a 2-innings Test with 40+ rows per innings. Fix: `ListView.builder` / `SliverList` per table, or at minimum `RepaintBoundary` per innings section so a score update repaints only one innings.
- **P1:** `_tappableRow` / squad rows call `ApiService().fetchPlayers()` **on tap** (see also `player_profile_screen.dart:376`). Tap → network/parse → navigation. Feels slow on first tap. Fix: share the already-loaded player list (P0-8) or prefetch on screen entry.
- **P2:** `players.where(...).firstWhere(...)` linear scans per tap (small N, fine) — fix by indexing players by `id`/`name` once (see P0-10).

### 2.4 `lib/screens/player_profile_screen.dart` (726 lines)
- **P1:** `_grid` uses `GridView.count(shrinkWrap: true, physics: NeverScrollableScrollPhysics())` inside a `ListView` — shrink-wrapped grids measure **all** children up front (defeats laziness). At 2 columns × few cards this is fine; do not grow it.
- **P1:** `onTap` in `_tappableRow` does `await ApiService().fetchPlayers()` + 3 linear `where`/`firstWhere` scans with `toLowerCase()` per player (lines 376-392). Same tap-latency issue as MatchDetail. Fix: shared service + `Map<String, Player>` index.
- **P2:** `_FormatTables` does `.where((e) => e.key == _format)` twice per build (lines 511, 516) + `_formats` getter rebuilds a `Set` per build (501-502). Trivial at this size; memoise when formats grow.
- ✅ GOOD: `maxLines` + `ellipsis` everywhere — no unbounded text layout cost.

### 2.5 `lib/screens/stats_screen.dart` (327 lines) — most sorts per build
- **P0-2 (P0):** `build()` does **10 full sorts** (`byRuns`, `byAvg`, `bySr`, `byWkts`, `byEcon`, `byHundreds`, `byFifties`, `bySixes`, `byFours`, `byBowlAvg`) + 2 `where` filters + `_stats(p)` recomputed **per comparison** (each comparator calls `_stats(b)` / `_stats(a)`, which itself folds `battingByFormat`/`bowlingByFormat`). Comparator cost is `O(n log n × statsCost)`. Fix: compute `_stats` **once per player** into a `List<(_PlayerStats)>`, then sort the precomputed list; memoise per `(_format, _discipline, players)`; invalidate only when inputs change.
- **P1:** `_section` builds 10 `ListView` children eagerly (each section's top-N rows). With `ListView.builder` per section or a single `SliverList`, off-screen sections cost nothing.
- ⚠️ P2: `_stats()` returns `double.infinity` for missing bowling — `sort` with `infinity` is correct but `toStringAsFixed` on `infinity` renders "Infinity" if a board ever shows it. Guard the display (not a perf issue, a correctness nit).

### 2.6 `lib/screens/leagues_screen.dart` (422 lines)
- **P0-2 (P0):** `build()` → `FutureBuilder` → `where(_inLeague)` + `sort(_matchOrder)` + **3 separate** `where(...).length` passes (`liveCount`, `upcomingCount`, `finishedCount`) + nested `FutureBuilder` → `_pointsTable(list)` → `computePointsTable` (full scan + `toLowerCase()` per match + 2 innings loops) + top-players `sort` ×2 + `where(...).take(3)` ×2. All re-run on every `setState` (league chip tap). Fix: compute points table + counts + top players once per `(league, matches)` in a memoised getter; single-pass counts.
- ✅ GOOD: `_matchesFuture` / `_playersFuture` cached in `initState`; `_reload()` reassigns both (correct).
- ⚠️ P1: Nested `FutureBuilder` (matches outer, players inner) — the inner builder re-runs whenever the outer rebuilds. Fine at this scale; prefer `Future.wait` in `initState` into one future.
- ⚠️ P2: `computePointsTable` is pure and testable (good). It is called in `build` — move the call to the memoised layer (P0-2), not into the widget.

### 2.7 `lib/screens/compare_screen.dart` (425 lines)
- ⚠️ P1: `initState` uses `ApiService().fetchPlayers().then(...)` with **no error handler** — if the fetch throws, `_loading` stays `true` forever (infinite spinner). `ApiService` is defensive (rarely throws), but a `.catchError` / `try/catch` that sets `_loading=false` + error state is still required.
- **P0-7 (P0):** `RegExp(r'^(\d+)').firstMatch(best.trim())` per build (line 255). Hoist to `static final`.
- ⚠️ P2: `_byId` linear scan per build (2 calls) — trivial; index if player count grows.
- ✅ GOOD: stale-picker re-validation, same-player guard.

### 2.8 `lib/screens/favourites_screen.dart` (332 lines)
- ✅ GOOD: `_playersFuture` / `_matchesFuture` cached as `late final` in `initState`. Nested `FutureBuilder` for matches is scoped to the favourites-matches section only.
- ⚠️ P1: `build()` does `players.map((p) => p.team).toSet().toList()..sort()` + full player `Card` list + full team `Card` list eagerly in a `ListView(children:)`. For hundreds of favourited players this is the jank source. Fix: `ListView.builder`.
- ⚠️ P2: `SharedPreferences.getInstance()` per toggle (`_prefsOrNull` per `_toggle*`) — each call is async + channel round-trip. Cache the `SharedPreferences` instance once in `initState` (it is already effectively a singleton, but the `await` per toggle still posts a microtask per tap).

### 2.9 `lib/services/cricsheet_service.dart` (922 lines) — the scale cliff
- **P0-1 (P0):** `parse()` does `jsonDecode` (sync, UI isolate) + `_parseMatch` per match + per-over + per-delivery nested loops with `Map.cast` per node. Then **every** aggregation (`_batAcc`, `_bowlAcc`, `profile`, `vsOpponent`, `byVenue`, `matchup`, `dismissalHistory`, `recentForm`, `teamH2H`) re-scans **all matches × all deliveries** with fresh `Map`/`Set` allocations (`inningsRuns`, `inningsDismissed`, `matchesSeen`, …). Sample: 4 matches ≈ hundreds of deliveries — invisible. Full `all_json.zip`: thousands of matches, ~1M deliveries — `profile()` alone becomes seconds on the UI thread.
  - Fix: (a) `compute(CricsheetService.parse, jsonText)` for the parse; (b) build per-player indexes once (`Map<shortName, List<Delivery>>` + `Map<shortName, _Identity>`); (c) memoise `profile(shortName)` per dataset version; (d) document that `loadBundled()` must be called once and shared (P0-8).
- **P0-10 (P0):** `_identityFor` (380-392) does a linear `_identities.entries` scan + `toLowerCase()` per entry, **twice** (exact + last-name fallback). `_teamOf` (396-401) scans all matches × all teams per call. `_batAcc`/`_bowlAcc` call `_teamOf`-style scans inside their loops. Fix: `Map<String,_Identity> _byLowerName`, `Map<String,String> _teamByShortName` built once in the constructor.
- ⚠️ P1: `String` key `'${m.index}:${d.inningsIndex}'` allocated per delivery per query — with an index this disappears.
- ✅ GOOD: `parse()` never throws; `loadBundled` returns empty service on failure; `bowlerCreditedKinds` correctly excludes run-outs; `dismissed-without-facing` handled.

### 2.10 `lib/services/api_service.dart` (481 lines) + `smooth_update.dart` (214 lines)
- ✅ GOOD (already fixed): in-flight dedup (`_matchesInFlight`, `_scorecardInFlight`, `InFlightDeduper`), TTL caches (live 10 min / completed 60 min), `crossCheckMatches` never throws, `_notifyMatchesListeners` try/catch per listener, `UpdateFeed` SWR with background refresh + small indicator (not full spinner).
- **P0-8 (P0):** `ApiService` is constructed **per screen** (`ApiService()` in 6+ places). Each instance has its own `_matchesCache`, `_detailCache`, `_playerCache`, `_matchesInFlight`, and its own lazy `_cricsheetFuture`. The dedup + cache only work **within** one instance. Fix: provide one `ApiService` via `Provider` in `main.dart` (or a static singleton) and `context.read<ApiService>()` in screens.
- ⚠️ P1: Duplicate `import 'dart:async';` (lines 2-3) — the one analyze warning. Delete one line.
- ⚠️ P2: `debugPrint` on cross-check mismatch (line 209) + `smooth_update.dart:131` — fine (debug only, not in release hot path), but guard with `kDebugMode` if it ever moves into a per-delivery loop.

### 2.11 `lib/services/auto_update_service.dart` (153 lines)
- ✅ GOOD: `tick()` never throws (try/catch), `start()` calls `stop()` first, `lastPoll` exposed for UI.
- **P0-9 (P0):** `Timer.periodic(livePollInterval)` — 10 min is quota-safe, but the timer lives as long as the `Provider` does. If a second `AutoUpdateService` is ever created (P0-8), two timers poll. Fix: assert single instance (P0-8) + `assert(_timer == null)` in `start()` after `stop()`.
- ⚠️ P2: `tick()` awaits `fetchMatches()` then `fetchMatchDetail` per finished match serially — fine (finished matches are rare). No change needed.

### 2.12 `lib/services/providers/*.dart` (5 providers) + `completeness_validator.dart` + `prediction_engine.dart` + `mock_data_service.dart`
- **P0-6 (P0):** Every provider does `_client = client ?? http.Client()` and never calls `_client.close()`. See fix in §4.
- ⚠️ P1: `jsonDecode(res.body)` on the UI isolate per provider response (5 call sites in `cricapi_provider.dart` alone). Responses are small (tens of KB) — fine now. For large scorecard payloads, `compute(jsonDecode, body)` is the standard fix; do it when payloads grow, not before.
- ✅ GOOD: providers never throw (defensive parsing, `try/catch`); `completeness_validator` is pure math (cheap); `prediction_engine` is O(1) per player; `mock_data_service` is static data (no parse cost).

### 2.13 `lib/widgets/*` — gradients, shadows, animations
- ✅ GOOD: `LivePulseDot` is a **one-shot** `TweenAnimationBuilder` (700 ms), not `AnimationController.repeat` — the comment is accurate and the test-timeout bug is fixed. `StatBar` / `AnimatedScore` are also one-shot `TweenAnimationBuilder`s. No infinite tickers.
- ⚠️ P1: `TweenAnimationBuilder` count: 4 sites (`premium_widgets.dart` ×3 + `h2h_card.dart` ×1). Each `TweenAnimationBuilder` rebuilds its subtree every frame for 700-900 ms. With 10 `StatBar`s on screen (player profile), that is 10 concurrent 700 ms animations — fine on modern phones, but **do not** put a `TweenAnimationBuilder` inside a `ListView.builder` item that rebuilds on scroll. Current usage is in static headers/cards — acceptable.
- ⚠️ P1: `AppTheme.premiumCard()` / `heroCard()` create **2 `BoxShadow`s each** (blur 18-32) + a `LinearGradient` per card. Blur shadows are the most expensive paint operation on low-end Android. Every `KingGradientCard` / `KingMatchCard` / `PlayerCard` pays it. At 10-20 visible cards this is fine; at 100+ scrolled cards it shows up in the raster thread. Fix: (a) keep shadows but reduce `blurRadius` on low-end devices (`MediaQuery` / `Platform` check), (b) add `RepaintBoundary` around each card so a score update repaints only that card, (c) never put a `BoxShadow` inside a scrolling item that also animates.
- ⚠️ P2: `GoldDonut` uses `CustomPaint` + `_DonutPainter.shouldRepaint` correctly compares `fraction`/`color`. Good. `OverGraph` does `RegExp` + string parsing per row — hoist regexes (P0-7) and parse once per innings, not per row.
- ✅ GOOD: No `Image` / `NetworkImage` / `CachedNetworkImage` anywhere — zero image-decode / cache cost today. When player photos are added, use `cached_network_image` + `RepaintBoundary` + fixed-size placeholders (see §4, P2-4). The `cached_network_image` removal note in `pubspec.yaml` is accurate — do not re-add it without the `libdartjni.so` bundling fix.

### 2.14 `lib/models/*` + `lib/utils/*`
- ✅ GOOD: Models are immutable `const` classes with `fromJson`/`toJson` — cheap to construct, no hidden work.
- ⚠️ P2: `BattingStats.operator +` allocates a new object per fold — used in `battingOverall()` per `_stats()` call per comparison (Stats P0-2). Memoise the overall once per player.
- ⚠️ P2: `strings.dart:140` uses `Provider.of<LanguageProvider>(this)` inside a `BuildContext` extension — `Provider.of` without `listen: false` **subscribes** the calling widget. If called in `build()`, it is equivalent to `watch` (see P0-5). Verify call sites use it only where a rebuild on language change is wanted.

### 2.15 `pubspec.yaml` + `assets/`
- ✅ GOOD: Only 4 runtime deps (`provider`, `http`, `shared_preferences`, `intl`). No `cached_network_image`, no `google_mobile_ads` in the dependency list — minimal plugin surface = minimal startup cost and minimal native-library load.
- ✅ GOOD: Bundled asset is only **147 KB** (`cricsheet_sample.json`). Startup asset load is negligible.
- ⚠️ P1 (future): Full `all_json.zip` will be **tens of MB**. Do **not** bundle it as a single `rootBundle.loadString` asset — that loads the entire string into memory at once. Ship it as a compressed asset + `compute()` parse, or download it on first run into app documents and parse incrementally (see §4, P0-1).

---

## 3. ListView.builder vs Column — full inventory

| Location | Current | Verdict |
|----------|---------|---------|
| `home_screen.dart:145` `ListView(children:)` | Eager: header + search + tabs + **all** match cards + trending `Column` | **P0-3:** Convert to `ListView.builder` / `CustomScrollView` + `SliverList` |
| `home_screen.dart:404` Trending `Column` | Eager, 4 items | OK at 4, but use `ListView.builder` when the cap grows |
| `match_detail_screen.dart:179,456,1009,1048` `ListView(children:)` | Eager: full scorecard, commentary, squad, prediction | **P0-3:** `ListView.builder` per tab |
| `player_profile_screen.dart:38` `ListView(children:)` | Eager: all tables + form + matchup + dismissal | **P0-3:** `SliverList` / builder; keep `GridView.count(shrinkWrap)` small or convert to `SliverGrid` |
| `player_profile_screen.dart:470` `GridView.count(shrinkWrap, NeverScrollable)` | Measures all children | P1: OK at 2×N small; convert to `SliverGrid` if N grows |
| `compare_screen.dart:98` `ListView(children:)` | Eager: picker + chips + full compare table | P1: table is bounded (~20 rows) — acceptable; builder if rows grow |
| `stats_screen.dart:193` `ListView(children:)` | Eager: 10 leaderboard sections | **P0-3:** `ListView.builder` / `SliverList` |
| `leagues_screen.dart:209` `ListView(children:)` | Eager: points table + top players + all matches | **P0-3:** `ListView.builder` |
| `favourites_screen.dart:181` `ListView(children:)` | Eager: all team + player cards + fav matches | **P0-3:** `ListView.builder` |
| `match_detail` + `over_graph` scorecard tables | `Column` + `for` rows inside `SingleChildScrollView` (horizontal) | Correct for wide tables (horizontal scroll needs a bounded `Row`); keep, but wrap each innings in `RepaintBoundary` |
| **Total `ListView.builder` / `ListView.separated` / `GridView.builder` in `lib/`** | **0** | **P0-3: this is the headline gap.** |

---

## 4. Fix snippets (not applied — other teams own the edits)

### P0-1 — Cricsheet off the UI thread
```dart
// Before (UI isolate, blocks frames on large datasets):
final svc = CricsheetService.parse(jsonText);
// After:
import 'package:flutter/foundation.dart';
final svc = await compute(CricsheetService.parse, jsonText);
// + memoise per player:
final _profileCache = <String, Player>{};
Player profile(String short) => _profileCache.putIfAbsent(short, () => _buildProfile(short));
// + index once in constructor:
final Map<String, _Identity> _byLowerName = {for (final e in identities.entries) e.key.toLowerCase(): e.value};
```

### P0-2 — Memoise derived lists
```dart
// Before: getter recomputed per build (and twice per build in Home).
List<CricketMatch> get _visible { /* where + sort */ }
// After: cache + invalidate on input change.
List<CricketMatch>? _visibleCache;
String _visibleKey = '';
List<CricketMatch> get _visible {
  final key = '$_filter|$_query|$_formatFilter|${_matches.length}';
  if (_visibleCache != null && key == _visibleKey) return _visibleCache!;
  _visibleKey = key;
  _visibleCache = _computeVisible();
  return _visibleCache!;
}
void _invalidateVisible() => _visibleCache = null; // call from _load() + filter setters
// Stats: compute _stats once per player:
final statsById = {for (final p in players) p.id: _stats(p)};
// then sort the precomputed list — never call _stats() inside a comparator.
```

### P0-3 — Builder lists
```dart
// Before:
ListView(children: [header, for (final m in list) KingMatchCard(match: m)]);
// After:
ListView.builder(
  itemCount: list.length + 1, // +1 header
  itemBuilder: (ctx, i) => i == 0 ? const _Header() : KingMatchCard(match: list[i - 1]),
);
// Or with headers + sections:
CustomScrollView(slivers: [
  const SliverToBoxAdapter(child: _Header()),
  SliverList(delegate: SliverChildBuilderDelegate((ctx, i) => KingMatchCard(match: list[i]), childCount: list.length)),
]);
```

### P0-4 — Debounced search
```dart
Timer? _searchDebounce;
void _onQueryChanged(String v) {
  _searchDebounce?.cancel();
  _searchDebounce = Timer(const Duration(milliseconds: 300), () {
    if (!mounted) return;
    setState(() => _query = v);
  });
}
@override void dispose() { _searchDebounce?.cancel(); _searchController.dispose(); super.dispose(); }
```

### P0-5 — Scope `watch` to leaves
```dart
// Before (whole screen rebuilds on language change):
Widget build(BuildContext context) {
  final lang = context.watch<LanguageProvider>();
  return Scaffold(...huge tree...);
}
// After: read once where text is rendered, or:
final lang = context.select<LanguageProvider, bool>((p) => p.isHindi);
// ... and pass plain strings down. Keep watch only in leaf widgets (LanguageToggle already does this correctly).
```

### P0-6 — One shared http.Client
```dart
// In main.dart:
Provider<http.Client>(create: (_) => http.Client(), dispose: (_, c) => c.close()),
// In providers: accept the shared client, never create + never close per-provider.
// If a singleton is preferred:
class ApiHttp { static final http.Client shared = http.Client(); }
```

### P0-7 — Hoisted RegExp
```dart
// Before: RegExp(r'^\s*\d+\s*-\s*').firstMatch(fow)  // per row
// After (file top):
static final _fowPrefix = RegExp(r'^\s*\d+\s*-\s*');
// ... _fowPrefix.firstMatch(fow)
```

### P0-8 — One shared ApiService
```dart
// In main.dart:
Provider<ApiService>(create: (_) => ApiService(), dispose: (_, s) => s.dispose?.call()),
// In screens: final api = context.read<ApiService>();  // never ApiService() per screen
// + delete the duplicate `import 'dart:async';` in api_service.dart (line 3).
```

### P0-9 — Timer guard
```dart
void start() {
  stop();
  assert(_timer == null);
  _timer = Timer.periodic(AppConstants.livePollInterval, (_) => tick());
}
```

### P0-10 — Indexed lookups
```dart
// Build once in CricsheetService constructor:
final Map<String, String> teamByShortName = {};
final Map<String, List<CricsheetDelivery>> deliveriesByBatter = {};
final Map<String, List<CricsheetDelivery>> deliveriesByBowler = {};
// Then _batAcc/_bowlAcc iterate only that player's deliveries, not all matches × all deliveries.
```

---

## 5. 60fps Checklist (before shipping the final APK)

- [ ] **P0-1:** Cricsheet parse + aggregations on `compute()` / cached; profile screen opens in < 100 ms on the full dataset.
- [ ] **P0-2:** No `where`/`sort`/`RegExp`/`toLowerCase` in any `build()` — all derived lists memoised; `Home._visible` computed once per state change, not twice per build.
- [ ] **P0-3:** Every unbounded list uses `ListView.builder` / `SliverList`; `grep -r "ListView(children" lib/` returns only bounded, small lists (< 10 items).
- [ ] **P0-4:** Search debounced (300 ms); typing never triggers more than ~3 rebuilds/sec.
- [ ] **P0-5:** `context.watch` only in leaf widgets; no screen-level `watch` that rebuilds a whole tab.
- [ ] **P0-6:** One shared `http.Client`, closed on dispose; `grep -rn "http.Client()" lib/` returns exactly one site.
- [ ] **P0-7:** No `RegExp(` inside `build()` or per-row loops; `grep -rn "RegExp(" lib/` returns only `static final` declarations.
- [ ] **P0-8:** One shared `ApiService` via `Provider`; `grep -rn "ApiService()" lib/screens` returns zero (except `main.dart`).
- [ ] **P0-9:** `AutoUpdateService` timer asserted single; no duplicate polling after hot-restart / provider rebuild.
- [ ] **P0-10:** Cricsheet lookups are `Map` hits, not full scans; `profile()` does not loop over all matches.
- [ ] **Shadows:** `BoxShadow` blur ≤ 18 on scrolling cards, or `RepaintBoundary` per card; no shadow + animation on the same scrolling item.
- [ ] **Animations:** All animations one-shot ≤ 900 ms; zero `AnimationController.repeat`; `grep -rn "\.repeat(" lib/` returns zero.
- [ ] **Images (when added):** `cached_network_image` + fixed-size placeholder + `RepaintBoundary`; never `NetworkImage` without a cache.
- [ ] **No jank on low-end:** Test on a 2 GB / 720p device (or `--profile` + DevTools timeline): Home scroll, MatchDetail scorecard scroll, Stats scroll all hold 60fps with no raster-thread spikes.
- [ ] **Analyze + tests green:** `flutter analyze` 0 errors, `flutter test` all pass (the 4 pre-existing failures in §8 must be fixed by their owning teams, not by this audit).

---

## 6. Memory / Battery notes

| Area | Current | Risk | Fix |
|------|---------|------|-----|
| Cricsheet sample | 147 KB asset, parsed once per `ApiService` instance | Low now; **high** with full `all_json.zip` (tens of MB as one `String`) | P0-1 + P0-8: parse once, shared; stream / chunk the full dataset, never `loadString` the whole file |
| HTTP clients | 5 unclosed `Client()` | Medium: leaked sockets + radio wake | P0-6 |
| Timers | 1× 10-min `Timer.periodic` | Low (10 min is battery-friendly) | P0-9: assert single |
| Caches | `_matchesCache` + `_detailCache` + `_playerCache` per `ApiService` instance | Medium: N instances × N caches = N× memory | P0-8: one instance |
| Animations | 4 one-shot `TweenAnimationBuilder`s, 700-900 ms | Low: no infinite tickers | Keep; do not add `repeat()` |
| Shadows / gradients | 2 `BoxShadow`s + `LinearGradient` per card | Medium on low-end: raster cost scales with visible cards | `RepaintBoundary` per card; reduce blur on low-end |
| `SharedPreferences` | `getInstance()` per toggle | Low: singleton under the hood, but an extra async hop per tap | Cache once in `initState` |
| `debugPrint` | 2 sites in fetch path | Negligible in release (stripped / throttled) | Guard with `kDebugMode` if moved into loops |

**Battery:** The dominant cost is network radio wake, not CPU. The 10-min poll interval (not 45 s) is the right call — it keeps the radio in low-power state between polls. Do not shorten it without a quota + battery justification. `UpdateFeed` background refresh is fire-and-forget (good) but must not be called from `build()` (it is not — verified).

---

## 7. What is already good (do not regress)

- `FutureBuilder` futures are cached in `initState` in Home, Leagues, Stats, Favourites, MatchDetail — the classic "Future recreated every build" bug is **fixed** everywhere except the tap-time `fetchPlayers()` calls (P1, §2.3/§2.4).
- `TabController` lifecycle correct (create in `initState`, dispose in `dispose`).
- `LivePulseDot` one-shot, not `repeat` — the test-timeout bug is fixed.
- `UpdateFeed` / `InFlightDeduper` / `MatchDiff` — dedup + SWR + diff are already implemented; screens just need to use the shared instance (P0-8) to get the benefit.
- Models immutable + `const`; `const` usage is high (681 `const` sites, 2 `new` sites).
- No images today → zero image-decode cost. Keep that discipline when photos land.
- `flutter analyze`: 0 errors. `CricsheetService.parse` never throws. `AutoUpdateService.tick()` never throws.

---

## 8. Verification + pre-existing failures (not caused by this audit)

- `flutter analyze` (this audit): **1 warning** (`duplicate_import`, `api_service.dart:3`) + **4 infos** (`prefer_const_*`, test file only). No errors.
- `flutter test` (this audit): **53 passed, 4 failed.** Failures (pre-existing, owned by other teams):
  1. `match_detail_test.dart` — FOW row shows the number ONCE (circle only)
  2. `match_detail_test.dart` — Squad tab splits Team A / Team B sections
  3. `widget_test.dart` — OverGraph renders real FOW + partnership bars
  4. `widget_test.dart` — Team3: Profile shows ONE Cricsheet source line, never Complete
- This audit edited **no** source files. The only file written is this report.

---

## 9. Suggested fix order (for the owning teams)

1. **P0-8 + P0-6** (shared `ApiService` + shared `http.Client`) — unlocks every other cache/dedup benefit. Smallest diff, biggest leverage.
2. **P0-2** (memoise derived lists) — kills per-build re-sort cost in Home/Stats/Leagues.
3. **P0-3** (builder lists) — kills eager row construction.
4. **P0-1 + P0-10** (Cricsheet off-thread + indexed) — required before the full-dataset build.
5. **P0-4 + P0-5 + P0-7 + P0-9** (debounce, scoped `watch`, hoisted regex, timer guard) — small, mechanical, safe.
6. Shadows / `RepaintBoundary` / image caching — polish pass on a `--profile` build with DevTools timeline.
