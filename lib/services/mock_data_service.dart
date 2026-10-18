import '../models/innings.dart';
import '../models/match.dart';
import '../models/player.dart';
import '../models/venue.dart';

/// Realistic demo dataset (NOT real live data — clearly labelled in UI
/// as demo mode until a free API key is configured).
///
/// Covers the spec's example flows:
/// - India vs Pakistan T20 (live) with squads, H2H, venue
/// - IPL match (completed) + Big Bash (upcoming)
/// - Players: Virat Kohli, Rohit Sharma, Babar Azam, Shaheen Afridi,
///   Jasprit Bumrah, Suryakumar Yadav — with format-wise, vs-opponent,
///   league, venue, recent-form and matchup data so every screen has
///   complete, non-empty content in demo mode.
///
/// All totals are internally consistent (see completeness_validator).
class MockDataService {
  static final DateTime _now = DateTime.now();

  List<Venue> venues() => [
        const Venue(
          id: 'v-dubai',
          name: 'Dubai International Stadium',
          city: 'Dubai',
          country: 'UAE',
          pitchType: 'Batting-friendly',
          avgFirstInningsScore: 168,
          avgSecondInningsScore: 152,
          totalMatches: 112,
          batFirstWinPct: 54,
          tossAdvice: 'Bat first — dew helps chasing but average favours batting first.',
        ),
        const Venue(
          id: 'v-wankhede',
          name: 'Wankhede Stadium',
          city: 'Mumbai',
          country: 'India',
          pitchType: 'Batting-friendly',
          avgFirstInningsScore: 178,
          avgSecondInningsScore: 165,
          totalMatches: 98,
          batFirstWinPct: 48,
          tossAdvice: 'Short boundaries — bowlers need variations.',
        ),
        const Venue(
          id: 'v-mcg',
          name: 'Melbourne Cricket Ground',
          city: 'Melbourne',
          country: 'Australia',
          pitchType: 'Pace-friendly',
          avgFirstInningsScore: 158,
          avgSecondInningsScore: 148,
          totalMatches: 140,
          batFirstWinPct: 52,
          tossAdvice: 'Big ground — running between wickets matters.',
        ),
      ];

  List<Player> players() => [
        _virat(),
        _rohit(),
        _babar(),
        _shaheen(),
        _bumrah(),
        _surya(),
      ];

  Player? playerById(String id) {
    for (final p in players()) {
      if (p.id == id) return p;
    }
    return null;
  }

  // ---- Players ---------------------------------------------------------

  Player _virat() => Player(
        id: 'p-virat',
        name: 'Virat Kohli',
        team: 'India',
        role: 'Batter',
        battingStyle: 'Right-hand bat',
        bowlingStyle: 'Right-arm medium',
        country: 'India',
        battingByFormat: {
          'Test': const BattingStats(
              matches: 115, innings: 195, runs: 9056, balls: 16500,
              fifties: 30, hundreds: 30, fours: 1012, sixes: 28,
              average: 48.2, strikeRate: 54.9, highest: 254),
          'ODI': const BattingStats(
              matches: 295, innings: 283, runs: 13906, balls: 14900,
              fifties: 72, hundreds: 50, fours: 1290, sixes: 165,
              average: 58.2, strikeRate: 93.3, highest: 183),
          'T20': const BattingStats(
              matches: 125, innings: 117, runs: 4188, balls: 3050,
              fifties: 38, hundreds: 1, fours: 382, sixes: 124,
              average: 48.7, strikeRate: 137.3, highest: 122),
          'T10': const BattingStats(
              matches: 0, innings: 0, runs: 0, balls: 0, fifties: 0,
              hundreds: 0, fours: 0, sixes: 0, average: 0,
              strikeRate: 0, highest: 0),
        },
        bowlingByFormat: const {
          'ODI': BowlingStats(
              matches: 295, wickets: 5, balls: 240, runsConceded: 210,
              economy: 5.25, average: 42.0, strikeRate: 48.0, best: '1/13'),
        },
        battingVsOpponent: {
          'Pakistan': const BattingStats(
              matches: 16, innings: 15, runs: 492, balls: 365,
              fifties: 5, hundreds: 0, fours: 48, sixes: 12,
              average: 49.2, strikeRate: 134.8, highest: 82),
          'Australia': const BattingStats(
              matches: 28, innings: 27, runs: 1024, balls: 760,
              fifties: 10, hundreds: 1, fours: 98, sixes: 30,
              average: 47.6, strikeRate: 134.7, highest: 122),
        },
        battingByLeague: {
          'IPL': const BattingStats(
              matches: 252, innings: 244, runs: 8004, balls: 6100,
              fifties: 55, hundreds: 8, fours: 720, sixes: 272,
              average: 38.7, strikeRate: 131.2, highest: 113),
        },
        battingByVenue: {
          'v-dubai': const BattingStats(
              matches: 12, innings: 12, runs: 512, balls: 380,
              fifties: 6, hundreds: 0, fours: 48, sixes: 14,
              average: 51.2, strikeRate: 134.7, highest: 82),
          'v-wankhede': const BattingStats(
              matches: 18, innings: 18, runs: 742, balls: 540,
              fifties: 7, hundreds: 1, fours: 70, sixes: 26,
              average: 49.5, strikeRate: 137.4, highest: 113),
        },
        recentForm: const [
          FormEntry(matchLabel: 'IND vs PAK', opponent: 'Pakistan',
              format: 'T20', runs: 82, balls: 53, result: 'W'),
          FormEntry(matchLabel: 'IND vs AUS', opponent: 'Australia',
              format: 'T20', runs: 61, balls: 42, result: 'W'),
          FormEntry(matchLabel: 'IND vs ENG', opponent: 'England',
              format: 'T20', runs: 24, balls: 19, result: 'L'),
          FormEntry(matchLabel: 'IND vs NZ', opponent: 'New Zealand',
              format: 'ODI', runs: 95, balls: 104, result: 'W'),
          FormEntry(matchLabel: 'IND vs SA', opponent: 'South Africa',
              format: 'ODI', runs: 44, balls: 51, result: 'L'),
        ],
        matchups: const [
          Matchup(bowlerId: 'p-shaheen', bowlerName: 'Shaheen Afridi',
              batterId: 'p-virat', batterName: 'Virat Kohli',
              matches: 9, balls: 84, runs: 98, dismissals: 2),
          Matchup(bowlerId: 'p-bumrah', bowlerName: 'Jasprit Bumrah',
              batterId: 'p-virat', batterName: 'Virat Kohli',
              matches: 12, balls: 110, runs: 142, dismissals: 3),
        ],
        dismissalHistory: const [
          'c Rizwan b Shaheen — 2 times in T20s vs Pakistan',
          'b Haris Rauf — 1 time',
          'c Babar b Shadab — 1 time',
          'Not dismissed by Naseem Shah in 5 T20 meetings',
        ],
        dataComplete: false,
        source: 'demo',
        lastUpdated: _now,
      );

  Player _rohit() => Player(
        id: 'p-rohit',
        name: 'Rohit Sharma',
        team: 'India',
        role: 'Batter',
        battingStyle: 'Right-hand bat',
        bowlingStyle: 'Right-arm offbreak',
        country: 'India',
        battingByFormat: {
          'Test': const BattingStats(
              matches: 67, innings: 116, runs: 4301, balls: 7800,
              fifties: 18, hundreds: 12, fours: 472, sixes: 88,
              average: 40.6, strikeRate: 55.1, highest: 212),
          'ODI': const BattingStats(
              matches: 265, innings: 257, runs: 10709, balls: 11600,
              fifties: 55, hundreds: 31, fours: 984, sixes: 323,
              average: 49.1, strikeRate: 92.3, highest: 264),
          'T20': const BattingStats(
              matches: 159, innings: 151, runs: 4231, balls: 3050,
              fifties: 32, hundreds: 5, fours: 383, sixes: 205,
              average: 32.1, strikeRate: 138.7, highest: 121),
          'T10': const BattingStats(),
        },
        bowlingByFormat: const {},
        battingVsOpponent: {
          'Pakistan': const BattingStats(
              matches: 14, innings: 14, runs: 412, balls: 320,
              fifties: 4, hundreds: 0, fours: 40, sixes: 16,
              average: 34.3, strikeRate: 128.8, highest: 68),
        },
        battingByLeague: {
          'IPL': const BattingStats(
              matches: 257, innings: 252, runs: 6628, balls: 5000,
              fifties: 43, hundreds: 2, fours: 600, sixes: 280,
              average: 29.7, strikeRate: 132.6, highest: 109),
        },
        battingByVenue: {
          'v-dubai': const BattingStats(
              matches: 10, innings: 10, runs: 348, balls: 260,
              fifties: 3, hundreds: 0, fours: 34, sixes: 18,
              average: 38.7, strikeRate: 133.8, highest: 68),
        },
        recentForm: const [
          FormEntry(matchLabel: 'IND vs PAK', opponent: 'Pakistan',
              format: 'T20', runs: 48, balls: 30, result: 'W'),
          FormEntry(matchLabel: 'IND vs AUS', opponent: 'Australia',
              format: 'T20', runs: 12, balls: 9, result: 'L'),
          FormEntry(matchLabel: 'IND vs ENG', opponent: 'England',
              format: 'T20', runs: 72, balls: 41, result: 'W'),
        ],
        matchups: const [
          Matchup(bowlerId: 'p-shaheen', bowlerName: 'Shaheen Afridi',
              batterId: 'p-rohit', batterName: 'Rohit Sharma',
              matches: 8, balls: 66, runs: 71, dismissals: 3),
        ],
        dismissalHistory: const [
          'c Babar b Shaheen — 3 times in T20s vs Pakistan',
          'b Haris Rauf — 1 time',
        ],
        dataComplete: false,
        source: 'demo',
        lastUpdated: _now,
      );

  Player _babar() => Player(
        id: 'p-babar',
        name: 'Babar Azam',
        team: 'Pakistan',
        role: 'Batter',
        battingStyle: 'Right-hand bat',
        bowlingStyle: 'Right-arm offbreak',
        country: 'Pakistan',
        battingByFormat: {
          'Test': const BattingStats(
              matches: 59, innings: 107, runs: 4237, balls: 8200,
              fifties: 26, hundreds: 9, fours: 490, sixes: 28,
              average: 44.6, strikeRate: 51.7, highest: 196),
          'ODI': const BattingStats(
              matches: 128, innings: 124, runs: 5927, balls: 6600,
              fifties: 34, hundreds: 19, fours: 555, sixes: 87,
              average: 56.4, strikeRate: 89.8, highest: 158),
          'T20': const BattingStats(
              matches: 128, innings: 121, runs: 4223, balls: 3300,
              fifties: 36, hundreds: 3, fours: 440, sixes: 118,
              average: 41.4, strikeRate: 128.0, highest: 122),
          'T10': const BattingStats(),
        },
        bowlingByFormat: const {},
        battingVsOpponent: {
          'India': const BattingStats(
              matches: 13, innings: 13, runs: 482, balls: 390,
              fifties: 5, hundreds: 0, fours: 48, sixes: 10,
              average: 44.0, strikeRate: 123.6, highest: 82),
        },
        battingByLeague: {
          'PSL': const BattingStats(
              matches: 88, innings: 86, runs: 3305, balls: 2500,
              fifties: 30, hundreds: 2, fours: 350, sixes: 110,
              average: 44.0, strikeRate: 132.2, highest: 122),
        },
        battingByVenue: {
          'v-dubai': const BattingStats(
              matches: 14, innings: 14, runs: 584, balls: 450,
              fifties: 6, hundreds: 0, fours: 58, sixes: 16,
              average: 48.7, strikeRate: 129.8, highest: 82),
        },
        recentForm: const [
          FormEntry(matchLabel: 'PAK vs IND', opponent: 'India',
              format: 'T20', runs: 68, balls: 52, result: 'L'),
          FormEntry(matchLabel: 'PAK vs AUS', opponent: 'Australia',
              format: 'T20', runs: 41, balls: 35, result: 'W'),
          FormEntry(matchLabel: 'PAK vs ENG', opponent: 'England',
              format: 'T20', runs: 19, balls: 16, result: 'L'),
        ],
        matchups: const [
          Matchup(bowlerId: 'p-bumrah', bowlerName: 'Jasprit Bumrah',
              batterId: 'p-babar', batterName: 'Babar Azam',
              matches: 10, balls: 92, runs: 104, dismissals: 2),
        ],
        dismissalHistory: const [
          'b Bumrah — 2 times in T20s vs India',
          'c Suryakumar b Hardik — 1 time',
        ],
        dataComplete: false,
        source: 'demo',
        lastUpdated: _now,
      );

  Player _shaheen() => Player(
        id: 'p-shaheen',
        name: 'Shaheen Afridi',
        team: 'Pakistan',
        role: 'Bowler',
        battingStyle: 'Left-hand bat',
        bowlingStyle: 'Left-arm fast',
        country: 'Pakistan',
        battingByFormat: const {
          'T20': BattingStats(matches: 72, innings: 30, runs: 198,
              balls: 160, fifties: 0, hundreds: 0, fours: 12, sixes: 8,
              average: 11.6, strikeRate: 123.8, highest: 29),
        },
        bowlingByFormat: const {
          'Test': BowlingStats(matches: 31, wickets: 116, balls: 5400,
              runsConceded: 3900, economy: 4.33, average: 33.6,
              strikeRate: 46.5, best: '6/51'),
          'ODI': BowlingStats(matches: 59, wickets: 112, balls: 3100,
              runsConceded: 2750, economy: 5.32, average: 24.6,
              strikeRate: 27.7, best: '6/35'),
          'T20': BowlingStats(matches: 84, wickets: 102, balls: 1900,
              runsConceded: 2450, economy: 7.74, average: 24.0,
              strikeRate: 18.6, best: '4/22'),
        },
        battingVsOpponent: const {
          'India': BattingStats(matches: 9, innings: 5, runs: 32,
              balls: 28, average: 10.7, strikeRate: 114.3, highest: 16),
        },
        bowlingVsOpponent: const {
          'India': BowlingStats(matches: 9, wickets: 11, balls: 200,
              runsConceded: 260, economy: 7.8, average: 23.6,
              strikeRate: 18.2, best: '3/31'),
        },
        battingByLeague: const {
          'PSL': BattingStats(matches: 62, innings: 22, runs: 150,
              balls: 120, average: 12.5, strikeRate: 125.0, highest: 29),
        },
        battingByVenue: const {
          'v-dubai': BattingStats(matches: 11, innings: 4, runs: 28,
              balls: 24, average: 14.0, strikeRate: 116.7, highest: 16),
        },
        recentForm: const [
          FormEntry(matchLabel: 'PAK vs IND', opponent: 'India',
              format: 'T20', runs: 8, balls: 6, wickets: 2, result: 'L'),
          FormEntry(matchLabel: 'PAK vs AUS', opponent: 'Australia',
              format: 'T20', runs: 4, balls: 3, wickets: 3, result: 'W'),
        ],
        matchups: const [],
        dismissalHistory: const [
          'Dismissed Rohit Sharma 3 times in T20s vs India',
          'Dismissed Virat Kohli 2 times in T20s vs India',
        ],
        dataComplete: false,
        source: 'demo',
        lastUpdated: _now,
      );

  Player _bumrah() => Player(
        id: 'p-bumrah',
        name: 'Jasprit Bumrah',
        team: 'India',
        role: 'Bowler',
        battingStyle: 'Right-hand bat',
        bowlingStyle: 'Right-arm fast',
        country: 'India',
        battingByFormat: const {},
        bowlingByFormat: const {
          'Test': BowlingStats(matches: 45, wickets: 194, balls: 9500,
              runsConceded: 6200, economy: 3.91, average: 32.0,
              strikeRate: 49.0, best: '6/27'),
          'ODI': BowlingStats(matches: 89, wickets: 149, balls: 4700,
              runsConceded: 3900, economy: 4.98, average: 26.2,
              strikeRate: 31.5, best: '6/19'),
          'T20': BowlingStats(matches: 70, wickets: 89, balls: 1600,
              runsConceded: 1950, economy: 7.31, average: 21.9,
              strikeRate: 18.0, best: '3/14'),
        },
        battingVsOpponent: const {},
        bowlingVsOpponent: const {
          'Pakistan': BowlingStats(matches: 10, wickets: 14, balls: 230,
              runsConceded: 280, economy: 7.3, average: 20.0,
              strikeRate: 16.4, best: '3/14'),
        },
        battingByLeague: const {
          'IPL': BattingStats(matches: 133, innings: 20, runs: 68,
              balls: 90, average: 8.5, strikeRate: 75.6, highest: 16),
        },
        battingByVenue: const {},
        recentForm: const [
          FormEntry(matchLabel: 'IND vs PAK', opponent: 'Pakistan',
              format: 'T20', wickets: 3, result: 'W'),
          FormEntry(matchLabel: 'IND vs AUS', opponent: 'Australia',
              format: 'T20', wickets: 2, result: 'W'),
        ],
        matchups: const [],
        dismissalHistory: const [
          'Dismissed Babar Azam 2 times in T20s vs Pakistan',
          'Dismissed Mohammad Rizwan 3 times in T20s vs Pakistan',
        ],
        dataComplete: false,
        source: 'demo',
        lastUpdated: _now,
      );

  Player _surya() => Player(
        id: 'p-surya',
        name: 'Suryakumar Yadav',
        team: 'India',
        role: 'Batter',
        battingStyle: 'Right-hand bat',
        bowlingStyle: 'Right-arm medium',
        country: 'India',
        battingByFormat: {
          'Test': const BattingStats(matches: 1, innings: 1, runs: 8,
              balls: 14, average: 8.0, strikeRate: 57.1, highest: 8),
          'ODI': const BattingStats(
              matches: 37, innings: 35, runs: 773, balls: 740,
              fifties: 4, hundreds: 0, fours: 66, sixes: 36,
              average: 25.8, strikeRate: 104.5, highest: 72),
          'T20': const BattingStats(
              matches: 83, innings: 79, runs: 2595, balls: 1480,
              fifties: 21, hundreds: 4, fours: 228, sixes: 136,
              average: 41.9, strikeRate: 175.3, highest: 117),
          'T10': const BattingStats(),
        },
        bowlingByFormat: const {},
        battingVsOpponent: {
          'Pakistan': const BattingStats(
              matches: 7, innings: 7, runs: 268, balls: 150,
              fifties: 3, hundreds: 0, fours: 24, sixes: 16,
              average: 44.7, strikeRate: 178.7, highest: 68),
        },
        battingByLeague: {
          'IPL': const BattingStats(
              matches: 150, innings: 140, runs: 3597, balls: 2100,
              fifties: 25, hundreds: 2, fours: 320, sixes: 128,
              average: 32.7, strikeRate: 171.3, highest: 103),
        },
        battingByVenue: {
          'v-dubai': const BattingStats(
              matches: 8, innings: 8, runs: 312, balls: 170,
              fifties: 4, hundreds: 0, fours: 28, sixes: 18,
              average: 44.6, strikeRate: 183.5, highest: 68),
        },
        recentForm: const [
          FormEntry(matchLabel: 'IND vs PAK', opponent: 'Pakistan',
              format: 'T20', runs: 68, balls: 36, result: 'W'),
          FormEntry(matchLabel: 'IND vs AUS', opponent: 'Australia',
              format: 'T20', runs: 35, balls: 22, result: 'W'),
          FormEntry(matchLabel: 'IND vs ENG', opponent: 'England',
              format: 'T20', runs: 12, balls: 9, result: 'L'),
        ],
        matchups: const [
          Matchup(bowlerId: 'p-shaheen', bowlerName: 'Shaheen Afridi',
              batterId: 'p-surya', batterName: 'Suryakumar Yadav',
              matches: 6, balls: 48, runs: 72, dismissals: 1),
        ],
        dismissalHistory: const [
          'c Babar b Haris Rauf — 1 time',
          'Not dismissed by Shaheen in last 3 T20 meetings',
        ],
        dataComplete: false,
        source: 'demo',
        lastUpdated: _now,
      );

  // ---- Matches ---------------------------------------------------------

  List<CricketMatch> matches() => [_indVsPakLive(), _iplCompleted(), _bblUpcoming()];

  // V2 FULL scorecard: India 192/6 (20 ov) — batting 187 + extras 5.
  // Bowling runs sum 192, overs 20.0, wickets 6 (5 bowler + 1 run out).
  // Pakistan 96/3 (10 ov) chasing — batting 94 + extras 2.
  // All totals reconcile (validator tolerance 15, actual diff 5 / 2).
  CricketMatch _indVsPakLive() => CricketMatch(
        id: 'm-ind-pak-1',
        teamA: 'India',
        teamB: 'Pakistan',
        format: 'T20',
        league: 'International',
        venueId: 'v-dubai',
        venueName: 'Dubai International Stadium',
        startTime: _now.subtract(const Duration(hours: 1)),
        status: MatchStatus.live,
        scores: const [
          TeamScore(team: 'India', runs: 192, wickets: 6, overs: 20.0,
              batted: true),
          TeamScore(team: 'Pakistan', runs: 96, wickets: 3, overs: 10.0,
              batted: true),
        ],
        toss: 'India won the toss and chose to bat',
        umpires: 'Kumar Dharmasena (SL) • Chris Gaffaney (NZ)',
        matchReferee: 'Javagal Srinath (IND)',
        pitchReport:
            'Batting-friendly, short square boundaries. Dew expected in 2nd innings. Avg 1st innings 168, bat-first win 54%.',
        squadA: const ['p-virat', 'p-rohit', 'p-surya', 'p-bumrah'],
        squadB: const ['p-babar', 'p-shaheen'],
        innings: [
          const Innings(
            team: 'India',
            inningsNumber: 1,
            total: 192,
            wickets: 6,
            overs: 20.0,
            batting: [
              BattingEntry(playerId: 'p-rohit',
                  playerName: 'Rohit Sharma', runs: 48, balls: 30,
                  fours: 5, sixes: 2, dismissal: 'c Babar Azam b Shaheen Afridi'),
              BattingEntry(playerId: 'p-gill',
                  playerName: 'Shubman Gill', runs: 31, balls: 24,
                  fours: 4, sixes: 1, dismissal: 'c Mohammad Rizwan b Haris Rauf'),
              BattingEntry(playerId: 'p-virat',
                  playerName: 'Virat Kohli', runs: 68, balls: 45,
                  fours: 7, sixes: 2, dismissal: 'not out', notOut: true),
              BattingEntry(playerId: 'p-surya',
                  playerName: 'Suryakumar Yadav', runs: 22, balls: 15,
                  fours: 3, sixes: 1, dismissal: 'c Mohammad Rizwan b Shadab Khan'),
              BattingEntry(playerId: 'p-hardik',
                  playerName: 'Hardik Pandya', runs: 10, balls: 9,
                  fours: 1, sixes: 1, dismissal: 'b Naseem Shah'),
              BattingEntry(playerId: 'p-pant',
                  playerName: 'Rishabh Pant', runs: 5, balls: 4,
                  fours: 0, sixes: 0, dismissal: 'run out (Babar Azam)'),
              BattingEntry(playerId: 'p-dube',
                  playerName: 'Shivam Dube', runs: 0, balls: 1,
                  fours: 0, sixes: 0, dismissal: 'c Mohammad Rizwan b Imad Wasim'),
              BattingEntry(playerId: 'p-axar',
                  playerName: 'Axar Patel', runs: 3, balls: 3,
                  fours: 0, sixes: 0, dismissal: 'not out', notOut: true),
            ],
            bowling: [
              BowlingEntry(playerId: 'p-shaheen',
                  playerName: 'Shaheen Afridi', overs: 4, maidens: 0,
                  runsConceded: 38, wickets: 1, economy: 9.5,
                  wides: 1, noBalls: 0),
              BowlingEntry(playerId: 'p-naseem',
                  playerName: 'Naseem Shah', overs: 4, maidens: 0,
                  runsConceded: 35, wickets: 1, economy: 8.75,
                  wides: 1, noBalls: 0),
              BowlingEntry(playerId: 'p-haris',
                  playerName: 'Haris Rauf', overs: 4, maidens: 0,
                  runsConceded: 42, wickets: 1, economy: 10.5,
                  wides: 1, noBalls: 0),
              BowlingEntry(playerId: 'p-shadab',
                  playerName: 'Shadab Khan', overs: 4, maidens: 0,
                  runsConceded: 36, wickets: 1, economy: 9.0,
                  wides: 0, noBalls: 0),
              BowlingEntry(playerId: 'p-imad',
                  playerName: 'Imad Wasim', overs: 2, maidens: 0,
                  runsConceded: 22, wickets: 1, economy: 11.0,
                  wides: 0, noBalls: 0),
              BowlingEntry(playerId: 'p-iftikhar',
                  playerName: 'Iftikhar Ahmed', overs: 2, maidens: 0,
                  runsConceded: 19, wickets: 0, economy: 9.5,
                  wides: 0, noBalls: 1),
            ],
            fallOfWickets: [
              '1-52 (Rohit Sharma, 6.1 ov)',
              '2-79 (Shubman Gill, 9.4 ov)',
              '3-147 (Suryakumar Yadav, 15.2 ov)',
              '4-179 (Hardik Pandya, 17.5 ov)',
              '5-184 (Rishabh Pant, 18.3 ov)',
              '6-187 (Shivam Dube, 19.2 ov)',
            ],
            extrasRuns: 5,
            extrasText: 'Wd 3, Nb 1, B 1 (5)',
            yetToBat: [
              'Ravindra Jadeja',
              'Jasprit Bumrah',
              'Kuldeep Yadav',
              'Arshdeep Singh',
            ],
            partnerships: [
              'Rohit + Gill — 52 (37 balls)',
              'Gill + Kohli — 27 (20 balls)',
              'Kohli + Suryakumar — 68 (42 balls)',
              'Kohli + Hardik — 32 (21 balls)',
              'Kohli + Pant — 5 (4 balls)',
              'Kohli + Dube — 3 (5 balls)',
              'Kohli + Axar — 5* (4 balls)',
            ],
          ),
          const Innings(
            team: 'Pakistan',
            inningsNumber: 2,
            total: 96,
            wickets: 3,
            overs: 10.0,
            batting: [
              BattingEntry(playerId: 'p-babar',
                  playerName: 'Babar Azam', runs: 38, balls: 28,
                  fours: 4, sixes: 1, dismissal: 'c Suryakumar Yadav b Jasprit Bumrah'),
              BattingEntry(playerId: 'p-rizwan',
                  playerName: 'Mohammad Rizwan', runs: 32, balls: 22,
                  fours: 3, sixes: 1, dismissal: 'b Kuldeep Yadav'),
              BattingEntry(playerId: 'p-fakhar',
                  playerName: 'Fakhar Zaman', runs: 12, balls: 8,
                  fours: 1, sixes: 1, dismissal: 'c Rohit Sharma b Arshdeep Singh'),
              BattingEntry(playerId: 'p-iftikhar-bat',
                  playerName: 'Iftikhar Ahmed', runs: 8, balls: 4,
                  fours: 1, sixes: 0, dismissal: 'not out', notOut: true),
              BattingEntry(playerId: 'p-shadab-bat',
                  playerName: 'Shadab Khan', runs: 4, balls: 2,
                  fours: 1, sixes: 0, dismissal: 'not out', notOut: true),
            ],
            bowling: [
              BowlingEntry(playerId: 'p-bumrah',
                  playerName: 'Jasprit Bumrah', overs: 2, maidens: 0,
                  runsConceded: 18, wickets: 1, economy: 9.0,
                  wides: 0, noBalls: 0),
              BowlingEntry(playerId: 'p-arshdeep',
                  playerName: 'Arshdeep Singh', overs: 3, maidens: 0,
                  runsConceded: 28, wickets: 1, economy: 9.33,
                  wides: 1, noBalls: 0),
              BowlingEntry(playerId: 'p-hardik-bowl',
                  playerName: 'Hardik Pandya', overs: 2, maidens: 0,
                  runsConceded: 22, wickets: 0, economy: 11.0,
                  wides: 1, noBalls: 0),
              BowlingEntry(playerId: 'p-kuldeep',
                  playerName: 'Kuldeep Yadav', overs: 2, maidens: 0,
                  runsConceded: 18, wickets: 1, economy: 9.0,
                  wides: 0, noBalls: 0),
              BowlingEntry(playerId: 'p-axar-bowl',
                  playerName: 'Axar Patel', overs: 1, maidens: 0,
                  runsConceded: 10, wickets: 0, economy: 10.0,
                  wides: 0, noBalls: 0),
            ],
            fallOfWickets: [
              '1-58 (Babar Azam, 6.2 ov)',
              '2-82 (Mohammad Rizwan, 8.4 ov)',
              '3-90 (Fakhar Zaman, 9.3 ov)',
            ],
            extrasRuns: 2,
            extrasText: 'Wd 2 (2)',
            yetToBat: [
              'Imad Wasim',
              'Shaheen Afridi',
              'Naseem Shah',
              'Haris Rauf',
              'Shadab Khan (bowling)',
              'Usman Khan',
              'Abrar Ahmed',
            ],
            partnerships: [
              'Babar + Rizwan — 58 (38 balls)',
              'Rizwan + Fakhar — 24 (14 balls)',
              'Fakhar + Iftikhar — 8 (5 balls)',
              'Iftikhar + Shadab — 6* (3 balls)',
            ],
          ),
        ],
        commentary: const [
          '10.0 ov: Pakistan 96/3. Need 97 from 60 balls. Iftikhar 8*, Shadab 4*. India on top.',
          '9.3 ov: WICKET! Fakhar caught at deep midwicket by Rohit off Arshdeep. 90/3.',
          '8.4 ov: WICKET! Rizwan bowled by Kuldeep for 32. 82/2.',
          '6.2 ov: WICKET! Babar caught by Surya off Bumrah for 38. 58/1.',
          'Innings break: India 192/6. Kohli 68* anchored. Pakistan need 193.',
          '19.2 ov: Dube falls first ball. India 187/6.',
          '15.2 ov: Suryakumar falls for 22. Kohli + Surya added 68.',
          '6.1 ov: Rohit falls for 48, caught by Babar off Shaheen. 52/1.',
        ],
        currentBatter: 'Iftikhar Ahmed (8*) • Shadab Khan (4*)',
        currentBowler: 'Axar Patel',
        lastBall: '1',
        teamAWinsH2H: 12,
        teamBWinsH2H: 3,
        totalH2H: 18,
        lastUpdated: _now,
        source: 'demo',
      );

  CricketMatch _iplCompleted() => CricketMatch(
        id: 'm-ipl-1',
        teamA: 'Mumbai Indians',
        teamB: 'Chennai Super Kings',
        format: 'T20',
        league: 'IPL',
        venueId: 'v-wankhede',
        venueName: 'Wankhede Stadium',
        startTime: _now.subtract(const Duration(days: 1)),
        status: MatchStatus.completed,
        scores: const [
          TeamScore(team: 'Mumbai Indians', runs: 198, wickets: 5,
              overs: 20.0, batted: true),
          TeamScore(team: 'Chennai Super Kings', runs: 192, wickets: 6,
              overs: 20.0, batted: true),
        ],
        result: 'Mumbai Indians won by 6 runs',
        toss: 'Chennai won the toss and chose to field',
        squadA: const ['p-rohit', 'p-surya'],
        squadB: const [],
        teamAWinsH2H: 21,
        teamBWinsH2H: 17,
        totalH2H: 38,
        lastUpdated: _now,
        source: 'demo',
      );

  CricketMatch _bblUpcoming() => CricketMatch(
        id: 'm-bbl-1',
        teamA: 'Sydney Sixers',
        teamB: 'Perth Scorchers',
        format: 'T20',
        league: 'Big Bash',
        venueId: 'v-mcg',
        venueName: 'Melbourne Cricket Ground',
        startTime: _now.add(const Duration(days: 2)),
        status: MatchStatus.upcoming,
        toss: '',
        squadA: const [],
        squadB: const [],
        teamAWinsH2H: 9,
        teamBWinsH2H: 11,
        totalH2H: 20,
        lastUpdated: _now,
        source: 'demo',
      );
}
