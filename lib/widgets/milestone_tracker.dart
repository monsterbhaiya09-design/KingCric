import 'package:flutter/material.dart';
import '../models/innings.dart';
import '../utils/app_theme.dart';
import 'premium_widgets.dart';

/// One milestone derived ONLY from a loaded scorecard: a batter
/// approaching/reaching 50 or 100, a bowler approaching/reaching
/// 5 wickets, or a partnership approaching/reaching 100 runs.
/// [progress] is 0.0–1.0 toward the milestone target; [reached]
/// means the target is met or passed. Nothing is projected or
/// invented — a milestone appears only when real runs/wickets
/// in the scorecard put it in reach.
class Milestone {
  final String label;
  final String detail;
  final double progress;
  final bool reached;

  const Milestone({
    required this.label,
    required this.detail,
    required this.progress,
    required this.reached,
  });
}

/// Pure computation, unit-tested: batting 50/100 (shown from 25 runs),
/// bowling 5 wickets (shown from 3 wickets), partnerships 100 runs
/// (shown from 50 runs). Unparseable partnership strings are skipped.
List<Milestone> computeMilestones(List<Innings> innings) {
  final out = <Milestone>[];
  final partnershipRuns = RegExp(r'—\s*(\d+)');
  final partnershipRunsAlt = RegExp(r'(\d+)\s*\(');
  for (final inn in innings) {
    for (final b in inn.batting) {
      if (b.runs < 25) continue;
      if (b.runs >= 100) {
        out.add(Milestone(
          label: '💯 ${b.playerName}',
          detail: '${b.runs} runs • ${inn.team}',
          progress: 1,
          reached: true,
        ));
      } else if (b.runs >= 50) {
        out.add(Milestone(
          label: '🎯 ${b.playerName} → 100',
          detail:
              '${b.runs} runs • ${100 - b.runs} to go • ${inn.team}',
          progress: (b.runs / 100).clamp(0.0, 1.0),
          reached: false,
        ));
      } else {
        out.add(Milestone(
          label: '🎯 ${b.playerName} → 50',
          detail:
              '${b.runs} runs • ${50 - b.runs} to go • ${inn.team}',
          progress: (b.runs / 50).clamp(0.0, 1.0),
          reached: false,
        ));
      }
    }
    for (final b in inn.bowling) {
      if (b.wickets < 3) continue;
      if (b.wickets >= 5) {
        out.add(Milestone(
          label: '🎯 ${b.playerName} — 5 wickets',
          detail: '${b.wickets} wickets • ${inn.team} bowling',
          progress: 1,
          reached: true,
        ));
      } else {
        out.add(Milestone(
          label: '🎯 ${b.playerName} → 5 wickets',
          detail: '${b.wickets} wickets • ${5 - b.wickets} to go',
          progress: (b.wickets / 5).clamp(0.0, 1.0),
          reached: false,
        ));
      }
    }
    for (final p in inn.partnerships) {
      final m = partnershipRuns.firstMatch(p) ??
          partnershipRunsAlt.firstMatch(p);
      if (m == null) continue;
      final runs = int.tryParse(m.group(1)!);
      if (runs == null || runs < 50) continue;
      if (runs >= 100) {
        out.add(Milestone(
          label: '🤝 Partnership 100',
          detail: '$p • ${inn.team}',
          progress: 1,
          reached: true,
        ));
      } else {
        out.add(Milestone(
          label: '🤝 Partnership → 100',
          detail: '$p • ${100 - runs} to go • ${inn.team}',
          progress: (runs / 100).clamp(0.0, 1.0),
          reached: false,
        ));
      }
    }
  }
  // Reached milestones first, then closest to target.
  out.sort((a, b) {
    if (a.reached != b.reached) return a.reached ? -1 : 1;
    return b.progress.compareTo(a.progress);
  });
  return out;
}

/// Milestone tracker card for the Live tab. Shows at most 5
/// milestones; when no scorecard innings exist it renders nothing
/// (the scorecard tab owns the empty state), and when innings exist
/// but nothing is in reach it says so honestly.
class MilestoneTracker extends StatelessWidget {
  final List<Innings> innings;
  const MilestoneTracker({super.key, required this.innings});

  @override
  Widget build(BuildContext context) {
    if (innings.isEmpty) return const SizedBox.shrink();
    final milestones = computeMilestones(innings).take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PremiumSectionHeader(
            title: 'Milestones', icon: Icons.emoji_events),
        KingGradientCard(
          child: milestones.isEmpty
              ? const Text(
                  'No milestones in reach yet in this innings.',
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13),
                )
              : Column(
                  children: [
                    for (final m in milestones) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(m.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    color: m.reached
                                        ? AppTheme.goldLight
                                        : AppTheme.textPrimary)),
                          ),
                          if (m.reached)
                            const Text('✓',
                                style: TextStyle(
                                    color: AppTheme.goldLight,
                                    fontWeight: FontWeight.w900)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(m.detail,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12)),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: m.progress,
                          minHeight: 6,
                          backgroundColor: Colors.white12,
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(
                                  AppTheme.gold),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}
