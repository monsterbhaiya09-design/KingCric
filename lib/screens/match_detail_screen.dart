import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/innings.dart';
import '../models/match.dart';
import '../services/api_service.dart';
import '../services/prediction_engine.dart';
import '../utils/app_theme.dart';
import '../utils/strings.dart';
import '../models/player.dart';
import '../widgets/h2h_card.dart';
import '../widgets/over_graph.dart';
import '../widgets/player_card.dart';
import '../widgets/prediction_card.dart';
import '../widgets/premium_widgets.dart';
import 'player_profile_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _match = widget.match;
    _tabs = TabController(length: 4, vsync: this);
    _playersFuture = ApiService().fetchPlayers();
  }

  /// Tap a name in the scorecard/squad → that player's profile
  /// (reference rule P12: no dead text). Matches by exact name, then
  /// by first/last name, then by "contains". If no player exists in
  /// the loaded list, a SnackBar says so — never a silent dead tap.
  Future<void> _openPlayerByName(String name) async {
    final players = await _playersFuture;
    Player? found;
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
    if (!mounted) return;
    if (found == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Profile not available for $name yet.')),
      );
      return;
    }
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => PlayerProfileScreen(player: found!)));
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
        H2HCard(
          teamA: _match.teamA,
          teamB: _match.teamB,
          winsA: _match.teamAWinsH2H,
          winsB: _match.teamBWinsH2H,
          total: _match.totalH2H,
        ),
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
          Text(lang.isHindi
              ? 'स्कोरकार्ड अभी उपलब्ध नहीं है।'
              : 'Scorecard not available yet.'),
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
      future: _playersFuture,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final all = snap.data!;
        // Squad is split Team A / Team B (reference spec §4.2) — never
        // one flat list: the user must see at a glance who plays for
        // whom, with the match context (vs opponent • format) on
        // every row.
        final squadA =
            all.where((p) => _match.squadA.contains(p.id)).toList();
        final squadB =
            all.where((p) => _match.squadB.contains(p.id)).toList();
        Widget teamSection(String team, List<Player> squad,
            String opponent) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PremiumSectionHeader(
                title: '$team — Squad (${squad.length})',
                icon: Icons.groups_outlined,
              ),
              if (squad.isEmpty)
                const Text(
                    'Squad not available yet for this team.',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13)),
              for (final p in squad)
                PlayerCard(
                  player: p,
                  contextLine: 'vs $opponent • ${_match.format}',
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => PlayerProfileScreen(
                              player: p,
                              opponent: opponent,
                              venueId: _match.venueId,
                              format: _match.format))),
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
            teamSection(_match.teamA, squadA, _match.teamB),
            teamSection(_match.teamB, squadB, _match.teamA),
            if (squadA.isEmpty && squadB.isEmpty)
              const Text('Squad data will appear once the free API '
                  'returns squads for this match.'),
          ],
        );
      },
    );
  }

  Widget _predictionTab() {
    return FutureBuilder(
      future: _playersFuture,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final all = snap.data!;
        final squadIds = {..._match.squadA, ..._match.squadB};
        final squad =
            all.where((p) => squadIds.contains(p.id)).toList();
        final preds = squad
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
        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            const PremiumSectionHeader(
                title: 'Who will fire? — King Prediction',
                subtitle: 'Form + vs Opponent + Venue + Matchup + Pitch',
                icon: Icons.psychology_outlined),
            for (final pr in preds) PredictionCard(prediction: pr),
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
