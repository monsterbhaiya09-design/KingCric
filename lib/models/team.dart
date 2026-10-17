/// Team + H2H record. H2H is stored as wins per opponent so the
/// match screen can show "India 12 - 3 Pakistan (18 matches)" without
/// re-deriving it from every match.
class Team {
  final String id;
  final String name;
  final String shortName;
  final String type; // International / League / Domestic / Women / U19
  final Map<String, int> winsVs; // opponent -> wins
  final Map<String, int> lossesVs;
  final int totalMatches;
  final int totalWins;

  const Team({
    required this.id,
    required this.name,
    this.shortName = '',
    this.type = 'International',
    this.winsVs = const {},
    this.lossesVs = const {},
    this.totalMatches = 0,
    this.totalWins = 0,
  });

  int winsVsOpponent(String opp) => winsVs[opp] ?? 0;
  int lossesVsOpponent(String opp) => lossesVs[opp] ?? 0;

  factory Team.fromJson(Map<String, dynamic> j) => Team(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        shortName: j['shortName'] as String? ?? '',
        type: j['type'] as String? ?? 'International',
        winsVs: ((j['winsVs'] as Map?) ?? {}).map((k, v) =>
            MapEntry(k.toString(), (v as num).toInt())),
        lossesVs: ((j['lossesVs'] as Map?) ?? {}).map((k, v) =>
            MapEntry(k.toString(), (v as num).toInt())),
        totalMatches: (j['totalMatches'] as num?)?.toInt() ?? 0,
        totalWins: (j['totalWins'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'shortName': shortName,
        'type': type,
        'winsVs': winsVs,
        'lossesVs': lossesVs,
        'totalMatches': totalMatches,
        'totalWins': totalWins,
      };
}
