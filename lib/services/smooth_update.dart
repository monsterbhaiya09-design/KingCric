import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/match.dart';
import '../models/player.dart';
import 'api_service.dart';

/// Smooth-update engine — how reference apps feel instant.
///
/// The pattern (public best practice, also what Cricbuzz / CREX /
/// CricketLineX do from the outside):
///  1. **Stale-while-revalidate:** show the last verified data
///     instantly, fetch fresh data in the background, swap it in
///     without flicker — never a blank screen, never a full-screen
///     spinner on refresh.
///  2. **Smart polling:** live = 10 min, upcoming/series = 60 min,
///     completed = cached forever-ish (finished data never changes).
///  3. **Deduplication:** the same in-flight request is shared, so
///     two screens asking for the same match burn one quota hit.
///  4. **Incremental updates:** only matches whose score actually
///     changed are treated as changed (diff by score signature), so
///     the list does not rebuild/flicker for no reason.
///  5. **Honest freshness:** every screen shows "Last updated HH:MM"
///     + a manual Refresh button; a failed refresh keeps old data
///     and shows the stale timestamp, never a crash, never blank.
///
/// This file holds the reusable pieces. [ApiService] owns the caches
/// and the in-flight map; [UpdateFeed] is the ChangeNotifier screens
/// listen to for SWR behaviour.

/// One in-flight request per key. Same key while a request is running
/// returns the SAME Future — no duplicate network calls, no double
/// quota burn. Failures are not cached: the entry is removed so the
/// next call retries.
class InFlightDeduper<T> {
  final Map<String, Future<T>> _inFlight = {};

  Future<T> run(String key, Future<T> Function() work) {
    final existing = _inFlight[key];
    if (existing != null) return existing;
    final future = work().whenComplete(() => _inFlight.remove(key));
    _inFlight[key] = future;
    return future;
  }

  bool get hasInFlight => _inFlight.isNotEmpty;
  int get inFlightCount => _inFlight.length;
}

/// Diff two match lists by score signature. Returns the ids whose
/// score/status/result actually changed. Unchanged matches must NOT
/// re-render — that is what kills flicker in reference apps.
class MatchDiff {
  static String signature(CricketMatch m) {
    final scores = m.scores
        .map((s) => '${s.team}:${s.runs}/${s.wickets}@${s.overs}')
        .join('|');
    // EFFECTIVE status, not the raw field: two copies of one match
    // (one status=upcoming with scores, one status=live) are the
    // SAME on screen and must not count as "changed" / re-render.
    final eff = m.isCompleted
        ? 'completed'
        : (m.isEffectivelyLive ? 'live' : 'upcoming');
    return '$eff|$scores|${m.result}';
  }

  static List<String> changedIds(
      List<CricketMatch> oldList, List<CricketMatch> newList) {
    final oldById = {for (final m in oldList) m.id: signature(m)};
    final changed = <String>[];
    for (final m in newList) {
      final oldSig = oldById[m.id];
      if (oldSig == null || oldSig != signature(m)) changed.add(m.id);
    }
    return changed;
  }
}

/// "HH:MM" for the "Last updated" line. Never throws.
String formatLastUpdated(DateTime? t) {
  if (t == null) return '--:--';
  return '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';
}

/// ChangeNotifier that gives screens stale-while-revalidate behaviour
/// without each screen re-implementing it:
///
/// ```dart
/// final feed = UpdateFeed(api);
/// await feed.backgroundRefresh(); // returns cache instantly,
/// // then refreshes in background and notifies listeners.
/// ```
class UpdateFeed extends ChangeNotifier {
  final ApiService api;
  List<CricketMatch> matches = const [];
  bool refreshing = false;
  DateTime? lastUpdated;
  Object? lastError;
  bool _disposed = false;

  UpdateFeed({ApiService? api}) : api = api ?? ApiService() {
    this.api.addMatchesListener(_onApiMatches);
  }

  void _onApiMatches(List<CricketMatch> fresh) {
    if (_disposed) return;
    matches = fresh;
    lastUpdated = DateTime.now();
    lastError = null;
    notifyListeners();
  }

  /// SWR: returns cached matches immediately (never blank), kicks off
  /// a background refresh, notifies when fresh data lands. The
  /// `refreshing` flag drives a SMALL top indicator, not a
  /// full-screen spinner.
  Future<List<CricketMatch>> backgroundRefresh() async {
    if (matches.isNotEmpty) {
      // Fire-and-forget background refresh; errors keep old data.
      unawaited(_refreshInBackground());
      return matches;
    }
    return refresh();
  }

  Future<void> _refreshInBackground() async {
    if (refreshing) return;
    refreshing = true;
    notifyListeners();
    try {
      final fresh = await api.fetchMatches(forceRefresh: true);
      if (_disposed) return;
      final changed = MatchDiff.changedIds(matches, fresh);
      matches = fresh;
      lastUpdated = DateTime.now();
      lastError = null;
      debugPrint(
          'KingCric SWR: ${fresh.length} matches, ${changed.length} changed');
    } catch (e) {
      // Keep old data; surface the stale timestamp, not a crash.
      lastError = e;
    } finally {
      if (!_disposed) {
        refreshing = false;
        notifyListeners();
      }
    }
  }

  /// Forced refresh (pull-to-refresh / Refresh button): bypasses the
  /// cache for THIS call only. Old list stays visible while it runs.
  Future<List<CricketMatch>> refresh() async {
    if (refreshing) return matches;
    refreshing = true;
    notifyListeners();
    try {
      final fresh = await api.fetchMatches(forceRefresh: true);
      if (_disposed) return matches;
      matches = fresh;
      lastUpdated = DateTime.now();
      lastError = null;
      return fresh;
    } catch (e) {
      lastError = e;
      return matches; // keep old data on failure
    } finally {
      if (!_disposed) {
        refreshing = false;
        notifyListeners();
      }
    }
  }

  /// One match only (Match Detail pull-to-refresh). Returns null when
  /// the refresh fails — the caller keeps the old match on screen.
  Future<CricketMatch?> refreshMatch(String matchId) async {
    try {
      final fresh =
          await api.fetchMatchDetail(matchId, forceRefresh: true);
      if (fresh != null && !_disposed) {
        final idx = matches.indexWhere((m) => m.id == matchId);
        if (idx >= 0) {
          final next = List<CricketMatch>.of(matches);
          next[idx] = fresh;
          matches = next;
        }
        lastUpdated = DateTime.now();
        lastError = null;
        notifyListeners();
      }
      return fresh;
    } catch (e) {
      lastError = e;
      return null;
    }
  }

  /// One player only (Player Profile pull-to-refresh).
  Future<Player?> refreshPlayer(String playerId) async {
    try {
      final fresh = await api.fetchPlayer(playerId, forceRefresh: true);
      if (fresh != null) {
        lastUpdated = DateTime.now();
        lastError = null;
        notifyListeners();
      }
      return fresh;
    } catch (e) {
      lastError = e;
      return null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    api.removeMatchesListener(_onApiMatches);
    super.dispose();
  }
}
