import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import 'match_detail_screen.dart';

/// Leagues: one section per league — IPL, PSL, Big Bash, T10,
/// Domestic (Ranji / SMAT / Vijay Hazare), Women's, U19.
/// Each league shows only its own matches.
class LeaguesScreen extends StatefulWidget {
  const LeaguesScreen({super.key});
  @override
  State<LeaguesScreen> createState() => _LeaguesScreenState();
}

class _LeaguesScreenState extends State<LeaguesScreen> {
  String _league = 'IPL';
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leagues')),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(10),
            child: Row(
              children: AppConstants.leagues
                  .map((l) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(l),
                          selected: _league == l,
                          onSelected: (_) =>
                              setState(() => _league = l),
                        ),
                      ))
                  .toList(),
            ),
          ),
          Expanded(
            child: FutureBuilder(
              future: ApiService().fetchMatches(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(
                      child: CircularProgressIndicator());
                }
                final list =
                    snap.data!.where((m) => m.league == _league).toList();
                if (list.isEmpty) {
                  return Center(
                      child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                        'No $_league matches in demo data yet.\nWith a free API key, this section fills automatically.',
                        textAlign: TextAlign.center),
                  ));
                }
                return ListView(
                  padding: const EdgeInsets.all(14),
                  children: [
                    for (final m in list)
                      Card(
                        child: ListTile(
                          title: Text(m.title),
                          subtitle: Text(
                              '${m.format} • ${m.venueName}'),
                          trailing: Text(m.result.isEmpty
                              ? m.status.name
                              : m.result),
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      MatchDetailScreen(match: m))),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
