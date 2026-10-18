# FIX-7 — All 7 audit fixes (2026-10-18)

User approved: "Han, saare 7 fix kar + naya APK bhej".
Implements the exact fix list from CRICAPI-TRUTH-AUDIT.md §7 +
DATA-TRUTH-AUDIT.md §7. No code from competitors, no scraping —
only the documented free APIs + Cricsheet open data.

## 1. Pagination — `cricapi_provider.dart` `fetchUpcoming` / `fetchSeries`

- `fetchUpcoming` now loops `offset = 0, 25, 50, …` (max 5 pages),
  stopping on a short page, on a page with zero NEW entries (server
  ignoring `offset` — would otherwise loop the same page forever),
  or on the cap. Overlap is deduped by match id.
- `fetchSeries` paginates the same way (max 3 pages).
- Cost guard: upcoming is cached 60 min by the orchestrator, so
  worst case ≈ 5 hits/hour. The old code fetched only `offset=0`
  page 1 — every fixture beyond page 1 was unreachable by
  construction (the "Upcoming half / only 24th" bug).
- Page size 25 is a step, not an assumption: the server's real page
  size is undocumented; overlapping pages are deduped, so a larger
  server page size only costs extra hits, never wrong data.

## 2. Key / quota runtime check — `QuotaState` in `api_service.dart`

- `ApiService.quotaState`: `keyMissing` (no keyed provider
  configured) / `quotaExhausted` (a provider reported server-side
  exhaustion) / `ok` (a provider reported remaining quota) /
  `unknown` (key present, no quota report yet).
- Home shows DISTINCT banners for key-missing vs quota-exhausted
  vs last-fetch-fell-back-to-demo — and the demo banner now shows
  whenever `lastFetchWasMock`, regardless of key presence.
- Warm-cache stale path fixed: when every provider fails and the
  stale cache is served, `lastSource` is now set to `'mock'`
  (previously untouched, so the banner never showed and stale
  data looked live).

## 3. Player identity — name → numeric id → `players_info`

- New `CricketProvider.resolvePlayerId(name)`. CricAPI implements
  it via `GET /v1/players?search=<name>` (1 hit) and returns an id
  ONLY when a returned entry's name actually matches — exact first,
  then contains. The `search` param is NOT confirmed in public v1
  docs; it is sent best-effort and the response is scanned, so a
  server that ignores `search` yields null, never a wrong player.
  A live probe with the real key should confirm the param; if the
  endpoint does not support it, resolution falls back to null and
  profiles resolve through Cricsheet instead.
- `CricApiProvider.fetchPlayer` now takes the NUMERIC id (names are
  resolved first, by the orchestrator or defensively inside the
  method). The old `_mock.playerById` hard-gate — null for every
  player outside 6 mock ids even when the API answered — is GONE.
- `players_info` `stats` is parsed tolerantly (`parseStats`, unit-
  tested for the row shape `{fn, matchtype, stat, value}` and the
  nested-map shape). Unknown shapes → identity-only profile with
  `dataComplete=false`, never invented numbers.
- `ApiService.fetchPlayer` resolves names (with a session id-cache)
  before calling providers. Cricsheet-first order unchanged.
- Match Detail: the scorecard-tap hard-block
  ("Profile not available" SnackBar, no fetch attempted) is GONE.
  Every tap routes through `_openPlayerByName` → `fetchPlayer`.
  Squad rows keep their "Tap for full profile" hint.

## 4. Cricsheet enriched — 4 synthetic matches → 420 real ones

- `assets/cricsheet_sample.json` (149 KB → ~25 MB): 420 REAL
  internationals, 2024-01 → 2026-10, from `all_json.zip`
  (142 MB zip / 4 GB extracted / 23,134 files — too large to bundle
  whole). Stratified: ≤25 full-member + ≤5 associate matches per
  month; 1,847 distinct players incl. V Kohli, RG Sharma, JJ Bumrah,
  Babar Azam, TM Head.
- The old 4-match sample was SYNTHETIC (invented fixtures); its
  hand-computed test expectations were replaced by dataset
  invariants in `cricsheet_test.dart`.
- UI label updates automatically via `sourceMatches` (420).
- Limit: numbers cover only appearances inside this subset — still
  not full careers. Full archive needs a server-side store.
  Parse cost: one-time lazy parse on first `fetchPlayer`; moving
  it to an isolate is a tracked follow-up.

## 5. Dedupe — league + provider-id aware (`mergeMatches`)

- Key is now (teams, day, format, league) + provider attribution:
  - Same fixture from 2 providers → merges (richer wins).
  - Two DISTINCT matches from ONE provider (same key, different
    non-empty provider ids — double-header, men+women, two series
    same day) → KEPT as two cards.
  - A provider reporting no league ('' / 'International' /
    'Cricket') folds into the same fixture reported WITH a league
    by a different provider.
  - Two buckets with different NON-EMPTY leagues stay separate.
- `mergeMatches` takes optional `providerNames` (parallel to the
  lists); the orchestrator passes them, Home's already-merged
  lists pass none.

## 6. No silent drops — logging everywhere

- Every provider fetch debug-logs `received / dropped / kept`
  (CricAPI per method; EliteSport / EntitySport / SportScore /
  TheSportsDB per fetch). `ApiService` logs contributing providers
  + merged count per fetch. Logs NEVER include keys or URLs with
  keys (method + counts only).

## 7. Quota honesty — server-side `hitsLeft`

- CricAPI parses every response's `info` block (`hitsLeft` /
  `hitsToday`) and quota-error messages. `quotaExhausted` is true
  when `hitsLeft == 0` or a quota error arrives; `_capped`
  includes it, so the provider stops calling instead of burning
  calls that can only return quota errors. In-memory `_hits`
  alone is no longer trusted.
- Other providers report `serverHitsLeft == null` /
  `quotaExhausted == false` (they do not expose server quota).

## Also: per-card source labels

- `CricketMatch.source` (new field, round-trips through JSON):
  providers tag their matches, mock tags `'demo'`.
- `KingMatchCard` shows a tiny `Source: CricAPI / SportScore /
  Demo / …` line. Demo can never masquerade as real again.

## Verification

- `flutter analyze` → **No issues found!**
- `flutter test` → **77/77 passed** (5 CricAPI tests skip without
  a key; they PASS with `--dart-define=CRIC_API_KEY=test` on the
  mocked HTTP layer — pagination 25+2, offset-ignored stop,
  quota stop, resolve + players_info).
- `flutter build web --release` → ✓ Built.
- New tests: `test/fix7_test.dart` (12 tests). Updated:
  `test/cricsheet_test.dart` (bundled-subset invariants),
  test fakes (new interface members).

## Remaining limits (honest, not fixed here)

- CricAPI `/v1/players?search=` param is best-effort / unverified
  — needs one live probe with the real key to confirm. If the
  server ignores it, name resolution returns null and profiles
  resolve through Cricsheet only.
- CricAPI page size / sort order still unverified — pagination
  handles any page size, but the exact count of fixtures per page
  needs a live probe.
- Cricsheet subset is 2024–2026 only; pre-2024 careers are not in
  the app. Full archive needs a server-side store.
- Cricsheet parse is still on the calling thread (isolate = follow-up).
- EliteSport / EntitySport keys still not supplied — those
  providers stay skipped until keys are added.
- The secret's VALUE (is the compiled-in key valid?) still cannot
  be checked from code — CricAPI dashboard `hitsToday` is the proof.
