import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import 'premium_widgets.dart';

/// Ball-by-ball outcome strip for the current innings.
///
/// HONESTY RULE: KingCric's free providers return scorecard totals,
/// not a per-ball feed, so [balls] is normally null/empty. In that
/// case this widget shows an honest "not available" line and NEVER
/// invents ball outcomes from totals. When a future source does
/// supply real balls (e.g. a ball-level feed), pass them as short
/// outcome tokens: "0", "1", "2", "3", "4", "6", "W", "Wd", "Nb".
/// Only the most recent over (last 6 balls) is shown, latest last.
class BallStrip extends StatelessWidget {
  /// Real per-ball outcomes, latest last. Null/empty = not provided.
  final List<String>? balls;
  final String? teamLabel;

  const BallStrip({super.key, this.balls, this.teamLabel});

  /// Parse a provider "last ball" token into a strip entry, or null
  /// when the token is not a recognisable outcome.
  static String? normaliseOutcome(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    if (RegExp(r'^[0-6]$').hasMatch(t)) return t;
    if (t.toUpperCase() == 'W' || t.toUpperCase() == 'OUT') return 'W';
    if (t.toUpperCase() == 'WD') return 'Wd';
    if (t.toUpperCase() == 'NB') return 'Nb';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final clean = (balls ?? [])
        .map(normaliseOutcome)
        .whereType<String>()
        .toList();
    // Show at most the last over.
    final shown = clean.length > 6 ? clean.sublist(clean.length - 6) : clean;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PremiumSectionHeader(
          title: teamLabel == null
              ? 'Ball by Ball'
              : 'Ball by Ball • $teamLabel',
          icon: Icons.sports_cricket,
        ),
        KingGradientCard(
          child: shown.isEmpty
              ? const Text(
                  'Ball-by-ball not available from free provider.',
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final b in shown) _ballChip(b),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _ballChip(String b) {
    final isWicket = b == 'W';
    final isBoundary = b == '4' || b == '6';
    final bg = isWicket
        ? Colors.redAccent.withValues(alpha: 0.25)
        : isBoundary
            ? AppTheme.gold.withValues(alpha: 0.25)
            : AppTheme.navyCard2;
    final border = isWicket
        ? Colors.redAccent.withValues(alpha: 0.6)
        : isBoundary
            ? AppTheme.gold.withValues(alpha: 0.7)
            : Colors.white24;
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: border),
      ),
      child: Text(b,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 14,
            color: isWicket
                ? Colors.redAccent
                : isBoundary
                    ? AppTheme.goldLight
                    : AppTheme.textPrimary,
          )),
    );
  }
}
