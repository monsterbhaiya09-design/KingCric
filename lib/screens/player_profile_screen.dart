import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/player.dart';
import '../services/prediction_engine.dart';
import '../utils/strings.dart';
import '../widgets/prediction_card.dart';
import '../widgets/stat_card.dart';

/// Player profile: context-wise sections — Overall, vs Opponent,
/// Format-wise, Venue, Recent Form, Matchups, Dismissal history.
/// Never a raw dump: each section is labelled with its context.
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
    return Scaffold(
      appBar: AppBar(title: Text(player.name)),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(player.name,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w900)),
                  Text('${player.role} • ${player.team} • ${player.country}'),
                  Text(
                      'Batting: ${player.battingStyle} • Bowling: ${player.bowlingStyle}'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                          player.dataComplete
                              ? Icons.verified
                              : Icons.hourglass_top,
                          size: 16,
                          color: player.dataComplete
                              ? Colors.green
                              : Colors.amber),
                      const SizedBox(width: 6),
                      Text(player.dataComplete
                          ? lang.t('data_complete')
                          : lang.t('data_checking')),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (opponent != null && venueId != null)
            PredictionCard(
                prediction: PredictionEngine.predict(
                    player: player,
                    opponent: opponent!,
                    venueId: venueId!,
                    format: format ?? 'T20')),
          Section(
            title: lang.t('overall'),
            subtitle: 'All formats combined',
            children: [
              _grid([
                StatCard(label: lang.t('runs'), value: '${overall.runs}'),
                StatCard(
                    label: lang.t('average'),
                    value: overall.average.toStringAsFixed(1)),
                StatCard(
                    label: lang.t('strike_rate'),
                    value: overall.strikeRate.toStringAsFixed(1)),
                StatCard(
                    label: lang.t('hundreds'),
                    value: '${overall.hundreds}',
                    sub: '${overall.fifties} ${lang.t('fifties')}'),
              ]),
            ],
          ),
          if (vsOpp != null)
            Section(
              title: '${lang.t('vs_opponent')} — $opponent',
              children: [
                _grid([
                  StatCard(label: lang.t('runs'), value: '${vsOpp.runs}'),
                  StatCard(
                      label: lang.t('average'),
                      value: vsOpp.average.toStringAsFixed(1)),
                  StatCard(
                      label: lang.t('strike_rate'),
                      value: vsOpp.strikeRate.toStringAsFixed(1)),
                  StatCard(
                      label: 'Matches', value: '${vsOpp.matches}'),
                ]),
              ],
            ),
          if (fmt != null)
            Section(
              title: '${lang.t('format_wise')} — $format',
              children: [
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
              ],
            ),
          Section(
            title: 'All formats',
            children: [
              for (final e in player.battingByFormat.entries)
                Card(
                  child: ListTile(
                    title: Text(e.key),
                    trailing: Text(
                        '${e.value.runs} runs • Avg ${e.value.average.toStringAsFixed(1)} • SR ${e.value.strikeRate.toStringAsFixed(1)}'),
                  ),
                ),
            ],
          ),
          if (player.battingByLeague.isNotEmpty)
            Section(
              title: 'Leagues',
              children: [
                for (final e in player.battingByLeague.entries)
                  Card(
                    child: ListTile(
                      title: Text(e.key),
                      trailing: Text(
                          '${e.value.runs} runs • Avg ${e.value.average.toStringAsFixed(1)}'),
                    ),
                  ),
              ],
            ),
          if (player.battingByVenue.isNotEmpty)
            Section(
              title: lang.t('venue'),
              subtitle: 'Venue records per player',
              children: [
                for (final e in player.battingByVenue.entries)
                  Card(
                    child: ListTile(
                      title: Text(e.key),
                      trailing: Text(
                          '${e.value.runs} runs • Avg ${e.value.average.toStringAsFixed(1)} • SR ${e.value.strikeRate.toStringAsFixed(1)}'),
                    ),
                  ),
              ],
            ),
          Section(
            title: lang.t('recent_form'),
            children: [
              for (final f in player.recentForm)
                Card(
                  child: ListTile(
                    title: Text(f.matchLabel),
                    subtitle: Text(
                        '${f.opponent} • ${f.format} • ${f.result}'),
                    trailing: Text(f.wickets > 0
                        ? '${f.wickets} wkts'
                        : '${f.runs} (${f.balls})'),
                  ),
                ),
            ],
          ),
          if (player.matchups.isNotEmpty)
            Section(
              title: lang.t('matchup'),
              children: [
                for (final m in player.matchups)
                  Card(
                    child: ListTile(
                      title: Text('vs ${m.bowlerName}'),
                      subtitle: Text(
                          '${m.matches} matches • ${m.dismissals} dismissals'),
                      trailing: Text(
                          '${m.runs} runs / ${m.balls} balls • SR ${m.strikeRate.toStringAsFixed(1)}'),
                    ),
                  ),
              ],
            ),
          if (player.dismissalHistory.isNotEmpty)
            Section(
              title: 'Dismissal history',
              children: [
                for (final d in player.dismissalHistory)
                  Card(child: ListTile(title: Text(d))),
              ],
            ),
          if (player.bowlingByFormat.isNotEmpty)
            Section(
              title: 'Bowling',
              children: [
                for (final e in player.bowlingByFormat.entries)
                  Card(
                    child: ListTile(
                      title: Text(e.key),
                      trailing: Text(
                          '${e.value.wickets} wkts • Econ ${e.value.economy.toStringAsFixed(2)} • Avg ${e.value.average.toStringAsFixed(1)}'),
                    ),
                  ),
              ],
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
      childAspectRatio: 1.6,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      children: cards,
    );
  }
}
