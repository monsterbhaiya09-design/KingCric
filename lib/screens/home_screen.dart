import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/match.dart';
import '../services/api_service.dart';
import '../utils/strings.dart';
import '../widgets/language_toggle.dart';
import '../widgets/player_card.dart';
import 'match_detail_screen.dart';
import 'player_profile_screen.dart';

/// Home: Live / Upcoming / Recent + trending players + search.
/// Context-wise, never a raw dump: each match card shows the live
/// score, venue and format at a glance.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ApiService _api;
  List<CricketMatch> _matches = [];
  bool _loading = true;
  String _filter = 'live';
  String _query = '';

  @override
  void initState() {
    super.initState();
    _api = ApiService();
    _load();
  }

  Future<void> _load() async {
    try {
      final m = await _api.fetchMatches();
      if (!mounted) return;
      setState(() {
        _matches = m;
        _loading = false;
      });
    } catch (_) {
      // Never crash on a failed load; keep previous data / empty state.
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<CricketMatch> get _visible {
    var list = _matches.where((m) {
      if (_filter == 'live') return m.status == MatchStatus.live;
      if (_filter == 'upcoming') return m.status == MatchStatus.upcoming;
      return m.status == MatchStatus.completed;
    }).toList();
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list
          .where((m) =>
              m.teamA.toLowerCase().contains(q) ||
              m.teamB.toLowerCase().contains(q) ||
              m.league.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Row(
            children: [
              const Text('👑🏏',
                  style: TextStyle(fontSize: 28)), // Crown + Bat-Ball logo
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lang.t('app_name'),
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w900)),
                    Text(lang.t('tagline'),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              const LanguageToggle(),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: lang.t('search_hint'),
              prefixIcon: const Icon(Icons.search),
              filled: true,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 10),
          if (!_api.isLive)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10)),
              child: Text(lang.t('mock_mode'),
                  style: const TextStyle(fontSize: 12)),
            ),
          const SizedBox(height: 10),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'live', label: Text(lang.t('live'))),
              ButtonSegment(
                  value: 'upcoming', label: Text(lang.t('upcoming'))),
              ButtonSegment(value: 'recent', label: Text(lang.t('recent'))),
            ],
            selected: {_filter},
            onSelectionChanged: (s) =>
                setState(() => _filter = s.first),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(child: CircularProgressIndicator()),
          if (!_loading && _visible.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                  lang.isHindi
                      ? 'इस सेक्शन में कोई मैच नहीं है।'
                      : 'No matches in this section.',
                  textAlign: TextAlign.center),
            ),
          for (final m in _visible) _MatchCard(match: m, onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => MatchDetailScreen(match: m)));
          }),
          const AdPlaceholder(),
          const SizedBox(height: 8),
          Text(
              lang.isHindi ? 'ट्रेंडिंग खिलाड़ी' : 'Trending players',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          FutureBuilder(
            future: _api.fetchPlayers(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return Column(
                children: snap.data!
                    .take(4)
                    .map((p) => PlayerCard(
                          player: p,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      PlayerProfileScreen(player: p))),
                        ))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  final CricketMatch match;
  final VoidCallback onTap;
  const _MatchCard({required this.match, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final live = match.isLive;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (live)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(20)),
                      child: const Text('LIVE',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                  const SizedBox(width: 6),
                  Chip(label: Text('${match.league} • ${match.format}')),
                  const Spacer(),
                  if (match.lastBall.isNotEmpty)
                    Text('Last ball: ${match.lastBall}',
                        style: const TextStyle(color: Colors.white70)),
                ],
              ),
              const SizedBox(height: 8),
              Text(match.title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800)),
              if (match.venueName.isNotEmpty)
                Text('📍 ${match.venueName}',
                    style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              for (final s in match.scores)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(s.team,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(s.display),
                    ],
                  ),
                ),
              if (match.result.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(match.result,
                      style: const TextStyle(color: Colors.amber)),
                ),
              if (match.currentBatter.isNotEmpty)
                Text(
                    'Batting: ${match.currentBatter} • Bowling: ${match.currentBowler}'),
            ],
          ),
        ),
      ),
    );
  }
}
