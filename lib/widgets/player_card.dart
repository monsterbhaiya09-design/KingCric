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
                    Text(
                        'Avg ${bat.average.toStringAsFixed(1)} • SR ${bat.strikeRate.toStringAsFixed(1)}',
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 11)),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          player.dataComplete
                              ? Icons.verified
                              : Icons.hourglass_top,
                          size: 13,
                          color: player.dataComplete
                              ? AppTheme.green
                              : AppTheme.amber,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                              player.dataComplete
                                  ? 'Complete'
                                  : 'Verifying…',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 11)),
                        ),
                      ],
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
