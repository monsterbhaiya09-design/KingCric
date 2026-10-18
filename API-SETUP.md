# KingCric — API Setup (FREE, ₹0)

**Chosen provider: CricAPI / CricketData.org** — `https://api.cricapi.com/v1`
(first called CricAPI since 2015, now CricketData.org — same API, same
`api.cricapi.com` base URL, same endpoints).

Why this one first:
- **Only provider with a lifetime free tier that never expires** — 100
  hits/day forever, no credit card, no 7/14-day trial that dies.
- Covers what KingCric needs: live scores, ball-by-ball, full
  scorecards, player profiles, series, squads.
- Simple JSON + `?apikey=` query param — no OAuth, no RapidAPI
  subscription, no SDK to install.

> Never scrape Cricbuzz / Cricinfo / Crex / Cricmetrics. The app talks
> ONLY to a provider's documented JSON API. Scraping gets blocked and
> breaks the app; the API keeps working.

## 1. Get a FREE key (2 minutes)

1. Go to **https://cricketdata.org** (or https://api.cricapi.com).
2. Click **Sign up** — email + password, or Sign in with Google.
3. Open the **Dashboard** — your API key is shown there
   (looks like `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`).
4. Copy it. **Never paste it into chat, never commit it to git.**
   It travels only via `--dart-define` (below) or the in-app
   Settings key field (tested with `ApiService.testApiKeyValidity`
   before saving).

## 2. Build / run WITH the key

```bash
# Run on a phone / emulator with real data:
flutter run --dart-define=CRIC_API_KEY=YOUR_FREE_KEY

# Build the release APK with real data:
flutter build apk --release --dart-define=CRIC_API_KEY=YOUR_FREE_KEY
```

GitHub Actions: add the key as a repo secret named `CRIC_API_KEY`
(Settings → Secrets → Actions → New repository secret), then the
workflow passes it as `--dart-define=CRIC_API_KEY=${{ secrets.CRIC_API_KEY }}`.
If the secret is absent, the workflow still builds — the app just runs
in demo (mock) mode.

## 3. No key = demo mode (still fully usable)

- Without `--dart-define`, `AppConstants.hasApiKey` is false and every
  `ApiService` method falls back to `MockDataService` (realistic
  India vs Pakistan / IPL / Big Bash data).
- The UI must label this clearly as **Demo data** (it already does).
- `testApiKeyValidity()` returns `false` for an empty key — the app
  stays in demo mode, never crashes.

## 4. Endpoints used (CricAPI v1) → KingCric screens

| CricAPI endpoint | KingCric method | Screen |
|---|---|---|
| `GET /currentMatches?apikey=` | `fetchMatches()` | Home — live / upcoming / recent |
| `GET /cricketScore?apikey=&id=<matchId>` | `fetchScorecard()` + `fetchMatchDetail()` | Match Detail — full scoreboard |
| `GET /players_info?apikey=&id=<playerId>` | `fetchPlayer()` | Player Profile (basic profile; career / vs-opponent / venue / matchup stats are marked `dataComplete: false` in live mode until a richer source is added — never present partial data as complete) |
| `GET /series?apikey=&offset=0` | `fetchSeries()` | Leagues — series list |

Response envelope (all endpoints):
```json
{"status": "success", "info": {"hitsToday": 12, "hitsLimit": 100, "hitsLeft": 88}, "data": [...]}
```
`status: "failure"` + HTTP 400 = bad / exhausted key → the app falls
back to cached data, then mock data. The `info.hitsLeft` field is the
quota meter — log it, don't ignore it.

`cricketScore` scorecard shape (mapped in `_matchFromScorecard`):
`data.scorecard[]` → `{inning, batting:[{batter, dismissal, r, b, 4s, 6s, sr}], bowling:[{bowler, o, m, r, w, eco, wd, nb}], extras:{r, b, lb, wd, nb}, fallofwickets:[{name, score, over}], total, wickets, overs}`.
Fields the provider omits default to empty/0 — a partial response can
never crash the scoreboard.

## 5. Quota budget (100 hits/day) — DO NOT POLL EVERY 45 SECONDS

Old code polled every 45 s. That is **~1,920 calls/day** — 19× the
free quota. The key would die before lunch and the app would go dark
for every user that day.

New quota-safe policy (enforced in code, not just docs):

| What | Interval | Calls/day (worst case) |
|---|---|---|
| Live match list (`currentMatches`) | **10 min** cache + manual Refresh | ~60 if the app ran 10 h straight |
| Live match detail (`cricketScore`) | **10 min** cache | shares the same budget — detail is only fetched for the open match |
| Completed match detail / scorecard | **60 min** cache (finished data never changes) | ~1 per match, once |
| Series list | **60 min** cache | ~a few |
| Match just finished | **+1 extra fetch** (AutoUpdateService fires once on live→completed transition) | +1 per finished match |
| Player profile | **60 min** cache per player | ~1 per profile open |

Realistic day: **20–40 hits** — comfortably inside 100. A user who
leaves the app open all day still cannot burn the quota, because the
cache — not the timer — gates the calls.

`AutoUpdateService` uses `AppConstants.livePollInterval` (10 min).
The "45-second polling" idea is **rejected** — it is recorded here so
nobody reintroduces it.

## 6. Alternatives (if CricAPI ever goes down)

All are **paid-first** — listed only as fallbacks, NOT the default.
KingCric stays 100% free: if the primary key is exhausted, the app
falls back to cache → mock data, it never asks the user to pay.

| Provider | Free offer | Why not primary |
|---|---|---|
| **SportScore** (sportscore.com) | Free, CORS-open, no key for open-source projects | Cricket coverage is thinner than CricAPI; good backstop for scores only |
| **EliteSport API** (elitesportapi.com) | Free tier "for testing", `GET /matches/live`, `/matches/{id}/scorecard`, `/matches/{id}/commentary`, `/players/{id}`, `/fixtures`, `/series/{id}` via `x-api-key` header | Free tier is testing-only; paid plans $199+/mo — not free for production |
| **Sportmonks** (sportmonks.com) | **14-day free trial only**, then from €29/mo, 2,000 calls/hour/endpoint | Trial expires; not lifetime-free |
| **Roanuz** (sports.roanuz.com) | **No free tier**, free trial only, plans from ~₹17,669/mo (~$210/mo) | Not free at all |
| **RapidAPI / getcricketapi.com** (CricBuzz-derived) | 7-day trial, 50 units, then $19.99/mo | Trial expires; not lifetime-free |
| **EntitySport** (entitysport.com) | Free dev token, then $150/mo+ | Not free for production |
| **TheSportsDB** (thesportsdb.com) | Free for personal use, no key for basic endpoints | Schedules / logos / basic metadata only — NOT real-time-grade, no ball-by-ball |

If a fallback is ever wired in, it goes behind the same `ApiService`
interface (same methods, same cache, same `dataComplete` flag) so
screens never learn which provider answered.

## 7. Verify the key works (before shipping)

```bash
# 1. Key valid? (in-app: Settings → Test key, or curl)
curl "https://api.cricapi.com/v1/currentMatches?apikey=YOUR_FREE_KEY" | head -c 400
# Expect: {"status":"success", ...}  —  "failure" = bad key.

# 2. App in live mode? (no key → demo banner; key → live banner)
flutter run --dart-define=CRIC_API_KEY=YOUR_FREE_KEY

# 3. Quota check: after a day of use, the provider dashboard
#    "hitsToday" must stay < 100. If it hits 100, the cache TTLs above
#    were bypassed somewhere — search for direct http.get calls.
```

## 8. What is NOT ready (honest limits)

- **Live ball-by-ball is 10-min cached**, not sub-second. The free tier
  cannot support faster polling (see §5). Paid tiers / push feeds
  would be needed for true real-time — out of scope for the ₹0 build.
- **Player career / vs-opponent / venue / matchup stats in live mode**
  come from the free provider's basic profile only. Deep analytics
  still use the curated dataset and are flagged `dataComplete: false`
  in live mode — the app never presents them as live-verified.
- **Background updates when the app is closed** need WorkManager /
  Firebase Functions (free tier) — planned, not in this build.
- **Push notifications (FCM)** need a Firebase project — planned, not
  in this build.
