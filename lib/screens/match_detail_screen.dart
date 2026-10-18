import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/innings.dart';
import '../models/match.dart';
import '../models/player.dart';
import '../models/venue.dart';
import '../services/api_service.dart';
import '../services/cricsheet_service.dart';
import '../services/prediction_engine.dart';
import '../utils/app_theme.dart';
import '../utils/strings.dart';
import '../widgets/h2h_card.dart';
import '../widgets/over_graph.dart';
import '../widgets/prediction_card.dart';
import '../widgets/premium_widgets.dart';
import '../widgets/squad_player_card.dart';
import 'player_profile_screen.dart';

/// Top bowler-vs-batter matchups across the two squads, sorted by
/// dismissals desc, then balls desc. Only matchups where the bowler
/// is in one squad and the batter in the other count — same-team
/// pairs are not "head-to-head". Pure function, unit-tested.
List<Matchup> topPlayerMatchups(
    List<Player> squadA, List<Player> squadB, {int limit = 5}) {
  final aIds = squadA.map((p) => p.id).toSet();
  final bIds = squadB.map((p) => p.id).toSet();
  final seen = <String>{};
  final out = <Matchup>[];
  for (final p in [...squadA, ...squadB]) {
    for (final m in p.matchups) {
      // Matchup is stored on the BATTER: m.bowlerId is the bowler,
      // m.batterId is this player. Keep only cross-squad pairs.
      final bowlerInA = aIds.contains(m.bowlerId);
      final bowlerInB = bIds.contains(m.bowlerId);
      final batterInA = aIds.contains(m.batterId);
      final batterInB = bIds.contains(m.batterId);
      final cross = (bowlerInA && batterInB) || (bowlerInB && batterInA);
      if (!cross) continue;
      final key = '${m.bowlerId}|${m.batterId}';
      if (!seen.add(key)) continue;
      if (m.dismissals > 0 || m.balls >= 12) out.add(m);
    }
  }
  out.sort((x, y) {
    final d = y.dismissals.compareTo(x.dismissals);
    return d != 0 ? d : y.balls.compareTo(x.balls);
  });
  return out.take(limit).toList();
}

/// Cricket-overs helpers (top-level so they are unit-testable).
///
/// Overs are stored as CRICKET overs, not decimals: 3.2 means
/// 3 overs + 2 balls = 20 balls, NOT 3.2 * 6 = 19.2. Every place
/// that converts overs (equation, economy, O column) must use
/// these helpers — never a raw `* 6` on the stored double.

/// Cricket overs → balls bowled. 3.2 → 20, 19.5 → 119, 0 → 0.
int ballsFromCricketOvers(double overs) {
  final whole = overs.truncate();
  final ballsPart = ((overs - whole) * 10).round().clamp(0, 5);
  return whole * 6 + ballsPart;
}

/// Display form: 4.0 → '4', 3.2 → '3.2', 0 → '0'. Never truncates
/// the balls part (the O column must show 3.2, never 3).
String formatCricketOvers(double overs) {
  final whole = overs.truncate();
  final ballsPart = ((overs - whole) * 10).round().clamp(0, 5);
  return ballsPart == 0 ? '$whole' : '$whole.$ballsPart';
}

/// Economy recomputed from runs + balls: runs * 6 / balls.
/// The stored `economy` field is NEVER trusted — it can go stale
/// when overs are edited. Falls back to 0 when no balls bowled
/// (never NaN / Infinity).
double displayEconomy(BowlingEntry b) {
  final balls = ballsFromCricketOvers(b.overs);
  if (balls == 0) return 0;
  return b.runsConceded * 6 / balls;
}

/// FOW strings carry an embedded "N-" number ("1-52 (Rohit, 6.1 ov)")
/// but the UI circle already shows the number — strip the prefix so
/// the number appears ONCE, not twice.
String stripFowPrefix(String fow) =>
    fow.replaceFirst(RegExp(r'^\d+\s*-\s*'), '');

/// Dismissal line for a batter: 'not out' for a not-out batter
/// (even when the dismissal field is empty), else the dismissal.
String dismissalLabel(BattingEntry b) {
  if (b.notOut) return 'not out';
  if (b.dismissal.isNotEmpty) return b.dismissal;
  return '—';
}

/// V2 Match detail — PREMIUM + FULL scoreboard.
/// Tabs: Live | Scorecard (FULL) | Squad | Prediction
/// Scorecard shows: Batting R/B/4s/6s/SR + dismissal, Bowling
/// O/M/R/W/Econ/Wd/Nb, Extras breakdown, Fall of Wickets,
/// Partnerships, Yet to bat, Toss + Venue + Umpires.
/// Nothing truncates: tables scroll horizontally, all text wraps.
///
/// TEAM 2 detail rules (smallest details, per reference spec §4.2/§6):
/// - Overs are CRICKET overs (3.2 = 3 overs + 2 balls), never decimals:
///   [formatCricketOvers] / [ballsFromCricketOvers] are the single
///   conversion used by equation, CRR, bowling O and economy.
/// - FOW strings already carry their own "N-" prefix ("1-52 (...)"), so
///   the numbered circle strips it ([stripFowPrefix]) — no "1 1-52".
/// - Bowling economy is recomputed from runs + balls ([displayEconomy])
///   so it can never disagree with the O column.
/// - Dismissal for a not-out batter with an empty dismissal string
///   renders "not out" ([dismissalLabel]) — never a blank line.
/// - Squad is split Team A / Team B sections (never one flat list).
/// - "Last updated HH:MM" shows whenever the match carries lastUpdated;
///   when it does not, nothing is shown — never a fake timestamp.
class MatchDetailScreen extends StatefulWidget {
  final CricketMatch match;
  const MatchDetailScreen({super.key, required this.match});
  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  late CricketMatch _match;
  // Cached once in initState — NEVER recreated in build (recreating a
  // Future in build re-fires the fetch every frame, burning quota
  // and flickering the Squad / Prediction tabs).
  late final Future<List<Player>> _playersFuture;
  late final Future<List<Venue>> _venuesFuture;
  // CRICSHEET-WIRING: Cricsheet futures are LAZY — created on
  // first use by a Squad / Venue / Prediction tab, then cached.
  // The 25 MB asset must NOT be parsed in initState: a user who
  // only opens Live / Scorecard would pay the parse for nothing,
  // and eager creation also starts the platform-channel asset
  // load before the first frame. One Cricsheet load is shared by
  // all three tabs (the asset is parsed once per app run via the
  // static cache in CricsheetService.loadBundled).
  Future<Map<String, List<Player>>>? _cricsheetSquadsFuture;
  Future<Map<String, int>>? _cricsheetH2HFuture;
  Future<VenueStats?>? _cricsheetVenueFuture;
  Future<List<Matchup>>? _cricsheetMatchupsFuture;

  /// Gender for Cricsheet queries: providers write "Pakistan
  /// Women" for women's matches and bare names for men's;
  /// Cricsheet stores both under "Pakistan" and separates them
  /// with its gender field — without this, a men's squad fills
  /// with women's players.
  String get _cricsheetGender =>
      _match.teamA.toLowerCase().contains('women') ||
              _match.teamB.toLowerCase().contains('women')
          ? 'female'
          : 'male';

  Future<Map<String, List<Player>>> get _squadsFuture =>
      _cricsheetSquadsFuture ??= ApiService().cricsheetSquadsFor(
          _match.teamA, _match.teamB,
          format: _match.format, gender: _cricsheetGender);
  Future<Map<String, int>> get _h2hFuture =>
      _cricsheetH2HFuture ??= ApiService().cricsheetHeadToHead(
          _match.teamA, _match.teamB,
          format: _match.format, gender: _cricsheetGender);
  Future<VenueStats?> get _venueFuture => _cricsheetVenueFuture ??=
      ApiService()
          .cricsheetVenueStats(_match.venueName, gender: _cricsheetGender);
  Future<List<Matchup>> get _matchupsFuture =>
      _cricsheetMatchupsFuture ??= _loadCricsheetMatchups();
  bool _refreshingDetail = false;

  @override
  void initState() {
    super.initState();
    _match = widget.match;
    // MATCH-CENTRIC tabs: Live/Scorecard | Squad | Venue+H2H | Prediction.
    _tabs = TabController(length: 5, vsync: this);
    _playersFuture = ApiService().fetchPlayers();
    _venuesFuture = ApiService().fetchVenues();
    // NOTE: Cricsheet futures are lazy (getters above) — NOT
    // created here. Creating them in initState would parse the
    // 25 MB asset on every match open, even for Live / Scorecard.
    // AUTO-FETCH on open (was manual-Retry only): the list entry from
    // /currentMatches carries NO innings, so without this call every
    // live match opened with an empty scorecard. Non-force: respects
    // the 10-min live / 60-min completed cache, so re-opening the
    // same match costs no quota. Retry buttons use force: true.
    _refreshDetail(force: false);
  }

  /// Merge a fetched scorecard into the list entry: innings/scores
  /// from the detail win when non-empty; squad/venue/toss from
  /// whichever side has them. A wholesale replace would WIPE the
  /// list entry's squad ids (CricAPI /cricketScore returns no squad
  /// list), emptying the Squad tab that was already populated.
  static CricketMatch _mergeDetail(CricketMatch base, CricketMatch detail) {
    return CricketMatch(
      id: base.id,
      teamA: base.teamA,
      teamB: base.teamB,
      format: base.format,
      league: base.league,
      venueId: base.venueId,
      venueName:
          detail.venueName.isNotEmpty ? detail.venueName : base.venueName,
      startTime: base.startTime,
      status: detail.status,
      scores: detail.scores.isNotEmpty ? detail.scores : base.scores,
      result: detail.result.isNotEmpty ? detail.result : base.result,
      toss: detail.toss.isNotEmpty ? detail.toss : base.toss,
      squadA: base.squadA.isNotEmpty ? base.squadA : detail.squadA,
      squadB: base.squadB.isNotEmpty ? base.squadB : detail.squadB,
      innings: detail.innings.isNotEmpty ? detail.innings : base.innings,
      commentary:
          detail.commentary.isNotEmpty ? detail.commentary : base.commentary,
      currentBatter: detail.currentBatter.isNotEmpty
          ? detail.currentBatter
          : base.currentBatter,
      currentBowler: detail.currentBowler.isNotEmpty
          ? detail.currentBowler
          : base.currentBowler,
      lastBall:
          detail.lastBall.isNotEmpty ? detail.lastBall : base.lastBall,
      teamAWinsH2H: detail.teamAWinsH2H != 0
          ? detail.teamAWinsH2H
          : base.teamAWinsH2H,
      teamBWinsH2H: detail.teamBWinsH2H != 0
          ? detail.teamBWinsH2H
          : base.teamBWinsH2H,
      totalH2H:
          detail.totalH2H != 0 ? detail.totalH2H : base.totalH2H,
      source: detail.source.isNotEmpty ? detail.source : base.source,
      lastUpdated: detail.lastUpdated ?? base.lastUpdated,
      umpires: detail.umpires.isNotEmpty ? detail.umpires : base.umpires,
      matchReferee: detail.matchReferee.isNotEmpty
          ? detail.matchReferee
          : base.matchReferee,
      pitchReport: detail.pitchReport.isNotEmpty
          ? detail.pitchReport
          : base.pitchReport,
    );
  }

  /// Re-fetch this match's full detail (scorecard) on Retry.
  /// Never wipes the current match on failure — the last verified
  /// copy stays on screen with a SnackBar explaining the failure.
  Future<void> _refreshDetail({bool force = true}) async {
    if (_refreshingDetail) return;
    setState(() => _refreshingDetail = true);
    try {
      final fresh = await ApiService()
          .fetchMatchDetail(_match.id, forceRefresh: force);
      if (!mounted) return;
      if (fresh != null) {
        setState(() => _match = _mergeDetail(_match, fresh));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Could not refresh — showing last verified data.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Could not refresh — showing last verified data.')),
        );
      }
    } finally {
      if (mounted) setState(() => _refreshingDetail = false);
    }
  }

  /// Resolve a team's squad from the loaded player list.
  ///
  /// Fallback chain (never blank, never fake):
  /// 1. Official squad ids on the match (squadA / squadB).
  /// 2. Any loaded player whose team == [teamName].
  /// 3. Names from this match's scorecard for that team
  ///    (source 'scorecard' — stats not available, labelled so).
  /// Returns (players, sourceKey) where sourceKey is one of
  /// 'official' / 'team' / 'scorecard' / 'none'.
  (List<Player>, String) _resolveSquad(
      List<Player> all, List<String> ids, String teamName) {
    final byId = {for (final p in all) p.id: p};
    final out = <Player>[];
    final seen = <String>{};
    for (final id in ids) {
      final p = byId[id];
      if (p != null && seen.add(p.id)) out.add(p);
    }
    if (out.isNotEmpty) return (out, 'official');
    for (final p in all) {
      if (p.team == teamName && seen.add(p.id)) out.add(p);
    }
    if (out.isNotEmpty) return (out, 'team');
    // Scorecard-derived names for this team's innings.
    for (final inn in _match.innings) {
      if (inn.team != teamName) continue;
      for (final b in inn.batting) {
        final key = 'scorecard-${b.playerName}';
        if (!seen.add(key)) continue;
        out.add(Player(
          id: key,
          name: b.playerName,
          team: teamName,
          source: 'scorecard',
        ));
      }
      for (final b in inn.bowling) {
        final key = 'scorecard-${b.playerName}';
        if (!seen.add(key)) continue;
        out.add(Player(
          id: key,
          name: b.playerName,
          team: teamName,
          source: 'scorecard',
        ));
      }
    }
    if (out.isNotEmpty) return (out, 'scorecard');
    return (out, 'none');
  }

  String _squadSourceLabel(String sourceKey) {
    switch (sourceKey) {
      case 'cricsheet':
        return 'Squad: Real • Cricsheet • calculated from ball-by-ball '
            'data (2024–2026 dataset)';
      case 'official':
        return 'Squad: official squad list';
      case 'team':
        return 'Squad: from available player data for this team';
      case 'scorecard':
        return 'Squad: from scorecard names (full stats not available)';
      default:
        return 'Squad not available yet for this team.';
    }
  }

  /// CRICSHEET-WIRING: Cricsheet squads come FIRST. The old chain
  /// (official ids → mock team filter → scorecard names) meant every
  /// real match showed 2 Demo players + 0 for the other team,
  /// because CricAPI never supplies squads and the mock list only
  /// covers India/Pakistan stars. Cricsheet covers ~1,847 real
  /// players, so upcoming matches (no scorecard) get real squads
  /// too. Falls back to the old chain only when Cricsheet has zero
  /// players for that team.
  (List<Player>, String) _resolveSquadWithCricsheet(
      List<Player> all,
      Map<String, List<Player>> csSquads,
      List<String> ids,
      String teamName) {
    final cs = csSquads[teamName];
    if (cs != null && cs.isNotEmpty) return (cs, 'cricsheet');
    return _resolveSquad(all, ids, teamName);
  }

  /// Cross-squad Cricsheet matchups for the resolved squads.
  /// Returns [] when Cricsheet has no matchup data for these
  /// squads — the Venue tab then shows the honest no-data line
  /// (never falls back to mock matchups for Cricsheet squads).
  Future<List<Matchup>> _loadCricsheetMatchups() async {
    try {
      final all = await _playersFuture;
      final csSquads = await _squadsFuture;
      final (squadA, _) =
          _resolveSquadWithCricsheet(all, csSquads, _match.squadA, _match.teamA);
      final (squadB, _) =
          _resolveSquadWithCricsheet(all, csSquads, _match.squadB, _match.teamB);
      if (squadA.isEmpty && squadB.isEmpty) return [];
      return await ApiService().cricsheetCrossMatchups(squadA, squadB);
    } catch (_) {
      return [];
    }
  }

  /// Tap a name in the scorecard/squad → that player's profile
  /// (reference rule P12: no dead text).
  ///
  /// FIX-7: the old code hard-blocked scorecard players with a
  /// "Profile not available" SnackBar and never attempted a fetch.
  /// Now every tap goes through [ApiService.fetchPlayer], which
  /// resolves the name (Cricsheet first, then provider id lookup)
  /// and returns a real profile when one exists. Only when every
  /// source returns null does the SnackBar appear — and it says so
  /// honestly instead of pretending the player has no data.
  Future<void> _openPlayerByName(String name) async {
    // CRICSHEET-WIRING (resumed): fetch FIRST (Cricsheet-first,
    // offline, cached). The old order searched the local mock list
    // first, so tapping Babar / Shaheen / Virat / Rohit / Bumrah /
    // Surya opened the DEMO mock profile even though the Squad row
    // itself showed Real Cricsheet stats. Local list is only a
    // fallback when every source returns null.
    Player? found;
    try {
      found = await ApiService().fetchPlayer(name);
    } catch (_) {
      found = null;
    }
    if (found == null) {
      final players = await _playersFuture;
      final lower = name.toLowerCase();
      for (final p in players) {
        if (p.name.toLowerCase() == lower) {
          found = p;
          break;
        }
      }
      found ??= players.where((p) {
        final parts = lower.split(' ');
        return parts.isNotEmpty &&
            p.name.toLowerCase().contains(parts.last);
      }).firstOrNull;
    }
    if (!mounted) return;
    if (found == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Profile not available for $name yet.')),
      );
      return;
    }
    // Local copy: `found` is captured by the builder closure, so
    // promotion does not apply inside it.
    final profile = found;
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => PlayerProfileScreen(
                player: profile,
                opponent: _match.teamA == profile.team
                    ? _match.teamB
                    : _match.teamA,
                venueId: _match.venueId,
                format: _match.format)));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    return Scaffold(
      appBar: AppBar(
        // Fixture title: up to 2 lines, never mid-word cut (P5).
        // Body hero repeats it at 24px; the AppBar keeps it compact.
        title: Text(_match.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 17)),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: [
            Tab(text: lang.t('live')),
            Tab(text: lang.t('scorecard')),
            Tab(text: lang.t('squad')),
            Tab(text: lang.t('venue_h2h')),
            Tab(text: lang.t('prediction')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _liveTab(lang),
          _scorecardTab(lang),
          _squadTab(),
          _venueH2HTab(lang),
          _predictionTab(),
        ],
      ),
    );
  }

  // ---------------- LIVE ----------------

  Widget _liveTab(LanguageProvider lang) {
    final scoreA = _match.scoreOf(_match.teamA);
    final scoreB = _match.scoreOf(_match.teamB);
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // Hero live score — big, gold, animated.
        KingGradientCard(
          hero: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (_match.isEffectivelyLive) const LivePill(),
                  if (!_match.isEffectivelyLive)
                    GoldChip(
                        label: _match.isCompleted ? 'RESULT' : 'UPCOMING'),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('${_match.league} • ${_match.format}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(_match.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              if (_match.venueName.isNotEmpty)
                Text('📍 ${_match.venueName}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13)),
              if (_lastUpdatedLabel() != null) ...[
                const SizedBox(height: 6),
                Text(_lastUpdatedLabel()!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
              ],
              const SizedBox(height: 14),
              for (final s in _match.scores)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(s.team,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 16)),
                      ),
                      const SizedBox(width: 8),
                      Text(s.display,
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                              color: AppTheme.goldLight)),
                    ],
                  ),
                ),
              if (_match.result.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(_match.result,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppTheme.goldSoft,
                        fontWeight: FontWeight.w700)),
              ],
              if (_match.isEffectivelyLive) ...[
                const Divider(color: Colors.white12, height: 24),
                Text('Batting: ${_match.currentBatter}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 4),
                Text('Bowling: ${_match.currentBowler}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.textSecondary)),
                if (_match.lastBall.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Last ball: ',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.gold.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppTheme.gold.withValues(alpha: 0.5)),
                        ),
                        child: Text(_match.lastBall,
                            style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: AppTheme.goldLight)),
                      ),
                    ],
                  ),
                ],
              ],
              if (_match.toss.isNotEmpty) ...[
                const Divider(color: Colors.white12, height: 24),
                Text('🪙 ${_match.toss}',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ],
          ),
        ),
        if (scoreA != null && scoreB != null) ...[
          const PremiumSectionHeader(
              title: 'Target & Equation', icon: Icons.track_changes),
          KingGradientCard(
            child: Text(
              _equationText(scoreA, scoreB),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ],
        // Over-by-over momentum (partnership bars + FOW timeline,
        // from real scorecard data — never invented per-over runs).
        if (_match.innings.isNotEmpty)
          OverGraph(innings: _match.innings),
        // MATCH-CENTRIC: Team H2H lives in the Venue & H2H tab now,
        // not duplicated on Live.
        PremiumSectionHeader(
            title: lang.t('preview_info'), icon: Icons.info_outline),
        KingGradientCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoRow('Venue', _match.venueName),
              _infoRow('Format', _match.format),
              _infoRow('League', _match.league),
              _infoRow('Toss', _match.toss),
              if (_match.umpires.isNotEmpty)
                _infoRow('Umpires', _match.umpires),
              if (_match.matchReferee.isNotEmpty)
                _infoRow('Referee', _match.matchReferee),
              if (_match.pitchReport.isNotEmpty)
                _infoRow('Pitch', _match.pitchReport),
              _infoRow('Weather',
                  'Not available from free providers yet.'),
              const SizedBox(height: 8),
              Text(lang.t('disclaimer'),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 11)),
            ],
          ),
        ),
        const PremiumSectionHeader(
            title: 'Commentary', icon: Icons.chat_bubble_outline),
        for (final c in _match.commentary)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: AppTheme.premiumCard(radius: 12),
            padding: const EdgeInsets.all(12),
            child: Text(c,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13)),
          ),
        if (_match.commentary.isEmpty)
          Text(lang.isHindi
              ? 'कमेंट्री उपलब्ध नहीं है।'
              : 'No commentary available.'),
      ],
    );
  }

  /// Equation for a limited-overs chase, computed from structured
  /// totals/overs — never from a status string, never hardcoded to
  /// 20 overs.
  /// [scoreA] = first innings, [scoreB] = chasing innings.
  /// Test matches have no fixed target and can have 2 innings per
  /// team, so a first-innings "need" would be wrong: show every
  /// innings score instead.
  String _equationText(TeamScore first, TeamScore chasing) {
    if (!_match.isEffectivelyLive) {
      return '${_match.teamA} ${first.runs}/${first.wickets} • ${_match.teamB} ${chasing.runs}/${chasing.wickets}';
    }
    if (_match.format == 'Test' || _match.scores.length > 2) {
      return _match.scores
          .map((s) => '${s.team} ${s.runs}/${s.wickets}')
          .join(' • ');
    }
    const totalOvers = {'T20': 20.0, 'T10': 10.0, 'ODI': 50.0};
    final limit = totalOvers[_match.format];
    final need = first.runs + 1 - chasing.runs;
    if (need <= 0) {
      return _match.result.isNotEmpty
          ? _match.result
          : '${_match.teamB} need $need runs';
    }
    if (limit == null) {
      return '${_match.teamB} need $need runs (Test — no ball limit)';
    }
    final ballsBowled = ballsFromCricketOvers(chasing.overs);
    final ballsLeft = (limit * 6).round() - ballsBowled;
    if (ballsLeft <= 0) return '${_match.teamB} need $need runs';
    return '${_match.teamB} need $need runs from $ballsLeft balls • $need to win';
  }

  /// Run rate of an innings from structured totals + cricket overs.
  /// 0 balls bowled -> "0.00", never NaN / Infinity.
  String _runRate(Innings inn) {
    final balls = ballsFromCricketOvers(inn.overs);
    if (balls <= 0) return '0.00';
    return (inn.total * 6 / balls).toStringAsFixed(2);
  }

  /// "Last updated HH:MM" — shown only when the match carries a
  /// timestamp. Never a fake timestamp.
  String? _lastUpdatedLabel() {
    final lu = _match.lastUpdated;
    if (lu == null) return null;
    final hh = lu.hour.toString().padLeft(2, '0');
    final mm = lu.minute.toString().padLeft(2, '0');
    return 'Last updated $hh:$mm';
  }

  Widget _infoRow(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 82,
            child: Text(label,
                style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: Text(value,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // ---------------- FULL SCORECARD ----------------

  Widget _scorecardTab(LanguageProvider lang) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // Match context header — always visible on scorecard.
        KingGradientCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_match.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(
                  '${_match.league} • ${_match.format} • ${_match.venueName}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12)),
              if (_lastUpdatedLabel() != null) ...[
                const SizedBox(height: 4),
                Text(_lastUpdatedLabel()!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
              ],
              if (_match.toss.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('🪙 ${_match.toss}',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
              ],
              if (_match.umpires.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('Umpires: ${_match.umpires}',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ],
          ),
        ),
        for (final inn in _match.innings) ...[
          PremiumSectionHeader(
            title: '${inn.team} — ${inn.total}/${inn.wickets}',
            subtitle:
                '${formatCricketOvers(inn.overs)} overs • Innings ${inn.inningsNumber} • RR ${_runRate(inn)}',
            icon: Icons.sports_cricket,
          ),
          _battingTable(inn),
          const SizedBox(height: 10),
          _extrasRow(inn),
          const SizedBox(height: 12),
          _bowlingTable(inn),
          const SizedBox(height: 12),
          _fallOfWickets(inn),
          _partnerships(inn),
          _yetToBat(inn),
          if (inn.didNotBatNote.isNotEmpty) ...[
            const SizedBox(height: 8),
            KingGradientCard(
              child: Text(inn.didNotBatNote,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12)),
            ),
          ],
        ],
        if (_match.innings.isEmpty)
          KingGradientCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lang.t('scorecard_empty'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 6),
                Text(
                    lang.isHindi
                        ? 'यह मैच अभी शुरू नहीं हुआ है या प्रोवाइडर ने स्कोरकार्ड नहीं भेजा है।'
                        : 'This match has not started yet, or the provider has not sent a scorecard for it.',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13)),
                if (_lastUpdatedLabel() != null) ...[
                  const SizedBox(height: 6),
                  Text(_lastUpdatedLabel()!,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12)),
                ],
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _refreshingDetail ? null : _refreshDetail,
                  icon: _refreshingDetail
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child:
                              CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh, size: 18),
                  label: Text(lang.t('retry')),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _battingTable(Innings inn) {
    return KingGradientCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.gold.withValues(alpha: 0.14),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
            ),
            child: const Row(
              children: [
                Text('BATTING',
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: AppTheme.goldLight)),
                Spacer(),
                Text('Full card — tap a batter for profile',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 720,
              child: Column(
                children: [
                  const ScoreRow(
                    cells: [
                      SizedBox(
                          width: 190,
                          child: Text('BATTER',
                              style: TextStyle(
                                  color: AppTheme.goldLight,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900))),
                      ScoreHeaderCell('R', width: 52),
                      ScoreHeaderCell('B', width: 52),
                      ScoreHeaderCell('4s', width: 44),
                      ScoreHeaderCell('6s', width: 44),
                      ScoreHeaderCell('SR', width: 64),
                    ],
                  ),
                  for (final b in inn.batting)
                    ScoreRow(
                      highlighted: b.notOut,
                      cells: [
                        SizedBox(
                          width: 190,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // P12: every player name is tappable.
                              InkWell(
                                onTap: () =>
                                    _openPlayerByName(b.playerName),
                                child: Text(
                                  b.playerName +
                                      (b.notOut ? ' *' : ''),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: AppTheme.goldLight,
                                      decoration:
                                          TextDecoration.underline),
                                ),
                              ),
                              if (dismissalLabel(b).isNotEmpty)
                                Text(dismissalLabel(b),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: b.notOut
                                            ? AppTheme.goldLight
                                            : AppTheme.textSecondary,
                                        fontSize: 11,
                                        fontWeight: b.notOut
                                            ? FontWeight.w700
                                            : FontWeight.normal)),
                            ],
                          ),
                        ),
                        SizedBox(
                            width: 52,
                            child: Text('${b.runs}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                    color: AppTheme.goldLight))),
                        SizedBox(
                            width: 52,
                            child: Text('${b.balls}',
                                textAlign: TextAlign.right)),
                        SizedBox(
                            width: 44,
                            child: Text('${b.fours}',
                                textAlign: TextAlign.right)),
                        SizedBox(
                            width: 44,
                            child: Text('${b.sixes}',
                                textAlign: TextAlign.right)),
                        SizedBox(
                            width: 64,
                            child: Text(b.strikeRate.toStringAsFixed(1),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700))),
                      ],
                    ),
                  // Total row
                  Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.gold.withValues(alpha: 0.12),
                      border: Border(
                        top: BorderSide(
                            color:
                                AppTheme.gold.withValues(alpha: 0.4)),
                      ),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 190,
                          child: Text('TOTAL',
                              style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.goldLight)),
                        ),
                        SizedBox(
                            width: 52,
                            child: Text('${inn.total}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.goldLight))),
                        const SizedBox(width: 52),
                        const SizedBox(width: 44),
                        const SizedBox(width: 44),
                        SizedBox(
                            width: 64,
                            child: Text(
                                '${inn.wickets} wkts',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text('↔ Swipe table sideways to see all columns (R / B / 4s / 6s / SR)',
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _extrasRow(Innings inn) {
    final extrasLabel = inn.extrasText.isEmpty
        ? 'Extras: ${inn.extrasRuns}'
        : 'Extras: ${inn.extrasText}';
    return KingGradientCard(
      child: Row(
        children: [
          const Icon(Icons.add_circle_outline,
              size: 18, color: AppTheme.goldLight),
          const SizedBox(width: 8),
          Expanded(
            child: Text(extrasLabel,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          GoldChip(label: 'Total ${inn.total}/${inn.wickets}'),
        ],
      ),
    );
  }

  Widget _bowlingTable(Innings inn) {
    return KingGradientCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.blue.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
            ),
            child: const Row(
              children: [
                Text('BOWLING',
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: AppTheme.goldLight)),
                Spacer(),
                Text('O • M • R • W • Econ • Wd • Nb',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 720,
              child: Column(
                children: [
                  const ScoreRow(
                    cells: [
                      SizedBox(
                          width: 190,
                          child: Text('BOWLER',
                              style: TextStyle(
                                  color: AppTheme.goldLight,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900))),
                      ScoreHeaderCell('O', width: 52),
                      ScoreHeaderCell('M', width: 44),
                      ScoreHeaderCell('R', width: 52),
                      ScoreHeaderCell('W', width: 44),
                      ScoreHeaderCell('Econ', width: 64),
                      ScoreHeaderCell('Wd', width: 44),
                      ScoreHeaderCell('Nb', width: 44),
                    ],
                  ),
                  for (final b in inn.bowling)
                    ScoreRow(
                      cells: [
                        SizedBox(
                          width: 190,
                          child: InkWell(
                            onTap: () =>
                                _openPlayerByName(b.playerName),
                            child: Text(b.playerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: AppTheme.goldLight,
                                    decoration:
                                        TextDecoration.underline)),
                          ),
                        ),
                        SizedBox(
                            width: 52,
                            child: Text(formatCricketOvers(b.overs),
                                textAlign: TextAlign.right)),
                        SizedBox(
                            width: 44,
                            child: Text('${b.maidens}',
                                textAlign: TextAlign.right)),
                        SizedBox(
                            width: 52,
                            child: Text('${b.runsConceded}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700))),
                        SizedBox(
                            width: 44,
                            child: Text('${b.wickets}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.goldLight))),
                        SizedBox(
                            width: 64,
                            child: Text(displayEconomy(b).toStringAsFixed(2),
                                textAlign: TextAlign.right)),
                        SizedBox(
                            width: 44,
                            child: Text('${b.wides}',
                                textAlign: TextAlign.right)),
                        SizedBox(
                            width: 44,
                            child: Text('${b.noBalls}',
                                textAlign: TextAlign.right)),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text('↔ Swipe sideways for Econ / Wd / Nb',
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _fallOfWickets(Innings inn) {
    if (inn.fallOfWickets.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PremiumSectionHeader(
            title: 'Fall of Wickets', icon: Icons.trending_down),
        KingGradientCard(
          child: Column(
            children: [
              for (int i = 0; i < inn.fallOfWickets.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppTheme.red.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppTheme.red.withValues(alpha: 0.5)),
                        ),
                        child: Text('${i + 1}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(stripFowPrefix(inn.fallOfWickets[i]),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _partnerships(Innings inn) {
    if (inn.partnerships.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PremiumSectionHeader(
            title: 'Partnerships', icon: Icons.group_outlined),
        KingGradientCard(
          child: Column(
            children: [
              for (final p in inn.partnerships)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.handshake_outlined,
                          size: 16, color: AppTheme.goldLight),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(p,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _yetToBat(Innings inn) {
    if (inn.yetToBat.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PremiumSectionHeader(
            title: 'Yet to Bat', icon: Icons.hourglass_top),
        KingGradientCard(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final name in inn.yetToBat) GoldChip(label: name),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------- SQUAD / PREDICTION ----------------

  Widget _squadTab() {
    return FutureBuilder(
      future: Future.wait([_playersFuture, _squadsFuture]),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError || !snap.hasData) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Could not load squad data.',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => setState(() {}),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        final all = snap.data![0] as List<Player>;
        final csSquads =
            snap.data![1] as Map<String, List<Player>>;
        // MATCH-CENTRIC squad: Team A / Team B, Cricsheet FIRST,
        // then the old fallback chain (official ids → team filter
        // → scorecard names). Never one flat list, never blank,
        // never fake stats — every row carries this match's context.
        final (squadA, srcA) = _resolveSquadWithCricsheet(
            all, csSquads, _match.squadA, _match.teamA);
        final (squadB, srcB) = _resolveSquadWithCricsheet(
            all, csSquads, _match.squadB, _match.teamB);
        Widget teamSection(String team, List<Player> squad,
            String opponent, String srcKey) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PremiumSectionHeader(
                title: '$team — Squad (${squad.length})',
                icon: Icons.groups_outlined,
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(_squadSourceLabel(srcKey),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
              ),
              if (squad.isEmpty)
                const Text(
                    'Squad not available yet for this team.',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13)),
              for (final p in squad)
                SquadPlayerCard(
                  player: p,
                  opponent: opponent,
                  format: _match.format,
                  // FIX-7: no hard-block for scorecard rows. Every
                  // tap routes through _openPlayerByName, which
                  // fetches the profile (Cricsheet -> provider id
                  // lookup) instead of refusing outright. Rows with
                  // no stats yet show "Tap for profile" in the card.
                  onTap: () => _openPlayerByName(p.name),
                ),
            ],
          );
        }

        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            const PremiumSectionHeader(
                title: 'Squad — tap a player for full profile',
                icon: Icons.groups_outlined),
            teamSection(_match.teamA, squadA, _match.teamB, srcA),
            teamSection(_match.teamB, squadB, _match.teamA, srcB),
            if (squadA.isEmpty && squadB.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Squad data will appear once the free API '
                        'returns squads for this match.'),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _refreshDetail,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  // ---------------- VENUE + H2H ----------------

  Widget _venueH2HTab(LanguageProvider lang) {
    return FutureBuilder(
      future: Future.wait([
        _playersFuture,
        _venuesFuture,
        _squadsFuture,
        _h2hFuture,
        _venueFuture,
        _matchupsFuture,
      ]),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError || !snap.hasData) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Could not load venue & H2H data.',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => setState(() {}),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: Text(lang.t('retry')),
                  ),
                ],
              ),
            ),
          );
        }
        final all = snap.data![0] as List<Player>;
        final venues = snap.data![1] as List<Venue>;
        final csSquads =
            snap.data![2] as Map<String, List<Player>>;
        final csH2H = snap.data![3] as Map<String, int>;
        final csVenue = snap.data![4] as VenueStats?;
        final csMatchups = snap.data![5] as List<Matchup>;
        final venue = venues.where((v) =>
            (_match.venueId.isNotEmpty && v.id == _match.venueId) ||
            (v.name.isNotEmpty && v.name == _match.venueName)).firstOrNull;
        // CRICSHEET-WIRING: same Cricsheet-first squads as the
        // Squad tab, so H2H / matchups never see the 2-Demo + 0
        // squads the old chain produced for real matches.
        final (squadA, srcA) = _resolveSquadWithCricsheet(
            all, csSquads, _match.squadA, _match.teamA);
        final (squadB, srcB) = _resolveSquadWithCricsheet(
            all, csSquads, _match.squadB, _match.teamB);
        final fromCricsheet =
            srcA == 'cricsheet' || srcB == 'cricsheet';
        // Matchups: Cricsheet squads -> Cricsheet matchups ONLY
        // (mock players' stored matchups would be Demo data
        // wearing a real match's clothes). Mock squads -> the old
        // topPlayerMatchups over stored lists.
        final matchups = fromCricsheet
            ? csMatchups
            : topPlayerMatchups(squadA, squadB);
        // H2H: Cricsheet computed numbers win when the dataset has
        // any meeting between these teams; otherwise the match's
        // own (provider) values, which are 0 when unknown.
        final csH2HMatches = csH2H['matches'] ?? 0;
        final h2hWinsA =
            csH2HMatches > 0 ? (csH2H['teamAWins'] ?? 0) : _match.teamAWinsH2H;
        final h2hWinsB =
            csH2HMatches > 0 ? (csH2H['teamBWins'] ?? 0) : _match.teamBWinsH2H;
        final h2hTotal =
            csH2HMatches > 0 ? csH2HMatches : _match.totalH2H;
        // Venue: provider card only when it actually carries
        // stats; otherwise the Cricsheet computed card; otherwise
        // the honest no-data line.
        final providerVenueHasStats = venue != null &&
            (venue.totalMatches > 0 || venue.pitchType.isNotEmpty);

        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            PremiumSectionHeader(
                title: lang.t('venue_stats'), icon: Icons.stadium_outlined),
            KingGradientCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      _match.venueName.isNotEmpty
                          ? _match.venueName
                          : 'Venue not announced yet',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 18)),
                  const SizedBox(height: 4),
                  // `venue != null` here is for type promotion —
                  // providerVenueHasStats already implies it.
                  if (venue != null && providerVenueHasStats) ...[
                    Text('${venue.city}, ${venue.country}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 13)),
                    const SizedBox(height: 10),
                    _venueStatRow('Pitch',
                        venue.pitchType.isNotEmpty ? venue.pitchType : '—'),
                    _venueStatRow('Avg 1st innings',
                        venue.avgFirstInningsScore > 0
                            ? venue.avgFirstInningsScore.toStringAsFixed(0)
                            : '—'),
                    _venueStatRow('Avg 2nd innings',
                        venue.avgSecondInningsScore > 0
                            ? venue.avgSecondInningsScore.toStringAsFixed(0)
                            : '—'),
                    _venueStatRow('Matches at venue',
                        venue.totalMatches > 0
                            ? '${venue.totalMatches}'
                            : '—'),
                    _venueStatRow('Bat-first wins',
                        venue.batFirstWinPct > 0
                            ? '${venue.batFirstWinPct.toStringAsFixed(0)}%'
                            : '—'),
                    if (venue.tossAdvice.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Toss: ${venue.tossAdvice}',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13)),
                    ],
                  ] else if (csVenue != null) ...[
                    // CRICSHEET-WIRING: computed from bundled
                    // matches at this venue. Pitch / weather are
                    // not in Cricsheet — those rows below stay
                    // "Not available from free providers yet".
                    if (csVenue.city.isNotEmpty)
                      Text(csVenue.city,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13)),
                    const SizedBox(height: 10),
                    _venueStatRow('Avg 1st innings',
                        csVenue.avgFirstInnings.toStringAsFixed(0)),
                    _venueStatRow('Avg 2nd innings',
                        csVenue.avgSecondInnings.toStringAsFixed(0)),
                    _venueStatRow(
                        'Matches at venue', '${csVenue.matches}'),
                    _venueStatRow('Highest total',
                        '${csVenue.highestTotal}'),
                    _venueStatRow('Bat-first wins',
                        '${csVenue.batFirstWinPct.toStringAsFixed(0)}%'),
                    const SizedBox(height: 8),
                    const Text(
                        'Real • Cricsheet (2024–2026 dataset)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: AppTheme.goldSoft, fontSize: 12)),
                  ] else ...[
                    const SizedBox(height: 6),
                    Text(lang.t('venue_no_data'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 13)),
                  ],
                  const SizedBox(height: 10),
                  _venueStatRow(
                      'Pitch (match)',
                      _match.pitchReport.isNotEmpty
                          ? _match.pitchReport
                          : 'Not available from free providers yet.'),
                  _venueStatRow('Weather',
                      'Not available from free providers yet.'),
                  _venueStatRow('Toss',
                      _match.toss.isNotEmpty ? _match.toss : '—'),
                ],
              ),
            ),
            // H2HCard carries its own 'Head-to-Head' title — no
            // duplicate section header above it.
            H2HCard(
              teamA: _match.teamA,
              teamB: _match.teamB,
              winsA: h2hWinsA,
              winsB: h2hWinsB,
              total: h2hTotal,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 10),
              child: Text(
                  csH2HMatches > 0
                      ? 'Real • Cricsheet (2024–2026 dataset)'
                      : h2hTotal > 0
                          ? 'Source: ${_match.source.isNotEmpty ? _match.source : 'provider'}'
                          : lang.t('no_h2h_data'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12)),
            ),
            PremiumSectionHeader(
                title: lang.t('player_matchups'),
                icon: Icons.sports_cricket),
            if (matchups.isEmpty)
              Text(lang.t('no_matchups_data'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13))
            else
              for (final m in matchups)
                KingGradientCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${m.bowlerName} → ${m.batterName}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14)),
                            const SizedBox(height: 2),
                            Text(
                                '${m.dismissals} dismissal${m.dismissals == 1 ? '' : 's'} in ${m.balls} balls • ${m.runs} runs',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                      GoldChip(label: '${m.dismissals}w'),
                    ],
                  ),
                ),
          ],
        );
      },
    );
  }

  Widget _venueStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: Text(value,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _predictionTab() {
    return FutureBuilder(
      future: Future.wait([_playersFuture, _squadsFuture]),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError || !snap.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Could not load prediction data.',
                  textAlign: TextAlign.center),
            ),
          );
        }
        final all = snap.data![0] as List<Player>;
        final csSquads =
            snap.data![1] as Map<String, List<Player>>;
        // MATCH-CENTRIC: predictions use the same resolved squads as
        // the Squad tab (Cricsheet first) — never an empty list when
        // the Squad tab has players (scorecard fallback included).
        final (squadA, _) = _resolveSquadWithCricsheet(
            all, csSquads, _match.squadA, _match.teamA);
        final (squadB, _) = _resolveSquadWithCricsheet(
            all, csSquads, _match.squadB, _match.teamB);
        final squad = [...squadA, ...squadB];
        final preds = squad
            .where((p) => p.source != 'scorecard')
            .map((p) => PredictionEngine.predict(
                  player: p,
                  opponent: _match.teamA == p.team
                      ? _match.teamB
                      : _match.teamA,
                  venueId: _match.venueId,
                  format: _match.format,
                ))
            .toList()
          ..sort((a, b) => b.score.compareTo(a.score));
        // hasData guard: players with NO signal get an honest
        // "Not enough data" row, never a fake ~50 score card.
        final withData = preds.where((p) => p.hasData).toList();
        final noData = preds.where((p) => !p.hasData).toList();
        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            const PremiumSectionHeader(
                title: 'Who will fire? — King Prediction',
                subtitle: 'Form + vs Opponent + Venue + Matchup + Pitch',
                icon: Icons.psychology_outlined),
            if (preds.isEmpty)
              const Text(
                'No squad data for this match yet — predictions will appear once squads load.',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13),
              ),
            for (final pr in withData) PredictionCard(prediction: pr),
            if (noData.isNotEmpty) ...[
              const SizedBox(height: 8),
              const PremiumSectionHeader(
                  title: 'Not enough data',
                  icon: Icons.hourglass_top),
              for (final pr in noData)
                KingGradientCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(pr.playerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800)),
                      ),
                      const Text('Not enough data to predict.',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12)),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 12),
            const Text(
              'For information & entertainment only. Not betting advice. '
              'Prediction is a model, not a guarantee.',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 11),
            ),
          ],
        );
      },
    );
  }
}
