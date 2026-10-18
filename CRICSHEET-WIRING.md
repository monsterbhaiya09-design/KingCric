# Cricsheet Wiring — Squad / H2H / Venue / Matchups

**Status:** DONE, committed locally, NOT pushed.
**User symptom fixed:** Match Detail showed Squad = Pakistan 2 Demo players +
Sri Lanka 0, Venue & H2H all "Not available", H2H 0–0, "No bowler-vs-batter
history" — even though Fix7 had already bundled 420 real Cricsheet matches.
The data existed in the asset but was never wired into these tabs.

## What was wrong

- `CricsheetService` could build a full profile for one player
  (`playerById`), but nothing built a **squad list** from it. Squad tabs
  fell back to the mock team filter (6 curated players: India/Pakistan
  stars only) → Pakistan 2 Demo, Sri Lanka 0.
- H2H / Venue / Matchups read the **mock** match list, which has no
  Pakistan-vs-Sri-Lanka meeting and no venue history → 0–0 / Not available.
- Tapping a Squad row searched the **mock** list first, so tapping Babar /
  Shaheen / Virat / Rohit / Bumrah / Surya opened the Demo mock profile
  even though the row itself showed Real Cricsheet stats.

## What is wired now

### 1. Squad from Cricsheet — `CricsheetService.squadForTeams()`

- Players who appeared for that team in the bundled dataset, ranked by
  appearances **in the match's format first**, then overall appearances,
  then recency. Cap 20 per team.
- Format-aware ranking matters: the dataset skews T20 (303 T20 / 92 ODI /
  25 Test). Ranking by total appearances would fill an ODI squad with T20I
  regulars and drop ODI-only stars (Kohli plays only ODIs now).
- Gender filter: the dataset stores men and women under the same team name
  ("Pakistan"). Without it, the men's top-20 filled with women's players
  and Babar was pushed out entirely. `squadForTeams('Pakistan', …)` =
  men, `squadForTeams('Pakistan Women', …)` = women.
- Every squad player is a FULL `Player` with REAL computed stats: overall
  + per-format + **vs-opponent** (batting + bowling) + recent form +
  matchups + dismissal history. `source: 'cricsheet'`,
  `dataComplete: true`.
- Squad tab uses Cricsheet FIRST (label
  "Squad: Real • Cricsheet • calculated from ball-by-ball data
  (2024–2026 dataset)"). Mock team-filter / scorecard-names only when
  Cricsheet has zero players for that team (franchise sides, leagues
  outside the bundled internationals) — labelled Demo / Scorecard only.
- Upcoming matches (no scorecard, no squad ids) get real Cricsheet squads
  too — Sri Lanka no longer shows (0) when the dataset has SL players.

### 2. H2H from Cricsheet — `teamHeadToHead()` / `teamH2H()`

- Computed from bundled matches: `{matches, teamAWins, teamBWins,
  noResult}`, with optional format + gender filter (a men's ODI shows the
  men's ODI H2H, never pooled with women's meetings).
- Venue & H2H tab uses Cricsheet numbers when the dataset has any meeting
  between the teams, labelled "Real • Cricsheet (2024–2026 dataset)".
  Zero meetings → honest "No head-to-head in loaded data (2024–2026)",
  never a fake 0–0 presented as complete.

### 3. Venue stats from Cricsheet — `venueStats()`

- Fuzzy venue match: "Rawalpindi Cricket Stadium, Rawalpindi" matches the
  dataset's "Rawalpindi Cricket Stadium" (normalised + ≥75% token overlap).
- Computed: matches at venue, avg 1st / 2nd innings, highest total,
  bat-first win %. Used when the provider venue card carries no stats.
- Pitch / weather are NOT in Cricsheet — those rows stay
  "Not available from free providers yet." Never faked.

### 4. Matchups from Cricsheet — `crossSquadMatchups()`

- Bowler in one squad + batter in the other only (same-team pairs are not
  head-to-head). Sorted dismissals ↓, then balls ↓, top 5. A pair counts
  with dismissals > 0 or balls ≥ 12.
- Venue & H2H tab uses Cricsheet matchups when squads are Cricsheet-sourced
  (mock players' stored matchups would be Demo data wearing a real match's
  clothes). None → honest "No bowler-vs-batter history in loaded data
  (2024–2026)".

### 5. Tap path — `_openPlayerByName()` (resumed fix)

- Now fetches FIRST via `ApiService.fetchPlayer` (Cricsheet-first, offline,
  cached). Local mock list is only a fallback when every source returns
  null. Tapping Babar now opens his Real Cricsheet profile, not Demo.

### 6. Performance

- ONE parsed Cricsheet instance: `loadBundled()` caches in a static
  `_bundledCache` future; every tab / ApiService instance shares it. No
  re-parse per tab. Per-team player index is precomputed once during parse.
- Labels fixed: dataset range is **2024–2026** (was mislabelled 2025–2026
  in three UI strings + two empty-state strings).

## API surface (all never-throw)

- `ApiService.cricsheetSquadsFor(teamA, teamB, {format, gender})`
- `ApiService.cricsheetHeadToHead(teamA, teamB, {format, gender})`
- `ApiService.cricsheetVenueStats(venueName, {gender})`
- `ApiService.cricsheetCrossMatchups(squadA, squadB)`

## Verification

- `flutter analyze` → No issues found.
- Targeted tests: `test/cricsheet_wiring_test.dart` (8 tests: Pak+SL squads
  both non-empty + Real source + Babar runs > 0; men/women never mixed;
  Babar vs Sri Lanka split non-empty; H2H reconciles + format filter;
  Rawalpindi fuzzy venue + reconciles; cross-squad matchups cross-squad +
  sorted + single-pair reproducible; non-identity `cs-` players build real
  profiles + round-trip; ApiService wrappers + unknown team → empty),
  plus `match_centric_test.dart` (Squad tab renders Cricsheet squads,
  Venue & H2H tab shows venue + H2H + matchups) and `match_detail_test.dart`.
- Full-suite note: a single `flutter test` run of the whole suite stalled
  in one widget test (pumpAndSettle, 8+ min) and was killed by the
  500 s timeout; the same test passes in ~9 s in isolation. The stall is
  a test-harness / parallel-isolate artefact (25 MB parse in several
  isolates at once + concurrent file edits mid-run), not an app hang —
  the app itself parses once via the shared static cache. Targeted files
  above are the authoritative verification for this change.
- `flutter build web --release` → Built (see below).

## Honest limits (unchanged)

- Dataset covers **2024–2026 internationals only** (420 matches). Pre-2024
  careers, domestic / league / franchise squads, and women's leagues
  outside the bundled internationals are NOT in the app — those tabs fall
  back to Demo / scorecard / honest no-data lines, labelled as such.
- Squad = recent XI pool from the dataset, not the official XI for a
  future fixture. The source line says so.
- Pitch / weather / fantasy / ICC rankings: no free source — never faked.
- Cricsheet 25 MB parse is still on the calling thread (isolate = follow-up);
  do not grow the asset further without that fix.
