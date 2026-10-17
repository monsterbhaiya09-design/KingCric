/// Venue + pitch. Venue records per player live on Player
/// (battingByVenue); this model holds the ground-level context.
class Venue {
  final String id;
  final String name;
  final String city;
  final String country;
  final String pitchType; // e.g. "Batting-friendly", "Spin-friendly", "Pace-friendly"
  final double avgFirstInningsScore;
  final double avgSecondInningsScore;
  final int totalMatches;
  final double batFirstWinPct;
  final String tossAdvice;

  const Venue({
    required this.id,
    required this.name,
    this.city = '',
    this.country = '',
    this.pitchType = '',
    this.avgFirstInningsScore = 0,
    this.avgSecondInningsScore = 0,
    this.totalMatches = 0,
    this.batFirstWinPct = 0,
    this.tossAdvice = '',
  });

  factory Venue.fromJson(Map<String, dynamic> j) => Venue(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        city: j['city'] as String? ?? '',
        country: j['country'] as String? ?? '',
        pitchType: j['pitchType'] as String? ?? '',
        avgFirstInningsScore:
            (j['avgFirstInningsScore'] as num?)?.toDouble() ?? 0,
        avgSecondInningsScore:
            (j['avgSecondInningsScore'] as num?)?.toDouble() ?? 0,
        totalMatches: (j['totalMatches'] as num?)?.toInt() ?? 0,
        batFirstWinPct: (j['batFirstWinPct'] as num?)?.toDouble() ?? 0,
        tossAdvice: j['tossAdvice'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'city': city,
        'country': country,
        'pitchType': pitchType,
        'avgFirstInningsScore': avgFirstInningsScore,
        'avgSecondInningsScore': avgSecondInningsScore,
        'totalMatches': totalMatches,
        'batFirstWinPct': batFirstWinPct,
        'tossAdvice': tossAdvice,
      };
}
