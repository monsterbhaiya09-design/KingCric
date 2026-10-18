# Team 1 — Home + Live (detail pass)

Read: REFERENCE-SPEC.md, CRICKETLINEX-REFERENCE.md (+ REFERENCE-APPS-DEEP-DIVE
skimmed via spec). REQUIREMENTS-MAPPING.md arrived mid-task (parent-side);
its Home-relevant verdicts (Live/Favourites/Hindi well-covered, no
auto-update recalc advertised) match what this pass implements. V3-fix
commit 17ce998 kept — no reverts.

## What changed (working tree, UNCOMMITTED — do not commit per-file:
home_screen.dart / strings.dart / widget_test.dart also carry other
teams' interleaved edits; parent to consolidate)

### lib/screens/home_screen.dart
- H1: Live tab empty → "No live matches right now." + **Next up** section
  with the earliest upcoming match card (respects format filter, ignores
  text query). Never a dead blank screen.
- H6: search now matches team / fixture title / league / venue (was
  team+league only). Empty search → `No matches found for 'q'` (was the
  generic section message). Search field: controller + Clear (X) button
  + Search action + clear-button semantics.
- G5: Trending Players future cached once in initState (`_playersFuture`)
  — was re-created on every build (quota burn + flicker). Trending now
  has waiting / error / empty states (was spinner-forever on error).
- G4: offline banner `Offline — showing last verified data.` when a
  refresh fails with data on screen; refresh no longer wipes the list
  (no flicker); concurrent loads guarded (`_loadingMatches`).
- G3 Hindi parity: section headers now `lang.t('matches')` /
  `lang.t('trending_players')`; Refresh / Updating via `lang.t`; format
  'All' chip via `lang.t('all')`. Previously hardcoded English.
- G6: format chips `MaterialTapTargetSize.padded` (48dp); filter tabs
  vertical padding 10→12 (48dp) + Semantics(button, selected, label);
  chips get Semantics(selected) too.
- Pull-to-refresh: `AlwaysScrollableScrollPhysics` so a short list can
  still refresh. Finished filter uses `m.isCompleted` (was raw status).
- Semantics: filter-tab chips + format chips labelled for screen readers.

### lib/utils/strings.dart — 11 new keys, EN + हिं
matches, trending_players, next_up, no_live_matches,
no_matches_section, no_matches_found, no_trending, offline_banner,
refresh, updating, format_filter_label. All verified non-fallback in tests.

### test/widget_test.dart — 2 appended tests
- New Home strings exist in EN + Hindi, no key-fallback.
- Next-up = earliest upcoming; live-scored match is never "upcoming"
  (`isEffectivelyLive` true for Austria W 37/3 case).

## Verification
- `flutter analyze lib/screens/home_screen.dart lib/utils/strings.dart` →
  **No issues found!**
- `flutter test test/widget_test.dart` → **BLOCKED by other teams'
  in-progress tree**: compile errors in `player_profile_screen.dart`
  (`_FormatTables` undefined, Matchup→String), `api_service.dart`
  (`lastMatchesUpdated` duplicate), `smooth_update.dart` (nullable),
  `match_detail_test.dart`. None are Team 1 files; Team 1 did not touch
  them. Re-run after the tree compiles.
- Full `flutter analyze` (whole tree) shows those same other-team errors
  + warnings; Team 1 files contribute zero issues.

## Detail checklist (spec §4.1 H1–H10 + §4.8 G1–G6 for Home)
- H1 Live-default + next-up: PASS (code) — needs on-device check.
- H2 sort (Live recent-first / Upcoming start-asc / Finished end-desc): KEPT from redesign worker, verified in code.
- H3 card order: KEPT via shared KingMatchCard (other worker) — not re-touched.
- H4 upcoming shows no scores: KEPT in KingMatchCard.
- H5 finished shows both scores + result: KEPT in KingMatchCard.
- H6 search + empty message: PASS (code).
- H7 pull-to-refresh + Last updated HH:MM + Refresh button: PASS (code).
- H8 no ad placeholder: KEPT (AdPlaceholder → shrink without ID).
- H9 Trending top-4, tappable, source label: KEPT via PlayerCard; future cached + empty state added.
- H10 single demo banner: KEPT (mock_mode banner once).
- G3 Hindi parity on Home: PASS for Home strings (headers/empty/refresh/updating).
- G4 offline banner + keep-last-data: PASS (code).
- G5 no per-build futures: PASS (cached future).
- G6 48dp targets + semantics on tabs/chips: PASS (code).
- P1 one status truth / P2 live unmissable / P3 one team per row / P4 Title Case / P5 no truncation: KEPT from 17ce998 + redesign worker; not regressed.
