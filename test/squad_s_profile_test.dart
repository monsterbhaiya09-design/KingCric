import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:kingcric/models/player.dart';
import 'package:kingcric/models/prediction.dart';
import 'package:kingcric/screens/player_profile_screen.dart';
import 'package:kingcric/utils/strings.dart';
import 'package:kingcric/widgets/h2h_card.dart';
import 'package:kingcric/widgets/prediction_card.dart';
import 'package:kingcric/widgets/squad_player_card.dart';

/// Final Squad S: profile split (STATS first, ABOUT second),
/// missing sections hidden, fake zeros -> '—', honest H2H /
/// prediction empty states, tappable names, source labels.
void main() {
  // Tall viewport so a whole profile lays out at once (order
  // checks compare on-screen positions).
  void tallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 12000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget profileApp(Player p, {String? opponent}) {
    return ChangeNotifierProvider<LanguageProvider>(
      create: (_) => LanguageProvider(),
      child: MaterialApp(home: PlayerProfileScreen(player: p, opponent: opponent)),
    );
  }

  Widget cardApp(Widget child) {
    return ChangeNotifierProvider<LanguageProvider>(
      create: (_) => LanguageProvider(),
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  const t20 = BattingStats(
      matches: 20, innings: 20, runs: 640, balls: 480, fifties: 5, hundreds: 1, fours: 60, sixes: 20, average: 40.0, strikeRate: 133.3, highest: 92);

  const realPlayer = Player(
    id: 'p-1',
    name: 'Test Batter',
    team: 'India',
    role: 'Batter',
    battingStyle: 'Right-hand bat',
    bowlingStyle: '',
    country: 'India',
    battingByFormat: {'T20': t20},
    battingVsOpponent: {'Australia': t20},
    battingByVenue: {'MCG': t20},
    recentForm: [
      FormEntry(matchLabel: 'IND v AUS', opponent: 'Australia', format: 'T20', runs: 45, balls: 30, result: 'W'),
    ],
    matchups: [
      Matchup(bowlerId: 'b-1', bowlerName: 'Test Bowler', batterId: 'p-1', batterName: 'Test Batter', matches: 4, balls: 24, runs: 30, dismissals: 2),
    ],
    dismissalHistory: ['c Smith b Cummins — 3 times'],
    source: 'cricsheet',
    sourceMatches: 21,
  );

  const zeroBat = BattingStats();

  group('Profile split: STATS first, ABOUT second', () {
    testWidgets('Stats header sits above About; About carries identity + source', (tester) async {
      tallViewport(tester);
      await tester.pumpWidget(profileApp(realPlayer));
      await tester.pumpAndSettle();
      expect(find.text('Stats'), findsOneWidget);
      expect(find.text('About'), findsOneWidget);
      final statsY = tester.getTopLeft(find.text('Stats')).dy;
      final aboutY = tester.getTopLeft(find.text('About')).dy;
      expect(aboutY, greaterThan(statsY));
      // About rows.
      expect(find.text('Team'), findsOneWidget);
      expect(find.text('India'), findsWidgets);
      expect(find.text('Role'), findsOneWidget);
      expect(find.text('Batter'), findsWidgets);
      expect(find.text('Batting style'), findsOneWidget);
      // Source line: per-player count (dataset size no longer
      // hardcoded — full archive replaced the 420-match sample).
      expect(find.textContaining('Real • Cricsheet'), findsOneWidget);
      expect(find.textContaining('21 matches for this player'), findsOneWidget);
      // Stats sections present.
      expect(find.text('Overall — All Formats'), findsOneWidget);
      expect(find.text('All Formats — Full Table'), findsOneWidget);
    });

    testWidgets('missing sections are hidden, never fake rows', (tester) async {
      tallViewport(tester);
      const bare = Player(id: 'p-0', name: 'No Data', team: '', role: '');
      await tester.pumpWidget(profileApp(bare));
      await tester.pumpAndSettle();
      expect(find.text('Leagues'), findsNothing);
      expect(find.text('Dismissal History'), findsNothing);
      expect(find.text('All Formats — Full Table'), findsNothing);
      expect(find.text('Venue'), findsNothing);
      expect(find.text('Recent Form'), findsNothing);
      expect(find.text('Bowler vs Batter'), findsNothing);
      expect(find.text('No profile details available yet.'), findsOneWidget);
      // Demo/partial source, not a fake 'Complete'.
      expect(find.textContaining('Partial'), findsOneWidget);
    });

    testWidgets('zero-match player shows — for rates, never 0.0', (tester) async {
      tallViewport(tester);
      const zero = Player(
        id: 'p-z',
        name: 'Zero Player',
        team: 'Nowhere',
        battingByFormat: {'T20': zeroBat},
      );
      await tester.pumpWidget(profileApp(zero));
      await tester.pumpAndSettle();
      expect(find.text('—'), findsWidgets);
      // The format table renders Avg/SR as '—' for a 0-match row.
      expect(find.textContaining('Avg 0.0'), findsNothing);
    });
  });

  group('SquadPlayerCard', () {
    testWidgets('source labels by provenance + tap fires', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(cardApp(SquadPlayerCard(
        player: realPlayer,
        opponent: 'Australia',
        format: 'T20',
        onTap: () => tapped++,
      )));
      await tester.pump();
      expect(find.text('Real • Cricsheet'), findsOneWidget);
      expect(find.text('Tap for full profile'), findsOneWidget);
      await tester.tap(find.byType(SquadPlayerCard));
      expect(tapped, 1);
    });

    testWidgets('demo / partial / scorecard-only labels', (tester) async {
      await tester.pumpWidget(cardApp(const SquadPlayerCard(
        player: Player(id: 'd', name: 'Demo Player', team: 'X', source: 'demo'),
        opponent: 'Y',
        format: 'T20',
      )));
      await tester.pump();
      expect(find.text('Demo'), findsOneWidget);
      await tester.pumpWidget(cardApp(const SquadPlayerCard(
        player: Player(id: 's', name: 'Score', team: 'X', source: 'scorecard'),
        opponent: 'Y',
        format: 'T20',
      )));
      await tester.pump();
      expect(find.text('Scorecard only'), findsOneWidget);
      await tester.pumpWidget(cardApp(const SquadPlayerCard(
        player: Player(id: 'p', name: 'Part', team: 'X', source: 'provider'),
        opponent: 'Y',
        format: 'T20',
      )));
      await tester.pump();
      expect(find.text('Partial'), findsOneWidget);
    });

    testWidgets('no stats at all -> honest line, no fake zeros; format fallback labelled overall', (tester) async {
      await tester.pumpWidget(cardApp(const SquadPlayerCard(
        player: Player(id: 'z', name: 'Zero', team: 'X'),
        opponent: 'Y',
        format: 'T20',
      )));
      await tester.pump();
      expect(find.text('Stats not available for this player yet.'), findsOneWidget);
      expect(find.textContaining('Avg 0.0'), findsNothing);

      // Player with ODI-only stats shown in a T20 context:
      // batting line must say (overall), not (T20).
      const odiOnly = Player(
        id: 'o',
        name: 'Odi Only',
        team: 'X',
        battingByFormat: {
          'ODI': BattingStats(matches: 5, runs: 200, average: 50.0, strikeRate: 90.0),
        },
      );
      await tester.pumpWidget(cardApp(const SquadPlayerCard(
        player: odiOnly,
        opponent: 'Y',
        format: 'T20',
      )));
      await tester.pump();
      expect(find.textContaining('Batting (overall)'), findsOneWidget);
      expect(find.textContaining('Batting (T20)'), findsNothing);
    });
  });

  group('H2HCard honest states', () {
    testWidgets('total 0 shows — and no-matches text, never 0-0', (tester) async {
      await tester.pumpWidget(cardApp(const H2HCard(
        teamA: 'India',
        teamB: 'Australia',
        winsA: 0,
        winsB: 0,
        total: 0,
      )));
      await tester.pumpAndSettle();
      expect(find.text('—'), findsWidgets);
      expect(find.text('0 — 0'), findsNothing);
      expect(find.text('No head-to-head matches in the loaded data yet.'), findsOneWidget);
      expect(find.text('No matches yet'), findsOneWidget);
    });

    testWidgets('real split renders the scoreline', (tester) async {
      await tester.pumpWidget(cardApp(const H2HCard(
        teamA: 'India',
        teamB: 'Australia',
        winsA: 3,
        winsB: 2,
        total: 5,
      )));
      await tester.pumpAndSettle();
      expect(find.text('3 — 2'), findsOneWidget);
      expect(find.text('5 matches'), findsOneWidget);
    });
  });

  group('PredictionCard honest states', () {
    Prediction noData({double score = 0}) => Prediction(
          playerId: 'p-1',
          playerName: 'Test Batter',
          opponent: 'Australia',
          venueId: '',
          format: 'T20',
          score: score,
          recentFormScore: 0,
          vsOpponentScore: 0,
          venueScore: 0,
          matchupScore: 0,
          pitchScore: 0,
          explanationEn: '',
          explanationHi: '',
          hasData: false,
        );

    testWidgets('no signal -> Not enough data, no fake number', (tester) async {
      await tester.pumpWidget(cardApp(PredictionCard(prediction: noData())));
      await tester.pump();
      expect(find.text('Not enough data to predict.'), findsOneWidget);
      expect(find.text('Not betting advice.'), findsNothing);
    });

    testWidgets('NaN score is also no-data even if hasData is true', (tester) async {
      const p = Prediction(
        playerId: 'p-1',
        playerName: 'Test Batter',
        opponent: 'Australia',
        venueId: '',
        format: 'T20',
        score: double.nan,
        recentFormScore: double.nan,
        vsOpponentScore: double.nan,
        venueScore: double.nan,
        matchupScore: double.nan,
        pitchScore: double.nan,
        explanationEn: '',
        explanationHi: '',
      );
      await tester.pumpWidget(cardApp(const PredictionCard(prediction: p)));
      await tester.pump();
      expect(find.text('Not enough data to predict.'), findsOneWidget);
    });

    testWidgets('real prediction renders verdict + score', (tester) async {
      const p = Prediction(
        playerId: 'p-1',
        playerName: 'Test Batter',
        opponent: 'Australia',
        venueId: '',
        format: 'T20',
        score: 72,
        recentFormScore: 70,
        vsOpponentScore: 80,
        venueScore: 60,
        matchupScore: 65,
        pitchScore: 50,
        explanationEn: 'Good recent form.',
        explanationHi: '',
      );
      await tester.pumpWidget(cardApp(const PredictionCard(prediction: p)));
      await tester.pump();
      expect(find.text('Likely to perform'), findsOneWidget);
      expect(find.text('72'), findsOneWidget);
    });
  });
}
