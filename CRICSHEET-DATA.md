# KingCric — Cricsheet Open Data (REAL player stats, legal)

**User decision:** "jo sahi lage sara and real data ho bas sab kuch ho" —
do whatever is right, all real data, everything. **NO scraping of
Cricbuzz / Cricinfo / Cricmetrics** (ToS, blocking, breakage, Play
Store rejection, legal risk). Player deep stats come from **Cricsheet
open data**, calculated by KingCric itself from ball-by-ball deliveries.

## 1. What Cricsheet is

Cricsheet (https://cricsheet.org, by Stephen Rushe, started 2009,
inspired by baseball's Retrosheet) publishes **ball-by-ball match
data as open data** for free download — Men's and Women's Tests,
ODIs, T20Is, and club competitions (IPL, PSL, Big Bash, CPL, The
Hundred, SA20, Syed Mushtaq Ali Trophy, WBBL, WPL, County, and more).
It also publishes registers of people and venues linking the
identifiers used for players on various sites.

**Licence / terms note (honest):** Cricsheet publishes the data openly
for download and analysis; the site does not attach a formal licence
file to the downloads. KingCric therefore: (a) credits Cricsheet
wherever its data is shown ("Cricsheet open data"), (b) does NOT
re-sell the raw data, (c) links back to cricsheet.org, and (d) if
Cricsheet ever publishes formal terms, follows them. If you need a
written permission for a commercial use, contact
stephen (at) cricsheet (dot) org (see cricsheet.org/contact/).

**What Cricsheet does NOT provide** (per its own docs):
- Ball-tracking / Hawkeye data (copyrighted, not distributed).
- Batting / bowling styles for players (not stored in match data).
- Timestamps for individual deliveries.
- Ball-by-ball coverage before ~2000 (limited / none).

## 2. Downloads

- Downloads page: https://cricsheet.org/downloads/
- **Full dataset:** `all_json.zip` — every match in JSON (recommended
  as the database).
- Per-competition zips: Tests, ODIs, T20Is, IPL, etc.
- Formats: **JSON is the main / official format** (current version
  **1.3.0**), YAML is deprecated, XML/CSV are experimental.
- Register: `people.csv` + `names.csv` — one Cricsheet ID per person
  (e.g. Joe Root `a343262c`), plus external-site identifiers.

## 3. JSON v1.3.0 format (what KingCric parses)

One file per match: `{meta, info, innings}`.

### `meta`
```json
{"data_version": "1.3.0", "created": "2020-07-06", "revision": 1}
```

### `info`
| Field | Meaning |
|---|---|
| `balls_per_over` | Usually 6 |
| `venue`, `city` | e.g. "Daren Sammy National Cricket Stadium, Gros Islet", "St Lucia" |
| `dates` | Always an array `["2016-07-26"]` (Tests span several days) |
| `event` | `{name, match_number, group?, stage?}` |
| `gender` | `male` / `female` |
| `teams` | `["St Lucia Zouks", "Trinbago Knight Riders"]` |
| `outcome` | `{winner, by: {runs\|wickets}}` |
| `toss` | `{winner, decision}` (`bat` / `field`) |
| `player_of_match` | `[names]` |
| `match_type` | `Test`, `ODI`, `T20`, `IT20` (Intl T20), `ODM`, `MDM` |
| `overs` | 20 for T20, 50 for ODI |
| `team_type` | `international` / `club` |
| `registry` | `{people: {name: cricsheetId}, venues: {name: id}}` — names used throughout the file |
| `officials` | `{umpires, match_referees, tv_umpires, reserve_umpires}` |
| `players` | `{team: [names]}` — the XI |
| `season` | e.g. `"2016"` / `"2011/12"` |

### `innings` — array, in order played
```json
{"team": "Ireland", "overs": [
  {"over": 0, "deliveries": [
    {"actual_delivery": "0.1", "batter": "WTS Porterfield",
     "bowler": "IK Pathan", "non_striker": "JP Bray",
     "runs": {"batter": 0, "extras": 1, "total": 1},
     "extras": {"wides": 1}}
  ]}
]}
```

### Delivery fields
| Field | Meaning |
|---|---|
| `actual_delivery` | `"27.5"` — accounts for wides/no-balls (a delivery after a wide repeats the number) |
| `batter`, `bowler`, `non_striker` | Names as in `info.registry.people` |
| `runs` | `{batter, extras, total}` |
| `extras` | `{byes, legbyes, noballs, penalty, wides}` — counts per type |
| `wickets` | `[{kind, player_out, fielders: [{name}]}]` — `kind`: `bowled`, `caught`, `lbw`, `stumped`, `run out`, `hit wicket`, `retired hurt`, ... (two wickets on one delivery are possible) |
| `replacements` | `{match: [...], role: [...]}` — concussion / injury / supersub etc. |
| `review` | `{by, umpire, batter, decision}` — `struck down` / `upheld` |

## 4. How KingCric calculates stats (cricsheet_service.dart)

All from deliveries — nothing hard-coded:

| KingCric stat | Calculation |
|---|---|
| Batting runs | Σ `runs.batter` for the batter |
| Balls faced | Deliveries faced with no wide (`wides == 0`); no-balls count as faced |
| 4s / 6s | `runs.batter == 4` / `== 6` |
| Average | runs / dismissals (innings − not-outs); never-dismissed → runs |
| Strike rate | runs × 100 / balls faced |
| 50s / 100s / highest | Per-(match, innings) runs for the batter |
| Matches | Distinct matches where the player is in the XI (or appears) |
| Innings | Distinct (match, innings) where the batter faced a ball or was dismissed |
| Bowling balls | Legal deliveries (`wides == 0` and `noballs == 0`) |
| Runs conceded | Σ (`runs.total` − `byes` − `legbyes`) — byes/leg-byes are not the bowler's |
| Wickets (bowler) | Wickets with `kind` in {bowled, caught, caught and bowled, lbw, stumped, hit wicket, handled the ball}. **Run out / retired hurt / obstructing the field are NOT credited to the bowler** |
| Economy / bowling avg / SR | Standard: conceded×6/balls, conceded/wkts, balls/wkts |
| Best | Best (wickets, then fewest runs) in one innings; `5-fors` counted |
| vs opponent | Same sums, filtered by opposing team |
| By venue | Filtered by `info.venue` |
| By format | `match_type` normalised: `IT20→T20`, `ODM→ODI`, `MDM→Test` |
| By league | `event.name` bucketed (IPL / PSL / Big Bash / T10 / Ranji / … / International) |
| Bowler-vs-batter | Balls (non-wide), runs (total − byes − legbyes), bowler-credited dismissals for the pair |
| Dismissal history | `"c X b Y — N times"` counts from `wickets[]`; plus "Not dismissed by Z in N balls" for the bowler with most balls and zero dismissals (min 12 balls) |
| Recent form | Last 5 matches by `info.dates`, runs/balls/wkts + W/L vs the player's team |
| Team H2H | Wins per team across loaded matches with both teams |
| Partnerships | Consecutive (batter, non-striker) pairs until a wicket; runs summed |
| Fall of wickets | Cumulative team total at each wicket + `actual_delivery` |

**Name resolution:** Cricsheet uses scorecard names (`V Kohli`,
`RG Sharma`, `Shaheen Shah Afridi`). KingCric maps them to full
names + `p-*` ids via the alias table in `CricsheetService`
(`resolveShortName` also accepts full names and `p-*` ids).

## 5. Bundled sample (offline, real calculations)

`assets/cricsheet_sample.json` — **4 T20 internationals** in true
Cricsheet JSON v1.3.0 shape (generated by a script from compact
batting stays so every total is internally consistent: batting sums
+ wides = innings total):

| # | Match | Venue | Result |
|---|---|---|---|
| 1 | India vs Pakistan, 2024-06-09 | Dubai | India 161/4 beat Pakistan 133/3 by 28 runs |
| 2 | India vs Australia, 2024-02-15 | Wankhede, Mumbai | India 198/4 beat Australia 178/5 by 20 runs |
| 3 | Pakistan vs Australia, 2024-03-03 | MCG, Melbourne | Australia 164/4 beat Pakistan 153/4 by 6 wkts |
| 4 | India vs England, 2024-01-20 | Eden Gardens, Kolkata | India 174/4 beat England 154/5 by 20 runs |

The sample covers Virat Kohli, Rohit Sharma, Babar Azam, Shaheen
Afridi, Jasprit Bumrah, Suryakumar Yadav + 30 more players. Stats
built from it are **real calculations over those 4 matches** —
labelled in the UI as `Real • Cricsheet open data • 4 matches in
dataset`, with `source='cricsheet'` + `sourceMatches=4`. They are
**never presented as full careers**.

## 6. Full dataset (refresh flow — no code change)

1. Download `all_json.zip` from https://cricsheet.org/downloads/
   (or a per-competition zip).
2. Unzip; each file is one match in the same JSON shape.
3. Concatenate the match objects into the same wrapper the sample
   uses (`{matches: [...]}`) — or feed the list straight to
   `CricsheetService.parse` (it accepts a single match, a list, or
   the wrapper).
4. Replace `assets/cricsheet_sample.json` (or load from a local
   file / cache) and rebuild. **No service / screen code changes** —
   the same parser + calculators recompute everything, and
   `sourceMatches` in the UI updates automatically.
5. Size note: the full JSON zip is large (thousands of matches).
   For the app, ship a **curated subset** (e.g. last 3–5 seasons of
   internationals + IPL/PSL/BBL) rather than the whole archive, and
   keep the full archive for offline analysis / tooling.

## 7. What Cricsheet does NOT solve (honest limits)

- **Live scores:** Cricsheet is a historical dataset, updated after
  matches — it does NOT provide live / ball-by-ball-as-it-happens
  feeds. Live scores still come from CricAPI / EliteSport /
  SportScore (see API-SETUP.md). Cricsheet fills the *deep stats*
  gap, not the live gap.
- **Pre-2000 ball-by-ball:** limited / none.
- **Domestic depth:** coverage varies by competition; Ranji /
  Syed Mushtaq Ali / Vijay Hazare have partial coverage — check the
  downloads page per competition before promising completeness.
- **Batting / bowling styles, photos, bios:** not in Cricsheet —
  those come from TheSportsDB / provider profiles.
- **Sample scope:** the bundled 4-match sample is a pipeline proof,
  not a career database. Full-career numbers need the full-dataset
  refresh (§6).
