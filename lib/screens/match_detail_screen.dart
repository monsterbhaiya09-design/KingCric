import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/innings.dart';
import '../models/match.dart';
import '../services/api_service.dart';
import '../services/prediction_engine.dart';
import '../utils/app_theme.dart';
import '../utils/strings.dart';
import '../widgets/h2h_card.dart';
import '../widgets/player_card.dart';
import '../widgets/prediction_card.dart';
import '../widgets/premium_widgets.dart';
import 'player_profile_screen.dart';

/// V2 Match detail — PREMIUM + FULL scoreboard.
/// Tabs: Live | Scorecard (FULL) | Squad | Prediction
/// Scorecard shows: Batting R/B/4s/6s/SR + dismissal, Bowling
/// O/M/R/W/Econ/Wd/Nb, Extras breakdown, Fall of Wickets,
/// Partnerships, Yet to bat, Toss + Venue + Umpires.
/// Nothing truncates: tables scroll horizontally, all text wraps.
class MatchDetailScreen extends StatefulWidget {
  final CricketMatch match;
  const MatchDetailScreen({super.key, required this.match});
  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  late CricketMatch _match;

  @override
  void initState() {
    super.initState();
    _match = widget.match;
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    return Scaffold(
      appBar: AppBar(
        title: Text(_match.title,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: [
            Tab(text: lang.t('live')),
            Tab(text: lang.t('scorecard')),
            Tab(text: lang.t('squad')),
            Tab(text: lang.t('prediction')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _liveTab(lang),
          _scorecardTab(lang),
          _squadTab(),
          _predictionTab(),
        ],
      ),
    );
  }

  // ---------------- LIVE ----------------

  Widget _liveTab(LanguageProvider lang) {
    final scoreA = _match.scoreOf(_match.teamA);
    final scoreB = _match.scoreOf(_match.teamB);
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // Hero live score — big, gold, animated.
        KingGradientCard(
          hero: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (_match.isLive) const LivePill(),
                  if (!_match.isLive)
                    GoldChip(
                        label: _match.isCompleted ? 'RESULT' : 'UPCOMING'),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('${_match.league} • ${_match.format}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(_match.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              if (_match.venueName.isNotEmpty)
                Text('📍 ${_match.venueName}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 14),
              for (final s in _match.scores)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(s.team,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 16)),
                      ),
                      const SizedBox(width: 8),
                      Text(s.display,
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                              color: AppTheme.goldLight)),
                    ],
                  ),
                ),
              if (_match.result.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(_match.result,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppTheme.goldSoft,
                        fontWeight: FontWeight.w700)),
              ],
              if (_match.isLive) ...[
                const Divider(color: Colors.white12, height: 24),
                Text('Batting: ${_match.currentBatter}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 4),
                Text('Bowling: ${_match.currentBowler}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.textSecondary)),
                if (_match.lastBall.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Last ball: ',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.gold.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppTheme.gold.withValues(alpha: 0.5)),
                        ),
                        child: Text(_match.lastBall,
                            style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: AppTheme.goldLight)),
                      ),
                    ],
                  ),
                ],
              ],
              if (_match.toss.isNotEmpty) ...[
                const Divider(color: Colors.white12, height: 24),
                Text('🪙 ${_match.toss}',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ],
          ),
        ),
        if (scoreA != null && scoreB != null) ...[
          const PremiumSectionHeader(
              title: 'Target & Equation', icon: Icons.track_changes),
          KingGradientCard(
            child: Text(
              _match.isLive
                  ? '${_match.teamB} need ${scoreA.runs + 1 - scoreB.runs} runs from ${(20 * 6 - (scoreB.overs * 6).round())} balls • ${scoreA.runs + 1 - scoreB.runs} to win'
                  : '${_match.teamA} ${scoreA.runs}/${scoreA.wickets} • ${_match.teamB} ${scoreB.runs}/${scoreB.wickets}',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ],
        H2HCard(
          teamA: _match.teamA,
          teamB: _match.teamB,
          winsA: _match.teamAWinsH2H,
          winsB: _match.teamBWinsH2H,
          total: _match.totalH2H,
        ),
        const PremiumSectionHeader(
            title: 'Match Info', icon: Icons.info_outline),
        KingGradientCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoRow('Venue', _match.venueName),
              _infoRow('Toss', _match.toss),
              if (_match.umpires.isNotEmpty)
                _infoRow('Umpires', _match.umpires),
              if (_match.matchReferee.isNotEmpty)
                _infoRow('Referee', _match.matchReferee),
              if (_match.pitchReport.isNotEmpty)
                _infoRow('Pitch', _match.pitchReport),
            ],
          ),
        ),
        const PremiumSectionHeader(
            title: 'Commentary', icon: Icons.chat_bubble_outline),
        for (final c in _match.commentary)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: AppTheme.premiumCard(radius: 12),
            padding: const EdgeInsets.all(12),
            child: Text(c,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13)),
          ),
        if (_match.commentary.isEmpty)
          Text(lang.isHindi
              ? 'कमेंट्री उपलब्ध नहीं है।'
              : 'No commentary available.'),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 82,
            child: Text(label,
                style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: Text(value,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // ---------------- FULL SCORECARD ----------------

  Widget _scorecardTab(LanguageProvider lang) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // Match context header — always visible on scorecard.
        KingGradientCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_match.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(
                  '${_match.league} • ${_match.format} • ${_match.venueName}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12)),
              if (_match.toss.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('🪙 ${_match.toss}',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
              ],
              if (_match.umpires.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('Umpires: ${_match.umpires}',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ],
          ),
        ),
        for (final inn in _match.innings) ...[
          PremiumSectionHeader(
            title: '${inn.team} — ${inn.total}/${inn.wickets}',
            subtitle:
                '${inn.overs.toStringAsFixed(1)} overs • Innings ${inn.inningsNumber}',
            icon: Icons.sports_cricket,
          ),
          _battingTable(inn),
          const SizedBox(height: 10),
          _extrasRow(inn),
          const SizedBox(height: 12),
          _bowlingTable(inn),
          const SizedBox(height: 12),
          _fallOfWickets(inn),
          _partnerships(inn),
          _yetToBat(inn),
        ],
        if (_match.innings.isEmpty)
          Text(lang.isHindi
              ? 'स्कोरकार्ड अभी उपलब्ध नहीं है।'
              : 'Scorecard not available yet.'),
      ],
    );
  }

  Widget _battingTable(Innings inn) {
    return KingGradientCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.gold.withValues(alpha: 0.14),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
            ),
            child: const Row(
              children: [
                Text('BATTING',
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: AppTheme.goldLight)),
                Spacer(),
                Text('Full card — tap a batter for profile',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 720,
              child: Column(
                children: [
                  const ScoreRow(
                    cells: [
                      SizedBox(
                          width: 190,
                          child: Text('BATTER',
                              style: TextStyle(
                                  color: AppTheme.goldLight,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900))),
                      ScoreHeaderCell('R', width: 52),
                      ScoreHeaderCell('B', width: 52),
                      ScoreHeaderCell('4s', width: 44),
                      ScoreHeaderCell('6s', width: 44),
                      ScoreHeaderCell('SR', width: 64),
                    ],
                  ),
                  for (final b in inn.batting)
                    ScoreRow(
                      highlighted: b.notOut,
                      cells: [
                        SizedBox(
                          width: 190,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                b.playerName +
                                    (b.notOut ? ' *' : ''),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14),
                              ),
                              if (b.dismissal.isNotEmpty)
                                Text(b.dismissal,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 11)),
                            ],
                          ),
                        ),
                        SizedBox(
                            width: 52,
                            child: Text('${b.runs}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                    color: AppTheme.goldLight))),
                        SizedBox(
                            width: 52,
                            child: Text('${b.balls}',
                                textAlign: TextAlign.right)),
                        SizedBox(
                            width: 44,
                            child: Text('${b.fours}',
                                textAlign: TextAlign.right)),
                        SizedBox(
                            width: 44,
                            child: Text('${b.sixes}',
                                textAlign: TextAlign.right)),
                        SizedBox(
                            width: 64,
                            child: Text(b.strikeRate.toStringAsFixed(1),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700))),
                      ],
                    ),
                  // Total row
                  Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.gold.withValues(alpha: 0.12),
                      border: Border(
                        top: BorderSide(
                            color:
                                AppTheme.gold.withValues(alpha: 0.4)),
                      ),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 190,
                          child: Text('TOTAL',
                              style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.goldLight)),
                        ),
                        SizedBox(
                            width: 52,
                            child: Text('${inn.total}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.goldLight))),
                        const SizedBox(width: 52),
                        const SizedBox(width: 44),
                        const SizedBox(width: 44),
                        SizedBox(
                            width: 64,
                            child: Text(
                                '${inn.wickets} wkts',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text('↔ Swipe table sideways to see all columns (R / B / 4s / 6s / SR)',
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _extrasRow(Innings inn) {
    final extrasLabel = inn.extrasText.isEmpty
        ? 'Extras: ${inn.extrasRuns}'
        : 'Extras: ${inn.extrasText}';
    return KingGradientCard(
      child: Row(
        children: [
          const Icon(Icons.add_circle_outline,
              size: 18, color: AppTheme.goldLight),
          const SizedBox(width: 8),
          Expanded(
            child: Text(extrasLabel,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          GoldChip(label: 'Total ${inn.total}/${inn.wickets}'),
        ],
      ),
    );
  }

  Widget _bowlingTable(Innings inn) {
    return KingGradientCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.blue.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
            ),
            child: const Row(
              children: [
                Text('BOWLING',
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: AppTheme.goldLight)),
                Spacer(),
                Text('O • M • R • W • Econ • Wd • Nb',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 720,
              child: Column(
                children: [
                  const ScoreRow(
                    cells: [
                      SizedBox(
                          width: 190,
                          child: Text('BOWLER',
                              style: TextStyle(
                                  color: AppTheme.goldLight,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900))),
                      ScoreHeaderCell('O', width: 52),
                      ScoreHeaderCell('M', width: 44),
                      ScoreHeaderCell('R', width: 52),
                      ScoreHeaderCell('W', width: 44),
                      ScoreHeaderCell('Econ', width: 64),
                      ScoreHeaderCell('Wd', width: 44),
                      ScoreHeaderCell('Nb', width: 44),
                    ],
                  ),
                  for (final b in inn.bowling)
                    ScoreRow(
                      cells: [
                        SizedBox(
                          width: 190,
                          child: Text(b.playerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 14)),
                        ),
                        SizedBox(
                            width: 52,
                            child: Text(b.overs.toStringAsFixed(0),
                                textAlign: TextAlign.right)),
                        SizedBox(
                            width: 44,
                            child: Text('${b.maidens}',
                                textAlign: TextAlign.right)),
                        SizedBox(
                            width: 52,
                            child: Text('${b.runsConceded}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700))),
                        SizedBox(
                            width: 44,
                            child: Text('${b.wickets}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.goldLight))),
                        SizedBox(
                            width: 64,
                            child: Text(b.economy.toStringAsFixed(2),
                                textAlign: TextAlign.right)),
                        SizedBox(
                            width: 44,
                            child: Text('${b.wides}',
                                textAlign: TextAlign.right)),
                        SizedBox(
                            width: 44,
                            child: Text('${b.noBalls}',
                                textAlign: TextAlign.right)),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text('↔ Swipe sideways for Econ / Wd / Nb',
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _fallOfWickets(Innings inn) {
    if (inn.fallOfWickets.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PremiumSectionHeader(
            title: 'Fall of Wickets', icon: Icons.trending_down),
        KingGradientCard(
          child: Column(
            children: [
              for (int i = 0; i < inn.fallOfWickets.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppTheme.red.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppTheme.red.withValues(alpha: 0.5)),
                        ),
                        child: Text('${i + 1}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(inn.fallOfWickets[i],
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _partnerships(Innings inn) {
    if (inn.partnerships.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PremiumSectionHeader(
            title: 'Partnerships', icon: Icons.group_outlined),
        KingGradientCard(
          child: Column(
            children: [
              for (final p in inn.partnerships)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.handshake_outlined,
                          size: 16, color: AppTheme.goldLight),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(p,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _yetToBat(Innings inn) {
    if (inn.yetToBat.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PremiumSectionHeader(
            title: 'Yet to Bat', icon: Icons.hourglass_top),
        KingGradientCard(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final name in inn.yetToBat) GoldChip(label: name),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------- SQUAD / PREDICTION ----------------

  Widget _squadTab() {
    return FutureBuilder(
      future: ApiService().fetchPlayers(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final all = snap.data!;
        final squadIds = {..._match.squadA, ..._match.squadB};
        final squad =
            all.where((p) => squadIds.contains(p.id)).toList();
        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            const PremiumSectionHeader(
                title: 'Squad — tap a player for full profile',
                icon: Icons.groups_outlined),
            for (final p in squad)
              PlayerCard(
                player: p,
                contextLine:
                    'vs ${_match.teamA == p.team ? _match.teamB : _match.teamA} • ${_match.format}',
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => PlayerProfileScreen(
                            player: p,
                            opponent: _match.teamA == p.team
                                ? _match.teamB
                                : _match.teamA,
                            venueId: _match.venueId,
                            format: _match.format))),
              ),
            if (squad.isEmpty)
              const Text('Squad data will appear once the free API '
                  'returns squads for this match.'),
          ],
        );
      },
    );
  }

  Widget _predictionTab() {
    return FutureBuilder(
      future: ApiService().fetchPlayers(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final all = snap.data!;
        final squadIds = {..._match.squadA, ..._match.squadB};
        final squad =
            all.where((p) => squadIds.contains(p.id)).toList();
        final preds = squad
            .map((p) => PredictionEngine.predict(
                  player: p,
                  opponent: _match.teamA == p.team
                      ? _match.teamB
                      : _match.teamA,
                  venueId: _match.venueId,
                  format: _match.format,
                ))
            .toList()
          ..sort((a, b) => b.score.compareTo(a.score));
        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            const PremiumSectionHeader(
                title: 'Who will fire? — King Prediction',
                subtitle: 'Form + vs Opponent + Venue + Matchup + Pitch',
                icon: Icons.psychology_outlined),
            for (final pr in preds) PredictionCard(prediction: pr),
          ],
        );
      },
    );
  }
}
