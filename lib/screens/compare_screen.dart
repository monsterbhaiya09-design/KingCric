import 'package:flutter/material.dart';
import '../models/player.dart';
import '../services/api_service.dart';
import 'player_profile_screen.dart';

/// Compare: two players side-by-side, every key stat row.
class CompareScreen extends StatefulWidget {
  const CompareScreen({super.key});
  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  List<Player> _players = [];
  String? _aId;
  String? _bId;

  @override
  void initState() {
    super.initState();
    ApiService().fetchPlayers().then((p) {
      if (!mounted) return;
      setState(() {
        _players = p;
        if (p.length >= 2) {
          _aId = p[0].id;
          _bId = p[1].id;
        }
      });
    });
  }

  Player? _byId(String? id) {
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
              Expanded(child: _picker(_aId, (v) => setState(() => _aId = v))),
              const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('VS',
                      style:
                          TextStyle(fontWeight: FontWeight.w900, fontSize: 18))),
              Expanded(child: _picker(_bId, (v) => setState(() => _bId = v))),
            ],
          ),
          const SizedBox(height: 16),
          if (a != null && b != null) _table(a, b),
        ],
      ),
    );
  }

  Widget _picker(String? value, ValueChanged<String?> onChanged) {
    return DropdownButton<String>(
      value: value,
      isExpanded: true,
      items: _players
          .map((p) =>
              DropdownMenuItem(value: p.id, child: Text(p.name)))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _table(Player a, Player b) {
    final ab = a.battingOverall();
    final bb = b.battingOverall();
    final rows = <List<String>>[
      ['Runs', '${ab.runs}', '${bb.runs}'],
      ['Average', ab.average.toStringAsFixed(1), bb.average.toStringAsFixed(1)],
      ['Strike Rate', ab.strikeRate.toStringAsFixed(1), bb.strikeRate.toStringAsFixed(1)],
      ['100s / 50s', '${ab.hundreds} / ${ab.fifties}', '${bb.hundreds} / ${bb.fifties}'],
      ['Fours / Sixes', '${ab.fours} / ${ab.sixes}', '${bb.fours} / ${bb.sixes}'],
      ['Highest', '${ab.highest}', '${bb.highest}'],
      ['Matches', '${ab.matches}', '${bb.matches}'],
    ];
    return Column(
      children: [
        Row(
          children: [
            Expanded(
                child: _head(a.name, () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => PlayerProfileScreen(player: a))))),
            const SizedBox(width: 8),
            Expanded(
                child: _head(b.name, () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => PlayerProfileScreen(player: b))))),
          ],
        ),
        const SizedBox(height: 12),
        for (final r in rows)
          Card(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                      child: Text(r[1],
                          textAlign: TextAlign.left,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700))),
                  Expanded(
                      child: Text(r[0],
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70))),
                  Expanded(
                      child: Text(r[2],
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700))),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _head(String name, VoidCallback onTap) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(name,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }
}
