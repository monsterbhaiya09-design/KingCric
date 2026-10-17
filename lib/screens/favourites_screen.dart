import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
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
  bool _notifications = true;
  static const _key = 'kingcric_fav_player_ids';
  static const _notifKey = 'kingcric_notifications';

  @override
  void initState() {
    super.initState();
    _load();
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
        _notifications = prefs.getBool(_notifKey) ?? true;
        // Keep the memory fallback in sync.
        _memoryFavIds = Set.of(_favIds);
        _memoryNotifications = _notifications;
      } else {
        _favIds = Set.of(_memoryFavIds);
        _notifications = _memoryNotifications;
      }
    });
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
        future: ApiService().fetchPlayers(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final players = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              SwitchListTile(
                title: const Text('Match notifications'),
                subtitle: const Text(
                    'Alerts for your favourite players and teams'),
                value: _notifications,
                onChanged: _toggleNotif,
              ),
              const SizedBox(height: 8),
              const Text('Tap ⭐ to favourite a player',
                  style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              for (final p in players)
                Card(
                  child: ListTile(
                    title: Text(p.name),
                    subtitle: Text('${p.role} • ${p.team}'),
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
            ],
          );
        },
      ),
    );
  }
}
