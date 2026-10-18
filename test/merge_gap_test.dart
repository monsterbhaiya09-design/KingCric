import 'package:flutter_test/flutter_test.dart';
import 'package:kingcric/models/match.dart';
import 'package:kingcric/services/api_service.dart';

/// Merge-gap regressions (merge lead):
/// HomeScreen._load calls mergeMatches([live, upcoming]) WITHOUT
/// providerNames. That path must keep same-teams/same-day
/// double-headers distinct (same-provider + different-id rule via
/// the per-entry source fallback) and must still merge the same
/// fixture seen in both lists into one card.
CricketMatch _m(
  String id,
  String teamA,
  String teamB, {
  DateTime? start,
  String league = 'International',
  String format = 'T20',
  String source = 'CricAPI',
  MatchStatus status = MatchStatus.upcoming,
  List<TeamScore> scores = const [],
}) {
  return CricketMatch(
    id: id,
    teamA: teamA,
    teamB: teamB,
    startTime: start ?? DateTime(2026, 10, 24, 14, 30),
    status: status,
    scores: scores,
    league: league,
    format: format,
    source: source,
  );
}

void main() {
  test(
      'Home path (no providerNames): double-header same teams/day/'
      'format/league, different start hour -> BOTH kept', () {
    final first = _m('cricapi-dh-1', 'India', 'Pakistan',
        start: DateTime(2026, 10, 24, 14, 30));
    final second = _m('cricapi-dh-2', 'India', 'Pakistan',
        start: DateTime(2026, 10, 24, 19, 30));
    // Exactly the Home shape: two already-merged lists, no names.
    final merged = ApiService.mergeMatches([
      [first],
      [second],
    ]);
    expect(merged.length, 2);
    expect(merged.map((m) => m.id),
        containsAll(['cricapi-dh-1', 'cricapi-dh-2']));
  });

  test(
      'Home path (no providerNames): same fixture from 2 providers '
      'merges to 1', () {
    final a = _m('cricapi-uuid', 'India', 'Pakistan', source: 'CricAPI');
    final b = _m('sportscore-99', 'India', 'Pakistan',
        source: 'SportScore');
    final merged = ApiService.mergeMatches([
      [a],
      [b],
    ]);
    expect(merged.length, 1);
  });

  test(
      'Home path (no providerNames): same fixture in live + upcoming '
      'lists merges to 1, live copy wins', () {
    final liveCopy = _m('same-1', 'India', 'Pakistan',
        status: MatchStatus.live,
        scores: const [
          TeamScore(team: 'Pakistan', runs: 160, wickets: 5, batted: true),
        ]);
    final upcomingCopy = _m('same-1', 'India', 'Pakistan',
        status: MatchStatus.upcoming);
    final merged = ApiService.mergeMatches([
      [liveCopy],
      [upcomingCopy],
    ]);
    expect(merged.length, 1);
    expect(merged.first.id, 'same-1');
    expect(merged.first.status, MatchStatus.live);
  });
}
