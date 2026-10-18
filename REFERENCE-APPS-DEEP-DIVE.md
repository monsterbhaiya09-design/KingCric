# KingCric — Reference Apps Deep Dive

> **How this was researched (honest method note)**
> - Studied via **public** sources only: Google Play listings, AppBrain pages,
>   official websites (cricbuzz.com, cricmetric.com, sofascore.com), and public
>   user reviews. **No code was copied, no private API was scraped, no MOD /
>   re-signed APK was installed.** MOD / "Premium Unlocked" APKs that appear in
>   search results were deliberately NOT downloaded — they are re-signed,
>   untrusted, and would be unsafe + illegal to ship.
> - This VM has **no Android emulator / KVM**, so the reference apps were NOT
>   run on a device here. Layout claims below come from Play Store descriptions,
>   AppBrain screenshot sets (9 screenshots for Cricbuzz, 8 for CREX), official
>   site structure, and review text — not from decompiled code.
> - Goal: copy **UI/UX patterns** (layout, order, labels, what is shown first),
>   never copy text, data, branding, or code.

---

## 1. App inventory (public facts, Oct 2026)

| App | Package | Version (Oct 2026) | Size | Installs | Rating | Developer |
|---|---|---|---|---|---|---|
| **Cricbuzz** | `com.cricbuzz.android` | 16.11.01 (9 Oct 2026) | ~37.6 MB Play / ~85.7 MB APKMirror bundle | 240M tracked / 100M+ Play badge | 3.91 ★ (3.13M ratings) | Cricbuzz.com / CRICBUZZ PLATFORMS LIMITED |
| **ESPNcricinfo** | `com.july.cricinfo` | updated 29 May 2026 | ~30 MB (reported) | 10M+ | 4.8 ★ (353K ratings) | JIOSTAR INDIA PRIVATE LIMITED |
| **CREX – Just Cricket** | `in.cricketexchange.app.cricketexchange` | 26.10.03 (5 Oct 2026) | ~67 MB Play | 100M+ | 4.36–4.4 ★ (550K ratings) | CREX / PARTH TECH DEVELOPERS LLP |
| **Cricmetric** | Web-first (cricmetric.com) | — | — | — | — | Cricmetric (analytics site + blog) |
| **CricMetry** | `com.cricmetry.*` | 1.0.5 (Aug 2025) | ~35 MB | 10+ / 31 total (AppBrain) | No ratings | CricMetry |
| **SofaScore** (bonus, multi-sport) | `com.sofascore.results` | Aug–Sep 2026 | — | 100M+ (all sports) | High | SofaScore |
| **CricketLineX ★ USER'S PICK** | `com.cricketLineX.CricketLineX` (now rebranded as **Just Cricket: Fast Live Score**) | 5.0.12 | — | 5M+ (LineX) / 15M downloads, 100K+ reviews, 4.5★ as Just Cricket | 4.0–4.4 ★ (79.8K–116K reviews) | ENTITY DIGITAL SPORTS PRIVATE LIMITED (Harish@entitysport.com, Jaipur) |

Key takeaway: **Cricbuzz = reach, CREX = speed + simplicity, Cricinfo = depth,
Cricmetric = analytics, CricketLineX = fastest live line + graphs + fantasy.**
KingCric must feel like CricketLineX/CREX in 2 seconds, and like
Cricinfo/Cricmetric when the user digs deeper.

> **User's explicit pick (2026-10-18):** User sent
> https://play.google.com/store/apps/details?id=com.cricketLineX.CricketLineX
> and said *"yeh bhi bahut accha hai"* — CricketLineX is the **primary
> reference** for KingCric. §4A below is therefore the controlling section;
> §14 is updated to reflect this (CREX is now secondary).

---

## 2. Cricbuzz — screenshot-by-screenshot breakdown

**Store promise:** "The world's No.1 cricket app, now featuring live streaming of
IPL, World Cup etc" + "Superfast scores and commentary".

**What the 9 Play Store screenshots + site show:**

1. **Home / Matches list (the core screen)**
   - Top: search bar + top nav (Live Scores / Schedule / Archives / News /
     Series / Teams / Videos / Rankings / More).
   - Matches are **grouped by status/section**, not one flat list:
     `ALL | Live Now | Today | INTERNATIONAL | LEAGUE | DOMESTIC | WOMEN`.
   - Inside each group, each row is: **Series name → Fixture ("IND vs SL") →
     Match label ("2nd Semi-Final") → Score lines → Result/status line**.
   - Live rows carry a **LIVE pill**; finished rows carry result ("IND won");
     upcoming rows carry start time, not a score.
   - **Pattern:** status is never inferred from the score alone — the app has
     an explicit `LIVE / RESULT / Upcoming` label on every card, and the
     filter tabs match that label exactly. (KingCric V3 broke this: a live
     match appeared under Upcoming.)

2. **Match detail (Live)**
   - Hero: **current score big** (e.g. `IND 192/6 (20.0)`), overs, run rate,
     batsmen at crease, bowler, "need X in Y balls" equation line.
   - Tabs (in this order): **Live / Scorecard / Commentary / Squads / Info**
     (sometimes: Commentary / Scorecard / Info / Squads).
   - Ball-by-ball commentary is **short lines, one ball per line** — not
     paragraphs. Cricbuzz commentary is "crisp, speed-first"; Cricinfo is
     "descriptive, neutral". Both are one-ball-per-row.
   - Scorecard (see §6 for full column spec) is per-innings, batting then
     bowling, then Extras / Total / Fall of Wickets / Did Not Bat.

3. **Player profile / Stats**
   - Profile: photo + name + role + team at top; then **Batting / Bowling**
     career tables by format (Test / ODI / T20I).
   - Deeper: **Rankings, Stats and Records** section; Archives for old
     scorecards. Cricbuzz does **NOT** expose a free-form Statsguru-style
     query builder — stats are pre-built tables, not a query tool.
   - **Pattern:** format tables use the same columns everywhere
     (M / Runs / Avg / SR / 100s / 50s for batting; M / Wkts / Avg / Econ /
     Best for bowling).

4. **Other screens**
   - **Series:** series page → fixtures + points table + top players + squads
     + series news.
   - **News / Videos:** editorial + video highlights; separate from scores.
   - **Rankings:** ICC Men / Women, team + player rankings.
   - **Notifications:** live match + breaking news, per-team follow.
   - **Languages:** English + regional languages on web; app follows device.

5. **Look & feel**
   - Light background, green accent (brand), **lots of white space, clear
     fonts** — reviews praise "clean and readable" and criticise **intrusive
     ads** (badly-timed in-match ads, repeated same ad, stream crashes) and
     **subscription restrictions**. Lesson: ads must never cover the score;
     a fake "Ad placeholder" box is worse than no ad at all.
   - **Size discipline:** ~18 MB in early mobile-first builds (per analysis),
     ~37 MB now. Light = fast on patchy networks.

**What KingCric MUST copy (pattern, not code/data):**
- Grouped match list (Live Now → Today → International / League / Domestic /
  Women), explicit status pill on every card, filter tabs that match pills.
- Hero score + equation line at the top of Match Detail.
- One-ball-per-line commentary, short lines.
- Pre-built format tables, same columns everywhere.

**What KingCric must NOT copy:**
- Ad density / badly-timed interstitials; subscription paywalls that block
  the scorecard; India-only bias ("just for Indian cricket" 1★ reviews).

---

## 3. ESPNcricinfo — screenshot-by-screenshot breakdown

**Store promise:** "Widest cricket coverage across the world" — IPL, PSL, BPL,
BBL, CPL, ICC World Cup, County Championship, Ranji Trophy, Sheffield Shield.

**What the listing + site show:**

1. **Home**
   - Feed mixes **live scores + news + videos + expert opinion** (Gambhir,
     Moody, Manjrekar, Agarkar, Chopra, Dasgupta). More editorial than
     Cricbuzz; heavier, more complete, slower to scan.
   - **Pattern:** Cricinfo optimises for **engagement + completeness**
     (long reads on laptop); Cricbuzz optimises for **latency + accessibility**
     (quick score on the move). KingCric must do Cricbuzz-style scanning on
     Home, Cricinfo-style depth on Player Profile.

2. **Match detail**
   - Same core: score hero → Scorecard → Commentary → Squads → Info.
   - Commentary is **descriptive and neutral**, occasionally with user
     comments / insights. Longer than Cricbuzz, slower to load.

3. **Player profile / Statsguru (the killer feature)**
   - Profile → career tables by format + **Statsguru**: custom queries
     filtered by **team, opposition, ground, date range, home/away, result,
     innings** — e.g. "Kohli vs Pakistan, away, 2020–2026, batting".
   - This is the model for KingCric's **vs-opponent / venue / format /
     combined** splits. KingCric must offer the *answers* (pre-computed
     splits), not a raw query builder — the user should not have to build a
     query to see "Virat vs Pakistan".
   - Statsguru data is used by the `cricketr` R package (batting/bowling by
     format, home/away, opposition, venue, timeline of wins/losses) — that
     proves the split dimensions users actually query: **format × opponent ×
     venue × home/away × result × time**.

4. **Other screens**
   - Series, Teams, Players browse; Rankings; Records; Archives.
   - Videos: Highlights / Analysis / Interviews / Press conferences.

5. **Look & feel**
   - Denser than Cricbuzz; **menu can clutter with too many tabs** (review
     complaint). Lesson: KingCric must keep bottom nav to **5 items max**
     and put the rest under More/Series.
   - Rating 4.8 ★ (much higher than Cricbuzz 3.91) — users reward depth +
     fewer ads, even if the app is heavier.

**What KingCric MUST copy:**
- Statsguru *dimensions* (format × opponent × venue × home/away × result)
  as pre-computed profile sections with clear headings.
- Series / Teams / Players browse + Archives (old scorecards reachable).
- Editorial separation: scores first, news second — never mix news into
  the scorecard.

**What KingCric must NOT copy:**
- Cluttered menu / too many tabs; heavy web-adapted layout on mobile.

---

## 4. CREX — screenshot-by-screenshot breakdown

**Store promise:** "Cricket live scores, real-time news, commentary, stats &
more" + "Instant ball-by-ball live updates".

**What the 8 Play Store screenshots + listing show:**

1. **Home**
   - Sections in this order: **Ongoing matches → Upcoming fixtures →
     Recently completed games → Series standings** (quick access).
   - **Pattern:** Home is a *feed*, not a database. The user sees what's
     happening *now* first, then what's next, then what finished.

2. **Match detail**
   - Live: score hero + **win probability meter** (updates with live
     conditions) + ball-by-ball commentary with **"small to big unique
     stats, clearly shown with numbers"** (review praise).
   - Scorecard: **detailed scorecard with wicket descriptions**
     ("c X b Y" on every dismissal) + **partnership statistics** +
     cumulative stats.
   - Tabs: **Home / Matches / Series / Fixtures** (bottom) + match-level
     tabs for Scorecard / Commentary / Info / Squads.
   - **Pin Live Score:** tap PIN icon → match rises to top of feed /
     stays visible (Premium). KingCric equivalent: Favourites / Pin.
   - **Graphs:** odds history + statistical trend graphs (Premium).
     KingCric equivalent (free): stat bars + GoldDonut + win-% bar — same
     *idea* (visual trend), different implementation.

3. **Player / Team**
   - Tap any player/team → **deep insights & stats** (form, rankings,
     records). **Fantasy tips** by experts (Aakash Chopra) + pre-match
     insights + strategic analysis.
   - **Player Stats Tab** inside Series Profile: top performers directly in
     series view (new in 26.x update).
   - **Format Chips:** filter team matches by format (Test/ODI/T20).
   - **Live Timers:** Stumps & Timeouts in real-time.

4. **Other screens**
   - **Series:** complete series info, points tables, top players, squads,
     series-specific news/highlights.
   - **Fixtures:** browse by **day / series / team**; classified into
     International / T20 / ODI / Test / League / Women.
   - **More:** ICC Men's Ranking, ICC Women's Ranking, **Change app
     language** (English / Hindi / Bengali), Premium info.
   - **Social:** Discussions, quizzes, fantasy tips, communities for
     favourite teams/players.

5. **Look & feel**
   - **Clean, no clutter, everything accessible quickly** (review).
   - **Speed is the brand:** "Super Fast Updates. You can get score before
     the live on OTT apps", "faster than most other apps I follow",
     "stats are simple and easy to understand, unlike Cricbuzz where stats
     are complicated".
   - **Complaints to avoid:** heavy data usage ("consumes far more data
     than Instagram"), irritating / sexual ads, new-version regressions
     ("new version is worst, old was best"), buffering on video.
   - Languages: **English / Hindi / Bengali** — KingCric's Hindi+English
     toggle matches this pattern; keep it in the header, not buried.

**What KingCric MUST copy:**
- Home order: Ongoing → Upcoming → Recently completed → Series standings.
- Wicket descriptions on every dismissal + partnership block + win-% bar.
- Format Chips (Test/ODI/T20/T10) on Team/Player/Series screens.
- Fixtures by Day / Series / Team; classification by format + Women.
- Pin / Favourite that lifts a match to the top.
- Simplicity rule: **every stat explained in one line** ("CREX explains
  simply; Cricbuzz confuses") — KingCric must label every number.

**What KingCric must NOT copy:**
- Heavy data usage (cache aggressively, 10-min TTL); video buffering;
  Premium-gated Pin/Graphs; intrusive ads.

---

## 4A. CricketLineX — PRIMARY REFERENCE (user's pick: "yeh bhi bahut accha hai")

**Store promise:** "Tired of delayed scores? Get the World's Fastest Live
Cricket Score with Live Line updates, Ball-by-Ball Commentary, and real-time
Stats." / "Trusted by 15 million cricket fans. Just Cricket (previously
Cricket LineX) gives you the fastest cricket live score updates in India."

**Identity notes:**
- Package `com.cricketLineX.CricketLineX`, developer **ENTITY DIGITAL SPORTS
  PRIVATE LIMITED** (Jaipur, support `cricketlinex@gmail.com` /
  `Harish@entitysport.com`). This is the **same EntitySport** that KingCric
  already uses as a tertiary API provider — a useful coincidence, NOT a
  licence to copy LineX's app or scrape its API. Patterns only, never data/code.
- The app has been rebranded on Play Store as **Just Cricket: Fast Live
  Score** ("previously Cricket LineX"). Same package, same lineage.
- Ratings: 4.0 ★ (116K reviews) on one listing snapshot, 4.4 ★ (79.8K) on an
  earlier snapshot; ViaAPK: 4.4 ★, ~85K ratings, 5M+ installs; as Just
  Cricket: 4.5 ★, 100K+ reviews, 15M downloads, 30+ countries.
- Disclaimer on listing: "strictly for informational and entertainment
  purposes only. We do not provide, facilitate, or promote any form of
  betting, gambling, or wagering." KingCric must carry the same disclaimer
  if it ever shows odds/session info — it currently does not, and must not
  imply betting.

**What the Play Store listing + reviews show, screen by screen:**

1. **Home**
   - **Home tab with trending matches** — not a flat list. Trending / live
     matches first, then the rest. ViaAPK's first-use test: "Opened the app,
     found the live game, and could keep up with the score and commentary at
     a glance. That simple job is where a cricket score app earns its place."
   - **Live / Upcoming / Finished matches** — the exact three-way split
     KingCric uses. LineX's version is the model: the three tabs are
     **mutually exclusive and status-accurate** (a live match never appears
     under Upcoming — the exact bug KingCric V3 had).
   - **Quick navigation for IPL live matches** — marquee tournament gets a
     shortcut, not a buried menu.

2. **Match Detail (the core — "Live Line" is the brand)**
   - **Live Line:** the fastest ball-by-ball line. Users report "before ball"
     / "super fastest" / "faster than TV" — speed is the entire brand.
     KingCric cannot match paid low-latency feeds on a free 100/day quota,
     so it must be **honest about 10-min cached ball-by-ball** and win on
     clarity, not fake "faster than TV" claims.
   - **Live scorecard:** full batting + bowling breakdown, same columns as §6.
   - **Ball-by-ball commentary:** "smart, clear, and instant updates" —
     short lines, one ball per line (same as Cricbuzz/CREX).
   - **Live cricket scorecard + stats:** live match stats + performance data,
     **over-by-over analysis**, **session updates**, **match highlights &
     key moments**.
   - **Live line & match graphs:** **deep over-by-over analysis** via
     **charts and graphs** — this is LineX's differentiator vs Cricbuzz.
     KingCric's equivalents: GoldDonut + stat bars + win-% bar + (next)
     over-by-over run/wicket mini-graph. Do NOT copy LineX's graph styling;
     copy the *idea* (one small graph per live match).
   - **Fantasy cricket points:** live player performance tracking, "perfect
     for Dream11 users". KingCric equivalent: player impact bar on scorecard
     (runs + SR + wickets → impact), labelled as KingCric's own calculation,
     never as official fantasy points.
   - **Playing XI, squads & pitch report + weather:** full match preview on
     the same Match Detail screen (Info tab).
   - **Head-to-head stats + ICC rankings:** inside Match Detail / Series.
   - **Smart notifications:** wickets, sixes, match start, milestones.

3. **Series**
   - **Series tab with points table & squads** — overview + upcoming + live +
     completed matches per series, including Ranji Trophy / Ford Trophy
     (domestic coverage is a LineX strength: "comprehensive coverage of
     international and domestic cricket").
   - Coverage: IPL, T20 World Cup, ODI World Cup, Test Championship,
     Champions Trophy, Asia Cup, BBL, PSL, SA20, ILT20, BPL, CPL, The
     Hundred, Ranji Trophy, County Championship, all international tours
     + domestic matches.

4. **Player / Team / Rankings**
   - **Player Stats, Rankings & Teams:** ICC rankings & stats, player
     performance records, team analysis & comparisons, squad details for
     every match.
   - **Historical records & stats:** legendary innings, milestones, records
     broken, all-time player/team stats.

5. **News**
   - **News Home Feed:** short videos, latest infographics, cricket news.
     LineX keeps news as a *feed*, separate from scores — same rule as §3.

6. **Look & feel**
   - **"Clean interface, smooth performance, detailed match insights"**
     (689 people found this review helpful). **"Clean, smooth, fast"** is
     repeated across 5★ reviews.
   - **Dark mode & light mode support** — LineX offers both; KingCric is
     dark-navy-only today. Add a Light mode later; do not block V3 on it.
   - **Dynamic Animations:** listed in "What's new" ("Watch your
     interactions come to life") + "Smooth Performance: glide through the
     app effortlessly". KingCric's LivePulse + AnimatedScore are the same
     idea — keep animations **one-shot / interruptible**, never infinite
     (infinite breaks tests + drains battery).
   - **Complaints to avoid (from 1★ / 4★ reviews):**
     - Ads on every minimise/reopen ("every time I minimise and open it,
       that shows ad which is so annoying" — 101 found helpful).
     - Score bugs: pinned score "always shows 6", "showing 4 is 6",
       occasional lag. **KingCric must regression-test pinned/favourite
       scores + boundary display** — a wrong 4/6 is a trust-killer.
     - Premium login forcing ads after purchase ("purchased premium, now
       not able to login and forced to see ads"). KingCric has no premium
       tier — never gate the scorecard behind login/paywall.

**What KingCric MUST copy from CricketLineX (pattern, not code/data):**
- Home: **Trending matches first** + Live / Upcoming / Finished tabs that
  are mutually exclusive + quick navigation to the marquee tournament.
- Match Detail: **Live Line hero** (score + equation + current over) +
  **over-by-over mini-graph** + **session updates** + **fantasy-style
  player impact** + Playing XI + pitch + weather + H2H on one screen.
- Series tab: overview + points table + squads + upcoming/live/completed.
- **Speed + clarity as brand:** every screen must answer in 2 seconds;
  every number labelled; no fake "faster than TV" claim on a cached feed.
- **Clean interface + smooth performance + dynamic (one-shot) animations**
  + Dark/Light mode (Light later).
- **Informational-only disclaimer** if odds/session info is ever shown.

**What KingCric must NOT copy from CricketLineX:**
- Ad on every resume/minimise; any ad covering the score; Premium login
  gating; "live line" betting-adjacent framing (no odds, no session betting
  UI); any claim of sub-second live on a free 100/day quota.

## 5. Cricmetric — analytics reference (web, not a mass-market app)

**What it is:** Analytics site + blog. Not a 100M-install app. Its value is
**how it shows analytics**, not its reach.

- **Scoreboard:** runs + balls + wickets per player per innings, **WPA
  (Win Probability Added)** per player, current score above the win-probability
  graph, click a player name → detailed player stats. **Pattern:** every
  scorecard row is tappable → profile. KingCric already does this; keep it.
- **Win Probability model:** XGBoost ("panel of 1,000 analysts"), monotone
  constraints (more runs ⇒ higher win %, losing wickets ⇒ lower win %),
  innings-break consistency override, volatility / range of possible scores
  (not a single number). **Pattern:** KingCric's prediction must show a
  **range + reason**, not a fake-precise single % with no explanation.
  Show "Likely / Risky / Unlikely" + Hindi/English reason (already planned).
- **Venue analytics:** H2H records, Venue Outcomes (bat-first win %),
  Average 1st Innings Scores over time, Venue Bowler Stats (average vs
  economy scatter by bowling style). **Pattern:** Venue screen must show
  **bat-first win %, avg 1st-innings score, bowler avg-vs-econ** — not just
  "pitch: dry".
- **Chart embedding:** static analytics for previews/reviews. KingCric
  equivalent: shareable stat cards (later, not V3).

**What KingCric MUST copy:**
- WPA-style per-player impact (even a simple version: runs + SR + wickets
  → impact bar) on the scorecard.
- Venue screen with 3 charts: bat-first win %, avg 1st-innings score trend,
  bowler avg-vs-econ.
- Prediction with monotone sanity (score up ⇒ win % up; wicket ⇒ win % down)
  + range + reason.

**What KingCric must NOT copy:**
- Academic tone / blog-first layout; Cricmetric is for analysts, not for a
  2-second score check. KingCric must hide the maths behind one-line reasons.

---

## 6. Scorecard — the canonical column spec (all apps agree)

### Batting (per innings, in batting order)
| Col | Meaning | Notes |
|---|---|---|
| Batter | Name + dismissal line (`c X b Y`, `b Y`, `st X b Y`, `run out (X)`, `lbw b Y`, `not out`) | Dismissal on second line, smaller font; "not out" highlighted |
| R | Runs | Bold |
| B | Balls faced | |
| 4s | Fours | |
| 6s | Sixes | |
| SR | Strike rate = R×100/B | 1 decimal |
| **Total** | `192/6 (20.0 ov)` + Extras line | Extras: `Wd 3, Nb 1, B 1, Lb 2 (7)` — never fold extras into a batter |

### Bowling (per innings, in bowling order)
| Col | Meaning |
|---|---|
| Bowler | Name |
| O | Overs (e.g. `4.0`, `3.2` = 3 overs + 2 balls) |
| M | Maidens |
| R | Runs conceded |
| W | Wickets |
| Econ | Economy = R / O |
| Wd / Nb | Wides / No-balls (or combined `Wd/Nb`) |

### Below the tables (every app shows these, in this order)
1. **Extras** (full breakdown, not just a total)
2. **Total** (runs/wkts + overs)
3. **Fall of Wickets** — numbered: `1-48 (Rohit, 5.2 ov), 2-79 (Gill, 9.4 ov)…`
4. **Partnerships** — per wicket: `3rd wkt: 61 (42 balls) — Kohli + Surya`
5. **Yet to Bat / Did Not Bat** — chips, not a table
6. **Match Info** — Toss, Venue, Umpires, Referee, Pitch report

### Equation line (live 2nd innings only, above the scorecard)
`Austria Women need 88 runs in 78 balls` — always one line, always above
the batting table, never inside a card footer.

---

## 7. Player Profile — canonical section order (Cricinfo + CREX + Cricbuzz)

1. **Header:** Photo / initials avatar + Name + Role + Team + Batting style +
   Bowling style + Country. (Cricinfo: photo left, name + role right.)
2. **Key numbers strip:** Runs (overall) • Avg • SR • Wkts — 4 numbers, big.
3. **Batting by Format** table: `Format | M | Inn | Runs | Avg | SR | 100s | 50s | HS`
4. **Bowling by Format** table: `Format | M | Wkts | Avg | Econ | SR | Best | 5w`
5. **Vs Opponent** (this match's opponent first, then all): same batting +
   bowling columns, filtered.
6. **By Venue** (this match's venue first): same columns, filtered.
7. **By League** (IPL / PSL / BBL / T10…): same columns, filtered.
8. **Recent Form** — last 5–10, most recent first: `vs X • Format • Runs (Balls) / Wkts • Result (W/L)`.
9. **Bowler-vs-Batter Matchup** — `Bowler X dismissed Batter Y N times in M balls, N runs` + "Never dismissed by Z in N balls" (if ≥12 balls, 0 dismissals).
10. **Dismissal History** — `c X b Y — N times` lines, most frequent first.
11. **Source label (KingCric-only, mandatory):** `Real • Cricsheet open data • N matches` OR `Demo • curated sample, not live-verified` OR `Partial • provider basic profile`. Never show a curated number with a "Complete" badge.

**Compare screen (all apps agree):** two players side-by-side, same rows,
same order as above, winner cell highlighted in gold/green. No extra columns.

---

## 8. Home / Match card — canonical layout (text mockup)

```
┌──────────────────────────────────────────────┐
│ [LIVE ●]  T20 • ECA Women's European Cup    │  ← status pill + format + series
│                                              │
│ Austria Women               37/3 (7.0 ov)   │  ← team name left, score right, bold
│ Sweden Women               124/9 (20.0 ov)   │
│                                              │
│ Austria Women need 88 runs in 78 balls      │  ← equation OR result, one line
│ 📍 Moara Vlasiei Cricket Ground, Bucharest  │  ← venue, one line, ellipsis
│ ──────────────────────────────────────────── │
│ Tap for FULL scorecard →                     │  ← one CTA, not two
└──────────────────────────────────────────────┘
```

Rules that every reference app follows (and KingCric V3 broke):
- **One team per line.** Never `TeamA,TeamB` on one line (V3 bug).
- **Score is right-aligned, same column** for both teams.
- **Status pill = filter.** If pill says LIVE, the card is in the Live tab.
  If pill says UPCOMING, there is no score. If pill says RESULT, there is
  a result line. No exceptions.
- **Team names Title Case.** `Bulgaria Women`, never `bulgaria women`.
- **Venue one line, ellipsis.** Never wrap venue into 2 lines that push
  the score off-screen.
- **One CTA.** "Tap for FULL scorecard →" — not two competing links.
- **Header shows full app name.** `KingCric` must never truncate to `King…`.
  Use FittedBox / smaller font / shorter subtitle, not ellipsis on the brand.
- **Tabs never wrap.** `Live | Upcoming | Recent` — one line, no `Upcomin g`.
- **No fake ad box.** If no AdMob ID, render nothing (SizedBox.shrink).

---

## 9. Bottom nav / Top nav — canonical (all apps)

- **Bottom nav (5 max):** Home • Matches • Series • Stats • More
  (KingCric current: Home • Leagues • Compare • Stats • Favourites —
  keep 5, but rename Leagues → Series to match user mental model, and put
  Compare + Favourites inside More or as top-level only if space allows.
  Decision: keep current 5 for V3, revisit after reference-spec review.)
- **Top nav (Home):** Search bar (always visible, top) + Language toggle
  (EN / हिं) in header + Live/Upcoming/Recent filter tabs below search.
- **Match Detail tabs (in order):** Live • Scorecard • Commentary • Squads •
  Info (H2H + Venue + Toss inside Info, not a separate top-level tab).
- **Series screen:** Fixtures + Points Table + Top Players + Squads + News.

---

## 10. Colours / Fonts / Premium vs Boring

| App | Colours | What feels premium | What feels boring |
|---|---|---|---|
| Cricbuzz | Green accent, white bg, dark text | White space, big scores, fast load | Too many ads, flat cards |
| Cricinfo | Red/blue, dense, editorial | Depth, Statsguru, expert bylines | Cluttered menu, heavy |
| CREX | Dark + green, bold scores | Speed, simple stats, win-% meter, graphs | Heavy data, video buffering |
| SofaScore | Dark, rating-centric, heatmaps | Ratings, heatmaps, momentum charts | Multi-sport generic |
| **KingCric** | **Dark navy `#0B1026` + gold `#D4AF37`** | **Gold gradient hero, LivePulse dot, GoldDonut, stat bars, big bold scores, crown avatar** | **Plain cards, plain colours, no pulse, no charts, truncated text** |

**KingCric premium rules (keep):**
- Navy + gold gradient on hero cards, gold borders (1.2–1.4), double shadows.
- LivePulse dot (one-shot, not infinite — infinite breaks `pumpAndSettle` tests).
- GoldDonut for win-% / completion; stat bars for Avg/SR/Econ.
- Bold 20px+ scores, w900 headings, generous padding (16px card, 12px rows).

**KingCric boring traps (avoid):**
- Plain white cards with grey text and no hierarchy.
- Numbers without labels ("27150" with no "runs" + no source).
- Fake placeholders ("Ad placeholder", "Complete" on demo data).

---

## 11. Feature inventory — what every top app has (KingCric checklist)

- [x] Live scores + ball-by-ball commentary (short lines)
- [x] Full scorecard (batting/bowling/FOW/partnerships/extras/Yet-to-bat)
- [x] Upcoming fixtures + Recent results (filter tabs = status pills)
- [x] Series / Leagues (fixtures + points table + top players + squads)
- [x] Player profiles (format / vs-opponent / venue / league / form / matchup)
- [x] Player Compare (side-by-side, same rows)
- [x] Stats leaders (top scorers / top wicket-takers, by format)
- [x] Favourites (team/player follow) + Notifications (match start, wicket, milestone, result)
- [x] Search (player / team / match, instant)
- [x] Language toggle (EN / हिं — CREX also has Bengali; KingCric: EN+HI first)
- [x] Venue / Pitch + Toss impact
- [x] H2H (team + player)
- [x] Win probability / Prediction (with reason + range, not fake-precise %)
- [x] Rankings (ICC Men/Women, team + player) — *KingCric: add in next pass*
- [x] Archives (old scorecards reachable) — *KingCric: add in next pass*
- [ ] News / Videos — *KingCric: NOT in V3 (scores + stats first); add later, never inside scorecard*
- [ ] Live streaming — *KingCric: NOT in scope (rights); never promise it*

---

## 12. What KingCric MUST copy vs MUST NOT copy

### MUST copy (layout, not code/data)
1. Home order: Ongoing → Upcoming → Recently completed → Series standings.
2. Match card: one team per line, score right-aligned, status pill = filter.
3. Match Detail tabs: Live • Scorecard • Commentary • Squads • Info.
4. Scorecard columns: Batter R B 4s 6s SR / Bowler O M R W Econ Wd Nb + FOW + Partnerships + Yet-to-bat + Match Info.
5. Player Profile section order (§7) + Statsguru dimensions as pre-computed splits.
6. Format Chips (Test/ODI/T20/T10) on Team/Player/Series.
7. Fixtures by Day / Series / Team; classification by format + Women.
8. Pin / Favourite lifts match to top.
9. Win-% bar + reason (Cricmetric monotone rule: score up ⇒ win % up).
10. Search always visible; language toggle in header; 5-item bottom nav max.

### MUST NOT copy
1. Ad density / badly-timed interstitials / fake ad placeholder boxes.
2. Subscription paywalls that block the scorecard.
3. India-only bias; cluttered menus with too many tabs.
4. Heavy data usage / video buffering (cache, 10-min TTL, no auto-video).
5. MOD / re-signed APKs; scraping Cricbuzz/Cricinfo/Cricmetric data or APIs.
6. Fake "Complete" badges on demo/curated data; fake-precise prediction %.

---

## 13. KingCric differentiation (why it is NOT a clone)

- **King theme:** navy + gold, crown avatar, "Har Ball, Har Stat, King Jaisa."
  No reference app uses this royal identity — it is KingCric's alone.
- **Deeper analytics than Cricbuzz/CREX:** vs-opponent + venue + league +
  bowler-vs-batter + dismissal history + recent form on *every* profile, not
  just career tables. Cricinfo has Statsguru (query builder); KingCric gives
  the *answers* pre-computed.
- **Honest source labels:** every number carries `Real • Cricsheet` /
  `Real • CricAPI` / `Demo` / `Partial`. Reference apps do not label sources;
  KingCric does, so the user never mistakes demo for real.
- **Free model:** 100% free, no paywall on scorecard, no fake premium.
- **Hindi + English:** first-class toggle, not an afterthought.

---

## 14. PRIMARY REFERENCE PICK (updated — user's pick overrides earlier draft)

### Primary: **CricketLineX** ("yeh bhi bahut accha hai" — user, 2026-10-18)

**Why CricketLineX (primary, per user):**
1. **User likes it most.** The user explicitly named LineX as the app to
   copy from. That settles the pick — CREX moves to secondary.
2. **"Fastest live line" + graphs + fantasy is exactly KingCric's brief:**
   Home with trending matches first, Live / Upcoming / Finished tabs that
   are mutually exclusive, Match Detail with live-line hero + over-by-over
   mini-graph + session updates + fantasy-style player impact + Playing XI +
   pitch + weather + H2H on one screen, Series tab with points table +
   squads. That is the screen-by-screen template for KingCric's final
   redesign (see §4A).
3. **Clean + smooth + dynamic animations** is what its 5★ reviews praise
   ("clean interface, smooth performance, detailed match insights") —
   the same three words KingCric's user wants ("not boring, not confusing,
   everything visible").
4. **LineX's failures are KingCric's checklist:** ad on every resume, wrong
   4/6 on pinned scores, lag, Premium-login gating. KingCric must avoid all
   four (cache, honest labels, no paywall on scorecard, regression tests for
   4/6 + pinned scores).

**Secondary: CREX** — for speed + simplicity ("faster than most", "stats
simple and easy"), Home feed order (Ongoing → Upcoming → Recently
completed → Series standings), one-team-per-line cards, wicket
descriptions, partnership block, win-% meter, Format Chips,
Fixtures-by-Day/Series/Team.

**Secondary: Cricbuzz** — for grouped match list (Live Now / Today /
International / League / Domestic / Women), hero score + equation line,
one-ball-per-line commentary, and pre-built format tables.

**Depth: ESPNcricinfo + Cricmetric** — for Statsguru dimensions (format ×
opponent × venue × home/away × result) and venue/win-probability analytics.
Use them for Player Profile + Venue + Prediction, never for Home layout.

> **Companion spec:** A parallel worker produced `REFERENCE-SPEC.md`
> (567+ lines) from the same sources — product rule: *KingCric = Cricbuzz
> speed + CREX clarity + Cricinfo depth + Cricmetric analytics, in King
> navy+gold skin, every number readable in 2 sec Hindi/English*, with 12
> non-negotiable patterns + per-screen MUST-show specs + 20-point checklist.
> This deep-dive (§4A + §14) and REFERENCE-SPEC.md agree: LineX is primary.
> The final redesign must merge **V3-fix commit 17ce998 + this deep-dive +
> REFERENCE-SPEC.md**, then push once and build once.

---

## 15. Top 10 UI patterns KingCric MUST adopt (action checklist)

1. **Status pill = filter, always.** LIVE card ⇒ Live tab. UPCOMING ⇒ no score.
   RESULT ⇒ result line. No exceptions, no "live match under Upcoming".
2. **One team per line, score right-aligned.** Never `TeamA,TeamB` on one line.
3. **Hero score + equation line** at the top of every Match Detail:
   `Austria Women need 88 runs in 78 balls` — one line, above the table.
4. **Scorecard columns fixed:** Batter R B 4s 6s SR / Bowler O M R W Econ
   Wd Nb + Extras + Total + FOW (numbered) + Partnerships + Yet-to-bat.
5. **Player Profile in §7 order** — Header → Key strip → Batting by Format →
   Bowling by Format → Vs Opponent → Venue → League → Recent Form →
   Matchup → Dismissal History → Source label.
6. **Format Chips** (Test/ODI/T20/T10) on every Team/Player/Series screen.
7. **Fixtures by Day / Series / Team**, classified by format + Women.
8. **Full names, Title Case, never truncated mid-word.** `KingCric` in header
   (FittedBox), `Bulgaria Women vs Sweden Women` on 2 lines if needed,
   venue on 1 line with ellipsis.
9. **No fake boxes.** No "Ad placeholder", no "Complete" on demo data.
   Every number carries a source label (Real / Demo / Partial).
10. **2-second rule.** A new user opening Home must answer in 2 seconds:
    "Which matches are live? What's the score? What do I tap next?"
    If any card fails that test, the layout is wrong.
11. **(LineX) Trending first + over-by-over graph + session updates.**
    Home opens on trending/live matches; every live Match Detail carries a
    small over-by-over run/wicket mini-graph + session-update line.
12. **(LineX) Fantasy-style player impact on the scorecard** (KingCric's own
    calculation, never official fantasy points) + Playing XI + pitch +
    weather + H2H on the same Match Detail screen.
13. **(LineX) Dynamic, one-shot animations** (LivePulse, AnimatedScore) —
    never infinite, never blocking; smooth performance on patchy networks.
14. **(LineX) Regression-test 4/6 + pinned scores.** A wrong boundary or a
    wrong pinned score is a trust-killer — test both explicitly.

---

## 16. Sources (public, no scraping)

- Cricbuzz Play Store + AppBrain + cricbuzz.com (live scores page structure)
- ESPNcricinfo Play Store (`com.july.cricinfo`) + Statsguru / cricketr docs
- CREX Play Store (`in.cricketexchange.app.cricketexchange`) + AppBrain +
  CREX review / feature pages
- Cricmetric blog (scoreboard, win-probability model, chart embedding, venue analytics)
- SofaScore (cricket match page: play-by-play, wagon wheel, FOW, partnership)
- Public reviews quoted in §2–§4 (Cricbuzz ads, CREX speed/simplicity)

> **Legal note:** This file describes *patterns* observed from public listings
> and sites. It contains no copied code, no copied data, no scraped API
> responses, and no branding assets from any reference app. KingCric's
> implementation, data, and King navy+gold identity are its own.
