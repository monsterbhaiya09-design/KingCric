import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/player.dart';
import '../services/api_service.dart';
import '../services/prediction_engine.dart';
import '../utils/app_theme.dart';
import '../utils/strings.dart';
import '../widgets/prediction_card.dart';
import '../widgets/premium_widgets.dart';
import '../widgets/stat_card.dart';

/// V2 Player profile — PREMIUM: gradient hero, avatar, stat bars,
/// full tables with horizontal scroll, no overflow.
class PlayerProfileScreen extends StatelessWidget {
  final Player player;
  final String? opponent;
  final String? venueId;
  final String? format;
  const PlayerProfileScreen(
      {super.key,
      required this.player,
      this.opponent,
      this.venueId,
      this.format});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final overall = player.battingOverall();
    final vsOpp =
        opponent != null ? player.battingVs(opponent!) : null;
    final fmt = format != null ? player.battingInFormat(format!) : null;
    final bowlingOverall = player.bowlingOverall();
    return Scaffold(
      appBar: AppBar(
          title: Text(player.name,
              maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // Premium hero
          Container(
            decoration: AppTheme.heroCard(),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    KingAvatar(name: player.name, radius: 34),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(player.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900)),
                          const SizedBox(height: 3),
                          // Identity: only non-empty parts, joined —
                          // never a trailing "•" when team/country is missing.
                          Builder(builder: (_) {
                            final parts = [
                              player.role,
                              player.team,
                              player.country
                            ].where((s) => s.trim().isNotEmpty).toList();
                            if (parts.isEmpty) return const SizedBox.shrink();
                            return Text(parts.join(' • '),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 13));
                          }),
                          const SizedBox(height: 3),
                          // Styles: hidden entirely when both are empty —
                          // never "Batting:  • Bowling: ".
                          Builder(builder: (_) {
                            final parts = <String>[];
                            if (player.battingStyle.trim().isNotEmpty) {
                              parts.add('Batting: ${player.battingStyle}');
                            }
                            if (player.bowlingStyle.trim().isNotEmpty) {
                              parts.add('Bowling: ${player.bowlingStyle}');
                            }
                            if (parts.isEmpty) return const SizedBox.shrink();
                            return Text(parts.join(' • '),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12));
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // ONE source line, directly under the hero identity
                // (spec P-P2). Never a bare "Complete": Cricsheet
                // states its dataset size, demo says Demo, anything
                // else is Partial — a curated number is never
                // presented as a verified full career.
                Builder(builder: (_) {
                  final isReal = player.source == 'cricsheet';
                  final isDemo = player.source == 'demo';
                  final label = isReal
                      ? (player.sourceMatches > 0
                          ? 'Real • Cricsheet open data • ${player.sourceMatches} matches in dataset'
                          : 'Real • Cricsheet open data')
                      : isDemo
                          ? 'Demo data — curated sample, not live-verified'
                          : 'Partial • provider basic profile — not fully verified';
                  final icon = isReal
                      ? Icons.verified
                      : isDemo
                          ? Icons.sports_cricket
                          : Icons.hourglass_top;
                  final color = isReal ? AppTheme.green : AppTheme.amber;
                  return Row(
                    children: [
                      Icon(icon, size: 16, color: color),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                  );
                }),
                const SizedBox(height: 12),
                // Hero quick stats — always visible, no truncation.
                Row(
                  children: [
                    Expanded(
                        child: _heroStat('Runs', '${overall.runs}')),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _heroStat(
                            'Avg',
                            overall.matches == 0
                                ? '—'
                                : overall.average.toStringAsFixed(1))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _heroStat(
                            'SR',
                            overall.matches == 0
                                ? '—'
                                : overall.strikeRate.toStringAsFixed(1))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _heroStat(
                            'Wkts', '${bowlingOverall.wickets}')),
                  ],
                ),
              ],
            ),
          ),
          // Match context: prediction when opened from a match
          // (opponent known). Venue is optional — an empty venueId
          // just scores the venue input as "no data", never crashes.
          if (opponent != null) ...[
            const PremiumSectionHeader(
                title: 'Who will fire? — King Prediction',
                subtitle:
                    'Form + vs Opponent + Venue + Matchup + Pitch • Model, not a guarantee',
                icon: Icons.psychology_outlined),
            PredictionCard(
                prediction: PredictionEngine.predict(
                    player: player,
                    opponent: opponent!,
                    venueId: venueId ?? '',
                    format: format ?? 'T20')),
          ],
          const PremiumSectionHeader(
              title: 'Overall — All Formats',
              subtitle: 'Career totals, every format combined',
              icon: Icons.emoji_events),
          _grid([
            StatCard(
                label: lang.t('runs'),
                value: '${overall.runs}',
                barFraction: (overall.runs / 15000).clamp(0.0, 1.0)),
            // No matches => '—', never "0.0": an average / strike
            // rate over zero innings is undefined, not zero.
            StatCard(
                label: lang.t('average'),
                value: overall.matches == 0
                    ? '—'
                    : overall.average.toStringAsFixed(1),
                barFraction: overall.matches == 0
                    ? 0.0
                    : (overall.average / 60).clamp(0.0, 1.0)),
            StatCard(
                label: lang.t('strike_rate'),
                value: overall.matches == 0
                    ? '—'
                    : overall.strikeRate.toStringAsFixed(1),
                barFraction: overall.matches == 0
                    ? 0.0
                    : (overall.strikeRate / 180).clamp(0.0, 1.0)),
            StatCard(
                label: lang.t('hundreds'),
                value: '${overall.hundreds}',
                sub: '${overall.fifties} ${lang.t('fifties')}'),
          ]),
          // Stat bars — visual, not just numbers.
          const SizedBox(height: 12),
          KingGradientCard(
            child: Column(
              children: [
                StatBar(
                    label: 'Runs',
                    value: '${overall.runs}',
                    fraction: (overall.runs / 15000).clamp(0.0, 1.0)),
                StatBar(
                    label: 'Average ( / 60)',
                    value: overall.matches == 0
                        ? '—'
                        : overall.average.toStringAsFixed(1),
                    fraction: overall.matches == 0
                        ? 0.0
                        : (overall.average / 60).clamp(0.0, 1.0),
                    color: AppTheme.blue),
                StatBar(
                    label: 'Strike Rate ( / 180)',
                    value: overall.matches == 0
                        ? '—'
                        : overall.strikeRate.toStringAsFixed(1),
                    fraction: overall.matches == 0
                        ? 0.0
                        : (overall.strikeRate / 180).clamp(0.0, 1.0),
                    color: AppTheme.green),
                StatBar(
                    label: 'Boundaries (4s + 6s)',
                    value: '${overall.fours + overall.sixes}',
                    fraction:
                        ((overall.fours + overall.sixes) / 1500)
                            .clamp(0.0, 1.0),
                    color: AppTheme.amber),
              ],
            ),
          ),
          // vs Opponent: hidden when there is no data for this
          // opponent (matches == 0) — no silent 0/0/0 rows (G2).
          if (vsOpp != null && vsOpp.matches > 0) ...[
            PremiumSectionHeader(
                title: '${lang.t('vs_opponent')} — $opponent',
                icon: Icons.sports_cricket),
            _grid([
              StatCard(label: lang.t('runs'), value: '${vsOpp.runs}'),
              StatCard(
                  label: lang.t('average'),
                  value: vsOpp.average.toStringAsFixed(1)),
              StatCard(
                  label: lang.t('strike_rate'),
                  value: vsOpp.strikeRate.toStringAsFixed(1)),
              StatCard(label: 'Matches', value: '${vsOpp.matches}'),
            ]),
            if ((player.bowlingVsOpponent[opponent]?.wickets ?? 0) > 0)
              _tableRow(
                  'Bowling vs $opponent',
                  '${player.bowlingVsOpponent[opponent]!.wickets} wkts • Econ ${player.bowlingVsOpponent[opponent]!.economy.toStringAsFixed(2)} • Avg ${player.bowlingVsOpponent[opponent]!.average.toStringAsFixed(1)}'),
          ],
          if (fmt != null && fmt.matches > 0) ...[
            PremiumSectionHeader(
                title: '${lang.t('format_wise')} — $format',
                icon: Icons.category_outlined),
            _grid([
              StatCard(label: lang.t('runs'), value: '${fmt.runs}'),
              StatCard(
                  label: lang.t('average'),
                  value: fmt.average.toStringAsFixed(1)),
              StatCard(
                  label: lang.t('strike_rate'),
                  value: fmt.strikeRate.toStringAsFixed(1)),
              StatCard(label: 'Matches', value: '${fmt.matches}'),
            ]),
            if ((player.bowlingByFormat[format]?.wickets ?? 0) > 0)
              _tableRow(
                  'Bowling • $format',
                  '${player.bowlingByFormat[format]!.wickets} wkts • Econ ${player.bowlingByFormat[format]!.economy.toStringAsFixed(2)} • Avg ${player.bowlingByFormat[format]!.average.toStringAsFixed(1)}'),
          ],
          const PremiumSectionHeader(
              title: 'All Formats — Full Table',
              subtitle: 'Swipe sideways to see every column',
              icon: Icons.table_chart_outlined),
          // Batting + Bowling tables with format chips (spec §4.3:
          // Bowling by Format sits right after Batting, not at the
          // bottom of the screen).
          _FormatTables(player: player),
          if (player.battingByLeague.isNotEmpty) ...[
            const PremiumSectionHeader(
                title: 'Leagues', icon: Icons.emoji_events_outlined),
            for (final e in player.battingByLeague.entries)
              _tableRow(e.key,
                  '${e.value.runs} runs • Avg ${e.value.average.toStringAsFixed(1)} • SR ${e.value.strikeRate.toStringAsFixed(1)}'),
          ],
          if (player.battingByVenue.isNotEmpty) ...[
            PremiumSectionHeader(
                title: lang.t('venue'),
                subtitle: 'Venue records per player',
                icon: Icons.stadium_outlined),
            for (final e in player.battingByVenue.entries)
              _tableRow(e.key,
                  '${e.value.runs} runs • Avg ${e.value.average.toStringAsFixed(1)} • SR ${e.value.strikeRate.toStringAsFixed(1)}'),
          ],
          // Recent Form: hidden when empty — no header for
          // a section with no rows (spec P-P3).
          if (player.recentForm.isNotEmpty) ...[
            PremiumSectionHeader(
                title: lang.t('recent_form'), icon: Icons.show_chart),
            for (final f in player.recentForm)
              _tableRow(
                  f.matchLabel,
                  '${f.opponent} • ${f.format} • ${f.result} • ${f.wickets > 0 ? '${f.wickets} wkts' : '${f.runs} (${f.balls})'}'),
          ],
          if (player.matchups.isNotEmpty) ...[
            PremiumSectionHeader(
                title: lang.t('matchup'),
                subtitle: 'Tap a bowler to open their profile',
                icon: Icons.compare_arrows),
            for (final m in player.matchups)
              _tappableRow(
                context,
                'vs ${m.bowlerName}',
                '${m.matches} matches • ${m.dismissals} dismissals • ${m.runs} runs / ${m.balls} balls • SR ${m.strikeRate.toStringAsFixed(1)}',
                m,
              ),
          ],
          if (player.dismissalHistory.isNotEmpty) ...[
            const PremiumSectionHeader(
                title: 'Dismissal History',
                subtitle:
                    'Most frequent first • "c X b Y — N times"',
                icon: Icons.history),
            for (final d in player.dismissalHistory) _tableRow(d, ''),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _heroStat(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: AppTheme.goldLight)),
          const SizedBox(height: 2),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }

  /// Matchup row: tapping the bowler opens their profile (P12).
  /// Resolved via ApiService.fetchPlayer (Cricsheet-first, then
  /// provider id resolution) — NOT fetchPlayers(), whose list is
  /// mock-only (6 curated players) and could never resolve a real
  /// Cricsheet bowler. bowlerId first, then the display name.
  Widget _tappableRow(
      BuildContext context, String title, String trailing, Matchup m) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: AppTheme.premiumCard(radius: 12),
      child: InkWell(
        onTap: () async {
          final api = ApiService();
          Player? found;
          if (m.bowlerId.trim().isNotEmpty) {
            found = await api.fetchPlayer(m.bowlerId);
          }
          found ??= await api.fetchPlayer(m.bowlerName);
          if (!context.mounted) return;
          if (found == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(
                      'Profile not available for ${m.bowlerName} yet.')),
            );
            return;
          }
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => PlayerProfileScreen(player: found!)));
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.goldLight,
                        decoration: TextDecoration.underline)),
              ),
              const SizedBox(width: 10),
              if (trailing.isNotEmpty)
                Flexible(
                  child: Text(trailing,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tableRow(String title, String trailing) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: AppTheme.premiumCard(radius: 12),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          if (trailing.isNotEmpty)
            Flexible(
              child: Text(trailing,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _grid(List<Widget> cards) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.55,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: cards,
    );
  }
}

/// Batting + Bowling tables with format chips (spec §4.3).
/// Chips filter BOTH tables: 'All' = every format row, otherwise only
/// the selected format. Bowling sits right after Batting — never at
/// the bottom of the screen.
class _FormatTables extends StatefulWidget {
  final Player player;
  const _FormatTables({required this.player});
  @override
  State<_FormatTables> createState() => _FormatTablesState();
}

class _FormatTablesState extends State<_FormatTables> {
  String _format = 'All';

  List<String> get _formats {
    final s = <String>{'All'};
    s.addAll(widget.player.battingByFormat.keys);
    s.addAll(widget.player.bowlingByFormat.keys);
    const order = ['All', 'Test', 'ODI', 'T20', 'T10'];
    final rest = s.where((f) => !order.contains(f)).toList()..sort();
    return [...order.where(s.contains), ...rest];
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.player;
    final batEntries = _format == 'All'
        ? player.battingByFormat.entries.toList()
        : player.battingByFormat.entries
            .where((e) => e.key == _format)
            .toList();
    final bowlEntries = _format == 'All'
        ? player.bowlingByFormat.entries.toList()
        : player.bowlingByFormat.entries
            .where((e) => e.key == _format)
            .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _formats.map((f) {
              final selected = _format == f;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(f),
                  selected: selected,
                  onSelected: (_) => setState(() => _format = f),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 10),
        const Text('Batting',
            style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15,
                color: AppTheme.goldLight)),
        const SizedBox(height: 8),
        if (batEntries.isEmpty)
          Text('No batting data for $_format.',
              style: const TextStyle(color: AppTheme.textSecondary))
        else
          _battingTable(batEntries),
        const SizedBox(height: 14),
        const Text('Bowling',
            style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15,
                color: AppTheme.goldLight)),
        const SizedBox(height: 8),
        if (bowlEntries.isEmpty)
          Text('No bowling data for $_format.',
              style: const TextStyle(color: AppTheme.textSecondary))
        else
          _bowlingTable(bowlEntries),
      ],
    );
  }

  Widget _battingTable(
      List<MapEntry<String, BattingStats>> entries) {
    return KingGradientCard(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 700,
          child: Column(
            children: [
              const ScoreRow(
                cells: [
                  SizedBox(
                      width: 90,
                      child: Text('FORMAT',
                          style: TextStyle(
                              color: AppTheme.goldLight,
                              fontSize: 11,
                              fontWeight: FontWeight.w900))),
                  ScoreHeaderCell('M', width: 48),
                  ScoreHeaderCell('Runs', width: 72),
                  ScoreHeaderCell('Avg', width: 64),
                  ScoreHeaderCell('SR', width: 64),
                  ScoreHeaderCell('100s', width: 56),
                  ScoreHeaderCell('50s', width: 56),
                  ScoreHeaderCell('HS', width: 56),
                ],
              ),
              for (final e in entries)
                ScoreRow(
                  cells: [
                    SizedBox(
                        width: 90,
                        child: Text(e.key,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700))),
                    SizedBox(
                        width: 48,
                        child: Text('${e.value.matches}',
                            textAlign: TextAlign.right)),
                    SizedBox(
                        width: 72,
                        child: Text('${e.value.runs}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: AppTheme.goldLight))),
                    SizedBox(
                        width: 64,
                        child: Text(
                            e.value.average.toStringAsFixed(1),
                            textAlign: TextAlign.right)),
                    SizedBox(
                        width: 64,
                        child: Text(
                            e.value.strikeRate.toStringAsFixed(1),
                            textAlign: TextAlign.right)),
                    SizedBox(
                        width: 56,
                        child: Text('${e.value.hundreds}',
                            textAlign: TextAlign.right)),
                    SizedBox(
                        width: 56,
                        child: Text('${e.value.fifties}',
                            textAlign: TextAlign.right)),
                    SizedBox(
                        width: 56,
                        child: Text('${e.value.highest}',
                            textAlign: TextAlign.right)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bowlingTable(
      List<MapEntry<String, BowlingStats>> entries) {
    return KingGradientCard(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 620,
          child: Column(
            children: [
              const ScoreRow(
                cells: [
                  SizedBox(
                      width: 90,
                      child: Text('FORMAT',
                          style: TextStyle(
                              color: AppTheme.goldLight,
                              fontSize: 11,
                              fontWeight: FontWeight.w900))),
                  ScoreHeaderCell('M', width: 48),
                  ScoreHeaderCell('Wkts', width: 56),
                  ScoreHeaderCell('Avg', width: 64),
                  ScoreHeaderCell('Econ', width: 64),
                  ScoreHeaderCell('SR', width: 64),
                  ScoreHeaderCell('Best', width: 72),
                  ScoreHeaderCell('5w', width: 48),
                ],
              ),
              for (final e in entries)
                ScoreRow(
                  cells: [
                    SizedBox(
                        width: 90,
                        child: Text(e.key,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700))),
                    SizedBox(
                        width: 48,
                        child: Text('${e.value.matches}',
                            textAlign: TextAlign.right)),
                    SizedBox(
                        width: 56,
                        child: Text('${e.value.wickets}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: AppTheme.goldLight))),
                    SizedBox(
                        width: 64,
                        child: Text(
                            e.value.average.toStringAsFixed(1),
                            textAlign: TextAlign.right)),
                    SizedBox(
                        width: 64,
                        child: Text(e.value.economy.toStringAsFixed(2),
                            textAlign: TextAlign.right)),
                    SizedBox(
                        width: 64,
                        child: Text(
                            e.value.strikeRate.toStringAsFixed(1),
                            textAlign: TextAlign.right)),
                    SizedBox(
                        width: 72,
                        child: Text(e.value.best,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right)),
                    SizedBox(
                        width: 48,
                        child: Text('${e.value.fiveWickets}',
                            textAlign: TextAlign.right)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
