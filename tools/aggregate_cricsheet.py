#!/usr/bin/env python3
"""Aggregate the FULL Cricsheet JSON archive into a compact per-player
stats asset for KingCric (assets/cricsheet_stats.json).

Why aggregates, not raw ball-by-ball: the full archive is ~62 MB
zipped / hundreds of MB unzipped. Bundling it would explode the APK.
Aggregates keep every number the profile screens show (career,
per-format, vs-opponent, per-venue, per-league batting + bowling,
dismissal counts, bowler-vs-batter pairs) in a few MB.

Semantics mirror lib/services/cricsheet_service.dart's sample index:
- batting `matches` = XI matches in scope (players list), `innings` =
  innings actually batted; average = runs / dismissals (dismissals =
  times the batter was out); SR = runs*100/balls (wides excluded
  from balls, as in the Dart code).
- bowling `matches` = matches actually bowled in scope.
- bowler-credited wicket kinds: bowled, caught, caught and bowled,
  lbw, stumped, hit wicket, handled the ball (run out etc. excluded).
- league bucket: IPL / PSL / Big Bash / T10 League / Ranji /
  Syed Mushtaq Ali / Vijay Hazare, else International (same mapping
  as CricsheetService.leagueForEvent).
- dismissal lines use raw Cricsheet short names (e.g. "c X b Y");
  the Dart side uses aggregate lines wholesale when present, so
  they never mix with sample lines for the same batter.

Input: one or more Cricsheet *_json.zip files (format zips:
tests_json, odis_json, t20s_json — men's + women's internationals).
Domestic / league zips are deliberately NOT inputs here: the format
zips already cover every international; franchise data would add
thousands of players for a small gain and is reported as skipped.

Output: assets/cricsheet_stats.json
  { "meta": {matches, yearMin, yearMax, generated, source,
             inputs: [...], indexes: ["h2h", "venues"]},
    "players": { shortName: {
        "team": first team seen,
        "m": XI matches (career),
        "bat": { scope: [matches, innings, runs, balls, fours,
                          sixes, dismissals, fifties, hundreds,
                          highest] },
        "bowl": { scope: [matches, innings, wickets, balls,
                           runsConceded, fiveWickets, bestWkts,
                           bestRuns] },
        "dis": { "line": count },
        "pairs": { bowlerShort: [matches, balls, runs, dismissals] }
    } },
    "h2h": { "teamA|teamB|fmt|gender": [matches, aWins, bWins,
        noResult] },
      teamA/teamB are the two Cricsheet team names SORTED
      alphabetically, so aWins always belongs to the sorted-first
      team (callers map back). fmt is Test/ODI/T20/T10 or ALL;
      gender is male/female (info.gender) or ALL. Every match
      increments 4 keys: (fmt,gender), (fmt,ALL), (ALL,gender),
      (ALL,ALL). Ties and no-results count as noResult.
    "venues": { venue: {city, matches, avgFirst, avgSecond,
        highest, batFirstWinPct,
        topBatters: [[short, runs, matches], ...] (top 10),
        topBowlers: [[short, wickets, matches], ...] (top 10),
        byGender: {male|female: {matches, avgFirst, avgSecond,
            highest, batFirstWinPct}} } }
      Venue totals use the same definitions as the Dart sample
      venueStats (innings totals summed from deliveries, bat-first
      win = winner == first innings batting team). Top players are
      all-gender (player ven: scopes carry no gender split). }
Scopes: "all", "fmt:Test|ODI|T20|T10", "opp:<team>", "ven:<venue>",
"lg:<league>". A bat/bowl scope is emitted only when the player has
an innings in it (except bat "all", which is always emitted so the
career XI-match count survives). Nothing is ever invented: absent
scope = absent, never zero-filled in the app.

Dedupe: the same Cricsheet file id appearing in two input zips is
counted ONCE (seen-ids set) — the format zips are disjoint in
practice, but a future re-run must stay idempotent.

Usage: python3 tools/aggregate_cricsheet.py /tmp/cs_full/tests_json.zip
       /tmp/cs_full/odis_json.zip /tmp/cs_full/t20s_json.zip
       --out assets/cricsheet_stats.json
"""
import argparse
import json
import sys
import zipfile
from collections import defaultdict

BOWLER_CREDITED = {
    "bowled", "caught", "caught and bowled", "lbw", "stumped",
    "hit wicket", "handled the ball",
}


def norm_format(mt):
    return {"Test": "Test", "MDM": "Test", "ODI": "ODI", "ODM": "ODI",
            "T20": "T20", "IT20": "T20", "T10": "T10"}.get(mt, mt or "T20")


def league_for_event(event):
    e = (event or "").lower()
    if "ipl" in e or "indian premier" in e:
        return "IPL"
    if "psl" in e or "pakistan super" in e:
        return "PSL"
    if "big bash" in e:
        return "Big Bash"
    if "t10" in e:
        return "T10 League"
    if "ranji" in e:
        return "Ranji Trophy"
    if "syed mushtaq" in e:
        return "Syed Mushtaq Ali"
    if "vijay hazare" in e:
        return "Vijay Hazare"
    return "International"


class Bat:
    __slots__ = ("matches", "innings", "runs", "balls", "fours", "sixes",
                 "dismissals", "inn_runs")

    def __init__(self):
        self.matches = set()
        self.innings = set()
        self.runs = 0
        self.balls = 0
        self.fours = 0
        self.sixes = 0
        self.dismissals = 0
        self.inn_runs = {}  # innings key -> runs (for 50s/100s/HS)

    def emit(self):
        fifties = hundreds = highest = 0
        for r in self.inn_runs.values():
            if r >= 100:
                hundreds += 1
            elif r >= 50:
                fifties += 1
            if r > highest:
                highest = r
        return [len(self.matches), len(self.innings), self.runs,
                self.balls, self.fours, self.sixes, self.dismissals,
                fifties, hundreds, highest]


class Bowl:
    __slots__ = ("matches", "innings", "wickets", "balls", "runs",
                 "inn_wkts", "inn_runs")

    def __init__(self):
        self.matches = set()
        self.innings = set()
        self.wickets = 0
        self.balls = 0
        self.runs = 0
        self.inn_wkts = {}
        self.inn_runs = {}

    def emit(self):
        five = 0
        best_w = best_r = 0
        for k, w in self.inn_wkts.items():
            if w >= 5:
                five += 1
            r = self.inn_runs.get(k, 0)
            if w > best_w or (w == best_w and r < best_r):
                best_w, best_r = w, r
        return [len(self.matches), len(self.innings), self.wickets,
                self.balls, self.runs, five, best_w, best_r]


def dismissal_line(kind, bowler, fielders):
    if kind == "run out":
        f = f" ({' / '.join(fielders)})" if fielders else ""
        return f"run out{f}"
    if kind == "bowled":
        return f"b {bowler}"
    if kind == "lbw":
        return f"lbw b {bowler}"
    if kind == "stumped":
        f = f" {fielders[0]}" if fielders else ""
        return f"st{f} b {bowler}"
    if kind == "caught":
        f = f" {fielders[0]}" if fielders else ""
        return f"c{f} b {bowler}"
    return f"{kind} b {bowler}"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("zips", nargs="+")
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    players = {}  # short -> dict(team, bat{}, bowl{}, dis{}, pairs{})
    seen_ids = set()
    meta_matches = 0
    years = []
    dates_seen = []
    # H2H index: (teamSorted0, teamSorted1, fmt, gender) -> counts.
    h2h = defaultdict(lambda: [0, 0, 0, 0])
    # Venue totals: (venue, genderOrALL) -> running totals.
    ven_tot = {}

    def ven_acc(venue, gender):
        key = (venue, gender)
        a = ven_tot.get(key)
        if a is None:
            a = {"matches": 0, "firstSum": 0, "firstCount": 0,
                 "secondSum": 0, "secondCount": 0, "highest": 0,
                 "batFirstWins": 0, "decided": 0, "city": ""}
            ven_tot[key] = a
        return a

    def player(short):
        p = players.get(short)
        if p is None:
            p = {"team": "", "bat": defaultdict(Bat),
                 "bowl": defaultdict(Bowl), "dis": defaultdict(int),
                 "pairs": {}}
            players[short] = p
        return p

    for zpath in args.zips:
        z = zipfile.ZipFile(zpath)
        for name in z.namelist():
            if not name.endswith(".json"):
                continue
            file_id = name.rsplit("/", 1)[-1]
            if file_id in seen_ids:
                continue
            try:
                d = json.loads(z.read(name))
            except Exception:
                continue
            info = d.get("info", {})
            innings = d.get("innings", [])
            if not innings:
                continue
            seen_ids.add(file_id)
            meta_matches += 1
            dates = info.get("dates") or []
            if dates:
                years.append(str(dates[0])[:4])
                dates_seen.append(str(dates[0])[:10])
            fmt = norm_format(info.get("match_type", ""))
            venue = info.get("venue", "") or ""
            city = info.get("city", "") or ""
            gender = info.get("gender", "") or ""
            winner = (info.get("outcome") or {}).get("winner", "") or ""
            # Per-match innings totals (delivery sums) for the venue
            # index; first innings batting team for bat-first wins.
            inn_totals = {}
            first_batting = innings[0].get("team", "") if innings else ""
            event = (info.get("event") or {}).get("name", "") or ""
            league = league_for_event(event)
            teams = info.get("teams", []) or []
            players_by_team = info.get("players", {}) or {}

            # XI membership -> batting matches in every scope.
            for team, shorts in players_by_team.items():
                opp = next((t for t in teams if t != team), "")
                for short in shorts:
                    p = player(short)
                    if not p["team"]:
                        p["team"] = team
                    for scope in ("all", f"fmt:{fmt}", f"opp:{opp}",
                                  f"ven:{venue}", f"lg:{league}"):
                        p["bat"][scope].matches.add(file_id)

            for ii, inn in enumerate(innings):
                batting_team = inn.get("team", "")
                bowling_team = next((t for t in teams if t != batting_team),
                                    "")
                for over in inn.get("overs", []) or []:
                    for dlv in over.get("deliveries", []) or []:
                        batter = dlv.get("batter", "")
                        bowler = dlv.get("bowler", "")
                        runs = dlv.get("runs", {}) or {}
                        extras = dlv.get("extras", {}) or {}
                        br = runs.get("batter", 0) or 0
                        total = runs.get("total", 0) or 0
                        wides = extras.get("wides", 0) or 0
                        noballs = extras.get("noballs", 0) or 0
                        byes = extras.get("byes", 0) or 0
                        legbyes = extras.get("legbyes", 0) or 0
                        inn_key = f"{file_id}:{ii}"
                        inn_totals[ii] = inn_totals.get(ii, 0) + total
                        bat_scopes = ("all", f"fmt:{fmt}",
                                      f"opp:{bowling_team}",
                                      f"ven:{venue}", f"lg:{league}")
                        bowl_scopes = ("all", f"fmt:{fmt}",
                                       f"opp:{batting_team}",
                                       f"ven:{venue}", f"lg:{league}")
                        # Batting.
                        pb = player(batter)
                        for s in bat_scopes:
                            a = pb["bat"][s]
                            a.matches.add(file_id)
                            a.innings.add(inn_key)
                            a.inn_runs[inn_key] = \
                                a.inn_runs.get(inn_key, 0) + br
                            if not wides:
                                a.balls += 1
                            a.runs += br
                            if br == 4:
                                a.fours += 1
                            if br == 6:
                                a.sixes += 1
                        # Wickets.
                        wkts = dlv.get("wickets", []) or []
                        if wkts:
                            w = wkts[0]
                            kind = w.get("kind", "")
                            out = w.get("player_out", "")
                            fielders = [(f.get("name", ""))
                                        for f in (w.get("fielders") or [])]
                            if out and out != batter:
                                po = player(out)
                                for s in bat_scopes:
                                    a = po["bat"][s]
                                    a.matches.add(file_id)
                                    a.innings.add(inn_key)
                                    a.inn_runs.setdefault(inn_key, 0)
                                    a.dismissals += 1
                            if out == batter:
                                for s in bat_scopes:
                                    pb["bat"][s].dismissals += 1
                            # Bowling (charged = total - byes - legbyes).
                            pbo = player(bowler)
                            charged = total - byes - legbyes
                            legal = not wides and not noballs
                            for s in bowl_scopes:
                                a = pbo["bowl"][s]
                                a.matches.add(file_id)
                                a.innings.add(inn_key)
                                if legal:
                                    a.balls += 1
                                a.runs += charged
                                a.inn_runs[inn_key] = \
                                    a.inn_runs.get(inn_key, 0) + charged
                                if kind in BOWLER_CREDITED:
                                    a.wickets += 1
                                    a.inn_wkts[inn_key] = \
                                        a.inn_wkts.get(inn_key, 0) + 1
                            # Dismissal history + pair.
                            if out == batter:
                                line = dismissal_line(kind, bowler, fielders)
                                pb["dis"][line] += 1
                        else:
                            pbo = player(bowler)
                            charged = total - byes - legbyes
                            legal = not wides and not noballs
                            for s in bowl_scopes:
                                a = pbo["bowl"][s]
                                a.matches.add(file_id)
                                a.innings.add(inn_key)
                                if legal:
                                    a.balls += 1
                                a.runs += charged
                                a.inn_runs[inn_key] = \
                                    a.inn_runs.get(inn_key, 0) + charged
                        # Bowler-vs-batter pair (balls exclude wides,
                        # runs charged to bowler, as in Dart code).
                        pbo = player(bowler)
                        pair = pbo["pairs"].get(batter)
                        if pair is None:
                            pair = [set(), 0, 0, 0]
                            pbo["pairs"][batter] = pair
                        pair[0].add(file_id)
                        if not wides:
                            pair[1] += 1
                        pair[2] += total - byes - legbyes
                        if wkts and wkts[0].get("player_out") == batter \
                                and wkts[0].get("kind") in BOWLER_CREDITED:
                            pair[3] += 1

            # ---- H2H + venue indexes for this match ----------------
            # (A missing info.gender contributes only to ALL keys.)
            genders = (gender, "ALL") if gender else ("ALL",)
            if len(teams) == 2:
                t_sorted = sorted(teams)
                for f2 in (fmt, "ALL"):
                    for g2 in genders:
                        c = h2h[(t_sorted[0], t_sorted[1], f2, g2)]
                        c[0] += 1
                        if winner == t_sorted[0]:
                            c[1] += 1
                        elif winner == t_sorted[1]:
                            c[2] += 1
                        else:
                            c[3] += 1
            if venue:
                first = inn_totals.get(0)
                second = inn_totals.get(1)
                for g2 in genders:
                    a = ven_acc(venue, g2)
                    a["matches"] += 1
                    if not a["city"] and city:
                        a["city"] = city
                    if first is not None:
                        a["firstSum"] += first
                        a["firstCount"] += 1
                        if first > a["highest"]:
                            a["highest"] = first
                    if second is not None:
                        a["secondSum"] += second
                        a["secondCount"] += 1
                        if second > a["highest"]:
                            a["highest"] = second
                    if winner and first_batting:
                        a["decided"] += 1
                        if winner == first_batting:
                            a["batFirstWins"] += 1
        z.close()

    out_players = {}
    for short, p in players.items():
        bat = {}
        for scope, a in p["bat"].items():
            # Career "all" always emitted (XI-match count); other
            # scopes only when the player actually batted there.
            if scope == "all" or a.innings:
                bat[scope] = a.emit()
        bowl = {}
        for scope, a in p["bowl"].items():
            if a.innings:
                bowl[scope] = a.emit()
        if not bat and not bowl:
            continue
        entry = {"team": p["team"], "bat": bat, "bowl": bowl}
        if p["dis"]:
            entry["dis"] = dict(p["dis"])
        if p["pairs"]:
            # Matchup pairs need a meaningful sample: a pair with
            # fewer than 12 balls is noise, and the UI only ever
            # shows the top few pairs per batter. Totals are
            # unaffected by this filter (pairs are not totals).
            entry["pairs"] = {b: [len(v[0]), v[1], v[2], v[3]]
                              for b, v in p["pairs"].items() if v[1] >= 12}
        out_players[short] = entry

    # ---- Venue index: totals + top players per venue -------------
    # Top players come from the per-player ven: scopes (all-gender);
    # totals are gender-rolled (ALL + per-gender when present).
    ven_bat = defaultdict(list)  # venue -> [(short, runs, matches)]
    ven_bowl = defaultdict(list)  # venue -> [(short, wkts, matches)]
    for short, p in players.items():
        for scope, a in p["bat"].items():
            if scope.startswith("ven:") and a.innings:
                ven_bat[scope[4:]].append(
                    (short, a.runs, len(a.matches)))
        for scope, a in p["bowl"].items():
            if scope.startswith("ven:") and a.innings:
                ven_bowl[scope[4:]].append(
                    (short, a.wickets, len(a.matches)))

    def ven_totals(a):
        return {
            "matches": a["matches"],
            "avgFirst": round(a["firstSum"] / a["firstCount"], 2)
            if a["firstCount"] else 0,
            "avgSecond": round(a["secondSum"] / a["secondCount"], 2)
            if a["secondCount"] else 0,
            "highest": a["highest"],
            "batFirstWinPct": round(a["batFirstWins"] * 100 / a["decided"], 1)
            if a["decided"] else 0,
        }

    out_venues = {}
    for (venue, g), a in ven_tot.items():
        if g != "ALL":
            continue
        entry = ven_totals(a)
        entry["city"] = a["city"]
        entry["topBatters"] = [
            [s, r, m] for s, r, m in sorted(
                ven_bat.get(venue, []),
                key=lambda t: (-t[1], -t[2], t[0]))[:10]]
        entry["topBowlers"] = [
            [s, w, m] for s, w, m in sorted(
                ven_bowl.get(venue, []),
                key=lambda t: (-t[1], -t[2], t[0]))[:10]]
        by_gender = {}
        for g2 in ("male", "female"):
            ga = ven_tot.get((venue, g2))
            if ga is not None and ga["matches"]:
                by_gender[g2] = ven_totals(ga)
        if by_gender:
            entry["byGender"] = by_gender
        out_venues[venue] = entry

    out_h2h = {"|".join(k): v for k, v in h2h.items()}

    import datetime
    out = {
        "meta": {
            "matches": meta_matches,
            "yearMin": min(years) if years else "",
            "yearMax": max(years) if years else "",
            # Latest match date in the base: delta pruning drops
            # finished-match deltas dated <= coverageEnd, because
            # a regenerated base already contains those matches.
            "coverageEnd": max(dates_seen) if dates_seen else "",
            "generated": datetime.date.today().isoformat(),
            "source": "Cricsheet open data (cricsheet.org)",
            "inputs": [z.rsplit("/", 1)[-1] for z in args.zips],
            "scope": "men's + women's internationals, Test/ODI/T20; "
                     "domestic + franchise leagues excluded",
            "indexes": ["h2h", "venues"],
        },
        "players": out_players,
        "h2h": out_h2h,
        "venues": out_venues,
    }
    with open(args.out, "w") as f:
        json.dump(out, f, separators=(",", ":"), sort_keys=True)
    print(f"matches={meta_matches} players={len(out_players)} "
          f"h2h={len(out_h2h)} venues={len(out_venues)} "
          f"years={min(years) if years else ''}-{max(years) if years else ''}")


if __name__ == "__main__":
    main()
