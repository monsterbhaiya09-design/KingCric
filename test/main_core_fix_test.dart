import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:kingcric/models/innings.dart';
import 'package:kingcric/models/match.dart';
import 'package:kingcric/models/player.dart';
import 'package:kingcric/services/api_service.dart';
import 'package:kingcric/services/providers/cricapi_provider.dart';
import 'package:kingcric/services/providers/cricket_provider.dart';
import 'package:kingcric/services/providers/sportscore_provider.dart';
import 'package:kingcric/services/providers/thesportsdb_provider.dart';
import 'package:kingcric/utils/constants.dart';

/// MAIN-CORE FIX tests: Live + Upcoming + Scorecard + real data.
///
/// Bug: a match with scores on the board ("Austria Women need 88
/// runs in 78 balls", 124/9 + 37/3) showed under UPCOMING while the
/// Live tab was empty. Root causes (see MAIN-CORE-FIX.md):
///  1. resolveStatus let a stale "scheduled / not started" label beat
///     scores on the board.
///  2. isEffectivelyLive treated bare 'won the' (the toss) as a
///     terminal result.
///  3. Merge richness counted placeholder 0/0 score rows, so a
///     backstop copy could outrank the live copy and take its
///     non-CricAPI id with it (scorecard fetch then failed).
///  4. Backstops always passed hasScores=false, so live backstop
///     matches parsed as upcoming.
///  5. HTTP 429 never marked quota exhausted, so no quota banner.

bool get _keyConfigured => AppConstants.hasApiKey;

CricketMatch _m(
  String id,
  String teamA,
  String teamB, {
  MatchStatus status = MatchStatus.upcoming,
  List<TeamScore> scores = const [],
  String source = 'CricAPI',
}) {
  return CricketMatch(
    id: id,
    teamA: teamA,
    teamB: teamB,
    startTime: DateTime(2026, 10, 18, 14, 30),
    status: status,
    scores: scores,
    source: source,
  );
}

void main() {
  // ---------- Fix 1: scores beat a stale not-started label ----------
  test('resolveStatus: stale scheduled label + scores = LIVE', () {
    expect(
      ProviderParsing.resolveStatus(
        raw: 'Match scheduled',
        hasScores: true,
      ),
      MatchStatus.live,
    );
    expect(
      ProviderParsing.resolveStatus(
        raw: 'Match not started',
        hasScores: true,
      ),
      MatchStatus.live,
    );
    expect(
      ProviderParsing.resolveStatus(
        raw: 'Preview: Austria Women vs Sweden Women',
        hasScores: true,
      ),
      MatchStatus.live,
    );
    // Genuinely not started: empty score array -> still upcoming.
    expect(
      ProviderParsing.resolveStatus(
        raw: 'Match scheduled',
        hasScores: false,
      ),
      MatchStatus.upcoming,
    );
    expect(
      ProviderParsing.resolveStatus(
        raw: 'Match not started',
        hasScores: false,
      ),
      MatchStatus.upcoming,
    );
    // Toss line + scores = live (play has started).
    expect(
      ProviderParsing.resolveStatus(
        raw: 'Austria Women won the toss and elected to bat',
        hasScores: true,
      ),
      MatchStatus.live,
    );
    // Toss line + NO scores = still upcoming (toss only).
    expect(
      ProviderParsing.resolveStatus(
        raw: 'Austria Women won the toss and elected to bat',
        hasScores: false,
      ),
      MatchStatus.upcoming,
    );
  });

  // ---------- Fix 2: 'won the toss' is NOT terminal ----------
  test('isEffectivelyLive: won-the-toss + scores = LIVE', () {
    final tossLive = _m(
      'm-toss',
      'Austria Women',
      'Sweden Women',
      status: MatchStatus.upcoming,
      scores: const [
        TeamScore(team: 'Sweden Women', runs: 124, wickets: 9, batted: true),
        TeamScore(team: 'Austria Women', runs: 37, wickets: 3, batted: true),
      ],
    );
    // result carries the raw provider status text (the toss line).
    final withTossResult = CricketMatch(
      id: tossLive.id,
      teamA: tossLive.teamA,
      teamB: tossLive.teamB,
      startTime: tossLive.startTime,
      status: tossLive.status,
      scores: tossLive.scores,
      result: 'Austria Women won the toss and elected to bat',
    );
    expect(withTossResult.isEffectivelyLive, isTrue);
  });

  test('isEffectivelyLive: real result still terminal', () {
    final finished = CricketMatch(
      id: 'm-done',
      teamA: 'Bulgaria Women',
      teamB: 'Sweden Women',
      startTime: DateTime(2026, 10, 18),
      status: MatchStatus.upcoming,
      scores: const [
        TeamScore(team: 'Bulgaria Women', runs: 98, wickets: 9, batted: true),
        TeamScore(team: 'Sweden Women', runs: 99, wickets: 0, batted: true),
      ],
      result: 'Sweden Women won by 10 wkts',
    );
    expect(finished.isEffectivelyLive, isFalse);
  });

  // ---------- Fix 3: merge richness ----------
  test('merge: live copy beats upcoming copy with placeholder row', () {
    final liveCopy = _m(
      'live-1',
      'Austria Women',
      'Sweden Women',
      status: MatchStatus.live,
      scores: const [
        TeamScore(team: 'Sweden Women', runs: 124, wickets: 9, batted: true),
      ],
    );
    // Backstop copy: one real row + one 0/0 placeholder row for the
    // side yet to bat (batted=false). Old code counted 2 rows and
    // let this copy win the merge (taking its non-CricAPI id).
    final upcomingCopy = _m(
      'up-1',
      'Austria Women',
      'Sweden Women',
      status: MatchStatus.upcoming,
      scores: const [
        TeamScore(team: 'Sweden Women', runs: 124, wickets: 9, batted: true),
        TeamScore(team: 'Austria Women', runs: 0, wickets: 0, batted: false),
      ],
      source: 'TheSportsDB',
    );
    final merged = ApiService.mergeMatches([
      [liveCopy],
      [upcomingCopy],
    ]);
    expect(merged.length, 1);
    expect(merged.first.id, 'live-1');
    expect(merged.first.status, MatchStatus.live);
  });

  test('merge: completed copy beats live copy on equal scores', () {
    final liveCopy = _m(
      'live-1',
      'India',
      'Pakistan',
      status: MatchStatus.live,
      scores: const [
        TeamScore(team: 'Pakistan', runs: 160, wickets: 5, batted: true),
        TeamScore(team: 'India', runs: 161, wickets: 4, batted: true),
      ],
    );
    // MERGE-LEAD: same fixture from one provider carries the SAME id.
    // (Different ids + same provider = distinct fixtures, e.g. a
    // double-header where match 1 finished and match 2 is live —
    // those must NOT merge. The old version of this test used a
    // different id, which only passed because the old merge ignored
    // the per-match source; MatchMerge is now the single definition.)
    final completedCopy = _m(
      'live-1',
      'India',
      'Pakistan',
      status: MatchStatus.completed,
      scores: const [
        TeamScore(team: 'Pakistan', runs: 160, wickets: 5, batted: true),
        TeamScore(team: 'India', runs: 161, wickets: 4, batted: true),
      ],
    );
    final merged = ApiService.mergeMatches([
      [liveCopy],
      [completedCopy],
    ]);
    expect(merged.length, 1);
    expect(merged.first.status, MatchStatus.completed);
  });

  // ---------- Fix 4: backstops pass real hasScores ----------
  test('TheSportsDB: live event with scores + toss status = LIVE', () async {
    final client = MockClient((req) async {
      return http.Response(
        jsonEncode({
          'events': [
            {
              'idEvent': 'tsdb-1',
              'strHomeTeam': 'Austria Women',
              'strAwayTeam': 'Sweden Women',
              'strStatus': 'Austria Women won the toss and elected to bat',
              'intHomeScore': '37/3',
              'intAwayScore': '124/9',
              'dateEvent': '2026-10-18',
              'strTime': '14:30:00',
              'strLeague': 'International',
              'strVenue': 'Moara Vlasiei Cricket Ground',
              'strSport': 'Cricket',
            },
          ],
        }),
        200,
      );
    });
    final p = TheSportsDbProvider(client: client);
    final matches = await p.fetchMatches();
    expect(matches, isNotNull);
    expect(matches!.length, 1);
    expect(matches.first.status, MatchStatus.live);
    expect(matches.first.isEffectivelyLive, isTrue);
  });

  test('SportScore: live match with scores + toss status = LIVE', () async {
    final client = MockClient((req) async {
      return http.Response(
        jsonEncode({
          'data': [
            {
              'id': 'ss-1',
              'home_team': 'Austria Women',
              'away_team': 'Sweden Women',
              'status': 'Austria Women won the toss and elected to bat',
              'score': {'home': '37/3', 'away': '124/9'},
            },
          ],
        }),
        200,
      );
    });
    final p = SportScoreProvider(client: client);
    final matches = await p.fetchMatches();
    expect(matches, isNotNull);
    expect(matches!.length, 1);
    expect(matches.first.status, MatchStatus.live);
  });

  // ---------- CricAPI end-to-end (needs dummy key for isConfigured) --
  test('CricAPI fetchUpcoming excludes stale-label live match',
      skip: !_keyConfigured, () async {
    final client = MockClient((req) async {
      return http.Response(
        jsonEncode({
          'status': 'success',
          'info': {'hitsLeft': 99},
          'data': [
            {
              'id': 'live-1',
              'teams': ['Austria Women', 'Sweden Women'],
              'matchType': 'T20',
              'status': 'Match scheduled',
              'venue': 'Moara Vlasiei Cricket Ground',
              'dateTimeGMT': '2026-10-18T14:30:00',
              'score': [
                {'inning': 'Sweden Women Inning 1', 'r': 124, 'w': 9, 'o': 20},
                {'inning': 'Austria Women Inning 1', 'r': 37, 'w': 3, 'o': 7},
              ],
              'matchStarted': false,
              'matchEnded': false,
            },
            {
              'id': 'up-1',
              'teams': ['India', 'Pakistan'],
              'matchType': 'T20',
              'status': 'Match scheduled',
              'venue': 'Dubai',
              'dateTimeGMT': '2026-10-25T14:30:00',
              'score': [],
              'matchStarted': false,
              'matchEnded': false,
            },
          ],
        }),
        200,
      );
    });
    final p = CricApiProvider(client: client);
    final upcoming = await p.fetchUpcoming();
    expect(upcoming, isNotNull);
    // Only the genuinely not-started fixture survives.
    expect(upcoming!.length, 1);
    expect(upcoming.first.id, 'up-1');
  });

  test('CricAPI fetchScorecard uses list id, returns full innings',
      skip: !_keyConfigured, () async {
    var scorecardIds = <String>[];
    final client = MockClient((req) async {
      if (req.url.path.contains('cricketScore')) {
        scorecardIds.add(req.url.queryParameters['id'] ?? '?');
        return http.Response(
          jsonEncode({
            'status': 'success',
            'info': {'hitsLeft': 99},
            'data': {
              'id': 'match-1',
              'teams': ['Austria Women', 'Sweden Women'],
              'matchType': 'T20',
              'status': 'Austria Women need 88 runs in 78 balls',
              'venue': 'Moara Vlasiei Cricket Ground',
              'dateTimeGMT': '2026-10-18T14:30:00',
              'score': [
                {'inning': 'Sweden Women Inning 1', 'r': 124, 'w': 9, 'o': 20},
                {'inning': 'Austria Women Inning 1', 'r': 37, 'w': 3, 'o': 7},
              ],
              'matchStarted': true,
              'matchEnded': false,
              'scorecard': [
                {
                  'inning': 'Sweden Women Inning 1',
                  'batting': [
                    {
                      'batter': 'Batter One',
                      'r': 52,
                      'b': 30,
                      '4s': 6,
                      '6s': 1,
                      'dismissal': 'c X b Y'
                    },
                    {
                      'batter': 'Batter Two',
                      'r': 20,
                      'b': 15,
                      '4s': 2,
                      '6s': 0,
                      'dismissal': ''
                    },
                  ],
                  'bowling': [
                    {
                      'bowler': 'Bowler One',
                      'o': 4,
                      'm': 0,
                      'r': 30,
                      'w': 2,
                      'eco': 7.5,
                      'wd': 1,
                      'nb': 0
                    },
                  ],
                  'extras': {'r': 5, 'wd': 2, 'nb': 1, 'b': 2, 'lb': 0},
                  'fallofwickets': [
                    {'name': 'Batter One', 'score': 52, 'over': '8.2'}
                  ],
                  'total': 124,
                  'wickets': 9,
                  'overs': 20,
                },
              ],
            },
          }),
          200,
        );
      }
      return http.Response(
          jsonEncode({'status': 'success', 'data': []}), 200);
    });
    final p = CricApiProvider(client: client);
    final detail = await p.fetchScorecard('match-1');
    expect(detail, isNotNull);
    expect(scorecardIds, ['match-1']);
    expect(detail!.innings.length, 1);
    expect(detail.innings.first.batting.length, 2);
    expect(detail.innings.first.bowling.length, 1);
    expect(detail.innings.first.total, 124);
    expect(detail.status, MatchStatus.live);
  });

  // ---------- ApiService: scorecard auto-fetch via detail ----------
  test('ApiService fetchMatchDetail returns innings from provider',
      () async {
    final api = ApiService(
      providers: [_FakeCoreProvider()],
      loadCricsheetSample: false,
    );
    final detail = await api.fetchMatchDetail('match-1');
    expect(detail, isNotNull);
    expect(detail!.innings.length, 1);
    expect(detail.innings.first.batting.first.playerName, 'Batter One');
    expect(detail.innings.first.bowling.first.playerName, 'Bowler One');
  });

  // ---------- Fix 5: HTTP 429 marks quota exhausted ----------
  test('CricAPI 429 marks quotaExhausted and stops further calls',
      skip: !_keyConfigured, () async {
    var calls = 0;
    final client = MockClient((req) async {
      calls++;
      return http.Response('Too Many Requests', 429);
    });
    final p = CricApiProvider(client: client);
    expect(await p.fetchMatches(), isNull);
    expect(p.quotaExhausted, isTrue);
    expect(p.serverHitsLeft, 0);
    expect(await p.fetchMatches(), isNull);
    expect(calls, 1); // second call blocked locally, no HTTP
  });

  test('ApiService quotaState is quotaExhausted after CricAPI 429',
      skip: !_keyConfigured, () async {
    final client = MockClient((req) async {
      return http.Response('Too Many Requests', 429);
    });
    final api = ApiService(
      providers: [CricApiProvider(client: client)],
      loadCricsheetSample: false,
    );
    expect(api.quotaState, QuotaState.unknown);
    await api.fetchMatches();
    expect(api.quotaState, QuotaState.quotaExhausted);
    // Last verified data path: all providers failed -> mock fallback
    // with lastSource mock, so the Home demo banner shows instead
    // of silent demo-as-live.
    expect(api.lastFetchWasMock, isTrue);
  });
}

/// Minimal fake provider: list entry + full scorecard for one match.
/// Proves ApiService.fetchMatchDetail wires list id -> scorecard.
class _FakeCoreProvider implements CricketProvider {
  @override
  String get name => 'FakeCore';
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
  Future<List<CricketMatch>?> fetchMatches() async => [
        CricketMatch(
          id: 'match-1',
          teamA: 'Austria Women',
          teamB: 'Sweden Women',
          startTime: DateTime(2026, 10, 18, 14, 30),
          status: MatchStatus.live,
          scores: const [
            TeamScore(
                team: 'Sweden Women', runs: 124, wickets: 9, batted: true),
          ],
          source: 'FakeCore',
        ),
      ];
  @override
  Future<List<CricketMatch>?> fetchUpcoming() async => null;
  @override
  Future<CricketMatch?> fetchScorecard(String matchId) async {
    if (matchId != 'match-1') return null;
    return CricketMatch(
      id: 'match-1',
      teamA: 'Austria Women',
      teamB: 'Sweden Women',
      startTime: DateTime(2026, 10, 18, 14, 30),
      status: MatchStatus.live,
      scores: const [
        TeamScore(team: 'Sweden Women', runs: 124, wickets: 9, batted: true),
      ],
      innings: const [
        Innings(
          team: 'Sweden Women',
          total: 124,
          wickets: 9,
          overs: 20,
          batting: [
            BattingEntry(
              playerId: 'b1',
              playerName: 'Batter One',
              runs: 52,
              balls: 30,
              dismissal: 'c X b Y',
            ),
          ],
          bowling: [
            BowlingEntry(
              playerId: 'bw1',
              playerName: 'Bowler One',
              overs: 4,
              runsConceded: 30,
              wickets: 2,
            ),
          ],
        ),
      ],
      source: 'FakeCore',
    );
  }

  @override
  Future<List<Map<String, dynamic>>?> fetchSeries() async => null;
  @override
  Future<Player?> fetchPlayer(String playerId) async => null;
}
