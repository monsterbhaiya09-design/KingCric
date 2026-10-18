import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/prediction.dart';
import '../utils/app_theme.dart';
import '../utils/strings.dart';
import 'premium_widgets.dart';

/// V2 premium prediction card: gold donut + verdict pill + stat bars.
/// All fractions clamped — CircularProgress/donut never asserts.
class PredictionCard extends StatelessWidget {
  final Prediction prediction;
  const PredictionCard({super.key, required this.prediction});

  Color _color() {
    switch (prediction.verdict) {
      case PredictionVerdict.likely:
        return AppTheme.green;
      case PredictionVerdict.risky:
        return AppTheme.amber;
      case PredictionVerdict.unlikely:
        return AppTheme.red;
    }
  }

  /// NaN/Inf-safe, clamped 0..1 fraction for a 0-100 input score.
  static double _frac(double v) =>
      v.isNaN || v.isInfinite ? 0.0 : (v / 100).clamp(0.0, 1.0);

  /// Display text for a 0-100 input score: '—' when no data (NaN/Inf).
  static String _scoreText(double v) =>
      v.isNaN || v.isInfinite ? '—' : v.toStringAsFixed(0);

  @override
  Widget build(BuildContext context) {
    final isHindi = context.watch<LanguageProvider>().isHindi;
    final verdict = isHindi ? prediction.verdictHi() : prediction.verdictEn();
    final explanation =
        isHindi ? prediction.explanationHi : prediction.explanationEn;
    final score = prediction.score.isNaN
        ? 0.0
        : prediction.score.clamp(0.0, 100.0);
    final color = _color();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: AppTheme.premiumCard(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GoldDonut(
              fraction: score / 100,
              center: score.toStringAsFixed(0),
              color: color,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(prediction.playerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 16)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: color.withValues(alpha: 0.5)),
                    ),
                    child: Text(verdict,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w800,
                            fontSize: 12)),
                  ),
                  const SizedBox(height: 6),
                  Text(explanation,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 13)),
                  const SizedBox(height: 10),
                  // Model inputs — the full weighted formula, not just 3.
                  // Form 30% • vs Opponent 25% • Venue 20% •
                  // Matchup 15% • Pitch 10%. '—' = no data for that input.
                  const Text(
                      'Form 30% • vs Opponent 25% • Venue 20% • Matchup 15% • Pitch 10%',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 11)),
                  const SizedBox(height: 6),
                  StatBar(
                      label: 'Recent Form',
                      value: _scoreText(prediction.recentFormScore),
                      fraction: _frac(prediction.recentFormScore),
                      color: AppTheme.gold),
                  StatBar(
                      label: 'vs Opponent',
                      value: _scoreText(prediction.vsOpponentScore),
                      fraction: _frac(prediction.vsOpponentScore),
                      color: AppTheme.blue),
                  StatBar(
                      label: 'Venue',
                      value: _scoreText(prediction.venueScore),
                      fraction: _frac(prediction.venueScore),
                      color: AppTheme.green),
                  StatBar(
                      label: 'Matchup',
                      value: _scoreText(prediction.matchupScore),
                      fraction: _frac(prediction.matchupScore),
                      color: AppTheme.amber),
                  StatBar(
                      label: 'Pitch',
                      value: _scoreText(prediction.pitchScore),
                      fraction: _frac(prediction.pitchScore),
                      color: AppTheme.red),
                  const SizedBox(height: 10),
                  // Honesty: a model, never a guarantee, never betting advice.
                  const Text(
                      'Prediction is a model, not a guarantee. For information & entertainment only. Not betting advice.',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
