import 'package:flutter/material.dart';
import '../models/player.dart';
import '../utils/app_theme.dart';

/// Player row: name, role, key numbers — taps through to profile.
class PlayerCard extends StatelessWidget {
  final Player player;
  final VoidCallback? onTap;
  final String? contextLine; // e.g. "vs Pakistan • T20"
  const PlayerCard(
      {super.key, required this.player, this.onTap, this.contextLine});

  @override
  Widget build(BuildContext context) {
    final bat = player.battingOverall();
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppTheme.gold,
                child: Text(
                  player.name.isNotEmpty ? player.name[0] : '?',
                  style: const TextStyle(
                      color: Colors.black,
                      fontSize: 22,
                      fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(player.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                    Text('${player.role} • ${player.team}',
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12)),
                    if (contextLine != null)
                      Text(contextLine!,
                          style: const TextStyle(
                              color: AppTheme.goldLight, fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${bat.runs} runs',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(
                      'Avg ${bat.average.toStringAsFixed(1)} • SR ${bat.strikeRate.toStringAsFixed(1)}',
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 11)),
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
                      Text(
                          player.dataComplete
                              ? 'Data complete'
                              : 'Verifying…',
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
