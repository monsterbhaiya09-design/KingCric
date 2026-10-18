# KingCric — PRODUCT SPEC
## Google-style product definition: vision, users, journeys, metrics, backlog, acceptance criteria

**Date:** 2026-10-18
**Author role:** Product Manager (Google-style)
**Status:** READ-ONLY product work — no code edited. This doc is the single source of truth for *what* KingCric must be and *what counts as done*. Engineering docs own the *how*.
**Companion docs (all in `~/workspace/cricket-app/kingcric/`):**
- `REFERENCE-SPEC.md` — 12 non-negotiable patterns + per-screen MUST-show specs + 20-point checklist
- `REFERENCE-APPS-DEEP-DIVE.md` — Cricbuzz / Cricinfo / CREX / Cricmetric / CricketLineX / SofaScore deep dive
- `CRICKETLINEX-REFERENCE.md` — primary reference (user pick): Just Cricket: Fast Live Score
- `REQUIREMENTS-MAPPING.md` — every KingCric requirement × every reference app, gaps = KingCric moat
- `PLAYER-DATA-EXTRACTION.md` — how reference apps extract + arrange player data
- `PREMIUM-SMOOTH.md` — premium design system + smoothness checklist
- `API-SETUP.md`, `MULTI-API.md`, `CRICSHEET-DATA.md` — legal data sources + quota + calculation

**Honest scope notes (carry over from companion docs, do not re-litigate):**
- Reference analysis is from **public sources only** (Play Store listings, AppBrain, official sites, reviews). No reference APK was downloaded/installed/run/decompiled by a subagent; no code, text, images, branding, or data was copied; no private API was scraped. Details that could not be verified from public text are `[inferred]` in the source docs.
- **No scraping** of Cricbuzz / Cricinfo / Cricmetrics. KingCric uses only legal sources: official free APIs (CricAPI / CricketData.org primary, EliteSport secondary, EntitySport API tertiary, SportScore backstop with attribution, TheSportsDB metadata) + Cricsheet open data calculated by KingCric itself.
- The user decided: *"jo sahi lage sara and real data ho bas sab kuch ho"* — do whatever is right, all real data, everything should be there. And: *"unki files nikal ke teko unke codes use nahi karne hai"* / *"bas samajhna hai ki kaise banaya gaya hai taki tu ek hi kaam baar bar galat na kare and uske baad tu hamare app ko hamare hisab se hi banayega"* — study to understand, never use their codes, then build OUR app OUR way.

---

## 1. Vision

### 1.1 One-sentence vision

> **KingCric = Cricbuzz's speed + Crex's clarity + Cricinfo's depth + Cricmetric's analytics, in a King (navy + gold) skin — and every number instantly readable in 2 seconds on a phone, in Hindi or English.**

### 1.2 Tagline

> **"Har Ball, Har Stat, King Jaisa."**

### 1.3 What KingCric is — and is not

| KingCric IS | KingCric IS NOT |
|---|---|
| A **check** app first (glance → score → done in 2 sec), deep on demand | A news / video / quiz / fantasy-tips feed that buries the score |
| A **trust** app: every number carries a source label (Real / Demo / Partial) | An app that asks for blind trust or labels curated/demo data "Complete" |
| **Full version for every user**, no paywall on scorecard / stats / compare / prediction | A "full for paying users" app (CREX PIN, Cricbuzz Plus, LineX Premium patterns) |
| **Legal + stable**: official free APIs + Cricsheet open data, own code | A scraper / clone: no copied code, assets, feeds, or data from any reference app |
| **King identity**: navy `#0B1026` + gold `#D4AF37`, crown + bat-ball logo | A generic blue/white clone of CricketLineX |
| **₹0 to build**; earnings later from usage / AdMob banner only | An app that spends the user's money or gates features behind payment |

### 1.4 The user's test (the only test that matters)

> **"Kholte hi samajh aa jaye — kaunsi match live hai, score kya hai, kaun jeet raha hai, kis player ka kya haal hai."**
>
> If the first screen needs thinking, the app has already failed — no matter how many features exist underneath.

### 1.5 Why KingCric wins (positioning vs the references)

| Reference | What it owns | Where it loses | KingCric's answer |
|---|---|---|---|
| Cricbuzz (240M installs) | Speed, reach, grouped match list, hero score | Ad density, paywalled Fantasy Handbook, India bias | Same speed-perception, no ad-on-resume, no paywalled scorecard |
| ESPNcricinfo (10M+, 4.8★) | Depth, Statsguru (format × opponent × venue × home/away × result) | Cluttered menu, query-builder (user does the work) | Same depth **pre-computed** on profile/match screens — user never builds a query |
| CREX (100M+, 4.36★) | Clarity, win-% meter, format chips, "everything is simple" | Heavy data, intrusive ads, Premium-gated PIN/graphs | Same clarity + visible win-% + honest model, FREE, no Premium gate |
| Cricmetric | Rigorous analytics (XGBoost, monotone, range, backtest) | Academic tone, no live app, query tool not profile section | Same rigour as *profile sections* (matchup, venue, dismissal) + plain-language WHY |
| CricketLineX / Just Cricket (15M, #8 Top Free Sports India, user pick) | Fastest-live brand, Live/Upcoming/Finished, trending, graphs, fantasy points, 25 MB | 17% 1★ tail (ads on every resume + wrong status), "Limited player statistics", 19–26 permissions | Same skeleton + **deeper player analytics** + honest labels + 2 permissions + no ad-on-resume |
| SofaScore | Generic compare, multi-sport polish | Cricket depth thin, not cricket-first | Cricket-first compare with vs-opponent / venue / matchup depth |

**KingCric's moat (things NO reference app does well — from REQUIREMENTS-MAPPING §2):**
1. Dismissal history as a profile section (`"c X b Y — N times"` + `"Not dismissed by Z in N balls"`)
2. Bowler-vs-batter matchup as a profile section (not a query tool)
3. Match-context squad view (each squad row already shows vs-opponent + format + combined + form + prediction)
4. Side-by-side Player Compare as a first-class screen (batting + bowling, per-row winner)
5. Per-player venue records pre-computed (current venue first)
6. Honest source labels + visible completeness (never "Complete" on partial data)
7. T10 as a first-class format chip; U19 as a first-class filter
8. Full version for every user, no paywall, lean permissions (2 vs LineX 19–26), no ad-on-resume
9. King identity + **Hindi parity in ONE app** (every label in Hindi, never mixed)

---

## 2. Users (personas)

KingCric serves three personas. Every feature must state which persona(s) it serves; a feature serving none is cut.

### 2.1 Persona 1 — The Checker (casual fan) — PRIMARY

| Field | Detail |
|---|---|
| Who | Follows 1–3 teams (e.g. India + MI + RCB). Checks the score 10–30× a day during a match, mostly on a mid-range Android phone, often on mobile data, often at night. |
| Goal | "Score kya hai? Kaun jeet raha hai?" in 2 seconds, then back to life. |
| Behaviour | **Two-pass usage** (observed in CricketLineX reviews): glance at score first, commentary only if the match state raises a question. Commentary rebuilds context after returning, not read ball-by-ball. |
| Frustrations | App opens to news/videos instead of score; live match hidden under Upcoming (KingCric V3 bug); ad on every resume; status says "not started" for a completed match; score truncated ("Bulgaria Women,Sweden Wo…"). |
| What wins them | Home = Live first, biggest bold score, LIVE pill + pulse, equation ("need 88 in 78"), "Last updated HH:MM", pull-to-refresh, no ad placeholder, no fake chrome. |
| Success looks like | Opens app → sees live score in ≤2 sec → closes app happy. Returns next ball. |

### 2.2 Persona 2 — The Fantasy Player (Dream11 / fantasy user)

| Field | Detail |
|---|---|
| Who | Plays fantasy (Dream11 etc.), picks XI before toss, tracks live fantasy points during the match. |
| Goal | "Kaun chalega aaj? Kis ko pick karu? Live me kaun points de raha hai?" |
| Behaviour | Pre-match: Playing XI + pitch + weather + H2H + form + matchup. Live: player impact + points. Post-match: what went right/wrong in picks. |
| Frustrations | No "who will fire" prediction; matchup hidden behind a query builder; fantasy points made up / no formula shown; paywalled fantasy tips (Cricbuzz Plus). |
| What wins them | Match Detail → Squad with context lines + Prediction tab ("Who will fire?" — score + Likely/Risky/Unlikely + ONE Hindi/English WHY line + inputs shown + "Model • not a guarantee"). KingCric fantasy points **only if** a real provider supplies them — **do NOT fake** a Dream11-official formula; label "KingCric fantasy points (unofficial)" if added, with formula shown. |
| Success looks like | Picks XI from KingCric's squad context + prediction, checks live impact, trusts the WHY line more than a bare %. |

### 2.3 Persona 3 — The Stats Nerd (analyst / deep fan)

| Field | Detail |
|---|---|
| Who | Wants to *study* cricket: Statsguru-style filters, venue records, dismissal history, bowler-vs-batter, H2H, career splits. Often a second-screen user during a match. |
| Goal | "Virat vs Pakistan, T20, Eden Gardens — kaisa hai? Bumrah ne Babar ko kitni baar out kiya? Kis ground pe chase hota hai?" |
| Behaviour | Opens player profile, reads tables top-to-bottom, compares two players, checks venue/H2H before arguing with friends. |
| Frustrations | Statsguru makes them build every query; no app aggregates dismissal history; "Limited player statistics" (CricketLineX complaint); curated numbers presented as "Complete" with no dataset size. |
| What wins them | Player Profile fixed order (see §4.3) with pre-computed splits; Dismissal History + Matchup as first-class sections; Compare side-by-side with bowling + winner highlight; venue rows pre-computed; source label with dataset size on every block. |
| Success looks like | Finds "Bumrah vs Babar: 1 dismissal" and "c X b Y — N times" without building a query, and trusts it because the source + dataset size are shown. |

### 2.4 Non-persona (explicitly out of scope for v1)

- Betting / odds users: KingCric shows prediction as a **model**, with "For information & entertainment only. Not betting advice." No odds, no betting links, no gambling features.
- News/video consumers: News & video updates exist in CricketLineX but are **not** on KingCric Home v1 — they dilute the check screen. They belong in a later "News" tab, not in the way of the score.

---

## 3. User journeys (end-to-end, with acceptance per journey)

Each journey lists: entry → steps → exit → what must NEVER happen. Journeys are the acceptance tests for the backlog in §5.

### J1 — Open app → live match in 2 seconds (Checker, PRIMARY journey)

| Step | Screen | What the user sees / does |
|---|---|---|
| 1 | Home | App opens to Home in <2s, no crash, no blank screen. Header reads **KingCric** in full + EN/हिं toggle. |
| 2 | Home | Default tab = **Live**. If a live match exists, it is the first card: red LIVE pill + pulsing dot, biggest bold score, equation ("need 88 in 78 balls"), venue, current batters/bowler, "Tap for FULL scorecard". |
| 3 | Home | If NO live match: "No live matches right now." + next upcoming match card directly below (never a dead blank screen). |
| 4 | (Optional) | Pull-to-refresh updates scores; "Last updated HH:MM" visible; manual Refresh button always visible. |
| Exit | — | User knows the score and closes the app, or taps the card → J2. |

**Must NEVER happen:** Live match under Upcoming pill; Live tab "No matches" while a live match exists; score truncated; ad placeholder; full-screen spinner on refresh; status pill contradicting the filter.

### J2 — Tap match card → full scoreboard + context (Checker → Fantasy)

| Step | Screen | What the user sees / does |
|---|---|---|
| 1 | Match Detail | Lands on Scorecard/Live tab with hero score visible **without scrolling**. SAME score + status as the card (M1: Live tab and Scorecard tab never disagree). |
| 2 | Match Detail — Live tab | Hero score + equation + target/equation bar + H2H bar + Match Info (venue / toss / umpires / referee / pitch) + commentary (newest first). |
| 3 | Match Detail — Scorecard tab | Per innings, in P6 order: Batting (Batter + dismissal \| R \| B \| 4s \| 6s \| SR) → Extras → Bowling (Bowler \| O \| M \| R \| W \| Econ \| Wd \| Nb) → Fall of Wickets (numbered) → Partnerships → Yet-to-bat. "↔ Swipe sideways for all columns" hint on wide tables. |
| 4 | Match Detail — Squad tab | Team A (XI + bench) + Team B, each player row tappable → profile, with context line `"vs <Opponent> • <Format>"`. |
| 5 | Match Detail — Prediction tab | "Who will fire?" — one card per squad player, sorted by score desc: Name • Score 0–100 • Likely/Risky/Unlikely + ONE WHY line + "Model • not a guarantee". No-data → "Not enough data", never a fake 0–100. |
| Exit | — | User taps a player name (anywhere) → J3, or taps Compare → J4, or goes back to Home. |

**Must NEVER happen:** Scorecard names as plain (non-tappable) text; Extras/FOW/Partnerships hidden or reordered; a "need X" line on a completed match; a score on an upcoming card; prediction without inputs/explanation.

### J3 — Tap player → full profile (Stats Nerd, PRIMARY deep journey)

| Step | Screen | What the user sees / does |
|---|---|---|
| 1 | Player Profile — Hero | Avatar initials (gold ring) + Name + Role • Team • Country + Batting/Bowling style. **Source line directly under identity** (e.g. `"Real • Cricsheet open data • 4 matches in dataset"` or `"Demo data — curated sample, not live-verified"`). Quick stats row (Runs \| Avg \| SR \| Wkts) visible without scrolling. |
| 2 | (If opened from a match) | Prediction card: vs `<Opponent>` at `<Venue>`, `<Format>`. |
| 3 | Profile — sections in FIXED order | Overall (all formats) → vs Opponent (`<Opponent>`) → Format-wise (`<Format>`) → All Formats Full Table (horizontal scroll: Format \| M \| Runs \| Avg \| SR \| 100s \| 50s) → Leagues (one row per league) → Venue records (one row per venue, current venue first) → Recent Form (last 5) → Matchup (bowler-vs-batter) → Dismissal History → Bowling Full Table. |
| 4 | Profile — Matchup | One row per bowler: `Bowler • Matches • Dismissals • Runs • Balls • SR`, sorted by dismissals desc. Tapping a matchup bowler → that bowler's profile. |
| 5 | Profile — Dismissal History | Most frequent first: `"c X b Y — N times"` + `"Not dismissed by Z in N balls"` (≥12 balls, 0 dismissals). |
| Exit | — | User taps a matchup bowler → that profile; or taps Compare → J4 with this player pre-selected; or goes back. |

**Must NEVER happen:** "Complete" on demo/curated data or on a 4-match sample; empty sections shown as "0 / 0 / 0" (hidden instead, with source line explaining why); rates shown with >2 decimals ("45.600000"); generic career table without the opponent filter when opened from a match.

### J4 — Compare 2 players side-by-side (Stats Nerd + Fantasy)

| Step | Screen | What the user sees / does |
|---|---|---|
| 1 | Compare | Two pickers `[Player A ▼] VS [Player B ▼]` + avatars + names (tappable → profile) + one source line covering both players. |
| 2 | Compare — Batting | Same rows for both: Runs / Average / Strike Rate / 100s-50s / Fours-Sixes / Highest / Matches. Per-row winner highlighted in gold; draws = no highlight. |
| 3 | Compare — Bowling | Same treatment: Wkts / Econ / Avg / Best / Matches. (V3 was batting-only — bowling is P0.) |
| 4 | Compare — Depth rows | Vs-opponent + venue + matchup rows where data exists (same source labelling as Profile). |
| Exit | — | User taps a name → J3 for that player. |

**Must NEVER happen:** Pickers going stale on list reload (known V2 bug); batting-only compare; no winner highlight; no source labels.

### J5 — Favourite team/player → notifications (Checker + Fantasy)

| Step | Screen | What the user sees / does |
|---|---|---|
| 1 | Anywhere | Taps ⭐ on a player / team / match → persisted (survives restart). |
| 2 | Favourites | `[Notifications ON/OFF]` + "Alerts for your favourite players and teams" + Favourite Teams list + Favourite Players list (each row ⭐ toggle, tappable → profile). Empty: "Tap ⭐ on any player or team to follow them here." |
| 3 | Favourites — Notification granularity | Per-match toggles: Wickets / Sixes / Match start / Milestones / Result — opt-in, selective, never noisy by default. |
| 4 | Home | Favourited matches pinned to top of Home (CREX PIN behaviour, **FREE** — never Premium-gated). |
| Exit | — | User receives only the events they opted into. |

**Must NEVER happen:** Favourites = players only (teams required); toggle claiming FCM pushes when none are wired (label "Local reminders (push coming soon)" until FCM lands); noisy-by-default notifications; Premium-gated PIN.

### J6 — Browse leagues / series (Checker + Stats Nerd)

| Step | Screen | What the user sees / does |
|---|---|---|
| 1 | Leagues | Chips (horizontal scroll): `[IPL] [PSL] [Big Bash] [T10] [Ranji] [SMAT] [Vijay Hazare] [County] [Sheffield Shield] [Women's] [U19] [International] [All]` |
| 2 | Leagues — Selected league | Series info (name • dates • format • teams) → Points Table (P/W/L/PTS/NRR; "Table not available" honestly when absent) → Top Players (top 3 runs + top 3 wickets in this league) → Matches (Live first, then Upcoming, then Recent — **same Home card component**, not a second card). |
| 3 | Leagues — Empty | `"No <League> matches yet."` + what will fill it (never a dead end). Chip exists even with no data. |
| Exit | — | User taps a match → J2; taps a player → J3. |

**Must NEVER happen:** League showing another league's matches; a second, diverging match-card layout; a league chip missing (Women's/U19/domestic must all exist as chips); a fake points table.

### J7 — Browse stats / leaders (Stats Nerd)

| Step | Screen | What the user sees / does |
|---|---|---|
| 1 | Stats | Chips: `[Batting] [Bowling] [All-round]` + Format filter `[All | Test | ODI | T20 | T10]` (actually filters — V3 had no format filter). |
| 2 | Stats — Sections | Each ranked 1..N, tappable → profile: Most Runs / Best Average (min 10 innings — qualifier stated) / Best Strike Rate (min 10 innings) / Most Wickets / Best Economy (min 10 overs) / Most 100s / Most 50s / Most Sixes. |
| 3 | Stats — Records (P1, per CricketLineX addendum) | Records section: highest totals, legendary innings, most runs/wkts in the loaded dataset. Dataset-derived leaders labelled as such — **never** presented as ICC rankings unless a free provider returns ICC rankings. |
| Exit | — | User taps a name → J3. |

**Must NEVER happen:** A 1-match average of 200 topping the board (min-qualifier required); stats hard-coded instead of derived from the loaded player list; no format filter.

### J8 — Switch language EN ↔ हिं (all personas)

| Step | What happens |
|---|---|
| 1 | User taps EN / हिं toggle in the Home header. |
| 2 | **EVERY** label switches: tabs, pills, empty states, buttons, prediction WHY lines, section headings, error states. |
| 3 | No mixed-language screen (e.g. no "Upcomin g" + Hindi mix; no English pill on a Hindi screen). |

**Must NEVER happen:** Mixed-language screen; toggle that only switches the header.

---

## 4. Feature specs (what each screen MUST show — condensed from REFERENCE-SPEC §4)

> Full per-screen MUST-show specs with text mockups live in REFERENCE-SPEC §4. This section is the PM's condensed, shippable version — same rules, no new rules. If the two conflict, REFERENCE-SPEC wins on layout, this doc wins on priority.

### 4.1 Home (the "check" screen — most important screen)

- **Goal:** 2-second answer: which matches are live, score, who is winning.
- **Layout (exact order):** Header (👑 KingCric + EN/हिं) → Search → `[Live] [Upcoming] [Finished]` (one row, never wraps, selected = gold pill; "Recent" renamed → **"Finished"** per CricketLineX) → Live cards (if any) → Upcoming / Finished cards → Trending Players (top 4, rule stated, tappable, source-labelled) → "Last updated HH:MM" + Refresh under the tabs.
- **Card contents (exact order):** status pill + `League • Format` → fixture title (max 2 lines) → venue (1 line, ellipsis) → ONE row per team: `Team Name` (left, 1 line) + `score` (right, bold gold) → ONE result/equation line (live: "need X from Y"; result: "X won by …"; upcoming: "Starts: …") → current batters/bowler (live only) → "Tap for FULL scorecard".
- **Rules:** Default tab = Live. Upcoming card shows NO score rows (or "Yet to bat" only). Recent/Finished card shows BOTH scores + final result line. Search filters the CURRENT tab (empty → "No matches found for '…'"). Pull-to-refresh re-fetches. Demo mode = ONE amber banner at top ("Demo data — connect a free API key for live scores"), not repeated on every card. NO ad placeholder. NO news/videos/quizzes/fantasy tips on Home v1.
- **Bottom nav:** `[Home] [Leagues] [Compare] [Stats] [Favourites]` — one tap to each; Home → Live → Scorecard path as short as CricketLineX's.

### 4.2 Match Detail (the "read" screen — depth lives here)

- **Tabs (this order, always):** `Live | Scorecard | Squad | Prediction` (+ Preview/Info + Overs/Graph per REFERENCE-SPEC §8A L3 — Preview/Info = pitch + weather + toss + Playing XI; Overs/Graph = runs-per-over + wickets from innings overs + FOW).
- **Live tab:** Hero score + equation + target/equation bar + H2H bar + Match Info (venue / toss / umpires / referee / pitch) + commentary (newest first, each entry = over/ball + text; empty = "No commentary available.", never a spinner forever).
- **Scorecard tab (P6 order, never reordered):** Header (Title • League • Format • Venue • Toss • Umpires) → per innings: `"Team — total/wkts (overs) • Innings N"` → BATTING (Batter + dismissal \| R \| B \| 4s \| 6s \| SR; not-out highlighted + `*`) → TOTAL row → EXTRAS (`"Extras: Wd 3, Nb 1, B 1 (5)"`) → BOWLING (Bowler \| O \| M \| R \| W \| Econ \| Wd \| Nb) → FALL OF WICKETS (numbered 1..N) → PARTNERSHIPS → YET TO BAT (chips) → "↔ Swipe sideways for all columns". No innings yet → "Scorecard not available yet."
- **Squad tab:** Team A (XI + bench) + Team B, each row tappable → profile, with context line `"vs <Opponent> • <Format>"`. Empty → "Squad will appear once the data source returns squads."
- **Prediction tab:** "Who will fire? — King Prediction" + formula inputs line ("Form + vs Opponent + Venue + Matchup + Pitch") + one card per squad player sorted by score desc (Name • Score 0–100 • Likely/Risky/Unlikely + ONE WHY line + "Prediction is a model, not a guarantee."). + Disclaimer: "For information & entertainment only. Not betting advice."
- **Global Match Detail rules:** Live tab and Scorecard tab NEVER disagree (same scores, status, result line, same `resolveStatus`). Equation computed from structured overs, never from a status string. **Every** player name in scorecard/squad tappable → profile (P12).

### 4.3 Player Profile (the "study" screen — Cricinfo + Cricmetric depth)

- **Fixed order (never reordered):** Hero (avatar initials gold-ring + Name + Role • Team • Country + Batting/Bowling style + **source line directly under identity** + Quick stats Runs \| Avg \| SR \| Wkts, always visible, no scroll) → [Prediction card IF opened from a match: vs `<Opponent>` at `<Venue>`, `<Format>`] → Overall (all formats, career totals + stat bars) → vs Opponent (`<Opponent>`) → Format-wise (`<Format>`) → All Formats Full Table (horizontal scroll) → Leagues (one row per league) → Venue records (one row per venue, current venue first) → Recent Form (last 5) → Matchup (bowler-vs-batter) → Dismissal History → Bowling Full Table.
- **Rules:** Source line directly under hero identity, not buried. Empty sections HIDDEN (never "0 / 0 / 0"). Rates = 1–2 decimals, consistently. Tapping a matchup bowler → that bowler's profile. Match section shows ONLY that match's opponent context (J3).

### 4.4 Compare

- Two pickers (re-validated on reload) + VS + avatars + names (tappable) + one source line for both. Batting table + Bowling table, per-row winner in gold, draws = no highlight. Same source labelling as Profile.

### 4.5 Stats / Leaders

- Chips `[Batting] [Bowling] [All-round]` + Format filter `[All | Test | ODI | T20 | T10]` (actually filters). Sections ranked 1..N, tappable → profile, each average/SR/economy leaderboard STATES its min-qualifier ("min 10 innings" / "min 10 overs"). Stats derived from the loaded player list, never hard-coded. Records section (dataset-derived, labelled as such).

### 4.6 Leagues / Series

- Chips per competition incl. Women's + U19 + all domestic (see J6). Per-series: Info + Points Table (or honest "Table not available") + Top Players + Matches (same Home card). Reuse Home card component.

### 4.7 Favourites + Notifications

- Notifications ON/OFF + per-match toggles (Wickets / Sixes / Start / Milestones / Result) + Favourite Teams + Favourite Players. Favourited matches pinned to top of Home, FREE. Honest labelling until FCM wired.

### 4.8 Global rules (every screen)

- **G1 — One source of truth:** status, team names, scores parsed once (`resolveStatus`, `cleanTeamName`, `titleCaseTeam`); every screen reads the parsed model. No screen re-parses a string.
- **G2 — No silent zeros:** `0` only when the source genuinely says 0. Missing = section hidden + source line explains why.
- **G3 — Hindi parity:** every user-facing string in EN + हिं. No mixed-language screen.
- **G4 — Offline:** no network → last verified cache + "Offline — showing last verified data" banner. Never a crash, never an infinite spinner.
- **G5 — Performance:** Home list renders in <1s on a mid phone. No `FutureBuilder` that re-fires on every build (futures cached in `initState`).
- **G6 — Accessibility:** min tap target 48dp, body text never below 11sp, colour never the ONLY signal (LIVE pill = text + dot).
- **G7 — No fake chrome:** no ad placeholder, no "Complete" on partial data, no "Live" pill on a non-live match, no TODO/dev text in release.
- **G8 — No fake numbers:** no fantasy points without a real provider + formula shown; no ICC rankings without a provider returning them; no "faster than TV" on a 10-min-cached free tier.
- **G9 — King skin, reference layout:** navy+gold + crown + GoldDonut + StatBar = brand; card/table/tab structures = reference. Innovation in analytics (venue, matchup, prediction), not in moving R/B/4s/6s columns.

---

## 5. Success metrics (how we know it worked — all must be met before shipping)

> Metrics are **acceptance gates**, not aspirations. A single fail = do not ship (per REFERENCE-SPEC §8).

### 5.1 User-perceived metrics (measured on the release APK, on a real phone — GT 6T)

| # | Metric | Target | How measured |
|---|---|---|---|
| M1 | **2-second rule** | App opens to Home in <2s; live score readable in ≤2s from Home open | Stopwatch on GT 6T, release APK, mid network. |
| M2 | **Home render** | Home list renders in <1s on a mid phone | Same as M1, list visible (not spinner). |
| M3 | **No truncation** | 0 truncated strings in the 20-point checklist run (header, tabs, titles, team names, venues) | Manual checklist §6, 360dp width + GT 6T. |
| M4 | **No fake data** | 0 screens showing "Complete" on demo/curated data; 0 numbers without a source label; 0 ad placeholders; 0 dev text | Checklist §6 items 16–17 + QA detail report. |
| M5 | **One status truth** | 0 live matches under Upcoming; 0 upcoming under Live; pill == filter == header, always | Checklist §6 items 4–6 + Austria W regression case. |
| M6 | **Tappability** | 100% of player names (scorecard / squad / trending / stats / compare) open that player's profile | Checklist §6 item 14, tap-through audit. |
| M7 | **Hindi parity** | 100% of labels in Hindi in Hindi mode; 0 mixed-language screens | Checklist §6 item 20, Hindi-mode walkthrough. |
| M8 | **No crash** | 0 crashes on the checklist run (open → Home → match → profile → compare → stats → leagues → favourites → back) | Checklist run + `flutter test` green. |

### 5.2 Engineering metrics (measured in CI / VM)

| # | Metric | Target | How measured |
|---|---|---|---|
| M9 | **Analyze** | `flutter analyze` = No issues found | GitHub Actions Analyze step. |
| M10 | **Tests** | `flutter test` = all pass (incl. V3 regression tests + new P0 tests) | GitHub Actions Test step + local run. |
| M11 | **Web build** | `flutter build web --release` succeeds | Local + CI (sanity, not the deliverable). |
| M12 | **Quota** | ≤40 CricAPI hits/day in realistic use (10-min live cache, 60-min completed/series/player, +1 match-end fetch) | API-SETUP quota budget; code review of cache TTLs; no direct `http.get` outside providers. |
| M13 | **60fps smoothness** | No full-list rebuild on poll; no full-screen spinner on refresh; skeleton states, not blank screens | PREMIUM-SMOOTH smoothness checklist; code review (ListView.builder, const, cached futures, deduped requests). |
| M14 | **Offline** | No-network → last verified cache + offline banner, never crash / infinite spinner | Airplane-mode test on GT 6T. |
| M15 | **APK** | ONE official Gradle-built APK via GitHub Actions; `aapt2` badging (package `com.kingcric.app`, minSdk 24, targetSdk 36) + apksigner + zipalign all pass | GitHub Actions Verify step + local verify of the downloaded APK (size + sha256 recorded). |

### 5.3 Trust metrics (user-reported, post-ship)

| # | Metric | Target |
|---|---|---|
| M16 | **User verdict** | User says "ab sahi dikh raha hai" on the GT 6T screenshots — no "fuddu" recurrence. |
| M17 | **1★-tail risks** | Zero recurrence of CricketLineX's top complaints in KingCric: no ad-on-resume, no wrong-status, no "Limited player statistics" (dismissal/matchup/venue sections exist). |

---

## 6. Acceptance criteria (ship gate — ALL must pass)

This is the **20-point checklist** from REFERENCE-SPEC §8, restated here as the ship gate (same list, same order, no edits). Run on a real phone, on the release APK. ALL 20 must pass. A single fail = do not ship.

1. [ ] App opens to Home in < 2s, no crash, no blank screen.
2. [ ] Header reads **KingCric** in full (never "King…"), EN/हिं toggle visible.
3. [ ] Default tab is **Live**. If a live match exists, it is the first card.
4. [ ] Every Live card has a red **LIVE** pill + pulsing dot + the biggest bold score on the card.
5. [ ] Every Live card shows "need X from Y balls" (chase) or current equation — never a "need" line on a completed match.
6. [ ] No live score ever appears under an UPCOMING pill, and no upcoming match ever appears under Live.
7. [ ] Every team name is Title Case, one team per row, no commas joining two teams, no "Inning 1" inside a name.
8. [ ] Every fixture title is fully readable (max 2 lines, no mid-word cut).
9. [ ] Tabs read **Live / Upcoming / Finished** in full, on one line each, in both EN and हिं. (Note: "Recent" → "Finished" per CricketLineX; if the build still says "Recent", this item fails until renamed.)
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

**Plus PM's three extra gates (from §5):**
21. [ ] `flutter analyze` clean + `flutter test` all pass + `flutter build web` succeeds.
22. [ ] ONE official Gradle-built APK, verified (size + sha256 + aapt2 badging + apksigner + zipalign).
23. [ ] Quota: realistic-day usage ≤40 CricAPI hits (cache TTLs reviewed, no direct `http.get` outside providers).

---

## 7. Prioritized backlog

### 7.1 P0 — MUST-HAVE for the next APK (ship-blocking)

> If any P0 item fails its acceptance criteria in §7.1, the APK does not ship. P0 = the user's "each and every thing sahi se chahiye" + the V3 screenshot bugs + the reference-spec non-negotiables.

| # | P0 item | Owner team* | Acceptance (from §6 unless stated) |
|---|---|---|---|
| P0-1 | **One status truth** — `resolveStatus()` at parse; Home filter, card pill, detail header all read it; Austria W case (scores + no result → Live, LIVE pill, never Upcoming). Delete UI-layer status bandage as source of truth (defensive fallback only). | Data/API + Home | §6 items 3, 4, 6 + regression test (in-progress status → live; completed → Finished; not-started → Upcoming). |
| P0-2 | **Structured team/score rows + clean team names** — one `TeamScore` per team/inning; `cleanTeamName` + `titleCaseTeam` at parse; inning label separate from team name. | Data/API | §6 item 7: no `","` in any team name, no lowercase team, no "Inning 1" inside a name, ever. |
| P0-3 | **No truncation, no dev text** — FittedBox app name ("KingCric" full), no-wrap tabs, 2-line fixture titles, horizontal-scroll tables + swipe hint, AdPlaceholder renders nothing without an AdMob ID. | Home + Match Detail + QA | §6 items 2, 8, 9, 17. Verify at 360dp width + GT 6T. |
| P0-4 | **Honest source labels** — every stats block carries Real/Demo/Partial + provider + dataset size; "Complete" ONLY for genuinely full-career data; mock/demo players `dataComplete=false` + source Demo. | Player/Compare + Data/API | §6 item 16. No screen shows "Complete" on demo/curated data. |
| P0-5 | **Home 2-second check** — default tab Live; Live first; hero gradient + LIVE pill + biggest bold score + equation; "Last updated HH:MM" + Refresh; pull-to-refresh (no full-screen spinner); Trending Players (top 4, rule stated, tappable, source-labelled); ONE demo banner (not per-card); no news/videos on Home. | Home | §6 items 1, 3, 4, 5, 11 + M1/M2. |
| P0-6 | **Full scoreboard, P6 order, tappable names** — Batting → Extras → Bowling → FOW → Partnerships → Yet-to-bat, per innings; every batter/bowler name tappable → profile; Live tab and Scorecard tab never disagree. | Match Detail | §6 items 12, 13, 14. |
| P0-7 | **Player Profile fixed order + source line** — Hero + source line under identity + Quick stats (no scroll) → Overall → vs Opponent → Format → Full Table → Leagues → Venue → Form → Matchup → Dismissal → Bowling. Empty sections hidden. Rates 1–2 decimals. | Player/Compare | §6 item 15. |
| P0-8 | **Compare: batting + bowling + winner highlight + never-stale pickers** | Player/Compare | §6 item 18. |
| P0-9 | **Stats: format filter + min-qualifiers; Leagues: Women's + U19 + domestic chips + same Home card; Favourites: teams + players + selective notification toggles + honest FCM labelling** | Stats/Leagues/Favourites | §6 item 19. |
| P0-10 | **Hindi parity** — EN/हिं toggle switches ALL labels; no mixed-language screen. | All teams (strings) | §6 item 20. |
| P0-11 | **Smooth API layer** — cache-first (stale-while-revalidate): cache instantly, background refresh, no flicker; deduped in-flight requests; smart polling (Live 10 min, Upcoming/Series/Player 60 min, Completed never re-fetch); offline → last verified cache + banner; quota ≤40/day. | Data/API | M12/M13/M14 + API-SMOOTH spec (cache-first, no flicker, no duplicate calls). |
| P0-12 | **QA gate** — `flutter analyze` clean + `flutter test` all pass (incl. V3 regression tests) + `flutter build web` OK + 20-point checklist on release APK on GT 6T + ONE verified Gradle APK. | QA | §6 items 21–23 + M9–M11, M15. |

\* Owner teams are the Google-style feature teams already spawned (Home/Live, Match Detail, Player/Compare, Stats/Leagues/Favourites, Data/API/Cricsheet, QA/Testing). The PM does not reassign work mid-flight — this table is the *priority contract* those teams build against.

### 7.2 P1 — NEXT (after the P0 APK ships and the user confirms "ab sahi dikh raha hai")

| # | P1 item | Why P1, not P0 | Acceptance |
|---|---|---|---|
| P1-1 | **Preview/Info tab** on Match Detail (pitch report text + weather + toss + Playing XI, before start) | Reference (CricketLineX L3) but not ship-blocking; Squad tab already carries XI. | Upcoming match shows Preview with pitch/weather/toss/XI; no "score" on upcoming card. |
| P1-2 | **Overs/Graph view** (runs-per-over + wickets, "live line & match graphs") | Cheap from innings overs + FOW; reference asks for it, but hero + scorecard already answer the 2-sec check. | Graph renders from structured overs; never from a status string; empty → "Graph not available yet." |
| P1-3 | **Records section** (highest totals, legendary innings, most runs/wkts in loaded dataset) | CricketLineX feature; dataset-derived leaders must be labelled as such, never as ICC rankings. | Records labelled with dataset + source; no ICC-ranking claim without a provider. |
| P1-4 | **Light theme** (King dark stays default) | CricketLineX + CREX ship both; King dark must be *complete* first (every screen/dialog/empty state). | Light theme covers every screen; dark remains default; toggle persisted. |
| P1-5 | **Fantasy points (real provider only)** | LineX feature; KingCric must NOT fake a Dream11 formula. Only if a provider supplies fantasy points + formula. | Points shown with provider + formula; if no provider, section absent (missing beats made-up). |
| P1-6 | **FCM push notifications** (Firebase free tier) | Until wired, "Local reminders (push coming soon)" is honest. FCM = real push for favourited events. | Toggle gates real FCM alerts; selective per-event; never noisy by default. |
| P1-7 | **Background updates when app is closed** (WorkManager / Firebase Functions free tier) | Same honesty rule as FCM; auto-update inside the app is P0, background is P1. | Match-end recalc fires when app is closed; "Last updated" reflects it. |
| P1-8 | **Cricsheet full-dataset refresh** (`all_json.zip` → replace asset → rebuild, no code change) | Bundled sample = 4 T20Is (real-over-sample, labelled). Full careers need the full dataset. | `sourceMatches` updates automatically; profiles show full-career counts; no code change required. |
| P1-9 | **Win-probability meter + graph on Live tab** (CREX visible meter + Cricmetric range/honesty) | Prediction tab (P0) already carries score + WHY; meter/graph is the visual upgrade. | Meter + range shown with inputs + "Model • not a guarantee"; monotone sanity holds (score up ⇒ win % up). |
| P1-10 | **News tab** (headlines, interviews, short clips) | Explicitly excluded from Home v1 (dilutes the check screen). Later tab only. | News lives in its own tab, never on Home; source-labelled. |

### 7.3 P2 — LATER (do not build now; record so nobody re-litigates)

| # | P2 item | Why later |
|---|---|---|
| P2-1 | ML prediction model (trained on Cricsheet historical ball-by-ball, backtested, calibrated) | Phase 2 of prediction; Phase 1 weighted model (form 30% + vs opp 25% + venue 20% + matchup 15% + pitch 10%) is P0. ML needs backtest + calibration before it can claim "most accurate". |
| P2-2 | Ball-tracking / Hawk-Eye / shot maps / wagon wheels (CricViz Layer 3–4) | No free provider returns ball-tracking; Cricsheet has no tracking. Out of scope for the ₹0 build. |
| P2-3 | ICC rankings view (official) | Needs a provider returning ICC rankings; dataset-derived leaders are P1, official ICC rankings are P2. Never present dataset leaders as ICC rankings. |
| P2-4 | Video highlights / embedded streams | Licensing + cost + Home dilution. Not in the ₹0 build. |
| P2-5 | WebSocket live feed (sub-second) | CricAPI free tier has no WebSocket; WebSocket API is paid (CricketData L/U tiers). 10-min cached polling is the honest free-tier behaviour. |
| P2-6 | iOS build | Android first (user decision). iOS after Android ships + user confirms. |
| P2-7 | Play Store release (release keystore + $25 Google fee) | Current APK is debug-signed for sideloading only, NOT for Play Store upload. Play Store is a separate, user-approved step after the sideload APK is confirmed working. |

### 7.4 Explicitly NOT doing (Do-NOT list — PM-enforced)

1. **No scraping** of Cricbuzz / Cricinfo / Cricmetrics (ToS, blocking, breakage, Play Store rejection, legal risk).
2. **No copied code / assets / feeds / data** from any reference app. Study for understanding only; KingCric code is original.
3. **No decompile / MOD APK / re-signed APK** of any reference app.
4. **No fake numbers:** no fantasy points without a provider + formula; no ICC rankings without a provider; no "faster than TV" on a 10-min-cached free tier; no "Complete" on partial/demo data.
5. **No ad placeholder / dev text / TODO in release.** If a feature is not wired, it is hidden, not labelled as broken.
6. **No paywall** on scorecard / stats / compare / prediction. No Premium-gated PIN. No login-gated stats. No full-screen ad on every resume.
7. **No spending the user's money.** ₹0 build. The $25 Play Store fee is Google's fee, paid only when the user explicitly approves the Play Store step.
8. **No second / diverging card or table layout.** One Home card component, one scorecard layout, everywhere.
9. **No "Recent" label.** Tabs are Live / Upcoming / **Finished** (CricketLineX wording). "Recent" is ambiguous and fails §6 item 9.
10. **No rebuilding again and again.** P0 ships once, verified, as ONE Gradle APK. P1 waits for user confirmation of P0.

---

## 8. Data + source honesty (PM contract — the trust feature)

| Data | Source | Label shown to user | Freshness |
|---|---|---|---|
| Live scores, live scorecard | CricAPI (primary), EliteSport (secondary) | `Real • CricAPI • live` | 10-min cache (free-tier limit) — "Last updated HH:MM" |
| Backstop scores | SportScore | `Real • SportScore` | Same cache. Attribution: "Powered by SportScore" (free-tier requirement) |
| Schedules, badges, bios | TheSportsDB | `Real • TheSportsDB` | 60-min cache |
| Deep player stats (career / vs opp / venue / matchup / dismissal) | Cricsheet open data, calculated by KingCric | `Real • Cricsheet open data • N matches in dataset` | Static per bundled dataset; grows on dataset refresh (P1-8) |
| Sample / curated numbers (source missing) | Mock / curated | `Demo data — curated sample, not live-verified` | Never presented as real |
| Prediction | KingCric model (form 30% + vs opp 25% + venue 20% + matchup 15% + pitch 10%) | `Model • not a guarantee` + inputs + WHY line | Recomputed on open |
| EntitySport (tertiary) | EntitySport API (public API only — NOT the CricketLineX app's feed) | `Real • EntitySport` | Per provider cache; sample completed competitions only |

**Rules:** A screen never mixes two sources without saying so. If a profile mixes Cricsheet career + CricAPI live form, it says both. Cross-check: if 2 sources disagree on score, keep primary + log, never crash, never replace verified data with unverified. Validation: innings reconcile (batting + extras ≈ total within tolerance) else keep last verified copy.

---

## 9. Risks + mitigations (PM's honest list)

| Risk | Likelihood / impact | Mitigation (already in the plan) |
|---|---|---|
| Free-tier quota exhausted (100/day) → app goes dark | Medium / High | 10-min live cache + 60-min completed/series/player + deduped requests + manual refresh (not auto-poll) + cache → mock fallback + quota budget ≤40/day (M12). |
| Provider returns wrong status / joined team name (V3 bugs recur) | Medium / High (trust killer) | `resolveStatus` + `cleanTeamName` + `titleCaseTeam` at parse + regression tests + §6 items 6–7 as ship gate. |
| Cricsheet sample too small (4 T20Is) misread as "full career" | Medium / High | Dataset-size label on every Cricsheet block; never "Complete"; P1-8 full-dataset refresh path documented. |
| Reference-app analysis based on public text, not installed teardown (`[inferred]` details) | Medium / Medium | Hands-on device / live-browser session still open (REFERENCE-SPEC §9) must amend this spec where real screens differ. No `[inferred]` detail is a ship-blocker by itself — the 20-point checklist is. |
| Team parallelism → conflicting edits (6 feature teams + redesign + API teams on the same tree) | Medium / Medium | This spec is the priority contract; V3-fix commit `17ce998` is the base (do not revert); teams commit locally, do NOT push; parent merges + pushes once, builds once. |
| User trust (shaken by repeated APK failures) | High / High | Ship ONE verified Gradle APK, not two manual APKs; verify size + sha256 + badging before delivery; never present a manual APK as Gradle; no excuses, no repeated basic troubleshooting. |
| Play Store rejection (scraped data / copied assets / betting) | Low / High if it happens | No scraping, no copied assets, no odds/betting, disclaimer on prediction, 2 permissions only. |

---

## 10. What "done" looks like (definition of done for the next APK)

The next APK is **done** when ALL of the following are true — not when "most" are true:

1. P0-1 through P0-12 (§7.1) all pass their acceptance criteria.
2. The 20-point checklist (§6 items 1–20) + PM's 3 extra gates (§6 items 21–23) all pass on the release APK on the GT 6T.
3. `flutter analyze` clean + `flutter test` all pass + `flutter build web` succeeds.
4. ONE official Gradle-built APK via GitHub Actions, verified (size + sha256 + aapt2 badging + apksigner + zipalign), delivered via ONE direct link with size + hash + install steps.
5. User confirms "ab sahi dikh raha hai" on the GT 6T screenshots — no "fuddu" recurrence.
6. No P1/P2 item is claimed as done. P1 waits for user confirmation of P0.

**After P0 ships and the user confirms, P1 is planned in P1 order (§7.2). P2 is not scheduled.**

---

## 11. Sources

- `REFERENCE-SPEC.md` (12 patterns, per-screen specs, 20-point checklist, CricketLineX addendum)
- `REFERENCE-APPS-DEEP-DIVE.md` (Cricbuzz 240M / Cricinfo / CREX / Cricmetric / CricketLineX / SofaScore)
- `CRICKETLINEX-REFERENCE.md` (Just Cricket: Fast Live Score, 15M installs, #8 Top Free Sports India)
- `REQUIREMENTS-MAPPING.md` (Requirement × App matrix, gaps, KingCric implementation plan per requirement)
- `PLAYER-DATA-EXTRACTION.md` (industry 4-layer pipeline, extraction, arrangement, formulas, edge cases)
- `PREMIUM-SMOOTH.md` (premium design system: navy+gold, typography, spacing, cards, animations, smoothness)
- `API-SETUP.md`, `MULTI-API.md`, `CRICSHEET-DATA.md` (legal sources, quota, calculation, fallback)
- User decisions (from conversation): full version only; ₹0 free model; Android first, Hindi+English; "jo sahi lage sara and real data ho bas sab kuch ho"; study reference apps to understand, never use their codes, build OUR app OUR way; "ek ek choti se choti chize dekh ke samaj ke banana"; "meko each and every thing sahi se chahiye"; 30 workers, Google-style best team, perfect work.
