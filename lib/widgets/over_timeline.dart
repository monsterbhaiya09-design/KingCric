import 'package:flutter/material.dart';
import '../models/innings.dart';
import '../utils/app_theme.dart';
import 'premium_widgets.dart';

/// Over-by-over strip for one innings: one chip per completed over,
/// with a wicket marker on every over in which a wicket fell
/// (parsed from the real fall-of-wickets strings, e.g.
/// "1-52 (Rohit Sharma, 6.1 ov)" → wicket in over 6).
///
/// HONESTY RULE: free providers do not supply per-over run totals,
/// so per-over runs are shown ONLY when [overRuns] is supplied by a
/// real ball-level source (index 0 = over 1). Without it, chips show
/// over numbers + wicket markers only, with an honest caption —
/// per-over runs are never estimated from totals or bowling figures.
class OverTimeline extends StatelessWidget {
  final List<Innings> innings;

  /// Real per-over runs, index 0 = over 1. Null = not provided.
  final List<int>? overRuns;

  /// Real per-over runs keyed by POSITION in [innings]
  /// (preferred when ball data covers several innings; falls back
  /// to [overRuns] when an innings has no entry).
  final Map<int, List<int>>? overRunsByInnings;

  const OverTimeline(
      {super.key, required this.innings, this.overRuns, this.overRunsByInnings});

  /// Overs in which a wicket fell, parsed from FOW strings.
  /// Unparseable entries are skipped, never guessed.
  static Set<int> parseWicketOvers(List<String> fallOfWickets) {
    final overRe = RegExp(r'(\d+)\.(\d+)\s*ov');
    final out = <int>{};
    for (final f in fallOfWickets) {
      final m = overRe.firstMatch(f);
      if (m == null) continue;
      final over = int.tryParse(m.group(1)!);
      if (over != null) out.add(over);
    }
    return out;
  }

  /// Completed whole overs + balls in the current partial over,
  /// from cricket overs (17.3 = 17 overs + 3 balls).
  static ({int whole, int balls}) splitOvers(double overs) {
    final whole = overs.truncate();
    final balls = ((overs - whole) * 10).round().clamp(0, 5);
    return (whole: whole, balls: balls);
  }

  @override
  Widget build(BuildContext context) {
    if (innings.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PremiumSectionHeader(
            title: 'Over Timeline', icon: Icons.timeline),
        for (var i = 0; i < innings.length; i++)
          _overCard(innings[i], overRunsByInnings?[i] ?? overRuns),
      ],
    );
  }

  Widget _overCard(Innings inn, List<int>? runs) {
    return KingGradientCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${inn.team} • ${inn.total}/${inn.wickets}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 10),
          _overStrip(inn, runs),
          const SizedBox(height: 8),
          Text(
            runs == null
                ? 'Per-over runs not provided by free providers — wickets shown from fall of wickets.'
                : 'Runs per over from ball-level data.',
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _overStrip(Innings inn, List<int>? runs) {
    final split = splitOvers(inn.overs);
    final wickets = parseWicketOvers(inn.fallOfWickets);
    final totalChips = split.whole + (split.balls > 0 ? 1 : 0);
    if (totalChips <= 0) {
      return const Text('No overs bowled yet.',
          style:
              TextStyle(color: AppTheme.textSecondary, fontSize: 13));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var over = 1; over <= totalChips; over++) ...[
            _overChip(
              over: over,
              isCurrent: over == totalChips && split.balls > 0,
              hasWicket: wickets.contains(over - 1),
              runs: runs != null && over - 1 < runs.length
                  ? runs[over - 1]
                  : null,
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }

  Widget _overChip({
    required int over,
    required bool isCurrent,
    required bool hasWicket,
    int? runs,
  }) {
    return Container(
      width: 44,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: hasWicket
            ? Colors.redAccent.withValues(alpha: 0.18)
            : isCurrent
                ? AppTheme.gold.withValues(alpha: 0.18)
                : AppTheme.navyCard2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasWicket
              ? Colors.redAccent.withValues(alpha: 0.5)
              : isCurrent
                  ? AppTheme.gold.withValues(alpha: 0.6)
                  : Colors.white24,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$over',
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: isCurrent
                      ? AppTheme.goldLight
                      : AppTheme.textPrimary)),
          Text(hasWicket ? 'W' : (runs == null ? '•' : '$runs'),
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: hasWicket
                      ? Colors.redAccent
                      : AppTheme.textSecondary)),
        ],
      ),
    );
  }
}
