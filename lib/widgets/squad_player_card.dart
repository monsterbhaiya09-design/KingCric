import 'package:flutter/material.dart';
import '../models/player.dart';
import '../utils/app_theme.dart';
import 'premium_widgets.dart';

/// Squad player row — shown ONLY inside a match (Squad tab).
///
/// Match-centric: every row carries THIS match's context, not just
/// career totals:
/// - Batting in THIS format (fallback: overall when the player has
///   no stats in this format yet — never a fake 0/0/0 row)
/// - vs THIS opponent mini-line
/// - Bowling in THIS format (omitted for pure batters with no
///   bowling record — never a fake "0 wkts" line)
/// - Recent form: last 5 entries, compact chips
/// - Honest source label (Real • Cricsheet / Demo / Partial /
///   "Scorecard only" for scorecard-derived names with no profile)
///
/// A player with NO stats at all shows "Stats not available yet"
/// instead of zeros — zeros would look like real data.
class SquadPlayerCard extends StatelessWidget {
  final Player player;
  final String opponent;
  final String format;
  final VoidCallback? onTap;

  const SquadPlayerCard({
    super.key,
    required this.player,
    required this.opponent,
    required this.format,
    this.onTap,
  });

  bool get _isScorecardOnly => player.source == 'scorecard';

  /// Format batting, falling back to overall when the player has
  /// no recorded stats in this format.
  BattingStats _formatBatting() {
    final inFormat = player.battingInFormat(format);
    if (inFormat.matches > 0 || inFormat.runs > 0) return inFormat;
    return player.battingOverall();
  }

  /// Format bowling, falling back to overall bowling when the
  /// player has no recorded bowling in this format.
  BowlingStats? _formatBowling() {
    final inFormat = player.bowlingByFormat[format];
    if (inFormat != null && (inFormat.wickets > 0 || inFormat.balls > 0)) {
      return inFormat;
    }
    final overall = player.bowlingOverall();
    if (overall.wickets > 0) {
      return BowlingStats(
        wickets: overall.wickets,
        matches: overall.matches,
        balls: 0,
        runsConceded: 0,
        economy: 0,
        average: 0,
        strikeRate: 0,
        best: '-',
      );
    }
    return null;
  }

  String _sourceLabel() {
    if (_isScorecardOnly) return 'Scorecard only';
    if (player.source == 'cricsheet') return 'Real • Cricsheet';
    // Provenance, not completeness: a provider partial profile is
    // Partial, never "Demo" (demo = curated sample only).
    if (player.source == 'demo') return 'Demo';
    return 'Partial';
  }

  @override
  Widget build(BuildContext context) {
    final bat = _formatBatting();
    final vs = player.battingVs(opponent);
    final bowl = _formatBowling();
    final hasAnyStats = bat.matches > 0 ||
        bat.runs > 0 ||
        player.recentForm.isNotEmpty ||
        (bowl != null && bowl.wickets > 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: AppTheme.premiumCard(),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  KingAvatar(name: player.name, radius: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(player.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w900, fontSize: 16)),
                        const SizedBox(height: 2),
                        Text('${player.role} • ${player.team}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: AppTheme.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GoldChip(label: _sourceLabel()),
                ],
              ),
              const SizedBox(height: 10),
              if (!hasAnyStats)
                const Text('Stats not available for this player yet.',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13)),
              if (hasAnyStats) ...[
                // Batting in THIS format.
                Text(
                  'Batting ($format): ${bat.runs} runs • Avg ${bat.average.toStringAsFixed(1)} • SR ${bat.strikeRate.toStringAsFixed(1)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 4),
                // vs THIS opponent.
                if (vs.matches > 0 || vs.runs > 0)
                  Text(
                    'vs $opponent: ${vs.runs} runs • Avg ${vs.average.toStringAsFixed(1)} • SR ${vs.strikeRate.toStringAsFixed(1)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppTheme.goldSoft, fontSize: 13),
                  )
                else
                  Text('vs $opponent: no data yet',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 13)),
                if (bowl != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Bowling ($format): ${bowl.wickets} wkts${bowl.economy > 0 ? ' • Econ ${bowl.economy.toStringAsFixed(2)}' : ''}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13),
                  ),
                ],
                if (player.recentForm.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('Recent form (last 5)',
                      style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final f in player.recentForm.take(5))
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.navyCard3,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color:
                                    AppTheme.gold.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            _formChip(f),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
              const SizedBox(height: 8),
              const Row(
                children: [
                  Icon(Icons.touch_app,
                      size: 14, color: AppTheme.goldLight),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text('Tap for full profile',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 11)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formChip(FormEntry f) {
    final bat = '${f.runs} (${f.balls})';
    final bowl = f.wickets > 0 ? ' • ${f.wickets}w' : '';
    return '$bat$bowl • ${f.result}';
  }
}
