# KingCric — Reliability Spec: Error Handling + Offline

> Role: Reliability Engineer. READ-ONLY audit + spec. **No code was edited.**
> Date: 2026-10-18. Codebase audited: `lib/services/`,
> `lib/services/providers/*`, `lib/screens/*`, `lib/utils/strings.dart`,
> `lib/utils/constants.dart`, `lib/main.dart`, `test/*.dart`.
> Test run at audit time: `flutter test` → **53 passed, 4 failed**.
> Failing (widget tests, pre-existing at audit time, NOT fixed here):
> `match_detail_test.dart` FOW row number-once; `match_detail_test.dart`
> Squad tab splits; `widget_test.dart` OverGraph FOW + partnership bars;
> `widget_test.dart` Profile shows ONE Cricsheet source line.
> Reliability-relevant service/model tests (fallback, cross-check,
> status resolution, caching, AutoUpdate never-throws, NaN guards) pass.

## 1. Non-negotiable rules

1. **Never crash.** Every network / parse / storage call is guarded.
   An uncaught error shows a fallback screen, never a killed process.
   (`main.dart` already does this with `runZonedGuarded` +
   `FlutterError.onError` — keep it.)
2. **Never blank.** A failed refresh keeps the last verified data on
   screen. A screen with no cache shows an honest empty/error state
   with Retry — never an infinite spinner, never a blank page.
3. **Never fake data.** Fallback to cache → mock demo is allowed ONLY
   if the UI labels it honestly (Demo / Offline / Last updated).
   Demo data must never be presented as live, and a stale cache must
   never be presented as fresh.
4. **Never lose the error silently.** `catch (_)` with no logging is a
   bug (see §5). Errors are classified, logged (no keys / no PII),
   and surfaced as a user-facing message + Retry where the user can act.
5. **Never burn quota on a doomed retry.** 400/401 = do not retry.
   429 = stop, respect back-off, tell the user. 500/503/timeout/socket
   = retry with back-off, max 3 attempts, then fall back.

## 2. What the code does TODAY (audited, not assumed)

### 2.1 Provider layer — strong fail-soft, weak diagnosis

Every provider (`CricApiProvider`, `EliteSportProvider`,
`EntitySportProvider`, `SportScoreProvider`, `TheSportsDbProvider`)
follows the `CricketProvider` contract: **never throw** — return
`null` / `[]` on any error, timeout, bad shape, quota exhaustion, or
wrong base URL. Each `_get` / `_getJson`:

- Checks `_capped` (in-memory daily self-cap) before calling.
- Increments `_hits` **before** the request (so a timeout / 500 also
  consumes one cap unit — see Gap G2).
- `http.get(...).timeout(15s)`.
- `if (res.statusCode != 200) return null` — **all non-200 codes are
  treated identically** (see Gap G1). There is no branch for
  400 / 401 / 403 / 404 / 429 / 500 / 502 / 503.
- `catch (_) { return null; }` — **exception type is discarded**
  (see Gap G4). `SocketException`, `TimeoutException`,
  `ClientException`, `FormatException` are indistinguishable.
- JSON parsing is defensive: `jsonDecode` in try/catch, per-item
  try/catch, `ProviderParsing.toInt/toDouble/toStr` defaults to 0/''.
  A malformed envelope → `null` → fallback. Good.
- `testKey()`: 1 cheap call, `statusCode != 200 → false`,
  `body['status'] == 'success'` required. Any exception → `false`.
  Good, but the caller cannot tell *why* it failed (bad key vs
  no network vs server down).

`CricsheetService.loadBundled()` / `parse()`: never throw — missing /
malformed asset → empty service. Good. `ApiService._cricsheet()` also
never throws.

### 2.2 Orchestrator (`ApiService`) — fallback chain works, diagnosis does not

- Fallback chain: CricAPI → EliteSport → EntitySport → SportScore →
  TheSportsDB → cache → mock. A provider returning `null` / `[]`
  moves to the next provider. Good.
- Cache: matches 10-min TTL (live), detail 10-min live / 60-min
  completed, series 60-min, player 60-min. `fetchMatches` returns
  fresh cache without a network call. Good.
- `refreshMatchesInBackground()` = stale-while-revalidate: returns
  cache immediately, refreshes in background, calls `onUpdated`.
  Errors keep cache. Good.
- In-flight deduplication: `_matchesInFlight` + `_scorecardInFlight`
  share one request across concurrent callers. Good.
- Cross-check: `crossCheckMatches()` compares primary vs cached
  other-provider result, logs mismatch via `debugPrint`, keeps
  primary. **It never blocks bad data** — `CompletenessValidator.
  pickVerifiedMatch()` exists but `ApiService` does not call it
  (see Gap G6). The validator is only enforced in
  `AutoUpdateService` for the live→completed transition.
- `testApiKeyValidity({key})`: ignores the passed-in `key` value
  (comment in code admits this — keys are compile-time defines, so
  a typed key cannot be tested without rebuilding the provider).
  It tests the compiled-in providers instead. **A Settings screen
  that passes a typed key gets a misleading answer** (Gap G7).
- `fetchMatches` / `fetchScorecard` / `fetchSeries` / `fetchPlayer`
  **never throw** — they return cache / mock / `null`.
  Consequence: **callers cannot distinguish** no-internet vs
  quota-exhausted vs bad-key vs bad-JSON vs genuinely-empty
  (see Gap G3). Every failure looks the same downstream.

### 2.3 Auto-update (`AutoUpdateService`) — best-guarded component

- `tick()` never throws; re-entrancy guard `_ticking` skips
  overlapping ticks; every listener call is try/catch-guarded so one
  bad listener cannot break the tick or the others. Good.
- `start()` never throws; timer creation guarded. Good.
- `resume()`: refreshes only when a live match exists; otherwise
  re-emits cached matches. Good (quota-safe).
- `refreshLiveOnly()`: force-refreshes matches only; completed
  matches served from cache. Good.
- Live→completed transition: fetches final scorecard with
  `forceRefresh: true`, validates with
  `CompletenessValidator.inningsReconciles()`, drops invalid
  scorecards, keeps last verified data. Good.
- `lastPoll` timestamp is updated per tick for "Last updated" UI.
  Good.

### 2.4 Screens — inconsistent error states (biggest surface gap)

| Screen | Error state today | Verdict |
|---|---|---|
| Home | `_load()` try/catch sets `_offline = _matches.isNotEmpty` + shows `offline_banner` ("Offline — showing last verified data."). First load shows full-page spinner; refreshes keep last list. Has "Last updated HH:MM" + manual Refresh + pull-to-refresh. | **Mostly good — but the catch is nearly dead code** (Gap G3): `ApiService.fetchMatches()` never throws, so `_load()`'s catch almost never runs and `_offline` is almost never set. The banner exists but is rarely shown even when the network is down. |
| Leagues | `FutureBuilder` with `snap.hasError` → "Could not load matches. Check your connection and try again." + Retry (`_reload`). | **Retry is dead code** (Gap G3): the future (`ApiService.fetchMatches()`) never throws, so `hasError` is never true. A network failure shows mock/empty data, not this error. |
| Stats | Same pattern: `hasError` → "Could not load stats…" + Retry. | Same — dead `hasError`. |
| Favourites | Same pattern: `hasError` → "Could not load favourites…" + Retry. Plus nested `hasError` for matches ("Could not load matches for your teams."). `SharedPreferences` load has `_prefsOrNull()` → in-memory fallback. | Same — dead `hasError` for network. Prefs fallback is good. |
| Match Detail | Squad / Prediction tabs: `FutureBuilder`, `if (!snap.hasData)` → spinner. **No `hasError` branch at all.** No Retry. If the future never completes with data, the spinner is infinite (in practice `fetchPlayers()` returns mock, so it resolves — but the code has no error path). Scorecard/Live tabs render from the passed-in `Match` object; a `null` detail is not distinguished from "still loading". | **Gap G8**: no error state, no Retry, potential infinite spinner. |
| Compare | `_loading` bool + spinner, no error state, no Retry. `double.tryParse` → `NaN` handled by prediction guards. | **Gap G8**: no error state. |
| Player Profile | Takes a `Player` object directly — no fetch, no FutureBuilder, no error state. Relies on the caller having a valid player. | Acceptable IF callers always pass valid data; no independent error path. |
| Global (`main.dart`) | `runZonedGuarded` + `FlutterError.onError` → `debugPrint`. No `ErrorWidget.builder`, no crash-reporting service, no user-visible fallback screen. | Adequate for a free build; a user-visible "Something went wrong — Restart" fallback screen is missing (Gap G9). |

### 2.5 Strings — only 2 error strings exist

`lib/utils/strings.dart` has `offline_banner` ("Offline — showing
last verified data." / "ऑफ़लाइन — आखिरी वेरिफाइड डेटा दिख रहा है।")
and `mock_mode` ("Demo data — add a free API key to go live").
There are **no** strings for: no-internet, timeout, server error,
invalid/expired key, quota exhausted, provider down, empty result,
retry, or "showing stale data". Three screens hard-code English
error text (`'Could not load matches…'`) instead of going through
`Strings.t` — those strings do **not** switch to Hindi (Gap G10).

### 2.6 Quota / caps

- Per-provider in-memory caps: CricAPI 90/100, SportScore 500,
  SportsDB 400, EliteSport 90, EntitySport 90. Caps are checked
  before each call. Good.
- Caps are **per app run only** — they reset on restart, so a restart
  loop can exceed the provider's daily limit. No date-based reset,
  no persistence (Gap G2).
- No "quota exhausted" user message. When capped, the provider
  returns `null` silently and the chain falls through to the next
  provider / cache / mock. The user sees stale or demo data with
  no explanation (Gap G2).
- `providerHits` exposes per-provider hit counts for debugging.
  Good, but not surfaced in UI.

### 2.7 Logging

- Only 2 `debugPrint` call sites: `main.dart` (FlutterError + zone
  error) and `ApiService.crossCheckMatches` (mismatch). No
  structured logging, no log levels, no request logging (provider /
  endpoint / status / duration), no error classification (Gap G4).
- `catch (_)` everywhere discards the exception object and stack.
  Post-mortem debugging is impossible for field failures.

### 2.8 No connectivity detection

- No `connectivity_plus` (or any) dependency in `pubspec.yaml`.
  The app never knows whether the device is offline vs the server
  is down. "Offline" is inferred only from a failed fetch.
  Acceptable for a free build, but the offline banner cannot be
  accurate without it (Gap G5).

## 3. Per-error expected behaviour (the contract)

`Failure` is classified at the provider boundary and propagated as
a **typed result**, not as a bare `null`. Screens branch on the
classification, not on "did it throw".

```dart
// Proposed (spec, not yet implemented):
enum FailureKind {
  noInternet,      // SocketException / connectivity lost
  timeout,         // TimeoutException (15s)
  badRequest,      // HTTP 400 — malformed request, do NOT retry
  unauthorized,    // HTTP 401 / 403 — bad / expired key, do NOT retry
  notFound,        // HTTP 404 — match/player/series does not exist
  rateLimited,     // HTTP 429 — quota exhausted, respect back-off
  serverError,     // HTTP 500 / 502 / 503 — transient, retry with back-off
  badPayload,      // HTTP 200 but JSON malformed / wrong shape
  quotaExhausted,  // local self-cap hit (before any network call)
  noKey,           // provider not configured (key missing)
  emptyResult,     // HTTP 200, valid shape, zero items
  cacheOnly,       // all providers failed, serving last verified cache
  demoFallback,    // all providers + cache failed, serving mock demo
}
```

| # | Failure | Current behaviour | REQUIRED behaviour |
|---|---|---|---|
| E1 | **No internet** (SocketException, airplane mode, DNS fail) | Provider returns `null` → chain → cache/mock. Home `_offline` almost never set (Gap G3). Other screens show mock/empty, no message. | Keep cache, show **Offline banner** (EN+Hindi, §6) + "Last updated HH:MM" + **Retry** button. If no cache, show empty-error state with Retry (not spinner, not blank). Do NOT show demo data as if it were live. |
| E2 | **Timeout** (15s, slow / flaky network) | Same as E1 — `null`, silent. | Treat as transient: **retry with back-off** (§4) up to 3 attempts for this call. On final failure, same as E1 (cache + banner + Retry). Log as `timeout`. |
| E3 | **HTTP 400** (bad request — bad `id`, bad param) | `statusCode != 200 → null`, silent. | **Do NOT retry.** Log `badRequest` with endpoint + param shape (never the key). Fall back to cache/mock. If the `id` is user-visible (match/player), show "Not found" state (§6), not a generic error. |
| E4 | **HTTP 401 / 403** (bad / expired / revoked key) | `null`, silent. App falls back to backstop/mock. User has no idea their key is dead. | **Do NOT retry.** Mark provider `keyInvalid` for the rest of the session (stop burning calls against a dead key). Show **"API key invalid / expired — check your key"** (EN+Hindi) + how to fix (Dashboard → copy new key → GitHub secret / rebuild). Fall back to backstop/cache/mock with honest label. `testKey()` must return a *reason* (see §7). |
| E5 | **HTTP 404** (match/player/series not found) | `null`, silent. | **Do NOT retry.** Show "Not found" empty state for that item. Do NOT fall back to an unrelated mock item (a 404 for match X must never render match Y's data). |
| E6 | **HTTP 429** (provider rate limit) | `null`, silent. Chain tries the next provider (good) but each provider is also retried by the next tick, burning calls. | **Stop this provider for the session** (or until `Retry-After` + back-off expires). Show **"Daily limit reached — showing last verified data. Try again later."** (EN+Hindi). Do NOT hammer the provider. Log `rateLimited`. |
| E7 | **HTTP 500 / 502 / 503** (provider server error) | `null`, silent. | Transient: **retry with back-off** (§4), then next provider. On all-provider failure: cache + banner + Retry. Log `serverError` with status code. |
| E8 | **Bad JSON / wrong shape** (HTTP 200, `jsonDecode` throws, or `data` is not the expected type) | Caught → `null`, silent. | Log `badPayload` with endpoint + a truncated shape hint (keys, not values). Fall back to cache/mock. Do NOT crash. Do NOT show partial data as complete — run `CompletenessValidator` before rendering any provider payload that reaches a scorecard (see §7). |
| E9 | **Empty list** (HTTP 200, valid shape, `data: []`) | Provider returns `null` (empty → `null`), indistinguishable from an error. Orchestrator falls through to mock. | Distinguish `emptyResult` from error: if the provider *answered* with zero items, that is a valid answer — show the honest empty state ("No matches in this section."). Do NOT silently substitute mock demo data for a valid empty answer when a key is configured (see Gap G11). |
| E10 | **Quota exhausted (local self-cap)** | Provider returns `null` before calling. Silent. | Return `quotaExhausted`, not generic `null`. Show **"Daily limit reached"** message (§6). Do NOT fall through to mock as if live. Log once per session (not per call). |
| E11 | **No key / provider not configured** | Provider skipped silently. Home shows `mock_mode` banner. Other screens show no banner. | Every screen that shows provider-backed data must show the mode honestly: **Demo** (no key) vs **Live** (key) vs **Backstop** (keyless). No screen may render demo data without a Demo label. |
| E12 | **Provider down (whole provider unreachable)** | Chain falls through to next provider. Good — but no log, no user signal. | Chain + log `providerDown`. If ALL providers fail: cache + banner + Retry. If the failure persists across 2 ticks, show the banner persistently (not just on one screen). |
| E13 | **Stale cache** (cache exists but expired, refresh fails) | Cache is returned on failure (good), but UI shows it as if fresh except Home's "Last updated". | Keep cache + show **stale indicator**: "Last updated HH:MM" in amber + "Showing last verified data" + Retry. Never present stale data as fresh. |
| E14 | **Cricsheet asset missing / malformed** | `loadBundled()` → empty service, `parse()` → empty. Good. | Keep. Player profiles fall back to provider/mock with honest source label. Log `badPayload` once. |
| E15 | **SharedPreferences failure** (Favourites) | `_prefsOrNull()` → in-memory fallback, best-effort save. Good. | Keep. Never crash on prefs failure. |
| E16 | **Uncaught Dart / Flutter error** | `runZonedGuarded` + `FlutterError.onError` → `debugPrint`. No user-visible fallback. | Add a user-visible fallback: "Something went wrong — Restart" screen with a Restart button (Gap G9). Never a red error screen in release, never a silent kill. |

## 4. Retry logic (spec — not yet implemented)

| Rule | Value |
|---|---|
| Transient failures retried | `timeout`, `serverError` (500/502/503), `noInternet` **only when connectivity returns** (no blind retry loop while offline) |
| Never retried | `badRequest` (400), `unauthorized` (401/403), `notFound` (404), `badPayload` (shape), `quotaExhausted`, `noKey` |
| Rate-limited (429) | No immediate retry. Respect `Retry-After` header if present, else back off 60s → 5 min → stop for session. Show "Daily limit" message. |
| Back-off | Exponential with jitter: attempt 1 immediate, attempt 2 after ~1s, attempt 3 after ~2s, attempt 4 after ~4s. **Max 3 retries (4 attempts total)** per user-initiated call. Background ticks do NOT retry inside one tick — the next 10-min tick is the retry. |
| Quota safety | Retries count against the same per-provider cap. A retry must never push `_hits` past `dailyCap`. Retrying a 429 or a 401 is forbidden (it burns quota for zero information). |
| User-initiated vs background | Manual Refresh / Retry button → immediate retry with back-off. Auto-update tick → single attempt per provider per tick, no in-tick retry; the next tick retries. |
| Deduplication | In-flight dedup (already implemented) applies to retries too: concurrent callers share one retry chain, never two. |
| Cancellation | A retry chain is abandoned if the screen is disposed / the user navigates away. No `setState` after dispose (screens already guard with `mounted` — keep it). |

## 5. Logging (spec — not yet implemented)

Today: 2 `debugPrint` sites, `catch (_)` discards everything.
Required:

- **One logger**, e.g. `KingCricLog` in `lib/utils/logging.dart`:
  `log(level, tag, message, {error, stackTrace})` with levels
  `debug / info / warning / error`.
- Log every provider call: provider, endpoint path (never the key,
  never full URL with `apikey=`), HTTP status, duration ms, outcome
  (`ok / FailureKind`), hits-today. Example:
  `CricAPI currentMatches 200 812ms ok hits=12`.
- Log every fallback: `CricAPI null → EliteSport null → cache`.
- Log every cross-check mismatch and every validator rejection.
- Log every quota-cap hit and every 429, once per session per
  provider (not per call — no log spam).
- **Never log**: API keys, full URLs containing keys, user PII,
  full response bodies. Log shapes (keys, counts), not values.
- `debugPrint` in debug builds; in release, keep an in-memory ring
  buffer (last ~200 entries) that a future Diagnostics screen can
  show. No third-party crash SDK in the free build (no Firebase
  Crashlytics dependency added by this spec).

## 6. User-facing messages (Hindi + English — new `strings.dart` keys required)

All messages go through `Strings.t` (never hard-coded English).
Tone: plain, no jargon, one action (Retry / check key / try later).

| Key (proposed) | EN | Hindi |
|---|---|---|
| `error_no_internet` | "No internet — showing last verified data." | "इंटरनेट नहीं है — आखिरी वेरिफाइड डेटा दिख रहा है।" |
| `error_timeout` | "Taking too long — showing last verified data." | "बहुत देर लग रही है — आखिरी वेरिफाइड डेटा दिख रहा है।" |
| `error_server` | "Server is having trouble — showing last verified data." | "सर्वर में दिक्कत है — आखिरी वेरिफाइड डेटा दिख रहा है।" |
| `error_quota` | "Daily limit reached — showing last verified data. Try again later." | "आज की लिमिट खत्म हो गई — आखिरी वेरिफाइड डेटा दिख रहा है। बाद में फिर कोशिश करें।" |
| `error_bad_key` | "API key is invalid or expired — check your key in Settings." | "API key गलत या खत्म हो गई है — Settings में अपनी key चेक करें।" |
| `error_not_found` | "Not found — this match / player may have been removed." | "नहीं मिला — यह मैच / खिलाड़ी हटाया गया हो सकता है।" |
| `error_load_failed` | "Could not load. Check your connection and try again." | "लोड नहीं हुआ। कनेक्शन चेक करके फिर कोशिश करें।" |
| `error_stale` | "Showing last verified data." | "आखिरी वेरिफाइड डेटा दिख रहा है।" |
| `retry` | "Retry" | "फिर कोशिश करें" |
| `offline_banner` | (exists) "Offline — showing last verified data." | (exists) "ऑफ़लाइन — आखिरी वेरिफाइड डेटा दिख रहा है।" |
| `demo_banner` | (exists as `mock_mode`) "Demo data — add a free API key to go live" | (exists) "डेमो डेटा — लाइव के लिए फ्री API key डालें" |

**Where each message appears:**
- Home: Offline banner (E1/E2/E7/E12/E13) + Demo banner (E11) + Last updated + Refresh. Both banners can show together (offline + demo) — they are independent facts.
- Leagues / Stats / Favourites: the existing `hasError` + Retry UI must be wired to a **real** error signal (§7), and its hard-coded English text must move into `strings.dart` (Gap G10).
- Match Detail: add the missing error state (Gap G8): error text + Retry, never an infinite spinner.
- Compare / Player Profile: add an error/empty state (Gap G8).
- Scorecard: a validator rejection (E8) shows "Scorecard is being verified — showing last verified card." + Retry, never a half-parsed card.

## 7. Gaps found (ranked) + required fixes

| ID | Gap | Evidence | Fix required (before shipping) |
|---|---|---|---|
| G1 | **HTTP status codes are not distinguished.** 400/401/404/429/500 all → `null`. | Every provider: `if (res.statusCode != 200) return null;` | Branch on status code at the provider boundary; map to `FailureKind` (§3). 401/429 get dedicated handling (stop, message). |
| G2 | **Quota exhaustion is silent + caps reset on restart.** `_hits++` before the request; caps are in-memory only; no user message. | `constants.dart` caps; provider `_capped` checks; no "quota" string. | Return `quotaExhausted` (not `null`); show §6 `error_quota`; persist hits + date (e.g. `SharedPreferences`: `hits_<provider>_<yyyy-mm-dd>`) so restart does not reset the cap; count only *completed* requests, not timeouts, against the cap — or document that timeouts count. |
| G3 | **Screens' error states are dead code.** `ApiService` never throws, so `Home._load` catch, and Leagues/Stats/Favourites `snap.hasError`, almost never fire. | `ApiService` returns cache/mock/`null` on every path; `fetchMatches` has no `throw`. | Introduce a typed result / `lastFailure` on `ApiService` (e.g. `ApiService.lastFailure: FailureKind?` + `lastFailureAt`) that screens read after a fetch. Wire Home `_offline`, Leagues/Stats/Favourites `hasError`, and Match Detail's missing error state to it. Do NOT make `ApiService` throw — keep never-throw, but make the failure *observable*. |
| G4 | **Errors are swallowed, never logged.** `catch (_)` discards exception + stack; only 2 `debugPrint` sites. | `grep` for `catch (_)` across `lib/`; `debugPrint` only in `main.dart` + cross-check. | Add `KingCricLog` (§5); log provider calls, fallbacks, mismatches, validator rejections, quota hits. Log shapes, never keys/PII. |
| G5 | **No connectivity detection.** "Offline" is inferred from failed fetches. | No `connectivity_plus` in `pubspec.yaml`; no connectivity listener. | (Optional for v1, required for accurate banner) Add `connectivity_plus` or a lightweight `InternetAddress.lookup` probe; show Offline banner only when the device is offline, and "Server trouble" when the device is online but the provider fails. Until then, the banner must say "showing last verified data" (which is true in both cases) — never claim "Offline" when it might be the server. |
| G6 | **Cross-check never blocks bad data.** `pickVerifiedMatch()` exists but `ApiService` never calls it; cross-check only logs. | `CompletenessValidator.pickVerifiedMatch` has no callers in `ApiService`. | Call `pickVerifiedMatch()` (or at least `inningsReconciles()`) on every provider scorecard before caching/rendering it. A non-reconciling card is dropped, not rendered. |
| G7 | **`testApiKeyValidity({key})` ignores the passed-in key.** A typed key cannot be tested; the answer describes the compiled-in key. | Comment in `api_service.dart` admits this. | Either (a) remove the `key` parameter and rename to `testConfiguredKey()`, or (b) build a throwaway provider with the typed key and test it. Never return a misleading "valid" for a key that was never tested. |
| G8 | **Match Detail / Compare / Player Profile have no error state.** Infinite spinner risk; no Retry. | `match_detail_screen.dart` Squad/Prediction `FutureBuilder`: only `!hasData → spinner`. `compare_screen.dart`: `_loading` + spinner only. | Add error + Retry states to Match Detail (Squad/Prediction/Scorecard), Compare, and Player Profile, wired to `lastFailure` (G3). |
| G9 | **No user-visible crash fallback.** Zone + `FlutterError` only `debugPrint`. | `main.dart`: no `ErrorWidget.builder`, no fallback screen. | Add a minimal fallback: on zone/Flutter error, show "Something went wrong — Restart" with a Restart button that re-runs `main()`. Keep `ErrorWidget.builder` untouched (test framework constraint noted in `main.dart`). |
| G10 | **Hard-coded English error text in 3 screens.** Leagues/Stats/Favourites error strings bypass `Strings.t` → they never switch to Hindi. | `'Could not load matches…'`, `'Could not load stats…'`, `'Could not load favourites…'` literals. | Move all user-facing error text into `strings.dart` with EN + Hindi (§6). |
| G11 | **Valid empty answer is conflated with failure.** Provider returns `null` for empty parsed lists, so a genuine "no matches" is treated as an error and replaced by mock. | `return parsed.isEmpty ? null : parsed;` in every provider. | Return `[]` (not `null`) for a valid empty answer; return `null` only for failure. Orchestrator: `[]` → honest empty state; `null` → next provider / cache / mock. This is the E9 fix. |
| G12 | **No `Retry-After` handling.** 429 responses are not parsed for `Retry-After`. | No header parsing in any provider. | Parse `Retry-After` (seconds or HTTP date); if present, back off until then; else §4 back-off. |
| G13 | **No request timeout distinction.** All providers use 15s, but a 15s timeout on a slow network is treated the same as a refused connection. | `.timeout(15s)` everywhere, `catch (_)`. | Keep 15s, but classify `TimeoutException` as `timeout` (retryable) vs `SocketException` as `noInternet`. Requires G4 (stop discarding exception types). |

## 8. Offline mode (spec)

- **Definition:** Offline = device has no network OR all providers
  failed. The app must remain fully usable on cache + bundled data
  (Cricsheet sample + mock demo, both offline-safe).
- **Behaviour:**
  - Show the Offline banner (§6) on every data screen, not just Home.
  - Keep last verified cache; show "Last updated HH:MM" + stale
    indicator when the cache is older than its TTL (E13).
  - Pull-to-refresh / Retry still works offline — it attempts one
    fetch, fails fast, and keeps cache (no spinner hang, no blank).
  - Favourites / Compare / Stats work offline on cached + mock data
    (they already do — `fetchPlayers()` is mock-backed).
  - Cricsheet player profiles work fully offline (bundled asset).
  - No screen may show an infinite spinner while offline.
- **What offline is NOT:** offline does not mean "demo". Cached
  *live* data shown offline keeps its Live source label + stale
  timestamp; mock demo data keeps its Demo label. The two are never
  mixed.

## 9. Acceptance tests (for the implementing team)

1. Airplane mode + cold start → app opens, shows last cache or
   honest empty state, Offline banner, no crash, no infinite spinner.
2. Airplane mode + pull-to-refresh → one attempt, cache kept,
   banner stays, no blank.
3. Provider returns 401 → "API key invalid" message, provider
   stopped for session, backstop/cache shown, no retry storm.
4. Provider returns 429 → "Daily limit" message, provider stopped,
   no retry for the session.
5. Provider returns 500 → retry with back-off (≤3), then next
   provider, then cache + banner + Retry.
6. Provider returns 200 + malformed JSON → `badPayload` logged,
   cache kept, no crash, no partial card.
7. Provider returns 200 + `data: []` → honest "No matches in this
   section.", NOT mock demo data.
8. Local cap hit → "Daily limit" message, no network call made.
9. `testApiKeyValidity` with a typed key → tests *that* key, or the
   parameter is removed (G7).
10. Match Detail + Compare + Player Profile with failing fetch →
    error state + Retry, never infinite spinner.
11. Hindi toggle → every error / banner / Retry string switches to
    Hindi (no hard-coded English remains).
12. Zone/Flutter error → user-visible "Something went wrong —
    Restart" screen, app recoverable without reinstall.
13. `flutter test` green (including new tests for E1–E12), and the
    4 pre-existing widget failures from §0 are either fixed or
    explicitly triaged (they are NOT fixed by this spec).

## 10. What is already good (keep, do not regress)

- Provider never-throw contract + defensive parsing (defaults, not
  crashes).
- Fallback chain (5 providers → cache → mock) + in-flight dedup.
- Cache TTLs (live 10 min / completed 60 min) + stale-while-revalidate.
- `AutoUpdateService`: never throws, re-entrancy guard, validator
  gate on live→completed, resume-only-when-live.
- `CompletenessValidator`: reconciliation tolerance, `matchesAgree`,
  `isPlayerComplete` staleness rule.
- `CricsheetService`: never throws on missing/malformed asset.
- Favourites `SharedPreferences` in-memory fallback.
- `main.dart`: `runZonedGuarded` + `FlutterError.onError` +
  guarded `AutoUpdateService.start()`.
- Home: first-load spinner vs refresh-keeps-data, "Last updated",
  manual Refresh, pull-to-refresh, `mounted` guards.
