# KingCric — REFERENCE SPEC
## What kind of app KingCric must be (studied from Cricbuzz, ESPNcricinfo, Crex, Cricmetric, Sofascore)

**Date:** 2026-10-18
**Status:** READ-ONLY research + code audit. NO code edited in this file's work.
**User instruction behind it:** "pehle reference le and samaj ki kaisa app chahiye" — first take reference and understand what kind of app is needed, then build. Plus: "jaise jo market m exist karta hai uska app download kar and uski acche se saari chize dekh us app ki nikal ke" — download existing market apps and thoroughly extract everything from them.

> **Honest scope note — read first.**
> This spec is built from (a) public web research on the reference apps
> (Play Store listings, product breakdowns, help/docs pages) and
> (b) a full audit of KingCric's current code + the user's V3 screenshots.
> It does **NOT** claim a hands-on teardown of installed Cricbuzz / Crex /
> ESPNcricinfo APKs: a text-research subagent cannot download apps, install
> APKs, sign in, or drive a live browser. That hands-on step is still open
> and is listed as Step 0 in §9. Nothing below invents a screen that was not
> confirmed by at least one public source or by KingCric's own code.

**Sources used (public, verifiable):**
- Cricbuzz vs Cricinfo product breakdown (Prodlab): Cricbuzz = speed /
  mobile-first / "fans don't read cricket, they check cricket"; Cricinfo =
  depth / Statsguru / long-form. Cricbuzz app ~18 MB, 100M+ Android
  downloads; Cricinfo app ~30 MB, ~10M downloads.
- Cricbuzz Play Store / help pages: superfast scores, ball-by-ball
  commentary, notifications, news/editorials, schedules, rankings/stats/
  records, tournament specials, domestic coverage.
- ESPNcricinfo pages: ball-by-ball live coverage, full scorecard,
  in-depth analysis, schedule of upcoming matches, player profiles +
  career stats, push notifications for wickets / milestones / results,
  concise + full scoreboard, match graph, Live / Results / Fixtures with
  INT/DOM toggle, tap a player name → full profile + career stats.
- Crex (Cricket Exchange) Play Store: instant ball-by-ball updates,
  detailed scorecards + partnerships + player stats, win-probability meter
  that updates through the match, fantasy tips, pre-match insights,
  rankings / points tables / records, Home / Matches / Series / Fixtures
  tabs, series profile with points table + top players + squads, format
  chips, live timers, PIN live scores, light + dark mode, EN/Hindi/Bengali.
  User praise quoted on Play Store: fastest updates, "small to big unique
  stats shown clearly with numbers", "unlike Cricbuzz where stats are
  complicated, here everything is simple".
- Cricmetric About + embedding pages: "Moneyball of Cricket" — stats
  visualisation, in-game win-probability graph, descriptive analytics
  (IPL player ranks, matchup-based team rankings, captain rankings),
  predictive analytics (2019 WC pre-match predictions, 68% success),
  embeddable H2H records, venue outcomes (bat-first win %), average
  1st-innings scores by venue, venue bowler stats (avg vs economy
  scatter), player pages filterable by format / role / group-by year,
  Batter-vs-Bowler matchup query.
- Sofascore cricket pages: real-time results, ball-by-ball per innings,
  fall-of-wicket + partnership tables, play-by-play, wagon wheel,
  commentary, per-innings statistics, H2H, predictions/odds context.
- Generic reference (CricketAPI widget docs + standard scorecard
  examples): match card must show all three states LIVE / RESULT /
  UPCOMING side by side; series name + both teams + score + overs +
  result on one card; tournament page = Info / Teams / Stats / Points
  Table; match page = Scorecard / Live / Overs / Graph (+ Info/Squad).

---

## 1. The one-sentence product rule

> **KingCric = Cricbuzz's speed + Crex's clarity + Cricinfo's depth +
> Cricmetric's analytics, in a King (navy + gold) skin — and every number
> must be instantly readable in 2 seconds on a phone, in Hindi or English.**

The user's test is not "does it have features". It is: **"kholte hi samajh
aa jaye — kaunsi match live hai, score kya hai, kaun jeet raha hai, kis
player ka kya haal hai."** If the first screen needs thinking, the app
has already failed — no matter how many features exist underneath.

Cricbuzz wins because it optimises for the **check** (glance → score →
done), not the **read**. KingCric must do the same on Home, and earn the
right to be deep on the inner screens.

---

## 2. Common patterns — what EVERY good cricket app does the same way

These are non-negotiable. KingCric broke several of them in V3 (see §3);
the fix is to match the pattern, not to invent a new one.

| # | Pattern | How the references do it | KingCric rule |
|---|---------|--------------------------|---------------|
| P1 | **Status is ONE truth, derived from the match, never from one label** | LIVE = match in progress (scores moving, no result). UPCOMING = no balls bowled, start time in future. RESULT = final result line exists. A card NEVER shows a live score under an UPCOMING pill. | Status = `resolveStatus(start, end, scores, resultText)` at parse time. The Home filter, the card pill, and the detail header all read the SAME resolved status. No second, conflicting `isEffectivelyLive` workaround in the UI layer. |
| P2 | **Live is unmissable** | Red / green LIVE pill + pulsing dot, at the TOP-LEFT of the card. Score in the biggest bold type on the card. "Need X from Y balls" directly under the scores. | Keep `LivePill` (red gradient + dot). Live card gets hero gradient + stronger border. Non-live cards never get the live treatment. |
| P3 | **One team = one row, always** | Team A row, then Team B row. Never `TeamA,TeamB` in one string. Never two teams sharing one score line. | Score rows are built from a structured `scores[]` list (one entry per team/inning), never from splitting a joined string. Inning label is separate from team name: `Sweden Women — Inning 1`, not `Sweden Women Inning 1` baked into the name. |
| P4 | **Team names are Title Case, everywhere** | "Sweden Women", "Bulgaria Women" — never "bulgaria women". Short forms (IND, PAK, AUS) only where the reference uses them, and consistently. | Normalise once at parse: `titleCaseTeam()` + `cleanTeamName()` strip `Inning 1`, commas, stray suffixes. UI never re-cases. |
| P5 | **Long names wrap or shrink — never cut mid-word, never overlap** | Cricbuzz/Crex let a long fixture name take 2 lines; chips shrink via FittedBox; tables scroll horizontally with a "swipe" hint. | App name: FittedBox scale-down. Tabs: single-line FittedBox, no wrap. Fixture title: max 2 lines + ellipsis at a word boundary. Tables: fixed-width columns + horizontal scroll + hint. |
| P6 | **Scorecard = Batting, then Extras, then Bowling, then FOW, then Partnerships, then Yet-to-bat** | Identical order in Cricbuzz, Cricinfo, Crex, and standard scorecards. Batting columns: R, B, 4s, 6s, SR + dismissal line (`c X b Y`). Bowling columns: O, M, R, W, Econ (+ Wd, Nb). | Keep this exact order. Never reorder, never hide Extras/FOW/Partnerships. |
| P7 | **Every number has a source label** | Cricinfo shows the database; Cricmetric shows the model; Crex shows "fantasy tips by experts". No reference app shows a big number with no provenance. | Every stats block carries ONE source line: `Real • CricAPI • live`, `Real • Cricsheet open data • N matches`, or `Demo data — curated sample, not live-verified`. Never "Complete" on a demo/curated number. |
| P8 | **Home = Live first, then everything else** | Default tab is Live (or a merged "Matches" list with Live pinned to top). Upcoming / Results are one tap away, never the default when a live match exists. | Default filter = Live. If no live match exists, show a clear empty state ("No live matches right now — next match …") + Upcoming below, not a blank screen. |
| P9 | **No developer text in release** | No "AdMob unit id not set", no "TODO", no placeholder boxes. If a feature is not wired, it is hidden, not labelled as broken. | If no AdMob ID → render NOTHING (no placeholder box). Same for any unconfigured provider. |
| P10 | **Search + favourites + notifications are first-class, not buried** | Cricbuzz/Crex: search from Home; pin/favourite a match or team; notifications for wickets, milestones, results. | Search stays on Home. Favourites = star on player/team/match, persisted, with a notifications toggle that actually gates alerts. |
| P11 | **Language toggle is visible but quiet** | Crex: EN / Hindi / Bengali in settings + quick toggle. Cricbuzz: full vernacular editions. | Keep EN / हिं toggle in the Home header. It must switch ALL labels (tabs, pills, empty states), never leave a mix like "Upcomin g". |
| P12 | **Tapping anything drills down** | Tap a match → detail. Tap a player name in ANY scorecard / squad / leaderboard → that player's profile. Tap a team → team page. | No dead text. Every player name in scorecard, squad, compare, stats, trending is tappable to the profile. |

---

## 3. Where KingCric V3 broke the patterns (from the user's screenshots)

Screenshots (2026-10-18, V3 build 39121578986): Home / Upcoming,
Home / Recent, Home / Live. These are REAL bugs, not taste issues.

| Screenshot evidence | Pattern broken | Root cause (from code audit) |
|---|---|---|
| Austria W vs Sweden W: Sweden 124/9 (20), Austria 37/3 (7.0), "need 88 in 78" — shown under **UPCOMING** tab with **UPCOMING** pill | P1, P2, P8 | Provider mapped CricAPI `status` text straight through. "Need 88…" has no word "live"/"won", so it stayed `upcoming`. The UI then had to add `isEffectivelyLive` as a bandage. |
| Live tab: **"No matches in this section."** while a live match exists | P1, P8 | Same cause: filter used raw status for Upcoming but `isEffectivelyLive` for Live — two truths, opposite answers. |
| Recent: **"Bulgaria Women,Sweden Wo… 99/0 (5.5 ov)"** | P3, P4, P5 | Team name was built by joining/splitting a provider string (`"Bulgaria Women,Sweden Women Inning …"`), not from structured `scores[]`. |
| Recent: **"bulgaria women Inning 1"** lowercase | P4 | No title-case normalisation at parse; inning label baked into the name. |
| Header: **"King…"** | P5 | App name ellipsised at 1 line in a narrow Row. |
| Tab: **"Upcomin g"** wrapped mid-word | P5, P11 | SegmentedButton allowed wrapping on narrow screens. |
| Fixture: **"Bulgaria Women vs Sweden Wom…"** cut | P5 | Title capped at 1 line. |
| **"Ad placeholder — AdMob unit id not set yet"** visible in release | P9 | Placeholder widget rendered unconditionally. |
| Trending: **Virat Kohli 27150 runs — "Complete"** | P7 | Mock/curated players carried `dataComplete`-style labelling that read as full-career-verified. A 4-match Cricsheet sample can never be "Complete" career data. |

**What the parallel V3-fix worker already did (local commit `17ce998`,
NOT pushed at time of writing — this spec must be combined with it,
not redo it):** `resolveStatus()` + `isEffectivelyLive` hardening,
`cleanTeamName()` + `titleCaseTeam()`, header FittedBox, custom
no-wrap filter tabs, 2-line match title, AdPlaceholder hidden when no
AdMob ID, mock players `dataComplete=false` + Demo source label,
22/22 tests. The redesign must KEEP all of those fixes and then apply
§4–§8 on top. Do not regress them.

---

## 4. Screen-by-screen spec — what each screen MUST show

Conventions for every mockup below:
- `[...]` = tappable. `—` = section divider. Text in quotes is the
  literal label the user sees. Hindi strings live in `strings.dart`;
  every screen must render fully in EN and in हिं.

### 4.1 Home (the "check" screen — most important screen in the app)

**Goal:** In 2 seconds: which matches are live, what is the score, who
is winning. Nothing else competes for attention.

```
┌─────────────────────────────────────────────┐
│ 👑 KingCric            [EN | हिं]           │
│ Har Ball, Har Stat, King Jaisa.             │
├─────────────────────────────────────────────┤
│ 🔍 Search player, team, match…              │
├─────────────────────────────────────────────┤
│ [Live] [Upcoming] [Recent]   ← ONE row,     │
│   never wraps, selected = gold pill         │
├─────────────────────────────────────────────┤
│ ● LIVE  (only if a live match exists)        │
│ ┌─ MATCH CARD (hero, gold border) ────────┐ │
│ │ 🔴 LIVE   International • T20           │ │
│ │ Austria Women vs Sweden Women           │ │
│ │ 📍 Moara Vlasiei Cricket Ground…        │ │
│ │ Sweden Women        124/9 (20.0 ov)     │ │
│ │ Austria Women        37/3 (7.0 ov)      │ │
│ │ Austria Women need 88 runs in 78 balls  │ │
│ │ Batting: …  •  Bowling: …              │ │
│ │ → Tap for FULL scorecard                │ │
│ └─────────────────────────────────────────┘ │
│ ┌─ MATCH CARD (normal) ───────────────────┐ │
│ │ UPCOMING  International • ODI           │ │
│ │ Pakistan vs Sri Lanka                   │ │
│ │ 📍 Rawalpindi Cricket Stadium…          │ │
│ │ Starts: Today, 5:30 PM                  │ │
│ │ → Tap for preview                       │ │
│ └─────────────────────────────────────────┘ │
│ ── Trending Players ──                     │
│ [VK] Virat Kohli  •  Batter • India        │
│      27150 runs • Avg 45.6 • SR 78.8      │
│      Source: Demo data — not live-verified │  ← P7, never "Complete" on demo
└─────────────────────────────────────────────┘
Bottom nav: [Home] [Leagues] [Compare] [Stats] [Favourites]
```

**Rules:**
- H1. Default tab = Live. Empty Live = "No live matches right now."
  + next upcoming match card directly below (never a dead blank screen).
- H2. Card order inside a tab: Live → sorted by "most recently updated"
  first; Upcoming → by start time ascending; Recent → by end time
  descending.
- H3. Card contents, in this exact order: status pill + `League • Format`
  → fixture title (max 2 lines) → venue (1 line, ellipsis) → ONE row per
  team: `Team Name` (left, 1 line) + `score` (right, bold gold) → ONE
  result/equation line (live: "need X from Y"; result: "X won by …";
  upcoming: "Starts: …") → current batters/bowler (live only) → "Tap
  for FULL scorecard".
- H4. Upcoming card shows NO score rows (or "Yet to bat" only). Never a
  score on an upcoming card.
- H5. Recent card shows BOTH scores + the final result line. Never a
  "need X" line on a completed match.
- H6. Search filters the CURRENT tab's list by team / league / player.
  Empty search result = "No matches found for '…'".
- H7. Pull-to-refresh re-fetches. A "Last updated HH:MM" line sits under
  the tabs (Cricbuzz-style freshness signal). Manual Refresh button
  always visible.
- H8. NO ad placeholder. If no AdMob ID, render nothing.
- H9. Trending Players = top 4 by runs (or by a stated rule), each row
  tappable → profile, each row carrying its source label (P7).
- H10. Demo mode: ONE amber banner at top — "Demo data — connect a free
  API key for live scores" — not repeated on every card.

**NOT to do:** Do not put news, videos, quizzes, or fantasy tips on Home
v1. Cricbuzz/Crex have them, but they dilute the "check" screen. They
belong in a later "News" tab, not in the way of the score.

### 4.2 Match Detail (the "read" screen — depth lives here)

**Tabs (in this order, always):** `Live | Scorecard | Squad | Prediction`
(Crex: Matches/Series/Fixtures; Cricinfo: Live/Scorecard/Commentary;
KingCric keeps 4 tabs — Live doubles as commentary.)

```
LIVE TAB
┌─────────────────────────────────────────────┐
│ 🔴 LIVE   International • T20              │
│ Austria Women vs Sweden Women               │
│ 📍 Moara Vlasiei Cricket Ground…            │
│ Sweden Women        124/9 (20.0 ov)        │
│ Austria Women        37/3 (7.0 ov)         │
│ Austria Women need 88 runs in 78 balls      │
│ ── Batting: …  Bowling: …  Last ball: [6] ──│
│ 🪙 Toss: …                                  │
│ ── Target & Equation ──                     │
│ [equation line / mini win-probability bar]  │
│ ── Head-to-Head ──                          │
│ Austria W [███░░░░] 3 — 5 Sweden W (8)      │
│ ── Match Info ──                            │
│ Venue / Toss / Umpires / Referee / Pitch    │
│ ── Commentary ──                            │
│ [ball-by-ball, newest first]                │
└─────────────────────────────────────────────┘

SCORECARD TAB (P6 order, never reordered)
Header: Title • League • Format • Venue • Toss • Umpires
For EACH innings:
  "Sweden Women — 124/9 (20.0 ov) • Innings 1"
  BATTING table: Batter (+ dismissal line) | R | B | 4s | 6s | SR
    - not-out row highlighted, `*` after name
    - TOTAL row: runs / wickets
  EXTRAS: "Extras: Wd 3, Nb 1, B 1 (5)"
  BOWLING table: Bowler | O | M | R | W | Econ | Wd | Nb
  FALL OF WICKETS: numbered 1..N — "1 — Batter, 45 (5.2 ov)"
  PARTNERSHIPS: "A & B — 32 runs (24 balls)"
  YET TO BAT: chips
  "↔ Swipe sideways for all columns"
If no innings yet: "Scorecard not available yet." (upcoming)

SQUAD TAB
  Section: Team A (XI + bench) — each player row tappable → profile,
  with context line "vs <Opponent> • <Format>".
  Section: Team B — same.
  Empty: "Squad will appear once the data source returns squads."

PREDICTION TAB (Cricmetric-style, honest)
  "Who will fire? — King Prediction"
  "Form + vs Opponent + Venue + Matchup + Pitch"
  One card per squad player, sorted by score desc:
    Name • Score 0–100 • Likely / Risky / Unlikely
    + ONE line in plain Hindi/English explaining WHY
    + "Prediction is a model, not a guarantee."
```

**Rules:**
- M1. Live tab and Scorecard tab NEVER disagree: same scores, same
  status, same result line, same `resolveStatus`.
- M2. Equation for a chase: `need (target - current) from (balls left)`,
  computed from structured overs — never from a status string.
- M3. Tapping a batter/bowler name in the scorecard → that player's
  profile (P12). This is currently missing — scorecard names are plain
  text. Fix it.
- M4. Commentary: newest first, each entry = over/ball + text. Empty =
  "No commentary available." — never a spinner forever.
- M5. Prediction cards show the formula inputs, not just a number.
  A prediction with no data behind it shows "Not enough data", not a
  fake 0–100.

### 4.3 Player Profile (the "study" screen — Cricinfo + Cricmetric depth)

**Order (fixed — this is the Cricinfo/Statsguru order users expect):**

```
Hero: [Avatar initials] Name
      Role • Team • Country
      Batting: … • Bowling: …
      [SOURCE LINE — P7]  e.g. "Real • Cricsheet open data • 4 matches in dataset"
                           or  "Demo data — curated sample, not live-verified"
      Quick stats row: Runs | Avg | SR | Wkts
[Prediction card IF opened from a match: vs <Opponent> at <Venue>, <Format>]

Overall — All Formats (career totals, all formats combined)
  [Runs] [Average] [Strike Rate] [100s / 50s]
  Stat bars: Runs / Average (/60) / SR (/180) / Boundaries

vs Opponent — <Opponent>   (only when opened from a match)
  Runs | Average | SR | Matches

Format-wise — <Format>     (only when opened from a match)
  Runs | Average | SR | Matches

All Formats — Full Table (horizontal scroll)
  Format | M | Runs | Avg | SR | 100s | 50s

Leagues (one row per league: runs • avg • SR)
Venue records (one row per venue: runs • avg • SR)   ← user asked for this explicitly
Recent Form (last 5: match • opponent • format • result • runs/balls or wkts)
Matchup — Bowler vs Batter (vs each bowler: matches • dismissals • runs/balls • SR)
Dismissal History ("c X b Y — N times" + "Not dismissed by Z in N balls")
Bowling — Full Table (per format: wkts • econ • avg • best)
```

**Rules:**
- P-P1. Hero quick stats are ALWAYS visible, no scroll needed to find
  Runs/Avg/SR/Wkts.
- P-P2. The source line is directly under the hero identity, not buried
  at the bottom. A Cricsheet profile states its dataset size; a demo
  profile says Demo. Never "Complete" unless the dataset is genuinely
  a full career (which a 4-match sample is not — say "Real • 4 matches",
  not "Complete").
- P-P3. Empty sections are HIDDEN, not shown as "0 / 0 / 0". A player
  with no venue data shows no Venue section.
- P-P4. Every number that is a rate (Avg, SR, Econ) shows 1–2 decimals,
  consistently. No "45.600000".
- P-P5. Tapping a matchup bowler → that bowler's profile.

### 4.4 Compare (side-by-side — Crex/Cricmetric pattern)

```
[Player A picker ▼]   VS   [Player B picker ▼]
[A avatar + name]          [B avatar + name]
[tap name → profile]       [tap name → profile]
Source: … (one line, both players' sources)

        A              Stat              B
      27,150           Runs           19,241
       45.6           Average          42.1
       78.8         Strike Rate        88.4
      48 / 112      100s / 50s       32 / 98
     2715 / 400    Fours / Sixes    1980 / 310
        183           Highest          264
        523           Matches          401
  ── Winner highlight: better value in gold per row ──
  ── Same for Bowling: Wkts • Econ • Avg • Best ──
```

**Rules:**
- C1. Pickers must never go stale (known V2 review bug: Dropdown stale
  value). If a player list reloads, selected IDs re-validate.
- C2. Add Bowling comparison (currently batting-only) — Cricmetric
  compares both disciplines.
- C3. Per-row winner highlighted in gold. Draws = no highlight.
- C4. Compare respects the same source labelling as Profile (P7).

### 4.5 Stats / Leaders (Cricinfo Rankings + Crex Series Stats pattern)

```
Tabs or chips: [Batting] [Bowling] [All-round]  +  Format filter: [All | Test | ODI | T20 | T10]
Sections (each ranked 1..N, tappable → profile):
  Most Runs — name • team • runs
  Best Average (min 10 innings — state the qualifier!)
  Best Strike Rate (min 10 innings)
  Most Wickets — name • team • wkts
  Best Economy (min 10 overs)
  Most 100s / Most 50s / Most Sixes
```

**Rules:**
- S1. Every average/SR/economy leaderboard STATES its minimum qualifier
  ("min 10 innings"). A 1-match average of 200 must never top the board.
- S2. Stats are derived from the loaded player list — never hard-coded.
- S3. Format filter actually filters (currently Stats has no format
  filter — add it, per Cricinfo Statsguru).

### 4.6 Leagues / Series (Crex Series pattern)

```
Chips (horizontal scroll): [IPL] [PSL] [Big Bash] [T10] [Ranji] [SMAT] [Vijay Hazare]
  [Women's] [U19] [International] [All]
For the selected league:
  ── Series info: name • dates • format • teams ──
  ── Points Table (when the source provides it) ──
  ── Top Players (top 3 runs + top 3 wickets in this league) ──
  ── Matches (Live first, then Upcoming, then Recent — same card as Home) ──
Empty: "No <League> matches yet." + what will fill it (never a dead end).
```

**Rules:**
- L1. Each league shows ONLY its own matches (current behaviour — keep).
- L2. League chips include Women's + U19 + all domestic (user: "sab means
  sab kuch") — even if a league currently has no data, the chip exists
  and its empty state explains why.
- L3. Reuse the Home match card (one card component, two places), not a
  second, diverging `ListTile` card.

### 4.7 Favourites + Notifications (Cricbuzz/Crex pattern)

```
[Notifications ON/OFF]  — "Alerts for your favourite players and teams"
Favourite Teams: [⭐ India] [⭐ Mumbai Indians] …  (add: currently players only)
Favourite Players: list, each with ⭐ toggle, tappable → profile
Empty: "Tap ⭐ on any player or team to follow them here."
```

**Rules:**
- F1. Add favourite TEAMS (currently players only) — the user asked for
  "favourite team/player".
- F2. The notifications toggle gates real alerts; it must not claim to
  send FCM pushes when none are wired (currently no FCM — label it
  "Local reminders (push coming soon)" until FCM lands, or wire FCM).
- F3. Favourited teams/players surface their matches at the top of Home
  (Crex PIN behaviour) — or at least filter to them from Favourites.

### 4.8 Global rules (apply to every screen)

- G1. **One source of truth for status, team names, and scores.** Parse
  once (`resolveStatus`, `cleanTeamName`, `titleCaseTeam`); every screen
  reads the parsed model. No screen re-parses a string.
- G2. **No silent zeros.** `0` shown only when the source genuinely says
  0. Missing data = section hidden + source line explains why.
- G3. **Hindi parity.** Every user-facing string exists in EN + हिं.
  No mixed-language screen.
- G4. **Offline behaviour.** No network → last verified cache + "Offline
  — showing last verified data" banner. Never a crash, never an infinite
  spinner.
- G5. **Performance.** Home list must render in < 1s on a mid phone.
  No `FutureBuilder` that re-fires on every build (known V2 review bug:
  futures recreated every build → quota burn + flicker). Cache the
  future in `initState`.
- G6. **Accessibility.** Minimum tap target 48dp, text never below 11sp
  for body, colour never the ONLY signal (LIVE pill has text + dot,
  not dot alone).

---

## 5. KingCric differentiation — what stays King, what goes reference

**Keep (King identity — this is the brand):**
- Navy `#0B1026` + gold `#D4AF37` + gold gradients, gold borders,
  crown mark. This is the one visual thing KingCric owns; Cricbuzz is
  green, Cricinfo is blue/red, Crex is blue. Navy+gold is distinct.
- Tagline "Har Ball, Har Stat, King Jaisa."
- Premium surfaces: gradient hero cards, GoldDonut, StatBar, KingAvatar
  gold-ring initials. These are good — they are the "not boring" layer.
- Prediction with a plain-language WHY line (Cricmetric-style) — none of
  the references does this as clearly for a casual fan. This is a real
  differentiator if the explanation stays honest.

**Adopt (reference layout — this is usability):**
- The card, table, and tab structures in §4 — exactly as the references
  do them. Do not redesign the scorecard layout; the scorecard layout is
  solved. Innovation belongs in the analytics (venue, matchup,
  prediction), not in moving the R/B/4s/6s columns around.
- Cricbuzz's "check in 2 seconds" Home hierarchy: Live → score →
  equation → tap. KingCric's current Home already aims at this; the
  reference spec tightens it (H1–H10).
- Crex's clarity: "small to big unique stats shown clearly with
  numbers" + one-line explanations. Every KingCric analytics block
  gets a one-line "what this means" caption.
- Cricmetric's honesty about models: win probability / prediction always
  labelled as a model with its inputs, never as a fact.

**Drop:**
- Ad placeholder boxes, "Complete" badges on partial data, any
  developer-facing text, any second/diverging card or table layout.

---

## 6. Data-source honesty map (which number comes from where)

| Data | Source | Label shown to user | Freshness |
|---|---|---|---|
| Live scores, live scorecard | CricAPI (primary), EliteSport (secondary) | `Real • CricAPI • live` | 10-min cache (free-tier limit) — shown as "Last updated HH:MM" |
| Backstop scores | SportScore | `Real • SportScore` | Same cache |
| Schedules, badges, bios | TheSportsDB | `Real • TheSportsDB` | 60-min cache |
| Deep player stats (career / vs opp / venue / matchup / dismissal) | Cricsheet open data, calculated by KingCric | `Real • Cricsheet open data • N matches in dataset` | Static per bundled dataset; grows when dataset refreshes |
| Sample / curated numbers (where a source is missing) | Mock / curated | `Demo data — curated sample, not live-verified` | Never presented as real |
| Prediction | KingCric model (form 30% + vs opp 25% + venue 20% + matchup 15% + pitch 10%) | `Model • not a guarantee` + inputs | Recomputed on open |

**Rule:** A screen never mixes two sources without saying so. If a
profile mixes Cricsheet career + CricAPI live form, it says both.

---

## 7. Top 5 fixes KingCric must do to match the reference apps

These are ordered by user-visible damage (worst first). The parallel
V3-fix commit `17ce998` already covers #1–#3 at the parse/UI layer;
the redesign must KEEP those and finish #4–#5, then re-verify all five
against this spec.

1. **One status truth (P1).** `resolveStatus()` at parse time from
   start/end + scores + result text; Home filter, card pill, and detail
   header all read it. Delete the UI-layer `isEffectivelyLive` bandage
   as the source of truth (keep it only as a defensive fallback, never
   as the thing the filter keys on). **Acceptance:** the Austria W
   screenshot case — a match with scores and no result — appears under
   Live with a LIVE pill, never under Upcoming.
2. **Structured team/score rows (P3/P4).** One `TeamScore` per team per
   innings; team names cleaned + title-cased once at parse; inning
   label separate from team name. **Acceptance:** no `","` in any team
   name, no lowercase team, no "Inning 1" inside a name, ever.
3. **No truncation, no dev text (P5/P9).** FittedBox app name, no-wrap
   tabs, 2-line fixture titles, horizontal-scroll tables + swipe hint,
   AdPlaceholder renders nothing without an AdMob ID. **Acceptance:**
   the three V3 screenshots render with every string fully readable.
4. **Honest source labels (P7).** Every stats block carries its source
   line; "Complete" appears ONLY for a genuinely full-career dataset.
   Trending/Stats/Compare use the same labelling as Profile.
   **Acceptance:** no screen shows "Complete" on demo/curated data;
   Cricsheet profiles state their dataset size.
5. **Make names tappable + finish Compare/Stats/Leagues/Favourites
   (P12, §4.4–4.7).** Scorecard/squad/leaderboard names → profile;
   Compare gains bowling + per-row winner highlight + stale-picker fix;
   Stats gains format filter + min-qualifier labels; Leagues reuses the
   Home card + gains points table / top players / Women's + U19 +
   domestic chips; Favourites gains teams + honest notification
   labelling. **Acceptance:** every player name in the app is tappable;
   no dead text.

---

## 8. 20-point "user opens app and immediately understands" checklist

Run this on a real phone, on the release APK, before shipping. ALL 20
must pass. A single fail = do not ship.

1. [ ] App opens to Home in < 2s, no crash, no blank screen.
2. [ ] Header reads **KingCric** in full (never "King…"), EN/हिं toggle visible.
3. [ ] Default tab is **Live**. If a live match exists, it is the first card.
4. [ ] Every Live card has a red **LIVE** pill + pulsing dot + the biggest bold score on the card.
5. [ ] Every Live card shows "need X from Y balls" (chase) or current equation — never a "need" line on a completed match.
6. [ ] No live score ever appears under an UPCOMING pill, and no upcoming match ever appears under Live.
7. [ ] Every team name is Title Case, one team per row, no commas joining two teams, no "Inning 1" inside a name.
8. [ ] Every fixture title is fully readable (max 2 lines, no mid-word cut).
9. [ ] Tabs read **Live / Upcoming / Recent** in full, on one line each, in both EN and हिं.
10. [ ] Search finds a team/league/player and shows a clear "No matches found for '…'" when nothing matches.
11. [ ] Pull-to-refresh updates scores; "Last updated HH:MM" is visible.
12. [ ] Tapping a match opens Match Detail with the SAME score + status as the card.
13. [ ] Match Detail Scorecard shows Batting → Extras → Bowling → FOW → Partnerships → Yet-to-bat, in that order, with swipe hint on tables.
14. [ ] Tapping any player name (scorecard / squad / trending / stats / compare) opens that player's profile.
15. [ ] Player Profile shows Runs/Avg/SR/Wkts without scrolling, then Overall → vs Opponent → Format → Full Table → Leagues → Venue → Form → Matchup → Dismissal → Bowling, with a source line under the hero.
16. [ ] No screen shows "Complete" on demo/curated data; every stats block carries a source label (Real/Demo + provider + dataset size where relevant).
17. [ ] No "Ad placeholder", "TODO", or developer text anywhere in the release build.
18. [ ] Compare shows batting AND bowling, highlights the per-row winner, and pickers never go stale.
19. [ ] Stats shows format filter + min-qualifier labels ("min 10 innings"); Leagues shows Women's + U19 + domestic chips; Favourites has teams + players.
20. [ ] In Hindi mode, EVERY label (tabs, pills, empty states, buttons) is Hindi — no mixed-language screen.

---

## 8A. ADDENDUM — CricketLineX / "Just Cricket: Fast Live Score" (user-named PRIMARY reference)

**User-named reference:** https://play.google.com/store/apps/details?id=com.cricketLineX.CricketLineX
— the app now rebranded as "Just Cricket: Fast Live Score" (previously
Cricket LineX), "Trusted by 15 million cricket fans". This is the
reference the user pointed at directly, so it outranks the generic
research in §1–§5 where the two conflict. Treat CricketLineX as the
primary model for **speed + layout**, and Cricinfo/Cricmetric as the
model for **depth**.

**What CricketLineX promises (from its Play Store listing, verbatim
substance — not from an installed teardown, see §9):**
- "Fastest cricket live score updates in India — ball-by-ball, updated
  instantly", "one step ahead of every ball", "faster than TV".
- Real-time score + ball-by-ball commentary (smart, clear, instant) +
  full live scorecard (batting + bowling breakdown) + live line &
  match graphs (deep over-by-over analysis).
- Smart notifications: wickets, sixes, match start, milestones.
- Fantasy cricket points — live player performance tracking (Dream11-style).
- Playing XI, squads & pitch report — full match preview.
- Head-to-head stats & ICC rankings; historical records & stats
  (legendary innings, milestones, all-time player/team stats).
- News & video updates (headlines, interviews, short highlight clips).
- Dark mode + light mode.
- Coverage: IPL, T20 WC, ODI WC, Champions Trophy, WTC, Asia Cup, BBL,
  PSL, SA20, ILT20, BPL, CPL, The Hundred, Ranji Trophy, County
  Championship, all international tours + domestic.
- Navigation (from its own listing): **Home tab with trending matches;
  Live / Upcoming / Finished matches; Series tab with points table &
  squads; quick navigation for IPL live matches.**
- Disclaimer on the listing: strictly informational/entertainment, no
  betting/gambling. KingCric must carry the same kind of line if it ever
  shows odds/win-probability (see below).

**What this changes for KingCric (add to §4–§5, do not replace them):**
- **L1 — Speed is the headline.** CricketLineX sells ONE thing first:
  fastest. KingCric's Home must therefore lead with the live score in
  the biggest type, with an explicit freshness signal ("Last updated
  HH:MM", pull-to-refresh, manual Refresh). Free-tier 10-min caching
  must be disclosed honestly (P7) — KingCric cannot claim
  "faster than TV" on a 100-hits/day free tier, and must not fake it.
- **L2 — Home = Trending + Live/Upcoming/Finished.** CricketLineX's
  exact Home structure is: trending matches on top, then the
  Live / Upcoming / Finished split. KingCric's current
  Live / Upcoming / Recent tabs already match this — keep the three-tab
  model, rename "Recent" → **"Finished"** to match the reference
  wording users recognise (Recent = ambiguous; Finished = done).
- **L3 — Match page = Preview + Live + Scorecard + Graphs.** Every
  match, even an upcoming one, gets: Playing XI + squads + pitch report
  (+ weather where available) + H2H BEFORE it starts; then live score +
  commentary + scorecard + over-by-over graph while live. KingCric's
  Match Detail currently has Live | Scorecard | Squad | Prediction —
  add **Preview/Info** (pitch, weather, toss, Playing XI) and an
  **Overs/Graph** view (runs-per-over + wickets, i.e. the "live line &
  match graphs" piece) — both are cheap to build from data KingCric
  already holds (innings overs + FOW).
- **L4 — Fantasy points (live).** CricketLineX shows live fantasy
  points per player. KingCric should add a simple, documented fantasy
  points line per player in the live scorecard/squad (e.g. runs + 4s/6s
  bonus + wickets + catches, formula shown in the spec's data section).
  Do NOT invent a Dream11-official formula — label it "KingCric fantasy
  points (unofficial)".
- **L5 — Notifications = wickets, sixes, milestones, match start.**
  Match the exact event list (not generic "match notifications").
  Until FCM is wired, label honestly (see F2).
- **L6 — Records & ICC rankings.** Add a Records section (highest
  totals, legendary innings, most runs/wkts in the loaded dataset) and
  an ICC-rankings view to Stats. Rankings need a source — if no free
  provider returns ICC rankings, show dataset-derived leaders and say
  so; never present dataset leaders as ICC rankings.
- **L7 — Dark + Light mode.** CricketLineX supports both. KingCric is
  dark-only today. Add a Light mode toggle (or record it as a V-next
  item) — do not claim it until it exists.
- **L8 — Disclaimer.** If KingCric shows win probability / prediction,
  carry a short line: "For information & entertainment only. Not
  betting advice." — matching the reference's disclaimer posture.

**CricketLineX vs the other references (how to combine):**
- CricketLineX = the **Home + Match page skeleton** (speed, Live /
  Upcoming / Finished, trending, graphs, fantasy points).
- Cricinfo = the **Player Profile + Statsguru depth** (format splits,
  vs-opponent, career tables).
- Cricmetric = the **analytics honesty** (win-probability graph with
  inputs, venue/H2H charts, model labelled as model).
- Crex = the **clarity** (one-line explanations, simple numbers).
- KingCric's job = CricketLineX's skeleton + Cricinfo depth +
  Cricmetric honesty + Crex clarity, in navy + gold.

## 9. What is still open (do not claim as done)

- **Hands-on teardown of installed reference apps.** As noted at the
  top: this spec is from public web research + code audit. The user's
  follow-up — "download existing market apps and thoroughly extract all
  their things" — needs a live-browser / device session that can install
  APKs, drive the apps, and screenshot each screen (Cricbuzz Home,
  Cricbuzz match detail, Crex match detail + win-probability meter,
  Cricinfo player profile + Statsguru, Cricmetric player + venue pages,
  Sofascore match page). That session should verify §4 against real
  screens and amend this spec where the real apps differ from the public
  descriptions.
- **Reference-spec + V3-fix merge.** Local commit `17ce998` (V3 bug
  fixes) is unpushed. The redesign must be built ON TOP of it, then
  pushed once, then built once — per the user's "baar baar na banana
  pade" rule.
- **Live-data verification on a phone.** CricAPI key is in GitHub
  Secrets; the live path has not yet been verified end-to-end on the
  user's GT 6T (live match under Live tab, with correct pill + scores).
  Checklist items 3–6, 11–12 are the acceptance test for that.
