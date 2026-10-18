# KingCric — Design System (Google-style, v1)

> **Status:** Spec only. Read-only — this file changes no code. Implementation
> must converge to these tokens; where existing code differs, the token table
> in §1–§3 is the source of truth for the next build.
>
> **Sources:** `lib/utils/app_theme.dart`, `lib/widgets/premium_widgets.dart`,
> `lib/widgets/match_card.dart`, `REFERENCE-SPEC.md` §2/§5, `CRICKETLINEX-REFERENCE.md`
> §4–§6, `REQUIREMENTS-MAPPING.md` (Hindi parity, honest labels).
>
> **Product rule (from REFERENCE-SPEC.md):** KingCric = Cricbuzz speed +
> Crex clarity + Cricinfo depth + Cricmetric analytics, in a King
> (navy + gold) skin — every number readable in 2 seconds, in Hindi or English.
>
> **Identity rule:** Identity = colours + logo + tone (navy/gold, crown +
> bat-ball, "Har Ball, Har Stat, King Jaisa."). Layout = reference apps
> (familiar, not invented). Never copy another app's code, text, images,
> or data — patterns only.

---

## 0. Principles (non-negotiable)

| # | Principle | What it means in practice |
|---|-----------|---------------------------|
| P1 | **One status truth** | Filter, pill, header, and card all read the same effective status (`isEffectivelyLive` + `isCompleted`). A live match never shows an UPCOMING pill. |
| P2 | **2-second rule** | A new user answers in 2 s: "Which matches are live? Score? What do I tap?" Live first, score biggest, CTA one tap away. |
| P3 | **One team = one row** | Never `TeamA,TeamB` on one line. Team name left, score right, one row per team/innings. |
| P4 | **No truncation, no fake chrome** | Full `KingCric` header (FittedBox), tabs never wrap, titles ≤ 2 lines, tables scroll horizontally with a hint. No ad-placeholder box, no `Complete` on demo/curated data, no dev text in release. |
| P5 | **Honest labels** | Every number carries Real / Demo / Partial + provider + dataset size where relevant. Demo is never presented as real. |
| P6 | **King skin, reference layout** | Navy + gold is the brand. Card order, scorecard columns, profile order, and tab order follow the reference apps. |
| P7 | **Hindi parity** | Every user-facing string goes through `Strings.t` (EN/हिं). The toggle switches ALL labels, not just the header. |
| P8 | **Premium = restraint** | 2 brand colours + neutrals. 1 font family. 1 spacing grid. Subtle gradients, soft shadows, one-shot animations. No rainbow, no endless blink, no crowded screen. |
| P9 | **Smooth = cache-first** | Show cached data instantly, refresh in background, no flicker, no full-screen spinner for a refresh. Skeleton for first load only. |
| P10 | **Accessible by default** | Touch target ≥ 48 dp, contrast per §10, font-scale safe (FittedBox / maxLines / ellipsis, never hard clip). |

---

## 1. Colour tokens

### 1.1 Brand (dark mode = default)

| Token | Hex | Usage | Current code |
|---|---|---|---|
| `navy` (bg) | `#0B1026` | Scaffold / app background | `AppTheme.navy` |
| `navyDeep` | `#070B1D` | Deepest background, splash / bottom sheet | `AppTheme.navyDeep` |
| `navyCard` (surface) | `#151B38` | Default card surface | `AppTheme.navyCard` |
| `navyCard2` | `#1D2450` | Raised card / chip bg / avatar inner | `AppTheme.navyCard2` |
| `navyCard3` | `#232B5E` | Track / divider-strong / donut bg | `AppTheme.navyCard3` |
| `gold` (primary) | `#D4AF37` | Primary actions, borders, highlights, selected tab | `AppTheme.gold` |
| `goldLight` | `#FFD700` | Bright gold: scores, active text, pill text | `AppTheme.goldLight` |
| `goldSoft` | `#FFE98A` | Soft gold: result lines, subtle emphasis | `AppTheme.goldSoft` |
| `goldDark` | `#9C7E1A` | Gradient end, pressed state, dark gold | `AppTheme.goldDark` |

### 1.2 Text (dark mode)

| Token | Hex | Usage |
|---|---|---|
| `textPrimary` | `#F5F0E1` | Headings, scores, primary body |
| `textSecondary` | `#B8BDD4` | Secondary body, captions, venue, labels |
| `textMuted` | `#8A90B0` | Muted / disabled / tertiary hints |
| `onGold` | `#000000` | Text on gold primary button (black for contrast) |
| `onLive` | `#FFFFFF` | Text on LIVE pill (white) |

### 1.3 Neutrals / dividers (dark mode)

| Token | Hex / value | Usage |
|---|---|---|
| `white12` | `White @ 12%` (`Colors.white12`) | Hairline divider, card separator, table row border (`white @ 7%` for table rows) |
| `white07` | `White @ 7%` | Scoreboard row bottom border |
| `black45` | `Black @ 45%` | Card shadow (see §3) |
| `scrim` | `Black @ 60%` | Modal / bottom-sheet scrim |

### 1.4 Semantic

| Token | Hex | Usage | Do NOT use for |
|---|---|---|---|
| `liveRed` | `#FF3B30` | LIVE pill bg gradient start, LIVE dot, live pulse glow | Body text, non-live emphasis |
| `liveRedDark` | `#C81E1E` | LIVE pill bg gradient end | — |
| `red` (error) | `#E74C3C` | Errors, destructive actions, failed state | Live indicator (use `liveRed`) |
| `green` (success / win) | `#2ECC71` | Success, "Real" source check, win, positive delta | Live indicator |
| `greenDark` | `#1E9E52` | Green gradient / pressed, donut for success | — |
| `amber` (warning) | `#F39C12` | Warning, "Partial" / "Demo" caution, favourite star, risky prediction | Gold primary (use `gold` for brand) |
| `blue` (info) | `#4DA3FF` | Info links, secondary info accents only | Primary actions (gold owns that) |

> **Rule:** Gold is the *only* brand accent. Semantic colours are for
> *meaning* (live / success / warning / error / info), never for decoration.
> `amber` ≠ `gold`: amber warns, gold brands.

### 1.5 Gradients (subtle — never flashy)

| Token | Stops | Usage |
|---|---|---|
| `goldGradient` | `#FFD700 → #D4AF37 → #9C7E1A` (TL → BR) | Gold rule under section headers, avatar ring, gold text accents, primary button (optional) |
| `navyGradient` | `#1D2450 → #0B1026` (TL → BR) | Page / header background wash |
| `cardGradient` | `#1D2450 → #151B38` (TL → BR) | Default premium card |
| `liveGradient` | `#2B1A3D → #151B38` (TL → BR) | Live card background (hero variant) |
| `heroGradient` | `#2A1E4A → #151B38 → #0B1026` (TL → BR) | Hero card (match hero, player hero) |
| `livePillGradient` | `#FF3B30 → #C81E1E` (L → R) | LIVE pill only |

> **Rule:** Max 1 gradient per card. No gradient text except the 64 px gold
> rule and the avatar ring. No rainbow gradients anywhere.

### 1.6 Light mode (follow-up, §9)

Light mode keeps the *same* tokens, remapped: bg `#F6F3EA` (warm paper),
surface `#FFFFFF`, text `#10132B` / `#4A4E6B` / `#7A7E9C`, gold stays
`#D4AF37` (borders / accents) with `goldDark #9C7E1A` for text-on-light
contrast. Semantic colours stay the same hex. Dark is the default and the
only mode that ships in the next build; light is a follow-up, not a blocker.

---

## 2. Typography

### 2.1 Family

| Rule | Value |
|---|---|
| Family | **1 family only — system default** (Roboto on Android). No custom font file in v1. |
| Why | System font is fastest, most legible, and matches the OS. Premium comes from hierarchy + spacing, not a fancy font. |
| Hindi | Same family; Devanagari glyphs render via system font. Verify every Hindi string at the same sizes (Hindi glyphs are taller — see §10). |

### 2.2 Scale (the only sizes in the app)

| Token | Size | Weight | Line height | Letter spacing | Usage |
|---|---|---|---|---|---|
| `display` | **28** | w900 | 34 | 0.2 | Hero score on Match Detail hero (with `AnimatedScore`), rarely elsewhere |
| `h1` | **24** | w900 | 30 | 0.2 | Screen titles, player name in profile hero |
| `h2` | **22** | w900 | 28 | 0.3 | AppBar title (`KingCric`), section hero titles |
| `h3` | **20** | w900 | 26 | 0.2 | Match fixture title (≤ 2 lines), card title |
| `title` | **18** | w900 | 24 | 0.2 | Section header (`PremiumSectionHeader`), card heading |
| `subtitle` | **16** | w800 | 22 | 0 | Sub-heading, key stat label, tab label (selected) |
| `body` | **14** | w400 / w700 | 20 | 0 | Body text, list rows, team rows |
| `bodySmall` | **13** | w400 / w800 | 18 | 0 | Secondary rows, stat values, table body |
| `caption` | **12** | w400 / w700 | 16 | 0 | Captions, venue, league • format, last-updated, CTA |
| `label` | **11** | w700 / w900 | 14 | 0.5 | Table headers, pill labels, over labels, eyebrows |

> **Rules:**
> - No other sizes. If a design needs a size not in this table, round to the
>   nearest token — do not invent `15`, `17`, `19`, `21`, `23`, etc.
> - Scores are always w900. Labels are always w700+. Body is w400 unless it
>   is a value (then w800).
> - Numbers use tabular figures implicitly via the system font; never
>   letter-space numbers beyond `0.5` (pill labels only).
> - Existing code uses 38 px for `AnimatedScore` — cap hero score at 38 px
>   only for that one widget; the `display` token (28) is the rule for
>   static hero text.

### 2.3 Text behaviour (never clip mid-word)

| Rule | Value |
|---|---|
| Match fixture title | `maxLines: 2`, `ellipsis`, w900 20 |
| Venue | `maxLines: 1`, `ellipsis`, caption 12, `textSecondary` |
| Team name (row) | `maxLines: 1`, `ellipsis`, body 15 w700 — with `FittedBox(scaleDown)` on the header `KingCric` (22 px, scales instead of ellipsising) |
| Tab label | Single line, `FittedBox(scaleDown)`, never wraps (`Upcomin g` is a bug) |
| Table header | `maxLines: 1`, `clip`, label 11 w900 |
| Section header | `maxLines: 2`, `ellipsis`, title 18 w900 + 64 px gold rule (§3) |
| Long names | Wrap to 2 lines or shrink — never cut mid-word without ellipsis. |

---

## 3. Spacing, radius, shadow

### 3.1 Spacing grid

| Token | Value | Usage |
|---|---|---|
| `s2` | **2** | Micro gap (icon → label inside pill/chip) |
| `s4` | **4** | Tight gap (row padding vertical, dot → text) |
| `s8` | **8** | Default inner gap (icon → text, chip → chip, label → value) |
| `s12` | **12** | Card-to-card gap, section inner gap, tab → content |
| `s16` | **16** | Page padding, card padding, section gap |
| `s24` | **24** | Large section gap (between major blocks) |

> **Rule:** All padding / margin / gaps come from `{2, 4, 8, 12, 16, 24}`.
> Existing `10`, `14`, `18`, `20` values in code converge to the nearest
> grid token on the next pass (10 → 8 or 12, 14 → 12 or 16, 18 → 16,
> 20 → 16 or 24). Do not invent new spacing values.

### 3.2 Radius

| Token | Value | Usage |
|---|---|---|
| `r8` | **8** | Small: progress bar, donut track, inline tags |
| `r12` | **12** | Small card, table container, image thumb, button (secondary) |
| `r16` | **16** | Default card (`CardTheme`, `premiumCard` default), input, bottom sheet |
| `r20` | **20** | Hero card (`heroCard`), match card (`InkWell` ripple), chip/pill (full pill = 20), tab container |
| `rCircle` | **50%** | Avatar, LIVE dot, icon circle |

> **Rule:** Cards are `16` (default) or `20` (hero/match). Chips/pills are
> `20` (fully rounded). Never use `10`, `14`, `18` for new work.

### 3.3 Shadow (dark mode — soft, never harsh)

| Token | Value | Usage |
|---|---|---|
| `shadowCard` | `Black @ 45%, blur 18, offset (0, 8)` + `Gold @ 8%, blur 24, offset (0, 2)` | Default premium card |
| `shadowHero` | `Black @ 50%, blur 22, offset (0, 10)` + `Gold @ 18%, blur 32, offset (0, 4)` | Hero card |
| `shadowPill` | `LiveRed @ 50%, blur 12, offset (0, 3)` | LIVE pill only |
| `shadowAvatar` | `Gold @ 45%, blur 12, offset (0, 4)` | Avatar ring |

> **Rule:** No shadow on flat surfaces (scaffold, app bar, tab bar).
> `elevation: 0` on `CardTheme` — shadows come from `BoxDecoration`, not
> Material elevation. Light mode uses softer shadows (see §9).

### 3.4 Borders

| Token | Value | Usage |
|---|---|---|
| `borderGold` | Gold @ 45%, width 1.2 | Default premium card border |
| `borderGoldStrong` | Gold @ 60%, width 1.4 | Hero card border |
| `borderSubtle` | Gold @ 35%, width 1.0 | `CardTheme` side (legacy) — converge to `borderGold` |
| `borderChip` | Gold @ 50%, width 1.0 | `GoldChip` border |
| `divider` | White @ 12%, height 1 | Section divider |
| `dividerTable` | White @ 7%, height 1 | Scoreboard row bottom border |

---

## 4. Cards

### 4.1 `KingGradientCard` (default)

- Background: `cardGradient`. Radius: `16` (spec) — existing code uses
  `18` default / `20` for tap ripple; converge to `16` / `20` hero.
- Border: `borderGold`. Shadow: `shadowCard`. Padding: `16`.
- Tap: `InkWell` with `borderRadius 20`, ripple only — no scale bounce.
- Content: any child; header + body pattern below.

### 4.2 Hero card (`hero: true` / `AppTheme.heroCard()`)

- Background: `heroGradient`. Radius: `20`. Border: `borderGoldStrong`.
- Shadow: `shadowHero`. Padding: `16`.
- Usage: live match card, match-detail hero, player-profile hero. Only ONE
  hero per screen — the live match or the hero score. Non-live cards never
  get the hero treatment.

### 4.3 Match card (`KingMatchCard` — ONE component, Home AND Leagues)

Canonical order (CricketLineX / Cricbuzz / Crex pattern):

1. Row: status pill (`LivePill` if live, else `GoldChip` RESULT / UPCOMING)
   + `League • Format` (caption 12, `textSecondary`, 1 line) + `Last: X`
   (optional, goldLight w800) — pill derives from the *same* effective
   status as the filter.
2. Fixture title: h3 20 w900, ≤ 2 lines.
3. Venue: `📍 Venue` (caption 12, `textSecondary`, 1 line) — only if present.
4. Score rows: ONE row per team — name left (body 15 w700, 1 line) + score
   right (17 w900, `goldLight`). Upcoming cards show NO score rows (a match
   that has not started has no score) — instead a `Starts: Today, 7:00 PM`
   line. Finished cards show both scores + result line.
5. Result / equation: result line (goldSoft w700, ≤ 2 lines) or equation
   (`need 88 in 78 balls`) for live chases.
6. Live only: divider + `Batting: …` / `Bowling: …` (12 px).
7. CTA row: `→ Tap for FULL scorecard` (goldLight 12 w700) + `Scorecard →`
   (gold 12). Exactly ONE CTA — no duplicate CTA row.

### 4.4 Section header (`PremiumSectionHeader`)

- Title: title 18 w900, ≤ 2 lines. Optional icon: 20 px, `goldLight`, 8 px gap.
- Optional subtitle: caption 12, `textSecondary`, ≤ 2 lines, 3 px below title.
- Gold rule: 64 × 2 px, `goldGradient`, 8 px below subtitle.
- Top padding 18, bottom padding 10.

### 4.5 Empty / error / loading states

| State | Pattern |
|---|---|
| Empty (truly none) | Centred caption: `No matches in this section.` — only when the filter genuinely has zero matches. Never show it while a live match exists in another bucket. |
| Loading (first load) | Skeleton: grey boxes in card shape (see §8), no full-screen spinner. |
| Refreshing | Small indicator at top of list, old data stays visible (stale-while-revalidate). Never blank the list. |
| Error | Keep old data + `Last updated HH:MM` + Retry button. Never blank screen, never crash. |
| No table | Honest `Table not available` — never a fake table. |
| No ads | Render NOTHING (`SizedBox.shrink()`) when no AdMob ID — never a placeholder box. |

---

## 5. Buttons

### 5.1 Primary (gold)

- Background: `gold` (`#D4AF37`). Text: `onGold` black, subtitle 16 w800.
- Radius: `12`. Padding: vertical 12, horizontal 16. Min height: `48`.
- States: pressed → `goldDark`; disabled → gold @ 40% + text @ 50%.
- Usage: main CTA per screen only (e.g. `Refresh`, `Follow`). Max 1 primary
  per screen.

### 5.2 Secondary (outline)

- Background: transparent. Border: gold @ 50%, 1.0. Text: `goldLight`,
  subtitle 16 w700. Radius: `12`. Padding: same as primary.
- Usage: secondary actions (`View all`, `Change`, `Clear`).

### 5.3 Text button

- No background, no border. Text: `goldLight`, body 14 w700.
- Usage: inline links, `Scorecard →`, `Tap for FULL scorecard`, `Retry`.

### 5.4 Icon button

- Hit area: **48 × 48** min (see §10). Icon: 24 px (see §7). Colour:
  `goldLight` for actions, `textSecondary` for neutral, `textMuted` for disabled.
- Favourite star: filled `amber` when favourited, outline `textSecondary` when not.

> **Rule:** Never use a coloured button for a non-action (e.g. a status pill
> is not a button). Buttons do things; pills label things.

---

## 6. Chips, pills, tabs

### 6.1 `GoldChip` (format / league / role / status)

- Background: gold @ 16%. Border: `borderChip`. Radius: `20`.
- Padding: horizontal 10, vertical 4. Text: goldSoft 12 w700, 1 line,
  ellipsis. Optional icon: 13 px, `goldLight`, 4 px gap.
- Labels: `RESULT`, `UPCOMING`, `Test`, `ODI`, `T20`, `T10`, `IPL`, `Batter`, etc.
- Never use a chip for a live match — live gets `LivePill`.

### 6.2 `LivePill` (LIVE only)

- Background: `livePillGradient`. Radius: `20`. Padding: horizontal 10,
  vertical 4. Shadow: `shadowPill`.
- Content: `LivePulseDot` (10–12 px, `liveRed`, glow) + 6 px gap + label
  `LIVE` (white, 12 w900, letterSpacing 1.2).
- Usage: live match card, live tab header, match-detail hero. Non-live
  cards never get a live pill.

### 6.3 Filter tabs (Home: Live / Upcoming / Finished)

- Custom `_FilterTabs` row: 3 `Expanded` buttons, single row, no wrap.
- Each label: single line, `FittedBox(scaleDown)` — never wraps
  (`Upcomin g` is a bug). Selected: gold pill background + black text;
  unselected: transparent + `textSecondary` text.
- Height: `48` min. Radius: `20` for the container, `20` for the selected pill.
- Order: **Live → Upcoming → Finished** (CricketLineX pattern; `Recent`
  is labelled `Finished` in UI, Hindi `समाप्त`).

### 6.4 Format chips (Test / ODI / T20 / T10)

- Same `GoldChip` style. Selected: gold fill + black text. Unselected:
  `navyCard2` bg + `textSecondary` text.
- Used on: Player Profile, Stats, Leagues, Team screens. `T10` is a
  first-class chip (not hidden), `U19` is a first-class filter (not buried).

### 6.5 Segmented / `SegmentedButton`

- Do NOT use `SegmentedButton` for the Home filter (it wraps labels).
  Use the custom `_FilterTabs` row (§6.3). `SegmentedButton` may be used
  only where labels are short and fixed (e.g. `EN | हिं` toggle — see §6.6).

### 6.6 Language toggle (EN / हिं)

- Compact chips, not full buttons. Selected: gold pill. Unselected: outline.
- Must switch ALL labels via `Strings.t` — never leave a screen half-translated.
- No duplicate crown icon next to the toggle (removed in V3 fix).

---

## 7. Tables (scorecard — the most important table in the app)

### 7.1 Scorecard columns (fixed — never reorder)

| Table | Columns (in order) |
|---|---|
| Batting | Batter + dismissal (flex) \| **R** \| **B** \| **4s** \| **6s** \| **SR** |
| Bowling | Bowler (flex) \| **O** \| **M** \| **R** \| **W** \| **Econ** \| **Wd** \| **Nb** |
| FOW | Numbered list: `1. 45-1 (Batter, 5.2 ov)` — one line each |
| Partnerships | `Batter A + Batter B — 68 (42 balls)` — one line each |
| Yet-to-bat | Chips, one per player |

- Header: `ScoreHeaderCell` — label 11 w900, `goldLight`, letterSpacing 0.5,
  right-aligned for numbers, fixed width 48 (batter/bowler name flexes).
- Body: `ScoreRow` — vertical padding 9, horizontal 8, bottom border
  `dividerTable`. Not-out row highlighted (gold @ 10% bg + `*` after name).
- Total row: bold, top border, `TOTAL 192/6 (20.0 ov)`.
- Extras: `Wd 3, Nb 1, B 1 (5)` — one line, caption 12.
- Container: fixed-width (720 px) + **horizontal scroll** + `swipe →` hint.
  Never squeeze columns until numbers clip.

### 7.2 Stats tables (player / leaders)

- Same header/body pattern. Numbers right-aligned, names left-aligned.
- Winner highlight: better value per row in gold (Compare screen). Draw = no highlight.
- Min-qualifier note under the table: e.g. `Min 10 innings` (caption 12, `textMuted`).
- Format filter above the table (chips), not inside it.

### 7.3 Points table (Leagues)

- Columns: Team (flex) \| P \| W \| L \| NR \| PTS \| NRR.
- NRR to 3 decimals, right-aligned. Leader row: gold left border (2 px).
- `Table not available` when the provider has no table — never a fake table.

---

## 8. Icons, images, animations

### 8.1 Icons

| Token | Value | Usage |
|---|---|---|
| `iconSmall` | **13–14 px** | Inside chips, CTA arrows, inline icons |
| `iconMedium` | **20 px** | Section header icons, list leading icons |
| `iconLarge` | **24 px** | AppBar / IconButton icons, bottom-nav icons |
| `iconHero` | **28–32 px** | Crown in header (48 px tile, crown glyph inside), empty-state icon |
| Colour | `goldLight` for actions / brand, `textSecondary` for neutral, `textMuted` for disabled, `liveRed` only for LIVE dot | Never use semantic colours for decorative icons |
| Hit area | **48 × 48 min** for every tappable icon (see §10) | Icon glyph may be 24 px; the tap target is 48 px |

- Icon set: Material icons only in v1 (no custom icon font). Bottom nav:
  Home (`home`), Leagues (`emoji_events`), Compare (`compare_arrows`),
  Stats (`bar_chart`), Favourites (`star`).

### 8.2 Images

| Token | Spec |
|---|---|
| App logo | Crown + Bat-Ball, gold on navy. Header tile: 48 × 48, radius 12, gold gradient bg. Launcher icon: all `mipmap-*` densities (48/72/96/144/192). |
| `KingAvatar` | Circle, gold-gradient ring (2.5 px padding), inner `navyCard2`, initials (max 2, uppercase, w900). Radius: 28 default (56 px diameter), font = radius × 0.62. Fallback: `?` if name empty. |
| Player photo | Circular, same ring as `KingAvatar` when a photo exists; initials fallback when it does not. Never show a broken-image icon. |
| Team logo | 32 × 32, radius 8, `navyCard2` bg, initials fallback. |
| Venue / stadium | 16:9, radius 16, `navyCard` bg, no image = no box (do not render an empty grey box). |
| Caching | `cached_network_image` or `Image.network` + cache — photo fetched once, reused. Placeholder: initials avatar, never a spinner inside a row. |
| Attribution | SportScore data renders `Powered by SportScore` (caption 11, `textMuted`) wherever its data appears. |

### 8.3 Animations (one-shot, 200–300 ms, never infinite)

| Token | Duration | Curve | Usage |
|---|---|---|---|
| `animFast` | **200 ms** | `easeOut` | Chip select, toggle, tab switch, button press |
| `animMedium` | **300 ms** | `easeOutCubic` | Card entry, stat bar fill, donut fill, count-up |
| `animHero` | **700 ms** | `easeOutBack` / `easeOutCubic` | LIVE dot scale-in (one-shot), `AnimatedScore` count-up, `StatBar` fill — one-shot only |
| `animNone` | 0 ms | — | Filter switch must not animate the list (no layout jank) |

> **Rules:**
> - **Never** `AnimationController.repeat` — a repeating controller never
>   settles, breaks `pumpAndSettle` tests, and burns CPU on a background tab.
>   The LIVE dot is a one-shot scale-in + static glow (`LivePulseDot`).
> - **Never** animate a full list rebuild. Only the changed row animates.
> - **Never** use a full-screen spinner for a refresh. Skeleton for first
>   load, small top indicator for refresh.
> - Hero transitions: card → detail uses the standard `MaterialPageRoute`
>   (no custom hero flight in v1). Keep it fast and predictable.

### 8.4 Skeleton (first load only)

- Grey boxes in card shape: `navyCard2` bg, radius 16, shimmer optional
  (one-shot, 700 ms). 2–3 skeleton cards on Home, 1 on detail.
- Skeleton shows ONLY on first load (no cache). Refresh never shows skeleton.

---

## 9. Dark mode (default) + Light mode (follow-up)

### 9.1 Dark (ships now)

- Scaffold: `navy #0B1026`. Surface: `navyCard #151B38`. Text:
  `textPrimary #F5F0E1` / `textSecondary #B8BDD4` / `textMuted #8A90B0`.
- Gold: `gold #D4AF37` primary, `goldLight #FFD700` bright, `goldSoft #FFE98A` soft.
- Cards: `cardGradient` + `borderGold` + `shadowCard`. Hero: `heroGradient` + `borderGoldStrong` + `shadowHero`.
- This is the only mode in the next build.

### 9.2 Light (follow-up — spec now, implementation later)

| Token | Light hex | Notes |
|---|---|---|
| `bg` | `#F6F3EA` (warm paper) | Scaffold |
| `surface` | `#FFFFFF` | Card |
| `surface2` | `#EFEAE0` | Chip / raised |
| `textPrimary` | `#10132B` | Headings / scores |
| `textSecondary` | `#4A4E6B` | Secondary |
| `textMuted` | `#7A7E9C` | Muted |
| `gold` | `#D4AF37` (same) | Borders / accents |
| `goldText` | `#9C7E1A` (`goldDark`) | Text on light — gold `#D4AF37` fails contrast on white, so gold *text* uses `goldDark` |
| `divider` | `Black @ 10%` | Dividers |
| Shadow | `Black @ 12%, blur 12, offset (0, 4)` | Softer than dark |

> **Rules for light mode:** Same layout, same spacing, same radius, same
> typography. Only colours change. Semantic colours (live / success /
> warning / error) stay the same hex. Do NOT ship light mode until the
> contrast audit (§10) passes for every token pair.

---

## 10. Accessibility

| Requirement | Rule |
|---|---|
| Touch target | **≥ 48 × 48 dp** for every tappable element (buttons, icon buttons, chips, tabs, list rows, star). Icon glyph may be smaller; the hit area is 48. |
| Contrast (dark) | `textPrimary #F5F0E1` on `navy #0B1026` ≈ 15:1 ✅. `textSecondary #B8BDD4` on `navy` ≈ 9:1 ✅. `textMuted #8A90B0` on `navy` ≈ 5:1 ✅ (body-small only, never for primary text). Black on `gold #D4AF37` ≈ 8:1 ✅. White on `liveRed #FF3B30` ≈ 3.5:1 — pill label is w900 12 px + glow; acceptable for a *label* (not body text), and the pill is never the only signal (dot + position + filter also signal LIVE). |
| Contrast (light) | `textPrimary #10132B` on `#FFFFFF` ≈ 17:1 ✅. Gold *text* on white must use `goldDark #9C7E1A` (≈ 4.6:1 ✅), never `gold #D4AF37` (≈ 2:1 ❌). |
| Font scale | Must survive Android font-scale up to 1.3× without overflow: `FittedBox(scaleDown)` on header + tabs, `maxLines` + `ellipsis` on every `Text`, horizontal scroll on tables, `SingleChildScrollView` on detail screens. Never hard-clip. |
| Hindi | Devanagari glyphs are taller — test every Hindi string at 1.3× scale. Hindi toggle must switch ALL labels. |
| Semantics | Every `IconButton` has `tooltip` / `semanticLabel`. LIVE pill has `semanticsLabel: 'Live'`. Images have `semanticLabel` (player name / team name). |
| Motion | Respect reduced-motion: one-shot animations only, no infinite pulse, no auto-playing carousel. Animations are decorative — content is readable with animations off. |
| Colour is not the only signal | LIVE = pill + dot + filter position + equation, not colour alone. Winner = gold + `✓` / position, not colour alone. Source = text label (`Real` / `Demo` / `Partial`), not colour alone. |
| Keyboard / TalkBack | All interactive elements focusable, in logical order (header → tabs → list → CTA). No tap target that is only a `GestureDetector` without semantics. |

---

## 11. Component checklist (before shipping)

Use this as the acceptance gate for every screen:

- [ ] Colours: only tokens from §1. No hard-coded hex outside `AppTheme`. No `amber` used as brand gold, no `red` used as live.
- [ ] Typography: only sizes from §2.2. No invented sizes. Scores w900, labels w700+.
- [ ] Spacing: only grid from §3.1. Radius only from §3.2. Shadows only from §3.3. Borders only from §3.4.
- [ ] Cards: default `16` / hero `20`, one hero per screen, one CTA per card, status pill = filter truth.
- [ ] Buttons: one primary per screen, 48 min height, black-on-gold, disabled state defined.
- [ ] Chips/pills/tabs: `GoldChip` for status/format, `LivePill` for live only, custom `_FilterTabs` (never `SegmentedButton` for Home), tabs never wrap.
- [ ] Tables: fixed columns (§7), horizontal scroll + hint, numbered FOW, highlighted not-out, honest `Table not available`.
- [ ] Icons: 13/20/24/28 sizes, 48 hit area, tooltip/semantics on every tappable icon.
- [ ] Images: avatar ring + initials fallback, never broken-image icon, SportScore attribution where its data appears.
- [ ] Animations: one-shot 200–300 ms (700 ms hero), no `repeat`, no full-list rebuild animation, skeleton first-load only.
- [ ] Dark: default, passes §10 contrast. Light: spec only, not shipped until contrast audit passes.
- [ ] Accessibility: 48 hit area, contrast, font-scale 1.3×, Hindi parity, semantics, colour-is-not-only-signal.
- [ ] No fake chrome: no ad placeholder, no `Complete` on demo, no dev text, no `King…` truncation, no `Upcomin g` wrap, no comma-joined team names, no lowercase team names.
- [ ] Hindi: every string via `Strings.t`, toggle switches ALL labels.
- [ ] Source labels: every number carries Real / Demo / Partial + provider + dataset size where relevant.

---

## 12. Token → Code map (where each token lives)

| Token group | File |
|---|---|
| Colours, gradients, `premiumCard()`, `heroCard()`, `ThemeData.dark` | `lib/utils/app_theme.dart` |
| `KingGradientCard`, `LivePulseDot`, `LivePill`, `StatBar`, `PremiumSectionHeader`, `KingAvatar`, `GoldChip`, `ScoreHeaderCell`, `ScoreRow`, `AnimatedScore`, `GoldDonut` | `lib/widgets/premium_widgets.dart` |
| `KingMatchCard` (canonical match card) | `lib/widgets/match_card.dart` |
| `OverGraph` (partnership bars + FOW timeline) | `lib/widgets/over_graph.dart` |
| `PlayerCard`, `H2HCard`, `PredictionCard`, `StatCard`, `LanguageToggle` | `lib/widgets/*.dart` |
| Strings (EN/हिं) | `lib/utils/strings.dart` |
| AdMob ID (empty = render nothing) | `AppConstants.admobBannerAdUnitId` in `lib/utils/constants.dart` |
| Formats / leagues lists | `AppConstants.formats` / `leagues` in `lib/utils/constants.dart` |

> **Future work (not in this spec):** Custom font family (only if system font
> proves insufficient), light-mode implementation + contrast audit, motion
> tokens for page transitions, illustration system for empty states.
> None of these block the next build.

---

## Appendix: Quick reference — the 5 tokens to memorise

| What | Token |
|---|---|
| Background | `navy #0B1026` |
| Brand / primary | `gold #D4AF37` (bright: `goldLight #FFD700`) |
| Text | `textPrimary #F5F0E1` / `textSecondary #B8BDD4` |
| Card | Radius `16`, `cardGradient`, `borderGold`, `shadowCard`, padding `16` |
| LIVE | `liveRed #FF3B30` pill + dot + `LIVE` label — never anything else |

*End of Design System v1.*
