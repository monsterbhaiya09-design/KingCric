# KingCric — REQUIREMENTS MAPPING
## How OUR requirements are implemented in the reference apps, and how KingCric will do them OUR way

**Date:** 2026-10-18
**User instruction behind it:** "inke saare apps download kar and acche se samaj ki kaise kiya hai kaam and fir jo hamari requirements hai woh dekh kaise in apps me dali gayi hai fir tu hamare apps ko sahi se bana" — download all their apps, understand properly how the work is done, then see how OUR requirements are implemented in those apps, then make OUR app properly.

**Previous clarifications honoured:**
- "unki files nikal ke teko unke codes use nahi karne hai" — extracting files is ONLY to understand, NOT to use their codes.
- "bas samajhna hai ki kaise banaya gaya hai taki tu ek hi kaam baar bar galat na kare and uske baad tu hamare app ko hamare hisab se hi banayega" — understand how it was made so the same mistake is not repeated, then build OUR app OUR way.

> **Honest method note — read first.**
> This mapping is built from **public sources only**: Play Store listings,
> AppBrain / Similarweb / Uptodown metadata pages, official websites
> (cricbuzz.com, cricmetric.com, sofascore.com, crex.com), public reviews,
> plus the earlier KingCric reference docs (REFERENCE-SPEC.md,
> REFERENCE-APPS-DEEP-DIVE.md, CRICKETLINEX-REFERENCE.md) which used the
> same public-source method.
>
> **What this subagent did NOT do:** It did NOT download, install, run, or
> decompile any reference APK (a text-research subagent cannot operate a
> live browser, install APKs, sign in, or drive an app on a device; the VM
> has no Android emulator / KVM). It did NOT copy any code, text, images,
> branding, or data from any reference app. It did NOT scrape any private
> API. Where a detail could not be verified from public text, it is marked
> `[inferred]` and must be treated as a hypothesis, not a fact.
>
> **What is still open:** A hands-on device / live-browser session must
> install the reference apps, screenshot each screen, and amend this
> mapping where real screens differ from public descriptions. That session
> is the only way to honestly claim "downloaded and inspected the app".
>
> **Legal sources KingCric uses (never scraping Cricbuzz / Cricinfo /
> Cricmetrics):** CricAPI / CricketData.org (primary, 100/day free),
> EliteSport (secondary), EntitySport API (tertiary, public API only —
> NOT the CricketLineX app's feed), SportScore (keyless backstop, with
> attribution), TheSportsDB (schedules / bios / badges), Cricsheet open
> data (ball-by-ball, calculated by KingCric). See API-SETUP.md,
> MULTI-API.md, CRICSHEET-DATA.md.

---

## 0. OUR REQUIREMENTS (from requirements-v1.md + user decisions)

| ID | Requirement | User's words / decision |
|----|-------------|-------------------------|
| A | **Fastest ball-by-ball live score** | "ek dum sabse fast ball by ball" |
| B | **Most accurate prediction** | "jisse sabse jayada accurate aye woh" |
| C1 | **Player Compare side-by-side** | YES |
| C2 | **Venue / pitch stats + toss impact + venue records per player** | YES + "venue records per player" (user-added) |
| C3 | **Favourite team/player + notifications** | YES |
| C4 | **Women's + U19** | YES |
| C5 | **All domestic: Ranji, Syed Mushtaq Ali, Vijay Hazare, etc.** | YES — "sab means sab kuch" |
| C6 | **Every player, batting + bowling; formats Test/ODI/T20/T10; levels International + Domestic + Leagues (IPL/PSL/BBL/T10, each league separate)** | "har ek sab kuch" |
| C7 | **Dismissal history: who got whom out, how many times, who never got whom out** | Core requirement |
| C8 | **Bowler-vs-batter matchup: matches, wickets, runs, balls** | Core requirement |
| C9 | **Match-context view: squad players, each player's overall + vs opponent + format + other formats + combined T20+ODI, runs/balls/50s/100s/avg/SR/everything, recent performance overall + vs opponent, prediction; match section shows only that match's opponent context** | India vs Pakistan T20 example |
| C10 | **H2H: team H2H (how many matches, who won how many) + player H2H + overall** | Core requirement |
| D | **Auto-update: as soon as a match finishes, that player's data updates immediately; stats never stale; live ball-by-ball + on finish recalculate career / vs opponent / venue / H2H / recent form / prediction inputs** | "har minute me koi na koi new match khatam hota hai so use player ka data bhi hato hath hamare app me update hota jaye" |
| E | **Data completeness: full + correct, from everywhere, nothing missed; multiple sources + cross-check (2–3 sources, 3rd verifies mismatch), full career backfill, full scorecard (batting+bowling+fielding+dismissal), validation (totals must reconcile), completeness flag internally, never show wrong/incomplete as complete** | "data bilkul bhi adha adhura nahi hona chahiye sidhi baat pura data hona chahiye uska ek dum correct data and har jagah se nikal lena kuch chute na" |
| F | **Full version only, not MVP-only** | "dekh bro humko full version hi chahiye" |
| G | **100% free model: user will not spend even ₹1; idea + time only; earnings later from usage/ads** | "meko ek ruppees bhi nahi lagana hai" |
| H | **Android first, Hindi + English both, monetization via AdMob ads, Play Store eventually** | E) Android first, Hindi+English, ads |
| I | **Presentation: not raw data, clean presentation; match section shows only that match's opponent context** | "clean presentation, not raw data" |

Legend for the matrix below:
- ✅ = App implements this well (public listing / reviews confirm it)
- ◐ = Partial / gated / inferred / only in some screens or paid tier
- ❌ = Not found in public listing / reviews, or explicitly criticised as missing
- `[inferred]` = derived from listing/review wording, not a verified screenshot

---

## 1. MATRIX — Requirement × App

### A) Fastest ball-by-ball live score

| App | Verdict | How they do it (public evidence) |
|-----|---------|----------------------------------|
| **CricketLineX (PRIMARY)** | ✅ | Brand IS speed: "Fastest cricket live score updates in India", "one step ahead of every ball", "faster than TV". Home = trending + Live/Upcoming/Finished. Ball-by-ball commentary "smart, clear, instant". Live line + match graphs (over-by-over). Reviews praise "lightning speed" (768 helpful) AND complain "ball by ball very slow" (1★) — speed claim is contested, not uniform. |
| **Cricbuzz** | ✅ | "Superfast scores", "fans don't read cricket, they check cricket". Mobile-first, ~18 MB early builds, lean. Ball-by-ball commentary = short lines, one ball per line. Live rows carry LIVE pill. Auto-updating match pages. |
| **ESPNcricinfo** | ◐ | Ball-by-ball live coverage exists, but commentary is descriptive + longer, slower to scan. Optimises for completeness / engagement, not latency. Home mixes news + scores — slower to reach the score than Cricbuzz/LineX. |
| **CREX** | ✅ | "Instant ball-by-ball live updates", "Super Fast Updates — score before live on OTT apps". Reviews: "faster than most other apps". Home order: Ongoing → Upcoming → Recently completed. |
| **Cricmetric** | ❌ | Web analytics site, not a live-score app. No ball-by-ball live feed. Win-probability graph is post-hoc / model-based, not a live line. |
| **SofaScore** | ◐ | Real-time results + play-by-play for many sports, but cricket is one sport among 25+. Live scores + lineups + box scores, but NOT cricket-first ball-by-ball depth. |

**What KingCric learns:** Speed is *perceived* in <2 sec: live match first, score biggest, status unmistakable. No reference app proves "fastest" uniformly — all have slow complaints. KingCric must be honest: free tier = 10-min cached ball-by-ball (CricAPI 100/day), shown as "Last updated HH:MM". Win on clarity, not on a fake "faster than TV" claim.

### B) Most accurate prediction / win probability

| App | Verdict | How they do it |
|-----|---------|----------------|
| **CricketLineX** | ❌ | No advertised prediction / win-% feature. Reviewers explicitly compare: "Crex is best showing winning percentage" (1★ on LineX). Gap. |
| **Cricbuzz** | ◐ | Recently added live win probability during major matches (secondary source: AllCric comparison). No public formula, no per-player "who will fire" prediction. Fantasy Handbook (Plus) gives venue + matchup + form + differential picks — but paywalled / subscriber-only. |
| **ESPNcricinfo** | ❌ | No win-probability / prediction product in public listing. Depth is retrospective (Statsguru), not predictive. |
| **CREX** | ✅ | **Best in set for this requirement.** Real-time win-% meter that updates through the match + fan polls + fantasy tips by experts (Aakash Chopra) + pre-match insights + strategic analysis + graphs. Win-% is visible on the match screen, not buried. Premium adds Odds History + Graphs (paid). |
| **Cricmetric** | ✅ | **Most honest / most rigorous in set.** XGBoost win-probability model ("panel of 1,000 analysts"), monotone constraints (more runs ⇒ higher win %, losing wickets ⇒ lower), innings-break consistency, volatility / range of possible scores (not a single number). 2019 WC pre-match predictions 68% success (claimed). Shows model + range, not fake-precise %. |
| **SofaScore** | ◐ | Win-probability graphs + momentum charts exist (multi-sport), but cricket-specific prediction depth is thin vs CREX/Cricmetric. `[inferred]` |

**What KingCric learns:** Two models exist — CREX (visible meter, no formula) and Cricmetric (rigorous model + range + honesty). KingCric must combine them: visible win-% meter + per-player "who will fire" (Likely/Risky/Unlikely) + ONE Hindi/English WHY line + inputs shown + "Model • not a guarantee" + disclaimer "For information & entertainment only. Not betting advice." Never a fake-precise single % with no explanation. Never present prediction as fact.

### C1) Player Compare side-by-side

| App | Verdict | How they do it |
|-----|---------|----------------|
| **CricketLineX** | ❌ | "Team analysis & comparisons" is listed, but NO advertised side-by-side player-compare screen. Reviews do not mention a compare screen. Gap. |
| **Cricbuzz** | ◐ | Player profiles + rankings + records exist; users can open two profiles and compare manually. No public evidence of a dedicated side-by-side compare screen. `[inferred]` |
| **ESPNcricinfo** | ◐ | Statsguru lets a user build two queries and compare outputs, but it is a query builder, not a side-by-side compare screen. Powerful, not casual. |
| **CREX** | ◐ | "Tap any player/team → deep insights & stats", fantasy team builder compares players implicitly (pick A vs B for fantasy). No advertised dedicated side-by-side compare screen. |
| **Cricmetric** | ◐ | Matchup-based team/captain rankings + player ranks (IPL) exist; comparison is via rankings/tables, not a side-by-side screen. |
| **SofaScore** | ✅ | **Best in set for generic compare.** "Compare players, teams, and seasons with live and historical stats" is an explicit SofaScore feature (multi-sport). Layout: same stat rows, two columns. Cricket-specific depth (vs opponent, venue) is thinner than KingCric needs. |

**What KingCric learns:** NO cricket app in this set does side-by-side player compare well as a first-class screen. This is a KingCric differentiator. KingCric Compare must be: two pickers (never stale — known V2 bug), same rows for both players (Runs/Avg/SR/100s/50s/4s/6s/HS/Matches + Bowling Wkts/Econ/Avg/Best), per-row winner highlighted in gold, both players' source labels shown, names tappable → profile. Do NOT copy SofaScore's generic table blindly — add KingCric depth (vs opponent, venue, matchup rows).

### C2) Venue / pitch stats + toss impact + venue records per player

| App | Verdict | How they do it |
|-----|---------|----------------|
| **CricketLineX** | ◐ | Match Detail includes pitch report + weather + Playing XI + H2H. No advertised per-player venue-records table. Pitch = a text report, not a stats table. |
| **Cricbuzz** | ◐ | Match Info shows venue + toss + umpires + pitch (text). Fantasy Handbook (Plus) gives venue info. No public per-player venue-records table. |
| **ESPNcricinfo** | ✅ | **Best in set for venue as a filter.** Statsguru filters by ground: "batsmanAvgRunsGround", "bowlerAvgWktsGround", home/away, opposition, date range. The `cricketr` package proves the dimensions users query: format × opponent × venue × home/away × result × time. But it is a query builder — the user must build the query. |
| **CREX** | ◐ | Pre-match info + analysis includes venue context; points table + rankings. No advertised per-player venue-records table. |
| **Cricmetric** | ✅ | **Best in set for venue analytics.** Venue Outcomes (bat-first win %), Average 1st-Innings Scores over time, Venue Bowler Stats (avg-vs-econ scatter by bowling style), H2H records embeddable. Venue is a *chart*, not just text. |
| **SofaScore** | ❌ | Venue/pitch analytics for cricket not advertised; venue is a label, not a stats screen. |

**What KingCric learns:** Two halves exist — Cricinfo (venue as a *filter* the user must build) and Cricmetric (venue as *charts*). NOBODY gives "player X at venue Y" pre-computed on the player profile as a first-class section. KingCric must: (1) Venue section on Player Profile (one row per venue: runs • avg • SR, venue of current match first), (2) Venue section on Match Detail (bat-first win %, avg 1st-innings score, bowler avg-vs-econ, toss impact line, pitch report text + weather), (3) pre-computed answers, NOT a query builder. Data: Cricsheet ball-by-ball → group by venue; CricAPI/Toss from live feed.

### C3) Favourite team/player + notifications

| App | Verdict | How they do it |
|-----|---------|----------------|
| **CricketLineX** | ✅ | Smart notifications: wickets, sixes, match start, milestones. Per-match / per-team opt-in `[inferred]`. Complaint: "annoying push notifications" when everything is on — selective is the lesson. |
| **Cricbuzz** | ✅ | Notifications for favourite teams/players + matches; "never miss an update". Customizable per match/team. |
| **ESPNcricinfo** | ✅ | Push notifications for wickets / milestones / results. Favourite teams/players follow. |
| **CREX** | ✅ | **Most complete in set.** Notifications for all live & upcoming matches, key events, & Breaking News. PIN live score (Premium-gated): pinned match rises to top of feed. Follow favourite teams (Fixtures → follow). Fantasy team tracking. Complaint: Premium-gated PIN is a paywall on a basic follow feature. |
| **Cricmetric** | ❌ | No app notifications (web analytics site). |
| **SofaScore** | ✅ | **Best granularity in set.** Personalized notifications for goals/kickoffs/final scores/red cards/substitutions (football) → cricket equivalent: wickets, milestones, results. "Follow your favourite teams and leagues", "Create your own live scoreboard", "You choose what to follow and how often". Customizable, never noisy by default. |

**What KingCric learns:** The pattern is universal: follow team/player → selective event notifications (wickets/sixes/start/milestones/result) → favourited matches surface at top of Home (CREX PIN behaviour). The failure mode is also universal: noisy-by-default + Premium-gated PIN. KingCric must: (1) Favourite TEAMS + PLAYERS + MATCHES (V3 had players only — add teams), (2) Per-match toggles: Wickets / Sixes / Start / Milestones / Result, opt-in, selective, (3) Favourited matches pinned to top of Home, FREE (never Premium-gated), (4) Honest labelling until FCM is wired: "Local reminders (push coming soon)" — never claim FCM pushes when none are wired.

### C4) Women's + U19

| App | Verdict | How they do it |
|-----|---------|----------------|
| **CricketLineX** | ◐ | Coverage list: IPL, WCs, Champions Trophy, WTC, Asia Cup, BBL, PSL, SA20, ILT20, BPL, CPL, Hundred, Ranji, County, "all international tours and domestic". Women's not named as a separate section in the listing; U19 not named. V3 screenshot evidence: Women's matches DID appear in KingCric's live feed (Austria W, Sweden W, Bulgaria W) via CricAPI — so the *data* exists, the *section* is the gap. |
| **Cricbuzz** | ✅ | Grouped match list includes a WOMEN section explicitly (Live Now / Today / INTERNATIONAL / LEAGUE / DOMESTIC / WOMEN). Women's cricket is a first-class filter, not an afterthought. |
| **ESPNcricinfo** | ✅ | Widest coverage: "Widest cricket coverage across the world" — includes Women's internationals, Women's leagues, U19 (via coverage + archives). ICC Women's Rankings exist. |
| **CREX** | ✅ | Fixtures classified: International / T20 / ODI / Test / League / **Women**. Explicit Women filter in Fixtures. Coverage: "India Women Tour of South Africa", "Women's Premier League" named in listing. U19 not named as a separate filter. |
| **Cricmetric** | ◐ | Analytics covers IPL + international; Women's / U19 coverage is thin / not advertised. |
| **SofaScore** | ◐ | Cricket coverage includes County, Test, Hundred; Women's / U19 cricket is present but not a headline section (multi-sport app, cricket is one sport). |

**What KingCric learns:** Cricbuzz + CREX both make Women a *filter*, not just a tag. NOBODY makes U19 a first-class filter — it is always buried under "domestic / tours". KingCric must: (1) Women as a chip/filter on Home + Leagues + Fixtures (not just a tag on a card), (2) U19 as a chip/filter alongside Women (differentiator — "sab means sab kuch"), (3) Even if a filter currently has no data, the chip exists and its empty state explains why ("No U19 matches yet — they will appear here when the source returns them"), never a dead end.

### C5) All domestic: Ranji, Syed Mushtaq Ali, Vijay Hazare, etc.

| App | Verdict | How they do it |
|-----|---------|----------------|
| **CricketLineX** | ✅ | **Best domestic naming in set.** Explicitly lists Ranji Trophy & County Championship + "All international tours and domestic cricket matches". Domestic is in the coverage list, not hidden. |
| **Cricbuzz** | ✅ | DOMESTIC section in grouped match list; covers Ranji, SMAT, Vijay Hazare, County, Sheffield Shield (via "domestic tournaments from across the globe"). |
| **ESPNcricinfo** | ✅ | Explicit: "Ranji Trophy, Sheffield Shield, County Championship" + domestic coverage. Archives reach old domestic scorecards. |
| **CREX** | ✅ | Covers "all domestic leagues like T20 WC, IPL, BBL, PSL, BPL, Abu Dhabi T10, Super Smash, T20 Blast, County Cricket, Super 50 Cup and a lot more." Domestic = a list, not a single bucket. |
| **Cricmetric** | ◐ | IPL-focused analytics; domestic beyond IPL is thin. |
| **SofaScore** | ◐ | County Championship named; Ranji / SMAT / Vijay Hazare not named as headline coverage. |

**What KingCric learns:** Every good app *names* domestic competitions (Ranji, County, etc.) in its coverage list — it does not say "domestic" generically. KingCric must: (1) Leagues screen with chips for EACH domestic competition (Ranji, SMAT, Vijay Hazare, County, Sheffield Shield, Super Smash, T20 Blast, Super 50 Cup), (2) Each chip shows ONLY its own matches (already KingCric behaviour — keep), (3) Points table + top players + squads per domestic series where the source provides them, (4) Honest empty states per competition.

### C6) Every player, batting + bowling; Test/ODI/T20/T10; International + Domestic + Leagues (each league separate)

| App | Verdict | How they do it |
|-----|---------|----------------|
| **CricketLineX** | ◐ | Player info + ICC Rankings + stats + team analysis; "Detailed player and team info". League coverage is broad, but per-league *separate* player splits (e.g. "Kohli in IPL vs Kohli in PSL") are NOT advertised. Reviewer complaint: "Limited player statistics". |
| **Cricbuzz** | ✅ | Player profiles with batting + bowling career tables by format (Test/ODI/T20I). Rankings + Stats + Records. Format tables use same columns everywhere. T10 not a headline format. |
| **ESPNcricinfo** | ✅ | **Best in set for format splits.** Career tables by format + Statsguru (format × opponent × venue × home/away × result × date). Every player has a profile; every format has a table. T10 is not a Statsguru headline format (Test/ODI/T20I are). |
| **CREX** | ✅ | "Tap any player/team → deep insights & stats". Player Stats Tab inside Series Profile: top performers directly in series view. Format Chips (Test/ODI/T20) on Team/Player/Series. Coverage: all tours + leagues. T10: Abu Dhabi T10 named in coverage. |
| **Cricmetric** | ◐ | IPL player ranks + matchup-based rankings; not a per-player-per-league database. |
| **SofaScore** | ◐ | 150,000 players with profiles + season stats + live ratings (multi-sport). Cricket per-league splits are thinner than Cricinfo/CREX. |

**What KingCric learns:** The pattern is: profile → format tables (same columns) + Format Chips + per-league splits. The gaps are: (1) T10 as a first-class format chip (only CREX names Abu Dhabi T10; Cricinfo/Cricbuzz stop at T20I), (2) per-league *separate* player splits (IPL vs PSL vs BBL vs T10 as separate rows, not merged). KingCric must: (1) Format Chips Test/ODI/T20/T10 on EVERY Team/Player/Series screen, (2) Player Profile → "By League" section (one row per league: runs • avg • SR + bowling), (3) League screens show ONLY that league's matches + players, (4) Every player has batting AND bowling tables (never batting-only).

### C7) Dismissal history (who got whom out, how many times, who never got whom out)

| App | Verdict | How they do it |
|-----|---------|----------------|
| **CricketLineX** | ❌ | No advertised dismissal-history feature. |
| **Cricbuzz** | ◐ | Scorecard shows dismissal line per innings ("c X b Y") — that IS dismissal data, but only for *this* innings, not aggregated history ("X has dismissed Y N times"). No history view. |
| **ESPNcricinfo** | ◐ | Statsguru / `cricketr` includes `batsmanDismissals` (how a batter gets out: caught/bowled/lbw/run out distribution) — dismissal *modes*, not "bowler X dismissed batter Y N times" as a first-class view. |
| **CREX** | ◐ | Scorecard has wicket descriptions ("c X b Y" on every dismissal) + partnership stats. Same as Cricbuzz: per-innings, not aggregated history. |
| **Cricmetric** | ◐ | Batter-vs-Bowler matchup query exists (see C8) — the closest to dismissal history, but it is a query tool, not a "dismissal history" section on a profile. |
| **SofaScore** | ❌ | No dismissal-history feature advertised. |

**What KingCric learns:** NOBODY does dismissal history as a first-class profile section. Every app shows the dismissal *for this innings*; none aggregates "c X b Y — N times" + "Not dismissed by Z in N balls". This is KingCric's clearest moat. KingCric must: Player Profile → Dismissal History section, most frequent first: `"c Rohit b Bumrah — 3 times"`, plus `"Not dismissed by Shaheen in 42 balls"` (≥12 balls, 0 dismissals). Data: Cricsheet ball-by-ball → group by (dismissal kind, fielder, bowler, batter) → count. Label: "Real • Cricsheet open data • N matches".

### C8) Bowler-vs-batter matchup (matches, wickets, runs, balls)

| App | Verdict | How they do it |
|-----|---------|----------------|
| **CricketLineX** | ❌ | No advertised bowler-vs-batter matchup view. |
| **Cricbuzz** | ❌ | No matchup view; Fantasy Handbook (Plus) mentions "player matchups" as a *fantasy* input, paywalled, not a standalone matchup screen. |
| **ESPNcricinfo** | ◐ | Statsguru can be used to approximate matchups (filter by opposition + bowler), but there is no "Bowler X vs Batter Y" screen. |
| **CREX** | ◐ | Fantasy analysis + pre-match insights mention "matchup dynamics" (Aptoid FAQ: "evaluate player performance, form, and matchup dynamics"). No standalone matchup table advertised. |
| **Cricmetric** | ✅ | **Only app in set with a real matchup feature.** "Batter-vs-Bowler matchup query" + matchup-based team/captain rankings. This is Cricmetric's differentiator. It is a query tool, not a profile section. |
| **SofaScore** | ❌ | No bowler-vs-batter matchup view. |

**What KingCric learns:** Only Cricmetric has matchup, and it is a *query tool*. KingCric must make it a *profile section*: Player Profile → Matchup section, one row per bowler: `Bowler • Matches • Dismissals • Runs • Balls • SR`, sorted by dismissals desc, plus "Not dismissed by Z" rows. Data: Cricsheet ball-by-ball → group by (bowler, batter) → balls, runs, bowler-credited dismissals (caught/bowled/lbw/stumped/hit-wicket; run-outs NOT credited to bowler). Tapping a matchup bowler → that bowler's profile.

### C9) Match-context view (squad players: overall + vs opponent + format + other formats + combined T20+ODI + runs/balls/50s/100s/avg/SR/everything + recent form overall + vs opponent + prediction; match section shows only that match's opponent context)

| App | Verdict | How they do it |
|-----|---------|----------------|
| **CricketLineX** | ◐ | Match Detail = Playing XI + squads + pitch + weather + H2H + live scorecard. Squad exists. Per-player *context* (vs opponent, format, combined) is NOT shown on the squad — squad is names + roles, not stats. |
| **Cricbuzz** | ◐ | Squad + Playing XI + match info exist. Player profile has format tables. But the *match-context* view (squad list where each row already shows "vs this opponent, this format") does NOT exist — the user must tap each player individually. |
| **ESPNcricinfo** | ◐ | Squad + profile + Statsguru exist. The user *can* build "Kohli vs Pakistan, T20" via Statsguru, but the app does not pre-compute it on the match screen. The work is on the user. |
| **CREX** | ◐ | Pre-match insights + strategic analysis + player stats on the match screen. Closest to context, but the public listing does not show per-squad-player vs-opponent + combined-format rows. |
| **Cricmetric** | ◐ | Matchup-based rankings + venue charts give context, but not a squad list with per-player context rows. |
| **SofaScore** | ❌ | Squad + H2H + form exist (multi-sport), but no cricket match-context view (vs opponent + format + combined). |

**What KingCric learns:** NOBODY pre-computes match context on the squad list. Every app makes the user tap each player and build the query. This is KingCric's second moat. KingCric must: Match Detail → Squad tab where EACH player row shows a context line: `"vs Pakistan • T20: 142 runs • Avg 47.3 • SR 138.2"` + tap → full profile with Overall + vs Opponent + Format + Other Formats + Combined (T20+ODI) + Recent Form (overall + vs opponent) + Prediction (who will fire). The match section must show ONLY that match's opponent context (never a generic career table without the opponent filter). This is exactly the user's India vs Pakistan T20 example — and no reference app does it.

### C10) H2H: team H2H + player H2H + overall

| App | Verdict | How they do it |
|-----|---------|----------------|
| **CricketLineX** | ✅ | Head-to-head stats on Match Detail + Series. Team H2H ("X [bar] 3 — 5 Y (8)") pattern. Player H2H not advertised. |
| **Cricbuzz** | ✅ | H2H on match pages (team H2H: matches, wins). Player H2H via profiles, not a dedicated H2H screen. |
| **ESPNcricinfo** | ✅ | H2H via Statsguru / team records (team vs team across formats). Player H2H via opposition filters. |
| **CREX** | ✅ | H2H implied in pre-match insights + series info. |
| **Cricmetric** | ✅ | **Best in set for H2H as a product.** Embeddable H2H records (charts, not just numbers). H2H is a *shareable* object, not just a line. |
| **SofaScore** | ✅ | H2H records + team form + live standings before each match (explicit feature). |

**What KingCric learns:** Team H2H is universal: "X 3 — 5 Y (8 matches)" with a bar. Player H2H is always via filters, never a dedicated view. KingCric must: (1) Match Detail → H2H block: team H2H bar + counts + overall, (2) Player Profile → vs Opponent section IS the player H2H (same data, labelled as H2H), (3) Matchup section IS the player-vs-player H2H. Do NOT build a separate H2H screen — H2H lives where the user already is (match + profile).

### D) Auto-update (match finish → player data updates immediately, never stale)

| App | Verdict | How they do it |
|-----|---------|----------------|
| **CricketLineX** | ✅ | Real-time live score + smart notifications on finish (result notification). Player stats / records update via their feed. Speed of post-match player-stat recalculation is not advertised. |
| **Cricbuzz** | ✅ | Auto-updating match pages ("auto-update without refresh"), result notifications. Player career tables update after matches (via their database). No public SLA for "how fast after finish". |
| **ESPNcricinfo** | ✅ | Live coverage + push notifications (wickets/milestones/results). Statsguru updates after matches. |
| **CREX** | ✅ | Real-time updates + instant notifications for matches, key events, breaking news. |
| **Cricmetric** | ❌ | No live auto-update (analytics site, batch updates). |
| **SofaScore** | ✅ | Real-time alerts + live scoreboard; stats update after matches. |

**What KingCric learns:** Every live app does two things: (1) live score auto-updates during the match, (2) result notification on finish. NOBODY advertises "player career / vs opponent / venue / H2H / recent form recalculated immediately on finish" as a feature — it happens silently in their database. KingCric must make it *explicit and verifiable*: (1) Live matches polled on a stated interval (10 min on free tier — honest, not fake "instant"), (2) On live→completed transition, AutoUpdateService fetches the final scorecard ONCE, validates it (innings reconcile), then recalculates career / vs opponent / venue / H2H / recent form / prediction inputs, (3) "Last updated HH:MM" visible on Home + Match Detail, (4) Manual Refresh always visible. On the free tier, "immediately" means "on the next 10-min poll + one match-end fetch" — say so, do not claim sub-second.

### E) Data completeness (full + correct, from everywhere, nothing missed)

| App | Verdict | How they do it |
|-----|---------|----------------|
| **CricketLineX** | ◐ | Broad coverage (15M fans, 30+ countries) but reviewers complain about wrong status ("completed but show is not started") + limited player stats + crashes. Completeness is *claimed*, not verified. No completeness flag, no source labels. |
| **Cricbuzz** | ✅ | Deepest *editorial* completeness: scores + news + rankings + records + archives. But data is their proprietary database — no cross-check, no source labels, no completeness flag visible to the user. |
| **ESPNcricinfo** | ✅ | Deepest *historical* completeness: Statsguru + archives + records across formats/eras. Same caveat: proprietary, no visible validation. |
| **CREX** | ◐ | Broad coverage + rankings + points tables + records. Reviews praise simplicity, complain about heavy data + regressions ("new version is worst"). No completeness flag. |
| **Cricmetric** | ✅ | **Most rigorous about validation in set.** Model has monotone constraints, backtesting, calibration (80% range, Brier score). It *measures* its own accuracy. But it is a model, not a completeness guarantee. |
| **SofaScore** | ◐ | Broad multi-sport completeness; cricket depth is thinner. No completeness flag. |

**What KingCric learns:** NOBODY shows a completeness flag or source labels to the user. Every app asks the user to trust it blindly. KingCric's differentiator is to make completeness *visible and honest*: (1) Multiple free sources + cross-check (if 2 sources disagree on score, prefer primary + log, never crash, never replace verified data with unverified), (2) Full scorecard validation (batting + extras must reconcile to total within tolerance, else keep last verified copy), (3) Source label on EVERY stats block (Real • CricAPI / Real • Cricsheet • N matches / Demo / Partial), (4) `dataComplete` flag internally + "Real • N matches in dataset" externally (never "Complete" on a 4-match sample), (5) Never show wrong/incomplete as complete. This is the user's "pura data, ekdum correct" rule made visible.

### F) Full version only

| App | Verdict | How they do it |
|-----|---------|----------------|
| All 6 | ✅/◐ | All ship "full" apps, but Cricbuzz/CREX/LineX all gate features behind Premium/paywall (CREX PIN + Graphs + Odds History = Premium; Cricbuzz Fantasy Handbook = Plus; LineX Premium login). "Full" in the market means "full for paying users". |

**What KingCric learns:** KingCric's "full version" must mean "full for EVERY user, no paywall on scorecard/stats/compare/prediction". No Premium-gated PIN, no paywalled scorecard, no login-gated stats. AdMob banner only (when an ID exists), never a full-screen ad on every resume, never covering the score.

### G) 100% free model (₹0)

| App | Verdict | How they do it |
|-----|---------|----------------|
| **CricketLineX** | ✅ | Free, contains ads. 15M downloads on free + ads. |
| **Cricbuzz** | ✅ | Free, supported by ads. No in-app purchase to remove ads (per FAQ). |
| **ESPNcricinfo** | ✅ | Free (ad-supported). |
| **CREX** | ◐ | Free + Premium (₹99/mo, ₹199/quarter, ₹499/year) for ad-free + Graphs + Odds History + PIN. Free tier is real, but best features are paywalled. |
| **Cricmetric** | ◐ | Web, free to read; no app monetization model to copy. |
| **SofaScore** | ◐ | Free + Premium (ad-free) subscription. |

**What KingCric learns:** Free + ads is the market norm (Cricbuzz, LineX). Premium-gated features are the market norm too — but KingCric's user decision is explicit: ₹0 to build, earnings later from usage/ads, NO paywall on core features. KingCric must: (1) Build cost ₹0 (Flutter + free APIs + free tiers only), (2) Monetization = AdMob banner only (when ID exists), never interstitial on every resume, never paywall, (3) Play Store $25 one-time fee is Google's fee, not KingCric's build cost — APK distribution is free until ad earnings cover it. Do NOT copy CREX's Premium-gated PIN/Graphs.

### H) Android first, Hindi + English, AdMob, Play Store

| App | Verdict | How they do it |
|-----|---------|----------------|
| **CricketLineX** | ◐ | Android + iOS, English + 5 more languages (per Uptodown). Hindi not named as a separate edition. Dark + light mode. Ads (free + ads). Play Store #8 Top Free Sports India. |
| **Cricbuzz** | ✅ | **Best in set for Hindi.** Separate vernacular edition: "Cricbuzz - In Indian Languages" — Hindi, Tamil, Kannada, Telugu, Marathi, Bengali. Ball-by-ball in regional languages. Main app = English + commentary. |
| **ESPNcricinfo** | ◐ | English-first; regional language support is thinner than Cricbuzz vernacular. |
| **CREX** | ✅ | **Best in set for in-app language toggle.** "App language options available in English, Hindi & Bengali" — in-app toggle, not a separate app. This is KingCric's model (EN / हिं toggle in header). |
| **Cricmetric** | ❌ | English-only web. |
| **SofaScore** | ✅ | Multi-language (global app), language follows device / settings. |

**What KingCric learns:** Two models exist — Cricbuzz (separate vernacular app) and CREX (in-app toggle EN/Hindi/Bengali). KingCric must use CREX's model: ONE app, EN / हिं toggle in the Home header, switching ALL labels (tabs, pills, empty states, buttons) — never a mixed-language screen. AdMob: banner only, hidden until a real ID exists (no placeholder box). Play Store: 2 permissions only (INTERNET + NETWORK_STATE) vs LineX's 19–26 — a listing advantage; say so on the Play Store page.

### I) Presentation: not raw data, clean

| App | Verdict | How they do it |
|-----|---------|----------------|
| **CricketLineX** | ✅ | "Clean interface, smooth performance, detailed match insights", "sleek and intuitive". Two-pass usage: glance at score first, commentary only if the match state raises a question. |
| **Cricbuzz** | ✅ | "Clean and readable", white space, big scores, fast load. Fails when ads cover the score. |
| **ESPNcricinfo** | ◐ | Dense, editorial, cluttered menu (review complaint). Depth at the cost of scanability. |
| **CREX** | ✅ | **Best in set for clarity.** Reviews: "small to big unique stats shown clearly with numbers", "unlike Cricbuzz where stats are complicated, here everything is simple". One-line explanations, simple numbers, graphs. |
| **Cricmetric** | ◐ | Charts + graphs, but academic tone — for analysts, not for a 2-second check. |
| **SofaScore** | ✅ | "Visually impactful", heatmaps, momentum charts, ratings. Multi-sport generic, but visual. |

**What KingCric learns:** The winning pattern is CREX + LineX: clean, 2-second glance, every number labelled, one-line explanation per analytics block. KingCric must: (1) Home = check screen (Live → score → equation → tap, nothing else competes), (2) Every analytics block gets a one-line "what this means" caption, (3) Match section shows ONLY that match's opponent context (never a generic career table without the opponent filter), (4) King navy+gold skin + gradient hero + GoldDonut + StatBar = the "not boring" layer, but layout = reference (do not redesign the scorecard layout — it is solved).

---

## 2. GAPS — Requirements NO reference app does well (KingCric differentiation)

These are the requirements where KingCric must NOT copy — it must invent, because no reference app does them:

| # | Gap | Why it is a moat |
|---|-----|------------------|
| 1 | **Dismissal history as a profile section** ("c X b Y — N times" + "Not dismissed by Z in N balls") | No app aggregates dismissal history. All show per-innings dismissal only. |
| 2 | **Bowler-vs-batter matchup as a profile section** (matches/wickets/runs/balls per pair) | Only Cricmetric has a matchup *query tool*. No app has it as a profile section. |
| 3 | **Match-context squad view** (each squad row already shows vs-opponent + format + combined + recent form + prediction) | No app pre-computes context on the squad list. All make the user tap each player. |
| 4 | **Side-by-side Player Compare as a first-class screen** (batting + bowling, per-row winner, never-stale pickers) | No cricket app has a dedicated compare screen; SofaScore's generic compare lacks cricket depth. |
| 5 | **Per-player venue records as a profile section** (one row per venue, current venue first) | Cricinfo has venue as a *filter* (user builds query); Cricmetric has venue *charts*. Neither has per-player venue rows pre-computed. |
| 6 | **Honest source labels + completeness flag visible to the user** (Real • Cricsheet • N matches / Demo / Partial) | No app labels sources or shows completeness. All ask for blind trust. |
| 7 | **T10 as a first-class format chip** (Test/ODI/T20/T10 everywhere) | Cricinfo/Cricbuzz stop at T20I; only CREX names Abu Dhabi T10. |
| 8 | **U19 as a first-class filter** (alongside Women) | Nobody makes U19 a filter. It is always buried. |
| 9 | **Full version for EVERY user, no paywall on scorecard/stats/compare/prediction** | All competitors gate features behind Premium/Plus. |
| 10 | **King identity (navy+gold + crown) + Hindi parity (ALL labels in Hindi, never mixed)** | Cricbuzz vernacular = separate app; CREX toggle = EN/Hindi/Bengali but not full parity on every screen. KingCric must have full parity in ONE app. |

---

## 3. KingCric IMPLEMENTATION PLAN — per requirement, OUR way, legal sources only

### A) Fastest ball-by-ball live score — OUR way
- **Source:** CricAPI primary (currentMatches + cricketScore) → EliteSport secondary → EntitySport API tertiary → SportScore backstop → cache → mock. Fallback chain + cross-check (primary wins on mismatch, log it, never crash).
- **Polling:** 10-min cache (live), 60-min (completed/series/player). Manual Refresh + pull-to-refresh always visible. "Last updated HH:MM" on Home + Match Detail.
- **UI:** Home default = Live. Live card = hero gradient + red LIVE pill + pulsing dot + biggest bold score + equation ("need X from Y") + current batters/bowler. Match Detail tabs: Live | Scorecard | Squad | Prediction (+ Preview/Info + Overs/Graph per REFERENCE-SPEC §8A L3).
- **Honesty:** Never claim "faster than TV" / "instant" on a 100/day free tier. Claim "fast, honest live scores". Disclaimer: "For information & entertainment only. Not betting advice." (LineX posture).
- **Acceptance:** Austria W case — a match with scores + no result appears under Live with LIVE pill, never under Upcoming. (Regression test exists in commit 17ce998.)

### B) Most accurate prediction — OUR way
- **Model (Phase 1, free):** Weighted stats: recent form 30% + vs opponent 25% + venue 20% + matchup 15% + pitch 10% → 0–100 score + Likely/Risky/Unlikely + ONE Hindi/English WHY line + inputs shown + "Model • not a guarantee".
- **Model (Phase 2, planned):** ML trained on Cricsheet historical ball-by-ball (free open data), backtested, calibrated (range, not single %). Monotone sanity: score up ⇒ win % up; wicket ⇒ win % down (Cricmetric rule).
- **UI:** Prediction tab on Match Detail (one card per squad player, sorted by score desc) + win-% meter on Live tab. Never present as fact, never as betting advice.
- **Acceptance:** Prediction with no data shows "Not enough data", not a fake 0–100.

### C1) Player Compare — OUR way
- **UI:** Two pickers (re-validated on list reload — stale-picker bug fixed) + VS + same rows for both players + per-row winner in gold + source labels for both + names tappable → profile. Batting AND bowling (V3 was batting-only — add bowling).
- **Data:** Cricsheet-calculated + provider basic profiles. Same source labelling as Profile.
- **Acceptance:** Compare shows batting + bowling, highlights per-row winner, pickers never go stale.

### C2) Venue / pitch / toss / venue records per player — OUR way
- **Match Detail → Info/Preview:** Venue name + pitch report text + weather (where available) + toss + umpires + referee + bat-first win % + avg 1st-innings score + bowler avg-vs-econ (Cricmetric pattern) + toss-impact line.
- **Player Profile → Venue section:** One row per venue (runs • avg • SR + bowling), current match's venue first. Hidden if no venue data (never "0 / 0 / 0").
- **Data:** Cricsheet (group by venue) + CricAPI (toss/venue/pitch) + TheSportsDB (venue metadata where available).

### C3) Favourites + notifications — OUR way
- **Favourites:** Teams + Players + Matches (V3 had players only — add teams). ⭐ toggle on player/team/match, persisted.
- **Notifications:** Per-match toggles: Wickets / Sixes / Start / Milestones / Result, opt-in, selective. Favourited matches pinned to top of Home (CREX PIN behaviour, FREE — never Premium-gated).
- **Honesty:** Until FCM is wired, label "Local reminders (push coming soon)". When FCM lands (Firebase free tier, planned), toggle gates real alerts.

### C4) Women's + U19 — OUR way
- **Filters:** Women + U19 as chips on Home + Leagues + Fixtures (not just tags). Classification: International / T20 / ODI / Test / League / Women / U19 (CREX pattern + U19 added).
- **Empty states:** Chip exists even with no data; empty state explains why ("No U19 matches yet — they will appear here when the source returns them").
- **Data:** CricAPI currentMatches (Women's matches already appear in V3 feed) + EliteSport + SportScore backstop. U19 coverage depends on provider — honest about gaps, never fake.

### C5) All domestic — OUR way
- **Leagues screen:** Chips per competition: IPL, PSL, BBL, T10, Ranji, SMAT, Vijay Hazare, County, Sheffield Shield, Super Smash, T20 Blast, Super 50 Cup, Women's, U19, International, All. Each chip shows ONLY its own matches.
- **Per-series:** Info (name/dates/format/teams) + Points Table (P/W/L/PTS/NRR, "Table not available" honestly when absent) + Top Players (top 3 runs + top 3 wickets in this league) + Matches (Live first, then Upcoming, then Recent — same Home card component, not a second card).
- **Data:** CricAPI series + EliteSport fixtures/series + TheSportsDB league lists.

### C6) Every player, batting + bowling, all formats, all levels, each league separate — OUR way
- **Profile:** Format Chips Test/ODI/T20/T10 on every Team/Player/Series screen. Batting by Format table + Bowling by Format table (same columns everywhere). "By League" section (one row per league). "By Venue" section. "Vs Opponent" section.
- **Data:** Cricsheet (format splits: IT20→T20, ODM→ODI, MDM→Test; league/event splits) + provider basic profiles (CricAPI/EliteSport) + mock fallback labelled Demo. T10: Cricsheet + CREX-style coverage (Abu Dhabi T10) where available; honest about T10 gaps in free sources.

### C7) Dismissal history — OUR way
- **Profile → Dismissal History:** Most frequent first: `"c Rohit b Bumrah — 3 times"`, plus `"Not dismissed by Shaheen in 42 balls"` (≥12 balls, 0 dismissals).
- **Data:** Cricsheet ball-by-ball → group by (dismissal kind, fielder, bowler, batter) → count. Run-outs NOT credited to bowler for bowler stats, but shown as fielding dismissals. Label: "Real • Cricsheet open data • N matches".
- **Acceptance:** Dismissal history is a section, not a footnote. No app in the set does this — it is KingCric's moat.

### C8) Bowler-vs-batter matchup — OUR way
- **Profile → Matchup:** One row per bowler: `Bowler • Matches • Dismissals • Runs • Balls • SR`, sorted by dismissals desc. Tapping a matchup bowler → that bowler's profile.
- **Data:** Cricsheet ball-by-ball → group by (bowler, batter) → balls, runs, bowler-credited dismissals (caught/bowled/lbw/stumped/hit-wicket). Same calculation as C7, different grouping.
- **Acceptance:** Matchup is a section, not a query tool. Cricmetric's query-tool pattern is the reference; KingCric's pre-computed section is the improvement.

### C9) Match-context view — OUR way
- **Match Detail → Squad tab:** EACH player row shows context line: `"vs Pakistan • T20: 142 runs • Avg 47.3 • SR 138.2"` + tap → full profile.
- **Profile (when opened from a match):** Hero + Prediction card (vs <Opponent> at <Venue>, <Format>) + Overall (all formats) + vs Opponent (<Opponent>) + Format (<Format>) + Other Formats + Combined (T20+ODI) + Full Table (all formats) + Leagues + Venue + Recent Form (overall + vs opponent) + Matchup + Dismissal + Bowling.
- **Rule:** Match section shows ONLY that match's opponent context. Never a generic career table without the opponent filter.
- **Data:** Cricsheet (vs-opponent + format + combined splits) + provider live form (CricAPI). Combined T20+ODI = sum of the two format splits (batting + bowling).

### C10) H2H — OUR way
- **Match Detail → H2H block:** Team H2H bar + counts: `"India [████░░] 8 — 5 Pakistan (13)"` + overall. Same data on Series screen where relevant.
- **Profile → vs Opponent = player H2H.** Profile → Matchup = player-vs-player H2H. No separate H2H screen — H2H lives where the user already is.
- **Data:** Cricsheet (team H2H from ball-by-ball outcomes) + provider H2H where available. Cricsheet team H2H is calculated, not hard-coded.

### D) Auto-update — OUR way
- **Live:** Poll on 10-min cache + manual Refresh + pull-to-refresh. "Last updated HH:MM" visible.
- **On finish:** AutoUpdateService detects live→completed transition → fetches final scorecard ONCE → validates (innings reconcile, else keep last verified) → recalculates career / vs opponent / venue / H2H / recent form / prediction inputs → emits via onMatchFinished.
- **Background (planned, not in V3):** WorkManager / Firebase Functions (free tier) for updates when app is closed + FCM push. Label honestly until wired.
- **Acceptance:** After a match finishes, opening the player profile shows the updated stats (recalculated), not stale numbers. No silent stale data.

### E) Data completeness — OUR way
- **Multi-source + cross-check:** CricAPI → EliteSport → EntitySport API → SportScore → TheSportsDB → cache → mock. On score mismatch between sources, keep primary + log, never crash, never replace verified with unverified.
- **Validation:** Innings reconcile (batting + extras ≈ total within tolerance) else keep last verified. No partial response crashes the scoreboard (fields default to empty/0).
- **Completeness flag:** `dataComplete` internally + source label externally: `Real • CricAPI • live` / `Real • Cricsheet open data • N matches in dataset` / `Demo data — curated sample, not live-verified` / `Partial • provider basic profile`. Never "Complete" on a 4-match sample or demo data.
- **Full career backfill (planned):** Cricsheet `all_json.zip` refresh → replace asset → rebuild, no code change; same parser recomputes, `sourceMatches` updates automatically. Bundled sample = 4 T20Is (real-over-sample, labelled with dataset size, NOT full careers).
- **Acceptance:** No screen shows a number without a source label. No demo/curated number labelled "Complete".

### F) Full version only — OUR way
- **Ship:** All screens (Home, Match Detail, Player Profile, Compare, Stats, Leagues, Favourites) + all features (C1–C10) + Hindi/English + AdMob slot (hidden until ID exists) in ONE APK. No Premium-gated scorecard/stats/compare/prediction. No login-gated stats.
- **Build order:** Internally step-by-step (V2 UI → multi-source → Cricsheet → V3 fixes → reference redesign → this mapping), but final deliverable = FULL version, not MVP.

### G) 100% free model — OUR way
- **Build cost ₹0:** Flutter + free APIs + free tiers only. No paid API, no paid tool, no paid asset.
- **Monetization:** AdMob banner only (when ID exists via `--dart-define=ADMOB_BANNER_UNIT_ID`), never full-screen on every resume, never covering the score, never a placeholder box when no ID.
- **Play Store:** $25 one-time Google Developer fee is Google's fee, not KingCric's build cost. APK distribution is free until ad earnings cover it. Listing will state: 2 permissions only (INTERNET + NETWORK_STATE) vs LineX's 19–26.

### H) Android first, Hindi + English, AdMob, Play Store — OUR way
- **Android first:** minSdk 24 (Android 7.0, same floor as LineX), targetSdk 36, arm64 + armeabi-v7a + x86_64 (universal APK via official Gradle build on GitHub Actions).
- **Hindi parity:** EN / हिं toggle in Home header, switching ALL labels (tabs, pills, empty states, buttons, prediction WHY lines). Never a mixed-language screen. `strings.dart` holds every user-facing string in EN + हिं.
- **AdMob:** See G. **Play Store:** Release keystore (not debug) + $25 fee when ready; current APK is debug-signed for sideloading only, NOT for Play Store upload.

### I) Presentation — OUR way
- **Home = check screen:** Live first, score biggest, equation, tap → detail. Nothing else competes (no news/videos/quizzes/fantasy tips on Home v1).
- **Match Detail = read screen:** Hero + equation + tabs (Live | Scorecard | Squad | Prediction + Preview/Info + Overs/Graph). Scorecard order: Batting → Extras → Bowling → FOW → Partnerships → Yet-to-bat. Never reordered.
- **Profile = study screen:** Fixed order (Hero → Key strip → Overall → vs Opponent → Format → Full Table → Leagues → Venue → Form → Matchup → Dismissal → Bowling → Source label). Empty sections hidden, never "0 / 0 / 0".
- **King skin:** Navy `#0B1026` + gold `#D4AF37` + gold gradients + crown + GoldDonut + StatBar + KingAvatar gold-ring. Layout = reference (familiar), skin = King (distinct). Do NOT redesign the scorecard layout — it is solved.

---

## 4. What KingCric will NOT do (learned from reference failures)

| Do NOT | Why (evidence) |
|--------|----------------|
| No ad on every resume / minimise | Single most upvoted LineX complaint (150 helpful); CREX/Cricbuzz ad complaints. Banner only, never interstitial on resume, never covering score. |
| No fake ad placeholder box | V3 bug: "Ad placeholder — AdMob unit id not set yet" in release. Render nothing when no ID. |
| No "Complete" on demo/curated data | V3 bug: Virat 27150 runs labelled "Complete" on curated data. Never. |
| No "faster than TV" / "instant" claim | Free tier = 10-min cached. LineX claims it and gets 1★ "very slow ball by ball". Claim "fast, honest live scores" + show "Last updated". |
| No fake Fantasy points | LineX has fantasy points from a real feed. KingCric: do NOT fake. Leave out until a real provider supplies it. |
| No betting / odds / session-betting UI | LineX disclaimer: "strictly informational/entertainment, no betting". KingCric: same disclaimer if win-% / prediction is shown. Never odds. |
| No Premium-gated PIN / Graphs / scorecard | CREX PIN + Graphs = Premium; Cricbuzz Handbook = Plus. KingCric: full for every user. |
| No scraping Cricbuzz/Cricinfo/Cricmetrics | ToS + blocking + breakage + Play Store rejection + legal risk. Official APIs + Cricsheet open data only. |
| No copying code / text / images / branding from any reference app | Study patterns only. KingCric code, data, and King identity are its own. |
| No mixed-language screen | CREX toggle is the model, but KingCric must have FULL parity (every label in Hindi when Hindi is on). |
| No silent stale data | Every screen shows "Last updated" + source label. No infinite spinner, no crash on offline (last verified cache + "Offline — showing last verified data"). |
| No truncation / mid-word cuts | V3 bugs: "King…", "Upcomin g", "Sweden Wom…". FittedBox + 2-line titles + horizontal-scroll tables + hint. |

---

## 5. Top 5 KingCric differentiators (why it is NOT a clone)

1. **Dismissal history + Bowler-vs-batter matchup as first-class profile sections** — no reference app does either as a section. Calculated from Cricsheet ball-by-ball, labelled honestly. This is the moat.
2. **Match-context squad view** — each squad row already shows vs-opponent + format + combined + recent form + prediction. No reference app pre-computes context; all make the user tap each player.
3. **Honest source labels + visible completeness** — every number carries Real/Demo/Partial + provider + dataset size. No reference app does this. Trust is the feature.
4. **Full version for every user, no paywall, lean permissions (2 vs LineX 19–26), no ad-on-resume** — the market gates features; KingCric does not.
5. **King identity + Hindi parity in ONE app** — navy+gold + crown + "Har Ball, Har Stat, King Jaisa." + EN/हिं toggle switching ALL labels. Cricbuzz needs a separate vernacular app; KingCric does it in one.

---

## 6. Acceptance checklist (before shipping the final redesign)

Run on a real phone (GT 6T), on the release APK. ALL must pass.

- [ ] Home opens in <2s, header reads **KingCric** in full, EN/हिं toggle visible.
- [ ] Default tab = Live. Live match (with scores, no result) appears under Live with LIVE pill, never under Upcoming. No live score under UPCOMING pill.
- [ ] Every team name Title Case, one team per row, no commas, no "Inning 1" in a name. Fixture title fully readable (max 2 lines).
- [ ] Tabs read Live / Upcoming / Recent (or Finished) in full, one line each, in EN and हिं.
- [ ] Match Detail Scorecard: Batting → Extras → Bowling → FOW → Partnerships → Yet-to-bat, with swipe hint. Tapping any player name → profile.
- [ ] Player Profile: Runs/Avg/SR/Wkts without scrolling, then Overall → vs Opponent → Format → Full Table → Leagues → Venue → Form → Matchup → Dismissal → Bowling, with source line under hero. No "Complete" on demo/curated data.
- [ ] Compare: batting AND bowling, per-row winner in gold, pickers never stale. Stats: format filter + min-qualifier labels. Leagues: Women's + U19 + domestic chips, points table + top players. Favourites: teams + players + per-match notification toggles.
- [ ] No "Ad placeholder", "TODO", or developer text anywhere. No fake Fantasy points. No "faster than TV" claim. "Last updated HH:MM" visible.
- [ ] In Hindi mode, EVERY label is Hindi. No mixed-language screen.
- [ ] After a match finishes, player stats recalculate (not stale). Offline shows last verified cache + banner, never a crash.

---

## 7. Sources (public, no scraping, no decompile)

- Play Store: CricketLineX / Just Cricket (`com.cricketLineX.CricketLineX`), Cricbuzz (`com.cricbuzz.android`), ESPNcricinfo (`com.july.cricinfo`), CREX (`in.cricketexchange.app.cricketexchange`)
- AppBrain: Cricbuzz, CREX, CricketLineX, SofaScore metadata + ratings + installs
- Similarweb / Uptodown / ViaAPK / Appcracy / Soft112: CricketLineX metadata + reviews
- Official sites: cricbuzz.com, cricmetric.com, sofascore.com, crex.com
- Statsguru / `cricketr` / `cricpy` docs: Statsguru dimensions (format × opponent × venue × home/away × result × date), `batsmanDismissals`, `batsmanAvgRunsGround`, `bowlerAvgWktsGround`, `getPlayerDataOppnHA`
- Cricmetric: win-probability model (XGBoost, monotone, range), venue analytics (bat-first win %, avg 1st-innings, bowler avg-vs-econ), matchup query
- CREX / Cricbuzz / LineX Play Store descriptions: win-% meter, fantasy tips, PIN, notifications, coverage lists, language options, Premium pricing
- AllCric comparisons: Cricbuzz win-probability (major matches), AllCric win-% + predicted score range + session predictions + player impact
- KingCric prior docs: requirements-v1.md, REFERENCE-SPEC.md, REFERENCE-APPS-DEEP-DIVE.md, CRICKETLINEX-REFERENCE.md, API-SETUP.md, MULTI-API.md, CRICSHEET-DATA.md, V3-fix commit 17ce998

> **Legal note:** This file describes *patterns* observed from public listings and sites. It contains no copied code, no copied data, no scraped API responses, and no branding assets from any reference app. KingCric's implementation, data, and King navy+gold identity are its own.
