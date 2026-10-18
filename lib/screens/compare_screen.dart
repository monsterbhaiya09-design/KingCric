import 'package:flutter/material.dart';
import '../models/player.dart';
import '../services/api_service.dart';
import '../utils/app_theme.dart';
import '../widgets/premium_widgets.dart';
import 'player_profile_screen.dart';

/// Compare: two players side-by-side — batting AND bowling —
/// with a per-row winner highlight in gold.
///
/// Stale-picker fix (known V2 review bug): the Dropdown value is
/// only passed when it still exists in the loaded player list;
/// after a reload, dead ids are re-validated before use.
class CompareScreen extends StatefulWidget {
  const CompareScreen({super.key});
  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  List<Player> _players = [];
  String? _aId;
  String? _bId;
  bool _loading = true;
  // Format filter: 'All' = career totals; otherwise that format only.
  String _format = 'All';
  static const _formats = ['All', 'Test', 'ODI', 'T20', 'T10'];

  @override
  void initState() {
    super.initState();
    ApiService().fetchPlayers().then((p) {
      if (!mounted) return;
      setState(() {
        _players = p;
        _loading = false;
        // Re-validate: drop ids that no longer exist in the list.
        if (!_players.any((pl) => pl.id == _aId)) {
          _aId = _players.isNotEmpty ? _players[0].id : null;
        }
        if (!_players.any((pl) => pl.id == _bId)) {
          _bId = _players.length >= 2 ? _players[1].id : null;
        }
        // Never compare a player with themselves.
        if (_aId != null && _aId == _bId) {
          _bId = _players
              .firstWhere((pl) => pl.id != _aId,
                  orElse: () => _players[0])
              .id;
        }
      });
    });
  }

  /// Picker change with same-player guard: picking the same player on
  /// both sides silently moves the other side to the first different
  /// player, so the table never compares a player with themselves.
  void _pickA(String? v) {
    if (v == null) return;
    setState(() {
      _aId = v;
      if (_aId == _bId) {
        _bId = _players
            .firstWhere((pl) => pl.id != _aId,
                orElse: () => _players[0])
            .id;
      }
    });
  }

  void _pickB(String? v) {
    if (v == null) return;
    setState(() {
      _bId = v;
      if (_aId == _bId) {
        _aId = _players
            .firstWhere((pl) => pl.id != _bId,
                orElse: () => _players[0])
            .id;
      }
    });
  }

  Player? _byId(String? id) {
    if (id == null) return null;
    for (final p in _players) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final a = _byId(_aId);
    final b = _byId(_bId);
    return Scaffold(
      appBar: AppBar(title: const Text('Player Compare')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Row(
            children: [
              Expanded(child: _picker(_aId, _pickA)),
              const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('VS',
                      style: TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 18))),
              Expanded(child: _picker(_bId, _pickB)),
            ],
          ),
          const SizedBox(height: 12),
          _formatChips(),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (a == null || b == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                  child: Text('No players available to compare yet.',
                      textAlign: TextAlign.center)),
            )
          else ...[
            Text(
              'Source — A: ${_sourceLabel(a)} • B: ${_sourceLabel(b)}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 12),
            ),
            if (_format != 'All') ...[
              const SizedBox(height: 4),
              Text('Showing $_format numbers only.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12)),
            ],
            const SizedBox(height: 12),
            _table(a, b),
          ],
        ],
      ),
    );
  }

  /// Format chips (Test/ODI/T20/T10) — same filter as Profile/Stats.
  /// 'All' = career totals across formats.
  Widget _formatChips() {
    return SingleChildScrollView(
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
    );
  }

  String _sourceLabel(Player p) {
    if (p.source == 'cricsheet') return 'Real • Cricsheet';
    if (p.source == 'demo') return 'Demo';
    return p.dataComplete ? 'Real' : 'Partial';
  }

  Widget _picker(String? value, ValueChanged<String?> onChanged) {
    // Only pass a value that exists in the list — otherwise the
    // Dropdown throws "value not in items" (the stale-picker crash).
    final safeValue =
        value != null && _players.any((p) => p.id == value) ? value : null;
    return DropdownButton<String>(
      value: safeValue,
      isExpanded: true,
      hint: const Text('Select player'),
      items: _players
          .map((p) => DropdownMenuItem(
              value: p.id,
              child: Text(p.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _table(Player a, Player b) {
    // Format filter: 'All' = career totals; otherwise that format only.
    final ab = _format == 'All'
        ? a.battingOverall()
        : a.battingInFormat(_format);
    final bb = _format == 'All'
        ? b.battingOverall()
        : b.battingInFormat(_format);
    // Weighted bowling economy / average across ALL formats
    // (total runs / total balls, total runs / total wickets) — never
    // a single-format value presented as a career number.
    // With a format selected, use that format's bowling row directly.
    ({double econ, double avg, String best}) bowlingAgg(Player p) {
      if (_format != 'All') {
        final s = p.bowlingByFormat[_format];
        if (s == null) {
          return (econ: double.infinity, avg: double.infinity, best: '—');
        }
        return (
          econ: s.balls == 0
              ? double.infinity
              : s.runsConceded / (s.balls / 6),
          avg: s.wickets == 0
              ? double.infinity
              : s.runsConceded / s.wickets,
          best: s.best,
        );
      }
      var runs = 0, balls = 0, wkts = 0;
      var best = '—';
      var bestWkts = -1;
      for (final s in p.bowlingByFormat.values) {
        runs += s.runsConceded;
        balls += s.balls;
        wkts += s.wickets;
        if (s.wickets > bestWkts) {
          bestWkts = s.wickets;
          best = s.best;
        }
      }
      return (
        econ: balls == 0 ? double.infinity : runs / (balls / 6),
        avg: wkts == 0 ? double.infinity : runs / wkts,
        best: best,
      );
    }

    // Wickets in a format, for the format-filtered bowling row.
    int bowlingWkts(Player p) {
      if (_format == 'All') return p.bowlingOverall().wickets;
      return p.bowlingByFormat[_format]?.wickets ?? 0;
    }

    final aAgg = bowlingAgg(a);
    final bAgg = bowlingAgg(b);
    // 'Best' like "5/19" compares on wickets taken in that spell;
    // unparseable / '—' = not comparable (no fake winner).
    double bestWkts(String best) {
      final m = RegExp(r'^(\d+)').firstMatch(best.trim());
      if (m == null) return double.nan;
      return double.tryParse(m.group(1)!) ?? double.nan;
    }
    // Rows: (label, aText, bText, aNumeric, bNumeric, higherWins)
    // higherWins=false means LOWER is better (economy, bowling avg).
    final battingRows = <(String, String, String, double, double, bool)>[
      ('Runs', '${ab.runs}', '${bb.runs}', ab.runs.toDouble(),
          bb.runs.toDouble(), true),
      ('Average', ab.average.toStringAsFixed(1),
          bb.average.toStringAsFixed(1), ab.average, bb.average, true),
      ('Strike Rate', ab.strikeRate.toStringAsFixed(1),
          bb.strikeRate.toStringAsFixed(1), ab.strikeRate, bb.strikeRate,
          true),
      ('100s / 50s', '${ab.hundreds} / ${ab.fifties}',
          '${bb.hundreds} / ${bb.fifties}',
          (ab.hundreds * 100 + ab.fifties).toDouble(),
          (bb.hundreds * 100 + bb.fifties).toDouble(), true),
      ('Fours / Sixes', '${ab.fours} / ${ab.sixes}',
          '${bb.fours} / ${bb.sixes}',
          (ab.fours + ab.sixes).toDouble(),
          (bb.fours + bb.sixes).toDouble(), true),
      ('Highest', '${ab.highest}', '${bb.highest}',
          ab.highest.toDouble(), bb.highest.toDouble(), true),
      ('Matches', '${ab.matches}', '${bb.matches}',
          ab.matches.toDouble(), bb.matches.toDouble(), true),
    ];
    final bowlingRows = <(String, String, String, double, double, bool)>[
      ('Wickets', '${bowlingWkts(a)}', '${bowlingWkts(b)}',
          bowlingWkts(a).toDouble(), bowlingWkts(b).toDouble(), true),
      ('Economy',
          aAgg.econ.isFinite ? aAgg.econ.toStringAsFixed(2) : '—',
          bAgg.econ.isFinite ? bAgg.econ.toStringAsFixed(2) : '—',
          aAgg.econ, bAgg.econ, false),
      ('Bowling Avg',
          aAgg.avg.isFinite ? aAgg.avg.toStringAsFixed(1) : '—',
          bAgg.avg.isFinite ? bAgg.avg.toStringAsFixed(1) : '—',
          aAgg.avg, bAgg.avg, false),
      // Best compares on wickets in the spell ("5/19" beats "3/10");
      // unparseable bests are not comparable — no fake winner.
      ('Best', aAgg.best, bAgg.best,
          bestWkts(aAgg.best), bestWkts(bAgg.best), true),
    ];
    // Overall winner: count of rows won (draws / non-comparable = 0).
    int rowWins(bool forA) {
      var n = 0;
      for (final rows in [battingRows, bowlingRows]) {
        for (final r in rows) {
          final (_, _, _, aVal, bVal, higherWins) = r;
          if (aVal == bVal || aVal.isNaN || bVal.isNaN) continue;
          if (!aVal.isFinite || !bVal.isFinite) continue;
          final aWon = higherWins ? aVal > bVal : aVal < bVal;
          if (forA ? aWon : !aWon) n++;
        }
      }
      return n;
    }

    final aWins = rowWins(true);
    final bWins = rowWins(false);
    final summary = aWins == bWins
        ? 'Level $aWins–$bWins across ${battingRows.length + bowlingRows.length} stats'
        : aWins > bWins
            ? '${a.name} leads $aWins–$bWins'
            : '${b.name} leads $bWins–$aWins';
    return Column(
      children: [
        Row(
          children: [
            Expanded(
                child: _head(a, () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => PlayerProfileScreen(player: a))))),
            const SizedBox(width: 8),
            Expanded(
                child: _head(b, () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => PlayerProfileScreen(player: b))))),
          ],
        ),
        const SizedBox(height: 10),
        Text(summary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontWeight: FontWeight.w800, color: AppTheme.goldLight)),
        const SizedBox(height: 12),
        const PremiumSectionHeader(
            title: 'Batting', icon: Icons.sports_cricket),
        for (final r in battingRows) _row(r),
        const PremiumSectionHeader(
            title: 'Bowling', icon: Icons.sports_baseball),
        for (final r in bowlingRows) _row(r),
      ],
    );
  }

  Widget _row((String, String, String, double, double, bool) r) {
    final (label, aText, bText, aVal, bVal, higherWins) = r;
    final comparable = aVal != bVal && aVal.isFinite && bVal.isFinite;
    final aWins = comparable && (higherWins ? aVal > bVal : aVal < bVal);
    final bWins = comparable && (higherWins ? bVal > aVal : bVal < aVal);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: AppTheme.premiumCard(radius: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
              child: Text(aText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.left,
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: aWins ? AppTheme.goldLight : null))),
          Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textSecondary))),
          Expanded(
              child: Text(bText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: bWins ? AppTheme.goldLight : null))),
        ],
      ),
    );
  }

  Widget _head(Player player, VoidCallback onTap) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              KingAvatar(name: player.name, radius: 26),
              const SizedBox(height: 8),
              Text(player.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text('${player.role} • ${player.team}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 11)),
              const SizedBox(height: 2),
              const Text('Tap for profile',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}
