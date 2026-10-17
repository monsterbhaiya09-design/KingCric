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
class AutoUpdateService {
  final ApiService _api;
  Timer? _timer;
  final Map<String, MatchStatus> _lastKnown = {};
  final List<void Function(CricketMatch finished)> _listeners = [];

  AutoUpdateService({ApiService? api}) : _api = api ?? ApiService();

  void addFinishedListener(void Function(CricketMatch) fn) =>
      _listeners.add(fn);

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

  /// One poll cycle. Public so tests / manual refresh can call it.
  /// NEVER throws: all failures are swallowed so a flaky network /
  /// bad payload can never kill the app process.
  Future<void> tick() async {
    try {
      await _tickInner();
    } catch (_) {
      // Best-effort polling only; keep last verified data.
    }
  }

  Future<void> _tickInner() async {
    final matches = await _api.fetchMatches();
    for (final m in matches) {
      final prev = _lastKnown[m.id];
      _lastKnown[m.id] = m.status;
      if (prev == null) continue; // first sighting: no transition yet
      if (prev != MatchStatus.completed &&
          m.status == MatchStatus.completed) {
        // Match just finished: fetch full detail + validate.
        final detail =
            await _api.fetchMatchDetail(m.id) ?? m;
        if (!CompletenessValidator.inningsReconciles(detail)) {
          // Keep last verified data; do not propagate a bad scorecard.
          continue;
        }
        for (final fn in _listeners) {
          fn(detail);
        }
      }
    }
  }

  /// How long ago the service last polled (for "Last updated" UI).
  DateTime lastPoll = DateTime.now();

  void dispose() => stop();
}
