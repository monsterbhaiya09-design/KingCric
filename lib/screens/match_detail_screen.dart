import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/match.dart';
import '../services/api_service.dart';
import '../services/prediction_engine.dart';
import '../utils/strings.dart';
import '../widgets/h2h_card.dart';
import '../widgets/player_card.dart';
import '../widgets/prediction_card.dart';
import '../widgets/stat_card.dart';
import 'player_profile_screen.dart';

/// Match detail: live score + scorecard + commentary + squad (with
/// per-player context vs this opponent) + H2H + predictions.
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

  @override
  void initState() {
    super.initState();
    _match = widget.match;
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    return Scaffold(
      appBar: AppBar(
        title: Text(_match.title),
        bottom: TabBar(
          controller: _tabs,
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

  Widget _liveTab(LanguageProvider lang) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        H2HCard(
          teamA: _match.teamA,
          teamB: _match.teamB,
          winsA: _match.teamAWinsH2H,
          winsB: _match.teamBWinsH2H,
          total: _match.totalH2H,
        ),
        Section(
          title: lang.t('live'),
          children: [
            for (final s in _match.scores)
              Card(
                child: ListTile(
                  title: Text(s.team,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  trailing: Text(s.display),
                ),
              ),
            if (_match.toss.isNotEmpty) Text('🪙 ${_match.toss}'),
            if (_match.currentBatter.isNotEmpty)
              Text(
                  'Batting: ${_match.currentBatter} • Bowling: ${_match.currentBowler}'),
          ],
        ),
        Section(
          title: lang.t('commentary'),
          children: [
            for (final c in _match.commentary)
              Card(child: ListTile(title: Text(c))),
            if (_match.commentary.isEmpty)
              Text(lang.isHindi
                  ? 'कमेंट्री उपलब्ध नहीं है।'
                  : 'No commentary available.'),
          ],
        ),
      ],
    );
  }

  Widget _scorecardTab(LanguageProvider lang) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        for (final inn in _match.innings) ...[
          Section(
            title: '${inn.team} — ${inn.total}/${inn.wickets} '
                '(${inn.overs.toStringAsFixed(1)} ov)',
            children: [
              for (final b in inn.batting)
                Card(
                  child: ListTile(
                    title: Text(b.playerName),
                    subtitle: Text(b.notOut
                        ? 'not out'
                        : b.dismissal.isEmpty
                            ? ''
                            : b.dismissal),
                    trailing: Text(
                        '${b.runs} (${b.balls}) • SR ${b.strikeRate.toStringAsFixed(1)}'),
                  ),
                ),
              const SizedBox(height: 8),
              Text(lang.isHindi ? 'बॉलिंग' : 'Bowling',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              for (final b in inn.bowling)
                Card(
                  child: ListTile(
                    title: Text(b.playerName),
                    trailing: Text(
                        '${b.wickets}/${b.runsConceded} • ${b.overs} ov • Econ ${b.economy.toStringAsFixed(2)}'),
                  ),
                ),
            ],
          ),
        ],
        if (_match.innings.isEmpty)
          Text(lang.isHindi
              ? 'स्कोरकार्ड अभी उपलब्ध नहीं है।'
              : 'Scorecard not available yet.'),
      ],
    );
  }

  Widget _squadTab() {
    return FutureBuilder(
      future: ApiService().fetchPlayers(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final all = snap.data!;
        final squadIds = {..._match.squadA, ..._match.squadB};
        final squad =
            all.where((p) => squadIds.contains(p.id)).toList();
        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            for (final p in squad)
              PlayerCard(
                player: p,
                contextLine:
                    'vs ${_match.teamA == p.team ? _match.teamB : _match.teamA} • ${_match.format}',
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => PlayerProfileScreen(
                            player: p,
                            opponent: _match.teamA == p.team
                                ? _match.teamB
                                : _match.teamA,
                            venueId: _match.venueId,
                            format: _match.format))),
              ),
            if (squad.isEmpty)
              const Text('Squad data will appear once the free API '
                  'returns squads for this match.'),
          ],
        );
      },
    );
  }

  Widget _predictionTab() {
    return FutureBuilder(
      future: ApiService().fetchPlayers(),
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
            for (final pr in preds) PredictionCard(prediction: pr),
          ],
        );
      },
    );
  }
}
