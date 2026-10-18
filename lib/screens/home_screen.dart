import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/match.dart';
import '../services/api_service.dart';
import '../utils/app_theme.dart';
import '../utils/strings.dart';
import '../widgets/language_toggle.dart';
import '../widgets/player_card.dart';
import '../widgets/premium_widgets.dart';
import 'match_detail_screen.dart';
import 'player_profile_screen.dart';

/// V2 Home — PREMIUM King look: gradient hero, live pulse, bold scores,
/// gold borders, animated match cards. Same navigation, richer visuals.
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
          // Premium header — gold crown + gradient title.
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.heroCard(),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: AppTheme.goldGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.gold.withValues(alpha: 0.5),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Text('👑',
                      style: TextStyle(fontSize: 30)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(lang.t('app_name'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5)),
                      Text(lang.t('tagline'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppTheme.goldSoft, fontSize: 12)),
                    ],
                  ),
                ),
                const LanguageToggle(),
              ],
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: lang.t('search_hint'),
              prefixIcon: const Icon(Icons.search, color: AppTheme.goldLight),
              filled: true,
              fillColor: AppTheme.navyCard,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                      color: AppTheme.gold.withValues(alpha: 0.35))),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                      color: AppTheme.gold.withValues(alpha: 0.25))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppTheme.gold)),
            ),
          ),
          const SizedBox(height: 10),
          if (!_api.isLive)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                  color: AppTheme.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppTheme.amber.withValues(alpha: 0.4))),
              child: Text(lang.t('mock_mode'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12)),
            ),
          const SizedBox(height: 12),
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
          const PremiumSectionHeader(
              title: 'Matches', icon: Icons.sports_cricket),
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
          for (final m in _visible)
            _MatchCard(
                match: m,
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              MatchDetailScreen(match: m)));
                }),
          const AdPlaceholder(),
          const PremiumSectionHeader(
              title: 'Trending Players', icon: Icons.trending_up),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration:
          live ? AppTheme.heroCard() : AppTheme.premiumCard(),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (live) const LivePill(),
                  if (!live)
                    GoldChip(
                        label: match.isCompleted ? 'RESULT' : 'UPCOMING'),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('${match.league} • ${match.format}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12)),
                  ),
                  if (match.lastBall.isNotEmpty)
                    Text('Last: ${match.lastBall}',
                        style: const TextStyle(
                            color: AppTheme.goldLight,
                            fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 10),
              Text(match.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w900)),
              if (match.venueName.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text('📍 ${match.venueName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
              ],
              const SizedBox(height: 10),
              for (final s in match.scores)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(s.team,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15)),
                      ),
                      const SizedBox(width: 8),
                      Text(s.display,
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                              color: AppTheme.goldLight)),
                    ],
                  ),
                ),
              if (match.result.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(match.result,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppTheme.goldSoft,
                          fontWeight: FontWeight.w700)),
                ),
              if (match.currentBatter.isNotEmpty) ...[
                const Divider(color: Colors.white12, height: 20),
                Text('Batting: ${match.currentBatter}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 2),
                Text('Bowling: ${match.currentBowler}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary)),
              ],
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.arrow_forward,
                      size: 14, color: AppTheme.goldLight),
                  const SizedBox(width: 4),
                  const Text('Tap for FULL scorecard',
                      style: TextStyle(
                          color: AppTheme.goldLight,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text('Scorecard →',
                      style: TextStyle(
                          color: AppTheme.gold.withValues(alpha: 0.9),
                          fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
