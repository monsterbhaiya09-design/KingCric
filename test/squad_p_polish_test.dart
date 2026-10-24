import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingcric/models/match.dart';
import 'package:kingcric/widgets/empty_state.dart';
import 'package:kingcric/widgets/match_card.dart';

Widget wrap(Widget child) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    );

CricketMatch cardMatch({
  String teamA = 'bulgaria women',
  String teamB = 'sweden women',
  String league = 'International',
}) {
  return CricketMatch(
    id: 'p-1',
    teamA: teamA,
    teamB: teamB,
    league: league,
    format: 'T20',
    venueName: 'rawalpindi cricket stadium',
    startTime: DateTime(2026, 10, 24, 15, 30),
    status: MatchStatus.live,
    scores: const [
      TeamScore(team: 'bulgaria women', runs: 99, wickets: 0, overs: 5.5, batted: true),
      TeamScore(team: 'sweden women', runs: 124, wickets: 9, overs: 20.0, batted: true),
    ],
    source: 'CricAPI',
  );
}

void main() {
  testWidgets('EmptyState renders icon + message + exactly one action',
      (tester) async {
    var fired = false;
    await tester.pumpWidget(wrap(EmptyState(
      icon: Icons.sports_cricket,
      message: 'No live matches right now.',
      actionLabel: 'Refresh',
      onAction: () => fired = true,
    )));
    expect(find.text('No live matches right now.'), findsOneWidget);
    expect(find.text('Refresh'), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    expect(fired, isTrue);
  });

  testWidgets('EmptyState action button is 48dp tall', (tester) async {
    await tester.pumpWidget(wrap(EmptyState(
      icon: Icons.event_busy,
      message: 'Nothing here yet.',
      actionLabel: 'Retry',
      onAction: () {},
    )));
    final size = tester.getSize(find.byType(FilledButton));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('Card title-cases lowercase team names', (tester) async {
    await tester.pumpWidget(wrap(KingMatchCard(
      match: cardMatch(),
      onTap: () {},
    )));
    expect(find.text('Bulgaria Women'), findsWidgets);
    expect(find.text('Sweden Women'), findsWidgets);
    expect(find.text('bulgaria women'), findsNothing);
    expect(find.text('sweden women'), findsNothing);
  });

  testWidgets('Card keeps short acronyms and venue title case',
      (tester) async {
    await tester.pumpWidget(wrap(KingMatchCard(
      match: cardMatch(league: 'IPL'),
      onTap: () {},
    )));
    // League acronym untouched, venue title-cased.
    expect(find.textContaining('IPL • T20'), findsOneWidget);
    expect(find.textContaining('Rawalpindi Cricket Stadium'),
        findsOneWidget);
  });

  testWidgets('Card team rows use end ellipsis, never mid-word clip',
      (tester) async {
    const long = 'a very long team name that keeps going and going';
    final match = CricketMatch(
      id: 'p-2',
      teamA: long,
      teamB: 'sweden women',
      league: 'International',
      format: 'T20',
      startTime: DateTime(2026, 10, 24, 15, 30),
      status: MatchStatus.live,
      scores: const [
        TeamScore(
            team: long, runs: 99, wickets: 0, overs: 5.5, batted: true),
        TeamScore(
            team: 'sweden women',
            runs: 124,
            wickets: 9,
            overs: 20.0,
            batted: true),
      ],
      source: 'CricAPI',
    );
    await tester.pumpWidget(wrap(KingMatchCard(
      match: match,
      onTap: () {},
    )));
    final finder = find.text(
        'a Very Long Team Name That Keeps Going and Going');
    expect(finder, findsOneWidget);
    final text = tester.widget<Text>(finder);
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
    expect(text.softWrap, isFalse);
  });
}
