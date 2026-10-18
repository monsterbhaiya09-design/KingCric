# KingCric — Multi-Source API (all free providers, one interface)

User instruction: "pehle tu sabki api lagwa le and fir kaam kar taki baar
baar na banana pade" — integrate ALL free APIs FIRST, then build once.

## Architecture

Screens call ONLY `ApiService` (unchanged public interface):
`fetchMatches`, `fetchScorecard`, `fetchMatchDetail`, `fetchSeries`,
`fetchPlayer`, `fetchPlayers`, `fetchVenues`, `testApiKeyValidity`,
`clearCache`, `cacheEntryCount`, `isLive`, `lastSource`.

Providers in `lib/services/providers/` — one file per provider, all
implementing `CricketProvider` (never throw, never hard-code a key,
defensive parsing, per-provider daily cap):

| Order | Provider | File | Key | Quota |
|---|---|---|---|---|
| 1 Primary | CricAPI / CricketData.org | `cricapi_provider.dart` | `CRIC_API_KEY` | 100/day lifetime |
| 2 Secondary | EliteSport | `elitesport_provider.dart` | `ELITESPORT_API_KEY` (x-api-key) | testing tier, cap 90 |
| 3 Tertiary | EntitySport | `entitysport_provider.dart` | `ENTITYSPORT_API_KEY` (?token=) | dev token, sample only, cap 90 |
| 4 Backstop | SportScore | `sportscore_provider.dart` | none | ~10k/IP/day, cap 500, attribution required |
| 5 Metadata | TheSportsDB | `thesportsdb_provider.dart` | test key `123` / `SPORTSDB_API_KEY` | ~500/day, cap 400 |
| 6 Fallback | Cache → Mock demo | `api_service.dart` + `mock_data_service.dart` | — | always works offline |
| 0 Deep stats (fetchPlayer only) | **Cricsheet** open data | `cricsheet_service.dart` + `assets/cricsheet_sample.json` | none | **REAL calculated** career / vs-opponent / venue / matchup / dismissal / form / H2H. Tried FIRST in `fetchPlayer` (offline, zero quota). Sample = 4 T20Is, labelled with dataset size. Full dataset = `all_json.zip` refresh, no code change. See CRICSHEET-DATA.md. |

## Fallback + cross-check

- Primary → secondary → tertiary → backstops → cache → mock.
- A provider that fails / is capped / is unconfigured is skipped.
- Cross-check: primary vs cached other-provider result on shared
  matches (id → runs/wkts). Mismatch → keep primary + log, never crash,
  never replace verified data. No quota burned re-fetching all sources.
- `dataComplete`: providers return basic profiles with
  `dataComplete=false`; deep career/vs-opponent/venue/matchup sections
  stay on the curated dataset, labelled as such. Never presented as
  live-verified.

## Keys / secrets

`--dart-define=CRIC_API_KEY=...`, `ELITESPORT_API_KEY=...`,
`ENTITYSPORT_API_KEY=...`, `SPORTSDB_API_KEY=...` (all optional).
GitHub workflow passes all four from repo secrets; a missing secret
expands to empty, the provider is skipped, build does NOT fail.
Secrets: `CRIC_API_KEY`, `ELITESPORT_API_KEY`, `ENTITYSPORT_API_KEY`,
`SPORTSDB_API_KEY` (Settings → Secrets → Actions).

## Honest limits (see API-SETUP.md §9)

- Full innings scorecards: only CricAPI (EliteSport once host verified).
- Deep career / vs-opponent / venue / matchup: now from **Cricsheet
  open data** (real calculated stats, offline). Bundled sample = 4
  T20Is — real-over-sample, labelled with dataset size, NOT a full
  career. Full careers need the `all_json.zip` refresh (no code
  change). Players missing from Cricsheet still fall back to curated
  dataset + `dataComplete:false`.
- EliteSport base URL UNVERIFIED — may silently return null (safe).
- EntitySport dev token: sample completed competitions only.
- TheSportsDB free livescore is delayed; metadata/schedule backstop.
- SportScore: scores only, no full scorecard; attribution required.
- Ball-by-ball: 10-min cached, not sub-second (free-tier limit).
- No background-when-closed updates / FCM push yet.

## Verification

Run: `flutter analyze` (clean) + `flutter test` (7 tests incl. 4 new
multi-source fallback/cross-check tests) + `flutter build web`.
