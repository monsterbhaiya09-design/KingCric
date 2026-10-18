# KingCric — PLAYER DATA: How Reference Apps Extract It & How They Arrange It

**User instruction:** "yeh log kaise data nikalte hai players ka and kaise arrange karte hai sab kuch samajhna"
— understand how reference apps extract players' data and how they arrange everything.

**Method (honest):** Public sources only — Play Store listings, official docs
(ESPNcricinfo/Statsguru, Cricsheet, EntitySport, Roanuz, Sportradar, CricViz
interviews), public reviews, plus KingCric's own docs (CRICSHEET-DATA.md,
API-SETUP.md, MULTI-API.md, REQUIREMENTS-MAPPING.md, REFERENCE-SPEC.md,
REFERENCE-APPS-DEEP-DIVE.md, CRICKETLINEX-REFERENCE.md).
**Did NOT:** download/install/run/decompile any reference APK, copy any code /
text / images / branding / data, or scrape any private API. Details that could
not be verified from public text are marked `[inferred]` — treat as hypothesis,
not fact. A hands-on device session must amend this doc where real screens differ.

**Legal rule (user-decided, honoured throughout):** NO scraping of Cricbuzz /
Cricinfo / Cricmetrics. KingCric uses only legal sources: official free APIs
(CricAPI, EliteSport, EntitySport API, SportScore, TheSportsDB) + Cricsheet
open data calculated by KingCric itself.

---

## 1. SOURCES — Where does player data come from?

### 1.1 The industry pipeline (how the big apps get data)

There is no single "cricket database". Every serious app sits on top of a
**layered pipeline**. The clearest public description is CricViz's "four-storey
stack" (CricViz / Opta analyst Phil Oliver, via Marcellus interview):

| Layer | What it is | Who provides it | What it adds |
|---|---|---|---|
| 1. Scorecards | Complete scorecards: runs, wickets, catches, results, every documented match since Tests began (19th century) | Scorecard archives: ESPNcricinfo / Statsguru (Travis Basevi, built 2000 from scripts over scorecards), Cricket Archive (900k+ scorecards, 1.6M+ players), boards | Match + innings totals. No ball detail. |
| 2. Ball-by-ball | What happened on *each ball*: batter, bowler, runs, wicket kind, fielder | Ball-by-ball archives: Charles Davis's scorebook-to-digital archive (CricViz licensed it), Cricsheet open data (post-2000, JSON v1.3.0), on-ground scorers logging each delivery | Per-ball events → per-innings → per-match aggregation. This is where averages, SR, matchup, dismissal history come from. |
| 3. Coded events | Fielding positions, shot played, ball type (length/line/pace/spin) | Opta coded feeds (analysts tag each ball), Sportradar / EntitySport / Roanuz feeds | Shot maps, wagon wheels, length/line analysis, "balls in channel X". |
| 4. Ball tracking | 3D trajectory: bounce point, movement in air, deviation off pitch, predicted stumps path | Hawk-Eye + Virtual Eye (20+ years of tracking, licensed by CricViz; CricViz claims 3M+ deliveries, 55+ data points per ball) | Pitch maps, beehives, DRS prediction, difficulty-adjusted stats (e.g. "batting difficulty last 30 min"). |

**Live collection (Layer 2, real-time):**
- **Human scorers / scouts at the venue** — still the backbone in 2026.
  Sportradar alone employs 12,600+ venue data collectors; each event is
  timestamped and pushed upstream within seconds. Cricbuzz's own description:
  "ICC and boards' official feeds + on-ground scorers who manually input
  ball-by-ball data + AI systems that analyse live video feeds."
- **Optical tracking** (Hawk-Eye / Second Spectrum / Virtual Eye) runs
  alongside: player positions, ball trajectory, spatial data, sub-second.
- **Broadcast-derived feeds** are cheaper but carry 5–15 s lag — why
  "official venue data commands a premium".
- **Pub-Sub / streaming:** Cricbuzz-style apps publish each ball event to a
  broker (Kafka / Pub-Sub); subscribers (app/web) receive it. That is why
  their live scores feel "instant" — the event is pushed, not polled.

### 1.2 Per-app sources (public evidence)

| App | Source model (public) | Live | Historical / deep |
|---|---|---|---|
| **Cricbuzz** | Official board/ICC feeds + venue scorers + video AI; Kafka/Spark pipelines; Redis cache; WebSocket/Firebase push; automated cross-checks ("unrealistic run rate / impossible dismissal → human verification") `[secondary write-ups]` | ✅ Fastest claim | Scorecard archive + rankings + records (proprietary) |
| **ESPNcricinfo / Statsguru** | Statsguru DB (Basevi, 2000): scripts over scorecards → relational DB indexed by player × opposition × conditions × era. Live: own liveblogs + scorers. | ✅ Liveblogs | ✅ Deepest historical: every Test/ODI/T20I, filters by opponent/format/venue/home-away/result/date. `cricketr` / `cricdata` wrappers prove dimensions: format × opposition × venue × home/away × result × time. |
| **CREX** | Own feed + provider feeds `[inferred]`; "instant ball-by-ball", pre-match insights, fantasy tips. | ✅ "Score before OTT" claim | Player stats tab in Series Profile; format chips. |
| **CricketLineX (Just Cricket)** | **EntitySport** feed (developer = Entity Sport). EntitySport API: REST polling + WebSocket streaming, 50+ data types, 250+ competitions, fantasy points, ball-by-ball commentary, full scorecards, player-vs-player matchup data. | ✅ WebSocket live | Player info + ICC rankings + stats (reviewer complaint: "Limited player statistics" — depth is thin). |
| **Cricmetric** | CricViz-style modelling + own historical DB; XGBoost win-probability, matchup query, venue charts. | ❌ Analytics, not live | ✅ Rigorous: monotone constraints, backtest, calibration. |
| **SofaScore** | Multi-sport provider feeds (Opta/Sportradar-class), 150k+ player profiles, season stats, live ratings. | ✅ Real-time | ◐ Cricket depth thinner than Cricinfo. |
| **KingCric (ours)** | **Legal free tier:** CricAPI (live + scorecard + basic player) → EliteSport → EntitySport API (public API only, NOT CricketLineX's app feed) → SportScore backstop → TheSportsDB (bios/badges) → **Cricsheet open data** (deep stats, calculated by KingCric). | ◐ 10-min cached (100/day free) — honest, not "instant" | ✅ Cricsheet ball-by-ball → career/splits/matchup/dismissal (see §2). Full-dataset refresh = `all_json.zip` → replace asset → rebuild, no code change. |

**Key lesson:** Reference apps do NOT "download a player table" from one place.
They **ingest ball events, then aggregate**. The ball is the atom; everything
else (innings, match, career, vs-opponent, venue, matchup) is a GROUP BY over
balls. KingCric already follows this model via Cricsheet — that is the correct
architecture, not a shortcut.

---

## 2. EXTRACTION — Ball → Innings → Match → Career

### 2.1 The atom: one delivery

Every system, from CricViz (55+ fields) to Cricsheet (JSON v1.3.0), stores the
same core per-ball event:

```
delivery = {
  batter, bowler, non_striker,
  runs: { batter, extras, total },
  extras: { wides, noballs, byes, legbyes, penalty },
  wickets: [{ kind, player_out, fielders: [{ name }] }],
  actual_delivery: "27.5",   // accounts for wides/no-balls
  // premium layers (NOT in Cricsheet, NOT in KingCric free tier):
  //   shot_type, fielding_position, ball_length, ball_line,
  //   ball_speed, trajectory { bounce, deviation, predicted_stumps }
}
```

Cricsheet JSON v1.3.0 shape (what KingCric parses):
`{ meta: {data_version}, info: {venue, city, dates, event, gender, teams,
outcome, toss, player_of_match, match_type, overs, team_type, registry,
officials, players, season}, innings: [{ team, overs: [{ over, deliveries }] }] }`.

Provider APIs (CricAPI / EliteSport / EntitySport) return the same event in
JSON over REST (`/currentMatches`, `/cricketScore`, `/matches/{id}/scorecard`,
`/players/{id}`) or WebSocket push. KingCric's providers normalise all of them
into the same `CricketMatch` / `Innings` / `Player` models — screens never
learn which provider answered.

### 2.2 Aggregation pipeline (the same at every app)

```
Ball events
  → group by (match, innings)        → INNINGS totals (batting card, bowling card, FOW, partnerships)
  → group by (match)                  → MATCH result (winner, margin, toss, venue, officials)
  → group by (player)                 → CAREER totals
  → group by (player, format)         → FORMAT splits (Test / ODI / T20 / T10)
  → group by (player, opponent)       → VS-OPPONENT splits
  → group by (player, venue)          → VENUE splits
  → group by (player, league/event)   → LEAGUE splits
  → group by (bowler, batter)         → MATCHUP (balls, runs, dismissals)
  → group by (dismissal kind, fielder, bowler, batter) → DISMISSAL HISTORY
  → last 5 matches by date            → RECENT FORM
  → group by (teamA, teamB)           → TEAM H2H
```

**Why this matters:** If you store only career totals, you can never answer
"vs Pakistan at Dubai" or "Bumrah vs Babar". Reference apps that answer those
questions (Cricinfo Statsguru) do so because they kept the ball-level (or at
least innings-level) grain and re-aggregate on demand. KingCric's
`CricsheetService` does exactly this: `_batAcc` / `_bowlAcc` scan deliveries
with a scope predicate (`format == X`, `opponent == Y`, `venue == Z`,
`league == W`) and accumulate — no hard-coded totals anywhere.

### 2.3 KingCric's current extraction (what already exists)

| Step | KingCric code | Notes |
|---|---|---|
| Parse | `CricsheetService.parse` — single match `{meta,info,innings}` or wrapper `{matches:[...]}`; never throws; `{}` → empty (no phantom match) | JSON v1.3.0, verified against cricsheet.org/format/json |
| Delivery | `CricsheetDelivery` — batter/bowler/non-striker, batterRuns/extrasRuns/totalRuns, wides/noBalls/byes/legByes, actualDelivery, wicketKind/playerOut/fielders; `isWide`, `isNoBall`, `isLegalBall`, `isWicket` | Wides/no-balls handled via `actual_delivery` |
| Identity | `_identities` map: Cricsheet short name ("V Kohli", "RG Sharma") → `p-*` id + full name + role; `resolveShortName` accepts short / full / `p-*` / last-name fallback | Must grow with dataset (see §5 gap G1) |
| Career | `playerByShortName` → `_batAcc` / `_bowlAcc` per scope → `BattingStats` / `BowlingStats` | See §3 formulas |
| Splits | Format (IT20→T20, ODM→ODI, MDM→Test), vs opponent, venue, league (`leagueForEvent`: IPL/PSL/Big Bash/T10/Ranji/SMAT/Vijay Hazare/International) | League bucketing is keyword-based — see gap G3 |
| Matchup | `matchup(bowler, batter)` + `matchupsForBatter` (top 6 by balls) | Balls/runs/dismissals per pair |
| Dismissal | `dismissalHistoryFor` — `"c X b Y — N times"` + `"Not dismissed by Z in N balls"` (≥12 balls, 0 dismissals) | Most frequent first |
| Recent form | `recentFormFor` — last 5 by `info.dates`, runs/balls/wkts + W/L vs player's team | Skips DNB + 0-wkt rows |
| H2H / partnerships / FOW | `teamH2H`, `partnerships`, `fallOfWickets` | Cumulative totals at each wicket |

**Live extraction (separate path):** `ApiService` providers parse
`currentMatches` → `CricketMatch` (status via `resolveStatus`, team names via
`cleanTeamName` + `titleCaseTeam`, `isEffectivelyLive` fallback) and
`cricketScore` → full `Innings` (batting/bowling/extras/FOW). Live data is
cached (10-min live, 60-min completed) and cross-checked (primary wins on
mismatch, log, never crash).

---

## 3. CALCULATION — Formulas + Edge Cases

### 3.1 Batting

| Stat | Formula | Edge cases |
|---|---|---|
| Runs | Σ `runs.batter` | — |
| Balls faced | Count deliveries where batter faced AND `wides == 0`. No-balls count as faced. | Wide does NOT count as a ball faced. A batter dismissed without facing (run out at non-striker's end) gets an innings + dismissal but 0 balls — KingCric handles this via the second pass in `_batAcc`. |
| 4s / 6s | Count `runs.batter == 4` / `== 6` | A 4 off an overthrow / all-run 4 is NOT `runs.batter == 4` in Cricsheet — it is recorded as runs; KingCric counts only batter-run 4s/6s (correct per standard). |
| Average | `runs / dismissals` where `dismissals = innings − notOuts` | **Never-dismissed → average = runs** (KingCric: `dismissals > 0 ? runs/dismissals : runs` when innings > 0). This matches the standard practice of treating a never-out batter as "out once" for ranking (avoids ∞). 0 innings → 0 (never divide by zero). |
| Strike rate | `runs × 100 / balls` | 0 balls → 0 (never NaN). |
| 50s / 100s | Per-(match, innings) runs: `50 ≤ runs < 100` → 50; `runs ≥ 100` → 100 | A 100 also counts as a 50 in some displays — KingCric does NOT double-count (100s and 50s are disjoint). Highest = max per-innings runs. |
| Matches | Distinct matches where player is in XI (or appears) | A player in XI but DNB still counts as a match played (KingCric: second pass over `playersByTeam`). |
| Innings | Distinct (match, innings) where batter faced a ball OR was dismissed | DNB innings do NOT count. |

### 3.2 Bowling

| Stat | Formula | Edge cases |
|---|---|---|
| Balls bowled | Legal deliveries: `wides == 0 AND noballs == 0` | Wides + no-balls do NOT count as balls bowled. |
| Runs conceded | Σ (`runs.total − byes − legbyes`) | **Byes / leg-byes are NOT charged to the bowler.** Wides + no-balls ARE charged (they are in `total` and not subtracted). Penalty runs: Cricsheet `extras.penalty` — KingCric currently does NOT subtract penalty (gap G4; penalty is rare, usually 5). |
| Wickets (bowler-credited) | Wickets with `kind ∈ {bowled, caught, caught and bowled, lbw, stumped, hit wicket, handled the ball}` | **Run out / retired hurt / obstructing the field are NOT credited to the bowler.** A run out IS a fielding dismissal and appears in dismissal history as `run out (fielder)`, not as a bowler wicket. |
| Economy | `runsConceded × 6 / balls` | 0 balls → 0. |
| Bowling average | `runsConceded / wickets` | 0 wickets → 0 (never ∞). Identity check: `Avg = Economy × StrikeRate / 6` — if a display violates this, one column is wrong or rounded. |
| Bowling strike rate | `balls / wickets` | 0 wickets → 0. |
| Best | Best (wickets, then fewest runs) in one innings; `5-fors` counted when wickets ≥ 5 in an innings | Tie-break: same wickets → fewer runs wins (KingCric: `e.value > bestWkts || (== && r < bestRuns)`). |
| 5-fors / 10-fors | Count innings with wickets ≥ 5 (≥10 for Tests, both innings combined — KingCric currently counts per-innings only; see gap G5) | — |

### 3.3 Derived / composite

| Stat | Formula / rule | Notes |
|---|---|---|
| Combined T20+ODI | Sum of the two format splits (batting + bowling) via `BattingStats.operator +` | KingCric's `+` recomputes avg/SR from summed runs/balls/dismissals — correct, NOT an average-of-averages. **Known bug:** `BattingStats.operator +` computes `average = (runs+o.runs)/inn` where `inn = innings+o.innings` — that divides by *innings*, not *dismissals*. For combined views this under-states average when not-outs exist. Fix: track dismissals in the operator or recompute from Cricsheet (gap G6 — see §5). |
| Recent form | Last 5 matches by `info.dates` desc, runs/balls/wkts + W/L vs player's team | Ties on date → stable order by match index. |
| Matchup SR | `runs × 100 / balls` (per pair) | `ballsPerDismissal = balls / dismissals` (0 dismissals → 0, not ∞). |
| Team H2H | Wins per team across loaded matches with both teams; `noResult = played − aWins − bWins` | Abandoned / no-result matches count as played but not as wins. |
| Partnerships | Consecutive (batter, non-striker) pairs until a wicket; runs summed | Pair key is sorted (`A + B`) — order-independent. |
| Fall of wickets | Cumulative team total at each wicket + `actualDelivery` | `"1-52 (Batter, 6.1 ov)"`. |
| Prediction (KingCric) | Weighted: recent form 30% + vs opponent 25% + venue 20% + matchup 15% + pitch 10% → 0–100 + Likely/Risky/Unlikely + WHY line | Never a guarantee; "Model • not a guarantee" + betting disclaimer. |

### 3.4 What KingCric does NOT have (premium layers)

| Data | Who has it | KingCric free-tier status |
|---|---|---|
| Shot type / wagon wheel / pitch map / beehive | CricViz / Opta (coded + Hawk-Eye) | NOT available — needs coded + tracking feeds (paid). Do NOT fake. |
| Ball speed / trajectory / bounce / deviation | Hawk-Eye / Virtual Eye (licensed) | NOT available. Do NOT fake. |
| Fielding positions / fielding runs-saved | Opta / CricViz | NOT available. Fielding dismissals (catches, run outs, stumpings) ARE available from Cricsheet `wickets[].fielders` — show those, not runs-saved. |
| Batting / bowling styles, photos, bios, DOB | TheSportsDB / provider profiles | Partially via TheSportsDB (bios/badges). Styles: Cricsheet does NOT store them — KingCric leaves blank rather than guessing. |
| Pre-2000 ball-by-ball | CricViz (Davis archive) / Cricket Archive | NOT in Cricsheet (limited/none pre-2000). Career totals for pre-2000 players must come from scorecard archives (not in free tier) — label honestly. |
| Timestamps per delivery | Nobody in open data | Cricsheet has NO per-delivery timestamps — recent-form ordering uses `info.dates` (match date), not ball time. |

---

## 4. ARRANGEMENT — How Reference Apps Arrange Player Data

### 4.1 The universal profile order (all reference apps agree)

Every good cricket app arranges a player profile in the same order. KingCric
already matches this order — the spec below locks it in so no team reorders it.

```
1. HEADER (always visible, no scroll needed)
   Photo / avatar (gold-ring) • Full name • Role • Team • Country
   Batting style • Bowling style (blank if unknown — never guessed)
   Source label: "Real • Cricsheet open data • N matches" / "Demo" / "Partial"
   Last updated HH:MM

2. KEY STRIP (4 numbers, always visible)
   Runs • Avg • SR • Wkts   (overall, all formats combined)

3. PREDICTION CARD (only when opened from a match: opponent + venue + format known)
   "vs <Opponent> at <Venue>, <Format>" • Score 0–100 • Likely/Risky/Unlikely
   • ONE Hindi/English WHY line • Inputs shown • "Model • not a guarantee"

4. OVERALL — ALL FORMATS (stat bars + grid)
   Runs • Avg • SR • 100s (+ 50s) • Boundaries (4s+6s)
   Visual bars (not just numbers): Runs/15000, Avg/60, SR/180, Boundaries/1500

5. VS OPPONENT (when opened from a match; else the top opponent)
   "vs <Opponent>" • Runs • Avg • SR • Matches
   + Recent form vs this opponent (subset of §4.2)

6. FORMAT-WISE (when opened from a match; else all formats)
   "<Format>" • Runs • Avg • SR • Matches
   + Full table (see §4.3): FORMAT | M | Runs | Avg | SR | 100s | 50s

7. ALL FORMATS — FULL TABLE (horizontal scroll + "swipe" hint)
   Columns: FORMAT | M | Runs | Avg | SR | 100s | 50s
   Rows: Test, ODI, T20, T10 (only formats with data; never empty "0 / 0 / 0" rows)

8. LEAGUES ("By League")
   One row per league: "<League> — R runs • Avg A • SR S"
   Order: current match's league first, then by runs desc.
   League buckets: IPL, PSL, Big Bash, T10 League, Ranji Trophy,
   Syed Mushtaq Ali, Vijay Hazare, International.
   (See gap G3: keyword bucketing can mis-file an event.)

9. VENUE ("Venue records per player")
   One row per venue: "<Venue> — R runs • Avg A • SR S"
   Order: current match's venue first, then by runs desc.
   Hidden if no venue data (never "0 / 0 / 0").

10. RECENT FORM (last 5, most recent first)
    One row per match: "<TeamA vs TeamB> • <Opponent> • <Format> • <W/L/NR>
    • <runs (balls) | wkts>"
    + "vs this opponent" subset when opened from a match.

11. MATCHUP (Bowler-vs-Batter, as batter)
    One row per bowler: "vs <Bowler> — M matches • D dismissals
    • R runs / B balls • SR S"
    Sorted by dismissals desc, then balls desc. Top 6 by balls.
    Tapping a bowler → that bowler's profile (P12: every name tappable).
    + "Not dismissed by Z in N balls" is in Dismissal History (§4.2), not here.

12. DISMISSAL HISTORY
    Most frequent first: "c <Fielder> b <Bowler> — N times"
    Then: "Not dismissed by <Bowler> in N balls" (≥12 balls, 0 dismissals).
    Run outs: "run out (<Fielder>)" — NOT credited to bowler.
    Formats: "b X" (bowled), "lbw b X", "st <WK> b X", "c <F> b X".

13. BOWLING — FULL TABLE (only if player has bowled)
    One row per format: "<Format> — W wkts • Econ E • Avg A • Best B"
    + Bowling overall (total wickets across formats).

14. RECORDS / H2H (where data exists)
    Team H2H bar lives on Match Detail, not on Player Profile.
    Player H2H = Vs Opponent section (§4.1 #5) + Matchup section (#11).
    Do NOT build a separate H2H screen.
```

### 4.2 Tables vs cards vs charts — what goes where

| Content | Presentation | Why |
|---|---|---|
| Key strip, overall, vs opponent, format-wise | Cards + stat bars (visual) | 2-second glance; bars make "good vs average" instant. |
| Full format table, bowling table | Fixed-column table, horizontal scroll, 640px min width, "swipe" hint | Numbers must align; squeezing clips digits. |
| Leagues, venue, recent form, matchup, dismissal | One row per item, title left, stats right, tappable where a profile exists | Scannable list; rows expand to 3 lines max, never cut mid-word. |
| Prediction, matchup, venue charts | Meter / bars + ONE-line explanation | CREX visibility + Cricmetric honesty: meter + WHY + inputs. |
| Wagon wheel, pitch map, shot map, beehive | NOT in KingCric free tier | Needs coded + tracking feeds. Do NOT fake with invented coordinates. |
| Collapsible vs always-visible | Sections 1–7 always visible; 8–13 visible by default, scrollable (no accordions on v1) | Reference apps show profile as a scroll, not a tap-to-expand puzzle. Keep it scrollable. |

### 4.3 Column orders (fixed — do not redesign)

- **Batting table:** FORMAT \| M \| Runs \| Avg \| SR \| 100s \| 50s
- **Bowling table:** FORMAT \| M \| Wkts \| Econ \| Avg \| SR \| Best
- **Scorecard batting:** Batter + dismissal \| R \| B \| 4s \| 6s \| SR
- **Scorecard bowling:** Bowler \| O \| M \| R \| W \| Econ \| Wd \| Nb
- **Matchup row:** Bowler • Matches • Dismissals • Runs • Balls • SR
- **Recent form row:** Match • Opponent • Format • Result • Runs (Balls) / Wkts
- **League / venue row:** Name • Runs • Avg • SR (bowling: Wkts • Econ • Avg)

### 4.4 Name resolution — the hardest invisible problem

Reference apps solve this with a **player registry**: one canonical ID per
person, plus aliases. ESPNcricinfo has a numeric player ID (e.g. Kohli 253802);
Cricsheet has `people.csv` (`a343262c` for Joe Root) + `names.csv` linking
external-site IDs; Roanuz / EntitySport have their own IDs.

KingCric's current solution (correct shape, small scale):

```
Cricsheet short name ("V Kohli", "RG Sharma", "Shaheen Shah Afridi")
  → _identities map → { id: "p-virat", displayName: "Virat Kohli", role: "Batter" }
  → Player.id = "p-virat" (stable across screens, compare, favourites)
```

Rules:
1. **Display name is always the full name** ("Virat Kohli"), never the short
   name ("V Kohli"), never an ID.
2. **Short names exist only inside the parser** — they must never leak into
   UI, favourites keys, or compare pickers.
3. **Team names are Title Case everywhere** (`cleanTeamName` + `titleCaseTeam`
   at parse time). Short ALL-CAPS abbreviations (MI, CSK, IPL, USA) are
   preserved; "bulgaria women" → "Bulgaria Women".
4. **Team changes:** a player's `team` is the team of the *most recent* match
   in the loaded dataset (or the provider profile's team). If a player has
   played for two teams, the profile shows the latest team; splits by league
   show the league, not the team.
5. **Format changes:** `match_type` normalised at parse: `IT20→T20`,
   `ODM→ODI`, `MDM→Test`, `T10→T10`. Unknown → raw (never silently dropped).
6. **Women's / U19 / Domestic separation:** `gender` (`male`/`female`) +
   `team_type` (`international`/`club`) + `event.name` determine the bucket.
   Women's matches are NOT merged into men's career totals. U19 is a separate
   filter chip (differentiator). Domestic is split by competition (Ranji /
   SMAT / Vijay Hazare), never a single "domestic" bucket.
7. **T10:** first-class format chip (Test/ODI/T20/T10) on every Team/Player/
   Series screen. T10 events are bucketed by `leagueForEvent` (`t10` →
   "T10 League").

### 4.5 Update flow — live → completed → recalculated

```
Live match (poll, 10-min cache)
  → fetchMatches → CricketMatch (status via resolveStatus, isEffectivelyLive)
  → UI shows cached first, refreshes in background (stale-while-revalidate),
    no flicker, "Last updated HH:MM"

Match finishes (live → completed transition)
  → AutoUpdateService detects transition
  → fetches final scorecard ONCE (cricketScore)
  → validates: innings reconcile (batting + extras ≈ total within tolerance)
    else keeps last verified copy, does NOT propagate bad data
  → recalculates: career / vs opponent / venue / H2H / recent form /
    prediction inputs (Cricsheet parser re-runs over updated dataset;
    provider profiles refresh on 60-min cache)
  → emits via onMatchFinished → UI updates without restart

Player profile opened after finish
  → shows recalculated stats + new "Last updated" + source label
  → never shows stale numbers silently
```

On the free tier, "immediately" means "on the next 10-min poll + one
match-end fetch" — say so, do not claim sub-second. Background-when-closed
(WorkManager / Firebase Functions) + FCM push are planned, not in V3; label
honestly until wired ("Local reminders (push coming soon)").

---

## 5. KINGCRIC GAPS TO FIX (from comparing KingCric to reference)

| # | Gap | Evidence | Fix |
|---|---|---|---|
| G1 | **Identity map is tiny (44 players).** Any player outside the map returns `null` → profile missing. Reference apps have a registry for *every* player (Cricsheet `people.csv` has 1.6M+ via Cricket Archive scale; ESPNcricinfo has numeric IDs for all). | `cricsheet_service.dart` `_identities` (44 entries). `playerByShortName` returns `null` when `ident == null`. | Load Cricsheet `people.csv` + `names.csv` as the identity source (or a generated Dart map) instead of a hand-written 44-entry map. Fallback: if a short name is unknown, create a profile with display name = title-cased short name + role "Batter" (never `null` → missing profile). Unknown players must still show a profile, labelled "Partial". |
| G2 | **BattingStats `operator +` divides by innings, not dismissals.** Combined T20+ODI average is wrong when not-outs exist. | `player.dart`: `average: inn == 0 ? 0 : (runs+o.runs)/inn` where `inn = innings+o.innings`. | Add `dismissals` to `BattingStats` (or compute combined average from Cricsheet `_batAcc` directly, not by summing two `BattingStats`). Add a test: two blocks with not-outs → combined average = totalRuns / totalDismissals. |
| G3 | **League bucketing is keyword-based.** `leagueForEvent` matches substrings ("ipl", "psl", "t10", "ranji") — an event named e.g. "IPL Warm-up" or "PSL All-Stars" is bucketed correctly, but a new league ("SA20", "ILT20", "The Hundred", "BPL", "CPL") falls to "International". | `cricsheet_service.dart` `leagueForEvent`. | Add explicit buckets for SA20, ILT20, The Hundred, BPL, CPL, WPL, WBBL, County, Sheffield Shield, Super Smash, T20 Blast, Super 50 Cup, Women's leagues. Fallback: return the raw `event.name` (not "International") when no bucket matches, so the league row still shows the real competition name. |
| G4 | **Penalty runs not handled.** Cricsheet `extras.penalty` is parsed but not subtracted / added anywhere. | `CricsheetDelivery` has no `penalty` field; `_bowlAcc` subtracts only byes/leg-byes. | Add `penalty` to `CricsheetDelivery`; bowler runs conceded = `total − byes − legbyes` (penalty is NOT charged to bowler — it is a team extra, like byes). Innings total must include penalty. Add a test with a penalty delivery. |
| G5 | **10-fors not counted; 5-fors per-innings only.** Tests have two innings per match; a 10-wicket match haul is a headline stat. | `_BowlAcc` counts `fiveWickets` per (match, innings) only. | Count `tenWickets` per match (sum across both innings of a Test). Show "Best" as best match haul for Tests (e.g. "10/123") alongside best innings. |
| G6 | **Recent form skips DNB + 0-wkt rows.** A player who played but did not bat and took 0 wickets is invisible in recent form — the user sees 5 matches, not the last 5 *played*. | `recentFormFor`: `if (!batted && wkts == 0) continue;` | Include DNB rows as "DNB" (did not bat) with 0 runs, so recent form = last 5 *played* matches, not last 5 *scored* matches. Label DNB explicitly. |
| G7 | **Matchups capped at 6, sorted by balls only.** The most *dangerous* matchup (most dismissals) may be outside the top 6 by balls. | `matchupsForBatter`: `sort by balls desc`, `take(6)`. | Sort by dismissals desc, then balls desc. Show top 6 by dismissals + top 3 by balls (deduped), or show all with a "Show all" affordance. Never hide the bowler who has dismissed the batter most. |
| G8 | **Dismissal history lines are unsorted by frequency.** `lines.sort()` is alphabetical, not by count — "c X b Y — 1 time" can appear before "c A b B — 5 times". | `dismissalHistoryFor`: `lines.sort()` (lexicographic). | Sort by count desc, then alphabetically. Most frequent first (spec §4.1 #12). |
| G9 | **Partnerships / FOW use string-sorting for runs.** `partnerships` parses runs out of a formatted string (`split('—')`) to sort — fragile. | `partnerships`: `int.tryParse(a.split('—').last...)`. | Keep (runs, balls, pair) as structured data, sort by runs, format only at display. Never parse a display string to sort. |
| G10 | **No fielding stats.** Catches / stumpings / run-outs are in Cricsheet (`wickets[].fielders`), but KingCric has no fielding table. Reference apps show catches + stumpings on the profile. | `Player` has no fielding fields. | Add `FieldingStats { catches, stumpings, runOuts }` to `Player`, calculated from `wickets[].fielders` + `kind` (caught → catcher, stumped → keeper, run out → thrower). Show on profile after bowling table. |
| G11 | **No "vs this opponent, this venue, this format" combined split.** KingCric has vs-opponent (all formats), format (all opponents), venue (all opponents) — but NOT the triple split "vs Pakistan at Dubai in T20" that the match-context view needs. | `Player` has `battingVsOpponent`, `battingByFormat`, `battingByVenue` — no triple key. | Add a scope query: `battingInScope({opponent, venue, format})` in `CricsheetService` (same `_batAcc` with a combined predicate). Use it for the match-context squad row + prediction inputs. Do NOT add a fourth map — compute on demand. |
| G12 | **Provider basic profiles have no deep splits.** CricAPI `players_info` gives bio + basic stats only; KingCric correctly labels them `dataComplete: false`, but the UI must never show them as if they were Cricsheet-calculated. | `api_service.dart` `fetchPlayer`: Cricsheet-first, then providers, then mock. | Keep Cricsheet-first. When a profile comes from a provider (not Cricsheet), show "Partial • provider basic profile" + hide empty splits (never "0 / 0 / 0" rows). When no source has data, show "Demo" (mock), never fake "Complete". |
| G13 | **Sample dataset = 4 matches.** Real-over-sample, labelled with dataset size — correct, but NOT full careers. Users will compare "Virat 169 runs" to Cricinfo's "27,150 runs" and think KingCric is wrong. | `assets/cricsheet_sample.json` (4 T20Is). | Full-dataset refresh (§6 of CRICSHEET-DATA.md) is the real fix: ship a curated subset (last 3–5 seasons internationals + IPL/PSL/BBL), not 4 matches. Until then, the profile header MUST show "Real • Cricsheet open data • 4 matches in dataset" (it already does) and the "Overall" section must carry a one-line caption: "Calculated over the loaded dataset (4 matches), not a full career." Add that caption. |

---

## 6. KINGCRIC IMPLEMENTATION CHECKLIST

- [ ] **Identity:** Load `people.csv`/`names.csv` (or generated map); unknown short name → title-cased profile, "Partial", never `null`. (G1)
- [ ] **Combined average:** Fix `BattingStats.operator +` to divide by dismissals (add `dismissals` field). Test with not-outs. (G2)
- [ ] **League buckets:** Add SA20, ILT20, The Hundred, BPL, CPL, WPL, WBBL, County, Sheffield Shield, Super Smash, T20 Blast, Super 50 Cup; fallback = raw event name. (G3)
- [ ] **Penalty runs:** Add `penalty` to delivery; innings total includes it; bowler conceded excludes it. Test. (G4)
- [ ] **10-fors:** Count per-match 10-wicket hauls (Tests); show best match haul. (G5)
- [ ] **Recent form DNB:** Include DNB rows labelled "DNB"; recent form = last 5 played. (G6)
- [ ] **Matchup sort:** Dismissals desc, then balls desc; never hide the top dismisser. (G7)
- [ ] **Dismissal sort:** Count desc, then alphabetical. (G8)
- [ ] **Partnerships:** Structured sort, never parse display strings. (G9)
- [ ] **Fielding:** Add `FieldingStats` (catches/stumpings/run-outs) from `wickets[].fielders`; show on profile. (G10)
- [ ] **Triple split:** `battingInScope({opponent, venue, format})` for match-context + prediction. (G11)
- [ ] **Provider labels:** "Partial • provider basic profile" when not Cricsheet; hide empty splits; never "Complete" on demo. (G12)
- [ ] **Sample caption:** "Calculated over the loaded dataset (N matches), not a full career." on Overall section when `source == 'cricsheet'`. (G13)
- [ ] **Arrangement lock:** Profile order = §4.1 (Header → Key strip → Prediction → Overall → Vs Opponent → Format-wise → Full Table → Leagues → Venue → Recent Form → Matchup → Dismissal → Bowling → Records). No team reorders it without updating this doc.
- [ ] **Column orders lock:** §4.3 (batting, bowling, scorecard, matchup, recent form, league/venue rows). No team changes column order without updating this doc.
- [ ] **Name rules:** Full names in UI; Title Case teams; short names never leak; abbreviations preserved (MI, CSK, IPL, USA). (§4.4)
- [ ] **Update flow:** Live poll → transition → once fetch → validate → recalc → emit. "Last updated HH:MM" on Home + Match Detail + Profile. (§4.5)
- [ ] **Honest limits:** No wagon wheel / pitch map / ball speed / trajectory / runs-saved (needs paid feeds). Do NOT fake. (§3.4)
- [ ] **Tests:** `flutter analyze` clean; `flutter test` must include: average with never-dismissed; bowling average identity (`Avg = Econ × SR / 6`); run-out NOT credited to bowler; byes/leg-byes NOT charged; combined average with not-outs; matchup sort by dismissals; dismissal sort by count; DNB in recent form; unknown player → Partial profile (not null).

---

## 7. SOURCES (all public, fetched 2026-10-18)

- ESPNcricinfo / Statsguru — Statsguru DB description (vectree.io), Basevi bio (Wikipedia: Statsguru built 2000 from scripts over scorecards), Statsguru dimensions via `cricketr` / `cricdata` (PyPI).
- Cricbuzz pipeline — TechnologyWithVivek ("Cricbuzz: The Technology Behind Real-Time Cricket Scores"), DevCookies / Medium (Pub-Sub model), IRM India ("Inside Cricbuzz: Risk Technology").
- CricViz / Opta / Hawk-Eye — Marcellus ("Cricket is having its Moneyball moment", four-storey stack), SportsMintMedia (CricViz: 3M+ deliveries, 55+ points/ball, Hawk-Eye + Virtual Eye), DFKCompany (CricViz PlayViz / BatViz), MediaBrief (CricViz × Cricket Australia).
- Sportradar — developer.sportradar.com Cricket overview (real-time scoring, ball-by-ball, pitch/field coordinates, official for ICC/ECB/CPL); Grapevine Birmingham (12,600+ venue collectors, scouts + optical tracking).
- EntitySport / Roanuz — entitysport.com (REST + WebSocket, 50+ data types, 250+ competitions, fantasy points, matchup data), sports.roanuz.com Performance API (Player Stats, Ball-by-Ball, Season Stats, Match Credit), highlightly.net (Roanuz: REST/GraphQL/Firebase/WebSocket/Webhook).
- Cricsheet — cricsheet.org (JSON v1.3.0, downloads, `people.csv`/`names.csv`, no ball-tracking/styles/timestamps, no pre-2000 ball-by-ball); CricketLogic (cricketlogic.net, DuckDB views over Cricsheet YAML); `cricketdata` R vignette (rdrr.io); Huzi.pk (Cricsheet free YAML/JSON); Ithy (Cricsheet open-source ball-by-ball, post-2000).
- Formulas — CricTracker (batting avg = runs/dismissals; bowling avg = runs/wkts), CricketTaken (bowling identity Avg = Econ × SR / 6), Testbook (SR = runs × 100 / balls), Academia.edu (never-dismissed → treat as out once for ranking).
- KingCric docs — CRICSHEET-DATA.md, API-SETUP.md, MULTI-API.md, REQUIREMENTS-MAPPING.md, REFERENCE-SPEC.md, REFERENCE-APPS-DEEP-DIVE.md, CRICKETLINEX-REFERENCE.md, `lib/services/cricsheet_service.dart`, `lib/models/player.dart`, `lib/screens/player_profile_screen.dart`.
