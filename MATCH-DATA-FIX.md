# MATCH-DATA-FIX — Live / Upcoming / Scorecard data missing (2026-10-18)

User report (GT 6T, final APK): Live matches incomplete; one live match
showed NO scorecard / NO match data / NO players data; Upcoming EMPTY
(no matches). Players must NOT be shown separately — they belong
INSIDE the match (squad + venue + H2H + everything in the match).

## Root causes (with file:line, pre-fix)

### R1 — Live incomplete: orchestrator returned the FIRST provider only
`lib/services/api_service.dart` — `_fetchMatchesUncached()` (pre-fix)
returned the first provider's non-empty list and never asked the
others. If CricAPI returned 1 live match, the app showed 1 live match
even when SportScore / TheSportsDB knew more. No merging, no dedupe.

### R2 — Upcoming EMPTY: nobody ever fetched upcoming fixtures
`lib/services/providers/cricapi_provider.dart` — `fetchMatches()` called
only `/v1/currentMatches`, which returns live + recent matches, NEVER
upcoming fixtures. CricAPI's upcoming endpoint (`/v1/matches`) was
never called by any provider, and `ApiService` had no upcoming path.
In live mode (CricAPI succeeds) the mock fallback never runs, so
Upcoming was genuinely empty. EliteSport / TheSportsDB only tried
fixtures when their live list was empty — and their result was
discarded anyway because CricAPI answered first (R1).

### R3 — No scorecard: Match Detail NEVER fetched the scorecard
`lib/screens/match_detail_screen.dart` — `initState()` (pre-fix) only
did `_match = widget.match` and never called
`fetchMatchDetail` / `fetchScorecard`. The Home list entry comes from
`/currentMatches`, which carries NO innings — so every live match
opened with `innings.isEmpty` → "Scorecard not available yet.",
even though `/cricketScore` had the full card. Scorecard fetch
existed in the service layer but no screen ever called it on open;
it was manual-Retry only.

### R4 — No players data in match: CricAPI scorecard has no squad list
CricAPI `/cricketScore` returns batting/bowling names but no squad
ids, so `squadA` / `squadB` were empty for every real match. The
Squad tab filtered the curated player list by those ids → empty.
(Partly fixed by the match-centric redesign already in the tree:
`_resolveSquad()` falls back to scorecard names with source
`'scorecard'`. This fix keeps that and adds R3's auto-fetch so the
scorecard names actually exist when the tab opens.)

### R5 — Refresh was a no-op inside the cache TTL
`lib/screens/home_screen.dart` — `_load()` called
`fetchMatches()` without `forceRefresh`, and the Refresh button /
pull-to-refresh called the same `_load()`. Inside the 10-min TTL the
cache was returned, so "refresh" showed the same stale list.

### R6 — Quota-exhausted fallback was silent
When CricAPI's 100-hits/day quota is exhausted, every provider
returns null and `ApiService` falls back to mock demo data with
`lastSource == 'mock'` — but Home showed no banner, so demo data
looked like (broken) live data: a "live" match with no scorecard.

## Fixes

| # | Fix | File |
|---|-----|------|
| F1 | `mergeMatches()`: ask EVERY configured provider, dedupe by normalised `(teamA, teamB, start-date)` — provider ids are NOT comparable across providers (uuid vs numeric vs idEvent). Richer entry wins: innings > more scores > live > first seen. | `lib/services/api_service.dart` |
| F2 | New `CricketProvider.fetchUpcoming()` (default `null`, so existing fakes compile). CricAPI → `/v1/matches` (keep only not-started); EliteSport → `/fixtures`; TheSportsDB → `searchevents.php?e=Cricket`. | `providers/cricket_provider.dart`, `cricapi_provider.dart`, `elitesport_provider.dart`, `thesportsdb_provider.dart` |
| F3 | `ApiService.fetchUpcoming()` merges upcoming from all providers, cached 60 min (fixtures barely change; CricAPI quota 100/day must not be spent re-fetching them every 10-min live refresh). Returns `[]`, never mock. | `lib/services/api_service.dart` |
| F4 | Home `_load({force})`: `fetchMatches(forceRefresh: force)` + merge `fetchUpcoming()`. Pull-to-refresh + Refresh button pass `force: true`. | `lib/screens/home_screen.dart` |
| F5 | Home banner when a key is configured but `lastSource == 'mock'`: "Live data unavailable right now — showing demo data. Daily API quota may be exhausted." | `lib/screens/home_screen.dart` |
| F6 | Match Detail auto-fetches detail on open (`_refreshDetail(force: false)`, cache-respecting). Retry buttons keep `force: true`. | `lib/screens/match_detail_screen.dart` |
| F7 | `_mergeDetail()`: detail innings/scores win when non-empty; squad/venue/toss from whichever side has them. A wholesale replace would WIPE the list entry's squad ids (scorecard has no squad list). | `lib/screens/match_detail_screen.dart` |
| F8 | Squad already match-centric in tree (`_resolveSquad`: official ids → team players → scorecard names labelled `'scorecard'`). Kept; F6 makes the scorecard names exist. Venue+H2H tab + Prediction tab already use the same resolved squads. | `lib/screens/match_detail_screen.dart` (pre-existing) |

## What is still honestly limited (not faked)

- **H2H**: no free provider returns team head-to-head. `H2HCard`
  shows 0–0 when no data; the Venue+H2H tab labels venue stats
  from the curated set and says "Not available from free providers
  yet." for pitch/weather. Never invented.
- **Squad full stats**: scorecard-derived squad rows carry names
  only (`source: 'scorecard'`); tapping one shows "Profile not
  available" unless the name matches a curated player. Full career
  stats for arbitrary XI players need a player-search endpoint no
  free tier offers.
- **CricAPI quota**: 100 hits/day. Live list 1 call / 10-min TTL,
  upcoming 1 call / 60-min TTL, scorecard 1 call per match open
  (cached). A user who opens the app all day can still exhaust it;
  the F5 banner says so instead of silently showing demo.
- **Merging cost**: one `fetchMatches` now calls every configured
  provider (CricAPI 1 + keyless backstops). Keyed providers without
  keys are skipped. Per-provider in-memory caps still apply.

## Verification

- `flutter analyze` → clean.
- `flutter test` → full suite passes (incl. new
  `test/match_data_fix_test.dart`: merge dedupe richer-wins,
  distinct fixtures kept, upcoming cache, CricAPI unconfigured
  returns null safely, `mergeMatches` unit).
- `flutter build web --release` → OK.
- Commit: `Fix: Live/Upcoming/Scorecard data missing` (local only,
  NOT pushed).
