import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingcric/models/innings.dart';
import 'package:kingcric/models/match.dart';
import 'package:kingcric/models/player.dart';
import 'package:kingcric/services/api_service.dart';
import 'package:kingcric/services/auto_update_service.dart';
import 'package:kingcric/services/completeness_validator.dart';
import 'package:kingcric/services/prediction_engine.dart';
import 'package:kingcric/services/providers/cricket_provider.dart';
import 'package:kingcric/services/smooth_update.dart';

CricketMatch _match({
  String id = 'm1',
  String teamA = 'Pakistan',
  String teamB = 'Sri Lanka',
  String format = 'ODI',
  String league = 'International',
  DateTime? startTime,
  MatchStatus status = MatchStatus.upcoming,
  List<TeamScore> scores = const [],
  String result = '',
  String source = 'CricAPI',
  List<Innings> innings = const [],
}) =>
    CricketMatch(
      id: id,
      teamA: teamA,
      teamB: teamB,
      format: format,
      league: league,
      startTime: startTime ?? DateTime.utc(2026, 10, 18, 10, 0),
      status: status,
      scores: scores,
      result: result,
      source: source,
      innings: innings,
    );

Player _player({
  String id = 'p1',
  String name = 'Test Player',
  String source = 'cricsheet',
  bool dataComplete = true,
  Map<String, BattingStats> battingByFormat = const {},
  Map<String, BowlingStats> bowlingByFormat = const {},
  List<FormEntry> recentForm = const [],
  List<Matchup> matchups = const [],
  DateTime? lastUpdated,
}) =>
    Player(
      id: id,
      name: name,
      team: 'Pakistan',
      battingByFormat: battingByFormat,
      bowlingByFormat: bowlingByFormat,
      recentForm: recentForm,
      matchups: matchups,
      dataComplete: dataComplete,
      source: source,
      sourceMatches: 420,
      lastUpdated: lastUpdated ?? DateTime.now(),
    );

void main() {
  group('Squad E: terminal result phrases', () {
    test('won the toss is NEVER terminal', () {
      expect(CricketMatch.isTerminalResult('Pakistan won the toss and elected to bat'), isFalse);
      expect(CricketMatch.isTerminalResult('X won the toss, chose to bowl'), isFalse);
      expect(CricketMatch.isTerminalResult('Stumps, Day 1'), isFalse);
      expect(CricketMatch.isTerminalResult('Austria Women need 88 runs in 78 balls'), isFalse);
      expect(CricketMatch.isTerminalResult(''), isFalse);
    });

    test('result phrases are terminal', () {
      expect(CricketMatch.isTerminalResult('Pakistan won by 5 wickets'), isTrue);
      expect(CricketMatch.isTerminalResult('India won the match by 5 wickets'), isTrue);
      expect(CricketMatch.isTerminalResult('Match ended'), isTrue);
      expect(CricketMatch.isTerminalResult('Match drawn'), isTrue);
      expect(CricketMatch.isTerminalResult('No result'), isTrue);
      expect(CricketMatch.isTerminalResult('Match abandoned'), isTrue);
      expect(CricketMatch.isTerminalResult('Sweden Women won by 10 wkts'), isTrue);
    });
  });

  group('Squad E: isEffectivelyLive / isCompleted', () {
    test('toss + scores = effectively live, not completed', () {
      final m = _match(
        result: 'Pakistan won the toss and elected to bat',
        scores: const [TeamScore(team: 'Pakistan', runs: 42, wickets: 1, overs: 8, batted: true)],
      );
      expect(m.isEffectivelyLive, isTrue);
      expect(m.isCompleted, isFalse);
    });

    test('result phrase = completed, never live — even with stale status live', () {
      final m = _match(
        status: MatchStatus.live,
        result: 'Pakistan won by 5 wickets',
        scores: const [TeamScore(team: 'Pakistan', runs: 250, wickets: 5, batted: true)],
      );
      expect(m.isCompleted, isTrue);
      expect(m.isEffectivelyLive, isFalse);
    });

    test('upcoming + no scores = neither live nor completed', () {
      final m = _match();
      expect(m.isEffectivelyLive, isFalse);
      expect(m.isCompleted, isFalse);
    });

    test('upcoming + scores + result phrase = completed', () {
      final m = _match(
        result: 'Sri Lanka won by 3 wickets',
        scores: const [TeamScore(team: 'Sri Lanka', runs: 251, wickets: 7, batted: true)],
      );
      expect(m.isCompleted, isTrue);
      expect(m.isEffectivelyLive, isFalse);
    });

    test('upcoming + placeholder 0/0 row only = NOT live', () {
      final m = _match(
        scores: const [TeamScore(team: 'Pakistan', runs: 0, wickets: 0, overs: 0, batted: true)],
      );
      expect(m.isEffectivelyLive, isFalse);
    });
  });

  group('Squad E: TeamScore.isMeaningful', () {
    test('placeholder 0/0 row is not meaningful', () {
      expect(const TeamScore(team: 'X', batted: true).isMeaningful, isFalse);
      expect(const TeamScore(team: 'X', batted: false, runs: 100).isMeaningful, isFalse);
    });
    test('any real action is meaningful', () {
      expect(const TeamScore(team: 'X', batted: true, runs: 1).isMeaningful, isTrue);
      expect(const TeamScore(team: 'X', batted: true, wickets: 1).isMeaningful, isTrue);
      expect(const TeamScore(team: 'X', batted: true, overs: 0.1).isMeaningful, isTrue);
    });
  });

  group('Squad E: MatchMerge dedupe', () {
    test('same fixture with swapped team order shares a key', () {
      final a = _match();
      final b = _match(teamA: 'Sri Lanka', teamB: 'Pakistan');
      expect(MatchMerge.dedupeKey(a), MatchMerge.dedupeKey(b));
      expect(MatchMerge.mergeCandidates(a, b), isTrue);
    });

    test('different league = different fixture', () {
      final a = _match();
      final b = _match(league: 'Asia Cup');
      expect(MatchMerge.dedupeKey(a) == MatchMerge.dedupeKey(b), isFalse);
      expect(MatchMerge.mergeCandidates(a, b), isFalse);
    });

    test('empty league folds into the same fixture', () {
      final a = _match(league: '');
      final b = _match(league: 'International');
      expect(MatchMerge.mergeCandidates(a, b), isTrue);
    });

    test('different day = different fixture', () {
      final a = _match();
      final b = _match(startTime: DateTime.utc(2026, 10, 19, 10, 0));
      expect(MatchMerge.mergeCandidates(a, b), isFalse);
    });

    test('same provider, different ids = DISTINCT matches, never merge (double-header)', () {
      final a = _match(id: 'p1-match-1', source: 'CricAPI');
      final b = _match(id: 'p1-match-2', source: 'CricAPI');
      expect(MatchMerge.mergeCandidates(a, b), isFalse);
    });

    test('different providers, same fixture = merge', () {
      final a = _match(id: 'uuid-1', source: 'SportScore');
      final b = _match(id: '12345', source: 'CricAPI');
      expect(MatchMerge.mergeCandidates(a, b), isTrue);
    });
  });

  group('Squad E: MatchMerge richness', () {
    test('full scorecard dominates scores-only', () {
      final scoresOnly = _match(scores: const [
        TeamScore(team: 'Pakistan', runs: 200, wickets: 6, batted: true),
      ]);
      final withCard = _match(
        scores: const [TeamScore(team: 'Pakistan', runs: 100, wickets: 2, batted: true)],
        innings: const [Innings(team: 'Pakistan', total: 100, wickets: 2)],
      );
      expect(MatchMerge.richness(withCard) > MatchMerge.richness(scoresOnly), isTrue);
      expect(MatchMerge.pickRicher(scoresOnly, withCard), withCard);
    });

    test('placeholder copy loses to one-real-score copy', () {
      final placeholder = _match(source: 'SportScore', scores: const [
        TeamScore(team: 'Pakistan', runs: 120, wickets: 4, batted: true),
        TeamScore(team: 'Sri Lanka', runs: 0, wickets: 0, batted: true),
      ]);
      final live = _match(
        source: 'CricAPI',
        status: MatchStatus.live,
        scores: const [
          TeamScore(team: 'Pakistan', runs: 120, wickets: 4, batted: true),
        ],
      );
      // Both have 1 meaningful score, but the placeholder row
      // costs -1, so the clean live copy wins. The placeholder
      // copy never wins on raw scores.length again.
      expect(MatchMerge.meaningfulScoreCount(placeholder), 1);
      expect(MatchMerge.pickRicher(placeholder, live), live);
    });

    test('completed beats live at equal scores', () {
      final live = _match(
        status: MatchStatus.live,
        scores: const [TeamScore(team: 'Pakistan', runs: 200, wickets: 6, batted: true)],
      );
      final done = _match(
        status: MatchStatus.upcoming,
        result: 'Pakistan won by 5 wickets',
        scores: const [TeamScore(team: 'Pakistan', runs: 200, wickets: 6, batted: true)],
      );
      expect(MatchMerge.pickRicher(live, done), done);
    });

    test('richness tie prefers non-demo source', () {
      final demo = _match(source: 'demo');
      final real = _match(source: 'CricAPI');
      expect(MatchMerge.pickRicher(demo, real), real);
    });
  });

  group('Squad E: prediction hasData guard', () {
    test('no signal -> hasData false, score 0, never fake ~50', () {
      final p = _player(
        battingByFormat: const {},
        dataComplete: false,
        source: '',
      );
      final pred = PredictionEngine.predict(
        player: p,
        opponent: 'Sri Lanka',
        venueId: 'v1',
        format: 'ODI',
      );
      expect(pred.hasData, isFalse);
      expect(pred.score, 0.0);
      expect(pred.explanationEn, contains('Not enough data'));
    });

    test('NaN pitch friendliness -> finite score', () {
      final p = _player(
        battingByFormat: const {
          'ODI': BattingStats(matches: 10, innings: 10, runs: 450, balls: 500, average: 45),
        },
        recentForm: const [
          FormEntry(matchLabel: 'v SL', opponent: 'Sri Lanka', format: 'ODI', runs: 60, balls: 50),
        ],
      );
      final pred = PredictionEngine.predict(
        player: p,
        opponent: 'Sri Lanka',
        venueId: 'v1',
        format: 'ODI',
        pitchBattingFriendliness: double.nan,
      );
      expect(pred.score.isFinite, isTrue);
      expect(pred.hasData, isTrue);
    });

    test('bowling-only player IS a signal', () {
      final p = _player(
        battingByFormat: const {},
        bowlingByFormat: const {
          'ODI': BowlingStats(matches: 20, wickets: 30, balls: 1000, runsConceded: 800),
        },
      );
      final pred = PredictionEngine.predict(
        player: p,
        opponent: 'Sri Lanka',
        venueId: 'v1',
        format: 'ODI',
      );
      expect(pred.hasData, isTrue);
      expect(pred.score.isFinite, isTrue);
    });

    test('NaN batting average -> finite score', () {
      final p = _player(
        battingByFormat: const {
          'ODI': BattingStats(matches: 5, innings: 5, runs: 100, balls: 90, average: double.nan),
        },
      );
      final pred = PredictionEngine.predict(
        player: p,
        opponent: 'Sri Lanka',
        venueId: 'v1',
        format: 'ODI',
      );
      expect(pred.score.isFinite, isTrue);
    });
  });

  group('Squad E: completeness honesty', () {
    test('demo profile is never Complete', () {
      final demo = _player(
        source: 'demo',
        dataComplete: false,
        battingByFormat: const {
          'ODI': BattingStats(matches: 100, innings: 100, runs: 5000, balls: 5000, average: 50),
        },
        recentForm: const [
          FormEntry(matchLabel: 'v SL', opponent: 'Sri Lanka', format: 'ODI', runs: 50, balls: 40),
        ],
      );
      expect(CompletenessValidator.isPlayerComplete(demo), isFalse);
      expect(CompletenessValidator.completenessLabel(demo), 'Demo');
    });

    test('cricsheet profile with full data is Complete', () {
      final real = _player(
        source: 'cricsheet',
        dataComplete: true,
        battingByFormat: const {
          'ODI': BattingStats(matches: 100, innings: 100, runs: 5000, balls: 5000, average: 50),
        },
        recentForm: const [
          FormEntry(matchLabel: 'v SL', opponent: 'Sri Lanka', format: 'ODI', runs: 50, balls: 40),
        ],
      );
      expect(CompletenessValidator.isPlayerComplete(real), isTrue);
      expect(CompletenessValidator.completenessLabel(real), 'Complete');
    });

    test('stale profile is not Complete', () {
      final stale = _player(
        source: 'cricsheet',
        dataComplete: true,
        lastUpdated: DateTime.now().subtract(const Duration(hours: 25)),
        battingByFormat: const {
          'ODI': BattingStats(matches: 10, innings: 10, runs: 100, balls: 100, average: 10),
        },
        recentForm: const [
          FormEntry(matchLabel: 'v SL', opponent: 'Sri Lanka', format: 'ODI', runs: 10, balls: 10),
        ],
      );
      expect(CompletenessValidator.isPlayerComplete(stale), isFalse);
    });

    test('provider-basic partial profile is Partial, never Complete', () {
      final partial = _player(
        source: '',
        dataComplete: false,
        battingByFormat: const {
          'ODI': BattingStats(matches: 10, innings: 10, runs: 100, balls: 100, average: 10),
        },
      );
      expect(CompletenessValidator.isPlayerComplete(partial), isFalse);
      expect(CompletenessValidator.completenessLabel(partial), 'Partial');
    });

    test('matchesAgree uses effective status, not raw field', () {
      final a = _match(
        status: MatchStatus.upcoming,
        result: 'Pakistan won the toss and elected to bat',
        scores: const [TeamScore(team: 'Pakistan', runs: 42, wickets: 1, batted: true)],
      );
      final b = _match(
        status: MatchStatus.live,
        result: 'Pakistan won the toss and elected to bat',
        scores: const [TeamScore(team: 'Pakistan', runs: 42, wickets: 1, batted: true)],
      );
      expect(CompletenessValidator.matchesAgree(a, b), isTrue);
    });
  });

  group('Squad E: smooth-update diff uses effective status', () {
    test('raw status flip with same effective state is NOT a change', () {
      final a = _match(
        status: MatchStatus.upcoming,
        result: 'Pakistan won the toss and elected to bat',
        scores: const [TeamScore(team: 'Pakistan', runs: 42, wickets: 1, batted: true)],
      );
      final b = _match(
        status: MatchStatus.live,
        result: 'Pakistan won the toss and elected to bat',
        scores: const [TeamScore(team: 'Pakistan', runs: 42, wickets: 1, batted: true)],
      );
      expect(MatchDiff.changedIds([a], [b]), isEmpty);
    });

    test('real score change IS a change', () {
      final a = _match(
        status: MatchStatus.live,
        scores: const [TeamScore(team: 'Pakistan', runs: 42, wickets: 1, batted: true)],
      );
      final b = _match(
        status: MatchStatus.live,
        scores: const [TeamScore(team: 'Pakistan', runs: 43, wickets: 1, batted: true)],
      );
      expect(MatchDiff.changedIds([a], [b]), ['m1']);
    });
  });

  group('Squad E: AutoUpdate re-entrancy + finish', () {
    test('start/stop lifecycle never leaks a timer', () {
      final svc = AutoUpdateService(
          api: ApiService(providers: <CricketProvider>[]));
      expect(svc.isRunning, isFalse);
      svc.start();
      expect(svc.isRunning, isTrue);
      svc.start(); // double start: still one timer, no crash
      expect(svc.isRunning, isTrue);
      svc.stop();
      expect(svc.isRunning, isFalse);
      svc.dispose();
      expect(svc.isRunning, isFalse);
    });

    test('overlapping ticks do not stack fetches', () async {
      final fake = _GatedFakeProvider();
      final svc = AutoUpdateService(api: ApiService(providers: [fake]));
      final t1 = svc.tick(); // enters fetch, waits on gate
      await Future<void>.delayed(Duration.zero);
      await svc.tick(); // must return immediately, no second fetch
      expect(fake.fetchCalls, 1);
      fake.release();
      await t1;
      expect(fake.fetchCalls, 1);
      svc.dispose();
    });

    test('finish transition fires once with force-refreshed detail', () async {
      final fake = _ScriptedFakeProvider();
      final svc = AutoUpdateService(api: ApiService(providers: [fake]));
      final finished = <CricketMatch>[];
      svc.addFinishedListener(finished.add);
      await svc.tick(); // first sighting: upcoming, no event
      expect(finished, isEmpty);
      await svc.tick(); // flips to completed -> one event
      expect(finished.length, 1);
      expect(fake.scorecardCalls, 1); // forceRefresh detail fetch
      await svc.tick(); // already completed -> no duplicate event
      expect(finished.length, 1);
      svc.dispose();
    });

    test('tick never throws even when provider explodes', () async {
      final svc = AutoUpdateService(api: ApiService(providers: [_ExplodingProvider()]));
      await svc.tick();
      await svc.resume();
      svc.dispose();
    });
  });
}

/// Fake provider whose fetchMatches waits on a gate, so a test can
/// prove a second overlapping tick is skipped, not stacked.
class _GatedFakeProvider implements CricketProvider {
  final _gate = Completer<void>();
  int fetchCalls = 0;

  void release() {
    if (!_gate.isCompleted) _gate.complete();
  }

  @override
  String get name => 'GatedFake';
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
  Future<List<CricketMatch>?> fetchMatches() async {
    fetchCalls++;
    await _gate.future;
    return [];
  }

  @override
  Future<List<CricketMatch>?> fetchUpcoming() async => null;
  @override
  Future<CricketMatch?> fetchScorecard(String matchId) async => null;
  @override
  Future<List<Map<String, dynamic>>?> fetchSeries() async => null;
  @override
  Future<Player?> fetchPlayer(String playerId) async => null;
}

/// Fake provider with a scripted list: tick 1 upcoming, tick 2+
/// completed — drives the finish-transition path deterministically.
class _ScriptedFakeProvider implements CricketProvider {
  int _calls = 0;
  int scorecardCalls = 0;

  @override
  String get name => 'ScriptedFake';
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
  Future<List<CricketMatch>?> fetchMatches() async {
    _calls++;
    final done = _calls >= 2;
    return [
      CricketMatch(
        id: 'm1',
        teamA: 'Pakistan',
        teamB: 'Sri Lanka',
        startTime: DateTime.utc(2026, 10, 18, 10, 0),
        status: done ? MatchStatus.completed : MatchStatus.upcoming,
        result: done ? 'Pakistan won by 5 wickets' : '',
        source: 'ScriptedFake',
      ),
    ];
  }

  @override
  Future<List<CricketMatch>?> fetchUpcoming() async => null;
  @override
  Future<CricketMatch?> fetchScorecard(String matchId) async {
    scorecardCalls++;
    return CricketMatch(
      id: matchId,
      teamA: 'Pakistan',
      teamB: 'Sri Lanka',
      startTime: DateTime.utc(2026, 10, 18, 10, 0),
      status: MatchStatus.completed,
      result: 'Pakistan won by 5 wickets',
      source: 'ScriptedFake',
    );
  }

  @override
  Future<List<Map<String, dynamic>>?> fetchSeries() async => null;
  @override
  Future<Player?> fetchPlayer(String playerId) async => null;
}

class _ExplodingProvider implements CricketProvider {
  @override
  String get name => 'Exploding';
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
  Future<bool> testKey() async => throw StateError('boom');
  @override
  Future<String?> resolvePlayerId(String name) async => throw StateError('boom');
  @override
  Future<List<CricketMatch>?> fetchMatches() async => throw StateError('boom');
  @override
  Future<List<CricketMatch>?> fetchUpcoming() async => throw StateError('boom');
  @override
  Future<CricketMatch?> fetchScorecard(String matchId) async => throw StateError('boom');
  @override
  Future<List<Map<String, dynamic>>?> fetchSeries() async => throw StateError('boom');
  @override
  Future<Player?> fetchPlayer(String playerId) async => throw StateError('boom');
}
