import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/prediction.dart';
import '../utils/app_theme.dart';
import '../utils/strings.dart';

/// Prediction card: score ring + verdict + bilingual explanation.
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

  @override
  Widget build(BuildContext context) {
    final isHindi = context.watch<LanguageProvider>().isHindi;
    final verdict = isHindi ? prediction.verdictHi() : prediction.verdictEn();
    final explanation =
        isHindi ? prediction.explanationHi : prediction.explanationEn;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: prediction.score / 100,
                      strokeWidth: 7,
                      backgroundColor: AppTheme.navyCard2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(_color()),
                    ),
                  ),
                  Text(prediction.score.toStringAsFixed(0),
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 20)),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(prediction.playerName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _color().withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(verdict,
                        style: TextStyle(
                            color: _color(),
                            fontWeight: FontWeight.w700,
                            fontSize: 12)),
                  ),
                  const SizedBox(height: 6),
                  Text(explanation,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 13)),
                  const SizedBox(height: 6),
                  Text(
                    'Form ${prediction.recentFormScore.toStringAsFixed(0)} • vs Opp ${prediction.vsOpponentScore.toStringAsFixed(0)} • Venue ${prediction.venueScore.toStringAsFixed(0)} • Matchup ${prediction.matchupScore.toStringAsFixed(0)} • Pitch ${prediction.pitchScore.toStringAsFixed(0)}',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
