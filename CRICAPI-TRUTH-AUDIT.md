# CRICAPI-TRUTH-AUDIT — Why Live=1, Upcoming=half/24th-only, Players=none

**Date:** 2026-10-18 · **Scope:** DIAGNOSIS ONLY. No code changed, nothing pushed, nothing rebuilt.
**User report (GT 6T, latest APK):** still no real data; Upcoming shows HALF the matches,
only the 24th's date, rest missing; Live still only 1 match; player data NONE.
**Method:** full read of the provider + orchestrator + Home + Match Detail code, plus public
web search for CricAPI/CricketData.org endpoint behaviour. No live API call was possible
from this VM (no key readable from the vault; `api.cricapi.com` is unreachable from the VM).
Anything not provable from code is marked **[UNVERIFIED — needs a live probe]**.

---

## 1. Every CricAPI endpoint the app calls

Base: `https://api.cricapi.com/v1` (`lib/utils/constants.dart`, `cricApiBaseUrl`).
All in `lib/services/providers/cricapi_provider.dart`.

| # | Call (exact code) | Caller | Pagination? |
|---|-------------------|--------|-------------|
| 1 | `GET /currentMatches?apikey=…` — no `offset` param | `fetchMatches()` | No paging param at all; returns whatever the server returns in one response |
| 2 | `GET /matches?apikey=…&offset=0` — **offset hardcoded 0, never advanced** | `fetchUpcoming()` | **NO LOOP. Only page 1 is ever fetched.** |
| 3 | `GET /cricketScore?apikey=…&id=<matchId>` | `fetchScorecard()` | Single match, no paging |
| 4 | `GET /series?apikey=…&offset=0` — offset hardcoded 0, never advanced | `fetchSeries()` | NO LOOP. Only page 1. |
| 5 | `GET /players_info?apikey=…&id=<playerId>` | `fetchPlayer()` | Single player, no paging |

**Endpoints the app NEVER calls (no code anywhere calls them):**
- No `GET /players?search=…` / player-search / player-finder endpoint. There is **no
  name → CricAPI numeric player-id lookup anywhere in the codebase**.
- No `GET /matchCalendar`, no per-series fixtures (`/series/{id}/matches` style),
  no squad endpoint. `fetchSeries()` returns `{id, name, dates, matches}` and nothing
  ever fetches fixtures *for* a series.
- No second page of anything: `offset` appears exactly twice in the CricAPI provider,
  both times as the literal `offset=0`.

### What public docs say about pagination — [UNVERIFIED, best available evidence]

- Third-party usage of the same API shows `currentMatches?apikey=…&offset=0`
  (arnlweb.com WordPress example), i.e. **the API accepts an `offset` parameter** —
  which only exists to page through results. The app never advances it.
- Public search results for the current CricketData.org docs did **not** return a
  page stating the page size for `/v1/matches` (searches returned the legacy
  cricapi.com docs, which predate the `api.cricapi.com/v1` envelope). So the exact
  page size (25? 50? 100?) is **unknown from public sources**.
- What IS proven from code: **if the API pages at all, every fixture beyond page 1
  is silently never fetched.** That is the single largest structural hole in the
  Upcoming path.

---

## 2. Is the key wired? — YES in code, value UNVERIFIABLE from here

- Workflow `.github/workflows/build-apk.yml`, Build step:
  ```yaml
  env:
    CRIC_API_KEY: ${{ secrets.CRIC_API_KEY }}
  run: |
    flutter build apk --release \
      --dart-define=CRIC_API_KEY="${CRIC_API_KEY:-}" ...
  ```
- `lib/utils/constants.dart`:
  ```dart
  static const String cricApiKey = String.fromEnvironment('CRIC_API_KEY', defaultValue: '');
  static bool get hasApiKey => cricApiKey.isNotEmpty;
  ```
- `CricApiProvider.isConfigured => AppConstants.cricApiKey.isNotEmpty`
  (`cricapi_provider.dart`). When the key is empty, **every CricAPI method returns
  `null` immediately** and the provider is skipped.
- Prior context: the user added a repo secret named `CRIC_API_KEY` and the secrets
  list showed `['CRIC_API_KEY']`. The secret's **value** is never visible from the
  repo, the vault, or the VM, so a mistyped / wrong-account / expired key **cannot
  be ruled out from code**. The only proofs available are runtime ones (see §6):
  CricAPI dashboard `hitsToday` moving when the app refreshes, or a one-off probe
  call with the real key.
- **Important consequence:** if the key is empty/wrong/exhausted, the app does NOT
  show an error — it silently falls through to the backstops (§4) and, if they also
  return nothing, to mock demo data with only the small "quota" banner when
  `lastSource == 'mock'`.

---

## 3. Filters that can drop matches (with file:line)

### 3a. `fetchUpcoming` keeps only "genuinely not-started" — cricapi_provider.dart ~fetchUpcoming

```dart
if (m.status == MatchStatus.upcoming && !m.isEffectivelyLive) parsed.add(m);
```
`isEffectivelyLive` (`lib/models/match.dart:107-114`): a match labelled `upcoming`
with any score row `batted && (runs > 0 || wickets > 0)` is reclassified live.
Correct for started matches. **Not** a cause of "only 24th".

### 3b. `mergeMatches` dedupe key collapses same-teams-same-day fixtures — api_service.dart `mergeMatches` / `_fixtureKey`

```dart
key = sorted(normalised teamA, normalised teamB) + '@' + startTime day
```
Two **genuinely different** fixtures with the same two teams on the same calendar
day (double-header, men + women, two formats, a Test listed twice) collapse into
**one** entry — the "richer" one wins, the other is deleted. This can explain
"half the matches" for a busy day, but **cannot** explain "only the 24th" by itself.

### 3c. Home tab filters — lib/screens/home_screen.dart `_visible` (lines ~87-121)

- Live tab: `m.isEffectivelyLive` only.
- Upcoming tab: `m.status == upcoming && !m.isEffectivelyLive`.
- Format filter default is `'All'` (line 30) — **no format filtering by default**.
- **There is NO date filter anywhere** in Home, ApiService, or any provider.
  Nothing in code selects, prefers, or restricts to the 24th. The "only 24th"
  shape therefore comes from **the data that arrived**, not from a filter.

### 3d. Silent per-entry drop — cricapi_provider.dart `fetchMatches` / `fetchUpcoming`

```dart
for (final e in list) { try { parsed.add(_matchFromFreeApi(...)); } catch (_) {} }
```
Any list entry whose parse throws is **silently discarded** — no log, no count.
(What can throw: an entry that is not a `Map`, a `score` row that is not a `Map`,
etc. Ordinary well-formed entries do not throw, so this is a minor contributor,
not the main one.)

### 3e. Date parsing fallback masks bad dates — cricapi_provider.dart `_matchFromFreeApi`

```dart
startTime: DateTime.tryParse(j['dateTimeGMT'] as String? ?? '') ?? DateTime.now(),
```
If a `/matches` entry carries its date under a different field (e.g. `date` only,
or `dateTimeGMT` null), its `startTime` silently becomes **now**. That would put
fixtures on *today's* date, not the 24th — so it does **not** explain the user's
report, but it is a live correctness hole (fixtures with wrong dates sort wrong
and dedupe wrong).

### 3f. Quota — the invisible kill-switch

- CricAPI free tier: **100 hits/day, server-side** (`API-SETUP.md`).
- Code cap is per-provider **per app run** (`_hits >= 90`, in-memory, resets on
  restart) — it does **not** track the server-side daily count.
- On server exhaustion the API returns `status: "failure"` → every CricAPI method
  returns `null` → orchestrator falls through to backstops/mock. The user has
  been testing repeatedly; a mid-day exhaustion is plausible and would present
  exactly as "suddenly half/partial data". **[UNVERIFIED — check dashboard
  `hitsToday` / `hitsLeft` in the CricAPI response `info` block.]**

---

## 4. What the "merge all providers" actually merges in practice

`ApiService._fetchMatchesUncached` / `fetchUpcoming` (api_service.dart) ask every
**configured** provider. In the shipped build the configured set is:

| Provider | Configured in shipped APK? | What it can actually return |
|----------|---------------------------|-----------------------------|
| CricAPI | **Only if the secret's value is a valid key** (§2) | Live + upcoming + scorecard + player identity |
| EliteSport | **NO** — `ELITESPORT_API_KEY` secret not set (no key ever supplied) | Skipped entirely (`isConfigured == false`) |
| EntitySport | **NO** — `ENTITYSPORT_API_KEY` secret not set | Skipped entirely; `fetchUpcoming() => null` anyway |
| SportScore | YES (keyless) | `fetchMatches()` only, via **unverified** widget paths (`cricket/matches`, `cricket/live`, `matches?sport=cricket`). `fetchUpcoming() => null`, `fetchScorecard() => null`. It can add live scores but **never** upcoming fixtures or scorecards. |
| TheSportsDB | YES (test key `123`) | `fetchMatches()`: `livescore.php?s=Cricket`, else `searchevents.php?e=Cricket`. `fetchUpcoming()`: **`searchevents.php?e=Cricket` only** — a *name search*: it returns events whose title contains the word "Cricket". Most fixtures are titled "Team A vs Team B" and contain no such word, so this backstop returns a **sparse, arbitrary subset** — consistent with "a few fixtures, possibly all from one date". |

**Net:** if CricAPI is absent/exhausted, Upcoming is *only* TheSportsDB's name-search
subset (SportScore/EntitySport contribute nothing to Upcoming), and Live is only
whatever SportScore's unverified widget paths + TheSportsDB's livescore return.
The "merge" fix from the previous cycle is real code, but with 2 of 5 providers
keyless-and-weak and 2 unconfigured, it mostly merges **CricAPI + two thin backstops**.

---

## 5. Player data: PROVEN gap — it can never arrive for current players

The chain, end to end:

1. **Squad rows for real matches are name-only by construction.**
   `MatchDetailScreen._resolveSquad` (match_detail_screen.dart:243-283): official
   squad ids are empty for every CricAPI match (the scorecard carries no squad
   ids), the "team" fallback only matches the **6 mock players**, so every real
   squad falls through to the scorecard-names branch, building
   `Player(id: 'scorecard-<Name>', name: <Name>, source: 'scorecard')` with
   **zero stats** (empty `battingByFormat`, etc.).
2. **Tapping a scorecard player is hard-blocked — no fetch is even attempted.**
   match_detail_screen.dart ~1255:
   ```dart
   if (p.source == 'scorecard') {
     showSnackBar('Profile not available for ${p.name} yet.');
     return;
   }
   ```
   So for every current player, the UI itself refuses to look up data.
3. **Even if the fetch ran, CricAPI could not answer it.** There is no
   name → CricAPI-id lookup, and `CricApiProvider.fetchPlayer(playerId)` calls
   `/players_info?id=<playerId>` — but `playerId` here would be a *name*
   (`'scorecard-Aiden Markram'`) or a KingCric id (`'v-kohli'`), while
   `/players_info` expects CricAPI's **numeric** player id. Worse, it then hard-gates:
   ```dart
   final base = _mock.playerById(playerId);
   if (base == null) return null;   // mock has exactly 6 ids: p-virat, p-rohit, ...
   ```
   `MockDataService.playerById` compares `p.id == id` (mock_data_service.dart:69-74),
   so **any player outside those 6 returns null even if `/players_info` succeeded**.
   And when it *does* succeed (the 6 mock players), the returned `Player` reuses
   the mock's curated deep stats — CricAPI contributes only name/role/styles.
   **Conclusion: CricAPI's player endpoint can NEVER produce real career stats in
   this codebase.**
4. **Cricsheet covers 44 names from 4 matches in Jan–Jun 2024.**
   `assets/cricsheet_sample.json`: 4 matches (2024-01-20 India–England Eden Gardens;
   2024-02-15 India–Australia Wankhede; 2024-03-03 Australia–Pakistan MCG;
   2024-06-09 India–Pakistan Dubai), 44 distinct squad names. `CricsheetService
   .playerById` resolves full names → short names (`resolveShortName`,
   cricsheet_service.dart:377-393, including last-name fallback) and returns
   calculated stats — **but only for those 44 names, and only from those 4 matches
   (T20 only)**. Any player from an Oct 2026 fixture (e.g. the South Africa vs
   Australia Test that is live on 2026-10-18) is not in the 44 → `null`.
5. **Final fallback is the same 6 mock players** (`ApiService.fetchPlayer` →
   `_mock.playerById`), matched by exact id, so it also returns `null` for a
   scorecard name.

**Net:** "player ka koi data hi nahi" is exactly what the code guarantees for any
player who is not one of the 6 mock / 44 Cricsheet names. This is not a display
bug — **no code path exists that can fetch a current player's data.**

---

## 6. Ranked explanation for the user's report

| Rank | Explanation | Evidence | Status |
|------|-------------|----------|--------|
| **1** | **`/v1/matches` is paged; app fetches only `offset=0` page 1.** If page 1 holds ~the 24th's fixtures (or the first N fixtures in the API's order), every later fixture is never fetched → "half matches, only 24th". | Code: single `offset=0`, no loop. Offset param exists per third-party usage. Page size / sort order unknown publicly. | **Most likely structural cause.** Needs live probe: call `/matches` with `offset=0`, then `offset=25/50/…`, compare `data.length` + `info`. |
| **2** | **CricAPI absent/exhausted → Upcoming = TheSportsDB name-search subset.** `searchevents.php?e=Cricket` returns only events with "Cricket" in the title → sparse, possibly one-date subset → "half, only 24th". | Code paths (§4). Quota 100/day vs repeated testing. | Strong alternative / co-cause. Needs dashboard `hitsToday` check. |
| **3** | **Merge dedupe collapses same-teams-same-day fixtures** (`_fixtureKey`). | Code: api_service.dart. | Real but secondary — cannot produce "only 24th" alone. |
| **4** | **Live = 1 because CricAPI free-tier "near live" coverage is partial** and the two backstops add ~nothing live (SportScore widget paths unverified; TheSportsDB cricket livescore frequently empty). Per-entry silent parse drops add a little. | Code paths (§4, §3d). | Likely true, but magnitude unverifiable without a live probe. Note: on 2026-10-18 there *are* multiple real live matches (e.g. SA–Aus Test), so 1 live is a coverage/fetch gap, not reality. |
| **5** | **Player data = none: proven by code** (§5) — no name→id lookup, `/players_info` gated on 6 mock ids, tap hard-blocked for scorecard players, Cricsheet = 44 names / 4 matches / 2024. | Code, fully proven. | **Certain.** |
| — | **Mock-data leak? RULED OUT for "24th".** Mock upcoming = `_now + 2 days` = 20 Oct (user tested 18 Oct); mock live = India–Pakistan. The 24th cannot come from mock. | mock_data_service.dart:462-466, `_bblUpcoming` startTime `_now + 2d`. | Ruled out. |
| — | **A date/format filter selecting the 24th? RULED OUT.** No date filter exists anywhere; format default is `All`. | home_screen.dart:28-30; full grep of filters. | Ruled out. |

---

## 7. Exact fix needed (NOT done here — diagnosis only)

1. **Paginate `/v1/matches` (and `/v1/series`):** loop `offset = 0, N, 2N…` until a
   page returns fewer than N / empty. Cache the merged list 60 min. This is the
   #1 fix for "Upcoming half / only 24th". Cost: a few extra hits once per hour,
   not per refresh — affordable inside 100/day if done once and cached.
   *First probe with the real key:* one call at `offset=0` — record `data.length`
   and the `info` block (`hitsToday/hitsLeft/total?`) — then `offset=<page size>`
   to confirm paging exists and what the page size is.
2. **Verify the key at runtime:** log (debug-only, never the key value) whether
   `isConfigured` is true and what CricAPI's `info.hitsLeft` says on first call;
   surface "Live key not configured / quota exhausted" distinctly instead of
   silently degrading to backstops. Confirm the repo secret's *value* is the
   Lifetime-Free key from the CricketData dashboard (value cannot be checked
   from code).
3. **Player identity resolution (the real player-data fix):** add a name → CricAPI
   numeric-id step (the CricketData API exposes player search/lookup in its
   dashboard docs — confirm the exact endpoint with a live probe), then call
   `/players_info` with the **numeric** id, and **remove** the
   `_mock.playerById` hard-gate in `CricApiProvider.fetchPlayer` so non-mock
   players can return. Remove the scorecard-tap hard-block and route taps through
   `ApiService.fetchPlayer`. Until then, *no* current player can ever show data.
4. **Enrich Cricsheet:** replace the 4-match sample with the full `all_json.zip`
   dataset (asset swap, no code change per CRICSHEET-DATA.md) so the 44-name
   ceiling lifts; keep the "N matches in dataset" label honest.
5. **Dedupe key:** include series/league (and, for multi-day Tests, the match id
   when providers agree) in `_fixtureKey` so same-teams-same-day fixtures stop
   collapsing; dedupe on id first when both entries share a provider id.
6. **Stop silent drops:** log (debug-only) the count of dropped entries per
   provider fetch, and log which provider contributed each list, so the next
   "half matches" report is diagnosable from a debug build instead of guesswork.
7. **Quota honesty:** the in-memory `_hits` cap does not track the server-side
   100/day. Read `info.hitsLeft` from CricAPI responses and stop calling before
   the server cut-off, showing the quota banner *before* data goes partial.

## 8. What was NOT the problem (stop re-fixing these)

- UI filters, tabs, truncation, header, scorecard layout — not implicated.
- The merge-all-providers change — real, but it cannot manufacture data the
  providers never returned.
- Mock data — ruled out as the source of the 24th (see §6).
- The Gradle build / signing / install path — unrelated to data content.
