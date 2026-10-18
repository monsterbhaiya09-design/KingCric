import 'package:flutter/material.dart';
import '../models/match.dart';
import '../models/player.dart';
import '../services/api_service.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';
import '../widgets/match_card.dart';
import '../widgets/premium_widgets.dart';
import 'match_detail_screen.dart';
import 'player_profile_screen.dart';

/// Leagues / Series (Crex + CricketLineX pattern):
/// chips (incl. Women's + U19 + all domestic) → Points Table →
/// Top Players in this league → Matches (Live first, then Upcoming,
/// then Finished) — reusing the SAME KingMatchCard as Home, never a
/// second diverging card.
///
/// Points table is computed from the LOADED matches in this league
/// and labelled as partial — providers do not return a full official
/// table on the free tier, so KingCric never presents its partial
/// table as the official one.
/// One points-table row. [nrr] is null when the loaded matches carry
/// no usable innings overs/totals for that team — the UI shows "—",
/// never a fake 0.00.
class PointsRow {
  final int p, w, l, nr, pts;
  final double? nrr;
  const PointsRow(
      {this.p = 0, this.w = 0, this.l = 0, this.nr = 0, this.pts = 0, this.nrr});
}

/// Cricket overs (e.g. 19.3 = 19 overs + 3 balls) → legal balls.
/// The fractional part is balls (0–5), NOT a decimal fraction.
int cricketOversToBalls(double overs) {
  if (overs <= 0) return 0;
  final whole = overs.floor();
  final balls = ((overs - whole) * 10).round().clamp(0, 5);
  return whole * 6 + balls;
}

/// Pure points-table computation, testable without a widget.
/// - Win = 2 pts, no-result/tie/abandoned = 1 pt each, loss = 0.
/// - A result names a winner only when it mentions exactly one of the
///   two teams (best-effort; "No result" / "abandoned" / "tied" /
///   "draw" always count as no-result).
/// - NRR = (runs scored / overs faced) − (runs conceded / overs
///   bowled), from innings totals/overs; null when no usable data.
Map<String, PointsRow> computePointsTable(List<CricketMatch> matches) {
  final table = <String, _MutableRow>{};
  for (final m in matches) {
    if (!m.isCompleted) continue;
    final a = table.putIfAbsent(m.teamA, _MutableRow.new);
    final b = table.putIfAbsent(m.teamB, _MutableRow.new);
    a.p += 1;
    b.p += 1;
    final lower = m.result.toLowerCase();
    final noResult = lower.contains('no result') ||
        lower.contains('abandon') ||
        lower.contains('tied') ||
        lower.contains('draw') ||
        lower.contains('match drawn');
    final namesA = lower.contains(m.teamA.toLowerCase());
    final namesB = lower.contains(m.teamB.toLowerCase());
    if (!noResult && namesA && !namesB) {
      a.w += 1;
      a.pts += 2;
      b.l += 1;
    } else if (!noResult && namesB && !namesA) {
      b.w += 1;
      b.pts += 2;
      a.l += 1;
    } else {
      a.nr += 1;
      b.nr += 1;
      a.pts += 1;
      b.pts += 1;
    }
    // NRR inputs from innings (only when both sides have overs).
    for (final inn in m.innings) {
      final balls = cricketOversToBalls(inn.overs);
      if (balls <= 0) continue;
      final row = table[inn.team];
      if (row == null) continue;
      row.runsFor += inn.total;
      row.ballsFor += balls;
      // The other team's innings in the same match are runs conceded.
      // Added in the loop below via the opponent innings.
    }
    // Runs conceded: for each innings, the opponent conceded them.
    for (final inn in m.innings) {
      final balls = cricketOversToBalls(inn.overs);
      if (balls <= 0) continue;
      final opponent = inn.team == m.teamA ? m.teamB : m.teamA;
      final row = table[opponent];
      if (row == null) continue;
      row.runsAgainst += inn.total;
      row.ballsAgainst += balls;
    }
  }
  return table.map((team, r) {
    double? nrr;
    if (r.ballsFor > 0 && r.ballsAgainst > 0) {
      nrr = (r.runsFor / r.ballsFor * 6) -
          (r.runsAgainst / r.ballsAgainst * 6);
    }
    return MapEntry(
        team,
        PointsRow(
            p: r.p, w: r.w, l: r.l, nr: r.nr, pts: r.pts, nrr: nrr));
  });
}

class _MutableRow {
  int p = 0, w = 0, l = 0, nr = 0, pts = 0;
  int runsFor = 0, ballsFor = 0, runsAgainst = 0, ballsAgainst = 0;
}

class LeaguesScreen extends StatefulWidget {
  const LeaguesScreen({super.key});
  @override
  State<LeaguesScreen> createState() => _LeaguesScreenState();
}

class _LeaguesScreenState extends State<LeaguesScreen> {
  String _league = 'IPL';
  late Future<List<CricketMatch>> _matchesFuture;
  late Future<List<Player>> _playersFuture;

  @override
  void initState() {
    super.initState();
    _matchesFuture = ApiService().fetchMatches();
    _playersFuture = ApiService().fetchPlayers();
  }

  void _reload() {
    setState(() {
      _matchesFuture = ApiService().fetchMatches();
      _playersFuture = ApiService().fetchPlayers();
    });
  }

  /// League filter: 'All' shows every league; otherwise exact match.
  bool _inLeague(CricketMatch m) =>
      _league == 'All' || m.league == _league;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leagues')),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(10),
            child: Row(
              children: ['All', ...AppConstants.leagues]
                  .map((l) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(l),
                          selected: _league == l,
                          onSelected: (_) => setState(() => _league = l),
                        ),
                      ))
                  .toList(),
            ),
          ),
          Expanded(
            child: FutureBuilder(
              future: _matchesFuture,
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                              'Could not load matches. Check your connection and try again.',
                              textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          FilledButton(
                              onPressed: _reload,
                              child: const Text('Retry')),
                        ],
                      ),
                    ),
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = snap.data!
                    .where(_inLeague)
                    .toList()
                  ..sort(_matchOrder);
                final liveCount =
                    list.where((m) => m.isEffectivelyLive).length;
                final upcomingCount =
                    list.where((m) => !m.isCompleted && !m.isEffectivelyLive).length;
                final finishedCount =
                    list.where((m) => m.isCompleted).length;
                return FutureBuilder(
                  future: _playersFuture,
                  builder: (context, psnap) {
                    final players = psnap.data ?? const <Player>[];
                    return ListView(
                      padding: const EdgeInsets.all(14),
                      children: [
                        // Series info (reference: Series tab shows
                        // standings + fixtures + squads at a glance).
                        Text(
                          '$_league • ${list.length} matches • '
                          '$liveCount live • $upcomingCount upcoming • '
                          '$finishedCount finished',
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12),
                        ),
                        const SizedBox(height: 10),
                        const PremiumSectionHeader(
                            title: 'Points Table',
                            subtitle:
                                'From loaded matches in this league — partial, not the official table',
                            icon: Icons.leaderboard_outlined),
                        _pointsTable(list),
                        const PremiumSectionHeader(
                            title: 'Top Players',
                            subtitle: 'Top 3 runs + top 3 wickets in this league',
                            icon: Icons.emoji_events_outlined),
                        ..._topPlayers(players),
                        const PremiumSectionHeader(
                            title: 'Matches',
                            icon: Icons.sports_cricket),
                        if (list.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                                _league == 'All'
                                    ? 'No matches in the loaded data yet.\nWith a free API key, this section fills automatically.'
                                    : 'No $_league matches in the loaded data yet.\nWith a free API key, this section fills automatically.',
                                textAlign: TextAlign.center),
                          ),
                        for (final m in list)
                          KingMatchCard(
                              match: m,
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          MatchDetailScreen(match: m)))),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Live first, then Upcoming (start ascending), then Finished.
  static int _matchOrder(CricketMatch a, CricketMatch b) {
    int rank(CricketMatch m) =>
        m.isEffectivelyLive ? 0 : (m.isCompleted ? 2 : 1);
    final r = rank(a).compareTo(rank(b));
    if (r != 0) return r;
    if (rank(a) == 1) return a.startTime.compareTo(b.startTime);
    return b.startTime.compareTo(a.startTime);
  }

  Widget _pointsTable(List<CricketMatch> list) {
    final table = computePointsTable(list);
    if (table.isEmpty) {
      return const Text('Table not available — no finished matches in '
          'this league yet.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13));
    }
    // Sort: PTS desc, then NRR desc (null NRR sorts last), then W desc.
    final rows = table.entries.toList()
      ..sort((a, b) {
        final pts = b.value.pts.compareTo(a.value.pts);
        if (pts != 0) return pts;
        final an = a.value.nrr, bn = b.value.nrr;
        if (an == null && bn == null) return b.value.w.compareTo(a.value.w);
        if (an == null) return 1;
        if (bn == null) return -1;
        final nrr = bn.compareTo(an);
        if (nrr != 0) return nrr;
        return b.value.w.compareTo(a.value.w);
      });
    // Horizontal scroll: the 7-column table (TEAM P W L NR PTS NRR)
    // is wider than a 360dp phone — it scrolls, never clips (P5).
    return KingGradientCard(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ScoreRow(cells: [
              SizedBox(
                  width: 140,
                  child: Text('TEAM',
                      style: TextStyle(
                          color: AppTheme.goldLight,
                          fontSize: 11,
                          fontWeight: FontWeight.w900))),
              ScoreHeaderCell('P', width: 40),
              ScoreHeaderCell('W', width: 40),
              ScoreHeaderCell('L', width: 40),
              ScoreHeaderCell('NR', width: 44),
              ScoreHeaderCell('PTS', width: 52),
              ScoreHeaderCell('NRR', width: 72),
            ]),
            for (final e in rows)
              ScoreRow(cells: [
                SizedBox(
                    width: 140,
                    child: Text(e.key,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            const TextStyle(fontWeight: FontWeight.w700))),
                SizedBox(
                    width: 40,
                    child: Text('${e.value.p}', textAlign: TextAlign.right)),
                SizedBox(
                    width: 40,
                    child: Text('${e.value.w}', textAlign: TextAlign.right)),
                SizedBox(
                    width: 40,
                    child: Text('${e.value.l}', textAlign: TextAlign.right)),
                SizedBox(
                    width: 44,
                    child: Text('${e.value.nr}', textAlign: TextAlign.right)),
                SizedBox(
                    width: 52,
                    child: Text('${e.value.pts}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: AppTheme.goldLight))),
                SizedBox(
                    width: 72,
                    child: Text(
                        e.value.nrr == null
                            ? '—'
                            : (e.value.nrr! >= 0 ? '+' : '') +
                                e.value.nrr!.toStringAsFixed(3),
                        textAlign: TextAlign.right)),
              ]),
          ],
        ),
      ),
    );
  }

  List<Widget> _topPlayers(List<Player> players) {
    // 'All' = every player with any batting data; a named league =
    // only players with a split for that league.
    final inLeague = players
        .where((p) => _league == 'All'
            ? p.battingByLeague.isNotEmpty
            : p.battingByLeague.containsKey(_league))
        .toList();
    if (inLeague.isEmpty) {
      return [
        const Text('No league player data in the loaded dataset yet.',
            style:
                TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
      ];
    }
    // 'All' league: rank on career numbers, labelled as such.
    int leagueRuns(Player p) => _league == 'All'
        ? p.battingOverall().runs
        : (p.battingByLeague[_league]?.runs ?? 0);
    double leagueAvg(Player p) => _league == 'All'
        ? p.battingOverall().average
        : (p.battingByLeague[_league]?.average ?? 0);
    final byRuns = [...inLeague]
      ..sort((a, b) => leagueRuns(b).compareTo(leagueRuns(a)));
    final byWkts = [...inLeague]
      ..sort((a, b) => b
          .bowlingOverall()
          .wickets
          .compareTo(a.bowlingOverall().wickets));
    // The player model carries no bowling-by-league split, so the
    // wickets board is honestly labelled CAREER wickets — never
    // presented as league wickets.
    return [
      for (final p in byRuns.where((p) => leagueRuns(p) > 0).take(3))
        _playerRow(p,
            '${leagueRuns(p)} runs • Avg ${leagueAvg(p).toStringAsFixed(1)}'),
      for (final p in byWkts
          .where((p) => p.bowlingOverall().wickets > 0)
          .take(3))
        _playerRow(p,
            '${p.bowlingOverall().wickets} wkts (career wickets — league split not available)'),
    ];
  }

  Widget _playerRow(Player p, String line) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: AppTheme.premiumCard(radius: 12),
      child: ListTile(
        title: Text(p.name,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(line,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right, size: 18),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(
                builder: (_) => PlayerProfileScreen(player: p))),
      ),
    );
  }
}
