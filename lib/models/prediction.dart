/// Prediction output. Score 0-100. Verdict is derived from the score
/// so Hindi + English labels always agree.
enum PredictionVerdict { likely, risky, unlikely }

class Prediction {
  final String playerId;
  final String playerName;
  final String opponent;
  final String venueId;
  final String format;
  final double score; // 0-100
  final double recentFormScore;
  final double vsOpponentScore;
  final double venueScore;
  final double matchupScore;
  final double pitchScore;
  final String explanationEn;
  final String explanationHi;

  /// False when the player has NO signal at all (no career matches,
  /// no recent form, no matchups). The UI must show "Not enough data"
  /// instead of a number — a prediction with no data behind it is a
  /// fake number. Defaults true so existing call sites are unaffected.
  final bool hasData;

  const Prediction({
    required this.playerId,
    required this.playerName,
    required this.opponent,
    required this.venueId,
    required this.format,
    required this.score,
    required this.recentFormScore,
    required this.vsOpponentScore,
    required this.venueScore,
    required this.matchupScore,
    required this.pitchScore,
    required this.explanationEn,
    required this.explanationHi,
    this.hasData = true,
  });

  PredictionVerdict get verdict {
    if (score >= 65) return PredictionVerdict.likely;
    if (score >= 40) return PredictionVerdict.risky;
    return PredictionVerdict.unlikely;
  }

  String verdictEn() {
    switch (verdict) {
      case PredictionVerdict.likely:
        return 'Likely to perform';
      case PredictionVerdict.risky:
        return 'Risky';
      case PredictionVerdict.unlikely:
        return 'Unlikely to fire';
    }
  }

  String verdictHi() {
    switch (verdict) {
      case PredictionVerdict.likely:
        return 'चलने की संभावना';
      case PredictionVerdict.risky:
        return 'रिस्की';
      case PredictionVerdict.unlikely:
        return 'चलना मुश्किल';
    }
  }

  Map<String, dynamic> toJson() => {
        'playerId': playerId,
        'playerName': playerName,
        'opponent': opponent,
        'venueId': venueId,
        'format': format,
        'score': score,
        'recentFormScore': recentFormScore,
        'vsOpponentScore': vsOpponentScore,
        'venueScore': venueScore,
        'matchupScore': matchupScore,
        'pitchScore': pitchScore,
        'explanationEn': explanationEn,
        'explanationHi': explanationHi,
        'hasData': hasData,
      };
}
