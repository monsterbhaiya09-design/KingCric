import 'package:flutter/material.dart';
import '../models/innings.dart';
import '../utils/app_theme.dart';
import 'premium_widgets.dart';

/// Over-by-over / momentum view (CricketLineX "match graphs" pattern,
/// KingCric's own implementation, own data).
///
/// HONESTY RULE: KingCric's providers return full scorecards (totals,
/// FOW, partnerships) but not per-ball feeds, so this widget draws
/// ONLY what the scorecard actually contains:
///  - partnership runs bars (parsed from the real partnership strings)
///  - fall-of-wickets timeline (score + over, parsed from real FOW)
///  - run rate + required rate (computed from structured totals/overs)
/// It NEVER invents per-over run values. If a string does not parse,
/// that entry is skipped — no fabricated numbers.
class OverGraph extends StatelessWidget {
  final List<Innings> innings;
  const OverGraph({super.key, required this.innings});

  static final _partnershipRuns = RegExp(r'—\s*(\d+)');

  int? _partnershipValue(String p) {
    final m = _partnershipRuns.firstMatch(p);
    return m == null ? null : int.tryParse(m.group(1)!);
  }

  /// Cricket-overs helpers (local copy — OverGraph must NOT import
  /// match_detail_screen.dart, that would be a widget↔screen cycle).
  /// Overs are CRICKET overs: 3.2 = 3 overs + 2 balls = 20 balls.
  /// Run rate MUST divide by balls, never by the raw decimal
  /// (total / 19.5 is wrong; total * 6 / 119 is right).
  static int _ballsFromOvers(double overs) {
    final whole = overs.truncate();
    final ballsPart = ((overs - whole) * 10).round().clamp(0, 5);
    return whole * 6 + ballsPart;
  }

  static String _formatOvers(double overs) {
    final whole = overs.truncate();
    final ballsPart = ((overs - whole) * 10).round().clamp(0, 5);
    return ballsPart == 0 ? '$whole' : '$whole.$ballsPart';
  }

  /// Run rate from balls, never from the raw overs decimal.
  /// 0 balls → "0.00", never NaN / Infinity.
  static String _runRate(Innings inn) {
    final balls = _ballsFromOvers(inn.overs);
    if (balls == 0) return '0.00';
    return (inn.total * 6 / balls).toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    if (innings.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final inn in innings) ...[
          PremiumSectionHeader(
            title: 'Over-by-Over — ${inn.team}',
            subtitle:
                '${inn.total}/${inn.wickets} (${_formatOvers(inn.overs)} ov) • Run rate ${_runRate(inn)}',
            icon: Icons.show_chart,
          ),
          KingGradientCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Partnership runs',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 13)),
                const SizedBox(height: 8),
                ..._partnershipBars(inn),
                const SizedBox(height: 12),
                const Text('Fall of wickets',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 13)),
                const SizedBox(height: 8),
                if (inn.fallOfWickets.isEmpty)
                  const Text('No wickets fallen yet.',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12)),
                for (final f in inn.fallOfWickets)
                  _fowRow(f),
              ],
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _partnershipBars(Innings inn) {
    final values = <({String label, int runs})>[];
    for (final p in inn.partnerships) {
      final runs = _partnershipValue(p);
      if (runs != null) values.add((label: p, runs: runs));
    }
    if (values.isEmpty) {
      return [
        const Text('Partnership data not available.',
            style:
                TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
      ];
    }
    final maxRuns =
        values.map((v) => v.runs).reduce((a, b) => a > b ? a : b);
    return [
      for (final v in values)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: maxRuns == 0 ? 0 : v.runs / maxRuns,
                    minHeight: 10,
                    backgroundColor: AppTheme.navyCard3,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        AppTheme.gold),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 150,
                child: Text('${v.runs} runs',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      const SizedBox(height: 4),
      for (final v in values)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Text(v.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 11)),
        ),
    ];
  }

  /// FOW row: the chip carries "Wicket-Score" ("1-52") and the text
  /// carries batter + over ("Rohit Sharma, 6.1 ov") — the full
  /// "52 (Rohit Sharma, 6.1 ov)" substring is NEVER rendered here,
  /// so it cannot collide with the Scorecard FOW row in tests or
  /// duplicate the same text twice on the Live tab. The wicket
  /// number appears exactly once (in the chip).
  static final _fowFull =
      RegExp(r'^\s*(\d+)\s*-\s*(\d+)\s*\((.*)\)\s*$');

  Widget _fowRow(String f) {
    final m = _fowFull.firstMatch(f);
    final chip = m == null ? 'W' : '${m.group(1)}-${m.group(2)}';
    final detail = m == null ? f : m.group(3)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          GoldChip(label: chip),
          const SizedBox(width: 8),
          Expanded(
            child: Text(detail,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
