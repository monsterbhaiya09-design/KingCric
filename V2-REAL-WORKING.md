# KingCric V2 — REAL WORKING: Premium UI + Full Scoreboard + Real Visible Data

Date: 2026-10-18. User feedback that drove V2:
- "bahut normal, simple and boring lagra hai"
- "scoreboard bhi full nahi dikh rha hai abhi and sahi se data bhi dekhne me nahi arha hai"
- "isko apan real working me dekhte hai kaisa dikhega"
- "api ka kya hai sab ready kar"

## 1. PREMIUM UI — no longer boring

**Theme (`lib/utils/app_theme.dart`):**
- Kept King colours navy `#0B1026` + gold `#D4AF37`, now with real depth:
  `navyDeep`, `navyCard3`, `goldSoft`, `greenDark`, `liveRed`, `blue`.
- New gradients: `goldGradient`, `navyGradient`, `cardGradient`,
  `liveGradient`, `heroCard()` (gold border 1.4 + double shadow),
  `premiumCard()` (gold border 1.2 + 2-layer shadow).
- Headings now w900, tighter letter-spacing.

**New shared widgets (`lib/widgets/premium_widgets.dart`, NEW):**
- `KingGradientCard` (hero + normal), `LivePill` + `LivePulseDot`
  (one-shot scale-in + static glow — deliberately NOT
  `AnimationController.repeat`, which never settles and timed out
  `pumpAndSettle` in widget tests; fixed during V2),
- `StatBar` (label + value + animated fill, clamped 0..1),
  `PremiumSectionHeader` (gold rule), `KingAvatar` (gold-ring
  gradient initials), `GoldChip`, `ScoreHeaderCell` / `ScoreRow`
  (fixed-width table rows), `AnimatedScore` (count-up),
  `GoldDonut` (custom-painted arc, no new dependency).

**Screens redesigned (same navigation, richer visuals):**
- `home_screen.dart`: gradient hero header (👑 crown in gold tile),
  gold-bordered search, premium match cards (hero card for LIVE),
  bold 20px scores, "Tap for FULL scorecard" CTA, premium trending.
- `player_profile_screen.dart`: gradient hero with avatar + 4 quick
  stats (Runs/Avg/SR/Wkts), stat bars, full format table
  (horizontal scroll: M/Runs/Avg/SR/100s/50s), league/venue/recent/
  matchup/dismissal/bowling as full-width premium rows — no truncation.
- `player_card.dart`: gradient avatar, gold-ring, runs in gold 18px,
  progress bar, ellipsised everywhere.
- `stat_card.dart`: premium gradient + gold value + optional bar.
- `h2h_card.dart`: gold chip, big win numbers, animated bar, clamped.
- `prediction_card.dart`: gold donut (replaces raw CircularProgress),
  verdict pill with border, 3 stat bars (Form / vs Opp / Venue),
  all fractions NaN-guarded + clamped.

## 2. FULL SCOREBOARD — `match_detail_screen.dart` rewritten

Tabs: Live | **Scorecard (FULL)** | Squad | Prediction.

**Live tab:** hero live score (big gold scores), Target & Equation
("need X runs from Y balls"), H2H, Match Info (Venue / Toss /
Umpires / Referee / Pitch), full commentary — all wrapped, no overflow.

**Scorecard tab — complete, for EVERY innings:**
- Header: title + league/format/venue + toss + umpires (always visible).
- **Batting table** (horizontal scroll, 720px, fixed columns):
  Batter + dismissal (2 lines) | R | B | 4s | 6s | SR. Not-out rows
  highlighted gold. TOTAL row with gold background.
- **Extras row:** `Extras: Wd 3, Nb 1, B 1 (5)` + Total chip.
- **Bowling table** (horizontal scroll): Bowler | O | M | R | W | Econ
  | Wd | Nb. "Swipe sideways" hint under each table.
- **Fall of Wickets:** numbered red circles, e.g. `1-52 (Rohit, 6.1 ov)`.
- **Partnerships:** handshake icon + `Kohli + Surya — 68 (42 balls)`.
- **Yet to Bat:** gold chips for every not-yet-batted player.
- Disposes `TabController` (fixes ticker leak from CODE-REVIEW-2).

**Mock data (`mock_data_service.dart`): FULL realistic cards**
- **India 192/6 (20.0):** batting 187 + extras 5.
  Rohit 48(30), Gill 31(24), Kohli 68*(45), Surya 22(15),
  Hardik 10(9), Pant 5(4) run out, Dube 0(1), Axar 3*(3).
  Yet to bat: Jadeja, Bumrah, Kuldeep, Arshdeep.
  Bowling: Shaheen 4-0-38-1, Naseem 4-0-35-1, Haris 4-0-42-1,
  Shadab 4-0-36-1, Imad 2-0-22-1, Iftikhar 2-0-19-0.
  Runs 38+35+42+36+22+19 = 192, overs 20.0, wickets 6 (5 bowler + 1 run out).
  FoW 6 entries, partnerships 7 entries.
- **Pakistan 96/3 (10.0) chasing:** batting 94 + extras 2.
  Babar 38(28), Rizwan 32(22), Fakhar 12(8), Iftikhar 8*(4),
  Shadab 4*(2). Bowling: Bumrah 2-0-18-1, Arshdeep 3-0-28-1,
  Hardik 2-0-22-0, Kuldeep 2-0-18-1, Axar 1-0-10-0. FoW 3, partnerships 4.
- Match context: umpires `Dharmasena • Gaffaney`, referee `Srinath`,
  pitch report (batting-friendly, dew, avg 168, bat-first 54%).
- Reconciliation: India diff 5, Pakistan diff 2 — both ≤ validator
  tolerance 15, so `inningsReconciles` still passes.

**Models extended (backwards-compatible, defaults = old behaviour):**
- `innings.dart`: `BowlingEntry` += `wides`, `noBalls`;
  `Innings` += `extrasRuns`, `extrasText`, `yetToBat`,
  `partnerships`, `didNotBatNote` + JSON round-trip.
- `match.dart`: `CricketMatch` += `umpires`, `matchReferee`,
  `pitchReport` + JSON round-trip.
- `player.dart`: `Player.bowlingOverall()` (sum wickets/matches).

## 3. REAL DATA VISIBILITY — no truncation, no overflow

- Every `Text` that can be long now has `maxLines` + `overflow:
  TextOverflow.ellipsis` (or `.clip` for numbers).
- Scoreboard tables use fixed column widths + horizontal
  `SingleChildScrollView` + "swipe" hint — columns never squeeze.
- All fractions clamped: H2H `frac`, StatBar, Donut, Prediction
  (`score.isNaN ? 0 : clamp`), `LinearProgressIndicator` values.
- Hindi + English toggle still works everywhere (all strings via
  `LanguageProvider.t`); no new hard-coded English-only strings in V2
  except proper nouns (player/team names).
- `AnimatedScore` / `StatBar` / `GoldDonut` use one-shot
  `TweenAnimationBuilder` — no infinite controllers, no jank, tests settle.

## 4. API — READY FOR REAL WORKING (no key needed to run)

`ApiService` was already wired for real data and is unchanged in V2:
- Free provider: CricAPI / CricketData.org (lifetime free tier,
  100 hits/day, no card). Key via `--dart-define=CRIC_API_KEY=...`,
  never hard-coded. See `API-SETUP.md` (parallel worker).
- `fetchMatches` (10-min cache), `fetchScorecard` (full innings:
  batting/bowling/extras/FoW → same `Innings` model V2 renders),
  `fetchSeries`, `fetchPlayer` (cached), `testApiKeyValidity`,
  `clearCache`. Quota-safe: live 10 min, completed 60 min, never 45s
  polling (45s would burn 1920 calls/day).
- No key → demo mode with the FULL V2 scorecard above, so the app
  works fully offline and the user sees REAL WORKING UI now.
- To go live: `flutter build apk --release
  --dart-define=CRIC_API_KEY=YOUR_FREE_KEY` (GitHub Actions workflow
  accepts the same define via workflow_dispatch input in a later step).

## Verification (this VM, Flutter 3.47.7)

- `flutter analyze` → **No issues found!**
- `flutter test` → **3/3 passed** (was 2/3 during V2: `pumpAndSettle`
  timed out on infinite `LivePulseDot.repeat` — fixed by making the
  dot one-shot; see premium_widgets.dart comment).
- `flutter build web --release` → **✓ Built build/web** (41 MB).
- Scorecard totals verified: India 187 + 5 = 192, bowling 192;
  Pakistan 94 + 2 = 96, bowling 96.

## What the user will see now

1. **Home:** King hero (gold crown tile + "KingCric / Har Ball…"),
   LIVE pill with glow, big gold scores (192/6, 96/3), venue, tap → detail.
2. **Match → Scorecard:** FULL India 192/6 table (8 batters, R/B/4s/6s/SR
   + full dismissals), Extras Wd 3 Nb 1 B 1, FULL bowling (O/M/R/W/Econ/Wd/Nb),
   FoW 6, partnerships 7, Yet to Bat 4 chips — then FULL Pakistan 96/3
   the same way. Swipe sideways for hidden columns.
3. **Match → Live:** hero score + "need 97 from 60 balls" + toss/umpires/
   pitch + commentary.
4. **Player → Virat:** hero (avatar + 24px name + Runs/Avg/SR/Wkts),
   Overall + stat bars, vs Pakistan, T20, full format table, leagues,
   venue, recent form, matchup, dismissal, bowling — all visible, no cut-off.
5. **Language:** EN / हिं toggle still works; demo banner still shows
   until a free API key is added.

## Files changed (V2)

- `lib/utils/app_theme.dart` — premium gradients / shadows / colours.
- `lib/widgets/premium_widgets.dart` — NEW (10 premium widgets).
- `lib/widgets/player_card.dart`, `stat_card.dart`, `h2h_card.dart`,
  `prediction_card.dart` — premium + clamping + overflow fixes.
- `lib/screens/home_screen.dart`, `match_detail_screen.dart`,
  `player_profile_screen.dart` — premium + full scoreboard + visibility.
- `lib/models/innings.dart`, `lib/models/match.dart`,
  `lib/models/player.dart` — full-scoreboard fields + bowlingOverall.
- `lib/services/mock_data_service.dart` — FULL India + Pakistan scorecards.
- `V2-REAL-WORKING.md` — this file.

NOT changed: navigation, bottom tabs, ApiService, prediction engine,
completeness validator, test expectations (tests still pass as-is).
NOT pushed: local commit only — main agent pushes to GitHub when ready.
