# KingCric DATA-TRUTH AUDIT (2026-10-18)

Diagnosis only. No code changed, nothing pushed, nothing rebuilt.
User symptoms on latest APK: (1) no real data, (2) Upcoming = half
matches, only 24th-date fixtures, rest missing, (3) Live = 1 match,
(4) no player data at all.

## 0. Method limits (read this first)

- All findings are from code in `~/workspace/cricket-app/kingcric/lib/`.
- The LIVE payloads (what CricAPI / TheSportsDB / SportScore return
  RIGHT NOW) could NOT be inspected: `api.cricapi.com` is unreachable
  from this VM (network blocked, established earlier). So where a
  symptom depends on the live payload (e.g. exactly which dates
  CricAPI page 1 holds), this audit identifies the code ceiling that
  makes the symptom POSSIBLE/INEVITABLE and says so explicitly — it
  does not guess the payload.
- No `.take()` / `.sublist()` / hard-coded N / hard-coded date
  truncation exists on any match list in `lib/` (grep clean).
  The truncation is STRUCTURAL: single-page fetches + provider
  ceilings + dedupe collisions. Details below.

## 1. Where the lists come from (the whole pipeline)

```
Home._load()
  ├─ ApiService.fetchMatches()      → 10-min cache
  │    └─ asks EVERY configured provider, mergeMatches(collected)
  │       ├─ CricAPI  /v1/currentMatches        (live + recent)
  │       ├─ EliteSport /matches/live → /fixtures fallback
  │       ├─ EntitySport (fetchMatches)
  │       ├─ SportScore candidate paths: cricket/matches,
  │       │   cricket/live, matches?sport=cricket (first parseable win)
  │       └─ TheSportsDB livescore.php?s=Cricket → FALLBACK
  │           searchevents.php?e=Cricket (generic keyword search!)
  └─ ApiService.fetchUpcoming()     → 60-min cache
       └─ asks every provider with fetchUpcoming(), mergeMatches
          ├─ CricAPI  /v1/matches?offset=0   ← SINGLE PAGE, NO PAGING
          ├─ EliteSport /fixtures
          ├─ TheSportsDB searchevents.php?e=Cricket
          └─ SportScore / EntitySport → null (no fixtures endpoint)
Home merges: mergeMatches([liveList, upcomingList])
Home._visible filters by tab (see §2), sorts, renders KingMatchCard.
Match card shows: "Starts: {day} {Mon}, {time}" from startTime
  (lib/widgets/match_card.dart:34-39) — this is the "24 ki date"
  the user sees: a day number straight from the provider payload.
```

Effective live-data sources in the shipped build: in practice
CricAPI alone. Only `CRIC_API_KEY` is confirmed present as a repo
secret; EliteSport / EntitySport keys were never confirmed, and
their base URLs are explicitly UNVERIFIED in code comments
(`constants.dart`: "VERIFY the base URL… A wrong host only makes
this provider return null"). SportScore's candidate widget paths
are guesses ("tries the documented candidate paths and returns
null when none answers"). TheSportsDB uses the public test key
`123` and a generic keyword search, not a fixtures/live feed.

## 2. (a) Filter / dedupe / limit code that can hide matches

### 2.1 Dedupe key — COLLAPSES distinct matches (api_service.dart ~277-305)

```dart
static String _fixtureKey(CricketMatch m) {
  String norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  final teams = [norm(m.teamA), norm(m.teamB)]..sort();
  final day = '${m.startTime.year}-${m.startTime.month}-${m.startTime.day}';
  return '${teams[0]}-vs-${teams[1]}@$day';
}
```

`mergeMatches()` keeps ONE entry per key; on collision the
"richer" entry wins (innings×100 + scores×10 + squad + live).

Consequences, proven from code:
- **Same teams + same calendar day + DIFFERENT match = one match
  deleted.** Double-headers, men's + women's fixtures the same
  day, two formats the same day, two leagues the same day,
  same-teams fixtures in two series the same day — all collapse
  to ONE card. This is a real "half matches missing" mechanism.
- **Same fixture reported with different parsed startTime is NOT
  deduped** (timezone/format differences, or one provider's
  fallback `DateTime.now()`), so the same fixture can ALSO appear
  twice. Dedupe is wrong in both directions.
- **Richer-wins can pick the WRONG entry.** A TheSportsDB stub
  (format forced `'T20'`, see §2.3) can beat a CricAPI entry on
  richness if it carries scores, and the merged card then carries
  the stub's format/status/id — and the scorecard fetch is keyed
  by that id.

### 2.2 Upcoming is a SINGLE PAGE — no pagination (cricapi_provider.dart)

```dart
Future<List<CricketMatch>?> fetchUpcoming() async {
  ... Uri.parse('.../v1/matches?apikey=...&offset=0');  // offset=0 ONLY
```

- There is NO pagination loop, NO `offset` increment, NO
  date-range parameter anywhere in `lib/`. Whatever page 1 of
  CricAPI `/v1/matches` contains is the absolute ceiling for
  CricAPI upcoming fixtures.
- If page 1 is a date-windowed / date-sorted page (e.g. dominated
  by 24 Oct fixtures), every fixture outside that page is
  UNREACHABLE — no amount of refresh, scrolling, or merging can
  ever show it. This is the top suspect for "Upcoming = half
  matches, only 24th date, rest gone". The live payload cannot be
  checked from this VM, so this is stated as the code ceiling,
  not a confirmed payload fact.
- TheSportsDB upcoming is worse: `searchevents.php?e=Cricket` is
  a GENERIC KEYWORD SEARCH, not a fixtures endpoint. It returns
  whatever the free search returns for "Cricket" (capped,
  unsorted, possibly one league/date heavy). It is not a
  fixtures feed and cannot be trusted for completeness.
- `fetchUpcoming()` returns `[]` (never mock) when no provider
  has fixtures — so in live mode there is no mock safety net
  for Upcoming at all.

### 2.3 Status misclassification moves matches between tabs

Home filter (`home_screen.dart`, `_visible`):
- Live tab: `m.isEffectivelyLive`
- Upcoming tab: `m.status == upcoming && !m.isEffectivelyLive`
- Finished tab: `m.isCompleted`

`isEffectivelyLive` (`models/match.dart`): status==upcoming + ANY
score with `batted && (runs > 0 || wickets > 0)` → LIVE.

`ProviderParsing.statusFromText` is ALWAYS called with
`hasScores: false` (`cricket_provider.dart:76`), and
`resolveStatus` has NO keywords for TheSportsDB-style statuses
like `"FT"`, `"NS"`, `"AET"`, `"Match Ended"`. So:
- A TheSportsDB FINISHED event (`strStatus: "FT"`) with scores
  parses as `status == upcoming`, then `isEffectivelyLive == true`
  → it lands in the LIVE tab (wrong) and VANISHES from Upcoming /
  Finished. Same for any provider that reports scores on a
  not-yet-classified match.
- TheSportsDB `_matchFromEvent` also forces `format: 'T20'` for
  every event and sets `batted: score > 0`, and its date fallback
  is `DateTime.now()` when `dateEvent` is empty/unparseable —
  such an event gets startTime = TODAY and can collide in the
  dedupe key with a real today-fixture.
- Conversely, CricAPI `/matches` entries whose status text is
  empty/unknown and have no scores → `upcoming` (correct), but
  any entry whose `matchStarted` is true with no scores yet is
  `live` — a pre-toss "started" fixture can sit in Live with no
  scorecard.

Net: the tab counts the user sees are NOT a trustworthy count of
what providers returned; classification alone can move matches
between tabs.

### 2.4 No list truncation by count — confirmed

Grep for `.take(`, `.sublist`, `limit`, `first N` in `lib/` finds
only: `cricsheet_service` (top-6 helper), leagues top-3, matchup
top-5, recent-form last-5, premium widget top-2. NONE truncates
the match lists. There is no hard-coded date (`2024`/`2025` /
`2026-10`) filter in `lib/`. "Only 24th" is NOT a date filter in
code — it is the payload window (§2.2) + dedupe (§2.1) + the card
rendering the provider's own startTime day (§1).

## 3. (b) Squad code path for a REAL match — what the user actually sees

### 3.1 CricAPI never supplies squads

`CricApiProvider._matchFromFreeApi` NEVER sets `squadA` /
`squadB`. Every real CricAPI match has `squadA == []`,
`squadB == []`. `_mergeDetail` preserves the (empty) list-entry
squads. No provider in the tree returns a squad list for a
match. There is no squad endpoint wired anywhere.

### 3.2 `_resolveSquad` fallback chain (match_detail_screen.dart ~243-284)

For each team, in order:
1. **Official ids** (`match.squadA/squadB`) → ALWAYS EMPTY for
   real matches (see §3.1). Never fires.
2. **Team filter**: any player in `all` with `p.team == teamName`.
   `all` comes from `ApiService().fetchPlayers()` — which is
   **MOCK ONLY** (see §3.3): exactly 6 players
   (Kohli/Rohit/Bumrah/Surya → team `India`; Babar/Shaheen →
   team `Pakistan`). So this step fires ONLY for India/Pakistan
   fixtures, and returns DEMO players with curated demo career
   stats labelled `Demo`.
3. **Scorecard names**: names from `_match.innings` for that team
   → `Player(id: 'scorecard-<name>', source: 'scorecard')` with
   ZERO stats. Fires ONLY if innings exist, i.e. only if the
   auto-fetch scorecard succeeded. For UPCOMING matches there is
   no scorecard → innings empty → this step yields NOTHING.
4. **None** → "Squad not available yet for this team."

### 3.3 What the user actually sees, per match type

| Match | Squad tab shows |
|---|---|
| Upcoming, any teams | NOTHING per team: "Squad not available yet for this team." + "Squad data will appear once the free API returns squads for this match." + Retry. No players, no data. |
| Live, scorecard fetched, non-India/Pak teams | Name-only rows: name + "Scorecard only" chip + "Stats not available for this player yet." Tap → SnackBar "Profile not available for X yet." No stats of any kind. |
| Live, India vs Pakistan | The 6 MOCK players with DEMO career stats (labelled `Demo`). Not the real XI, not real stats. |
| Any match, tap a scorecard-only row | SnackBar, no profile. |
| Any match, tap a mock row | Profile screen built from the same mock player (see §3.4). |

This is exactly the user's symptom "player ka koi data hi nahi":
for most real matches the Squad tab is empty or name-only, and
for India/Pakistan it is demo data. There is no path in the Squad
tab that fetches real per-player data.

### 3.4 The Cricsheet path is NOT wired into Squad/Profile

- `ApiService.fetchPlayer()` tries Cricsheet FIRST (real
  calculated stats) — but NOTHING in the Squad → Profile path
  calls it. `MatchDetailScreen._playersFuture`,
  `PlayerProfileScreen` (line 376), and `StatsScreen` all call
  `fetchPlayers()`, which is hard-coded to `return _mock.players()`
  ("No free tier offers a bulk player endpoint"). The
  Cricsheet-backed `fetchPlayer` is effectively dead code for
  the screens the user touches.
- Cricsheet sample itself is 4 matches / ~36 named players; even
  if wired in, it cannot cover a real squad.

## 4. (c) Can mock/demo masquerade as real? — YES, in two ways

1. **Match cards carry no source label.** The Home demo banner
   (`mock_mode`) shows ONLY when NO key is compiled in
   (`!_api.isLive`). In the shipped build a key IS compiled in,
   so the banner never shows — even when the list on screen IS
   the mock list (see §5). The only signal then is the quota
   banner (§5), which has a hole. A mock India–Pakistan "live"
   card looks pixel-identical to a real live card.
2. **Mock players in a real match's Squad tab** (§3.2 step 2)
   show demo career numbers (e.g. Kohli 27150 runs) with only a
   small `Demo` chip. The numbers are curated, not real, and
   they sit inside a REAL match's Squad tab — the most
   masquerade-prone surface in the app. A user scanning stats
   will read them as the app's data, and a user who notices the
   `Demo` chip correctly concludes "real data nahi hai".

Honest labels that DO work: `SquadPlayerCard` source chips
(`Real • Cricsheet` / `Demo` / `Partial` / `Scorecard only`),
and the scorecard "not available" states. The failure is not
labelling on cards — it is that the REAL path is empty so the
only populated path is demo/name-only.

## 5. Quota / fallback hole (why "Live = 1 match" can be DEMO)

- CricAPI free tier: 100 hits/day; code self-cap 90.
  Per cold launch: `fetchMatches` (1 hit) + `fetchUpcoming`
  (1 hit) + 1 hit per match-detail open. `AutoUpdateService`
  ticks `fetchMatches` every 10 min while the app is open.
  Quota CAN die mid-day with normal use.
- When ALL providers fail/empty:
  - If a warm cache exists, `_fetchMatchesUncached` returns the
    STALE CACHE **without setting `lastSource = 'mock'`** —
    so the quota banner does NOT show, and the user keeps
    seeing stale data labelled as if live.
  - If no cache exists, `lastSource = 'mock'` and the mock list
    (3 matches: 1 fake-live India–Pak, 1 completed, 1 upcoming)
    is returned — the user sees "Live = 1 match" that is DEMO,
    with only the small quota banner ("Live data unavailable…
    Daily API quota may be exhausted") as the signal.
- The quota banner condition in Home is
  `_api.isLive && _api.lastFetchWasMock && !_loading` — it does
  not cover the warm-cache-stale path above, and it does not
  survive a rebuild after a later successful-but-partial fetch.

## 6. (d) Ranked root causes for the user's 4 symptoms

### Symptom 1 — "Real data nahi hai"
1. **Squad/Profile never fetch real player data.** Only
   `fetchPlayers()` (mock-only) feeds Squad, Profile lookup,
   and Stats. `fetchPlayer` (Cricsheet-first) is unwired.
   CricAPI `fetchPlayer` itself returns mock-based deep stats
   with `dataComplete: false` (identity only from the API).
   → No screen can show real per-player career/vs-opponent/
   venue stats for a real match.
2. **Mock masquerade** (§4): demo players/numbers inside real
   matches, no per-card source label on match cards.
3. **Free-provider ceiling**: no squad endpoint, no per-player
   career endpoint, no H2H endpoint in any wired provider.
   Anything beyond live score + scorecard names + a 4-match
   Cricsheet sample does not exist in the app today.

### Symptom 2 — "Upcoming me adhe matches, sirf 24 ki date, baaki kahan gaye"
1. **CricAPI `/v1/matches?offset=0` single page, no pagination,
   no date range** (§2.2). Fixtures beyond page 1 are
   unreachable by construction. Top suspect for the missing half
   + single-date window.
2. **Dedupe collision** (§2.1): same teams + same day +
   different match → one card deleted. Hits tournament days
   hardest (exactly when many fixtures share teams/dates).
3. **TheSportsDB upcoming is a keyword search**, not fixtures —
   capped/unsorted, cannot fill the gaps.
4. **Status leakage** (§2.3): finished/upcoming TheSportsDB
   events with scores get pulled into the Live tab, thinning
   Upcoming further.
5. NOT a cause: no count limit, no date filter in code (§2.4).

### Symptom 3 — "Live me ek hi match"
1. **Effective live source = CricAPI `currentMatches` only**
   (§1). Merge cannot invent matches other providers did not
   return. If CricAPI returns 1 live match, the app shows 1.
2. **Quota-exhausted → mock fallback** (§5): the 3-match mock
   list has exactly 1 fake-live match. If the user opened the
   app after quota death, "Live = 1" is the DEMO match.
3. **Warm-cache stale path** (§5): quota death mid-session
   keeps showing the last cached list with no banner.

### Symptom 4 — "Player ka koi data hi nahi"
1. **No squad endpoint; CricAPI squads always empty** (§3.1).
2. **Upcoming matches: Squad tab is EMPTY by construction**
   (no scorecard → step 3 cannot fire; steps 1–2 empty for
   non-India/Pak teams) (§3.2).
3. **Live matches: scorecard names only, zero stats** — the
   `Scorecard only` rows + "Stats not available for this
   player yet." + tap → SnackBar, no profile (§3.2–3.3).
4. **India/Pakistan exception shows DEMO, not real** (§3.2
   step 2) — reads as "no real data", correctly.

## 7. What would actually fix it (diagnosis only — NOT implemented)

1. **Upcoming completeness**: paginate CricAPI `/v1/matches`
   (offset loop until empty/short page), add date-range
   windowing, and treat TheSportsDB search as a backstop only.
   Until then, Upcoming can never be complete.
2. **Dedupe key must include a match discriminator** (provider
   id per provider, or start-time + league + venue + format),
   not just teams+day — or dedupe only WITHIN one provider,
   never across providers with different id schemes.
3. **Status**: pass real `hasScores` into `statusFromText`;
   recognise `FT`/`Match Ended`/etc. as completed; never let a
   finished event with scores become "upcoming".
4. **Player data**: wire `fetchPlayer` (Cricsheet-first) into
   Squad rows / Profile open (lazy per-player enrichment),
   and get a REAL squad source — none of the current free
   providers supply squads, so without a new source (or the
   full Cricsheet dataset refresh) real squad stats are
   structurally unavailable. Do NOT fake them.
5. **Fallback honesty**: set `lastFetchWasMock` on the
   warm-cache-stale path too; add a per-card source label
   (CricAPI / Demo) on match cards; never render mock players
   inside a real match's Squad tab without a prominent
   "Demo players — real squad not available" header.
6. **Quota**: surface remaining-hits / quota state in UI;
   the current silent-degrade-to-demo is what makes every
   data symptom look like "app is broken" instead of
   "quota exhausted".
