import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'player_profile_screen.dart';

/// Stats / rankings: top runs, wickets, averages, strike rates.
/// Derived from the player list — no hard-coded leaderboard.
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stats & Rankings')),
      body: FutureBuilder(
        future: ApiService().fetchPlayers(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final players = snap.data!;
          final byRuns = [...players]
            ..sort((a, b) => b
                .battingOverall()
                .runs
                .compareTo(a.battingOverall().runs));
          final byAvg = [...players]
            ..sort((a, b) => b
                .battingOverall()
                .average
                .compareTo(a.battingOverall().average));
          final bySr = [...players]
            ..sort((a, b) => b
                .battingOverall()
                .strikeRate
                .compareTo(a.battingOverall().strikeRate));
          return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              _section(context, 'Most Runs', byRuns,
                  (p) => '${p.battingOverall().runs} runs'),
              _section(context, 'Best Average', byAvg,
                  (p) => p.battingOverall().average.toStringAsFixed(1)),
              _section(context, 'Best Strike Rate', bySr,
                  (p) => p.battingOverall().strikeRate.toStringAsFixed(1)),
            ],
          );
        },
      ),
    );
  }

  Widget _section(BuildContext context, String title, List players,
      String Function(dynamic) value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(title,
            style:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        for (var i = 0; i < players.length; i++)
          Card(
            child: ListTile(
              leading: CircleAvatar(child: Text('${i + 1}')),
              title: Text(players[i].name),
              subtitle: Text(players[i].team),
              trailing: Text(value(players[i]),
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
