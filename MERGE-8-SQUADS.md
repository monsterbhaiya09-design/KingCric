# Merge — 8 Squads (2026-10-18)

Merge lead report. All 8 squad commits were stacked on `main` (local
only, NOT pushed). The tree was clean before merging; no squad work
was lost — every squad's files are present in its commit (verified
via `git show --stat`).

## Squads merged

| Squad | Commit | Scope |
|---|---|---|
| H — Play Store readiness | `6c6b19f` | `PLAYSTORE-RELEASE.md`, `PRIVACY-POLICY.md` (new), `RELEASE-CHECKLIST.md` (new) |
| C — CricAPI provider | `794f8d2` | `cricapi_provider.dart` + `squad_c_cricapi_test.dart` |
| B — Home display | `be4885b` | `home_screen.dart`, `match_card.dart` + `squad_b_home_test.dart` |
| D — Providers + status truth | `b19fb69` | 5 providers + `cricket_provider.dart` + `squad_d_providers_test.dart` |
| G — QA tests | `390a7d1` | `squad_g_qa_test.dart` |
| E — Models + core logic | `e793741` | `match.dart` (MatchMerge), auto-update, prediction, completeness, smooth_update + `squad_e_models_test.dart` |
| F — Secondary screens | `526aec3` | compare / favourites / player profile / h2h / player / prediction / squad-player cards + `squad_f_screens_test.dart` |
| A — Cricsheet wiring (resumed) | `b5dfa53` | `cricsheet_service.dart`, `api_service.dart` (wiring part), `match_detail_screen.dart`, `strings.dart` + `cricsheet_wiring_test.dart` |

Merge commit: `Merge 8 squads + merge fixes` (this change).

## Merge fixes (applied by the merge lead)

### 1. Home-path merge dropped double-headers (Squad G finding)
`HomeScreen._load` calls `ApiService.mergeMatches([live, upcoming])`
WITHOUT `providerNames`. The old bucketing only applied the
same-provider + different-id rule when provider names were supplied,
so on the production Home path two distinct same-teams/same-day
fixtures (double-header, different ids, same source) collapsed into
one card. Fixed by making the no-names path fall back to each entry's
own `CricketMatch.source` for provider attribution (see fix 2).
Regression tests in `test/merge_gap_test.dart` (new): double-header
via the Home path keeps BOTH; same fixture from 2 providers via the
Home path merges to 1; same fixture in live + upcoming lists merges
to 1 with the live copy winning.

### 2. One definition of merge: `ApiService.mergeMatches` → `MatchMerge`
`ApiService` had its own local `richness()`, `_baseKey`, `_leagueKey`
and `_MergeBucket` — a second definition of richness/dedupe that had
already drifted from Squad E's `MatchMerge` (local version added
squad lengths; `MatchMerge` subtracts placeholder rows). Deleted all
of it. `mergeMatches` is now a thin pairwise loop over
`MatchMerge.mergeCandidates` / `MatchMerge.pickRicher`, with
effective provider = `providerNames[li]` when supplied, else the
entry's own `source`. `MatchMerge.mergeCandidates` gained optional
`providerA`/`providerB` overrides for exactly this. `MatchMerge`
also now treats the generic league label `'Cricket'` as the
international bucket (the old bucketing did; without this a
`'Cricket'`-league copy would never merge with the same fixture
reported with a real league).
Consequence: `main_core_fix_test.dart` "completed beats live" used
different ids for the two copies of the SAME fixture — under the
single definition, same provider + different ids = DISTINCT fixtures
(a double-header where match 1 finished and match 2 is live must NOT
merge). The test now uses the same id for both copies (same fixture
from one provider really does carry one id); its intent (completed
beats live on equal scores) is unchanged.

### 3. Stale `fetchUpcoming` doc comment
Said TheSportsDB supplies fixtures via `searchevents`. It does not:
Squad D made `fetchUpcoming` return `[]` with zero calls (keyword
title-search is junk as fixtures). Comment updated.

### 4. (Found during merge verification) `runAsync` warm-up deadlock
`match_detail_test.dart` and `match_centric_test.dart` warmed the
parse-once Cricsheet cache with `tester.runAsync(loadBundled)` inside
individual tests. That deadlocks when a previous test pumped
`MatchDetailScreen`: the Squad tab's asset-load future then never
completes, the spinner never disappears, `pumpAndSettle` hangs, and
the whole file failed on shutdown (the full suite stalled ~8 min on
this). Bisected with throwaway `zz_debug*` tests (deleted): trivial
`runAsync` and parse-only work after a screen test; only the asset
load inside `runAsync` after a screen test hangs. Fix: warm the
cache ONCE in `setUpAll` (real zone, before any fake-async test) in
both files; per-test `runAsync` warm-ups removed. Both files now pass
in ~14 s combined.

## Verification (quiet tree, no other agents editing)

- `flutter analyze` → **No issues found!**
- `flutter test` (full suite) → **189 passed, 21 skipped**
  (skipped = CricAPI tests needing a dummy key, as before).
  Before fix 4 the full suite stalled ~8 min on the Squad-tab test;
  after fix 4 it completes in ~35 s.
- `flutter build web --release` → **✓ Built build/web**

## Remaining limits (honest)

- CricAPI `/v1/players?search=` param is still best-effort /
  unverified in public docs — needs one live probe with the real key.
- Cricsheet subset covers 2024–2026 only; pre-2024 careers are not
  in the app. Full 4 GB archive needs a server-side store.
- Cricsheet 25 MB parse is still on the calling thread (isolate =
  follow-up); do not grow the asset further without that fix.
- EliteSport / EntitySport keys still not supplied — those providers
  stay skipped.
- The compiled-in key's VALUE (valid or not) still cannot be checked
  from code — CricAPI dashboard `hitsToday` is the proof.
- Live payload shapes from `api.cricapi.com` still can't be inspected
  from this VM (host blocked); merge/status fixes are proven by
  mocked-payload tests, not a live probe.
- Play Store still needs: release keystore (not created), AAB build
  job, hosted privacy-policy URL, support email, Google's $25
  one-time developer fee. Current builds are debug-signed APKs for
  sideloading only.

## What was NOT pushed

Nothing in this merge was pushed. The parent pushes + builds the APK.
