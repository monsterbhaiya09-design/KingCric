import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingcric/services/api_service.dart';
import 'package:kingcric/services/cricsheet_service.dart';

/// CRICSHEET-WIRING: the 420-match dataset must actually reach the
/// Squad / H2H / Venue / Matchups UI — not just exist in the asset.
/// These tests pin the wiring against the REAL bundled dataset:
/// Pakistan vs Sri Lanka squads, H2H, Rawalpindi venue, cross-squad
/// matchups, and non-identity (non-44) players.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CricsheetService cs;

  setUpAll(() async {
    final text = await rootBundle.loadString('assets/cricsheet_sample.json');
    cs = CricsheetService.parse(text);
    expect(cs.matchCount, 420);
  });

  test('squadForTeams: Pakistan AND Sri Lanka both get real squads', () {
    final squads = cs.squadForTeams('Pakistan', 'Sri Lanka');
    final pak = squads['Pakistan']!;
    final sl = squads['Sri Lanka']!;
    // The pre-wiring bug: Pakistan = 2 Demo players, Sri Lanka = 0.
    expect(pak, isNotEmpty);
    expect(sl, isNotEmpty);
    expect(pak.length, lessThanOrEqualTo(20));
    expect(sl.length, lessThanOrEqualTo(20));
    for (final p in [...pak, ...sl]) {
      expect(p.source, 'cricsheet');
      expect(p.dataComplete, isTrue);
      expect(p.id.startsWith('scorecard-'), isFalse);
    }
    expect(pak.any((p) => p.name == 'Babar Azam'), isTrue);
    // Real stats: Babar has runs in the dataset.
    final babar = pak.firstWhere((p) => p.name == 'Babar Azam');
    expect(babar.battingOverall().runs, greaterThan(0));
  });

  test('squadForTeams: men and women are NOT mixed', () {
    // The dataset stores both genders under "Pakistan" — without
    // the gender filter the men's top-20 filled with women's
    // players and Babar was pushed out entirely.
    final men = cs.squadForTeams('Pakistan', 'Sri Lanka');
    expect(
        men['Pakistan']!.any((p) => p.name == 'Aliya Riaz'), isFalse);
    expect(men['Pakistan']!.any((p) => p.name == 'Babar Azam'), isTrue);
    final women =
        cs.squadForTeams('Pakistan Women', 'Sri Lanka Women');
    expect(women['Pakistan Women'], isNotEmpty);
    expect(
        women['Pakistan Women']!.any((p) => p.name == 'Aliya Riaz'),
        isTrue);
    expect(
        women['Pakistan Women']!.any((p) => p.name == 'Babar Azam'),
        isFalse);
    // Gender-filtered H2H never exceeds the pooled total.
    final pooled = cs.teamHeadToHead('Pakistan', 'Sri Lanka');
    final menH2H = cs.teamHeadToHead('Pakistan', 'Sri Lanka',
        gender: 'male');
    expect(menH2H['matches'], lessThanOrEqualTo(pooled['matches'] ?? 0));
    expect(menH2H['matches'], greaterThan(0));
  });

  test('squadForTeams: vs-opponent split comes from Cricsheet', () {
    final squads = cs.squadForTeams('Pakistan', 'Sri Lanka');
    final babar =
        squads['Pakistan']!.firstWhere((p) => p.name == 'Babar Azam');
    // Babar faced Sri Lanka in the 2025-2026 window (Asia Cup etc.).
    final vs = babar.battingVs('Sri Lanka');
    expect(vs.matches, greaterThan(0));
    expect(vs.runs, greaterThan(0));
    // The Squad card reads exactly this split — no "no data yet"
    // when the dataset genuinely has the matchup.
    expect(babar.battingVsOpponent.containsKey('Sri Lanka'), isTrue);
  });

  test('teamHeadToHead: Pak vs SL reconciles, format filter works', () {
    final h2h = cs.teamHeadToHead('Pakistan', 'Sri Lanka');
    expect(h2h['matches'], greaterThan(0));
    expect(
        h2h['teamAWins']! + h2h['teamBWins']! + h2h['noResult']!,
        h2h['matches']);
    // Same numbers via the legacy entry point.
    expect(cs.teamH2H('Pakistan', 'Sri Lanka'), h2h);
    // Format filter never inflates the total.
    final t20 = cs.teamHeadToHead('Pakistan', 'Sri Lanka', format: 'T20');
    expect(t20['matches'], lessThanOrEqualTo(h2h['matches'] ?? 0));
  });

  test('venueStats: Rawalpindi fuzzy-matches and reconciles', () {
    final v1 = cs.venueStats('Rawalpindi Cricket Stadium');
    final v2 = cs.venueStats('Rawalpindi Cricket Stadium, Rawalpindi');
    expect(v1, isNotNull);
    expect(v2, isNotNull);
    expect(v1!.matches, v2!.matches);
    expect(v1.matches, greaterThan(0));
    expect(v1.avgFirstInnings, greaterThan(0));
    expect(v1.avgSecondInnings, greaterThan(0));
    expect(v1.highestTotal, greaterThanOrEqualTo(v1.avgFirstInnings));
    expect(v1.batFirstWinPct, inInclusiveRange(0, 100));
    expect(cs.venueStats('Nowhere Cricket Ground XYZ'), isNull);
  });

  test('crossSquadMatchups: Pak vs SL pairs are cross-squad + real', () {
    final squads = cs.squadForTeams('Pakistan', 'Sri Lanka');
    final pak = squads['Pakistan']!;
    final sl = squads['Sri Lanka']!;
    final matchups = cs.crossSquadMatchups(pak, sl);
    expect(matchups, isNotEmpty);
    final pakNames = pak.map((p) => p.name).toSet();
    final slNames = sl.map((p) => p.name).toSet();
    for (final m in matchups) {
      expect(m.balls, greaterThan(0));
      final bowlerInPak = pakNames.contains(m.bowlerName);
      final bowlerInSl = slNames.contains(m.bowlerName);
      final batterInPak = pakNames.contains(m.batterName);
      final batterInSl = slNames.contains(m.batterName);
      // Bowler in one squad, batter in the other — never same-team.
      expect(bowlerInPak != bowlerInSl, isTrue);
      expect(batterInPak != batterInSl, isTrue);
      expect(bowlerInPak != batterInPak, isTrue);
      // Reproducible through the single-pair query.
      final single = cs.matchup(bowler: m.bowlerName, batter: m.batterName);
      expect(single.balls, m.balls);
      expect(single.dismissals, m.dismissals);
    }
    // Sorted dismissals desc, then balls desc.
    for (var i = 1; i < matchups.length; i++) {
      expect(
          matchups[i].dismissals <= matchups[i - 1].dismissals, isTrue);
    }
  });

  test('non-identity dataset players build real profiles', () {
    final squads = cs.squadForTeams('Pakistan', 'Sri Lanka');
    final all = [...squads['Pakistan']!, ...squads['Sri Lanka']!];
    // Players outside the 44-name identity map get 'cs-...' ids.
    final generic = all.where((p) => p.id.startsWith('cs-')).toList();
    expect(generic, isNotEmpty);
    final p = generic.first;
    // Round-trip: cs- id -> short name -> full profile.
    final short = cs.resolveShortName(p.id);
    expect(short, isNotNull);
    final again = cs.playerById(p.id);
    expect(again, isNotNull);
    expect(again!.source, 'cricsheet');
    expect(again.name, p.name);
  });

  test('ApiService: cricsheetSquadsFor / H2H / venue / matchups', () async {
    final api = ApiService(
        providers: [], cricsheet: cs, loadCricsheetSample: false);
    final squads =
        await api.cricsheetSquadsFor('Pakistan', 'Sri Lanka');
    expect(squads['Pakistan'], isNotEmpty);
    expect(squads['Sri Lanka'], isNotEmpty);
    final h2h = await api.cricsheetHeadToHead('Pakistan', 'Sri Lanka');
    expect(h2h['matches'], greaterThan(0));
    final venue = await api.cricsheetVenueStats('Rawalpindi Cricket Stadium');
    expect(venue, isNotNull);
    final matchups = await api.cricsheetCrossMatchups(
        squads['Pakistan']!, squads['Sri Lanka']!);
    expect(matchups, isNotEmpty);
    // Unknown team -> empty, never invented.
    final unknown = await api.cricsheetSquadsFor('Nowhere XI', 'Pakistan');
    expect(unknown['Nowhere XI'], isEmpty);
    expect(unknown['Pakistan'], isNotEmpty);
  });

  test('resolveShortName: full name + short name + cs- id all work', () {
    expect(cs.resolveShortName('Virat Kohli'), 'V Kohli');
    expect(cs.resolveShortName('V Kohli'), 'V Kohli');
    expect(cs.resolveShortName('p-virat'), 'V Kohli');
    expect(cs.resolveShortName('p-unknown'), isNull);
    expect(cs.resolveShortName(''), isNull);
  });
}
