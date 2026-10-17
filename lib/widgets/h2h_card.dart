import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// Team H2H bar: "India 12 — 3 Pakistan (18 matches)".
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
    final frac = total == 0 ? 0.5 : winsA / total;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Head to Head',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 4),
            Text('$total matches • $teamA $winsA — $winsB $teamB',
                style: const TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: frac,
                minHeight: 10,
                backgroundColor: AppTheme.red.withValues(alpha: 0.6),
                valueColor: const AlwaysStoppedAnimation<Color>(
                    AppTheme.green),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(teamA,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(teamB,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
