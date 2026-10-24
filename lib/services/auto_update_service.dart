import 'dart:async';
import '../models/match.dart';
import '../utils/constants.dart';
import 'api_service.dart';
import 'completeness_validator.dart';

/// Auto-update: "match khatam hote hi data hatho-hath update".
///
/// Behaviour:
/// - Live matches are polled on [AppConstants.livePollInterval].
/// - When a match flips to completed, the service fetches its final
///   scorecard once, validates it, and emits it via [onMatchFinished]
///   so the UI / derived stats (career, vs opponent, venue, H2H,
///   recent form, prediction inputs) can recalculate immediately.
/// - Verified data is never replaced by unverified data: if the fresh
///   fetch fails validation, the last verified copy is kept and the
///   callback is NOT fired with bad data.
///
/// In this scaffold the service is driven by [ApiService] (mock in
/// demo mode, free API in live mode). A production build would run the
/// same logic in a background isolate / WorkManager + Firebase
/// Function so updates arrive even when the app is closed.
/// MANUAL pre-match refresh (Squad D, user rule): there is NO
/// automatic pre-match refresh in this app — no timer, no
/// refresh-on-resume for this feature. The UI shows a BUTTON; only
/// when the user presses it does [AutoUpdateService.refreshMatchData]
/// run. Not calling it leaves every cache exactly as before.
class AutoUpdateService {
  final ApiService _api;
  Timer? _timer;
  final Map<String, MatchStatus> _lastKnown = {};
  final List<void Function(CricketMatch finished)> _listeners = [];

  /// Re-entrancy guard: a slow fetch must never let two ticks overlap
  /// and fire the same finished-match event twice.
  bool _ticking = false;

  AutoUpdateService({ApiService? api}) : _api = api ?? ApiService();

  void addFinishedListener(void Function(CricketMatch) fn) =>
      _listeners.add(fn);

  /// Fired on EVERY successful poll with the fresh list (not just on
  /// finish). Screens use it for incremental updates: only matches
  /// whose score changed re-render. Never throws.
  final List<void Function(List<CricketMatch> matches)> _matchesListeners =
      [];
  void addMatchesListener(void Function(List<CricketMatch>) fn) =>
      _matchesListeners.add(fn);
  void removeMatchesListener(void Function(List<CricketMatch>) fn) =>
      _matchesListeners.remove(fn);

  /// App returned from background (AppLifecycleState.resumed):
  /// refresh ONLY when a live match exists. Upcoming/series/
  /// completed data is already cached with long TTLs — re-fetching
  /// it on every resume would burn quota for zero new information.
  Future<void> resume() async {
    try {
      final matches = await _api.fetchMatches();
      if (matches.any((m) => m.isEffectivelyLive)) {
        await tick();
      } else {
        for (final fn in List.of(_matchesListeners)) {
          try {
            fn(matches);
          } catch (_) {}
        }
      }
    } catch (_) {
      // Resume refresh is best-effort; cached data stays on screen.
    }
  }

  /// Refresh live matches only (manual refresh). Completed matches
  /// are served from the 60-min cache, never re-fetched — finished
  /// data cannot change.
  Future<void> refreshLiveOnly() async {
    try {
      await _api.fetchMatches(forceRefresh: true);
    } catch (_) {}
  }

  void start() {
    stop();
    // Fully guarded: a background poller must NEVER crash startup.
    // Every tick is try/catch-wrapped (see tick()).
    try {
      _timer =
          Timer.periodic(AppConstants.livePollInterval, (_) => tick());
      // First tick immediately so the home screen is never empty.
      // Deliberately un-awaited + guarded: tick() never throws.
      unawaited(tick());
    } catch (_) {
      // If even the timer cannot be created, the app still runs
      // on its initial mock data; polling is best-effort only.
    }
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// True while the periodic poller is armed. Testable; also lets
  /// callers avoid double-starting (start() already stops first,
  /// so this is a read-only signal, not a lock).
  bool get isRunning => _timer != null;

  /// One poll cycle. Public so tests / manual refresh can call it.
  /// NEVER throws: all failures are swallowed so a flaky network /
  /// bad payload can never kill the app process.
  Future<void> tick() async {
    // Skip overlapping ticks instead of stacking network calls.
    if (_ticking) return;
    _ticking = true;
    try {
      await _tickInner();
    } catch (_) {
      // Best-effort polling only; keep last verified data.
    } finally {
      _ticking = false;
    }
  }

  Future<void> _tickInner() async {
    // forceRefresh: true is REQUIRED here. A plain fetchMatches()
    // returns the 10-min TTL cache, which makes every poll inside
    // the TTL window return the SAME list — finish transitions
    // would never be seen and the poller would be a no-op (the
    // same bug Home had with Refresh). The tick interval already
    // equals the TTL (10 min), so this costs one call per tick,
    // exactly the quota the cache was designed around.
    final matches = await _api.fetchMatches(forceRefresh: true);
    lastPoll = DateTime.now();
    for (final fn in List.of(_matchesListeners)) {
      try {
        fn(matches);
      } catch (_) {}
    }
    for (final m in matches) {
      // Effective status: a match whose status field lags but whose
      // result already says "won by ..." IS completed (Squad E
      // status truth). Comparing raw status would miss that finish.
      final effective =
          m.isCompleted ? MatchStatus.completed : m.status;
      final prev = _lastKnown[m.id];
      _lastKnown[m.id] = effective;
      if (prev == null) continue; // first sighting: no transition yet
      if (prev != MatchStatus.completed &&
          effective == MatchStatus.completed) {
        // Match just finished: fetch the FINAL scorecard fresh
        // (forceRefresh: a cached live snapshot is stale by design).
        final detail = await _api.fetchMatchDetail(m.id,
                forceRefresh: true) ??
            m;
        if (!CompletenessValidator.inningsReconciles(detail)) {
          // Keep last verified data; do not propagate a bad scorecard.
          continue;
        }
        for (final fn in _listeners) {
          try {
            fn(detail);
          } catch (_) {
            // One bad listener must never break the others / the tick.
          }
        }
      }
    }
  }

  /// MANUAL refresh of one match's data (button-pressed only).
  ///
  /// What it does, in order:
  /// 1. Force-refreshes the match detail via ApiService, BYPASSING
  ///    the cache (forceRefresh: true) — this is the only way fresh
  ///    pre-match data (toss, venue, status, provider squads when
  ///    the provider supplies them) enters the app for this match.
  /// 2. Recomputes ("warms") the match's squad / H2H / venue
  ///    aggregates from base + delta through ApiService, so opening
  ///    the match afterwards shows fresh squads/stats immediately.
  ///
  /// What it does NOT do: it never runs on a timer, never runs on
  /// resume, never fires finish listeners, and never counts
  /// anything twice — detail caching is an overwrite and squad
  /// aggregates are pure functions of base + delta, so pressing
  /// twice yields byte-identical data, not doubled totals. Delta
  /// application for finished matches stays on the finish-event
  /// path (dedupe by match id there); this method only refreshes
  /// and warms.
  ///
  /// Honest failure reasons (never fake data): quota exhausted ->
  /// old data kept, no call burned; provider returns nothing
  /// (offline, or the provider has no scorecard for this match yet)
  /// -> old data kept. Provider pre-match supply, honestly: free
  /// providers expose teams / venue / toss / status; the OFFICIAL
  /// XI is only exposed at/after toss when the provider carries it
  /// — when it does not, squads stay archive-based and labelled by
  /// source (see CricsheetService). An XI is never invented.
  Future<ManualRefreshResult> refreshMatchData(
      CricketMatch match) async {
    try {
      if (_api.quotaState == QuotaState.quotaExhausted) {
        return ManualRefreshResult.failure(
            ManualRefreshReason.quotaExhausted);
      }
      final detail =
          await _api.fetchMatchDetail(match.id, forceRefresh: true);
      if (detail == null) {
        if (_api.quotaState == QuotaState.quotaExhausted) {
          return ManualRefreshResult.failure(
              ManualRefreshReason.quotaExhausted);
        }
        return ManualRefreshResult.failure(ManualRefreshReason.noData);
      }
      // Warm aggregates from base + delta (best-effort each).
      try {
        await _api.cricsheetSquadsFor(detail.teamA, detail.teamB);
      } catch (_) {}
      try {
        await _api.cricsheetHeadToHead(detail.teamA, detail.teamB);
      } catch (_) {}
      try {
        if (detail.venueName.isNotEmpty) {
          await _api.cricsheetVenueStats(detail.venueName);
        }
      } catch (_) {}
      return ManualRefreshResult.success(detail);
    } catch (_) {
      return ManualRefreshResult.failure(ManualRefreshReason.noData);
    }
  }

  /// How long ago the service last polled (for "Last updated" UI).
  DateTime lastPoll = DateTime.now();

  void dispose() => stop();
}

/// Result of [AutoUpdateService.refreshMatchData].
enum ManualRefreshReason {
  none,
  quotaExhausted,
  noData,
}

class ManualRefreshResult {
  final bool success;
  final CricketMatch? detail;
  final ManualRefreshReason reason;

  const ManualRefreshResult._(this.success, this.detail, this.reason);

  factory ManualRefreshResult.success(CricketMatch detail) =>
      ManualRefreshResult._(true, detail, ManualRefreshReason.none);

  factory ManualRefreshResult.failure(ManualRefreshReason reason) =>
      ManualRefreshResult._(false, null, reason);

  /// Human-readable reason for UI. Success has no reason text.
  String get message {
    switch (reason) {
      case ManualRefreshReason.quotaExhausted:
        return 'Daily API quota exhausted — old data kept.';
      case ManualRefreshReason.noData:
        return 'No data from provider (offline, or provider has no '
            'scorecard for this match yet) — old data kept.';
      case ManualRefreshReason.none:
        return '';
    }
  }
}
