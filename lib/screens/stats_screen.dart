import 'package:flutter/material.dart';
import '../models/player.dart';
import '../services/api_service.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';
import 'player_profile_screen.dart';

/// Stats / rankings — derived from the loaded player list, never
/// hard-coded. Format filter + minimum qualifiers on every
/// average / strike-rate / economy board (reference rule S1/S3):
/// a 1-match average of 200 must never top the board.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});
  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  String _format = 'All';
  // Discipline filter (reference §4.5): Batting / Bowling / All-round
  // chips filter which boards show. 'All' shows every board.
  String _discipline = 'All';
  late Future<List<Player>> _playersFuture;

  @override
  void initState() {
    super.initState();
    _playersFuture = ApiService().fetchPlayers();
  }

  void _reload() {
    setState(() {
      _playersFuture = ApiService().fetchPlayers();
    });
  }

  // Per-format stats for a player, or career overall when _format
  // is All. Bowling aggregates are weighted across formats.
  ({int runs, double avg, double sr, int hundreds, int fifties, int sixes,
      int innings, int wkts, double econ, double bowlAvg, int balls})
      _stats(Player p) {
    if (_format == 'All') {
      final bat = p.battingOverall();
      final bowl = p.bowlingOverall();
      var balls = 0, runsConc = 0;
      for (final s in p.bowlingByFormat.values) {
        balls += s.balls;
        runsConc += s.runsConceded;
      }
      return (
        runs: bat.runs,
        avg: bat.average,
        sr: bat.strikeRate,
        hundreds: bat.hundreds,
        fifties: bat.fifties,
        sixes: bat.sixes,
        innings: bat.innings,
        wkts: bowl.wickets,
        econ: balls == 0 ? double.infinity : runsConc / (balls / 6),
        bowlAvg:
            bowl.wickets == 0 ? double.infinity : runsConc / bowl.wickets,
        balls: balls,
      );
    }
    final bat = p.battingInFormat(_format);
    final bowl = p.bowlingByFormat[_format];
    return (
      runs: bat.runs,
      avg: bat.average,
      sr: bat.strikeRate,
      hundreds: bat.hundreds,
      fifties: bat.fifties,
      sixes: bat.sixes,
      innings: bat.innings,
      wkts: bowl?.wickets ?? 0,
      econ: bowl == null || bowl.balls == 0
          ? double.infinity
          : bowl.runsConceded / (bowl.balls / 6),
      bowlAvg: bowl == null || bowl.wickets == 0
          ? double.infinity
          : bowl.runsConceded / bowl.wickets,
      balls: bowl?.balls ?? 0,
    );
  }

  /// Fours in the current format filter (or career overall).
  int _fours(Player p) {
    if (_format == 'All') {
      return p.battingByFormat.values.fold(0, (s, b) => s + b.fours);
    }
    return p.battingInFormat(_format).fours;
  }

  /// Honest provenance for the whole screen (reference P7). Players
  /// carry their own `source` ('cricsheet' / 'demo' / provider name /
  /// ''); the screen reports the majority so a demo leaderboard is
  /// never mistaken for verified data.
  String _sourceLine(List<Player> players) {
    var real = 0, demo = 0;
    for (final p in players) {
      if (p.source == 'cricsheet') {
        real++;
      } else if (p.source == 'demo' || p.source.isEmpty) {
        demo++;
      } else {
        real++;
      }
    }
    if (demo == 0 && real > 0) {
      return 'Source: Real data — tap a player for full profile & source.';
    }
    if (real == 0) {
      return 'Source: Demo data — curated sample, not live-verified. '
          'Tap a player for the full profile.';
    }
    return 'Source: Mixed — $real real, $demo demo. Tap a player to see '
        'its own source label.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stats & Rankings')),
      body: FutureBuilder(
        future: _playersFuture,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                        'Could not load stats. Check your connection and try again.',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                        onPressed: _reload,
                        child: const Text('Retry')),
                  ],
                ),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final players = snap.data!;
          if (players.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                    'No player data yet. With a free API key, leaders appear here automatically.',
                    textAlign: TextAlign.center),
              ),
            );
          }
          // Qualifier gates: rate boards only rank players with a
          // real sample behind the rate (min 10 innings / 60 balls).
          final withInnings =
              players.where((p) => _stats(p).innings >= 10).toList();
          final withBowling =
              players.where((p) => _stats(p).balls >= 60).toList();
          final byRuns = [...players]
            ..sort((a, b) => _stats(b).runs.compareTo(_stats(a).runs));
          final byAvg = [...withInnings]
            ..sort((a, b) => _stats(b).avg.compareTo(_stats(a).avg));
          final bySr = [...withInnings]
            ..sort((a, b) => _stats(b).sr.compareTo(_stats(a).sr));
          final byWkts = [...players]
            ..sort((a, b) => _stats(b).wkts.compareTo(_stats(a).wkts));
          final byEcon = [...withBowling]
            ..sort((a, b) => _stats(a).econ.compareTo(_stats(b).econ));
          // Zero-value rows never belong on a leaderboard: a player
          // with 0 wickets must not appear on "Most Wickets".
          final byHundreds = [...players]
            ..sort((a, b) => _stats(b).hundreds.compareTo(_stats(a).hundreds));
          final byFifties = [...players]
            ..sort((a, b) => _stats(b).fifties.compareTo(_stats(a).fifties));
          final bySixes = [...players]
            ..sort((a, b) => _stats(b).sixes.compareTo(_stats(a).sixes));
          final byFours = [...players]
            ..sort((a, b) =>
                _fours(b).compareTo(_fours(a)));
          final byBowlAvg = [...withBowling]
            ..sort((a, b) => _stats(a).bowlAvg.compareTo(_stats(b).bowlAvg));
          final showBatting =
              _discipline == 'All' || _discipline == 'Batting';
          final showBowling =
              _discipline == 'All' || _discipline == 'Bowling';
          return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              // Source line (reference P7): every stats block carries
              // its provenance — never a bare number, never "Complete"
              // on demo/curated data.
              Text(_sourceLine(players),
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12)),
              const SizedBox(height: 10),
              // Discipline filter: Batting / Bowling / All.
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['All', 'Batting', 'Bowling']
                      .map((d) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(d),
                              selected: _discipline == d,
                              onSelected: (_) =>
                                  setState(() => _discipline = d),
                            ),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 6),
              // Format filter chips (reference: Statsguru-style).
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['All', ...AppConstants.formats]
                      .map((f) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(f),
                              selected: _format == f,
                              onSelected: (_) =>
                                  setState(() => _format = f),
                            ),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 8),
              if (showBatting) ...[
                _section(context, 'Most Runs',
                    byRuns.where((p) => _stats(p).runs > 0).toList(),
                    (p) => '${_stats(p).runs} runs',
                    emptyHint: 'No runs in this filter yet.'),
                _section(context, 'Best Average (min 10 innings)', byAvg,
                    (p) => _stats(p).avg.toStringAsFixed(1),
                    emptyHint: 'No player has 10+ innings yet.'),
                _section(context, 'Best Strike Rate (min 10 innings)', bySr,
                    (p) => _stats(p).sr.toStringAsFixed(1),
                    emptyHint: 'No player has 10+ innings yet.'),
                _section(context, 'Most 100s',
                    byHundreds.where((p) => _stats(p).hundreds > 0).toList(),
                    (p) => '${_stats(p).hundreds}',
                    emptyHint: 'No centuries in this filter yet.'),
                _section(context, 'Most 50s',
                    byFifties.where((p) => _stats(p).fifties > 0).toList(),
                    (p) => '${_stats(p).fifties}',
                    emptyHint: 'No fifties in this filter yet.'),
                _section(context, 'Most Fours',
                    byFours.where((p) => _fours(p) > 0).toList(),
                    (p) => '${_fours(p)}',
                    emptyHint: 'No fours recorded in this filter yet.'),
                _section(context, 'Most Sixes',
                    bySixes.where((p) => _stats(p).sixes > 0).toList(),
                    (p) => '${_stats(p).sixes}',
                    emptyHint: 'No sixes in this filter yet.'),
              ],
              if (showBowling) ...[
                _section(context, 'Most Wickets',
                    byWkts.where((p) => _stats(p).wkts > 0).toList(),
                    (p) => '${_stats(p).wkts} wkts',
                    emptyHint: 'No wickets in this filter yet.'),
                _section(context, 'Best Bowling Average (min 10 overs)',
                    byBowlAvg,
                    (p) => _stats(p).bowlAvg.toStringAsFixed(2),
                    emptyHint: 'No bowler has 10+ overs yet.'),
                _section(context, 'Best Economy (min 10 overs)', byEcon,
                    (p) => _stats(p).econ.toStringAsFixed(2),
                    emptyHint: 'No bowler has 10+ overs yet.'),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _section(BuildContext context, String title, List<Player> players,
      String Function(Player) value,
      {String emptyHint = ''}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(title,
            style:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        if (players.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(emptyHint,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13)),
          ),
        for (var i = 0; i < players.length; i++)
          Card(
            child: ListTile(
              leading: CircleAvatar(child: Text('${i + 1}')),
              title: Text(players[i].name,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(players[i].team,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: Text(value(players[i]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          PlayerProfileScreen(player: players[i]))),
            ),
          ),
      ],
    );
  }
}
