import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/innings.dart';
import '../../models/match.dart';
import '../../models/player.dart';
import '../../utils/constants.dart';
import '../mock_data_service.dart';
import 'cricket_provider.dart';

/// PRIMARY provider: CricAPI / CricketData.org.
/// Base: https://api.cricapi.com/v1 — `?apikey=` query param.
/// Lifetime free tier: 100 hits/day, no card. Covers live scores,
/// ball-by-ball, full scorecards, player profiles, series, squads.
/// Envelope: {"status":"success","info":{...},"data":[...]}.
/// Moved verbatim from the old single-provider ApiService so behaviour
/// is unchanged; the orchestrator now calls this via the interface.
class CricApiProvider implements CricketProvider {
  final http.Client _client;
  final MockDataService _mock = MockDataService();
  int _hits = 0;

  CricApiProvider({http.Client? client}) : _client = client ?? http.Client();

  @override
  String get name => 'CricAPI';

  @override
  bool get isConfigured => AppConstants.cricApiKey.isNotEmpty;

  @override
  int get dailyCap => AppConstants.cricApiDailyCap;

  @override
  int get hitsToday => _hits;

  bool get _capped => _hits >= dailyCap;

  Future<http.Response?> _get(Uri uri) async {
    if (_capped) return null;
    _hits++;
    try {
      return await _client.get(uri).timeout(const Duration(seconds: 15));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> testKey() async {
    final k = AppConstants.cricApiKey.trim();
    if (k.isEmpty) return false;
    try {
      final uri = Uri.parse(
          '${AppConstants.cricApiBaseUrl}/currentMatches?apikey=$k');
      final res = await _client.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return false;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return body['status'] == 'success';
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<CricketMatch>?> fetchMatches() async {
    if (!isConfigured || _capped) return null;
    final uri = Uri.parse(
        '${AppConstants.cricApiBaseUrl}/currentMatches?apikey=${AppConstants.cricApiKey}');
    final res = await _get(uri);
    if (res == null || res.statusCode != 200) return null;
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['status'] == 'failure') return null;
      final list = (body['data'] as List?) ?? [];
      final parsed = <CricketMatch>[];
      for (final e in list) {
        try {
          parsed.add(_matchFromFreeApi((e as Map).cast<String, dynamic>()));
        } catch (_) {}
      }
      return parsed.isEmpty ? null : parsed;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<CricketMatch?> fetchScorecard(String matchId) async {
    if (!isConfigured || _capped) return null;
    final uri = Uri.parse(
        '${AppConstants.cricApiBaseUrl}/cricketScore?apikey=${AppConstants.cricApiKey}&id=$matchId');
    final res = await _get(uri);
    if (res == null || res.statusCode != 200) return null;
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['status'] == 'failure') return null;
      final data = (body['data'] as Map?)?.cast<String, dynamic>();
      if (data == null || data.isEmpty) return null;
      return _matchFromScorecard(data);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Map<String, dynamic>>?> fetchSeries() async {
    if (!isConfigured || _capped) return null;
    final uri = Uri.parse(
        '${AppConstants.cricApiBaseUrl}/series?apikey=${AppConstants.cricApiKey}&offset=0');
    final res = await _get(uri);
    if (res == null || res.statusCode != 200) return null;
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['status'] == 'failure') return null;
      final list = (body['data'] as List?) ?? [];
      final parsed = <Map<String, dynamic>>[];
      for (final e in list) {
        try {
          final m = (e as Map).cast<String, dynamic>();
          parsed.add({
            'id': m['id']?.toString() ?? '',
            'name': m['name'] as String? ?? '',
            'startDate': m['startDate'] as String? ?? '',
            'endDate': m['endDate'] as String? ?? '',
            'matches': (m['matches'] as num?)?.toInt() ?? 0,
          });
        } catch (_) {}
      }
      return parsed.isEmpty ? null : parsed;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Player?> fetchPlayer(String playerId) async {
    if (!isConfigured || _capped) return null;
    final uri = Uri.parse(
        '${AppConstants.cricApiBaseUrl}/players_info?apikey=${AppConstants.cricApiKey}&id=$playerId');
    final res = await _get(uri);
    if (res == null || res.statusCode != 200) return null;
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['status'] == 'failure') return null;
      final data = (body['data'] as Map?)?.cast<String, dynamic>() ?? {};
      final base = _mock.playerById(playerId);
      if (base == null) return null;
      return Player(
        id: data['id']?.toString() ?? base.id,
        name: data['name'] as String? ?? base.name,
        team: base.team,
        role: data['role'] as String? ?? base.role,
        battingStyle: data['battingStyle'] as String? ?? base.battingStyle,
        bowlingStyle: data['bowlingStyle'] as String? ?? base.bowlingStyle,
        country: data['placeOfBirth'] as String? ?? base.country,
        battingByFormat: base.battingByFormat,
        bowlingByFormat: base.bowlingByFormat,
        battingVsOpponent: base.battingVsOpponent,
        bowlingVsOpponent: base.bowlingVsOpponent,
        battingByLeague: base.battingByLeague,
        battingByVenue: base.battingByVenue,
        recentForm: base.recentForm,
        matchups: base.matchups,
        dismissalHistory: base.dismissalHistory,
        dataComplete: false,
        // Honest source: provider gave identity only; the deep
        // stats riding along are the curated demo set (dataComplete
        // false), NOT CricAPI-verified career numbers.
        source: 'cricapi',
        lastUpdated: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  CricketMatch _matchFromFreeApi(Map<String, dynamic> j) {
    final teams = ((j['teams'] as List?) ?? []).map((e) => '$e').toList();
    final teamA = ProviderParsing.titleCaseTeam(
        teams.isNotEmpty ? teams[0] : 'Team A');
    final teamB = ProviderParsing.titleCaseTeam(
        teams.length > 1 ? teams[1] : 'Team B');
    // CricAPI booleans may arrive as bool or "true"/"false" strings.
    bool? asBool(Object? v) {
      if (v is bool) return v;
      if (v is String) {
        if (v.toLowerCase() == 'true') return true;
        if (v.toLowerCase() == 'false') return false;
      }
      return null;
    }

    final score = (j['score'] as List?) ?? [];
    final hasScores = score.any((s) {
      final m = (s as Map).cast<String, dynamic>();
      final r = (m['r'] as num?)?.toInt() ?? 0;
      final w = (m['w'] as num?)?.toInt() ?? 0;
      final o = (m['o'] as num?)?.toDouble() ?? 0;
      return r > 0 || w > 0 || o > 0;
    });
    // V3 BUG FIX: status text alone misclassifies in-progress matches
    // ("...need 88 runs in 78 balls" has no "live"/"won"). Resolve from
    // matchStarted/matchEnded + scores + status text together.
    final status = ProviderParsing.resolveStatus(
      raw: j['status'] as String? ?? '',
      matchStarted: asBool(j['matchStarted']),
      matchEnded: asBool(j['matchEnded']),
      hasScores: hasScores,
    );
    final scores = <TeamScore>[];
    for (final s in score) {
      final m = (s as Map).cast<String, dynamic>();
      final r = (m['r'] as num?)?.toInt() ?? 0;
      final w = (m['w'] as num?)?.toInt() ?? 0;
      final o = (m['o'] as num?)?.toDouble() ?? 0;
      scores.add(TeamScore(
        // V3 BUG FIX: `inning` can be a comma-joined pair
        // ("Bulgaria Women,Sweden Women Inning 2") or lowercase
        // ("bulgaria women Inning 1"). Clean to ONE title-cased team.
        team: ProviderParsing.cleanTeamName(
            m['inning'] as String? ?? '', [teamA, teamB]),
        runs: r,
        wickets: w,
        overs: o,
        batted: true,
      ));
    }
    return CricketMatch(
      id: j['id']?.toString() ?? j['matchId']?.toString() ?? '',
      teamA: teamA,
      teamB: teamB,
      format: j['matchType'] as String? ?? 'T20',
      league: j['series'] as String? ?? 'International',
      venueName: j['venue'] as String? ?? '',
      startTime: DateTime.tryParse(j['dateTimeGMT'] as String? ?? '') ??
          DateTime.now(),
      status: status,
      scores: scores,
      result: j['status'] as String? ?? '',
      toss: _tossText(j),
      lastUpdated: DateTime.now(),
    );
  }

  String _tossText(Map<String, dynamic> j) {
    final winner = j['tossWinner'] as String? ?? '';
    final choice = j['tossChoice'] as String? ?? '';
    if (winner.isEmpty) return '';
    if (choice.isEmpty) return '$winner won the toss';
    return '$winner won the toss and chose to $choice';
  }

  CricketMatch _matchFromScorecard(Map<String, dynamic> j) {
    final base = _matchFromFreeApi(j);
    final rawInnings = (j['scorecard'] as List?) ?? [];
    final innings = <Innings>[];
    var inningsNumber = 0;
    for (final raw in rawInnings) {
      inningsNumber += 1;
      try {
        innings.add(_inningsFromScorecard(
          (raw as Map).cast<String, dynamic>(),
          inningsNumber,
        ));
      } catch (_) {}
    }
    final winner = j['matchWinner'] as String? ?? '';
    final result = winner.isNotEmpty ? '$winner won' : base.result;
    return CricketMatch(
      id: base.id,
      teamA: base.teamA,
      teamB: base.teamB,
      format: base.format,
      league: base.league,
      venueName: base.venueName,
      startTime: base.startTime,
      status: base.status,
      scores: base.scores,
      result: result,
      toss: base.toss,
      innings: innings,
      lastUpdated: DateTime.now(),
    );
  }

  Innings _inningsFromScorecard(
      Map<String, dynamic> j, int inningsNumber) {
    final battingRaw = (j['batting'] as List?) ?? [];
    final bowlingRaw = (j['bowling'] as List?) ?? [];
    final batting = <BattingEntry>[];
    for (final b in battingRaw) {
      final m = (b as Map).cast<String, dynamic>();
      final dismissal = (m['dismissal'] as String? ?? '').trim();
      batting.add(BattingEntry(
        playerId: m['batter'] as String? ?? '',
        playerName: m['batter'] as String? ?? '',
        runs: (m['r'] as num?)?.toInt() ?? 0,
        balls: (m['b'] as num?)?.toInt() ?? 0,
        fours: (m['4s'] as num?)?.toInt() ?? 0,
        sixes: (m['6s'] as num?)?.toInt() ?? 0,
        dismissal: dismissal.isEmpty ? 'not out' : dismissal,
        notOut: dismissal.isEmpty ||
            dismissal.toLowerCase().contains('not out'),
      ));
    }
    final bowling = <BowlingEntry>[];
    for (final b in bowlingRaw) {
      final m = (b as Map).cast<String, dynamic>();
      final overs = (m['o'] as num?)?.toDouble() ?? 0;
      final runs = (m['r'] as num?)?.toInt() ?? 0;
      final wickets = (m['w'] as num?)?.toInt() ?? 0;
      bowling.add(BowlingEntry(
        playerId: m['bowler'] as String? ?? '',
        playerName: m['bowler'] as String? ?? '',
        overs: overs,
        maidens: (m['m'] as num?)?.toInt() ?? 0,
        runsConceded: runs,
        wickets: wickets,
        economy: (m['eco'] as num?)?.toDouble() ??
            (overs > 0 ? runs / overs : 0),
        wides: (m['wd'] as num?)?.toInt() ?? 0,
        noBalls: (m['nb'] as num?)?.toInt() ?? 0,
      ));
    }
    final extras = (j['extras'] as Map?)?.cast<String, dynamic>() ?? {};
    final extrasRuns = (extras['r'] as num?)?.toInt() ?? 0;
    final extrasParts = <String>[];
    for (final key in ['b', 'lb', 'wd', 'nb', 'pen']) {
      final v = (extras[key] as num?)?.toInt() ?? 0;
      if (v > 0) extrasParts.add('${key.toUpperCase()} $v');
    }
    final fowRaw = (j['fallofwickets'] as List?) ?? [];
    final fow = <String>[];
    for (final f in fowRaw) {
      final m = (f as Map).cast<String, dynamic>();
      final name = m['name'] as String? ?? '';
      final score = (m['score'] as num?)?.toInt() ?? 0;
      final over = m['over'] as String? ?? '';
      if (name.isNotEmpty) fow.add('$score-$name ($over ov)');
    }
    final total = (j['total'] as num?)?.toInt() ??
        batting.fold<int>(0, (acc, b) => acc + b.runs) + extrasRuns;
    final wickets = (j['wickets'] as num?)?.toInt() ??
        batting.where((b) => !b.notOut).length;
    return Innings(
      team: ProviderParsing.cleanTeamName(
          j['inning'] as String? ?? '', null),
      inningsNumber: inningsNumber,
      total: total,
      wickets: wickets,
      overs: (j['overs'] as num?)?.toDouble() ?? 0,
      batting: batting,
      bowling: bowling,
      fallOfWickets: fow,
      extrasRuns: extrasRuns,
      extrasText:
          extrasParts.isEmpty ? '' : '${extrasParts.join(', ')} ($extrasRuns)',
    );
  }
}
