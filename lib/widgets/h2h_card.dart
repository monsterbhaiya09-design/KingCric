import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import 'premium_widgets.dart';

/// V2 premium Team H2H: gold gradient bar, big win numbers, animated.
class H2HCard extends StatelessWidget {
  final String teamA;
  final String teamB;
  final int winsA;
  final int winsB;
  final int total;
  const H2HCard(
      {super.key,
      required this.teamA,
      required this.teamB,
      required this.winsA,
      required this.winsB,
      required this.total});

  @override
  Widget build(BuildContext context) {
    // Clamp: winsA+winsB may exceed total in live data (draws/no-results).
    // Draws / no-results = total minus both win counts (never negative).
    final draws =
        (total - winsA - winsB).clamp(0, total < 0 ? 0 : total);
    // Empty state: no matches => empty bar (0.0), never a 50/50
    // bar that implies a real split.
    final frac = total == 0 ? 0.0 : (winsA / total).clamp(0.0, 1.0);
    // Winner gets gold, loser gets secondary. Draw = both gold.
    final aLeads = winsA > winsB;
    final bLeads = winsB > winsA;
    return KingGradientCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events,
                  size: 20, color: AppTheme.goldLight),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Head-to-Head',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              ),
              GoldChip(label: '$total matches'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(teamA,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text('$winsA wins',
                        style: TextStyle(
                            color: aLeads || !bLeads
                                ? AppTheme.goldLight
                                : AppTheme.textSecondary,
                            fontWeight: FontWeight.w900,
                            fontSize: 22)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                // Empty state: '—', never "0 — 0" as a scoreline.
                child: Text(total == 0 ? '—' : '$winsA — $winsB',
                    style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(teamB,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text('$winsB wins',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            color: bLeads || !aLeads
                                ? AppTheme.goldLight
                                : AppTheme.textSecondary,
                            fontWeight: FontWeight.w900,
                            fontSize: 22)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: frac),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: v,
                minHeight: 10,
                backgroundColor: AppTheme.red.withValues(alpha: 0.6),
                valueColor: const AlwaysStoppedAnimation<Color>(
                    AppTheme.green),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // total == 0 is an EMPTY state, not a 0-0 result: say so
          // plainly instead of presenting "0 — 0 • 0 matches" as if
          // the teams genuinely never met.
          Text(
              total == 0
                  ? 'No head-to-head matches in the loaded data yet.'
                  : draws > 0
                      ? '$teamA $winsA — $winsB $teamB • $total matches • $draws draw${draws == 1 ? '' : 's'} / no-result${draws == 1 ? '' : 's'}'
                      : '$teamA $winsA — $winsB $teamB • $total matches',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}
