# KingCric — API Setup (FREE, ₹0) — MULTI-SOURCE

**One interface, ALL free providers.** Screens call only `ApiService`
(`fetchMatches`, `fetchScorecard`, `fetchMatchDetail`, `fetchSeries`,
`fetchPlayer`). Providers live in `lib/services/providers/` — one file
per provider, all behind the `CricketProvider` interface. Swapping or
adding a provider never touches a screen.

> Never scrape Cricbuzz / Cricinfo / Crex / Cricmetrics. The app talks
> ONLY to a provider's documented JSON API. Scraping gets blocked and
> breaks the app; the API keeps working.

## 1. Provider table — what each source provides

| # | Provider | Key? | Free quota | Provides | Role |
|---|---|---|---|---|---|
| 1 | **CricAPI / CricketData.org** `api.cricapi.com/v1` | Yes — `CRIC_API_KEY` (`?apikey=`) | **100 hits/day, lifetime, no card** | Live scores, full scorecards (batting/bowling/extras/FOW), series, basic player profiles | **PRIMARY** — only full-scorecard source |
| 2 | **EliteSport** `api.elitesportapi.com/v1` (VERIFY host on dashboard) | Yes — `ELITESPORT_API_KEY` (`x-api-key` header) | Free plan, testing tier — keep ≤90/day | Live matches, scorecard, commentary, player profile, fixtures, series | **SECONDARY** — CricAPI down / capped |
| 3 | **EntitySport** `rest.entitysport.com/v2` | Yes — `ENTITYSPORT_API_KEY` (`?token=`) | Free dev token: sample completed competitions only | Matches, live, info, competitions | **TERTIARY** — sample/ completed data |
| 4 | **SportScore** `sportscore.com/api/widget/` | **No key** | ~10,000 req/24h/IP | Live scores, fixtures, standings, top scorers, player stats (scores only) | **KEYLESS BACKSTOP** — needs attribution (see §2) |
| 5 | **TheSportsDB** `thesportsdb.com/api/v1/json/{key}/` | Test key `123` built in; own key via `SPORTSDB_API_KEY` | ~500/day reported (free registration) | Schedules/fixtures, results, team badges/logos, player bios, league lists, venues | **METADATA BACKSTOP** — not real-time |
| 6 | **Cricsheet** `cricsheet.org` (open data, NOT an API) | **No key** — bundled sample asset + full `all_json.zip` download | No quota (download once, compute locally) | **REAL calculated deep stats:** career, vs-opponent, venue, league, bowler-vs-batter, dismissal history, recent form, H2H, partnerships, FOW — computed from ball-by-ball data | **DEEP-STATS SOURCE** — `fetchPlayer` only, tried FIRST (offline, zero quota). See CRICSHEET-DATA.md |

**Fallback order:** CricAPI → EliteSport → EntitySport → SportScore →
TheSportsDB → cache (last verified) → mock demo data (always works
offline). If a provider fails, is capped, or is unconfigured, the next
one is tried. No provider can crash the app: every provider returns
null/[] on any error.

**Player profiles are different:** `fetchPlayer` tries **Cricsheet
first** (offline, zero quota). A Cricsheet-built profile has
`source='cricsheet'` + `dataComplete=true` + `sourceMatches` = matches
in the loaded dataset, and the profile screen labels it
`Real • Cricsheet open data • N matches in dataset`. Provider basic
profiles (`dataComplete=false`) and mock demo profiles are only used
when Cricsheet has no data for that player. Demo is never presented
as real.

**Cross-check:** the orchestrator compares the primary result against
any cached other-provider result for shared matches (id → runs/wkts).
On a mismatch it keeps the primary, logs the mismatch, and never
replaces verified data with unverified data. It does NOT burn quota
re-fetching from every provider on every call.

## 2. SportScore attribution (REQUIRED for the free tier)

SportScore's free tier is key-free and generous **on one condition**:
every surface rendering its data must show a visible
**"Powered by SportScore"** link. The constant
`AppConstants.sportScoreAttribution` carries that text. If KingCric
ever renders SportScore data without the attribution, that provider
must be disabled. (Commercial / white-label without attribution is
paid — we do NOT use it.)

## 3. Get keys (all free, none in chat / git)

| Key | How (2 min each) |
|---|---|
| `CRIC_API_KEY` | https://cricketdata.org → Sign up → Dashboard → API Keys → copy. Looks like `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`. |
| `ELITESPORT_API_KEY` | https://elitesportapi.com → Create account → Free plan → dashboard API key → copy. **Also verify the API host** on the dashboard/docs and update `eliteSportBaseUrl` if it differs. |
| `ENTITYSPORT_API_KEY` | https://entitysport.com → Sign up → dashboard → dev token. EntitySport publishes a sample dev token on its own docs for testing — **do NOT commit it**; use your own token from the dashboard. Dev token covers sample completed competitions only (no full live, no player search/profile/stats). |
| `SPORTSDB_API_KEY` | Optional. Without it the built-in test key `123` is used. For your own key: https://www.thesportsdb.com → free registration → profile page → copy key. |

**Never paste a key into chat, never commit it to git.** Keys travel
only via `--dart-define` (below), GitHub repo secrets, or the in-app
Settings key field (tested with `ApiService.testApiKeyValidity`).

## 4. Build / run WITH the keys

```bash
# Run on a phone / emulator with real data:
flutter run \
  --dart-define=CRIC_API_KEY=YOUR_FREE_KEY \
  --dart-define=ELITESPORT_API_KEY=YOUR_FREE_KEY \
  --dart-define=ENTITYSPORT_API_KEY=YOUR_FREE_TOKEN \
  --dart-define=SPORTSDB_API_KEY=YOUR_KEY

# Build the release APK with real data:
flutter build apk --release \
  --dart-define=CRIC_API_KEY=YOUR_FREE_KEY \
  --dart-define=ELITESPORT_API_KEY=YOUR_FREE_KEY \
  --dart-define=ENTITYSPORT_API_KEY=YOUR_FREE_TOKEN \
  --dart-define=SPORTSDB_API_KEY=YOUR_KEY
```

GitHub Actions: add each key as a repo secret with the SAME name
(Settings → Secrets → Actions → New repository secret):
`CRIC_API_KEY`, `ELITESPORT_API_KEY`, `ENTITYSPORT_API_KEY`,
`SPORTSDB_API_KEY` (optional). The workflow passes all four as
`--dart-define`; a missing secret expands to an empty define, that
provider is skipped, and **the build must NOT fail**. If no secrets are
set, the app builds in demo/backstop mode.

## 5. No key = demo / backstop mode (still fully usable)

- Without any key, CricAPI / EliteSport / EntitySport are skipped.
  SportScore + TheSportsDB (keyless) still try to answer; if they
  also fail, every method falls back to `MockDataService` (realistic
  India vs Pakistan / IPL / Big Bash data).
- The Home screen shows a **Demo** banner until a keyed provider is
  configured (`ApiService.isLive` = keyed provider present).
- `testApiKeyValidity()` returns `false` for an empty key — the app
  stays in demo/backstop mode, never crashes.

## 6. Endpoints used → KingCric screens

| Provider endpoint | KingCric method | Screen |
|---|---|---|
| CricAPI `GET /currentMatches?apikey=` | `fetchMatches()` | Home — live / upcoming / recent |
| CricAPI `GET /cricketScore?apikey=&id=` | `fetchScorecard()` + `fetchMatchDetail()` | Match Detail — full scoreboard |
| CricAPI `GET /players_info?apikey=&id=` | `fetchPlayer()` | Player Profile (basic profile; deep stats flagged `dataComplete: false`) |
| CricAPI `GET /series?apikey=&offset=0` | `fetchSeries()` | Leagues — series list |
| EliteSport `GET /matches/live`, `/matches/{id}/scorecard`, `/fixtures`, `/players/{id}` | same methods (fallback) | Same screens |
| EntitySport `GET /matches?token=`, `/matches/{id}/info?token=`, `/competitions?token=` | same methods (fallback) | Same screens |
| SportScore `GET /api/widget/cricket/matches` (+ live) | `fetchMatches()` (scores only) | Home — backstop scores |
| TheSportsDB `livescore.php?s=Cricket`, `search_all_leagues.php?s=Cricket`, `lookupplayer.php` | `fetchMatches()` / `fetchSeries()` / `fetchPlayer()` (metadata) | Home / Leagues / Player (metadata) |
| Cricsheet bundled sample / `all_json.zip` (open data, no HTTP) | `fetchPlayer()` (via `CricsheetService`, tried first) | Player Profile — REAL calculated career / vs-opponent / venue / matchup / dismissal / form |

Response envelopes:
- CricAPI: `{"status":"success","info":{"hitsToday":12,"hitsLimit":100,"hitsLeft":88},"data":[...]}`. `status:"failure"` + HTTP 400 = bad / exhausted key → fallback.
- EntitySport: `{status:"ok", response:{items:[...]}}`.
- TheSportsDB: `{events:[...]}` / `{teams:[...]}` / `{players:[...]}`.
- SportScore / EliteSport: `{data:[...]}` (or bare list). All parsers
  accept several envelope shapes and default missing fields to empty/0.

## 7. Quota budget — DO NOT POLL EVERY 45 SECONDS

Old code polled every 45 s. That is **~1,920 calls/day** — 19× the
CricAPI free quota. The key would die before lunch and the app would
go dark for every user that day.

New quota-safe policy (enforced in code, not just docs):

| What | Interval | Calls/day (worst case) |
|---|---|---|
| Live match list | **10 min** cache + manual Refresh | ~60 if the app ran 10 h straight |
| Live match detail / scorecard | **10 min** cache | shares the same budget — detail only for the open match |
| Completed match detail / scorecard | **60 min** cache (finished data never changes) | ~1 per match, once |
| Series list | **60 min** cache | ~a few |
| Match just finished | **+1 extra fetch** (AutoUpdateService fires once on live→completed transition) | +1 per finished match |
| Player profile | **60 min** cache per player | ~1 per profile open |

Per-provider daily self-caps (in code, below provider limits):
CricAPI 90/100, SportScore 500/~10,000, TheSportsDB 400/~500,
EliteSport 90 (testing tier), EntitySport 90 (dev token).
Realistic day: **20–40 hits on the primary** — comfortably inside 100.

`AutoUpdateService` uses `AppConstants.livePollInterval` (10 min).
The "45-second polling" idea is **rejected** — it is recorded here so
nobody reintroduces it.

## 8. Verify the keys work (before shipping)

```bash
# 1. CricAPI key valid? (in-app: Settings → Test key, or curl)
curl "https://api.cricapi.com/v1/currentMatches?apikey=YOUR_FREE_KEY" | head -c 400
# Expect: {"status":"success", ...}  —  "failure" = bad key.

# 2. App in live mode? (no key → demo banner; key → live banner)
flutter run --dart-define=CRIC_API_KEY=YOUR_FREE_KEY

# 3. Quota check: after a day of use, the provider dashboard
#    "hitsToday" must stay < 100. If it hits 100, the cache TTLs above
#    were bypassed somewhere — search for direct http.get calls.
#    (Only ApiService/providers may call http — grep to confirm.)
```

## 9. What is NOT ready (honest limits)

- **Live ball-by-ball is 10-min cached**, not sub-second. No free tier
  supports faster polling (see §7). Paid tiers / push feeds would be
  needed for true real-time — out of scope for the ₹0 build.
- **Player career / vs-opponent / venue / matchup stats** now come
  from **Cricsheet open data** (see CRICSHEET-DATA.md) — real stats
  calculated from ball-by-ball deliveries, offline, zero quota.
  CAVEAT: the bundled asset is a **4-match sample**, so those numbers
  are real-over-the-sample, labelled with the dataset size, and are
  NOT full careers. Full-career numbers need the full-dataset refresh
  (download `all_json.zip`, replace the asset, rebuild — no code
  change). When Cricsheet has no data for a player, the profile
  falls back to provider basic profile / curated demo, flagged
  `dataComplete: false` — never presented as live-verified.
- **EliteSport base URL is UNVERIFIED** (see §1). Until it is confirmed
  against the dashboard/docs, that provider may silently return null.
  That is safe (fallback works) but means it may contribute nothing.
- **EntitySport dev token covers sample completed competitions only**
  — no full live coverage, no player endpoints. It is a tertiary
  backstop, not a live source.
- **TheSportsDB free livescore is delayed** (2-min livescores are a
  premium feature). It is a metadata/schedule backstop, not live.
- **SportScore has no full innings scorecard** in the widget API —
  scores only. Full scorecards come only from CricAPI (or EliteSport
  once verified).
- **Background updates when the app is closed** need WorkManager /
  Firebase Functions (free tier) — planned, not in this build.
- **Push notifications (FCM)** need a Firebase project — planned, not
  in this build.
- **Paid-only providers are NOT used as primary:** Sportmonks (14-day
  trial, then €29/mo), Roanuz (no free tier, ~₹17,669/mo), RapidAPI /
  CricBuzz-derived (7-day trial, then $19.99/mo), Sportradar
  (enterprise only), DataSportsGroup (no free tier). SportXAPI has a
  free $0/100-calls tier (matches, H2H, standings, teams, players) —
  a possible future provider behind the same interface, not wired yet.

## 10. Adding a new provider (no rebuild of screens)

1. Add `lib/services/providers/<name>_provider.dart` implementing
   `CricketProvider` (never throw, never hard-code a key, respect
   its daily cap, parse defensively).
2. Add its key constant to `AppConstants` (`String.fromEnvironment`).
3. Register it in `ApiService`'s provider list (order = priority).
4. Add its row to §1, its key to §3, its secrets to §4, its limits
   to §9. Done — screens never change.
