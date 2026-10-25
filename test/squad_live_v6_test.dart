// SQUAD LIVE v6 — live scorecard / refresh / lineup / delay tests.
//
// Proven by 2026-10-25 phone screenshots (UAE vs Netherlands LIVE
// ODI): Home showed LIVE UAE 31/0 (6.0 ov) Source CricAPI, but the
// Scorecard tab said "Scorecard not available yet / not started
// yet" + a "Could not refresh" banner, the Squad tab had no
// Playing XI / Bench distinction, and the score lagged a paid feed
// by ~2 overs (31/0 at 6.0 ov vs 38/0 at 8.0 ov).
//
// These tests replay that exact shape with fakes (no network, no
// provider keys): a totals-only live list entry + a scorecard
// endpoint that returns nothing must NEVER yield an empty tab or a
// "not started" label, refresh failures must name their real
// reason, lineups must never be invented, and the live TTL must be
// 3 minutes (was 10).
//
// Run with: flutter test test/squad_live_v6_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:kingcric/models/innings.dart';
import 'package:kingcric/models/match.dart';
import 'package:kingcric/models/player.dart';
import 'package:kingcric/screens/match_detail_screen.dart';
import 'package:kingcric/services/api_service.dart';
import 'package:kingcric/services/cricsheet_service.dart';
import 'package:kingcric/services/providers/cricket_provider.dart';
import 'package:kingcric/utils/constants.dart';
import 'package:kingcric/utils/strings.dart';

// ------------------------------------------------------------------
// Fake provider: answers exactly what the test configures, nothing
// else. No network, no keys, no real provider behaviour.
// ------------------------------------------------------------------
class _FakeProvider implements CricketProvider {
  _FakeProvider({this.list, this.scorecard, this.quota = false});

  /// What fetchMatches returns (null = provider answers nothing).
  final List<CricketMatch>? list;

  /// What fetchScorecard returns (null = endpoint has nothing).
  final CricketMatch? scorecard;

  /// Whether this provider reports server-side quota exhaustion.
  final bool quota;

  @override
  String get name => 'Fake';

  @override
  bool get isConfigured => true;

  @override
  int get dailyCap => 90;

  @override
  int get hitsToday => 0;

  @override
  Future<List<CricketMatch>?> fetchMatches() async => list;

  @override
  Future<List<CricketMatch>?> fetchUpcoming() async => null;

  @override
  Future<CricketMatch?> fetchScorecard(String matchId) async => scorecard;

  @override
  Future<List<Map<String, dynamic>>?> fetchSeries() async => null;

  @override
  Future<Player?> fetchPlayer(String playerId) async => null;

  @override
  Future<String?> resolvePlayerId(String name) async => null;

  @override
  int? get serverHitsLeft => quota ? 0 : null;

  @override
  bool get quotaExhausted => quota;

  @override
  Future<bool> testKey() async => true;
}

// ------------------------------------------------------------------
// Fixtures — the exact screenshot shape.
// ------------------------------------------------------------------
CricketMatch _uaeNedLiveEntry() => CricketMatch(
      id: 'uae-ned-live-1',
      teamA: 'United Arab Emirates',
      teamB: 'Netherlands',
      format: 'ODI',
      league: 'International',
      venueName: 'ICC Academy Ground, Dubai',
      startTime: DateTime(2026, 10, 25, 11, 0),
      status: MatchStatus.live,
      scores: const [
        TeamScore(
            team: 'United Arab Emirates',
            runs: 31,
            wickets: 0,
            overs: 6.0,
            batted: true),
      ],
      source: 'CricAPI',
    );

CricketMatch _uaeNedWithInnings() {
  final entry = _uaeNedLiveEntry();
  return CricketMatch(
    id: entry.id,
    teamA: entry.teamA,
    teamB: entry.teamB,
    format: entry.format,
    league: entry.league,
    venueName: entry.venueName,
    startTime: entry.startTime,
    status: MatchStatus.live,
    scores: entry.scores,
    // Full squad carriers must NEVER leak into the lineup: these
    // 15 names did not bat or bowl, so none may appear as XI/bench.
    squadA: const [
      'Squad Player One',
      'Squad Player Two',
      'Squad Player Three',
    ],
    innings: const [
      Innings(
        team: 'United Arab Emirates',
        inningsNumber: 1,
        total: 31,
        wickets: 0,
        overs: 6.0,
        batting: [
          BattingEntry(
              playerId: 'p-1',
              playerName: 'Aryansh Sharma',
              runs: 15,
              balls: 19,
              notOut: true),
          BattingEntry(
              playerId: 'p-2',
              playerName: 'Tanish Suri',
              runs: 22,
              balls: 29,
              notOut: true),
        ],
        bowling: [
          BowlingEntry(
              playerId: 'p-9',
              playerName: 'Fred Klaassen',
              overs: 4.0,
              runsConceded: 20,
              wickets: 0),
        ],
      ),
    ],
    source: 'CricAPI',
  );
}

void main() {
  // Squad-tab widget tests need the Cricsheet cache warmed in the
  // real zone first (same pattern as match_detail_test.dart):
  // warming it inside a test's fake async deadlocks after a pumped
  // screen's initState fires provider work.
  setUpAll(() async {
    await CricsheetService.loadBundled();
  });

  group('SQUAD LIVE v6 — list-entry fallback (screenshot bug)', () {
    test('live entry + null scorecard + missing fixture returns '
        'partial totals, never null', () async {
      final entry = _uaeNedLiveEntry();
      final svc = ApiService(
        providers: [_FakeProvider(list: null, scorecard: null)],
        loadCricsheetSample: false,
      );
      final detail = await svc.fetchMatchDetailWithListEntry(
          entry.id, entry,
          forceRefresh: true);
      expect(detail, isNotNull);
      expect(detail!.innings, hasLength(1));
      expect(detail.innings.single.total, 31);
      expect(detail.innings.single.wickets, 0);
      expect(detail.innings.single.overs, 6.0);
      expect(detail.innings.single.didNotBatNote, contains('Partial'));
    });

    test('not-started entry with no scores stays null (honest empty)',
        () async {
      final entry = CricketMatch(
        id: 'upcoming-1',
        teamA: 'United Arab Emirates',
        teamB: 'Netherlands',
        format: 'ODI',
        league: 'International',
        startTime: DateTime(2026, 10, 26, 11, 0),
        status: MatchStatus.upcoming,
        scores: const [],
      );
      final svc = ApiService(
        providers: [_FakeProvider(list: null, scorecard: null)],
        loadCricsheetSample: false,
      );
      final detail = await svc.fetchMatchDetailWithListEntry(
          entry.id, entry,
          forceRefresh: true);
      expect(detail, isNull);
    });

    test('partial helper on the merged shape adds innings from '
        'totals', () {
      final partial = ApiService.withPartialScorecard(_uaeNedLiveEntry());
      expect(partial.innings, hasLength(1));
      expect(partial.innings.single.team, 'United Arab Emirates');
    });
  });

  group('SQUAD LIVE v6 — refresh failure reasons', () {
    test('quota-capped provider classifies as quotaExhausted', () async {
      final svc = ApiService(
        providers: [
          _FakeProvider(list: null, scorecard: null, quota: true)
        ],
        loadCricsheetSample: false,
      );
      final detail = await svc.fetchMatchDetailWithListEntry(
          'uae-ned-live-1', _uaeNedLiveEntry(),
          forceRefresh: true);
      // The list entry still saves the tab (partial), but a
      // scoreless entry proves the classification below.
      expect(detail, isNotNull);
      final svc2 = ApiService(
        providers: [
          _FakeProvider(list: null, scorecard: null, quota: true)
        ],
        loadCricsheetSample: false,
      );
      final nothing = await svc2.fetchMatchDetail('missing-id',
          forceRefresh: true);
      expect(nothing, isNull);
      expect(svc2.lastDetailFailure, DetailFailure.quotaExhausted);
      expect(svc2.detailFailureMessage, contains('quota'));
    });

    test('no provider answering classifies as providersDown', () async {
      final svc = ApiService(
        providers: [_FakeProvider(list: null, scorecard: null)],
        loadCricsheetSample: false,
      );
      final detail = await svc.fetchMatchDetail('missing-id',
          forceRefresh: true);
      expect(detail, isNull);
      expect(svc.lastDetailFailure, DetailFailure.providersDown);
      expect(svc.detailFailureMessage, contains('Providers did not answer'));
    });

    test('fresh real list without the fixture classifies as '
        'endpointEmpty', () async {
      final other = CricketMatch(
        id: 'other-match',
        teamA: 'India',
        teamB: 'Pakistan',
        format: 'T20',
        league: 'International',
        startTime: DateTime(2026, 10, 25, 11, 0),
        status: MatchStatus.live,
        source: 'Fake',
      );
      final svc = ApiService(
        providers: [
          _FakeProvider(list: [other], scorecard: null),
        ],
        loadCricsheetSample: false,
      );
      final detail = await svc.fetchMatchDetail('uae-ned-live-1',
          forceRefresh: true);
      expect(detail, isNull);
      expect(svc.lastDetailFailure, DetailFailure.endpointEmpty);
      expect(svc.detailFailureMessage, contains('no scorecard'));
    });
  });

  group('SQUAD LIVE v6 — lineup is never invented', () {
    test('confirmed players come only from batting/bowling rows, '
        'batters under their side, bowlers under the opposite side',
        () {
      final lineup = ApiService.lineupForMatch(_uaeNedWithInnings());
      expect(lineup.hasConfirmed, isTrue);
      expect(lineup.confirmedA, ['Aryansh Sharma', 'Tanish Suri']);
      // Fred Klaassen bowled AT UAE, so he is a Netherlands
      // confirmed player — grouping him under UAE would be a
      // wrong-team lineup.
      expect(lineup.confirmedB, ['Fred Klaassen']);
      expect(lineup.confirmedA, isNot(contains('Squad Player One')));
    });

    test('bowler is confirmed under the fielding side', () {
      final m = CricketMatch(
        id: 'm-x',
        teamA: 'United Arab Emirates',
        teamB: 'Netherlands',
        format: 'ODI',
        league: 'International',
        startTime: DateTime(2026, 10, 25, 11, 0),
        status: MatchStatus.live,
        innings: const [
          Innings(
            team: 'Netherlands',
            inningsNumber: 2,
            total: 10,
            wickets: 0,
            overs: 2.0,
            batting: [
              BattingEntry(
                  playerId: 'p-3',
                  playerName: 'Max O\'Dowd',
                  runs: 6,
                  balls: 8,
                  notOut: true),
            ],
            bowling: [
              BowlingEntry(
                  playerId: 'p-4',
                  playerName: 'Junaid Siddique',
                  overs: 2.0,
                  runsConceded: 10,
                  wickets: 0),
            ],
          ),
        ],
      );
      final lineup = ApiService.lineupForMatch(m);
      expect(lineup.confirmedB, ['Max O\'Dowd']);
      expect(lineup.confirmedA, ['Junaid Siddique']);
    });

    test('unmatched innings team is skipped, never guessed', () {
      final m = CricketMatch(
        id: 'm-y',
        teamA: 'United Arab Emirates',
        teamB: 'Netherlands',
        format: 'ODI',
        league: 'International',
        startTime: DateTime(2026, 10, 25, 11, 0),
        status: MatchStatus.live,
        innings: const [
          Innings(
            team: 'Some Other Side',
            inningsNumber: 1,
            total: 50,
            wickets: 1,
            overs: 10.0,
            batting: [
              BattingEntry(
                  playerId: 'p-5',
                  playerName: 'Mystery Batter',
                  runs: 20,
                  balls: 15),
            ],
          ),
        ],
      );
      expect(ApiService.lineupForMatch(m).hasConfirmed, isFalse);
    });

    test('totals-only partial yields no lineup', () {
      final partial =
          ApiService.withPartialScorecard(_uaeNedLiveEntry());
      expect(ApiService.lineupForMatch(partial).hasConfirmed, isFalse);
    });
  });

  group('SQUAD LIVE v6 — live TTL is 3 minutes', () {
    test('live cache TTL is 3 min, completed stays 60 min', () {
      expect(AppConstants.liveCacheTtl, const Duration(minutes: 3));
      expect(AppConstants.completedCacheTtl, const Duration(hours: 1));
      expect(ApiService.ttlForMatch(_uaeNedLiveEntry()),
          const Duration(minutes: 3));
      final done = CricketMatch(
        id: 'done-1',
        teamA: 'United Arab Emirates',
        teamB: 'Netherlands',
        format: 'ODI',
        league: 'International',
        startTime: DateTime(2026, 10, 25, 11, 0),
        status: MatchStatus.completed,
        result: 'Netherlands won by 5 wickets',
      );
      expect(ApiService.ttlForMatch(done), const Duration(hours: 1));
    });
  });

  group('SQUAD LIVE v6 — screen widgets', () {
    Widget wrap(Widget child) {
      return ChangeNotifierProvider(
        create: (_) => LanguageProvider(),
        child: MaterialApp(home: child),
      );
    }

    /// Drag the visible tab's list until [finder] is built (same
    /// pattern as match_detail_test.dart: TabBarView + ListViews
    /// make scrollUntilVisible unusable).
    Future<void> dragUntilBuilt(
        WidgetTester tester, Finder finder) async {
      for (var i = 0; i < 40 && finder.evaluate().isEmpty; i++) {
        await tester.drag(find.byType(TabBarView), const Offset(0, -250));
        await tester.pump();
      }
    }

    testWidgets('Scorecard tab shows partial totals for a live '
        'list entry, never "not started"', (tester) async {
      await tester.pumpWidget(
          wrap(MatchDetailScreen(match: _uaeNedLiveEntry())));
      await tester.pump();
      await tester.tap(find.text('Scorecard'));
      await tester.pumpAndSettle();
      expect(find.textContaining('31/0'), findsWidgets);
      expect(find.textContaining('has not started yet'), findsNothing);
    });

    testWidgets('Squad tab shows the confirmed lineup section '
        'when innings prove players', (tester) async {
      await tester.pumpWidget(
          wrap(MatchDetailScreen(match: _uaeNedWithInnings())));
      await tester.pump();
      await tester.tap(find.text('Squad'));
      await tester.pumpAndSettle();
      await dragUntilBuilt(
          tester, find.text('Lineup — confirmed on field'));
      expect(find.text('Lineup — confirmed on field'), findsWidgets);
      expect(find.textContaining('Aryansh Sharma'), findsWidgets);
      // The section must say it is NOT the official XI.
      expect(find.textContaining('not the official Playing XI'),
          findsWidgets);
    });

    testWidgets('Squad tab shows the honest no-XI line when '
        'nothing is proven', (tester) async {
      await tester.pumpWidget(
          wrap(MatchDetailScreen(match: _uaeNedLiveEntry())));
      await tester.pump();
      await tester.tap(find.text('Squad'));
      await tester.pumpAndSettle();
      await dragUntilBuilt(tester,
          find.textContaining('Official Playing XI not supplied'));
      expect(find.textContaining('Official Playing XI not supplied'),
          findsWidgets);
      expect(find.text('Lineup — confirmed on field'), findsNothing);
    });
  });
}
