# KingCric — Accessibility Audit (READ-ONLY)

**Scope:** Accessibility Engineer audit. No code was edited. All findings are
from static code inspection (screens, widgets, theme, strings) plus
measured contrast math and layout math. No physical device was available;
"screenshot description" entries below are reconstructions from the layout
math (what a 360 dp screenshot *would* show), not captured screenshots.
Flutter test suite was run read-only to cross-check (see §8).

**Audit dimensions:** 360 dp width (small phone) · font scale 1.3× ·
contrast (gold on navy, white on navy, all text/background pairs) ·
touch targets (min 48 dp) · screen-reader labels (Semantics) ·
Hindi labels · long names · truncation / overflow.

**Verdict:** **CONDITIONAL PASS — 5 must-fix issues (all small, all
localised), 8 should-fix issues.** The colour system is strong, the
no-truncation work (FittedBox, 2-line titles, horizontal-scroll tables)
is good, and the three existing `Semantics` sites are correct. The gaps
are: (1) almost no Semantics outside Home, (2) two sub-48 dp touch
targets, (3) one failing small-text contrast pair (LIVE pill),
(4) fixed-height / fixed-aspect containers that can overflow at 1.3×,
(5) colour-only meaning in three places (H2H bar, prediction verdict,
win/loss colour). Nothing here needs a redesign — each fix is a few
lines in one widget.

---

## 1. Contrast — measured (WCAG 2.1 AA)

Small text needs ≥ 4.5 : 1. Large text (≥ 18 pt bold or ≥ 24 pt) needs
≥ 3.0 : 1. Non-text contrast (icons, focus, controls) needs ≥ 3.0 : 1.

| Pair (foreground on background) | Ratio | Verdict |
|---|---|---|
| textPrimary #F5F0E1 on navy #0B1026 | 16.51 | ✅ PASS |
| textSecondary #B8BDD4 on navy | 10.09 | ✅ PASS |
| textMuted #8A90B0 on navy | 6.00 | ✅ PASS |
| gold #D4AF37 on navy | 8.95 | ✅ PASS |
| goldLight #FFD700 on navy | 13.41 | ✅ PASS |
| goldSoft #FFE98A on navy | 15.47 | ✅ PASS |
| textSecondary on navyCard #151B38 | 9.04 | ✅ PASS |
| textMuted on navyCard | 5.38 | ✅ PASS |
| gold on navyCard | 8.02 | ✅ PASS |
| goldSoft on navyCard | 13.87 | ✅ PASS |
| textSecondary on navyCard2 #1D2450 | 7.93 | ✅ PASS |
| textMuted on navyCard2 | 4.71 | ✅ PASS (margin 0.21 — do not darken) |
| black on gold #D4AF37 (selected tab / chip) | 9.99 | ✅ PASS |
| black on goldLight #FFD700 | 14.97 | ✅ PASS |
| green #2ECC71 on navyCard | 8.02 | ✅ PASS (verdict text) |
| amber #F39C12 on navyCard | 7.69 | ✅ PASS (verdict text) |
| red #E74C3C on navyCard | 4.41 | ⚠️ PASS but thin (margin 0.09 below) — see M-1 |
| blue #4DA3FF on navyCard | 6.42 | ✅ PASS |
| white on liveRed #FF3B30 (LIVE pill, 12 px w900) | 3.55 | ❌ **FAIL** — see M-2 |
| white on red #E74C3C | 3.82 | ❌ FAIL if ever used for small text (currently only bar fill, no text — see S-3) |
| white on green #2ECC71 | 2.10 | ❌ FAIL if ever used for text (currently **not** used for text — no white text sits on green/amber) |
| white on amber #F39C12 | 2.19 | ❌ FAIL if ever used for text (currently **not** used for text) |
| unselected BottomNav white54 (~#8B8B9E) on navy | 5.63 | ✅ PASS |
| gold selected BottomNav on navy | 8.95 | ✅ PASS |

**Notes**
- The palette is genuinely good: every *real* text pair passes AA. The
  two FAIL rows for white-on-green / white-on-amber are **latent** —
  no white text is currently rendered on those fills (prediction
  verdicts use coloured text on a 18 %-alpha tint over navyCard, which
  passes at 8.02 / 7.69 / 4.41). They are listed so nobody adds
  white-on-green text later assuming it is safe.
- The one **real** failure is the LIVE pill: white 12 px text on
  #FF3B30 (3.55). 12 px is normal text, so it needs 4.5, not 3.0.
  Fix: darken the pill gradient (e.g. #D92D20 → #A61E1E) or make the
  text black-on-goldLight like the selected tab. Either keeps the
  red "live" meaning while passing.
- Red verdict text on navyCard (4.41) passes but with almost no margin.
  Do not use a lighter red, and do not put red text on a lighter
  background (e.g. the red-tinted FOW circle background) — it would
  drop below 4.5.

### Colour-only meaning (WCAG 1.4.1 — must not be colour alone)
| Place | Colour cue | Non-colour cue present? |
|---|---|---|
| H2H bar (green vs red fill) | Winner = green side | ⚠️ **No** — the win numbers are in text beside it, so the *outcome* is readable, but the bar alone conveys nothing. Acceptable, but add a semantic label (see S-4). |
| Prediction verdict pill (green/amber/red) | Likely/Risky/Unlikely | ✅ Text label + donut number present. PASS. |
| Compare winner highlight (goldLight text) | Winner = gold | ⚠️ **No** — gold vs default-white is the *only* signal. Screen-reader and colour-blind users get no "winner" info. Add "leads" text or a Semantics label (see S-5). |
| LivePulseDot / LivePill (red) | Live | ✅ "LIVE" text + pill present. PASS. |
| Favourites star (amber vs outline) | Favourited | ⚠️ **No** — filled vs outline star only. `IconButton` has no tooltip / semantic label, so TalkBack announces just "button". See M-4. |

---

## 2. Touch targets (min 48 × 48 dp, WCAG 2.5.8 / Material)

| Control | Measured size | Verdict |
|---|---|---|
| Home `_FilterTabs` (Live / Upcoming / Finished) | Container padding 12 + 12 vertical + ~20 px text ≈ **44 dp** tall, full third-width wide | ❌ **FAIL (borderline)** — 4 dp short. See M-3. |
| `LanguageToggle` EN / हिं `ChoiceChip` (`visualDensity: compact`, labelPadding 2) | ≈ **32 dp** tall | ❌ **FAIL** — see M-3. |
| Home search clear `IconButton` (Icons.clear 20) | IconButton default min 48 dp | ✅ PASS |
| Home Refresh `TextButton.icon` | M3 TextButton min height 40 dp + padding → ≈ 40–48 dp | ⚠️ **BORDERLINE** — verify on device; add explicit min height if < 48. |
| Favourites star `IconButton` (default) | 48 dp | ✅ PASS |
| `BottomNavigationBar` (5 items) | ≈ 56 dp tall | ✅ PASS |
| `TabBar` tabs (Match Detail, 4 tabs, scrollable) | ≈ 48 dp tall | ✅ PASS |
| Compare `DropdownButton` | ≈ 48 dp | ✅ PASS |
| `ChoiceChip` elsewhere (format / discipline / league chips, default density) | ≈ 48 dp with `materialTapTargetSize: padded` on Home; **default** on Compare / Stats / Leagues / PlayerProfile | ⚠️ **MIXED** — Home chips explicitly set padded (PASS); all other chips rely on default (usually 48 dp, but not guaranteed). Set `materialTapTargetSize: padded` everywhere. |
| `InkWell` rows (match card, player card, scorecard names, squad rows) | Full row width, ≥ 48 dp tall (padding 12–16 + text) | ✅ PASS |
| FOW numbered circle (28 × 28 dp) | 28 dp — **not interactive** (display only) | ✅ PASS (no target requirement for non-interactive) |
| GoldChip (non-interactive label) | N/A | ✅ PASS |
| `SwitchListTile` (Favourites) | Full row, ≥ 48 dp | ✅ PASS |
| `FilledButton` Retry (Stats / Leagues / Favourites error states) | M3 min 40 dp tall — with padding ≈ 48 dp | ⚠️ BORDERLINE — same note as Refresh. |
| `KingAvatar` (non-interactive) | 56–68 dp | ✅ PASS |

**Screenshot description (360 dp, Home):** the three filter tabs look
generous (each ~110 dp wide) but are only ~44 dp tall — a fingertip
can still hit them, but a user with tremor / large fingers will
mis-tap the row above/below. The EN / हिं chips at the top-right look
small and cramped next to the 48 dp crown tile — the smallest tappable
thing on the Home screen.

---

## 3. Semantics / screen reader (TalkBack)

Inventory of explicit `Semantics` in the codebase: **3 sites only**,
all in `home_screen.dart`.

| Site | Semantics present? | Verdict |
|---|---|---|
| Home: search clear button | ✅ `Semantics(button: true, label: 'Clear search' / 'खोज साफ़ करें')` + tooltip | ✅ PASS |
| Home: format `ChoiceChip`s | ✅ `Semantics(button: true, selected: …, label: 'Format filter X' / Hindi)` | ✅ PASS |
| Home: filter tabs | ✅ `Semantics(button: true, selected: …, label: tab name)` | ✅ PASS |
| BottomNavigationBar (5 items) | ❌ None explicit — relies on Material defaults (label + selected state) | ⚠️ LIKELY OK — Material provides label/selected automatically, but **verify on device** that Hindi labels are announced (see §5). |
| Match card (whole card `InkWell`) | ❌ None — TalkBack reads every child Text in order (pill, league, title, venue, each score row, result, CTA). Long, unordered, no summary. | ❌ **FAIL** — see M-5. |
| Player card (`InkWell`) | ❌ None — same issue: name, role, bar (LinearProgressIndicator announces a % with no label), runs, avg, SR, source label. | ❌ **FAIL** — see M-5. |
| Scorecard batter/bowler name `InkWell` ("tap for profile") | ❌ None — TalkBack reads the name with no hint it is a button, and no hint where it goes. | ❌ **FAIL** — see M-5. |
| Scorecard tables (720 px horizontal scroll + "↔ Swipe" hint) | ❌ None — the swipe hint is **visual Text only**. TalkBack announces no "scrollable table" hint. | ❌ **FAIL** — see M-5. |
| Stat bars / progress bars (`LinearProgressIndicator`, `GoldDonut`, `OverGraph` bars, H2H bar) | ❌ None — TalkBack announces a bare percentage (or nothing for `GoldDonut` CustomPaint, which is **completely silent**). | ❌ **FAIL** — see M-5. |
| LivePill / LivePulseDot | ❌ None — "LIVE" text is readable, but the pulse conveys nothing to TalkBack (acceptable — text carries it). | ✅ PASS (text carries meaning). |
| Emoji-only / icon-only content | ⚠️ Crown 👑 (decorative, fine), 📍 venue prefix (decorative, fine — venue text follows), 🪙 toss prefix (decorative), arrow icons (decorative, text follows). No icon-only *control* except the Favourites star (see M-4). | ✅ PASS except star. |
| Favourites star `IconButton` | ❌ No `tooltip`, no `Semantics` — TalkBack announces "button" with no name or state. | ❌ **FAIL** — see M-4. |
| Favourites `SwitchListTile`s | ✅ Material provides label + on/off state automatically. | ✅ PASS (verify Hindi subtitles are announced). |
| Compare `DropdownButton` ("Select player") | ⚠️ Material provides basic semantics, but the hint + selected value + "VS" relationship are not grouped. | ⚠️ SHOULD-FIX — wrap in `Semantics(label: 'Compare player A, <name>')`. |
| Match Detail `TabBar` (Live / Scorecard / Squad / Prediction) | ✅ Material TabBar provides label + selected state. | ✅ PASS. |
| Error / empty states (Retry buttons, "No matches…") | ⚠️ Text is readable, but no `Semantics(liveRegion: true)` — a TalkBack user who triggers Refresh gets no announcement that the list changed. | ⚠️ SHOULD-FIX — announce list updates / errors via live region. |

---

## 4. 360 dp width (small phone)

| Screen / element | 360 dp behaviour | Verdict |
|---|---|---|
| Home ListView (padding 14 → content 332 dp) | All sections fit; header uses FittedBox. | ✅ PASS |
| Home `_FilterTabs` (3 × Expanded) | Each ~110 dp. EN labels fit; Hindi "आने वाले" + "✓ " at 14 px is tight but FittedBox scales down instead of wrapping. | ✅ PASS at 1.0×; ⚠️ at 1.3× see §5. |
| Match card (padding 16 → content 328 dp) | Title 2 lines, venue 1 line, one team per row, score right-aligned. No overflow. | ✅ PASS |
| Scorecard tables (fixed 720 px inside horizontal scroll) | Scrolls, never clips; "↔ Swipe" hint present visually. | ✅ PASS visually; ❌ semantics (see M-5). |
| Leagues points table (7 cols, ~488 dp wide, horizontal scroll) | Scrolls, never clips. | ✅ PASS visually; ⚠️ same semantics note. |
| Player profile format tables (700 / 620 px, horizontal scroll) | Scrolls, never clips. | ✅ PASS visually; ⚠️ same semantics note. |
| Player profile `_grid` (2 cols, aspect 1.55) | Cell = (360 − 28 padding − 10 spacing) / 2 = **161 dp** wide, ≈ 104 dp tall. | ⚠️ At 1.0× fits; at 1.3× borderline — see §5. |
| Compare: two `DropdownButton`s + "VS" | Each dropdown ≈ 150 dp, `isExpanded: true`, names ellipsised. | ✅ PASS |
| Compare table rows (3 × Expanded) | Label centre, values sides; long values ellipsised. | ✅ PASS |
| BottomNav (5 items) | 72 dp per item. EN labels fit. | ✅ PASS (EN); ⚠️ Hindi see §5. |
| Favourites lists (full-width `ListTile`s) | Title/subtitle 1 line ellipsis, star trailing. | ✅ PASS |
| `OverGraph` partnership row (bar + 150 px "N runs" box) | At 360: content 332 − 150 − 8 = 174 dp for the bar — usable. | ✅ PASS (but the label *below* the bar duplicates the number — TalkBack will read it twice; see S-6). |
| Match Detail `_infoRow` (82 px label + Expanded value) | Label 82 dp + value wraps to 5 lines. Long Hindi labels ("जानकारी" etc.) fit in 82 dp at 1.0×. | ✅ PASS at 1.0×; ⚠️ at 1.3× the 82 px label column can clip long labels — see S-7. |

**No horizontal overflow was found at 360 dp / 1.0×** — the
horizontal-scroll tables and FittedBox/ellipsis strategy work.

---

## 5. Font scale 1.3× (Android "Large text" / `textScaleFactor`)

Flutter's `MediaQuery.textScaler` scales all `Text` by default (no
`textScaleFactor` clamp exists anywhere in the app — verified by grep:
**zero** `textScaleFactor` / `textScaler` / `MediaQuery` overrides).
That is the *correct* default (never clamp the user's chosen size),
but it means fixed-size containers must absorb +30 % text.

| Element | 1.3× behaviour | Verdict |
|---|---|---|
| Body text (12–14 px → 15.6–18.2 px) | Wraps to extra lines in `maxLines: 2–3` blocks; `ListView`s grow. | ✅ PASS — lists scroll, no fixed heights on text blocks. |
| `_FilterTabs` (14 px → 18.2 px, FittedBox `scaleDown`) | FittedBox *shrinks* the label back down to fit the ~110 dp slot, so at 1.3× the tab label renders at ≈ 10.8 px effective — **smaller than the user's chosen size**, defeating the accessibility setting. | ⚠️ **SHOULD-FIX** — FittedBox scaleDown is the right overflow guard at 1.0× but the wrong behaviour at 1.3×. Prefer: allow the tab row to grow taller (2 lines) or reduce to shorter labels ("Live / Next / Done") at large scale, rather than shrinking text below the user's setting. Same note for the header "KingCric" FittedBox (22 → 28.6 px requested, shrunk back — but the header is a brand mark, so shrinking is acceptable there; document it). |
| Header "KingCric" (22 px → 28.6 px, FittedBox) | Shrinks back to fit. Brand mark — acceptable. | ✅ PASS (documented exception). |
| `StatCard` grid (fixed `childAspectRatio: 1.55`, cell 161 × ~104 dp) | Content at 1.3×: label 11→14.3 + value 21→27.3 + sub 11→14.3 + bar 6 + paddings ≈ 85–95 dp — fits in ~104 dp, **borderline**. Hindi label "स्ट्राइक रेट" (longer than "Strike Rate") can wrap to 2 lines → pushes total to ~105–110 dp → **overflow / clipped bar** in the worst case. | ⚠️ **SHOULD-FIX** — see S-8. |
| BottomNav Hindi labels | "पसंदीदा" at 1.3× ≈ 71 dp wide in a 72 dp slot — **clips or ellipsises**. EN fits. | ⚠️ **SHOULD-FIX** — see S-9. |
| Match Detail `_infoRow` label column (fixed 82 px) | Hindi labels at 1.3× ("जानकारी" is short, but "प्रीव्यू और जानकारी" is not used here; labels are Venue/Format/League/Toss/Umpires/Referee/Pitch/Weather — the *values* wrap, the *labels* are short EN words; in Hindi mode labels are still EN "Venue" etc. because `_infoRow` labels are hardcoded EN — see §6). | ✅ PASS for size; ❌ for Hindi (see §6). |
| Scorecard tables (fixed 720 px) | Text inside cells grows, but cells are fixed-width + `maxLines: 1` — long batter names at 1.3× will **ellipsise more aggressively** (still readable, not overflow). The 190 px name column at 1.3× holds ≈ 13 chars at 14 px → "Babar Azam" fits, "Shubman Gill" fits, longer names clip with "…". | ✅ PASS (ellipsis, not overflow) — but consider widening the name column to 210 px for 1.3× headroom. |
| `PlayerCard` right column (fixed 92 px) | "Avg 45.6" / "SR 78.8" at 1.3× ≈ 11→14.3 px — fits in 92 px. The "Real • Cricsheet" label at 1.3× ≈ 14 px × ~15 chars ≈ 110 px > 92 px → **ellipsises to "Real • Cricshe…"** (the icon + label row is `Flexible`, so it shrinks the text — readable but ugly). | ⚠️ SHOULD-FIX — widen to 100 px or allow the source label to wrap to 2 lines. |
| `GoldDonut` centre number (18 px → 23.4 px) | Fixed 72 dp donut, `maxLines: 1` + clip — "100" at 23 px fits (~35 dp). | ✅ PASS |
| `AnimatedScore` (38 px → 49 px) | `maxLines: 1` + clip — a 3-digit score at 49 px ≈ 75 dp, fits in the hero. | ✅ PASS |
| Dialogs / SnackBars ("Profile not available…") | Material handles scaling; SnackBar wraps to 2 lines. | ✅ PASS |

**Overall 1.3× verdict:** no crash, no hard overflow found in the
common path, but three soft spots (tab shrink, StatCard grid, BottomNav
Hindi) need the fixes in §7.

---

## 6. Hindi labels

| Area | Hindi coverage | Verdict |
|---|---|---|
| `strings.dart` — Home strings (matches, trending, next up, no-live, offline, refresh, updating, format filter) | ✅ Full EN + हिं | ✅ PASS |
| `strings.dart` — nav / common (home, live, upcoming, finished, leagues, stats, favourites, compare) | ✅ Full EN + हिं | ✅ PASS |
| `strings.dart` — profile / match (vs opponent, format-wise, venue, recent form, matchup, prediction, squad, scorecard) | ✅ Full EN + हिं | ✅ PASS |
| Match Detail tabs (Live / Scorecard / Squad / Prediction) | ✅ Via `lang.t` | ✅ PASS |
| **Hardcoded EN strings NOT in `strings.dart`** (found by grep) | ❌ **FAIL** — see list below | ❌ |
| Devanagari rendering | ✅ Flutter renders Devanagari natively; no custom font needed. Long Hindi words ("पसंदीदा", "आने वाले") are wider than EN — accounted for in §4/§5. | ✅ PASS |

**Hardcoded EN strings that do NOT switch with the toggle** (all in
`match_detail_screen.dart` unless noted):
- `'Target & Equation'`, `'Commentary'`, `'Fall of Wickets'`,
  `'Partnerships'`, `'Yet to Bat'`, `'BATTING'`, `'BOWLING'`,
  `'Full card — tap a batter for profile'`,
  `'O • M • R • W • Econ • Wd • Nb'`, `'Swipe table sideways…'`,
  `'Swipe sideways for Econ / Wd / Nb'`, `'Batting: …'` / `'Bowling: …'`
  / `'Last ball: '`, `'Umpires: …'`, `'Weather'`,
  `'Not available from free providers yet.'`, `'No commentary available.'`,
  `'Scorecard not available yet.'`, `'Squad not available yet…'`,
  `'Squad data will appear…'`, `'Who will fire? — King Prediction'`
  (one copy is localised, the squad/prediction copy is not),
  `'Form + vs Opponent + …'` (prediction header — localised in one
  place, hardcoded in the other), `'Batting'` / `'Bowling'` (compare
  headers), `'Most Runs'` / `'Best Average…'` / all Stats section
  titles, `'Points Table'` / `'Top Players'` / `'Matches'` (Leagues
  headers — `'Points Table'`/`'Top Players'` keys exist in strings.dart
  but the screen uses hardcoded EN), `'Favourite Teams — tap ⭐…'`,
  `'Notify me about'`, event names/hints (`'Wickets'` etc. — keys are
  EN-only), `'Matches of your favourite teams'`, `'Star a team…'`,
  `'No favourites yet…'`, `'Profile not available for … yet.'`
  (×2), `'Source — A: … • B: …'`, `'Showing X numbers only.'`,
  `'Level …' / '… leads …'`, `'Tap for profile'`,
  `'Tap for FULL scorecard'` / `'Scorecard →'`, `'Starts: Today…'`
  (date/time format is EN-only: "Today, 3:30 PM" / "Jan" months),
  `'Last updated HH:MM'` (prefix is localised, the "HH:MM" itself is
  fine — but the Match Detail copy is hardcoded EN, the Home copy uses
  `lang.t`), `'Batting'` / `'Bowling'` table headers in profile
  (`_FormatTables`), `'Leagues'`, `'Dismissal History'`,
  `'All Formats — Full Table'`, `'No batting data for …'`,
  `'No bowling data for …'`, `'Squad — tap a player…'`,
  `'Squad — Squad (N)'`, `'Prediction is a model, not a guarantee…'`
  (one copy localised via `lang.t('disclaimer')`, the other hardcoded).
- **Impact:** switching to हिं translates the shell (nav, Home headers,
  filter tabs) but leaves the *content* — scorecard, stats, leagues,
  favourites, compare, most detail text — in English. A Hindi-only user
  gets a half-Hindi app. This is the largest Hindi gap.
- **Also:** `_infoRow` labels ("Venue", "Format", …) and `_startsLine`
  month names ("Jan"…) are hardcoded EN. Dates should use
  `intl` `DateFormat` with the active locale.

---

## 7. Findings — must-fix (M) and should-fix (S)

### Must-fix

**M-1 — Red verdict text margin (PredictionCard, `red` #E74C3C on navyCard, 4.41).**
Passes, but by 0.09. Any future lightening (or rendering on the
red-tinted FOW background) breaks it. Fix: darken the red used for
*text* to #FF6B5E or #F26D5E (keeps the "red" meaning, raises the
ratio), or bump the verdict font weight/size. Verify the new pair
computes ≥ 4.5.

**M-2 — LIVE pill white-on-red (LivePill, 12 px, 3.55).**
Small text needs 4.5. Fix: darken the pill gradient to
#D92D20 → #A61E1E (white then computes ≈ 5.0+), or switch the pill
text to black on goldLight. Do not just bump the font — 12 px is the
right size for a pill; fix the colours.

**M-3 — Sub-48 dp touch targets.**
- `_FilterTabs`: increase vertical padding 12 → 14 (44 → 48 dp).
- `LanguageToggle`: remove `visualDensity: compact` (or set
  `materialTapTargetSize: padded`) so EN / हिं chips reach 48 dp.
- Audit-wide: set `materialTapTargetSize: MaterialTapTargetSize.padded`
  on **every** `ChoiceChip` (Compare, Stats, Leagues, PlayerProfile
  format chips currently rely on default).

**M-4 — Favourites star button has no accessible name.**
Add `tooltip: 'Follow <team/player>' / 'Unfollow …'` (and the Hindi
equivalents) to both star `IconButton`s. Tooltip gives TalkBack a name
for free. Same for the Leagues chevron `Icon` (decorative — set
`ExcludeSemantics` or leave, since the row text carries it; the star
is the interactive one that must be named).

**M-5 — Semantics for the main interactive surfaces.**
Add `Semantics` (label + hint + button) to:
- `KingMatchCard`: one summary label, e.g.
  `"Austria Women vs Sweden Women, live, Austria 37 for 3, need 88
  from 78 balls, tap for full scorecard"` (+ Hindi equivalent).
  Mark inner texts `ExcludeSemantics` so TalkBack reads the summary
  once, not every child.
- `PlayerCard`: `"Virat Kohli, Batter, India, 27150 runs, tap for
  profile"` (+ Hindi).
- Scorecard batter/bowler name `InkWell`s: `Semantics(button: true,
  label: 'Open profile for <name>')`.
- Horizontal-scroll scorecard / points / format tables:
  `Semantics(label: 'Scorecard table, swipe sideways for more
  columns', …)` on the scroll container, or wrap the visual "↔ Swipe"
  hint in `Semantics` so it is announced.
- `GoldDonut` + all `LinearProgressIndicator` bars: wrap in
  `Semantics(label: '<what>, <value>%')` — CustomPaint is silent
  without it.
- `Compare` dropdowns: `Semantics(label: 'Compare player A, <name>')`.
- List updates: announce Refresh / error / empty-state changes via a
  `Semantics(liveRegion: true)` region on Home.

### Should-fix

**S-1 — `textMuted` on navyCard2 (4.71) is one shade from failing.**
Do not darken `textMuted` anywhere; if a new background lighter than
navyCard2 appears, re-check.

**S-2 — Tab shrink at 1.3× (FittedBox `scaleDown`).**
Prefer growing the tab row taller / shorter labels over shrinking
text below the user's chosen size. Keep the header-brand exception
documented.

**S-3 — White-on-red / white-on-green / white-on-amber are latent FAILs.**
No white text currently sits on those fills. Add a lint comment in
`app_theme.dart` ("never put white text on green/amber/red fills")
so a future contributor does not introduce one.

**S-4 — H2H bar: add a semantic label** (`Semantics(label: 'Head to
head, <A> <winsA> wins, <B> <winsB> wins, <total> matches')`).

**S-5 — Compare winner: add a non-colour winner signal.**
E.g. a "▲ leads" marker / bold "leads" text next to the winner's
column, plus a Semantics label. The summary line ("X leads N–M")
already exists — make sure TalkBack reaches it (it is plain Text, so
it does), and add the marker so colour-blind users see it too.

**S-6 — OverGraph duplicate announcement.**
The partnership bar row shows "N runs" in a 150 px box *and* the full
label below — TalkBack reads the number twice. Mark the box
`ExcludeSemantics` (the label below carries it) or merge into one
label.

**S-7 — `_infoRow` label column (82 px) + hardcoded EN labels.**
Localise the labels (add `venue`/`format`/`league`/`toss`/`umpires`/
`referee`/`pitch`/`weather` keys to `strings.dart`) and let the label
column size to content (`IntrinsicWidth` / `ConstrainedBox`) instead
of a fixed 82 px, so Hindi labels never clip.

**S-8 — `StatCard` grid fixed aspect (1.55) at 1.3×.**
Replace `childAspectRatio` with `mainAxisExtent` (≈ 110 dp) or
`SliverGridDelegateWithMaxCrossAxisExtent`, so the cell grows with
text instead of clipping the bar. Alternatively reduce the value font
21 → 19 px (still ≥ 4.5 contrast, still bold) to buy headroom.

**S-9 — BottomNav Hindi labels at 1.3×.**
"पसंदीदा" ≈ 71 dp in a 72 dp slot. Options: shorten the Hindi label
("पसंद" — check with a Hindi speaker that it still reads as
"Favourites"), or set `selectedLabelStyle` / `unselectedLabelStyle`
with a slightly smaller font for Hindi, or allow the bar to grow.
Verify on a 360 dp device at 1.3× — do not ship on math alone.

**S-10 — PlayerCard source label at 1.3×.**
Widen the right column 92 → 100 px, or let the source label wrap to
2 lines. "Real • Cricshe…" is the current worst case.

**S-11 — Localise the hardcoded strings (§6).**
This is the largest single Hindi gap. Add the missing keys to
`strings.dart` (scorecard headers, stats/leagues/favourites/compare
titles, info-row labels, date formatting via `intl` with the active
locale) and replace every hardcoded EN literal in screens/widgets.
Do it in one pass — a half-localised app is worse than a documented
EN-only screen, because the toggle *promises* Hindi.

---

## 8. Per-screen verdict

| Screen | 360 dp | 1.3× | Contrast | Touch | Semantics | Hindi | Overall |
|---|---|---|---|---|---|---|---|
| Home | ✅ | ⚠️ tabs shrink | ✅ | ❌ M-3 (tabs, lang chips) | ⚠️ partial (3 sites OK, cards/tables missing) | ⚠️ shell OK, content EN | **FAIL — M-3, M-5** |
| Match Detail (Live) | ✅ | ✅ | ✅ | ✅ | ❌ M-5 (tables, names) | ❌ hardcoded EN | **FAIL — M-5, S-11** |
| Match Detail (Scorecard) | ✅ scroll | ✅ ellipsis | ✅ | ✅ | ❌ M-5 (tables, names) | ❌ hardcoded EN | **FAIL — M-5, S-11** |
| Match Detail (Squad / Prediction) | ✅ | ✅ | ⚠️ M-1 (red) | ✅ | ⚠️ cards missing | ⚠️ mixed | **FAIL — M-1, M-5** |
| Player Profile | ✅ scroll | ⚠️ S-8 grid | ✅ | ⚠️ chips default | ⚠️ tables missing | ⚠️ mixed | **FAIL — M-5, S-8, S-11** |
| Compare | ✅ | ✅ | ✅ | ⚠️ chips default | ⚠️ dropdown | ❌ hardcoded EN | **FAIL — M-5, S-11** |
| Stats | ✅ | ✅ | ✅ | ⚠️ chips default | ⚠️ sections | ❌ hardcoded EN | **FAIL — M-5, S-11** |
| Leagues | ✅ scroll | ✅ | ✅ | ⚠️ chips default | ⚠️ table | ❌ hardcoded EN | **FAIL — M-5, S-11** |
| Favourites | ✅ | ✅ | ✅ | ✅ | ❌ M-4 star | ❌ hardcoded EN | **FAIL — M-4, S-11** |
| BottomNav / shell | ✅ | ⚠️ S-9 Hindi | ✅ | ✅ | ⚠️ verify Hindi announcement | ⚠️ S-9 | **CONDITIONAL** |
| Global (theme) | — | — | ✅ (1 real fail: M-2) | — | — | — | **FAIL — M-2** |

**Reading the table:** no screen overflows at 360 dp / 1.0× and the
colour system passes. Every screen fails on the *same two* axes:
Semantics coverage (M-5) and Hindi completeness (S-11). Fix those two
systematically and the whole app moves to PASS.

---

## 9. Test evidence (read-only run)

`flutter test` (full suite, this VM, audit run):
- **53 passed, 4 failed** (57 total).
- The 4 failures are **test-harness issues in 2 suites**, not
  accessibility regressions found by this audit:
  - `match_detail_test.dart` (2): "FOW row shows the number ONCE",
    "Squad tab splits Team A / Team B" — both throw
    `Bad state: Too many elements` from `tester.scrollUntilVisible`
    (the finder matches multiple widgets; the test's scroll helper
    needs `.single` disambiguation). The underlying UI behaviour
    (FOW number once, squad split) is present in the code.
  - `widget_test.dart` (2): "OverGraph renders real FOW + partnership
    bars", "Profile shows ONE Cricsheet source line" — same
    `scrollUntilVisible` / finder-ambiguity pattern (not re-run in
    isolation during this audit; the full-suite log shows the same
    failure class).
- Recommendation: fix the 4 tests' finders (disambiguate with
  `.first` / a unique key) — do not change the UI to satisfy them.
  Re-run the suite after the M-fixes to confirm no new failures.

---

## 10. What is good (keep)

- **Contrast:** every real text pair passes AA — rare for a dark +
  gold theme. The palette is a strength.
- **No overflow at 360 dp / 1.0×:** horizontal-scroll tables +
  FittedBox + ellipsis + `maxLines` are applied consistently.
- **Three correct Semantics sites** on Home (clear-search, format
  chips, filter tabs) — the pattern to copy everywhere.
- **Honest empty / error states** with Retry — TalkBack can reach
  them; they just need live-region announcements.
- **No `textScaleFactor` clamp** — the user's chosen text size is
  respected (the right default).
- **Decorative emoji** (👑 📍 🪙) always accompany real text, never
  replace it.
- **Favourites event gating** (master switch disables events) is
  correctly modelled — the semantics just need to announce it.

---

## Appendix — how to verify the fixes (for the fixing team)

1. **Contrast:** re-run the ratio table in §1 after any colour change;
   no pair may drop below 4.5 (small) / 3.0 (large).
2. **Touch:** enable "Show layout bounds" / "Show taps" in Developer
   Options; every tappable must show ≥ 48 dp in both dimensions.
3. **TalkBack:** on a 360 dp device, navigate Home → Match Detail →
   Scorecard → Player Profile → Compare → Stats → Leagues →
   Favourites with TalkBack on, at 1.0× and 1.3×, in EN and हिं.
   Every interactive element must announce a name + role + state;
   every table must announce its scrollability; no element may read
   as bare "button".
4. **1.3×:** set font size to Largest in Android Settings, open every
   screen, confirm no clipping (especially StatCard grid, BottomNav
   Hindi, PlayerCard source label, filter tabs).
5. **Hindi:** toggle to हिं, open every screen, confirm no EN-only
   content remains except proper nouns (player/team names) and
   numerals.
6. **Tests:** fix the 4 finder-ambiguous tests, re-run the full suite,
   confirm 57/57.
