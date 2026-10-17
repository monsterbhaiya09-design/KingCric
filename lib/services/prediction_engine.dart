import '../models/player.dart';
import '../models/prediction.dart';

/// Prediction engine — weighted stats model (Phase 1, free).
///
/// Weights (must sum to 1.0):
///   recent form  30%  | vs opponent 25% | venue 20% | matchup 15% | pitch 10%
///
/// Each sub-score is normalised 0-100 from real stats, never guessed:
/// - Recent form: last 5 entries, runs per ball + wickets, recent = heavier.
/// - vs Opponent: batter average vs this opponent vs career average.
/// - Venue: average at this venue vs career average.
/// - Matchup: balls per dismissal vs the opposition's likely bowlers.
/// - Pitch: venue batting-friendliness (0-100 input from venue data).
///
/// Phase 2 (ML) will replace the linear blend with a trained model, but
/// the interface (predict()) stays the same.
class PredictionEngine {
  static const double wForm = 0.30;
  static const double wOpponent = 0.25;
  static const double wVenue = 0.20;
  static const double wMatchup = 0.15;
  static const double wPitch = 0.10;

  static Prediction predict({
    required Player player,
    required String opponent,
    required String venueId,
    required String format,
    double pitchBattingFriendliness = 55, // 0-100, from venue/pitch data
  }) {
    final career = player.battingOverall();
    final vsOpp = player.battingVs(opponent);
    final venueStats = player.battingByVenue[venueId];

    final formScore = _formScore(player);
    final oppScore = _relativeScore(
      vsOpp.average, career.average,
      fallback: vsOpp.matches == 0 ? 50 : 50,
    );
    final double venueScore = venueStats == null
        ? 50.0
        : _relativeScore(venueStats.average, career.average, fallback: 50);
    final matchupScore = _matchupScore(player);
    final double pitchScore =
        pitchBattingFriendliness.clamp(0, 100).toDouble();

    final total = formScore * wForm +
        oppScore * wOpponent +
        venueScore * wVenue +
        matchupScore * wMatchup +
        pitchScore * wPitch;

    final en = _explainEn(
      player: player,
      opponent: opponent,
      form: formScore,
      opp: oppScore,
      venue: venueScore,
      matchup: matchupScore,
    );
    final hi = _explainHi(
      player: player,
      opponent: opponent,
      form: formScore,
      opp: oppScore,
      venue: venueScore,
      matchup: matchupScore,
    );

    return Prediction(
      playerId: player.id,
      playerName: player.name,
      opponent: opponent,
      venueId: venueId,
      format: format,
      score: double.parse(total.toStringAsFixed(1)),
      recentFormScore: formScore,
      vsOpponentScore: oppScore,
      venueScore: venueScore,
      matchupScore: matchupScore,
      pitchScore: pitchScore,
      explanationEn: en,
      explanationHi: hi,
    );
  }

  static double _formScore(Player p) {
    if (p.recentForm.isEmpty) return 50;
    double weighted = 0;
    double weightSum = 0;
    for (var i = 0; i < p.recentForm.length && i < 5; i++) {
      final e = p.recentForm[i];
      final w = 5.0 - i; // most recent counts most
      final double runsComponent =
          ((e.runs / 50).clamp(0, 1.5) * 50).toDouble(); // 50 runs = 50 pts, capped
      final double ballComponent = e.balls == 0
          ? 0.0
          : (((e.runs / e.balls) * 100 / 150).clamp(0, 1.0) * 30).toDouble();
      final wkComponent =
          (e.wickets * 10).clamp(0, 20).toDouble();
      weighted += (runsComponent + ballComponent + wkComponent) * w;
      weightSum += w;
    }
    if (weightSum == 0) return 50;
    return (weighted / weightSum).clamp(0, 100).toDouble();
  }

  /// Score 0-100: how much better/worse is [value] than [baseline]?
  static double _relativeScore(double value, double baseline,
      {required double fallback}) {
    if (baseline <= 0) return fallback;
    final ratio = value / baseline;
    return (50 * ratio).clamp(5, 95).toDouble();
  }

  static double _matchupScore(Player p) {
    if (p.matchups.isEmpty) return 50;
    double total = 0;
    for (final m in p.matchups) {
      // More balls per dismissal = batter dominates the matchup.
      final bpd = m.ballsPerDismissal;
      final double s =
          bpd <= 0 ? 50.0 : (bpd / 30 * 50).clamp(10, 95).toDouble();
      total += s;
    }
    return total / p.matchups.length;
  }

  static String _explainEn({
    required Player player,
    required String opponent,
    required double form,
    required double opp,
    required double venue,
    required double matchup,
  }) {
    final bits = <String>[];
    bits.add(form >= 60
        ? 'Strong recent form (${form.toStringAsFixed(0)}/100).'
        : form >= 40
            ? 'Mixed recent form (${form.toStringAsFixed(0)}/100).'
            : 'Weak recent form (${form.toStringAsFixed(0)}/100).');
    bits.add(opp >= 60
        ? 'Has a good record vs $opponent.'
        : opp >= 40
            ? 'Average record vs $opponent.'
            : 'Struggles vs $opponent historically.');
    bits.add(venue >= 60
        ? 'Likes this venue.'
        : venue >= 40
            ? 'Average at this venue.'
            : 'Below par at this venue.');
    bits.add(matchup >= 60
        ? 'Dominates the likely bowling matchups.'
        : matchup >= 40
            ? 'Even bowling matchups.'
            : 'Bowling matchups favour the bowlers.');
    return '${player.name}: ${bits.join(' ')}';
  }

  static String _explainHi({
    required Player player,
    required String opponent,
    required double form,
    required double opp,
    required double venue,
    required double matchup,
  }) {
    final bits = <String>[];
    bits.add(form >= 60
        ? 'हालिया फॉर्म मजबूत है (${form.toStringAsFixed(0)}/100)।'
        : form >= 40
            ? 'हालिया फॉर्म मिला-जुला है (${form.toStringAsFixed(0)}/100)।'
            : 'हालिया फॉर्म कमजोर है (${form.toStringAsFixed(0)}/100)।');
    bits.add(opp >= 60
        ? '$opponent के खिलाफ अच्छा रिकॉर्ड है।'
        : opp >= 40
            ? '$opponent के खिलाफ औसत रिकॉर्ड है।'
            : '$opponent के खिलाफ दिक्कत होती है।');
    bits.add(venue >= 60
        ? 'इस मैदान पर अच्छा खेलता है।'
        : venue >= 40
            ? 'इस मैदान पर औसत है।'
            : 'इस मैदान पर औसत से नीचे है।');
    bits.add(matchup >= 60
        ? 'बॉलिंग मैचअप बैटर के पक्ष में है।'
        : matchup >= 40
            ? 'बॉलिंग मैचअप बराबर है।'
            : 'बॉलिंग मैचअप बॉलर्स के पक्ष में है।');
    return '${player.name}: ${bits.join(' ')}';
  }
}
