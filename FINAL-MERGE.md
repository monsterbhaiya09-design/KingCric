# FINAL MERGE — 5 final squads + merge gaps

Merge of the final builder squads on top of the 8-squad merge
(`51ed3e4`). Committed locally only — NOT pushed.

## Squads merged (all verified present)

- **Final V** `c5c29dc` — visual live: BallStrip, MilestoneTracker,
  OverTimeline widgets + Live-tab wiring.
- **Final P** `679ff07` — premium polish + designed empty states.
- **Final S** `6ad75ae` — profile split (Stats first, About second)
  + section honesty in H2H / prediction / squad cards.
- **Final D** `f3d58b6` — data depth: `ApiService.fetchBallData`
  (CricAPI live ball events, else Cricsheet bundled match, else
  empty), Cricsheet depth helpers.
- **Final R** `67666b1` — Play Store readiness: `build-aab.yml`,
  `FINAL-RELEASE.md`, privacy-policy HTML, release checklist.

## Merge gaps applied

### (a) Visual widgets wired to fetchBallData

`match_detail_screen.dart` now fetches ball data lazily
(`_ballDataFutureCached`, never in `initState`) and the Live tab
renders through `_visualLiveSection()`:

- Ball strip tokens come from `MatchBallData.balls` ONLY when
  `hasBallData` is true, with a source label
  (`Ball data: <source> • <matchDate>`).
- Per-over runs reach `OverTimeline` via the new
  `overRunsByInnings` map (keyed by scorecard position), so runs
  can never leak from one innings' card onto another. The legacy
  single-list `overRuns` still works.
- When `hasBallData` is false, the widgets' honest no-data states
  render. The single `lastBall` token is NOT dressed up as a
  strip anymore — it keeps its own "Last ball" chip in the header.
- Upcoming matches never trigger a fetch (no balls exist yet).
- The waiting branch is a static text line on purpose: an
  animating spinner there broke `pumpAndSettle` in the Squad G
  scorecard test while the (slow, 25 MB) ball load ran.

### (b) Scorecard sections hide-when-empty

FOW / partnerships / yet-to-bat already shrank when empty.
Batting, bowling, and extras now do too, both in the
`_scorecardTab` composition (spacers guarded so no dangling
gaps) and inside `_battingTable` / `_bowlingTable` / `_extrasRow`
(defence in depth). Extras hides when `extrasRuns <= 0` AND
`extrasText` is empty — never an "Extras: 0" row.
Squad S's cards were confirmed compliant and untouched:
H2H total 0 shows "—" / "No matches yet", prediction guards
`hasData` AND NaN/Inf, squad cards label format-vs-overall
honestly.

### (c) Proper release signing wiring

`android/app/build.gradle.kts` now reads `key.properties` when
it exists and creates a `release` signingConfig from its four
keys (`storeFile`, `storePassword`, `keyAlias`, `keyPassword`);
otherwise the release build falls back to the debug config,
exactly as before. Verified:

- The AAB workflow writes exactly those four keys into
  `android/key.properties` (runner-only, gitignored), so the
  wiring matches.
- The AAB workflow's CI-time patch step checks
  `"key.properties" in text` and skips itself — with this wiring
  in the repo file, the patch can never double-apply.
- The APK workflow never writes `key.properties`, so its
  debug-signed output is unchanged.

### (d) Test-contract note

`match_data_fix_test`'s CricAPI `fetchUpcoming` test assumes NO
key compiled in, so the full suite was run WITHOUT
`--dart-define` (plain `flutter test`), as required. The test
was not changed.

## Fixes found during verification (not in any squad brief)

1. **Spinner/pumpAndSettle hang** (above, gap a): the Squad G
   scorecard test timed out on `pumpAndSettle` after the Live
   tab gained its ball-data FutureBuilder. Replaced the waiting
   spinner with static text; the test passes.
2. **Stale profile tests vs Squad S's redesign**: three tests
   asserted the OLD source-line location/text (hero area,
   "Real • Cricsheet open data • 4 matches in dataset"). Squad
   S intentionally moved the source line to the About section
   and reworded it ("Real • Cricsheet • 420 matches • N for
   this player"). Updated the three tests to scroll to About
   and expect the new text — app behaviour unchanged, S's own
   profile tests already assert the new design.
3. **Lint clean-up**: `prefer_const_constructors` in
   `squad_v_visual_test.dart` (fixed via `dart fix`) and
   `prefer_const_literals_to_create_immutables` in the new
   `final_merge_test.dart` (fixed via `dart fix`).

## Verification (quiet tree)

- `flutter analyze` → **No issues found!**
- `flutter test` (FULL suite, no `--dart-define`) →
  **225 passed, 25 skipped, 0 failed** (skips = key-gated
  CricAPI tests, as before). First full run surfaced the 4
  failures above; after fixes, the suite passes with no stall
  (~43s) and no retry needed.
- `flutter build web --release` → **✓ Built build/web**
- New regression tests: `test/final_merge_test.dart` (3/3) —
  per-innings over runs do not leak across cards, empty innings
  renders nothing, legacy `overRuns` still works.

## Remaining limits (not claimed fixed)

- **True ball-by-ball needs a provider feed.** Free providers
  return scorecard totals, not a per-ball feed; CricAPI ball
  events appear only when the payload actually carries them.
  Otherwise the strip comes from the Cricsheet bundled match
  (finished 2024–2026 matches only) or shows the honest
  no-data state. Nothing is synthesised.
- **AAB job never run on the runner yet.** The workflow exists
  and the signing wiring is in place, but it needs the four
  release-signing secrets to run.
- **Play Store listing still needs**: $25 Google developer fee,
  release keystore secrets, a monitored support email, and a
  hosted privacy-policy URL (HTML is written, hosting is not).
- Cricsheet subset is 2024–2026 only; the 25 MB parse still
  runs on the calling thread (isolate = follow-up).
- CricAPI `/v1/players?search=` still unverified (needs a live
  probe with a real key); EliteSport/EntitySport keys not
  supplied; live payload shapes still can't be inspected from
  this VM (host blocked).
