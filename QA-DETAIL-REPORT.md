# KingCric — QA Detail Report (TEAM 6/6, READ-ONLY audit)

**Scope:** Every smallest detail — every text, spacing, label, filter, truncation — per user instruction: "ek ek choti se choti chize dekh ke samaj ke banana" + "meko each and every thing sahi se chahiye".
**Method:** Read-only code audit of all 7 screens + 9 widgets + models + providers + strings/constants. No code edited. No on-device run (no emulator in VM); findings are from code inspection + `flutter analyze` + `flutter test`.
**Snapshot caveat (IMPORTANT):** Parallel teams were editing the same tree DURING this audit (20+ files modified, uncommitted). Findings below are from the snapshot I read. Two `flutter test` runs completed earlier at 26/26 passed; later test invocations were aborted by a service restart / concurrent edits — **do NOT treat the later aborted runs as a pass.** `flutter analyze` at snapshot time: **FAILS with 3 errors** (see §0). Nothing in this report may be read as "ready to ship" until §0 errors are fixed and analyze + tests are re-run on a frozen tree.

---

## §0 — BLOCKERS (must fix before ANY build/push)

| # | Issue | Evidence | Owner |
|---|-------|----------|-------|
| B1 | `flutter analyze` ERROR: `lastMatchesUpdated` already defined (duplicate definition) | `lib/services/api_service.dart:114` | API / smooth-update team |
| B2 | `flutter analyze` ERROR ×2: `addMatchesListener` invoked on nullable receiver in `smooth_update.dart:96` (missing `?.` / null check) | `lib/services/smooth_update.dart:96` | API / smooth-update team |
| B3 | Tree is mid-edit by parallel teams: `favourites_screen.dart` has unused imports + unused fields (`_playersFuture`, `_matchesFuture`, `_eventHints`, `_reload`), `api_service.dart` has unused `_inFlightMatches` / `_notifyMatchesListeners`, test file has unused import. These are warnings, but they prove the tree was not frozen when audited. | `flutter analyze` output | All teams — freeze + clean before build |

**Verdict on §0:** FAIL. No APK may be built from this snapshot.

## §1 — Text: truncation / wrapping / overflow

| Check | Result | Notes |
|-------|--------|-------|
| Header shows full "KingCric" | ✅ PASS | `home_screen.dart`: title in `FittedBox(scaleDown)`, 22px w900; `LanguageToggle` compacted (no duplicate crown). V3 "King..." bug fixed. |
| Filter tabs never wrap ("Upcomin g") | ✅ PASS | Custom `_FilterTabs`: 3 `Expanded` buttons, each label single-line `FittedBox(scaleDown)`, `softWrap: false`. |
| Match title cut mid-word | ✅ PASS (card + detail) | `KingMatchCard` title `maxLines: 2` + ellipsis; detail title `maxLines: 2`. |
| Scorecard title (`match_detail` header) | ⚠️ MINOR | Header title uses `maxLines: 1` (not 2) — very long "Team A vs Team B" + league/venue line below is `maxLines: 2`. Acceptable, but inconsistent with the 2-line rule elsewhere. |
| Long team names in score rows | ✅ PASS | One team per row, `Expanded` + `maxLines: 1` + ellipsis; score right-aligned, fixed width. |
| Long player names (scorecard / profile / compare) | ✅ PASS | All use `maxLines: 1–2` + ellipsis; compare `_head` `maxLines: 2`. |
| Compare dropdown long names | ⚠️ MINOR | `DropdownMenuItem` child `Text(p.name)` has NO `maxLines`/ellipsis — a very long name can overflow the dropdown. Add ellipsis. |
| `MatchCard` "Last: …" line | ⚠️ MINOR | `Text('Last: ${m.lastBall}')` has NO `maxLines`/overflow. `lastBall` is currently a 1-char mock value, but a real provider string could be long. Add `maxLines: 1` + ellipsis. |
| MatchDetail "Last ball" chip | ⚠️ MINOR | Chip `Text(_match.lastBall)` has no `maxLines`. Same fix as above. |
| Favourites `ListTile` titles | ⚠️ MINOR | Team/player `ListTile.title` has no explicit `maxLines` — ListTile handles it, but long team names were not verified at 360dp. Verify on device. |
| Stats `ListTile` subtitle (team) | ✅ PASS (minor) | `subtitle: Text(team)` — short values; acceptable. |
| Hindi labels | ⚠️ PARTIAL — see §6 | Many labels still hardcoded English (see §6). |

## §2 — Filters: Live / Upcoming / Finished

| Check | Result | Notes |
|-------|--------|-------|
| Live / Upcoming / Finished mutually exclusive | ✅ PASS (logic) | Home `_visible`: live = `isEffectivelyLive`; upcoming = `status == upcoming && !isEffectivelyLive`; finished = `isCompleted`. A match lands in exactly one bucket. |
| Live match never under Upcoming | ✅ PASS (logic) | `isEffectivelyLive`: `status == live` OR (`status == upcoming` + scores on board + no "won by" result). Austria W case (scores + "need 88…") now resolves live at parse (`resolveStatus` checks `need / require / to win / …`) AND at filter. |
| Status pill = filter (same truth) | ✅ PASS | `KingMatchCard` pill derives from `isEffectivelyLive` + `isCompleted` — same getters the filter uses. Detail Live tab uses the same. |
| "No matches" when matches exist | ✅ PASS (logic) | Empty state only when `_visible.isEmpty` after filter+search+format. Correct. |
| Empty state doesn't distinguish load failure | ⚠️ MINOR | If the API fails, `_matches` stays `[]` and the user sees "No matches in this section" — indistinguishable from "genuinely no matches". Add a load-failure message / retry. |
| Finished filter: provider mislabels completed as upcoming | ⚠️ EDGE | If a provider returned `status = upcoming` + `result = "X won by …"` WITHOUT going through `resolveStatus`, the match would land in Upcoming (upcoming filter checks raw `status`, finished checks raw `isCompleted`). All current providers route through `resolveStatus` (which maps "won by" → completed), so this is defence-in-depth only: consider an `isEffectivelyCompleted` getter mirroring `isEffectivelyLive`. |
| Leagues ordering (Live → Upcoming → Finished) | ✅ PASS | `_matchOrder`: live 0, upcoming 1, finished 2; upcoming by start ascending. |
| Leagues points table labelled partial | ✅ PASS | Header subtitle: "From loaded matches in this league — partial, not the official table". Honest. |
| Leagues points table: NRR column missing | ⚠️ GAP vs spec | Spec wants P/W/L/PTS/NRR. Table shows P/W/L/PTS only. NRR cannot be computed from free data reliably — either add NRR when computable or document why it is omitted. Do NOT invent NRR. |

## §3 — Team names

| Check | Result | Notes |
|-------|--------|-------|
| Title Case everywhere | ✅ PASS | `titleCaseTeam` applied in ALL 5 providers (CricAPI, EliteSport, EntitySport, SportScore, TheSportsDB) + `cleanTeamName` for innings labels. "bulgaria women" → "Bulgaria Women". Abbreviations ≤4 ALL-CAPS (MI, CSK, IPL, USA) preserved. |
| One team per line, no comma-join | ✅ PASS | `cleanTeamName`: known-team match → last-mentioned team; else strip "Inning N" suffix, take segment after last comma, title-case. "Bulgaria Women,Sweden Women Inning 2" → "Sweden Women". |
| No "Inning N" in displayed team name | ✅ PASS | Suffix stripped in `cleanTeamName`; no `Inning` string appears in any displayed team-name widget (grep: `Inning` only in model field names + venue model). |
| No lowercase team names | ✅ PASS | All provider paths title-case. Mock data uses Title Case. |
| Residual risk: comma-joined `teams[]` list itself | ⚠️ EDGE | CricAPI `_matchFromFreeApi` takes `teams[0]` / `teams[1]` and title-cases them. If a provider ever returned a single comma-joined entry in `teams[]` (not the `inning` label), title-case alone would NOT split it. No evidence this happens; note as a watch item, not a bug. |

## §4 — Scorecard completeness

| Check | Result | Notes |
|-------|--------|-------|
| Batting columns (R/B/4s/6s/SR) | ✅ PASS | Fixed 720px table + horizontal scroll + "swipe" hint. Dismissal line under name (2 lines), not-out `*` + highlight row. TOTAL row with runs + wkts. |
| Bowling columns (O/M/R/W/Econ/Wd/Nb) | ⚠️ BUG — overs display | Header is correct, but `match_detail_screen.dart:701` renders bowling overs with `toStringAsFixed(0)` — **3.2 overs displays as "3"**, losing the balls. Innings overs elsewhere use `toStringAsFixed(1)` correctly. Fix: render cricket overs as `toStringAsFixed(1)` (7.2 = 7 ov + 2 balls), never `toStringAsFixed(0)`. |
| Bowling economy fallback | ⚠️ MINOR (math) | `cricapi_provider.dart`: fallback `runs / overs` when `eco` missing treats cricket overs (7.2) as decimal (7.2 → 11.9 instead of true 11.4 for 38 runs). Convert overs → balls first (whole*6 + balls) when computing economy. Only matters when provider omits `eco`. |
| Extras | ✅ PASS | `Extras: Wd 3, Nb 1, B 1 (5)` + `Total` chip. Falls back to `Extras: N` when no breakdown. |
| Fall of Wickets numbered | ✅ PASS | Numbered circles 1..N, `1-52 (Rohit Sharma, 6.1 ov)` format. OverGraph FOW regex parses this format correctly (`score @ over`). |
| Partnerships | ✅ PASS | Full strings shown; OverGraph parses `— N` runs for bars. "5*" (not-out) parses as 5. |
| Yet-to-bat | ✅ PASS | Chips; hidden (`SizedBox.shrink`) when empty. |
| Commentary empty state | ✅ PASS | "No commentary available." / Hindi equivalent. |
| Scorecard empty state | ✅ PASS | "Scorecard not available yet." / Hindi. |
| Over-by-over graph honesty | ✅ PASS | Draws ONLY partnership bars + FOW timeline + run rate from real scorecard data; never invents per-over runs; unparseable entries skipped. Good. |
| Equation (need X from Y) | ✅ PASS | Computed from structured totals/overs with proper cricket-overs→balls conversion (whole*6 + balls). Test matches handled ("no ball limit"). |

## §5 — Source labels / honesty

| Check | Result | Notes |
|-------|--------|-------|
| No fake "Complete" on demo/curated data | ✅ PASS | All 6 mock players `dataComplete: false` + `source: 'demo'`. `PlayerCard` labels by source: Cricsheet → "Real • Cricsheet" (green ✓), demo → "Demo", else "Partial". No UI string renders the word "Complete" to the user (grep: only `dataComplete` field + `lang.t('data_complete')` — see next row). |
| "Data complete" string still exists | ⚠️ MINOR | `strings.dart` still defines `data_complete: "Data complete"` and `player_profile_screen.dart` uses it when `dataComplete == true` AND `source` is neither cricsheet nor demo. Only reachable for a non-demo, non-Cricsheet provider profile with `dataComplete == true` — no current provider sets that. Verify no provider can set it spuriously; otherwise remove the string. |
| Cricsheet profile label duplication | ⚠️ MINOR | Profile shows TWO adjacent rows for Cricsheet: generic source row ("Real • Cricsheet open data") + scope row ("Real • Cricsheet open data • N matches in dataset"). Redundant — merge into one row. |
| Ad placeholder | ✅ PASS (default) | `AdPlaceholder` returns `SizedBox.shrink()` when `hasAds == false` (default). No fake ad box in release. |
| Ad placeholder if AdMob ID IS set | ⚠️ MINOR | If `ADMOB_BANNER_UNIT_ID` is ever set, `AdPlaceholder` renders the dev text "Ad placeholder — AdMob unit id not set yet" — which would then be FALSE (an ID IS set) and still not a real ad. When an ID is set, render a real `AdMob` banner or nothing — never the placeholder text. (The `ad_placeholder` string in `strings.dart` is otherwise dead.) |
| Prediction disclaimer | ✅ PASS | "For information & entertainment only. Not betting advice. Prediction is a model, not a guarantee." on Prediction tab. |
| Prediction NaN / out-of-range | ✅ PASS | Score clamped 0–100, NaN → 0; StatBar fractions clamped; donut fraction clamped. |
| Compare source line | ✅ PASS | "Source — A: … • B: …" with Real • Cricsheet / Demo / Partial per player. |
| SportScore attribution | ⚠️ UNVERIFIED | Constants declare `sportScoreAttribution = 'Powered by SportScore'` and docs require it wherever SportScore data renders. Grep found NO UI widget rendering this attribution. If SportScore is the answering source for a match, the attribution must appear. Either render it (when `lastSource == SportScore`) or confirm SportScore never answers alone. |
| "Last updated HH:MM" + Refresh | ✅ PASS | Home shows last-updated time + Refresh button. |
| Weather row honesty | ✅ PASS | Shows "Not available from free providers yet." — honest, not invented. |

## §6 — Language toggle (Hindi ⇄ English, rule P11: toggle switches ALL labels)

| Check | Result |
|-------|--------|
| Toggle itself | ✅ PASS — compact EN / हिं chips, works via `LanguageProvider`. |
| Strings via `lang.t` | ⚠️ PARTIAL — FAIL on full coverage. Large parts of the UI are hardcoded English and do NOT switch: Compare screen ("Player Compare", "VS", "Select player", "Batting", "Bowling", "Source — A: …"), Leagues ("Leagues", "Points Table" header subtitle, "Table not available…", "No league player data…", "Top Players"), Stats ("Stats & Rankings", section titles "Most Runs", "Best Average (min 10 innings)", …), Favourites ("Favourites", "Match notifications", "Notify me about", "Favourite Teams — tap ⭐…", "Favourite Players — tap ⭐…", event names Wickets/Sixes/Match start/Milestones), Match Detail ("Batting:", "Bowling:", "Last ball:", "Umpires:", "Full card — tap a batter for profile", "Swipe table sideways…", "Squad data will appear…", "Who will fire? — King Prediction", "Target & Equation", "Commentary", "Fall of Wickets", "Partnerships", "Yet to Bat"), MatchCard ("Tap for FULL scorecard", "Scorecard →", "Starts: …", "Batting:", "Bowling:", "Last:"), PlayerCard ("runs", "Avg … • SR …"), H2H ("Head to Head", "wins"), PredictionCard ("Recent Form", "vs Opponent", "Venue"), OverGraph ("Partnership runs", "Fall of wickets", "No wickets fallen yet.", "Partnership data not available."), Profile ("Overall — All Formats", "Leagues", "Dismissal History", "Bowling — Full Table", "All Formats — Full Table", "Recent Form" via lang.t ✅ for some). |
| Impact | Hindi toggle currently switches only the header, tabs, search hint, demo banner, a few section titles and prediction verdicts. A Hindi user still sees ~70% English labels. This violates the user's "Hindi + English both" requirement and reference rule P11. |
| Action for other teams | Move every user-facing string above into `strings.dart` with `en` + `hi` entries and use `lang.t(...)`. Do NOT ship "Hindi support" as complete until this is done. |

## §7 — Buttons / taps / navigation (rule P12: every player name tappable, no dead taps)

| Check | Result | Notes |
|-------|--------|-------|
| Match card tap → detail | ✅ PASS | `KingMatchCard.onTap` → `MatchDetailScreen`. |
| Scorecard batter/bowler tap → profile | ✅ PASS | `InkWell` + `_openPlayerByName`; missing profile → SnackBar "Profile not available for X yet" (never a silent dead tap). |
| Squad player tap → profile (with context) | ✅ PASS | Passes opponent + venue + format for context-aware profile. |
| Matchup bowler tap → profile | ⚠️ MINOR | `_tappableRow` matches by exact name OR last-name `contains` — a shared surname (e.g. two "Sharma"s) can open the WRONG player's profile. Prefer exact match first, then show SnackBar if ambiguous instead of guessing. |
| Compare headers tap → profile | ✅ PASS | Both names tappable. |
| Leagues top-player row tap → profile | ✅ PASS | `ListTile.onTap`. |
| Stats row tap → profile | ✅ PASS | `ListTile.onTap`. |
| Favourites player tap → profile | ✅ PASS | `ListTile.onTap`. Star buttons toggle independently. |
| Bottom nav (5 tabs) | ✅ PASS | Home / Leagues / Compare / Stats / Favourites, fixed type, gold selected. |
| Home Trending Players tap → profile | ✅ PASS | `PlayerCard.onTap` → profile. |
| Compare dropdown stale value | ✅ PASS | `safeValue` only passes a value still in the list; re-validated after load. No "value not in items" crash. |
| Prediction tab: empty squad | ⚠️ MINOR | If `squad` is empty, Prediction tab renders an empty list + disclaimer only — no "no squad" message (Squad tab HAS one; Prediction tab does not). Add the same empty-state line. |
| Refresh button | ✅ PASS | Manual `_load` + `RefreshIndicator` pull-to-refresh. |

## §8 — Futures / quota / smoothness (reference-app smoothness: no flicker, no stale, no quota burn)

| Check | Result | Notes |
|-------|--------|-------|
| `MatchDetail` futures cached in `initState` | ✅ PASS | `_playersFuture` created once; comment documents why. |
| `Leagues` / `Stats` futures cached in `initState` | ✅ PASS | `_matchesFuture` / `_playersFuture` / `_playersFuture` cached. |
| `Home` Trending Players `FutureBuilder` | ❌ FAIL | `future: _api.fetchPlayers()` is created INLINE in `build` (`home_screen.dart:270`) — recreated on EVERY build → re-fires fetch, flickers the Trending section, burns quota. Cache it in `initState` like MatchDetail does. |
| `Favourites` `FutureBuilder` | ❌ FAIL | `future: ApiService().fetchPlayers()` created inline in `build` + a NEW `ApiService()` per build — same re-fire/flicker/quota problem. Cache the future + reuse one `ApiService`. |
| `MatchDetail` Squad/Prediction `FutureBuilder`s | ✅ PASS | Both use the cached `_playersFuture`. |
| Polling intervals | ✅ PASS | 10-min live / 15-min idle / 60-min completed cache; no 45s polling. |
| Animations one-shot (no infinite tickers) | ✅ PASS | `LivePulseDot` one-shot scale-in + static glow; `TweenAnimationBuilder` everywhere; no `repeat()` controllers found. Tests can `pumpAndSettle`. |

## §9 — Model / provider details (smallest data details)

| Check | Result | Notes |
|-------|--------|-------|
| `resolveStatus` precedence | ✅ PASS | ended/result > not-started > live keywords > hasScores → live > upcoming. "Match not started" beats "started" substring. "won by" → completed. |
| `resolveStatus` false-positive watch | ⚠️ NOTE | Keyword "result" alone → completed (e.g. a live status "…result in a wicket" would misclassify). No evidence current providers emit that; watch item. "lunch"/"tea break"/"rain delay" → live: correct for a paused-but-in-progress match. |
| `TeamScore.display` | ✅ PASS | `batted ? 'R/W (ov)' : 'Yet to bat'`. |
| `isEffectivelyLive` | ✅ PASS | See §2. |
| H2H fraction with draws | ⚠️ MINOR | `frac = winsA / total` ignores draws/no-results (`winsA + winsB < total`): bar overstates A's share when draws exist. Use `winsA / (winsA + winsB)` when both > 0, else 0.5. |
| Compare bowling aggregate | ✅ PASS | Weighted across formats (total runs / total balls; total runs / total wickets), never a single-format value as career. Best = most-wickets format's best. |
| Compare "Best" row winner highlight | ✅ PASS (by design) | Uses (0, 0) numerics → `comparable == false` → no gold highlight. Correct: "Best" strings are not numerically comparable. |
| Stats qualifiers | ✅ PASS | Rate boards gated (min 10 innings / 60 balls); empty hints shown. |
| Stats "Best Economy (min 10 overs)" | ⚠️ INCONSISTENT | Title says 10 overs but gate is 60 balls = 10 overs — consistent in balls, but the code comment says "min 10 innings / 60 balls" for both boards; fine, just keep the label + gate in sync (they are: 60 balls = 10 overs). |
| Cricsheet calculations | ✅ PASS (from prior test evidence) | Kohli 169 runs / Babar avg 54 / Bumrah-vs-Babar 1 dismissal verified by `cricsheet_test.dart`. |
| `didNotBatNote` unused in UI | ⚠️ MINOR | `Innings.didNotBatNote` exists in the model but no screen renders it. Either render it or remove it. |

## §10 — Verification runs

| Run | Result |
|-----|--------|
| `flutter analyze` (snapshot, mid-edit tree) | ❌ FAIL — 3 errors (B1, B2) + warnings (unused imports/fields in `favourites_screen.dart`, `api_service.dart`, test file) + infos. Earlier clean-analyze claims (commit 17ce998: "No issues") do NOT apply to this snapshot — other teams have since edited the tree. |
| `flutter test` (first run this audit) | ✅ 26/26 passed (widget + cricsheet + team4/team5/match_detail suites). |
| `flutter test` (later re-runs) | ⚠️ INCONCLUSIVE — invocations aborted by service restart / concurrent edits. Not a failure signal, not a pass. Re-run on a frozen tree. |
| `flutter build web` | Not run in this audit (tree mid-edit; build would test a moving target). Re-run after freeze. |
| On-device (GT 6T) | Not possible from VM (no emulator). The user's V3 screenshots remain the only on-device evidence; the V3 bugs they showed (Live filter, comma-joined names, "King…", "Upcomin g", ad placeholder, fake "Complete") are all fixed in code per §§1–5. |

## §11 — Remaining issues for other teams (priority order)

**P0 — blockers:**
1. Fix B1 (duplicate `lastMatchesUpdated`) + B2 (`smooth_update.dart:96` null call). Re-run `flutter analyze` → must be clean.
2. Freeze the tree, re-run `flutter test` + `flutter build web` on the frozen tree, then commit.

**P1 — user-visible correctness:**
3. Bowling overs display `toStringAsFixed(0)` → `toStringAsFixed(1)` (§4).
4. Home + Favourites `FutureBuilder` futures created in `build` → cache in `initState` (§8).
5. Hindi toggle coverage: move ALL hardcoded English strings into `strings.dart` (§6). Do not claim Hindi support until done.
6. Cricsheet economy fallback: convert cricket overs → balls before `runs / overs` (§4).

**P2 — polish / honesty:**
7. Merge the two Cricsheet source rows in Player Profile into one (§5).
8. `AdPlaceholder` when an AdMob ID IS set must render a real banner or nothing, never placeholder text (§5).
9. SportScore "Powered by SportScore" attribution must render when SportScore answers (§5).
10. Prediction tab empty-squad message (§7).
11. Compare dropdown names: add ellipsis (§1); MatchCard/Detail "Last ball" texts: add `maxLines: 1` (§1).
12. Matchup tap: exact-match first, SnackBar on ambiguity instead of last-name guess (§7).
13. H2H bar: use `winsA / (winsA + winsB)` when draws exist (§9).
14. Leagues NRR: add or document omission (§2); render `didNotBatNote` or remove it (§9); Home empty state: distinguish load failure from genuinely-no-matches (§2).
15. Consider `isEffectivelyCompleted` mirror of `isEffectivelyLive` (§2); watch `resolveStatus` "result" keyword (§9).

## §12 — What PASSED (keep, do not regress)

V3 screenshot bugs (Live filter, comma-joined/lowercase team names, "King…", "Upcomin g", 2-line titles, ad placeholder hidden, no fake "Complete"), scorecard completeness (batting/bowling/extras/FOW/partnerships/yet-to-bat), source labels, prediction disclaimer + NaN guards, compare bowling aggregate + stale-picker fix, stats qualifiers, one-shot animations, quota-safe polling, profile fixed order (Overall → vs Opp → format → full table → leagues → venue → form → matchup → dismissal → bowling), tappable names with SnackBar fallback, points-table "partial" labelling, honest Weather row.

---

*End of report. Audit was read-only except for this file. No code was edited.*
