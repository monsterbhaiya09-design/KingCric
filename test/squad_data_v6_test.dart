import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingcric/services/cricsheet_service.dart';

// Squad DATA v6: provider-name resolution + full-archive H2H /
// venue indexes. Every test here uses INLINE aggregate data except
// the final group, which loads the REAL regenerated
// assets/cricsheet_stats.json and proves the production numbers
// (UAE vs Netherlands H2H, ICC Academy venue, associate-name
// resolution) against the shipped asset.
CricsheetService _inlineService() {
  const aggJson = '''
{"meta": {"matches": 9943, "yearMin": "2001", "yearMax": "2026",
          "coverageEnd": "2026-10-14", "source": "Cricsheet"},
 "players": {
  "R Chopra": {"team": "United Arab Emirates",
    "bat": {"all": [63, 57, 1392, 1493, 109, 40, 49, 6, 3, 127],
            "ven:ICC Academy, Dubai": [4, 4, 151, 172, 11, 7, 4, 1, 0, 78]},
    "bowl": {}, "dis": {}, "pairs": {}},
  "Waseem Muhammad": {"team": "United Arab Emirates",
    "bat": {"all": [100, 95, 3000, 2800, 300, 50, 100, 20, 5, 140],
            "ven:ICC Academy, Dubai": [13, 13, 455, 400, 40, 10, 20, 5, 1, 110]},
    "bowl": {}, "dis": {}, "pairs": {}},
  "MP O'Dowd": {"team": "Netherlands",
    "bat": {"all": [158, 158, 4514, 4916, 456, 92, 144, 30, 2, 158]},
    "bowl": {}, "dis": {}, "pairs": {}},
  "B de Leede": {"team": "Netherlands",
    "bat": {"all": [110, 105, 2095, 2256, 232, 10, 91, 12, 0, 82]},
    "bowl": {}, "dis": {}, "pairs": {}},
  "BFW de Leede": {"team": "Netherlands",
    "bat": {"all": [103, 92, 2217, 2643, 162, 52, 77, 12, 1, 123]},
    "bowl": {}, "dis": {}, "pairs": {}},
  "SA Edwards": {"team": "Netherlands",
    "bat": {"all": [153, 140, 3439, 3509, 251, 51, 109, 23, 0, 99]},
    "bowl": {}, "dis": {}, "pairs": {}},
  "FJ Klaassen": {"team": "Netherlands",
    "bat": {"all": [40, 30, 200, 150, 10, 1, 5, 0, 0, 40]},
    "bowl": {"all": [60, 60, 70, 1500, 1200, 2, 5, 28]}, "dis": {}, "pairs": {}},
  "PA van Meekeren": {"team": "Netherlands",
    "bat": {"all": [50, 40, 300, 250, 20, 2, 10, 0, 0, 50]},
    "bowl": {"all": [70, 70, 90, 1800, 1500, 1, 5, 30]}, "dis": {}, "pairs": {}},
  "CN Ackermann": {"team": "Netherlands",
    "bat": {"all": [90, 85, 2500, 2400, 200, 40, 80, 10, 2, 130]},
    "bowl": {}, "dis": {}, "pairs": {}},
  "NRJ Croes": {"team": "Netherlands",
    "bat": {"all": [30, 28, 800, 750, 60, 10, 20, 2, 0, 90]},
    "bowl": {}, "dis": {}, "pairs": {}},
  "A Sharma": {"team": "India",
    "bat": {"all": [60, 58, 1800, 1700, 150, 30, 60, 10, 1, 120]},
    "bowl": {}, "dis": {}, "pairs": {}},
  "AB Sharma": {"team": "India",
    "bat": {"all": [40, 38, 900, 850, 70, 10, 30, 2, 0, 80]},
    "bowl": {}, "dis": {}, "pairs": {}},
  "Aarsheya Sharma": {"team": "Singapore",
    "bat": {"all": [20, 18, 400, 380, 30, 2, 10, 0, 0, 60]},
    "bowl": {}, "dis": {}, "pairs": {}},
  "MA Khan": {"team": "Pakistan",
    "bat": {"all": [70, 65, 2000, 1900, 150, 20, 50, 5, 1, 110]},
    "bowl": {}, "dis": {}, "pairs": {}},
  "Matiullah Khan": {"team": "United Arab Emirates",
    "bat": {"all": [45, 42, 1100, 1000, 80, 10, 30, 1, 0, 90]},
    "bowl": {}, "dis": {}, "pairs": {}}
 },
 "h2h": {
  "Netherlands|United Arab Emirates|ODI|male": [4, 3, 1, 0],
  "Netherlands|United Arab Emirates|ODI|ALL": [4, 3, 1, 0],
  "Netherlands|United Arab Emirates|ALL|ALL": [15, 9, 5, 1]
 },
 "venues": {
  "ICC Academy, Dubai": {"city": "Dubai", "matches": 42,
    "avgFirst": 156.1, "avgSecond": 139.45, "highest": 273,
    "batFirstWinPct": 54.8,
    "topBatters": [["Waseem Muhammad", 455, 13], ["R Chopra", 151, 4]],
    "topBowlers": [["Junaid Siddique", 19, 10]],
    "byGender": {"male": {"matches": 28, "avgFirst": 166.54,
      "avgSecond": 157.21, "highest": 273, "batFirstWinPct": 42.9}}}
 }}
''';
  final sample = CricsheetService.parse('{"matches": []}');
  return CricsheetService(sample.matches,
      aggregate: CricsheetAggregate.parse(aggJson));
}

void main() {
  group('name resolution (associate examples)', () {
    test('every verified provider name resolves to its Cricsheet key',
        () {
      final cs = _inlineService();
      expect(cs.resolveShortNameForTeam('Rahul Chopra',
              'United Arab Emirates'),
          'R Chopra');
      // Token order swapped: provider "Muhammad Waseem" is stored
      // as "Waseem Muhammad".
      expect(cs.resolveShortNameForTeam('Muhammad Waseem',
              'United Arab Emirates'),
          'Waseem Muhammad');
      expect(cs.resolveShortNameForTeam("Max O'Dowd", 'Netherlands'),
          "MP O'Dowd");
      // Two same-team "de Leede" candidates: shortest first token
      // ("B") wins over "BFW" for the single first name "Bas".
      expect(
          cs.resolveShortNameForTeam('Bas de Leede', 'Netherlands'),
          'B de Leede');
      expect(cs.resolveShortNameForTeam('Scott Edwards', 'Netherlands'),
          'SA Edwards');
      expect(cs.resolveShortNameForTeam('Fred Klaassen', 'Netherlands'),
          'FJ Klaassen');
      expect(
          cs.resolveShortNameForTeam('Paul van Meekeren', 'Netherlands'),
          'PA van Meekeren');
      expect(cs.resolveShortNameForTeam('Colin Ackermann', 'Netherlands'),
          'CN Ackermann');
      expect(
          cs.resolveShortNameForTeam('Noah Croes', 'Netherlands'),
          'NRJ Croes');
    });

    test('playerByShortName accepts provider names directly', () {
      final cs = _inlineService();
      final p = cs.playerByShortName("Max O'Dowd");
      expect(p, isNotNull);
      expect(p!.name, contains("O'Dowd"));
    });

    test('wrong-team same-last-name does NOT resolve', () {
      final cs = _inlineService();
      // R Chopra plays for UAE, never for Netherlands.
      expect(cs.resolveShortNameForTeam('Rahul Chopra', 'Netherlands'),
          isNull);
      // "A Khan" is not a key; without a team it is ambiguous.
      expect(cs.resolveShortNameForTeam('A Khan', 'Netherlands'),
          isNull);
    });

    test('ambiguous name without team returns null, team picks one',
        () {
      final cs = _inlineService();
      // "Arun Sharma" matches A / AB / Aarsheya Sharma on
      // last + first-initial + middles: no team -> ambiguous.
      expect(cs.resolveShortName('Arun Sharma'), isNull);
      // Team disambiguation between MA Khan (Pakistan) and
      // Matiullah Khan (UAE), both matching "M Khan".
      expect(
          cs.resolveShortNameForTeam('M Khan', 'United Arab Emirates'),
          'Matiullah Khan');
      expect(cs.resolveShortNameForTeam('M Khan', 'Pakistan'), 'MA Khan');
    });
  });

  group('aggregate H2H + venue indexes (inline)', () {
    test('UAE vs NED ODI H2H comes from the aggregate index', () {
      final cs = _inlineService();
      final h = cs.teamH2H('United Arab Emirates', 'Netherlands',
          format: 'ODI', gender: 'male');
      // Index stores wins for the sorted-first team (Netherlands):
      // [4 matches, NED 3, UAE 1, 0 no-result].
      expect(h['matches'], 4);
      expect(h['teamAWins'], 1);
      expect(h['teamBWins'], 3);
      expect(h['noResult'], 0);
      // Argument order must not change who the wins belong to.
      final h2 = cs.teamH2H('Netherlands', 'United Arab Emirates',
          format: 'ODI', gender: 'male');
      expect(h2['teamAWins'], 3);
      expect(h2['teamBWins'], 1);
      final all = cs.teamH2H('United Arab Emirates', 'Netherlands');
      expect(all['matches'], 15);
      expect(all['teamAWins'], 5);
      expect(all['teamBWins'], 9);
      expect(all['noResult'], 1);
    });

    test('venueStats resolves provider venue to the archive venue',
        () {
      final cs = _inlineService();
      // Provider "ICC Academy Ground, Dubai" is not an archive key;
      // Jaccard picks "ICC Academy, Dubai" (3/4) over the No 2 ground.
      final v = cs.venueStats('ICC Academy Ground, Dubai');
      expect(v, isNotNull);
      expect(v!.venue, 'ICC Academy, Dubai');
      expect(v.city, 'Dubai');
      expect(v.matches, 42);
      expect(v.avgFirstInnings, 156.1);
      final male = cs.venueStats('ICC Academy Ground, Dubai',
          gender: 'male');
      expect(male, isNotNull);
      expect(male!.matches, 28);
      expect(cs.venueStats('Nowhere Ground XYZ'), isNull);
    });

    test('venue player methods use resolved names + venue', () {
      final cs = _inlineService();
      final p = cs.playerVenueStats(
          'Rahul Chopra', 'ICC Academy Ground, Dubai',
          team: 'United Arab Emirates');
      expect(p, isNotNull);
      expect(p!.shortName, 'R Chopra');
      expect(p.runs, 151);
      expect(p.battingMatches, 4);
      final squad = cs.venuePlayers(
          ['Rahul Chopra', 'Muhammad Waseem', 'Nobody Unknown'],
          'ICC Academy Ground, Dubai',
          team: 'United Arab Emirates');
      expect(squad.map((s) => s.shortName).toList(),
          ['R Chopra', 'Waseem Muhammad']);
      final leaders =
          cs.topPlayersAtVenue('ICC Academy Ground, Dubai');
      expect(leaders.batters.first.shortName, 'Waseem Muhammad');
      expect(leaders.batters.first.runs, 455);
      expect(leaders.bowlers.first.shortName, 'Junaid Siddique');
      expect(cs.topPlayersAtVenue('Nowhere Ground XYZ').batters, isEmpty);
    });
  });

  group('real regenerated asset', () {
    late CricsheetService cs;

    setUpAll(() {
      final text =
          File('assets/cricsheet_stats.json').readAsStringSync();
      final sample = CricsheetService.parse('{"matches": []}');
      cs = CricsheetService(sample.matches,
          aggregate: CricsheetAggregate.parse(text));
    });

    test('aggregate index is present in the shipped asset', () {
      expect(cs.aggregate, isNotNull);
      expect(cs.aggregate!.h2h.isNotEmpty, isTrue);
      expect(cs.aggregate!.venues.isNotEmpty, isTrue);
      expect(cs.aggregate!.matchCount, 9943);
    });

    test('all nine associate examples resolve in the real asset', () {
      expect(cs.resolveShortNameForTeam('Rahul Chopra',
              'United Arab Emirates'),
          'R Chopra');
      expect(cs.resolveShortNameForTeam('Muhammad Waseem',
              'United Arab Emirates'),
          'Waseem Muhammad');
      expect(cs.resolveShortNameForTeam("Max O'Dowd", 'Netherlands'),
          "MP O'Dowd");
      expect(
          cs.resolveShortNameForTeam('Bas de Leede', 'Netherlands'),
          'B de Leede');
      expect(cs.resolveShortNameForTeam('Scott Edwards', 'Netherlands'),
          'SA Edwards');
      expect(cs.resolveShortNameForTeam('Fred Klaassen', 'Netherlands'),
          'FJ Klaassen');
      expect(
          cs.resolveShortNameForTeam('Paul van Meekeren', 'Netherlands'),
          'PA van Meekeren');
      expect(cs.resolveShortNameForTeam('Colin Ackermann', 'Netherlands'),
          'CN Ackermann');
      expect(
          cs.resolveShortNameForTeam('Noah Croes', 'Netherlands'),
          'NRJ Croes');
    });

    test('UAE vs NED ODI H2H from the real asset has matches', () {
      final h = cs.teamH2H('United Arab Emirates', 'Netherlands',
          format: 'ODI', gender: 'male');
      expect(h['matches'], greaterThan(0));
      expect(h['matches'], 4);
      expect(h['teamAWins'], 1);
      expect(h['teamBWins'], 3);
    });

    test('ICC Academy venue from the real asset has matches', () {
      final v = cs.venueStats('ICC Academy Ground, Dubai');
      expect(v, isNotNull);
      expect(v!.matches, greaterThan(0));
      expect(v.matches, 42);
      final p = cs.playerVenueStats("Max O'Dowd",
          'ICC Academy Ground, Dubai',
          team: 'Netherlands');
      expect(p, isNotNull);
    });

    test('Tanish Suri resolves to his Cricsheet short form T Suri',
        () {
      // Correction to the brief's "verified absent" note: the FULL
      // name key is absent, but the Cricsheet short form exists —
      // T Suri, United Arab Emirates, 22 matches including vs
      // Netherlands — and it is the only T-initial Suri for UAE.
      // Resolving it is correct; inventing a profile would not be.
      expect(cs.resolveShortNameForTeam('Tanish Suri',
              'United Arab Emirates'),
          'T Suri');
    });
  });
}
