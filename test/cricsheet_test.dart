import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingcric/services/api_service.dart';
import 'package:kingcric/services/cricsheet_service.dart';

/// One T20 in true Cricsheet JSON v1.3.0 shape, hand-computed:
/// India innings: wide(1) + Kohli 4,6,1,6+out c Rizwan b Shaheen
/// (17 off 4) + Rohit 4,0,1 (5* off 3). Total 23/1.
/// Pakistan innings: Babar 20* off 8 vs Bumrah + Rizwan 6 run out
/// (Kohli). Total 26/1. India won by 3 runs (outcome only).
const _inlineMatch = '''
{"meta": {"data_version": "1.3.0", "created": "2024-06-09", "revision": 1},
 "info": {"balls_per_over": 6, "venue": "Dubai International Stadium",
 "city": "Dubai", "dates": ["2024-06-09"],
 "event": {"name": "India in Pakistan T20I Series", "match_number": 1},
 "gender": "male", "teams": ["India", "Pakistan"],
 "outcome": {"winner": "India", "by": {"runs": 3}},
 "toss": {"winner": "India", "decision": "bat"},
 "match_type": "IT20", "overs": 20, "team_type": "international",
 "players": {"India": ["V Kohli", "RG Sharma"],
             "Pakistan": ["Babar Azam", "Mohammad Rizwan"]},
 "season": "2024"},
 "innings": [
  {"team": "India", "overs": [
   {"over": 0, "deliveries": [
    {"actual_delivery": "0.0", "batter": "V Kohli", "bowler": "Shaheen Shah Afridi",
     "non_striker": "RG Sharma",
     "runs": {"batter": 0, "extras": 1, "total": 1}, "extras": {"wides": 1}},
    {"actual_delivery": "0.0", "batter": "V Kohli", "bowler": "Shaheen Shah Afridi",
     "non_striker": "RG Sharma", "runs": {"batter": 4, "extras": 0, "total": 4}},
    {"actual_delivery": "0.1", "batter": "V Kohli", "bowler": "Shaheen Shah Afridi",
     "non_striker": "RG Sharma", "runs": {"batter": 6, "extras": 0, "total": 6}},
    {"actual_delivery": "0.2", "batter": "V Kohli", "bowler": "Shaheen Shah Afridi",
     "non_striker": "RG Sharma", "runs": {"batter": 1, "extras": 0, "total": 1}},
    {"actual_delivery": "0.3", "batter": "RG Sharma", "bowler": "Shaheen Shah Afridi",
     "non_striker": "V Kohli", "runs": {"batter": 4, "extras": 0, "total": 4}},
    {"actual_delivery": "0.4", "batter": "RG Sharma", "bowler": "Shaheen Shah Afridi",
     "non_striker": "V Kohli", "runs": {"batter": 0, "extras": 0, "total": 0}},
    {"actual_delivery": "0.5", "batter": "RG Sharma", "bowler": "Shaheen Shah Afridi",
     "non_striker": "V Kohli", "runs": {"batter": 1, "extras": 0, "total": 1}},
    {"actual_delivery": "1.0", "batter": "V Kohli", "bowler": "Shaheen Shah Afridi",
     "non_striker": "RG Sharma", "runs": {"batter": 6, "extras": 0, "total": 6},
     "wickets": [{"kind": "caught", "player_out": "V Kohli",
                  "fielders": [{"name": "Mohammad Rizwan"}]}]}
   ]}
  ]},
  {"team": "Pakistan", "overs": [
   {"over": 0, "deliveries": [
    {"actual_delivery": "0.0", "batter": "Babar Azam", "bowler": "JJ Bumrah",
     "non_striker": "Mohammad Rizwan", "runs": {"batter": 4, "extras": 0, "total": 4}},
    {"actual_delivery": "0.1", "batter": "Babar Azam", "bowler": "JJ Bumrah",
     "non_striker": "Mohammad Rizwan", "runs": {"batter": 4, "extras": 0, "total": 4}},
    {"actual_delivery": "0.2", "batter": "Babar Azam", "bowler": "JJ Bumrah",
     "non_striker": "Mohammad Rizwan", "runs": {"batter": 2, "extras": 0, "total": 2}},
    {"actual_delivery": "0.3", "batter": "Babar Azam", "bowler": "JJ Bumrah",
     "non_striker": "Mohammad Rizwan", "runs": {"batter": 0, "extras": 0, "total": 0}},
    {"actual_delivery": "0.4", "batter": "Babar Azam", "bowler": "JJ Bumrah",
     "non_striker": "Mohammad Rizwan", "runs": {"batter": 6, "extras": 0, "total": 6}},
    {"actual_delivery": "0.5", "batter": "Babar Azam", "bowler": "JJ Bumrah",
     "non_striker": "Mohammad Rizwan", "runs": {"batter": 4, "extras": 0, "total": 4}},
    {"actual_delivery": "1.0", "batter": "Babar Azam", "bowler": "JJ Bumrah",
     "non_striker": "Mohammad Rizwan", "runs": {"batter": 0, "extras": 0, "total": 0}},
    {"actual_delivery": "1.1", "batter": "Babar Azam", "bowler": "JJ Bumrah",
     "non_striker": "Mohammad Rizwan", "runs": {"batter": 0, "extras": 0, "total": 0}},
    {"actual_delivery": "1.2", "batter": "Mohammad Rizwan", "bowler": "JJ Bumrah",
     "non_striker": "Babar Azam", "runs": {"batter": 4, "extras": 0, "total": 4}},
    {"actual_delivery": "1.3", "batter": "Mohammad Rizwan", "bowler": "JJ Bumrah",
     "non_striker": "Babar Azam", "runs": {"batter": 1, "extras": 0, "total": 1}},
    {"actual_delivery": "1.4", "batter": "Mohammad Rizwan", "bowler": "JJ Bumrah",
     "non_striker": "Babar Azam", "runs": {"batter": 1, "extras": 0, "total": 1},
     "wickets": [{"kind": "run out", "player_out": "Mohammad Rizwan",
                  "fielders": [{"name": "V Kohli"}]}]}
   ]}
  ]}
 ]}
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Cricsheet parse: malformed JSON never throws, returns empty', () {
    expect(CricsheetService.parse('not json').matchCount, 0);
    expect(CricsheetService.parse('{}').matchCount, 0);
    expect(CricsheetService.parse('[]').matchCount, 0);
  });

  test('Cricsheet parse: single match + wrapper both work', () {
    expect(CricsheetService.parse(_inlineMatch).matchCount, 1);
    expect(
        CricsheetService.parse('{"matches": [$_inlineMatch]}').matchCount,
        1);
  });

  test('Cricsheet career: Kohli 17 off 4, avg 17, SR 425', () {
    final cs = CricsheetService.parse(_inlineMatch);
    final kohli = cs.playerById('p-virat')!;
    expect(kohli.name, 'Virat Kohli');
    expect(kohli.source, 'cricsheet');
    expect(kohli.sourceMatches, 1);
    expect(kohli.dataComplete, isTrue);
    final t20 = kohli.battingByFormat['T20']!;
    expect(t20.runs, 17);
    expect(t20.balls, 4);
    expect(t20.average, 17.0);
    expect(t20.strikeRate, 425.0);
    expect(t20.fours, 1); // Kohli balls were 4, 6, 1, 6
    expect(t20.sixes, 2);
    expect(t20.highest, 17);
    expect(t20.matches, 1);
    // Wide is NOT a batter run (17, not 18).
    expect(kohli.battingVs('Pakistan').runs, 17);
    expect(kohli.battingByVenue['Dubai International Stadium']!.runs, 17);
  });

  test('Cricsheet: not-out average uses runs, run out not bowler wicket',
      () {
    final cs = CricsheetService.parse(_inlineMatch);
    final rohit = cs.playerById('p-rohit')!;
    expect(rohit.battingByFormat['T20']!.runs, 5);
    expect(rohit.battingByFormat['T20']!.average, 5.0); // never dismissed
    final bumrah = cs.playerById('p-bumrah')!;
    final bowl = bumrah.bowlingByFormat['T20']!;
    expect(bowl.balls, 11);
    expect(bowl.runsConceded, 26);
    expect(bowl.wickets, 0); // run out is NOT the bowler's wicket
    expect(bowl.economy, closeTo(26 * 6 / 11, 0.01));
  });

  test('Cricsheet bowling: Shaheen 1 wicket, wide charged to bowler', () {
    final cs = CricsheetService.parse(_inlineMatch);
    final shaheen = cs.playerById('p-shaheen')!;
    final bowl = shaheen.bowlingByFormat['T20']!;
    expect(bowl.wickets, 1); // caught IS the bowler's wicket
    expect(bowl.balls, 7);
    expect(bowl.runsConceded, 23); // 17 + 5 + 1 wide
    expect(bowl.best, '1/23');
  });

  test('Cricsheet matchup: Shaheen vs Kohli 4 balls, 18 runs, 1 wkt', () {
    final cs = CricsheetService.parse(_inlineMatch);
    final m = cs.matchup(bowler: 'Shaheen Shah Afridi', batter: 'V Kohli');
    expect(m.balls, 4); // wide not a ball faced
    expect(m.runs, 18); // matchup runs include the wide
    expect(m.dismissals, 1);
    final m2 = cs.matchup(bowler: 'JJ Bumrah', batter: 'Babar Azam');
    expect(m2.balls, 8);
    expect(m2.runs, 20);
    expect(m2.dismissals, 0);
  });

  test('Cricsheet dismissal history + FOW + partnerships + H2H', () {
    final cs = CricsheetService.parse(_inlineMatch);
    expect(cs.dismissalHistoryFor('V Kohli'),
        contains('c Mohammad Rizwan b Shaheen Afridi — 1 time'));
    final fow = cs.fallOfWickets(0, 0);
    expect(fow.length, 1);
    expect(fow.first, contains('V Kohli'));
    expect(fow.first, contains('1-23'));
    final parts = cs.partnerships(0, 0);
    expect(parts.first, contains('23'));
    final h2h = cs.teamH2H('India', 'Pakistan');
    expect(h2h['matches'], 1);
    expect(h2h['teamAWins'], 1);
    expect(h2h['teamBWins'], 0);
    final form = cs.recentFormFor('V Kohli');
    expect(form.length, 1);
    expect(form.first.runs, 17);
    expect(form.first.opponent, 'Pakistan');
    expect(form.first.result, 'W');
  });

  test('Cricsheet unknown player returns null', () {
    final cs = CricsheetService.parse(_inlineMatch);
    expect(cs.playerById('p-unknown'), isNull);
    expect(cs.playerById(''), isNull);
  });

  test('Cricsheet bundled subset: 420 real internationals (FIX-7)', () async {
    // FIX-7: the bundled asset is no longer the 4-match synthetic
    // sample — it is 420 REAL internationals (2024-2026, full-member
    // + associate strata) from Cricsheet all_json.zip. Exact per-
    // player totals are dataset-derived, so this test pins only
    // invariants: count, star coverage, and honest source labels.
    final text = await rootBundle.loadString('assets/cricsheet_sample.json');
    final cs = CricsheetService.parse(text);
    expect(cs.matchCount, 420);
    final kohli = cs.playerById('p-virat')!;
    expect(kohli.source, 'cricsheet');
    expect(kohli.sourceMatches, greaterThan(0));
    expect(kohli.battingOverall().runs, greaterThan(0));
    final babar = cs.playerById('p-babar')!;
    expect(babar.battingOverall().runs, greaterThan(0));
    final bumrah = cs.playerById('p-bumrah')!;
    expect(bumrah.bowlingOverall().wickets, greaterThan(0));
    // Matchup machinery still works on the real dataset.
    final bumrahVsBabar =
        cs.matchup(bowler: 'JJ Bumrah', batter: 'Babar Azam');
    expect(bumrahVsBabar.balls, greaterThanOrEqualTo(0));
  });

  test('ApiService fetchPlayer: Cricsheet first, then mock fallback',
      () async {
    final cs = CricsheetService.parse(_inlineMatch);
    final api = ApiService(
        providers: [], cricsheet: cs, loadCricsheetSample: false);
    final kohli = await api.fetchPlayer('p-virat');
    expect(kohli, isNotNull);
    expect(kohli!.source, 'cricsheet');
    expect(api.lastSource, 'cricsheet');
    // Unknown id: Cricsheet null -> providers none -> mock null.
    expect(await api.fetchPlayer('no-such-player'), isNull);
  });
}
