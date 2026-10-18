import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kingcric/models/match.dart';
import 'package:kingcric/services/providers/cricket_provider.dart';
import 'package:kingcric/services/providers/elitesport_provider.dart';
import 'package:kingcric/services/providers/entitysport_provider.dart';
import 'package:kingcric/services/providers/sportscore_provider.dart';
import 'package:kingcric/services/providers/thesportsdb_provider.dart';

/// Squad D: backstop providers + ONE status truth.
///
/// Rules under test:
/// - resolveStatus: hasScores -> LIVE before any not-started branch;
///   terminal = result phrases only ("won the toss" NEVER terminal);
///   pre-toss rain delay = upcoming, mid-match rain delay = live.
/// - Every provider computes REAL hasScores from its parsed scores
///   (never hard-coded false).
/// - Backstops never invent data: null on failure, no fake scores.
/// - fetchUpcoming for backstops: only real fixtures, [] when none,
///   never keyword-search junk presented as fixtures.
/// - Debug-log received/dropped/kept per provider (verified by
///   behaviour here; log text itself is debugPrint, not asserted).
void main() {
  group('Squad D: resolveStatus is ONE status truth', () {
    test('hasScores beats a stale not-started label', () {
      for (final label in [
        'Match scheduled',
        'Preview',
        'Upcoming',
        'Not started',
        'Yet to start',
        'To be played',
      ]) {
        expect(
          ProviderParsing.resolveStatus(raw: label, hasScores: true),
          MatchStatus.live,
          reason: 'label "$label" with scores must be LIVE',
        );
        expect(
          ProviderParsing.resolveStatus(raw: label, hasScores: false),
          MatchStatus.upcoming,
          reason: 'label "$label" without scores stays upcoming',
        );
      }
    });

    test('terminal = result phrases only', () {
      for (final result in [
        'India won by 5 wickets',
        'India won the match by 5 wickets',
        'Match ended',
        'Match drawn',
        'Drawn',
        'No result',
        'Abandoned',
        'Match tied',
        'Match finished',
        'Match completed',
      ]) {
        expect(
          ProviderParsing.resolveStatus(raw: result, hasScores: true),
          MatchStatus.completed,
          reason: '"$result" must be completed even with scores',
        );
      }
    });

    test('"won the toss" is NEVER terminal', () {
      expect(
        ProviderParsing.resolveStatus(
          raw: 'India won the toss and elected to bat',
          hasScores: false,
        ),
        MatchStatus.upcoming,
      );
      expect(
        ProviderParsing.resolveStatus(
          raw: 'India won the toss and elected to bat',
          hasScores: true,
        ),
        MatchStatus.live,
        reason: 'toss + scores = live, not completed',
      );
      expect(
        ProviderParsing.resolveStatus(
          raw: 'Pakistan won the toss and chose to bowl',
          hasScores: false,
        ),
        MatchStatus.upcoming,
      );
    });

    test('rain delay: pre-toss upcoming, mid-match live', () {
      expect(
        ProviderParsing.resolveStatus(raw: 'Rain delay', hasScores: false),
        MatchStatus.upcoming,
      );
      expect(
        ProviderParsing.resolveStatus(raw: 'Rain delay', hasScores: true),
        MatchStatus.live,
      );
      expect(
        ProviderParsing.resolveStatus(raw: 'Stumps, Day 1', hasScores: true),
        MatchStatus.live,
      );
      // "Stumps" means the day's play already ended, so it is live
      // even when the score array is missing from the payload.
      // (Only a bare pre-toss "Rain delay" stays upcoming.)
      expect(
        ProviderParsing.resolveStatus(raw: 'Stumps, Day 1', hasScores: false),
        MatchStatus.live,
      );
    });

    test('in-progress keywords still live', () {
      for (final text in [
        'Austria Women need 88 runs in 78 balls',
        '1st Innings',
        'Innings break',
        'Live',
        'In play',
        'Team A trail by 42 runs',
        'Team A lead by 120 runs',
      ]) {
        expect(
          ProviderParsing.resolveStatus(raw: text, hasScores: true),
          MatchStatus.live,
          reason: '"$text" with scores must be live',
        );
      }
    });

    test('matchEnded flag beats everything', () {
      expect(
        ProviderParsing.resolveStatus(
          raw: 'Live',
          matchEnded: true,
          hasScores: true,
        ),
        MatchStatus.completed,
      );
    });
  });

  group('Squad D: scoresPresent helper', () {
    test('0/0 placeholder is NOT scores', () {
      expect(
        ProviderParsing.scoresPresent(runs: 0, wickets: 0, overs: 0),
        isFalse,
      );
    });

    test('wicket on 0 runs IS scores', () {
      expect(
        ProviderParsing.scoresPresent(runs: 0, wickets: 1, overs: 0),
        isTrue,
      );
    });

    test('balls bowled with 0 runs IS scores', () {
      expect(
        ProviderParsing.scoresPresent(runs: 0, wickets: 0, overs: 0.1),
        isTrue,
      );
    });

    test('runs alone IS scores', () {
      expect(ProviderParsing.scoresPresent(runs: 5, wickets: 0), isTrue);
    });
  });

  group('Squad D: SportScore (keyless backstop)', () {
    test('live match with non-keyword status + scores -> LIVE', () async {
      final client = MockClient((req) async {
        return http.Response(
          jsonEncode({
            'data': [
              {
                'home_team': 'India',
                'away_team': 'Pakistan',
                'status': '1st Innings',
                'score': {'home': '120/4', 'away': '0/0'},
              },
            ],
          }),
          200,
        );
      });
      final matches = await SportScoreProvider(client: client).fetchMatches();
      expect(matches, isNotNull);
      expect(matches!.length, 1);
      expect(matches.first.status, MatchStatus.live);
      expect(matches.first.source, 'SportScore');
      expect(matches.first.scores.first.runs, 120);
    });

    test('stale "Match scheduled" label + scores -> LIVE, not upcoming',
        () async {
      final client = MockClient((req) async {
        return http.Response(
          jsonEncode({
            'data': [
              {
                'home_team': 'Austria Women',
                'away_team': 'Sweden Women',
                'status': 'Match scheduled',
                'score': {'home': '124/9', 'away': '37/3'},
              },
            ],
          }),
          200,
        );
      });
      final matches = await SportScoreProvider(client: client).fetchMatches();
      expect(matches, isNotNull);
      expect(matches!.first.status, MatchStatus.live);
    });

    test('genuinely not-started match -> upcoming, no fake score rows',
        () async {
      final client = MockClient((req) async {
        return http.Response(
          jsonEncode({
            'data': [
              {
                'home_team': 'India',
                'away_team': 'Australia',
                'status': 'Scheduled',
              },
            ],
          }),
          200,
        );
      });
      final matches = await SportScoreProvider(client: client).fetchMatches();
      expect(matches, isNotNull);
      expect(matches!.first.status, MatchStatus.upcoming);
      // No invented scores: no rows at all for a not-started match.
      expect(matches.first.scores, isEmpty);
    });

    test('HTTP failure -> null, never invented data', () async {
      final client = MockClient((req) async {
        return http.Response('error', 500);
      });
      final matches = await SportScoreProvider(client: client).fetchMatches();
      expect(matches, isNull);
    });

    test('unparseable body -> null, never invented data', () async {
      final client = MockClient((req) async {
        return http.Response(jsonEncode({}), 200);
      });
      final matches = await SportScoreProvider(client: client).fetchMatches();
      expect(matches, isNull);
    });

    test('fetchUpcoming is null: no SportScore fixtures endpoint', () async {
      var calls = 0;
      final client = MockClient((req) async {
        calls++;
        return http.Response(jsonEncode({}), 200);
      });
      final upcoming =
          await SportScoreProvider(client: client).fetchUpcoming();
      expect(upcoming, isNull);
      expect(calls, 0, reason: 'no fixtures endpoint, no HTTP at all');
    });
  });

  group('Squad D: TheSportsDB (metadata backstop)', () {
    test('live event with "1st Innings" + scores -> LIVE', () async {
      final client = MockClient((req) async {
        return http.Response(
          jsonEncode({
            'events': [
              {
                'idEvent': 'e1',
                'strHomeTeam': 'India',
                'strAwayTeam': 'Pakistan',
                'strStatus': '1st Innings',
                'intHomeScore': '120/4',
                'intAwayScore': '',
                'dateEvent': '2026-10-18',
                'strLeague': 'International',
              },
            ],
          }),
          200,
        );
      });
      final matches =
          await TheSportsDbProvider(client: client).fetchMatches();
      expect(matches, isNotNull);
      expect(matches!.first.status, MatchStatus.live);
      expect(matches.first.source, 'TheSportsDB');
    });

    test('fetchMatches with no live events -> null, NO keyword search',
        () async {
      final requested = <String>[];
      final client = MockClient((req) async {
        requested.add(req.url.toString());
        return http.Response(jsonEncode({'events': []}), 200);
      });
      final matches =
          await TheSportsDbProvider(client: client).fetchMatches();
      expect(matches, isNull);
      expect(
        requested.any((u) => u.contains('searchevents')),
        isFalse,
        reason: 'keyword title-search must never run',
      );
    });

    test('fetchUpcoming returns [] and makes ZERO HTTP calls', () async {
      var calls = 0;
      final client = MockClient((req) async {
        calls++;
        return http.Response(jsonEncode({}), 200);
      });
      final upcoming =
          await TheSportsDbProvider(client: client).fetchUpcoming();
      expect(upcoming, isEmpty);
      expect(calls, 0,
          reason: 'no real fixtures endpoint, keyword search disabled');
    });

    test('HTTP failure -> null, never invented data', () async {
      final client = MockClient((req) async {
        return http.Response('error', 500);
      });
      final matches =
          await TheSportsDbProvider(client: client).fetchMatches();
      expect(matches, isNull);
    });
  });

  group('Squad D: keyed providers never invent without a key', () {
    test('EliteSport unconfigured -> null everywhere', () async {
      final provider = EliteSportProvider(
        client: MockClient((req) async {
          return http.Response(jsonEncode({}), 200);
        }),
      );
      expect(provider.isConfigured, isFalse);
      expect(await provider.fetchMatches(), isNull);
      expect(await provider.fetchUpcoming(), isNull);
      expect(await provider.fetchPlayer('p1'), isNull);
      expect(await provider.resolvePlayerId('Virat Kohli'), isNull);
    });

    test('EntitySport unconfigured -> null everywhere', () async {
      final provider = EntitySportProvider(
        client: MockClient((req) async {
          return http.Response(jsonEncode({}), 200);
        }),
      );
      expect(provider.isConfigured, isFalse);
      expect(await provider.fetchMatches(), isNull);
      expect(await provider.fetchUpcoming(), isNull);
      expect(await provider.fetchPlayer('p1'), isNull);
      expect(await provider.resolvePlayerId('Virat Kohli'), isNull);
    });
  });
}
