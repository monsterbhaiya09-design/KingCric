import 'package:flutter_test/flutter_test.dart';
import 'package:kingcric/models/innings.dart';
import 'package:kingcric/models/match.dart';
import 'package:kingcric/models/player.dart';
import 'package:kingcric/services/api_service.dart';
import 'package:kingcric/services/auto_update_service.dart';
import 'package:kingcric/services/cricsheet_service.dart';
import 'package:kingcric/services/providers/cricket_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Squad D: full-archive aggregates (base) + finished-match delta +
// manual refresh. Every test uses INLINE data only — the 18 MB
// bundled asset is never loaded here, so these tests stay fast.

const _aggJson = '''
{"meta": {"matches": 9943, "yearMin": "2001", "yearMax": "2026",
          "coverageEnd": "2026-10-14", "source": "Cricsheet"},
 "players": {
  "MG Erasmus": {"team": "Namibia",
    "bat": {"all": [165, 160, 4726, 4856, 369, 144, 134, 37, 2, 121],
            "fmt:ODI": [60, 58, 1800, 1900, 140, 40, 50, 12, 0, 121],
            "fmt:T20": [105, 102, 2926, 2956, 229, 104, 84, 25, 2, 100],
            "opp:Ireland": [2, 2, 104, 83, 10, 1, 1, 2, 0, 53],
            "ven:Harare Sports Club": [5, 5, 200, 180, 20, 2, 4, 1, 0, 90]},
    "bowl": {"all": [125, 125, 123, 3067, 2666, 2, 5, 28],
             "fmt:ODI": [50, 50, 45, 1200, 1000, 1, 5, 28],
             "fmt:T20": [75, 75, 78, 1867, 1666, 1, 5, 30]},
    "dis": {"c X b Y": 3},
    "pairs": {}},
  "V Kohli": {"team": "India",
    "bat": {"all": [555, 626, 28186, 35417, 2769, 328, 535, 145, 85, 254],
            "fmt:Test": [100, 110, 4000, 8000, 300, 50, 90, 10, 5, 200],
            "fmt:ODI": [300, 320, 14000, 18000, 1200, 100, 200, 60, 30, 183],
            "fmt:T20": [155, 196, 10186, 9417, 1269, 178, 245, 75, 50, 254]},
    "bowl": {},
    "dis": {},
    "pairs": {}},
  "Shaheen Shah Afridi": {"team": "Pakistan",
    "bat": {},
    "bowl": {},
    "dis": {},
    "pairs": {"V Kohli": [10, 120, 90, 2]}}
 }}
''';

// One tiny sample match: Erasmus 50 (30 balls) for Namibia vs Ireland.
const _sampleMatch = '''
{"meta": {"data_version": "1.3.0"},
 "info": {"venue": "Windhoek", "city": "Windhoek", "dates": ["2026-10-01"],
  "event": {"name": "Ireland in Namibia"}, "gender": "male",
  "teams": ["Namibia", "Ireland"],
  "outcome": {"winner": "Namibia"}, "toss": {"winner": "Namibia", "decision": "bat"},
  "match_type": "ODI", "players": {"Namibia": ["MG Erasmus"], "Ireland": ["PR Stirling"]}},
 "innings": [{"team": "Namibia", "overs": [{"over": 0, "deliveries": [
   {"batter": "MG Erasmus", "bowler": "MR Adair", "non_striker": "PR Stirling",
    "runs": {"batter": 50, "extras": 0, "total": 50}}]}]}]}
''';

CricsheetService _serviceWithAgg() {
  final sample = CricsheetService.parse(_sampleMatch);
  return CricsheetService(sample.matches,
      aggregate: CricsheetAggregate.parse(_aggJson));
}

CricketMatch _finishedDetail({String id = 'fin1'}) {
  return CricketMatch(
    id: id,
    teamA: 'Namibia',
    teamB: 'Ireland',
    format: 'ODI',
    venueName: 'Harare Sports Club',
    startTime: DateTime.utc(2026, 10, 20, 10, 0),
    status: MatchStatus.completed,
    innings: [
      const Innings(
        team: 'Namibia',
        inningsNumber: 1,
        total: 250,
        wickets: 5,
        overs: 50.0,
        batting: [
          BattingEntry(
              playerId: 'mg-erasmus',
              playerName: 'MG Erasmus',
              runs: 50,
              balls: 30,
              fours: 5,
              sixes: 1,
              notOut: false),
        ],
        bowling: [
          BowlingEntry(
              playerId: 'r-trump',
              playerName: 'R Trumpelmann',
              overs: 4.0,
              runsConceded: 20,
              wickets: 2),
        ],
      ),
      const Innings(
        team: 'Ireland',
        inningsNumber: 2,
        total: 240,
        wickets: 6,
        overs: 50.0,
        batting: [
          BattingEntry(
              playerId: 'pr-stirling',
              playerName: 'PR Stirling',
              runs: 40,
              balls: 35,
              fours: 4,
              sixes: 0,
              notOut: false),
        ],
        bowling: [
          BowlingEntry(
              playerId: 'mg-erasmus',
              playerName: 'MG Erasmus',
              overs: 2.0,
              runsConceded: 15,
              wickets: 1),
        ],
      ),
    ],
  );
}

void main() {
  group('Squad D: full-archive aggregates', () {
    test('coverage label is honest and Erasmus totals are full, not sample',
        () {
      final cs = _serviceWithAgg();
      expect(cs.hasFullAggregates, isTrue);
      expect(cs.aggregateMatchCount, 9943);
      expect(cs.aggregateCoverageLabel,
          'Full archive 2001–2026 • 9943 matches');
      final p = cs.playerByShortName('MG Erasmus')!;
      // FULL career, not the 1-match sample (50 runs) and NOT the
      // sum of both (4776 would be double-counting the sample).
      expect(p.battingOverall().runs, 4726);
      expect(p.battingOverall().matches, 165);
      expect(p.bowlingOverall().wickets, 123);
      // vs-opponent pair that the sample alone cannot show.
      expect(p.battingVsOpponent['Ireland']!.runs, 104);
      // Venue depth: aggregate has Harare; sample venue was Windhoek.
      expect(p.battingByVenue['Harare Sports Club']!.runs, 200);
    });

    test('aggregate-only player resolves; unknown player stays null', () {
      final cs = _serviceWithAgg();
      final kohli = cs.playerByShortName('V Kohli')!;
      expect(kohli.battingOverall().runs, 28186);
      expect(cs.playerByShortName('Nobody Atall'), isNull);
    });

    test('aggregate matchup + dismissal lines, no fake data', () {
      final cs = _serviceWithAgg();
      final m = cs.matchup(bowler: 'Shaheen Shah Afridi', batter: 'V Kohli');
      expect(m.balls, 120);
      expect(m.dismissals, 2);
      final dh = cs.dismissalHistoryFor('MG Erasmus');
      expect(dh, contains('c X b Y — 3 times'));
    });
  });

  group('Squad D: finished-match delta', () {
    test('delta applied once; duplicate finish ignored', () {
      final cs = _serviceWithAgg();
      final detail = _finishedDetail();
      expect(cs.applyFinishedMatch(detail), DeltaApplyResult.applied);
      var p = cs.playerByShortName('MG Erasmus')!;
      expect(p.battingOverall().runs, 4726 + 50);
      expect(p.bowlingOverall().wickets, 123 + 1);
      expect(cs.applyFinishedMatch(detail),
          DeltaApplyResult.alreadyProcessed);
      p = cs.playerByShortName('MG Erasmus')!;
      expect(p.battingOverall().runs, 4726 + 50);
      expect(p.bowlingOverall().wickets, 123 + 1);
      expect(cs.deltaMatchCount, 1);
    });

    test('no scorecard stays pending and is never counted', () {
      final cs = _serviceWithAgg();
      final empty = CricketMatch(
        id: 'fin-pending',
        teamA: 'Namibia',
        teamB: 'Ireland',
        format: 'ODI',
        startTime: DateTime.utc(2026, 10, 21),
        status: MatchStatus.completed,
      );
      expect(cs.applyFinishedMatch(empty), DeltaApplyResult.noScorecard);
      expect(cs.pendingDeltaMatchIds, contains('fin-pending'));
      expect(cs.deltaMatchCount, 0);
      // The same match arriving later WITH a scorecard applies and
      // clears the pending entry.
      expect(cs.applyFinishedMatch(_finishedDetail(id: 'fin-pending')),
          DeltaApplyResult.applied);
      expect(cs.pendingDeltaMatchIds, isNot(contains('fin-pending')));
    });

    test('delta serialize/deserialize round-trip keeps totals', () {
      final cs = _serviceWithAgg();
      cs.applyFinishedMatch(_finishedDetail());
      final json = cs.delta.toJson();
      final cs2 = _serviceWithAgg()
        ..delta = CricsheetDelta.fromJson(json);
      final p = cs2.playerByShortName('MG Erasmus')!;
      expect(p.battingOverall().runs, 4776);
      expect(p.bowlingOverall().wickets, 124);
    });

    test('persisted delta survives a restart; base absorbs old deltas',
        () async {
      SharedPreferences.setMockInitialValues({});
      final cs = _serviceWithAgg();
      cs.applyFinishedMatch(_finishedDetail());
      await cs.persistDelta();
      final cs2 = _serviceWithAgg();
      await cs2.loadPersistedDelta();
      expect(cs2.deltaMatchCount, 1);
      expect(cs2.playerByShortName('MG Erasmus')!.battingOverall().runs,
          4776);
      // A delta match dated on/before the base coverageEnd
      // (2026-10-14) is absorbed by a regenerated base and pruned.
      final cs3 = _serviceWithAgg();
      cs3.delta.matches['old1'] = const CricsheetDeltaMatch(
        matchId: 'old1',
        date: '2026-10-10',
        format: 'ODI',
        venue: '',
        league: 'International',
        teamA: 'Namibia',
        teamB: 'Ireland',
        bat: {},
        bowl: {},
      );
      cs3.pruneDeltaAbsorbedByBase();
      expect(cs3.deltaMatchCount, 0);
    });
  });

  group('Squad D: MANUAL refresh only (user rule)', () {
    test('not calling refresh leaves provider untouched', () async {
      final fake = _RefreshFakeProvider();
      final svc = AutoUpdateService(
          api: ApiService(
              providers: [fake],
              cricsheet: _serviceWithAgg(),
              loadCricsheetSample: false));
      expect(fake.scorecardCalls, 0);
      svc.dispose();
    });

    test('calling refresh force-fetches; double-press never doubles',
        () async {
      final fake = _RefreshFakeProvider();
      final cs = _serviceWithAgg();
      final api = ApiService(
          providers: [fake], cricsheet: cs, loadCricsheetSample: false);
      final svc = AutoUpdateService(api: api);
      final match = CricketMatch(
        id: 'm1',
        teamA: 'Namibia',
        teamB: 'Ireland',
        format: 'ODI',
        venueName: 'Harare Sports Club',
        startTime: DateTime.utc(2026, 10, 24, 10, 0),
        status: MatchStatus.upcoming,
      );
      final before = cs.playerByShortName('MG Erasmus')!.battingOverall().runs;
      final r1 = await svc.refreshMatchData(match);
      expect(r1.success, isTrue);
      expect(r1.detail!.id, 'm1');
      expect(fake.scorecardCalls, 1);
      final r2 = await svc.refreshMatchData(match);
      expect(r2.success, isTrue);
      expect(fake.scorecardCalls, 2);
      // Squad aggregates recompute identically — nothing counted twice.
      final after = cs.playerByShortName('MG Erasmus')!.battingOverall().runs;
      expect(after, before);
      expect(cs.deltaMatchCount, 0);
      svc.dispose();
    });

    test('quota-exhausted call burns no call and keeps old data',
        () async {
      final api = _QuotaApi();
      final svc = AutoUpdateService(api: api);
      final match = CricketMatch(
        id: 'm1',
        teamA: 'Namibia',
        teamB: 'Ireland',
        startTime: DateTime.utc(2026, 10, 24, 10, 0),
        status: MatchStatus.upcoming,
      );
      final r = await svc.refreshMatchData(match);
      expect(r.success, isFalse);
      expect(r.reason, ManualRefreshReason.quotaExhausted);
      expect(r.message, contains('quota'));
      expect(api.fetchCalls, 0);
      svc.dispose();
    });

    test('no-data call fails honestly; cached detail untouched', () async {
      final fake = _RefreshFakeProvider();
      final api = ApiService(
          providers: [fake],
          cricsheet: _serviceWithAgg(),
          loadCricsheetSample: false);
      final svc = AutoUpdateService(api: api);
      final match = CricketMatch(
        id: 'm1',
        teamA: 'Namibia',
        teamB: 'Ireland',
        format: 'ODI',
        startTime: DateTime.utc(2026, 10, 24, 10, 0),
        status: MatchStatus.upcoming,
      );
      final ok = await svc.refreshMatchData(match);
      expect(ok.success, isTrue);
      fake.returnDetail = null; // provider goes dark
      final bad = await svc.refreshMatchData(match);
      expect(bad.success, isFalse);
      expect(bad.reason, ManualRefreshReason.noData);
      // Cached detail from the good refresh is still served.
      final cached = await api.fetchMatchDetail('m1');
      expect(cached, isNotNull);
      expect(cached!.id, 'm1');
      svc.dispose();
    });
  });
}

/// Fake provider serving one scripted scorecard detail.
class _RefreshFakeProvider implements CricketProvider {
  int scorecardCalls = 0;
  CricketMatch? returnDetail;

  _RefreshFakeProvider() {
    returnDetail = CricketMatch(
      id: 'm1',
      teamA: 'Namibia',
      teamB: 'Ireland',
      format: 'ODI',
      venueName: 'Harare Sports Club',
      startTime: DateTime.utc(2026, 10, 24, 10, 0),
      status: MatchStatus.upcoming,
      innings: [
        const Innings(team: 'Namibia', inningsNumber: 1, total: 250),
      ],
    );
  }

  @override
  String get name => 'RefreshFake';
  @override
  bool get isConfigured => true;
  @override
  int get dailyCap => 100;
  @override
  int get hitsToday => 0;
  @override
  int? get serverHitsLeft => null;
  @override
  bool get quotaExhausted => false;
  @override
  Future<bool> testKey() async => true;
  @override
  Future<String?> resolvePlayerId(String name) async => null;
  @override
  Future<List<CricketMatch>?> fetchMatches() async => [];
  @override
  Future<List<CricketMatch>?> fetchUpcoming() async => null;
  @override
  Future<CricketMatch?> fetchScorecard(String matchId) async {
    scorecardCalls++;
    return returnDetail;
  }

  @override
  Future<List<Map<String, dynamic>>?> fetchSeries() async => null;
  @override
  Future<Player?> fetchPlayer(String playerId) async => null;
}

/// ApiService that reports quota exhausted without any network call.
class _QuotaApi extends ApiService {
  int fetchCalls = 0;

  _QuotaApi() : super(providers: <CricketProvider>[]);

  @override
  QuotaState get quotaState => QuotaState.quotaExhausted;

  @override
  Future<CricketMatch?> fetchMatchDetail(String matchId,
      {bool forceRefresh = false}) async {
    fetchCalls++;
    return null;
  }
}
