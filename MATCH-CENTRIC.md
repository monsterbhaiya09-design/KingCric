# Match-Centric Redesign

User: "players ka alag se dikhane ki jagah only jo jo match hai usme
dikha and usme sara data dikha team ke sabhi players ka jo us squad
me hai and venue ka h2h ka sari chizo ka" — plus: live matches
missing, one live match showed no scorecard / no match data / no
players, Upcoming empty.

## Rule

**Home = matches ONLY. Players live ONLY inside their match.**
No separate Trending Players list anywhere on Home. (Stats tab still
browses all players — that is a stats screen, not a Home list.)

## What changed

### Home (`home_screen.dart`)
- REMOVED the Trending Players section entirely (FutureBuilder,
  `_playersFuture`, PlayerCard / PlayerProfile imports).
- Home now shows: header, search (matches only), Live / Upcoming /
  Finished tabs, format chips, Last updated + Refresh, match cards,
  Next-up when Live is empty.
- New hint line: "Players live inside each match — open a match,
  then Squad." (`home_players_hint`, EN + Hindi).

### Match Detail (`match_detail_screen.dart`) — 5 tabs now
Tabs: **Live | Scorecard | Squad | Venue & H2H | Prediction**.

#### Squad tab (rewritten)
Each team gets its own section (Team A / Team B) with a source line.
Squad resolution fallback chain — never blank, never fake:
1. **Official** squad ids on the match (`squadA` / `squadB`).
2. **Team** filter — any loaded player whose `team` == team name
   (this is what fires for provider matches that ship no squad ids).
3. **Scorecard** names — players named in this match's scorecard
   for that team, with `source: 'scorecard'` (stats not available,
   labelled so; tap shows "Profile not available yet").
4. **None** — honest "Squad not available yet" + Retry.

Each row is a new `SquadPlayerCard` carrying THIS match's context:
- Batting in THIS format (fallback: overall when no format stats)
- `vs {opponent}` mini-line (or "vs X: no data yet" — never fake)
- Bowling in THIS format (omitted for pure batters — never a fake
  "0 wkts" line)
- Recent form last 5 as compact chips (`82 (41) • W`, `45 (28) • 1w • L`)
- Source label: Real • Cricsheet / Demo / Partial / Scorecard only
- A player with NO stats at all shows "Stats not available for this
  player yet." — never a row of fake zeros.
- Tap opens the full profile (except scorecard-only names).

#### Venue & H2H tab (NEW)
- **Venue Stats**: name, city/country, pitch type, avg 1st/2nd
  innings score, matches at venue, bat-first win %, toss advice,
  plus match pitch report, weather ("Not available from free
  providers yet."), toss. If the venue is not in the loaded venue
  list: honest "Venue stats not available from free providers yet."
- **Team H2H**: `H2HCard` (moved here from the Live tab — no
  duplication) with wins, total, draws / no-results.
- **Top Player Matchups**: cross-squad bowler-vs-batter pairs only
  (bowler in one squad, batter in the other — same-team pairs like
  Virat vs Bumrah are NOT head-to-head), sorted by dismissals desc
  then balls desc, top 5. Each row: "Shaheen Afridi → Rohit Sharma:
  3 dismissals in 66 balls • 71 runs". Empty → honest "No
  bowler-vs-batter history in loaded data."
- Pure helper `topPlayerMatchups(squadA, squadB)` — unit-tested.

#### Scorecard tab
- Unchanged when innings exist (full card: batting / extras /
  bowling / FOW / partnerships / yet-to-bat).
- When innings are EMPTY: honest empty card — "Scorecard not
  available yet." + why (not started / provider sent none) + Last
  updated + **Retry** button (re-fetches via
  `fetchMatchDetail(..., forceRefresh: true)`; on failure the last
  verified copy stays + SnackBar). Never a blank tab.

#### Prediction tab
- Predictions now use the SAME resolved squads as the Squad tab
  (scorecard fallback included) — never empty when Squad has players.
- **hasData guard**: players with no signal get an honest
  "Not enough data to predict." row, never a fake ~50 score card.
- Scorecard-only names are excluded from predictions (no profile,
  no signal).

#### Live tab
- H2HCard removed (lives in Venue & H2H now). Everything else kept:
  hero score, equation, OverGraph, Preview & Info, commentary.

### New widget
- `lib/widgets/squad_player_card.dart` — `SquadPlayerCard` (see above).

### Strings (EN + Hindi)
New keys: `home_players_hint`, `venue_h2h`, `venue_stats`,
`toss_impact`, `player_matchups`, `scorecard_empty`, `retry`,
`squad_source_official`, `squad_source_team`,
`squad_source_scorecard`, `no_squad_data`, `venue_no_data`,
`no_matchups_data`, `not_enough_data`.
`trending_players` / `no_trending` keys are KEPT (Stats screen +
existing tests use them) — Home just no longer renders them.

## Why the reported bugs happened
- **Live match with no scorecard / no players**: provider matches
  often ship no innings and no squad ids. The old Squad tab only
  matched official squad ids → empty; the old Scorecard tab showed
  one bare line. Now: squad falls back to team filter → scorecard
  names; scorecard shows an honest empty state + Retry.
- **Upcoming empty**: provider "current matches" endpoints return
  live/recent only. (A parallel fix adds `fetchUpcoming()` fixtures
  merging — see MATCH-DATA-FIX.md; this redesign does not depend
  on it.)
- **Players shown separately**: Home Trending Players is removed.

## Verification
- `flutter analyze` → No issues found!
- `flutter test test/match_centric_test.dart` → 8/8 passed
  (SquadPlayerCard context + no-fake-zeros, cross-squad matchup
  filter, new strings EN+HI, empty-scorecard Retry, squad
  team-fallback, Venue & H2H tab).
- Full suite + `flutter build web --release` → see commit message
  for the numbers on this tree.

## Honest limits (unchanged)
- Free providers still ship no per-ball feed, no weather, no
  fantasy points, no ICC rankings — none are faked.
- Squad fallback "team filter" shows loaded players of that team,
  which may not equal the official XI — the source line says so.
