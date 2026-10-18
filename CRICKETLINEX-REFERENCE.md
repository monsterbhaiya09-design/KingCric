# CricketLineX / Just Cricket — Reference Analysis for KingCric

> **Purpose:** Study what makes the user's favourite reference app work, so KingCric
> can match its familiar patterns — with KingCric's own design, own code, and
> legal data sources. **No code, text, images, or data was copied from
> CricketLineX / Just Cricket.** All facts below come from public listings,
> public reviews, and public app-metadata pages (Play Store, AppBrain, Uptodown,
> ViaAPK, Appcracy). No private API was scraped, no APK was decompiled.
>
> **Honest limit:** The Play Store text fetch returns the listing text but not
> screenshot contents (only image URLs, no OCR). The screen-by-screen breakdown
> in §3 is therefore **inferred from the listing + reviews + FAQ**, not from
> in-app inspection. Where a detail could not be verified from public text, it
> is marked `[inferred]` and must be treated as a hypothesis, not a fact.

## 0. Identity — read this first

| Item | Value | Source |
|---|---|---|
| Current Play Store name | **Just Cricket: Fast Live Score** | Play Store listing (fetched 2026-10-18) |
| Previous name | **Cricket LineX: Fast Live score** | Same listing: "previously Cricket LineX" |
| Package | `com.cricketLineX.CricketLineX` | User-supplied link + Uptodown |
| Developer | **Entity Sport** | AppBrain + Play Store |
| Category | Sports | Play Store |
| Price | Free, contains ads | Play Store + AppBrain |
| Rating (Play Store text) | 4.5★ claimed in description; **4.0–4.4★** on metadata pages | Play Store fetch: "4 (121119 ratings)"; AppBrain: 4.01★ / 120,416 ratings; older crawls: 4.4★ / ~81–86K reviews |
| Downloads | **15 million** (Play Store: "15 million downloads · 30+ countries"); AppBrain: 15M installs, ~220K in last 30 days (~7.4K/day) | Play Store + AppBrain |
| Rank | **#8 Top Free, Sports, India** (AppBrain); also Top Free in Denmark (#46), Slovakia (#51), Saudi Arabia (#138) | AppBrain |
| Rating split (AppBrain) | 5★ ~74K, 4★ ~18K, 3★ ~2.2K, 2★ ~4.5K, **1★ ~20K** — the 1-star tail is large (~17%) | AppBrain histogram |
| Latest version | **5.2.19** (23 Sep 2026, per AppBrain); older mirrors list 5.1.25 / 5.1.1 / 5.0.12 / 5.0.2 — version numbers differ across mirrors, use Play Store as truth | AppBrain |
| Size | **25.28 MB** (AppBrain, Play Store build); Uptodown XAPK 5.1.25 = **43.57 MB** (arm64-v8a + armeabi-v7a bundle) | AppBrain / Uptodown |
| Min Android | **7.0** (API 24) — same floor KingCric already uses (minSdk 24) | ViaAPK / Appcracy |
| Permissions | **19** (AppBrain) / **26** (Uptodown variant) — KingCric has 2 (INTERNET + ACCESS_NETWORK_STATE), far leaner | AppBrain / Uptodown |
| Languages | English + 5 more (Uptodown); multi-language support claimed in reviews | Uptodown / reviews |
| Since | September 2023 (14 Sep 2023 per ViaAPK) | ViaAPK / AppBrain |
| Support | `support.justcricket@gmail.com` (new) / `cricketlinex@gmail.com` (old) | Play Store |
| Disclaimer | "Strictly for informational and entertainment purposes only. We do not provide, facilitate, or promote any form of betting, gambling, or wagering." | Play Store |
| Data safety (self-declared) | Shares Location, Personal info + 5 others with third parties; data encrypted in transit; **data can't be deleted** | Play Store |

> **Key strategic note:** The developer is **Entity Sport** — the same name as the
> EntitySport API already wired into KingCric's multi-source stack as a
> tertiary provider. That does **not** mean KingCric may reuse CricketLineX's
> app content or feed. EntitySport's public API (with its own dev token) is the
> legitimate route; the app's UI/data is not. KingCric must stay on its own
> legal sources (CricAPI + SportScore + TheSportsDB + EliteSport + EntitySport
> API + Cricsheet open data).

## 1. Full feature inventory (from Play Store description, verbatim themes)

### 1.1 Speed is the headline — not depth
- "Fastest cricket live score updates in India — ball-by-ball cricket scores,
  updated instantly as the game happens."
- "One step ahead of every ball." / "Know the cricket score before the crowd
  reacts." / "Faster than TV broadcasts."
- **Lesson for KingCric:** the *first* promise is speed + glanceability, not
  analytics. KingCric's V3 bug (live match hidden under Upcoming) breaks
  exactly this promise. Speed must be *perceived* in <2 seconds: live match
  first, score big, status unmistakable.

### 1.2 Feature list (Play Store, grouped)
| Group | Features (as listed) |
|---|---|
| Live core | Real-time live score; ball-by-ball commentary ("smart, clear, instant"); live scorecard — full batting + bowling breakdown; live line & match graphs — over-by-over analysis |
| Pre-match | Playing XI, squads & pitch report; weather updates; head-to-head stats |
| Engagement | Smart notifications — wickets, sixes, match start, milestones; fantasy cricket points — live player performance tracking; news & video updates — headlines, interviews, short highlight clips |
| History / records | Historical records & stats — legendary innings, milestones, records broken, all-time player + team stats; ICC rankings |
| Display | Dark mode & light mode support |
| Coverage | IPL, T20 WC, ODI WC, Champions Trophy, WTC, Asia Cup, BBL, PSL, SA20, ILT20, BPL, CPL, The Hundred, Ranji Trophy, County Championship, all international tours + domestic matches |
| Older listing adds | "Comprehensive info on all major and minor series"; "Detailed player and team info with ICC Rankings and stats"; "Session updates"; "Match highlights & key moments"; "Over-by-over analysis"; "Pre-match & live match insights"; "Fantasy points (perfect for Dream11 users)" |

### 1.3 What reviews say it actually does well / badly
**Praised (multiple reviews, 100s of "helpful" votes):**
- Speed + accuracy: "delivering real-time updates with lightning speed and
  accuracy" (768 helpful); "Greatest App provides the fastest score and have
  lots of Data comparing to the others App."
- Clean interface + smooth performance: "clean interface, smooth performance,
  and detailed match insights make following cricket more exciting and
  effortless"; "sleek and intuitive, making navigation a breeze even for
  first-time users"; "user-friendly interface", "minimal ads" (one review set).
- Comprehensive coverage: "comprehensive coverage of international and
  domestic cricket matches" (551 helpful).
- Two-pass usage pattern (ViaAPK/Appcracy analysis): glance at score first,
  then commentary only if the match state raises a question. Commentary is
  for *rebuilding context after returning*, not for reading every ball.

**Complained about (must NOT repeat in KingCric):**
- **Ads on every resume:** "everytime i minimize and open it that shows ad
  which is so annoying" (150 helpful); "The one first thing one does not want
  to see when opening an app is UNWANTED ADD" (1★); "do not broadcast
  advertisements like web series… 20 to 31 people deleted the crex app
  because it was broadcasting ads for web series."
- **Status bug — same class as KingCric V3:** "it's not working properly
  match has been completed but show is not started" (38 helpful). A
  completed match shown as "not started" is the mirror image of KingCric V3's
  live match shown as "Upcoming". **Status mapping is the #1 trust killer.**
- **Slow ball-by-ball (contradicts the speed claim):** "Features to ok but
  working ball by ball very slow very slow ball to ball" (1★).
- **Winning % envy:** "Crex is best showing winning percentage" (1★ on
  CricketLineX) — users compare win-probability features across apps.
  KingCric already has a prediction card; it must be visible and honest.
- **Other cons (review roundups):** "Limited player statistics",
  "Occasional app crashes", "No offline mode", "Annoying push
  notifications", "Requires internet", "Occasional lag in updates",
  "Limited customization", "Ads can be intrusive".

## 2. Navigation model (from listings — the clearest, most repeated pattern)

CricketLineX's navigation is **narrow and match-centred**, not a 5-tab
everything-app. The older listing states it most plainly:

> "Cricket Line X Tabs: Easy navigation for **Home, Live Scores (Upcoming,
> Finished), and Series (Points table, Squads)**."

The newer listing refines it:

> "Home tab with trending matches; **Live / Upcoming / Finished** matches;
> **Series tab with points table & squads**; Quick navigation for IPL live
> matches."

| Level | Structure |
|---|---|
| Top level | **Home** (trending matches) · **Live Scores** (Live / Upcoming / Finished) · **Series** (points table, squads) |
| Match detail (from feature list) | Live score → Scorecard → Commentary → Playing XI / Squads → Pitch + Weather → H2H → Graphs / Line → Fantasy points → News |
| Player / team (from feature list) | Player info + ICC Rankings + stats; Team info + analysis & comparisons |
| Notifications | Per-match / per-team: wickets, sixes, match start, milestones — opt-in, selective (reviewers warn against enabling everything) |

**What this means for KingCric:** KingCric V3 has 5 bottom tabs
(Home / Leagues / Compare / Stats / Favourites). CricketLineX has ~3
top-level destinations. KingCric should **not** delete its differentiators
(Compare, deep Stats, Favourites), but it should make the **Home → Live
match → Scorecard** path as short and obvious as CricketLineX's, and keep
Leagues/Compare/Stats/Favourites one tap away without crowding the Home
screen. The Home screen's job is: *live match first, in 2 seconds*.

## 3. Screen-by-screen breakdown

> `[inferred]` = derived from listing/review wording, not from a verified
> screenshot. Treat as a design hypothesis to validate, not as a quote.

### 3.1 Home — "glance, then dive"
- **Top:** Trending / live matches first. `[inferred]` A compact card per
  match: series tag (e.g. "IPL") + status pill (LIVE / Upcoming / Result) +
  team short names + score + overs + one-line state ("need 88 in 78 balls"
  / "won by 10 wkts") + venue on a second line.
- **Filter:** **Live / Upcoming / Finished** — three states, mutually
  exclusive, no match in two buckets. This is the exact rule KingCric V3
  violated (live match under Upcoming, Live empty).
- **Tap:** Card → match detail. No dead ends: every card is tappable, every
  tap lands on the scorecard/commentary for that match.
- **What KingCric V3 got wrong (screenshots 2026-10-18):** header truncated
  to "King…", tab wrapped to "Upcomin g", team name rendered as
  "Bulgaria Women,Sweden Wo…", a live match filed as Upcoming, an "Ad
  placeholder" box shown. All fixed locally in commit `17ce998` (NOT yet
  pushed — combine with this reference before the next build).

### 3.2 Match Detail — "score first, story second"
Order (from feature list + two-pass usage pattern):
1. **Hero score** — both innings, big, with overs + CRR/required rate +
   equation ("need X in Y balls") for chases.
2. **Tabs / sections** `[inferred]`: Live (score + commentary) · Scorecard
   (batting R/B/4s/6s/SR + dismissal, bowling O/M/R/W/Econ, Extras, FOW,
   partnerships, yet-to-bat) · Squads / Playing XI · Info (pitch, weather,
   toss, umpires, venue) · H2H · Graphs (worm / Manhattan / over-by-over).
3. **Commentary:** ball-by-ball, newest first, over headers, key moments
   highlighted (W, 4, 6, milestone). Reviewers use it to *rebuild context*,
   not to read every ball — so each entry must be self-contained.
4. **Fantasy points** per player, live. (KingCric: not built; do not fake it.
   If added later, it needs a real provider, not a made-up formula.)
5. **H2H + ICC rankings** on the same screen — users expect context without
   leaving the match.

### 3.3 Player — "stats with context, not a wall of numbers"
- From listings: "Detailed player and team info with ICC Rankings and
  stats", "Player performance records", "Team analysis & comparisons",
  "Historical records & stats".
- Reviewer complaint: **"Limited player statistics"** — even CricketLineX is
  criticised here. This is KingCric's opening: Cricsheet-calculated career /
  vs-opponent / venue / bowler-vs-batter / dismissal history is *deeper*
  than CricketLineX's player section.
- `[inferred]` Layout: header (name, role, team, ranking) → format tabs
  (Test/ODI/T20) → batting + bowling tables → recent form → H2H/matchup.
  KingCric already has this shape; keep it, but label the source honestly
  ("Real • Cricsheet open data • N matches" vs "Demo").

### 3.4 Series / Leagues — "points table + squads in one place"
- Per listing: "Series tab with points table & squads", "Comprehensive info
  on all major and minor series".
- `[inferred]`: Series screen = standings table (P/W/L/NR/PTS/NRR) + fixtures
  (Upcoming/Finished) + squads per team. KingCric's Leagues screen should
  match this: a series without a points table feels empty.

### 3.5 Compare / Stats / Favourites — where KingCric goes beyond
- CricketLineX has "Team analysis & comparisons" and ICC rankings, but no
  advertised side-by-side player-compare screen and no advertised
  venue-records-per-player. KingCric's Compare + Venue + Dismissal-history
  depth are differentiators — keep them, but put them **one tap from the
  player/match**, not buried.
- Favourites + selective notifications (wickets / sixes / milestones /
  match start) are expected; the warning from reviews is to keep them
  **opt-in and selective**, never noisy by default.

## 4. What CricketLineX does BETTER than KingCric V3 (copy the pattern)

| # | Pattern (CricketLineX) | KingCric V3 gap | Fix |
|---|---|---|---|
| 1 | **Live / Upcoming / Finished are mutually exclusive and correct** — a match appears in exactly one bucket, and the bucket matches its real state | Live match under Upcoming; Live tab empty; completed shown as not-started (their bug too — do not copy the bug, copy the *rule*) | Already fixed locally (`resolveStatus` + `isEffectivelyLive`, commit `17ce998`); add regression tests for completed→Finished, not-started→Upcoming |
| 2 | **Match card = one glance** — status pill + teams + score + overs + equation + venue, all readable in 2 seconds | V3 card showed score but status pill contradicted it (UPCOMING on a live game) | Status pill must derive from the *same* effective status as the filter, never from a separate field |
| 3 | **Score first, story second** — hero score at top, commentary below, no need to hunt | V3 Home showed "Tap for FULL scorecard" but the scorecard tab was not the obvious landing | Tapping a card lands on Scorecard/Live with the hero score visible without scrolling |
| 4 | **Team names are clean** — one team per line, title case, short name when long | V3 rendered "Bulgaria Women,Sweden Wo…" + "bulgaria women" lowercase | Already fixed locally (`cleanTeamName` + `titleCaseTeam`); keep short-name fallback (e.g. "Sweden Women" → "SWE-W" only if space demands it, never mid-word cut) |
| 5 | **No truncation anywhere** — header, tabs, and match titles show fully | V3: "King…", "Upcomin g", "Sweden Wom…" | Already fixed locally (FittedBox header, custom tabs, 2-line titles); re-verify on a small-width device (360dp) |
| 6 | **No fake UI chrome** — no placeholder boxes, no "unit id not set" text | V3 showed "Ad placeholder — AdMob unit id not set yet" | Already fixed locally (AdPlaceholder → `SizedBox.shrink()` when no ID); never show a placeholder in release |
| 7 | **Honest completeness** — a match is Live / Upcoming / Finished, never two things at once; a stat is shown or not shown | V3 showed curated 27150 runs as "Complete" | Already fixed locally (mock → `dataComplete:false`, source labels); never present curated/demo as complete |
| 8 | **Selective notifications** — wickets/sixes/start/milestones, opt-in per match/team | V3 favourites exist but notification granularity is not surfaced | Surface per-match "Notify me: Wickets / Sixes / Start / Milestones" toggles (FCM later; in-app flag first) |
| 9 | **Dark + light mode** — users expect both | KingCric is dark-only (navy+gold) | Keep King dark theme as default; add a light theme later — do not block the next build on it |
| 10 | **Series depth** — points table + squads on the Series screen | KingCric Leagues exists but points-table depth is thin | Series screen: standings (P/W/L/PTS/NRR) + fixtures + squads, even if some series show "Table not available" honestly |

## 5. What KingCric should do DIFFERENT / BETTER (do not clone)

| # | KingCric advantage | Why it matters |
|---|---|---|
| 1 | **Deeper player analytics** — career + vs-opponent + venue + league splits + bowler-vs-batter + dismissal history ("c X b Y — N times" + "Not dismissed by Z"), calculated from Cricsheet open ball-by-ball data | Directly answers CricketLineX's own "Limited player statistics" complaint. This is KingCric's moat — no other free app in this set shows dismissal history this way. |
| 2 | **Honest source labels** — "Real • Cricsheet open data • N matches" vs "Demo" vs "Partial", never fake "Complete" | CricketLineX's 1★ tail is full of trust complaints (ads, wrong status). Honest labels are a trust feature, not a footnote. |
| 3 | **King identity** — navy `#0B1026` + gold `#D4AF37`, crown + bat-ball logo, "Har Ball, Har Stat, King Jaisa." | CricketLineX is generic blue/white. KingCric should feel royal and memorable, while keeping the *layout* familiar (pattern §4). Identity = colours + logo + tone; layout = reference. |
| 4 | **Player Compare side-by-side** — two players, same table, same formats | CricketLineX lists "team analysis & comparisons" but no advertised side-by-side player compare. Keep it prominent. |
| 5 | **Prediction with explanation** — weighted model + Hindi/English reason, not just a bare "win %" | CricketLineX reviewers ask for winning % (Crex comparison). KingCric already has it — show it on the match card *and* the detail screen, with the reason line, and never present it as a guarantee. |
| 6 | **Fewer permissions, no data-deletion red flag** — KingCric: INTERNET + NETWORK_STATE only; CricketLineX: 19–26 permissions, "data can't be deleted" | A Play Store advantage. Say so on the listing when KingCric ships. |
| 7 | **No ad-on-every-resume** — KingCric hides the ad slot entirely until a real AdMob ID exists; when ads ship, they must be a small banner, never a full-screen ad on every resume | The single most upvoted CricketLineX complaint. Do not repeat it. |

## 6. Concrete KingCric spec changes from this reference

Apply on top of bug-fix commit `17ce998` (do not re-introduce the bugs it
fixed). Checklist for the next build:

- [ ] **Home (2-second rule):** Live matches first (if any), then Upcoming,
      then Recent. Each card: status pill (from effective status) + series tag
      + Team A line (name + score + overs) + Team B line + equation/result
      line + venue line. No card without a score line for a live/finished
      match. No match in two filters.
- [ ] **Match detail landing:** Tap card → Scorecard/Live tab with hero score
      visible without scrolling. Tabs: Live · Scorecard · Commentary ·
      Squads · Info (pitch/weather/toss/umpires) · H2H. Keep KingCric's
      Prediction + Venue sections; put them after Scorecard, not before it.
- [ ] **Scorecard columns (minimum):** Batting: Batter + dismissal | R | B |
      4s | 6s | SR. Bowling: Bowler | O | M | R | W | Econ. Plus Extras,
      FOW, Partnerships, Yet-to-bat. Horizontal scroll for wide tables +
      "swipe" hint. Never squeeze columns until numbers clip.
- [ ] **Team names:** `cleanTeamName` everywhere (already in `17ce998`);
      short-name fallback only when space demands it; never render a
      comma-joined pair; title case everywhere.
- [ ] **No truncation:** Header shows full "KingCric" (FittedBox, already
      fixed); tabs never wrap; match titles up to 2 lines; player names up
      to 2 lines. Verify at 360dp width.
- [ ] **No fake chrome:** No ad placeholder, no "Complete" on demo/curated
      data, no "Live" pill on a non-live match. Every label derives from
      the same source of truth as the filter.
- [ ] **Player profile:** Header (name/role/team/ranking) → format tabs →
      batting + bowling tables → vs-opponent → venue → recent form →
      matchup/dismissal → source label. Cricsheet profiles show the real
      label; demo profiles show "Demo".
- [ ] **Series screen:** Standings (P/W/L/PTS/NRR) + fixtures + squads.
      Honest "Table not available" when the provider has no table.
- [ ] **Notifications:** Per-match toggles (Wickets / Sixes / Start /
      Milestones), opt-in, selective. FCM later; store the preference now.
- [ ] **Dark + light:** Keep King dark as default; add light theme as a
      follow-up, not a blocker.
- [ ] **Fantasy points:** Do NOT fake. Leave out until a real provider
      supplies it. A missing section beats a made-up number.
- [ ] **Speed claim:** Do not claim "faster than TV" or "instant". KingCric
      on the free tier is 10-min cached (CricAPI 100/day). Claim "fast,
      honest live scores" — and show a "Last updated HH:MM" line so the
      user can see freshness instead of guessing.

## 7. Sources (all public, fetched 2026-10-18)

- Play Store: https://play.google.com/store/apps/details?id=com.cricketLineX.CricketLineX
- AppBrain: https://www.appbrain.com/app/just-cricket-fast-live-score/com.cricketLineX.CricketLineX
- Uptodown: https://cricketlinex.en.uptodown.com/android/download
- ViaAPK: https://www.viaapk.com/app/com.cricketLineX.CricketLineX
- Appcracy: https://www.appcracy.com/app/cricket-linex-fast-live-score.html
- APKCombo listing (search snippet only; direct page fetch failed — not
  used as a source beyond the snippet): https://apkcombo.com/cricket-linex-fast-live-score/com.cricketLineX.CricketLineX/
- KingCric V3 screenshots + bug-fix commit `17ce998` (local, parent's
  context): Live-filter, team-name, truncation, ad-placeholder, and
  source-label fixes already implemented locally, not yet pushed.
