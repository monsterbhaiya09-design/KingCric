import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/match.dart';
import '../models/player.dart';
import '../services/api_service.dart';
import '../widgets/match_card.dart';
import 'match_detail_screen.dart';
import 'player_profile_screen.dart';

/// Favourites: favourite team + players, persisted locally with
/// shared_preferences (free, no backend needed for v1).
/// Notifications (FCM) plug in here in the production build.
class FavouritesScreen extends StatefulWidget {
  const FavouritesScreen({super.key});
  @override
  State<FavouritesScreen> createState() => _FavouritesScreenState();
}

class _FavouritesScreenState extends State<FavouritesScreen> {
  Set<String> _favIds = {};
  Set<String> _favTeams = {};
  bool _notifications = true;
  // Cached futures (reference G5): never re-fire on every build.
  // NOT final: Retry reassigns them. `late final` + reassignment
  // throws LateError, so a Retry tap after a load error crashed.
  late Future<List<Player>> _playersFuture;
  late Future<List<CricketMatch>> _matchesFuture;

  /// One-line meaning of each notification event (reference: every
  /// setting explains itself in one line).
  static const _eventHints = {
    'Wickets': 'A wicket falls in a followed match.',
    'Sixes': 'A six is hit in a followed match.',
    'Match start': 'A followed team starts a match.',
    'Milestones': 'A followed player reaches 50 / 100 / 5 wickets.',
  };
  // Per-event notification preferences (CricketLineX event list):
  // wickets / sixes / match start / milestones. Stored locally now;
  // FCM push is not wired yet — the subtitle says so honestly.
  final Map<String, bool> _eventPrefs = {
    'Wickets': true,
    'Sixes': true,
    'Match start': true,
    'Milestones': true,
  };
  static const _key = 'kingcric_fav_player_ids';
  static const _teamKey = 'kingcric_fav_teams';
  static const _notifKey = 'kingcric_notifications';
  static const _eventKeyPrefix = 'kingcric_notif_event_';

  @override
  void initState() {
    super.initState();
    _playersFuture = ApiService().fetchPlayers();
    _matchesFuture = ApiService().fetchMatches();
    _load();
  }

  void _reload() {
    setState(() {
      _playersFuture = ApiService().fetchPlayers();
      _matchesFuture = ApiService().fetchMatches();
    });
  }

  // In-memory fallback: if the platform SharedPreferences channel is
  // ever unavailable (e.g. MissingPluginException on a broken build),
  // favourites still work for the session instead of crashing.
  static Set<String> _memoryFavIds = {};
  static bool _memoryNotifications = true;

  Future<SharedPreferences?> _prefsOrNull() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  Future<void> _load() async {
    final prefs = await _prefsOrNull();
    if (!mounted) return;
    setState(() {
      if (prefs != null) {
        _favIds = (prefs.getStringList(_key) ?? []).toSet();
        _favTeams = (prefs.getStringList(_teamKey) ?? []).toSet();
        _notifications = prefs.getBool(_notifKey) ?? true;
        for (final e in _eventPrefs.keys) {
          _eventPrefs[e] = prefs.getBool('$_eventKeyPrefix$e') ?? true;
        }
        // Keep the memory fallback in sync.
        _memoryFavIds = Set.of(_favIds);
        _memoryNotifications = _notifications;
      } else {
        _favIds = Set.of(_memoryFavIds);
        _notifications = _memoryNotifications;
      }
    });
  }

  Future<void> _toggleTeam(String team) async {
    setState(() {
      if (_favTeams.contains(team)) {
        _favTeams.remove(team);
      } else {
        _favTeams.add(team);
      }
    });
    try {
      final prefs = await _prefsOrNull();
      await prefs?.setStringList(_teamKey, _favTeams.toList());
    } catch (_) {}
  }

  Future<void> _toggleEvent(String event, bool v) async {
    setState(() => _eventPrefs[event] = v);
    try {
      final prefs = await _prefsOrNull();
      await prefs?.setBool('$_eventKeyPrefix$event', v);
    } catch (_) {}
  }

  Future<void> _toggle(String id) async {
    setState(() {
      if (_favIds.contains(id)) {
        _favIds.remove(id);
      } else {
        _favIds.add(id);
      }
    });
    _memoryFavIds = Set.of(_favIds);
    try {
      final prefs = await _prefsOrNull();
      await prefs?.setStringList(_key, _favIds.toList());
    } catch (_) {
      // Persistence is best-effort; in-memory state already updated.
    }
  }

  Future<void> _toggleNotif(bool v) async {
    setState(() => _notifications = v);
    _memoryNotifications = v;
    try {
      final prefs = await _prefsOrNull();
      await prefs?.setBool(_notifKey, v);
    } catch (_) {
      // Persistence is best-effort.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Favourites')),
      body: FutureBuilder(
        future: _playersFuture,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                        'Could not load favourites. Check your connection and try again.',
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
          final players = snap.data!;
          final teams = players.map((p) => p.team).toSet().toList()
            ..sort();
          return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              SwitchListTile(
                title: const Text('Match notifications'),
                subtitle: const Text(
                    'Local reminders for your favourites. Push (FCM) coming soon — not wired yet.'),
                value: _notifications,
                onChanged: _toggleNotif,
              ),
              const Text('Notify me about',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 15)),
              // Event toggles are gated by the master switch: with
              // notifications OFF, no event can be ON (otherwise the
              // UI promises alerts it will never send).
              for (final e in _eventPrefs.keys)
                SwitchListTile(
                  title: Text(e),
                  subtitle: Text(_eventHints[e] ?? ''),
                  value: _notifications && (_eventPrefs[e] ?? true),
                  onChanged: _notifications
                      ? (v) => _toggleEvent(e, v)
                      : null,
                ),
              if (_favIds.isEmpty && _favTeams.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8, bottom: 4),
                  child: Text(
                      'No favourites yet — tap ⭐ on any player or team to follow them here.',
                      style: TextStyle(fontSize: 13)),
                ),
              const SizedBox(height: 8),
              const Text('Favourite Teams — tap ⭐ to follow a team',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 8),
              for (final team in teams)
                Card(
                  child: ListTile(
                    title: Text(team,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      icon: Icon(
                          _favTeams.contains(team)
                              ? Icons.star
                              : Icons.star_border,
                          color: _favTeams.contains(team)
                              ? Colors.amber
                              : null),
                      onPressed: () => _toggleTeam(team),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              const Text('Favourite Players — tap ⭐ to follow a player',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 8),
              for (final p in players)
                Card(
                  child: ListTile(
                    title: Text(p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    subtitle: Text('${p.role} • ${p.team}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      icon: Icon(
                          _favIds.contains(p.id)
                              ? Icons.star
                              : Icons.star_border,
                          color: _favIds.contains(p.id)
                              ? Colors.amber
                              : null),
                      onPressed: () => _toggle(p.id),
                    ),
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                PlayerProfileScreen(player: p))),
                  ),
                ),
              const SizedBox(height: 12),
              // Matches of your favourite teams (reference F3): a
              // favourited team surfaces its matches here, so
              // Favourites is a live view, not just a star list.
              const Text('Matches of your favourite teams',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 8),
              FutureBuilder(
                future: _matchesFuture,
                builder: (context, msnap) {
                  if (msnap.hasError) {
                    return const Text(
                        'Could not load matches for your teams.',
                        style: TextStyle(fontSize: 13));
                  }
                  if (!msnap.hasData) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                          child: CircularProgressIndicator()),
                    );
                  }
                  final favMatches = msnap.data!
                      .where((m) => _favTeams.contains(m.teamA) ||
                          _favTeams.contains(m.teamB))
                      .toList()
                    ..sort((a, b) {
                      int rank(CricketMatch m) => m.isEffectivelyLive
                          ? 0
                          : (m.isCompleted ? 2 : 1);
                      final r = rank(a).compareTo(rank(b));
                      if (r != 0) return r;
                      return b.startTime.compareTo(a.startTime);
                    });
                  if (_favTeams.isEmpty) {
                    return const Text(
                        'Star a team above to see its matches here.',
                        style: TextStyle(fontSize: 13));
                  }
                  if (favMatches.isEmpty) {
                    return const Text(
                        'No loaded matches for your teams yet.',
                        style: TextStyle(fontSize: 13));
                  }
                  return Column(
                    children: [
                      for (final m in favMatches)
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
              ),
            ],
          );
        },
      ),
    );
  }
}
