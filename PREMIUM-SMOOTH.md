# KingCric — How Reference Apps Became Premium + Smooth, and What KingCric Must Do

> **Purpose:** Answer the user's question — *"kaise yeh apps premium bane hai
> and kaise yeh apps ka look and app bahut smooth hai sab kuch"* — with
> research + a concrete KingCric design system + smoothness checklist.
> **No assets, code, text, images, or branding were copied** from Cricbuzz /
> CREX / CricketLineX / ESPNcricinfo / Cricmetric / Sofascore. All patterns
> below come from public sources (Play Store listings, public reviews,
> official sites, general design / Flutter best practice) and from reading
> KingCric's own current code. Where a reference-app detail could not be
> verified from public text, it is marked `[inferred]`.
>
> Companion docs: `REFERENCE-SPEC.md`, `REFERENCE-APPS-DEEP-DIVE.md`,
> `CRICKETLINEX-REFERENCE.md`, `REQUIREMENTS-MAPPING.md`, `API-SETUP.md`,
> `MULTI-API.md`, `CRICSHEET-DATA.md`.

---

## 0. One-line answer

Premium apps feel premium because they are **restrained, consistent, and
fast** — 2–3 colours, 1 font family, an 8-point spacing grid, one card
shape everywhere, one-shot 200–300 ms animations, and **cache-first data**
so the screen is never blank. Smoothness is not a trick: it is
**lazy lists + `const` widgets + cached images + skeleton states +
no duplicate network calls**. KingCric V3 felt "normal, simple, boring"
because it broke most of these: flat cards with no hierarchy, no images,
full-screen spinners, `ListView(children:)` everywhere, and no skeleton
states (see §5).

---

## 1. PREMIUM LOOK — how the reference apps do it

### 1.1 Colours: restraint over spectacle

| Rule | What the best apps do | KingCric rule |
|---|---|---|
| Max 3 colours | One dominant colour ≈60% of the screen, one accent, neutrals for the rest. Public design research: ~75% of successful apps use a limited palette; premium = restrained, not rainbow. | **Navy `#0B1026` = 60%** (background), **Gold `#D4AF37` = accent** (scores, LIVE pill, active tab, key numbers), **Neutrals** for everything else. Never introduce a 4th brand colour. |
| Dark mode first | CREX, CricketLineX, Cricbuzz all ship dark + light. Dark is the default for live-score apps (night matches, low glare, scores pop). | King dark is default. Light theme is a follow-up, not a blocker — but the dark theme must be *complete* (every screen, every dialog, every empty state). |
| Colour = meaning | Red = LIVE / urgent only. Green = win / positive only. Gold = King brand / hero numbers. Grey = secondary / muted. Never reuse red for a decorative element. | `liveRed #FF3B30` only for the LIVE pill + pulse. `green #2ECC71` only for wins / positive deltas. Gold only for hero scores, active states, crown. |
| Contrast | Premium = readable. Body text on navy must pass WCAG AA (≥4.5:1). Muted text is for captions only, never for scores. | `textPrimary #F5F0E1` on navy, `textSecondary #B8BDD4` for labels, `textMuted #8A90B0` for captions only. Scores are always `textPrimary` + bold, never muted. |
| Gradients: subtle | Reference apps use *subtle* gradients (dark-to-darker), not flashy rainbows. A gradient that shouts is cheap; a gradient that whispers is premium. | Existing `cardGradient` (navy → deeper navy) + `goldGradient` (gold → dark gold) are correct. Rule: gold gradient only on **hero** cards + primary buttons, never on every card. Normal cards use the navy gradient + 1px gold border at 35–45% alpha. |

**KingCric palette (locked — already in `app_theme.dart`, do not expand):**

| Token | Hex | Use |
|---|---|---|
| `navy` | `#0B1026` | Scaffold background |
| `navyDeep` | `#070B1D` | AppBar / deepest background |
| `navyCard` | `#151B38` | Card base |
| `navyCard2` | `#1D2450` | Card gradient top / chip bg |
| `gold` | `#D4AF37` | Accent, active, borders |
| `goldLight` | `#FFD700` | Hero highlights |
| `goldSoft` | `#FFE98A` | Subtle gold text on dark |
| `goldDark` | `#9C7E1A` | Gradient end, pressed state |
| `textPrimary` | `#F5F0E1` | Headings, scores |
| `textSecondary` | `#B8BDD4` | Labels, body |
| `textMuted` | `#8A90B0` | Captions, "Last updated" |
| `green` | `#2ECC71` | Win / positive |
| `red` / `liveRed` | `#E74C3C` / `#FF3B30` | Loss / LIVE only |
| `amber` | `#F39C12` | Warning / favourite star |
| `blue` | `#4DA3FF` | Links / info only |

### 1.2 Typography: one family, clear hierarchy

Premium apps use **one font family, 3–4 weights, a fixed scale**. Multiple
font families = cheap. KingCric uses the system font (Roboto on Android)
with weights — that is fine and is what Cricbuzz/CREX do. What matters is
**hierarchy + spacing**, not a fancy font.

| Role | Size | Weight | Line height | Use | KingCric token |
|---|---|---|---|---|---|
| Hero score | 28–32 | w900 | 1.15 | Live match hero score only | `headlineLarge` (add) |
| Screen title | 22 | w900 | 1.2 | `KingCric`, screen headings | `headlineSmall` |
| Card title | 20 | w900 | 1.2 | Match title, player name in header | `titleLarge` |
| Section title | 16 | w800 | 1.3 | "Scorecard", "Batting", section headers | `titleMedium` |
| Body | 14 | w400–w600 | 1.5 | Scores in rows, commentary | `bodyMedium` |
| Caption | 12 | w400 | 1.4 | Venue, "Last updated", labels | `bodySmall` |
| Micro | 11 | w400–w600 | 1.4 | Pills, chips, table headers | `labelSmall` |

Rules:
- **Never more than 2 sizes on one card** (title + caption). A card with
  4 font sizes looks cluttered.
- **Letter spacing:** +0.3 on titles (already in `appBarTheme`), 0 on body.
- **Line length:** body text ≤ 50–75 chars per line; tables use tabular
  numbers (right-aligned) so columns line up.
- **Numbers:** scores are always bold + one size larger than surrounding
  labels. The score is the hero, the label is the servant.
- **Hindi parity:** the EN/हिं toggle must switch **all** labels
  (CREX model: one app, toggle switches everything). A half-translated
  screen feels broken, not bilingual.

### 1.3 Cards: one shape everywhere

Reference apps (CREX, CricketLineX, Cricbuzz) use **one card shape** on
every screen. The brain learns the shape once, then reads content fast.

| Property | KingCric spec |
|---|---|
| Corner radius | **16** normal cards, **18–20** hero cards. Never 4, never 28. |
| Border | 1px, gold at 35–45% alpha on premium cards, `white12` on plain cards. |
| Shadow | **Two soft shadows**, never one harsh shadow: `black 45% / blur 18 / offset (0,8)` + `gold 8% / blur 24 / offset (0,2)`. Hero: `black 50% / blur 22 / offset (0,10)` + `gold 18% / blur 32 / offset (0,4)`. Already in `AppTheme.premiumCard()` / `heroCard()` — keep, do not invent a third shadow. |
| Padding | Card interior **14–16**. Section gap **12**. Screen margin **14**. |
| Spacing grid | **8-point grid**: 8 / 12 / 16 / 24. No 5, 7, 13, 17. Every gap must be one of these. |
| White space | Generous. A card with breathing room feels luxurious; a cramped card feels budget. If a screen feels crowded, **remove** an element — do not shrink padding. |
| Grouping | Related items grouped by proximity + a shared card, not by dividers everywhere. One card = one idea (one match, one innings, one player). |

**What made V3 feel boring:** flat cards with no hierarchy, same size for
everything, no hero card, no gold border discipline, no spacing rhythm.
Fix = hierarchy (hero > card > row) + one card shape + generous spacing,
not more colours.

### 1.4 Icons: one set, one size, one colour rule

- **One icon set** (Material icons in KingCric). Never mix Material +
  Cupertino + custom doodles on the same screen.
- **Sizes:** 24 nav, 20 in cards, 16 in chips/pills. Never random sizes.
- **Colour:** active = gold, inactive = `textSecondary`, LIVE = red.
  Icons are never rainbow.
- **Spacing:** icon + 8 gap + label. Icon buttons have 48×48 touch
  targets (accessibility + no mis-taps).
- **Bottom nav:** 5 items max (Home / Leagues / Compare / Stats /
  Favourites in KingCric). Active = gold + label, inactive = muted.
  The active tab must be obvious in <1 second.

### 1.5 Images: the single biggest premium gap in KingCric

Reference apps feel alive because they show **faces, logos, stadiums**.
KingCric V3 shows **initials in circles (VK, RS)** — that alone makes it
feel like a wireframe, not a product.

| Image type | Reference pattern | KingCric plan |
|---|---|---|
| Player photo | Circle avatar, photo if available, initials fallback. Cached. | **Phase 1 (now):** gold-ring `KingAvatar` with initials (already exists) + consistent placeholder. **Phase 2:** TheSportsDB player thumbs (free, `thesportsdb_provider`) + `cached_network_image` with disk cache. Never show a broken-image icon — initials fallback always. |
| Team logo / flag | Small logo left of team name, 24–32px. | TheSportsDB team badges where available; otherwise gold crown / initials. Cache aggressively. |
| Stadium / venue | Venue card with photo or gradient + name. | Gradient + venue name + city for now; photo later via TheSportsDB venue data. Never a grey empty box. |
| Placeholder | Shimmer / skeleton in the *shape* of the final content, not a spinner. | See §2.4. |

**Image rules (non-negotiable):**
1. Every image has a **placeholder** (initials / skeleton) — never a blank
   hole, never a broken-image icon.
2. Every image is **cached** (disk cache, sized to display size —
   `memCacheWidth` = display width × devicePixelRatio; a 2000px photo in a
   48px avatar is a performance crime).
3. Images load **lazily** (only visible rows) and **never block** the
   text — text renders first, images fade in (200 ms fade, one-shot).
4. No image may cause a **layout shift** — reserve the exact box size
   upfront (fixed width/height or `AspectRatio`).

> **Note on `cached_network_image`:** it was removed from `pubspec.yaml`
> in the startup-crash fix because it was unused and pulled in
> `flutter_cache_manager → sqflite → jni`. It may be re-added **only**
> with a real `flutter build apk` (Gradle bundles `libdartjni.so`) —
> never with the old manual pipeline. Until then, use `Image.network`
> with `cacheWidth` + a local in-memory cache, or bundled assets.

### 1.6 Animations: purposeful, one-shot, 200–300 ms

Premium apps animate **one thing at a time, once**. Janky apps animate
everything, forever.

| Animation | Spec | KingCric status |
|---|---|---|
| Screen transition | 250 ms fade + slight slide (8px). One-shot. | Use `MaterialPageRoute` default + `Hero` for player avatar → profile. |
| Score update | Number counts / fades (200 ms) when it changes, no full-card rebuild. | `AnimatedScore` (TweenAnimationBuilder) already exists — use it for hero scores only. |
| LIVE pulse | One soft pulse, **one-shot** (not infinite `repeat`). Infinite animations never settle, break `pumpAndSettle` tests, and drain battery. | `LivePulseDot` was fixed to one-shot in V2 — **keep one-shot, never reintroduce `repeat`**. |
| Tab / filter change | 200 ms cross-fade of list content, no jump. | `AnimatedSwitcher` on the list, not a full-screen rebuild. |
| Pull-to-refresh | Native spinner, 300 ms min display (avoids flash). | `RefreshIndicator` on Home / Match Detail / Player. |
| Skeleton loading | Shimmer in the shape of the card, 800 ms cycle, stops when data arrives. | **Missing in V3 — add** (see §2.4). |
| Haptics | Light tap on favourite star / tab (Android `HapticFeedback.lightImpact`), never on every scroll. | Add only to favourite + tab taps. |
| **Never** | Infinite spinners, bouncing logos, rotating crowns, auto-playing carousels, parallax everywhere. | Banned. If it loops forever, it is not premium. |

**Animation budget:** at most **one** animation running at a time per
screen. If two animations overlap, remove one.

### 1.7 What makes an app feel *boring* vs *premium* (KingCric V3 diagnosis)

| Boring (V3) | Premium (target) |
|---|---|
| All cards same size, same weight | Hero card (match) > section card > row |
| All text same size | 28 hero score, 16 section, 12 caption |
| No images, initials only | Photos / logos with initials fallback |
| Full-screen spinner on every load | Skeleton card + cached data instantly |
| No spacing rhythm (random 5/7/13 gaps) | 8-point grid, generous white space |
| Gold everywhere (every border gold) | Gold only on hero + active + key numbers |
| No feedback on tap | 200 ms fade + light haptic on favourite/tab |
| Infinite pulse | One-shot pulse, then still |
| "Ad placeholder" box | No fake chrome — nothing renders without a real ID |

### 1.8 Premium checklist (before shipping any screen)

- [ ] 2–3 colours only, gold used sparingly, red only for LIVE.
- [ ] One font family, ≤3 weights, fixed scale (§1.2).
- [ ] One card shape (16 / 18–20 radius), two soft shadows, 8-point grid.
- [ ] Icons one set, 24/20/16 sizes, gold/active + muted/inactive.
- [ ] Every image has placeholder + cache + fixed box (no layout shift).
- [ ] Animations one-shot, 200–300 ms, ≤1 at a time, no infinite loops.
- [ ] No fake chrome (no ad placeholder, no "Complete" on demo data).
- [ ] 2-second rule: a new user answers "what's live? what's the score?
      what do I tap?" in ≤2 s.
- [ ] Hindi toggle switches **all** labels on the screen.
- [ ] Screen looks complete at 360 dp width (smallest common phone).

---

## 2. SMOOTHNESS — how reference apps achieve 60 fps

Smoothness is **not** about a faster phone. It is about doing less work
on the UI thread, showing cache first, and never rebuilding what did not
change. The reference apps (CREX, CricketLineX, Cricbuzz) all do the
same five things; KingCric must do the same.

### 2.1 Lists: lazy, keyed, `const`, bounded

**Current KingCric gap (verified from code):** every screen uses
`ListView(children:)` / plain `ListView(...)` — that builds **all**
children upfront, even off-screen ones. For a 100-row scorecard / stats
list, that is the #1 jank source.

| Rule | Why | KingCric action |
|---|---|---|
| `ListView.builder` (never `ListView(children:)`) for >12 items | Builds only visible rows; constant memory. 10–50× faster for long lists. | Migrate all 11 `ListView(` call sites (home, match_detail ×4, player_profile, stats, leagues, favourites, compare) to `ListView.builder` / `SliverList`. |
| `itemExtent` / `prototypeItem` for fixed-height rows | Skips measurement; ~30% scroll improvement. | Set `itemExtent` where rows are uniform (match cards, stat rows). |
| `ValueKey(item.id)` on every row | Stable identity → Flutter preserves state, no full rebuild on reorder / refresh. | Every row gets `key: ValueKey(match.id)` / `ValueKey(player.id)`. |
| `const` widgets in `itemBuilder` | `const` subtrees are never rebuilt. | Make every static child `const` (labels, dividers, icons). Run `flutter analyze` with `prefer_const_constructors` — zero warnings. |
| `cacheExtent: 250–1000` | Pre-builds off-screen rows, removes scroll jank. | Set `cacheExtent: 500` on Home + Match Detail lists. |
| `CustomScrollView` + Slivers for multi-section screens | One scrollable, coordinated headers, no nested `ListView` in `SingleChildScrollView`. | Match Detail + Player Profile → `CustomScrollView` with `SliverList` sections. |
| **Never** nested scrollables | Inner `ListView` inside outer scroll = constraint hell + jank. | If a section must not scroll, use `Column` + `shrinkWrap: false` via Slivers, never `ListView(shrinkWrap: true)` inside a scroll. |
| Flatten widget trees | Deep nesting (10+ levels) costs layout time on every frame. | Extract row widgets to standalone `StatelessWidget`s with `const` constructors. |

### 2.2 State: cache-first, background refresh, no flicker

This is the **#1 smoothness trick** of every reference app: the screen
is never blank, and refresh never flashes.

```
User opens Home
  → Show CACHED matches instantly (0 ms, from last fetch / mock)
  → Fetch fresh in background (10-min TTL, deduped)
  → If fresh differs: update ONLY changed rows (keys), no full rebuild
  → Show "Last updated HH:MM" + small refresh indicator at top
  → If fetch fails: keep cache + show "Couldn't refresh — showing last update" + Retry button
  → NEVER: full-screen spinner, blank screen, or clearing the list on refresh
```

| Rule | KingCric action |
|---|---|
| Cache-first (stale-while-revalidate) | `ApiService.fetchMatches` returns cache immediately, refreshes in background, notifies listeners. (API-SMOOTH worker owns this — this doc is the spec.) |
| Deduplication | In-flight request map: same key = same `Future`. Two screens asking for the same match share one call. No quota burn, no double spinner. |
| Localised state | Only the changed row rebuilds. Never wrap the whole `ListView` in a global `setState` / `Consumer`. Use `ValueKey` + per-row widgets. |
| Debounced search | Search input waits 300 ms after last keystroke before filtering / fetching. Typing must never trigger a fetch per keystroke. |
| Throttled polling | Live 10 min, Upcoming/Series 60 min, Completed never re-fetch (see `API-SETUP.md` quota budget). Polling faster than the quota = app goes dark + quota error = not smooth. |
| Background refresh | On app resume, refresh **only live matches**, not everything. |
| Offline fallback | No network → cached data + honest "Offline — showing last update". Never a crash, never a blank screen. |

### 2.3 Network: less, smaller, deduped

- **Pagination:** never fetch 1000 matches at once. `currentMatches` is
  already small; for series / stats, page at 20–50 items.
- **Compression:** `http` sends `Accept-Encoding: gzip` by default —
  keep it. Never fetch full-resolution images for list thumbnails.
- **Prefetch (careful):** prefetch the *next* screen only when the user
  is likely to tap it (e.g., prefetch the top live match's scorecard when
  Home loads) — and only within quota. Never prefetch everything.
- **Timeouts:** every request has a timeout (10 s). A hung request must
  never hang the UI — it fails to cache + retry.
- **Parsing off the UI thread:** Cricsheet JSON parsing (149 KB sample,
  larger for `all_json.zip`) must run in an `Isolate` / `compute()`.
  Parsing 1000s of deliveries on the UI thread = dropped frames.
  (Cricsheet worker: parse in isolate, cache the computed `Player` map.)

### 2.4 Loading states: skeleton, not spinner

**Current KingCric gap (verified):** 9× `CircularProgressIndicator`
full-screen centres (home, match_detail ×2, leagues, stats,
favourites ×2, compare). That is the single most "boring / cheap"
signal in the app. Reference apps use **skeletons**.

| State | What to show |
|---|---|
| First load, no cache | **Skeleton cards** in the exact shape of the real cards (grey rounded boxes, shimmer 800 ms cycle). 3 skeleton match cards on Home, skeleton scorecard rows on Match Detail. |
| Refresh with cache | Keep old data + small linear indicator at top (or pull-to-refresh spinner). Never clear the list. |
| Empty (truly no data) | Honest empty state: icon + one line ("No live matches right now") + Refresh button. Never a spinner forever. |
| Error | Keep cache (if any) + inline banner ("Couldn't refresh — showing last update HH:MM") + Retry. Never a full-screen error that hides good data. |

Skeleton spec: `Container` with `BoxDecoration` (navyCard2, radius 16)
+ `Shimmer`-style opacity pulse (one-shot per skeleton, 800 ms cycle,
stop on data). No new dependency needed — a simple
`TweenAnimationBuilder` opacity pulse is enough.

### 2.5 Flutter-specific performance rules

- **`const` everywhere:** every widget that can be `const` must be.
- **`RepaintBoundary`:** wrap the hero score card + over-graph in
  `RepaintBoundary` so a score change repaints only that card, not the
  whole screen.
- **No work in `build()`:** never parse JSON, sort 1000 items, or compute
  stats inside `build()`. Compute once (in service / `initState` /
  `FutureBuilder`), cache the result.
- **`FutureBuilder` futures:** create the `Future` once in `initState`,
  never in `build()` (recreating a `Future` in `build()` refetches on
  every rebuild — quota burn + flicker). This was a V1 code-review finding
  — verify it is fixed on every screen.
- **Image sizing:** `cacheWidth` / `memCacheWidth` = display size ×
  devicePixelRatio. Never decode a 2000px image for a 48px avatar.
- **Avoid `Opacity` + `Clip` in lists:** expensive. Use pre-baked
  colours with alpha instead of `Opacity` wrappers.
- **Impeller:** Flutter 3.47 uses Impeller by default — do not disable
  it. Profile in **profile / release** mode only; debug-mode jank is
  not real jank.
- **Profile before optimising:** use Flutter DevTools (Performance +
  Widget rebuilds) to find real bottlenecks. Do not guess.

### 2.6 Smoothness checklist (before shipping any screen)

- [ ] Lists use `ListView.builder` / `SliverList` + `ValueKey` + `const`.
- [ ] `itemExtent` set for uniform rows, `cacheExtent` 250–1000.
- [ ] No nested scrollables, no `ListView(shrinkWrap: true)` in a scroll.
- [ ] Cache-first: screen shows cached data in <100 ms, refreshes in background.
- [ ] No full-screen spinner when cache exists; skeleton only on first load.
- [ ] Deduplication: same request = same `Future`, no double fetch.
- [ ] Search debounced 300 ms; polling throttled per quota.
- [ ] Heavy parsing (Cricsheet) in isolate, not on UI thread.
- [ ] `Future` created in `initState`, never in `build()`.
- [ ] No work in `build()` (no parse / sort / compute).
- [ ] Images cached + sized + placeholder + fixed box (no layout shift).
- [ ] Animations one-shot, 200–300 ms, ≤1 at a time.
- [ ] Profile-mode DevTools shows no jank on scroll (60 fps).
- [ ] Offline → cached data + honest banner, never blank / crash.

---

## 3. KingCric design system — locked tokens (for `app_theme.dart`)

```dart
// Colours — locked, do not expand (see §1.1 table).
navy #0B1026, navyDeep #070B1D, navyCard #151B38, navyCard2 #1D2450,
gold #D4AF37, goldLight #FFD700, goldSoft #FFE98A, goldDark #9C7E1A,
textPrimary #F5F0E1, textSecondary #B8BDD4, textMuted #8A90B0,
green #2ECC71, red #E74C3C, liveRed #FF3B30, amber #F39C12, blue #4DA3FF.

// Typography — one family, fixed scale (see §1.2).
heroScore 28-32 w900 lh 1.15 | title 22 w900 lh 1.2 | cardTitle 20 w900 lh 1.2 |
section 16 w800 lh 1.3 | body 14 w400-600 lh 1.5 | caption 12 w400 lh 1.4 |
micro 11 w400-600 lh 1.4. Letter-spacing +0.3 on titles, 0 on body.

// Spacing — 8-point grid only: 8 / 12 / 16 / 24.
// Screen margin 14, card padding 14-16, section gap 12, row gap 8.

// Cards — radius 16 normal / 18-20 hero; border 1px gold 35-45% alpha
// (hero 1.4px / 60%); shadows: black 45% blur 18 offset (0,8) +
// gold 8% blur 24 offset (0,2); hero: black 50% blur 22 offset (0,10) +
// gold 18% blur 32 offset (0,4). Already in premiumCard()/heroCard().

// Icons — 24 nav / 20 card / 16 chip. Active gold, inactive muted,
// LIVE red. 48x48 touch targets.

// Animations — one-shot, 200-300 ms, <=1 at a time, no infinite loops.
// Screen 250 ms fade+slide 8px. Score 200 ms count/fade. Pulse one-shot.
// Skeleton 800 ms shimmer, stops on data. Haptics light on favourite/tab only.
```

---

## 4. KingCric implementation plan (what to change, in order)

> These are **spec** changes for the feature teams (Home/Live, Match
> Detail, Player/Compare, Stats/Leagues/Favourites, Data/API, QA). Do not
> implement them in this doc — implement them in code, one team at a time,
> with `flutter analyze` + `flutter test` + `flutter build web` green
> after each step.

### P1 — Stop the bleeding (boring + jank)
1. Replace all 9 full-screen `CircularProgressIndicator` centres with
   **skeleton cards** (first load) / keep-cache + top indicator (refresh).
2. Migrate all `ListView(children:)` → `ListView.builder` + `ValueKey` +
   `const` + `itemExtent` where uniform + `cacheExtent: 500`.
3. Fix `FutureBuilder` futures: create once in `initState`, never in
   `build()`.
4. Keep `LivePulseDot` one-shot. Remove any `repeat` animation.

### P2 — Premium look (hierarchy + images + spacing)
5. Enforce §1.2 typography scale on every screen (hero 28–32, section
   16, body 14, caption 12). No screen may use >2 sizes per card.
6. Enforce 8-point grid: audit every `EdgeInsets` / `SizedBox` — must be
   8 / 12 / 16 / 24 (screen margin 14 is the one exception).
7. Enforce one card shape: radius 16 / hero 18–20, two soft shadows,
   gold border only on hero + active.
8. Player avatars: gold-ring `KingAvatar` + initials now; TheSportsDB
   thumbs + disk cache in Phase 2 (with `libdartjni.so` caveat — see
   §1.5). Team badges same pattern. Fixed box, no layout shift.

### P3 — Smoothness (cache-first + isolate + dedup)
9. Cache-first on every screen (API-SMOOTH worker owns the service
   layer): show cache instantly, background refresh, changed-rows-only
   update, "Last updated HH:MM" line.
10. Cricsheet parsing in `Isolate` / `compute()`, result cached.
11. Deduplication: in-flight request map, same key = same `Future`.
12. Debounced search (300 ms), throttled polling per quota, background
    refresh only for live matches.

### P4 — Verify (prove it, don't claim it)
13. `flutter analyze` → zero issues. `flutter test` → all pass.
14. Profile-mode DevTools: scroll Home + Match Detail + Player Profile,
    confirm 60 fps, no jank, no full rebuilds on score update.
15. 360 dp width check: no truncation, no overflow, on every screen.
16. 20-point checklist from `REFERENCE-SPEC.md` §8 + §1.8 + §2.6 above —
    all must pass before the next APK.

---

## 5. KingCric V3 gaps (verified from current code)

| Gap | Evidence | Fix (§) |
|---|---|---|
| Full-screen spinners everywhere | 9× `CircularProgressIndicator` centres | §2.4 skeleton |
| Non-lazy lists | 11× `ListView(` (not `.builder`), no `itemExtent`, no `ValueKey` | §2.1 |
| No images | `KingAvatar` initials only, no `Image.network`, no cache | §1.5 |
| No skeleton | Zero skeleton/shimmer widgets | §2.4 |
| Animation risk | `LivePulseDot` was infinite `repeat` in V2 (fixed to one-shot) — must stay fixed | §1.6 |
| Possible `Future` in `build()` | V1 code-review finding — re-verify on every screen | §2.5 |
| Heavy parsing on UI thread | Cricsheet parser runs synchronously (sample is small now, `all_json.zip` will not be) | §2.3 isolate |
| Typography drift | `app_theme.dart` defines a scale, but screens use ad-hoc sizes | §1.2 + P2 |
| Spacing drift | Ad-hoc `EdgeInsets` / `SizedBox` values across screens | §1.3 8-point grid |

---

## 6. Sources (public, no copied assets/code)

- Premium-look research: `weareaffective.com` (what makes an app feel
  premium), `medium.com/@Ivaacan` (why some apps instantly feel premium),
  `moldstud.com` (visual consistency, typography + colour), `designity.com`
  (visual hierarchy), `audiorista.com` (style guide), `fastercapital.com`
  (visual design principles) — via `browser.search`, 2026-10-18.
- Flutter smoothness: `copyprogramming.com` Flutter ListView guides
  (builder vs children, `itemExtent`, `cacheExtent`, `const`, `ValueKey`,
  `SliverList`, image caching, Impeller) — via `browser.search`.
- Reference-app behaviour: CREX Play Store listing (instant ball-by-ball,
  detailed scorecards, graphs, PIN live score, light/dark, EN/Hindi/Bengali,
  premium ad-free) — via `browser.search`.
- KingCric current code: `lib/utils/app_theme.dart`,
  `lib/widgets/premium_widgets.dart`, `lib/screens/*.dart`,
  `pubspec.yaml` — read directly, 2026-10-18.
- No MOD APK, no decompile, no scraped private API, no copied asset.
