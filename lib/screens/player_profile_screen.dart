import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/player.dart';
import '../services/prediction_engine.dart';
import '../utils/app_theme.dart';
import '../utils/strings.dart';
import '../widgets/prediction_card.dart';
import '../widgets/premium_widgets.dart';
import '../widgets/stat_card.dart';

/// V2 Player profile — PREMIUM: gradient hero, avatar, stat bars,
/// full tables with horizontal scroll, no overflow.
class PlayerProfileScreen extends StatelessWidget {
  final Player player;
  final String? opponent;
  final String? venueId;
  final String? format;
  const PlayerProfileScreen(
      {super.key,
      required this.player,
      this.opponent,
      this.venueId,
      this.format});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final overall = player.battingOverall();
    final vsOpp =
        opponent != null ? player.battingVs(opponent!) : null;
    final fmt = format != null ? player.battingInFormat(format!) : null;
    final bowlingOverall = player.bowlingOverall();
    return Scaffold(
      appBar: AppBar(
          title: Text(player.name,
              maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // Premium hero
          Container(
            decoration: AppTheme.heroCard(),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    KingAvatar(name: player.name, radius: 34),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(player.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900)),
                          const SizedBox(height: 3),
                          Text(
                              '${player.role} • ${player.team} • ${player.country}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13)),
                          const SizedBox(height: 3),
                          Text(
                              'Batting: ${player.battingStyle} • Bowling: ${player.bowlingStyle}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                        player.dataComplete
                            ? Icons.verified
                            : Icons.hourglass_top,
                        size: 16,
                        color: player.dataComplete
                            ? AppTheme.green
                            : AppTheme.amber),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                          player.dataComplete
                              ? lang.t('data_complete')
                              : lang.t('data_checking'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
                // Cricsheet: REAL calculated stats — label the scope
                // honestly (sample dataset size), never as full career.
                if (player.source == 'cricsheet') ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.verified,
                          size: 16, color: AppTheme.green),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                            'Real • Cricsheet open data • ${player.sourceMatches} matches in dataset',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary)),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                // Hero quick stats — always visible, no truncation.
                Row(
                  children: [
                    Expanded(
                        child: _heroStat('Runs', '${overall.runs}')),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _heroStat('Avg',
                            overall.average.toStringAsFixed(1))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _heroStat('SR',
                            overall.strikeRate.toStringAsFixed(1))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _heroStat(
                            'Wkts', '${bowlingOverall.wickets}')),
                  ],
                ),
              ],
            ),
          ),
          if (opponent != null && venueId != null)
            PredictionCard(
                prediction: PredictionEngine.predict(
                    player: player,
                    opponent: opponent!,
                    venueId: venueId!,
                    format: format ?? 'T20')),
          const PremiumSectionHeader(
              title: 'Overall — All Formats',
              subtitle: 'Career totals, every format combined',
              icon: Icons.emoji_events),
          _grid([
            StatCard(
                label: lang.t('runs'),
                value: '${overall.runs}',
                barFraction: (overall.runs / 15000).clamp(0.0, 1.0)),
            StatCard(
                label: lang.t('average'),
                value: overall.average.toStringAsFixed(1),
                barFraction: (overall.average / 60).clamp(0.0, 1.0)),
            StatCard(
                label: lang.t('strike_rate'),
                value: overall.strikeRate.toStringAsFixed(1),
                barFraction:
                    (overall.strikeRate / 180).clamp(0.0, 1.0)),
            StatCard(
                label: lang.t('hundreds'),
                value: '${overall.hundreds}',
                sub: '${overall.fifties} ${lang.t('fifties')}'),
          ]),
          // Stat bars — visual, not just numbers.
          const SizedBox(height: 12),
          KingGradientCard(
            child: Column(
              children: [
                StatBar(
                    label: 'Runs',
                    value: '${overall.runs}',
                    fraction: (overall.runs / 15000).clamp(0.0, 1.0)),
                StatBar(
                    label: 'Average ( / 60)',
                    value: overall.average.toStringAsFixed(1),
                    fraction: (overall.average / 60).clamp(0.0, 1.0),
                    color: AppTheme.blue),
                StatBar(
                    label: 'Strike Rate ( / 180)',
                    value: overall.strikeRate.toStringAsFixed(1),
                    fraction:
                        (overall.strikeRate / 180).clamp(0.0, 1.0),
                    color: AppTheme.green),
                StatBar(
                    label: 'Boundaries (4s + 6s)',
                    value: '${overall.fours + overall.sixes}',
                    fraction:
                        ((overall.fours + overall.sixes) / 1500)
                            .clamp(0.0, 1.0),
                    color: AppTheme.amber),
              ],
            ),
          ),
          if (vsOpp != null) ...[
            PremiumSectionHeader(
                title: '${lang.t('vs_opponent')} — $opponent',
                icon: Icons.sports_cricket),
            _grid([
              StatCard(label: lang.t('runs'), value: '${vsOpp.runs}'),
              StatCard(
                  label: lang.t('average'),
                  value: vsOpp.average.toStringAsFixed(1)),
              StatCard(
                  label: lang.t('strike_rate'),
                  value: vsOpp.strikeRate.toStringAsFixed(1)),
              StatCard(label: 'Matches', value: '${vsOpp.matches}'),
            ]),
          ],
          if (fmt != null) ...[
            PremiumSectionHeader(
                title: '${lang.t('format_wise')} — $format',
                icon: Icons.category_outlined),
            _grid([
              StatCard(label: lang.t('runs'), value: '${fmt.runs}'),
              StatCard(
                  label: lang.t('average'),
                  value: fmt.average.toStringAsFixed(1)),
              StatCard(
                  label: lang.t('strike_rate'),
                  value: fmt.strikeRate.toStringAsFixed(1)),
              StatCard(label: 'Matches', value: '${fmt.matches}'),
            ]),
          ],
          const PremiumSectionHeader(
              title: 'All Formats — Full Table',
              subtitle: 'Swipe sideways to see every column',
              icon: Icons.table_chart_outlined),
          _formatTable(),
          if (player.battingByLeague.isNotEmpty) ...[
            const PremiumSectionHeader(
                title: 'Leagues', icon: Icons.emoji_events_outlined),
            for (final e in player.battingByLeague.entries)
              _tableRow(e.key,
                  '${e.value.runs} runs • Avg ${e.value.average.toStringAsFixed(1)} • SR ${e.value.strikeRate.toStringAsFixed(1)}'),
          ],
          if (player.battingByVenue.isNotEmpty) ...[
            PremiumSectionHeader(
                title: lang.t('venue'),
                subtitle: 'Venue records per player',
                icon: Icons.stadium_outlined),
            for (final e in player.battingByVenue.entries)
              _tableRow(e.key,
                  '${e.value.runs} runs • Avg ${e.value.average.toStringAsFixed(1)} • SR ${e.value.strikeRate.toStringAsFixed(1)}'),
          ],
          PremiumSectionHeader(
              title: lang.t('recent_form'), icon: Icons.show_chart),
          for (final f in player.recentForm)
            _tableRow(
                f.matchLabel,
                '${f.opponent} • ${f.format} • ${f.result} • ${f.wickets > 0 ? '${f.wickets} wkts' : '${f.runs} (${f.balls})'}'),
          if (player.matchups.isNotEmpty) ...[
            PremiumSectionHeader(
                title: lang.t('matchup'), icon: Icons.compare_arrows),
            for (final m in player.matchups)
              _tableRow('vs ${m.bowlerName}',
                  '${m.matches} matches • ${m.dismissals} dismissals • ${m.runs} runs / ${m.balls} balls • SR ${m.strikeRate.toStringAsFixed(1)}'),
          ],
          if (player.dismissalHistory.isNotEmpty) ...[
            const PremiumSectionHeader(
                title: 'Dismissal History', icon: Icons.history),
            for (final d in player.dismissalHistory) _tableRow(d, ''),
          ],
          if (player.bowlingByFormat.isNotEmpty) ...[
            const PremiumSectionHeader(
                title: 'Bowling — Full Table', icon: Icons.sports_baseball),
            for (final e in player.bowlingByFormat.entries)
              _tableRow(e.key,
                  '${e.value.wickets} wkts • Econ ${e.value.economy.toStringAsFixed(2)} • Avg ${e.value.average.toStringAsFixed(1)} • Best ${e.value.best}'),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _heroStat(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: AppTheme.goldLight)),
          const SizedBox(height: 2),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _tableRow(String title, String trailing) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: AppTheme.premiumCard(radius: 12),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          if (trailing.isNotEmpty)
            Flexible(
              child: Text(trailing,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _formatTable() {
    return KingGradientCard(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 640,
          child: Column(
            children: [
              const ScoreRow(
                cells: [
                  SizedBox(
                      width: 90,
                      child: Text('FORMAT',
                          style: TextStyle(
                              color: AppTheme.goldLight,
                              fontSize: 11,
                              fontWeight: FontWeight.w900))),
                  ScoreHeaderCell('M', width: 48),
                  ScoreHeaderCell('Runs', width: 72),
                  ScoreHeaderCell('Avg', width: 64),
                  ScoreHeaderCell('SR', width: 64),
                  ScoreHeaderCell('100s', width: 56),
                  ScoreHeaderCell('50s', width: 56),
                ],
              ),
              for (final e in player.battingByFormat.entries)
                ScoreRow(
                  cells: [
                    SizedBox(
                        width: 90,
                        child: Text(e.key,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700))),
                    SizedBox(
                        width: 48,
                        child: Text('${e.value.matches}',
                            textAlign: TextAlign.right)),
                    SizedBox(
                        width: 72,
                        child: Text('${e.value.runs}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: AppTheme.goldLight))),
                    SizedBox(
                        width: 64,
                        child: Text(
                            e.value.average.toStringAsFixed(1),
                            textAlign: TextAlign.right)),
                    SizedBox(
                        width: 64,
                        child: Text(
                            e.value.strikeRate.toStringAsFixed(1),
                            textAlign: TextAlign.right)),
                    SizedBox(
                        width: 56,
                        child: Text('${e.value.hundreds}',
                            textAlign: TextAlign.right)),
                    SizedBox(
                        width: 56,
                        child: Text('${e.value.fifties}',
                            textAlign: TextAlign.right)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _grid(List<Widget> cards) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.55,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: cards,
    );
  }
}
