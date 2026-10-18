# MAIN-CORE FIX — Live + Upcoming + Scorecard + real data

User priority (2026-10-18): "Main app = Live + Upcoming + Scorecard +
real data, sab sahi se." Nothing else. Squad/H2H/Venue wiring stays
DEFERRED in `git stash@{0}` (NOT popped). No header/truncation/polish,
no Compare/Stats/Leagues/Favourites/Prediction changes.

## The bug (user screenshot)

Austria Women vs Sweden Women showed under the UPCOMING tab with
scores 124/9 + 37/3 and the equation "Austria Women need 88 runs in
78 balls", while the Live tab was empty. That screenshot was taken on
an older build whose Home filter did not use `isEffectivelyLive`, but
auditing the CURRENT code found FIVE remaining paths that can still
produce the same symptom. All five are fixed here, each with a
pre-fix-failing test.

## Root causes (file:line, pre-fix)

### R1 — `resolveStatus` let a stale label beat scores
`lib/services/providers/cricket_provider.dart` — the "not started /
scheduled / preview / upcoming" branch ran BEFORE the hasScores
check. A fixtures feed (`/v1/matches`) can carry a stale status
string ("Match scheduled") for a match whose score array already
shows runs → parsed as UPCOMING with scores on the board.

### R2 — `isEffectivelyLive` treated the toss as a result
`lib/models/match.dart:116` — bare `'won the'` counted as terminal.
CricAPI list entries carry the raw status text in `result`, so a live
match whose status read "X won the toss and elected to bat" was
classified NOT-live. Combined with R1, the match landed under
Upcoming with scores — the exact screenshot.

### R3 — merge richness counted placeholder score rows
`lib/services/api_service.dart` — richness used `scores.length`.
Backstops emit a 0/0 placeholder row for the side yet to bat, so a
backstop copy (1 real + 1 placeholder row) outranked the live copy
(1 real row). The placeholder copy then won the merge and took its
non-CricAPI id with it → `/cricketScore` with that id failed → the
match opened with no scorecard.

### R4 — backstops always passed `hasScores=false`
`lib/services/providers/sportscore_provider.dart` and
`thesportsdb_provider.dart` used `statusFromText`, which hard-codes
`hasScores: false`. A live backstop match with a non-keyword status
("1st Innings") parsed as upcoming; only `isEffectivelyLive` at
display time rescued it, while its `status` field stayed wrong for
the merge, the pill and the TTL.

### R5 — HTTP 429 never marked quota exhausted
`lib/services/providers/cricapi_provider.dart` — `_updateQuota` only
runs on parsed 200 envelopes. A 429 response skipped it, so
`quotaExhausted` stayed false, the Home quota banner never appeared,
and the app silently degraded to demo/backstop data.

## Fixes

1. **F1 — `resolveStatus`**: the hasScores → LIVE rule now runs
   BEFORE the not-started branch. A genuinely not-started match has
   an empty / all-zero score array, so it still resolves upcoming
   (pre-toss rain delay stays upcoming; toss-only + no scores stays
   upcoming).
2. **F2 — `isEffectivelyLive`**: terminal = result phrases only
   ('won by', 'won the match', 'match ended', 'match drawn', 'drawn',
   'no result', 'abandoned'), mirroring `resolveStatus`. 'Won the
   toss' is no longer terminal.
3. **F3 — merge richness**: counts only MEANINGFUL scores
   (`batted && (runs > 0 || wickets > 0 || overs > 0)`), plus a
   status tie-break (completed +10, effectively-live +5). A full
   scorecard still dominates via the innings term. Live copy now
   beats an upcoming copy with a placeholder row; completed beats
   live on equal scores.
4. **F4 — backstops**: SportScore + TheSportsDB compute hasScores
   from their parsed scores and pass it to `resolveStatus`.
5. **F5 — CricAPI `_get`**: HTTP 429 sets `_quotaError = true` and
   `_serverHitsLeft = 0`, so `quotaState` becomes
   `quotaExhausted`, the Home banner shows, and further CricAPI
   calls stop locally (no wasted hits).

## What was already correct (verified, not changed)

- **Home filter** uses `isEffectivelyLive` for Live and
  `status == upcoming && !isEffectivelyLive` for Upcoming; the match
  card pill also derives from `isEffectivelyLive`.
- **Scorecard auto-fetch**: `MatchDetailScreen.initState` calls
  `_refreshDetail(force: false)` → `fetchMatchDetail` →
  `fetchScorecard` with the SAME CricAPI id the list entry came
  from (CricAPI list id == scorecard id; verified by test with a
  mocked `/cricketScore`). Upcoming matches correctly keep
  "Scorecard not available yet" (no scorecard exists yet).
- **No mock when a provider answered**: `fetchMatches` returns
  merged provider data only when a provider answered; mock is used
  only when ALL providers fail (and then `lastSource == 'mock'` so
  the demo banner shows). `fetchUpcoming` returns `[]`, never mock.
- **Quota banner**: Home already renders distinct banners for
  `keyMissing`, `quotaExhausted`, and `lastFetchWasMock`. F5 makes
  the 429 path actually reach the `quotaExhausted` state.
- **Upcoming pagination** (Fix7): offset loop, unchanged.

## Verification

- `flutter analyze` → No issues found!
- `flutter test` → full suite green (85 passed, 9 skipped —
  the skipped tests are CricAPI tests that need a dummy key).
- `flutter test --dart-define=CRIC_API_KEY=test
  test/main_core_fix_test.dart` → 12/12 passed.
- `flutter build web --release` → ✓ Built.
- New tests (`test/main_core_fix_test.dart`, 12): stale-label +
  scores → LIVE; toss + scores → effectively live; real result
  still terminal; merge live-beats-placeholder; merge
  completed-beats-live; TheSportsDB + SportScore live parse;
  CricAPI `fetchUpcoming` excludes a stale-label live match;
  CricAPI `fetchScorecard` uses the list id and returns full
  innings; `ApiService.fetchMatchDetail` returns innings;
  CricAPI 429 → quotaExhausted + no second HTTP call;
  `ApiService.quotaState` → quotaExhausted after 429 with
  `lastFetchWasMock` true.

## Still deferred (NOT in this change)

- Squad / H2H / Venue / Matchups Cricsheet wiring — in
  `stash@{0}`, per user redirect ("fuddu wali chiz baad me").
- Header/truncation/small UI polish.
- Compare / Stats / Leagues / Favourites / Prediction.
- Residual risk: if a non-CricAPI copy ever genuinely has MORE
  meaningful scores than the CricAPI copy, it wins the merge and
  the scorecard fetch uses its id (CricAPI returns null for a
  foreign id). Ties now favour the CricAPI copy (first + equal
  richness), and the live copy's id is preserved in the common
  case; a cross-provider id map is future work, not needed for
  the reported bug.
- Live payload shapes from `api.cricapi.com` still cannot be
  inspected from this VM (host blocked); fixes are proven by
  mocked-payload tests, not by a live probe.
