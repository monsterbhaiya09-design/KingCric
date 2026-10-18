import '../../models/match.dart';
import '../../models/player.dart';

/// One cricket-data provider behind the unified [ApiService] interface.
///
/// Rules every provider MUST follow:
/// - NEVER throw. Return null / [] on any error, timeout, bad shape,
///   quota exhaustion, or wrong base URL. The orchestrator falls back.
/// - NEVER hard-code a key. Keys come from --dart-define via constants.
/// - NEVER scrape Cricbuzz / Cricinfo / Crex / Cricmetrics.
/// - Track [hitsToday] and stop calling once [dailyCap] is hit.
/// - Parse defensively: unknown/missing fields default to empty/0 so a
///   partial provider response can never crash the scoreboard.
abstract class CricketProvider {
  /// Human name used in logs / debug ("CricAPI", "SportScore", ...).
  String get name;

  /// False when this provider cannot run (e.g. key missing).
  /// Keyless providers (SportScore, TheSportsDB test key) are always true.
  bool get isConfigured;

  /// Self-imposed daily cap (below the provider's real limit).
  int get dailyCap;

  /// HTTP calls made by this provider today (in-memory, per app run).
  int get hitsToday;

  /// Live / upcoming / recent matches, or null when unavailable.
  Future<List<CricketMatch>?> fetchMatches();

  /// Full scorecard for one match, or null when unavailable
  /// (upcoming match, no scorecard yet, provider error).
  Future<CricketMatch?> fetchScorecard(String matchId);

  /// Series list entries: {id, name, startDate, endDate, matches}.
  Future<List<Map<String, dynamic>>?> fetchSeries();

  /// Basic player profile, or null. Deep career / vs-opponent / venue /
  /// matchup stats are NOT expected from any free provider — providers
  /// return the basic profile with dataComplete=false and the
  /// orchestrator keeps the curated dataset for the deep sections,
  /// labelled as such. Never present partial data as complete.
  Future<Player?> fetchPlayer(String playerId);

  /// True when the provider accepts its configured key (1 cheap call).
  /// Keyless providers return true when their base URL answers.
  Future<bool> testKey();
}

/// Shared parsing helpers. All helpers are null-safe and never throw.
class ProviderParsing {
  /// "192/6" -> (192, 6). "192" -> (192, 0). Anything else -> (0, 0).
  static (int runs, int wickets) parseScoreString(Object? raw) {
    if (raw == null) return (0, 0);
    if (raw is num) return (raw.toInt(), 0);
    final s = '$raw'.trim();
    if (s.isEmpty || s == '-') return (0, 0);
    final parts = s.split('/');
    final runs = int.tryParse(parts[0].replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final wickets =
        parts.length > 1 ? int.tryParse(parts[1].replaceAll(RegExp(r'[^0-9]'), '')) ?? 0 : 0;
    return (runs, wickets);
  }

  static MatchStatus statusFromText(String raw) {
    final s = raw.toLowerCase();
    if (s.contains('live') ||
        s.contains('in play') ||
        s.contains('in progress') ||
        s.contains('playing')) {
      return MatchStatus.live;
    }
    if (s.contains('won') ||
        s.contains('result') ||
        s.contains('finished') ||
        s.contains('completed') ||
        s.contains('match ended')) {
      return MatchStatus.completed;
    }
    return MatchStatus.upcoming;
  }

  static double toDouble(Object? v, [double fallback = 0]) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fallback;
    return fallback;
  }

  static int toInt(Object? v, [int fallback = 0]) {
    if (v is num) return v.toInt();
    if (v is String) {
      return int.tryParse(v.replaceAll(RegExp(r'[^0-9-]'), '')) ?? fallback;
    }
    return fallback;
  }

  static String toStr(Object? v, [String fallback = '']) {
    if (v == null) return fallback;
    return '$v';
  }
}
