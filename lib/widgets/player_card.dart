import 'package:flutter/material.dart';
import '../models/player.dart';
import '../utils/app_theme.dart';
import 'premium_widgets.dart';

/// V2 premium player row: gradient avatar, gold ring, big numbers,
/// animated stat bar. No overflow — all text ellipsised.
class PlayerCard extends StatelessWidget {
  final Player player;
  final VoidCallback? onTap;
  final String? contextLine; // e.g. "vs Pakistan • T20"
  const PlayerCard(
      {super.key, required this.player, this.onTap, this.contextLine});

  @override
  Widget build(BuildContext context) {
    final bat = player.battingOverall();
    final bowl = player.bowlingOverall();
    const maxRuns = 15000.0;
    final frac = (bat.runs / maxRuns).clamp(0.0, 1.0);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: AppTheme.premiumCard(),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              KingAvatar(name: player.name, radius: 28),
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
                    if (contextLine != null) ...[
                      const SizedBox(height: 3),
                      GoldChip(label: contextLine!),
                    ],
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: frac,
                        minHeight: 5,
                        backgroundColor: AppTheme.navyCard3,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AppTheme.gold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 92,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${bat.runs}',
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: AppTheme.goldLight)),
                    const Text('runs',
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 11)),
                    const SizedBox(height: 2),
                    // Avg + SR on separate lines: the combined
                    // "Avg 45.6 • SR 78.8" string clipped in the 92px
                    // column on narrow phones. Wkts shown when > 0.
                    Text('Avg ${bat.average.toStringAsFixed(1)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 11)),
                    Text('SR ${bat.strikeRate.toStringAsFixed(1)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 11)),
                    if (bowl.wickets > 0)
                      Text('${bowl.wickets} wkts',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 11)),
                    const SizedBox(height: 2),
                    // V3 BUG FIX: mock/demo players showed "Complete"
                    // next to Virat's 27150 runs — misleading, because
                    // the curated demo dataset is NOT verified real
                    // data. Label honestly by source: Cricsheet =
                    // Real, demo = Demo, anything else partial =
                    // Partial.
                    Builder(
                      builder: (_) {
                        final isReal =
                            player.source == 'cricsheet';
                        // Source labels are by PROVENANCE, not by
                        // completeness: a provider partial profile is
                        // Partial, never "Demo" (demo = curated
                        // sample only). Labelling a partial as Demo
                        // understates real provider data.
                        final isDemo = player.source == 'demo';
                        final label = isReal
                            ? 'Real • Cricsheet'
                            : isDemo
                                ? 'Demo'
                                : 'Partial';
                        final color = isReal
                            ? AppTheme.green
                            : isDemo
                                ? AppTheme.amber
                                : AppTheme.textSecondary;
                        final icon = isReal
                            ? Icons.verified
                            : isDemo
                                ? Icons.sports_cricket
                                : Icons.hourglass_top;
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, size: 13, color: color),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                  label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 11)),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
