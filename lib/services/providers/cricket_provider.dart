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

  /// Upcoming fixtures ONLY (scheduled, not started), or null when
  /// the provider has no fixtures endpoint. Default is null so
  /// existing providers / test fakes keep compiling. The
  /// orchestrator merges this with [fetchMatches] so the Upcoming tab
  /// is never empty just because the "current matches" endpoint only
  /// returns live/recent games (CricAPI /currentMatches does exactly
  /// that — that was the Upcoming-empty bug).
  Future<List<CricketMatch>?> fetchUpcoming() async {
    return null;
  }

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
  ///
  /// [playerId] MUST be the provider's own player id (for CricAPI, the
  /// NUMERIC id from [resolvePlayerId]) — never a display name. The
  /// orchestrator resolves names to ids before calling this.
  Future<Player?> fetchPlayer(String playerId);

  /// Resolve a display name ("Virat Kohli") to this provider's player
  /// id, or null when the provider cannot resolve it. Providers that
  /// have no lookup return null. Never throws, never returns a
  /// wrong-player id: a match must be verified against the returned
  /// name before its id is used.
  Future<String?> resolvePlayerId(String name);

  /// Server-side quota remaining as reported by the provider's last
  /// response (`info.hitsLeft` for CricAPI), or null when the provider
  /// does not report it. In-memory hit counters are NOT a substitute:
  /// the server counts every hit, including ones from other sessions.
  int? get serverHitsLeft;

  /// True when the provider's last response said the server-side
  /// quota is exhausted (hitsLeft == 0 or an explicit quota error).
  /// The orchestrator stops calling such a provider instead of
  /// burning calls that can only return quota errors.
  bool get quotaExhausted;

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

  static MatchStatus statusFromText(String raw) => resolveStatus(
        raw: raw, matchStarted: null, matchEnded: null, hasScores: false);

  /// Resolve a match status from every signal a provider gives us.
  ///
  /// BUG FIX (V3 screenshots): CricAPI's `status` for an in-progress
  /// match reads like "Austria Women need 88 runs in 78 balls" — it
  /// contains neither "live" nor "won", so the old parser filed it as
  /// UPCOMING and the Live tab showed "No matches in this section."
  /// A match with runs on the board and no result IS in progress.
  ///
  /// Precedence: ended/result > started/scores/in-progress > upcoming.
  /// "not started" / "yet to start" / "scheduled" always win over any
  /// "started"-looking substring (e.g. "Match not started").
  static MatchStatus resolveStatus({
    required String raw,
    bool? matchStarted,
    bool? matchEnded,
    bool hasScores = false,
  }) {
    final s = raw.toLowerCase();
    if (matchEnded == true) return MatchStatus.completed;
    // Result phrases — check before in-progress ones ("won" also
    // appears in some live commentary, but "won by" is terminal).
    // NOTE: "won the" alone is NOT terminal — "won the toss" appears
    // on upcoming/live matches. Require "won the match".
    if (s.contains('won by') ||
        s.contains('won the match') ||
        s.contains('result') ||
        s.contains('finished') ||
        s.contains('completed') ||
        s.contains('match ended') ||
        s.contains('match drawn') ||
        s.contains('drawn') ||
        s.contains('no result') ||
        s.contains('abandoned')) {
      return MatchStatus.completed;
    }
    // Explicitly not started — must beat the "started" substring.
    if (s.contains('not started') ||
        s.contains('yet to start') ||
        s.contains('scheduled') ||
        s.contains('preview') ||
        s.contains('upcoming') ||
        s.contains('to be played')) {
      return MatchStatus.upcoming;
    }
    if (matchStarted == true) return MatchStatus.live;
    // Day-phase phrases (stumps / lunch / rain delay) only prove a
    // match is live if play has actually started (scores on the
    // board or matchStarted). A pre-toss "Rain delay" is upcoming.
    final playStarted = hasScores || matchStarted == true;
    if (playStarted &&
        (s.contains('stumps') ||
            s.contains('innings break') ||
            s.contains('lunch') ||
            s.contains('tea break') ||
            s.contains('rain delay'))) {
      return MatchStatus.live;
    }
    if (s.contains('live') ||
        s.contains('in play') ||
        s.contains('in progress') ||
        s.contains('playing') ||
        s.contains('need ') ||
        s.contains('needs ') ||
        s.contains('require') ||
        s.contains('trail') ||
        s.contains('lead by') ||
        s.contains('lead of') ||
        s.contains('day 1') ||
        s.contains('day 2') ||
        s.contains('day 3') ||
        s.contains('day 4') ||
        s.contains('day 5') ||
        s.contains('overs left') ||
        s.contains('balls left') ||
        s.contains('to win')) {
      return MatchStatus.live;
    }
    // Runs on the board + no result = in progress, whatever the
    // provider's status string says.
    if (hasScores) return MatchStatus.live;
    return MatchStatus.upcoming;
  }

  /// Title-case a team name ("bulgaria women" -> "Bulgaria Women").
  /// Short ALL-CAPS tokens (MI, CSK, IPL, USA) are abbreviations and
  /// are kept as-is. Longer ALL-CAPS words are title-cased.
  static String titleCaseTeam(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed.split(RegExp(r'\s+')).map((word) {
      if (word.isEmpty) return word;
      final isAllCaps =
          word == word.toUpperCase() && word.length <= 4;
      if (isAllCaps) return word;
      final first = word[0].toUpperCase();
      final rest = word.length > 1 ? word.substring(1).toLowerCase() : '';
      return '$first$rest';
    }).join(' ');
  }

  /// Clean a raw innings/team label into ONE team name.
  ///
  /// BUG FIX (V3 screenshots): the Recent tab showed
  /// "Bulgaria Women,Sweden Wo..." — a comma-joined pair of teams
  /// (CricAPI's `inning` label can carry both teams) rendered as if
  /// it were one team, plus lowercase ("bulgaria women Inning 1").
  ///
  /// Rules: if the label mentions exactly one of [teams], use it; if
  /// it mentions both, use the one mentioned LAST (closest to the
  /// "Inning N" suffix = the side that batted); otherwise strip the
  /// "Inning N" suffix, take the part before the first comma, and
  /// title-case it.
  static String cleanTeamName(String raw, [List<String>? teams]) {
    var s = raw.trim();
    if (s.isEmpty) return s;
    final known = (teams ?? []).where((t) => t.isNotEmpty).toList();
    if (known.isNotEmpty) {
      final lower = s.toLowerCase();
      // Pick the match at the HIGHEST index; break ties by LONGEST
      // name. Without the length tie-break, "India" (inside
      // "India Women") could overwrite "India Women" at the same index.
      String? bestMatch;
      var bestIndex = -1;
      var bestLen = -1;
      for (final t in known) {
        final idx = lower.lastIndexOf(t.toLowerCase());
        if (idx < 0) continue;
        if (idx > bestIndex || (idx == bestIndex && t.length > bestLen)) {
          bestIndex = idx;
          bestLen = t.length;
          bestMatch = t;
        }
      }
      if (bestMatch != null) return titleCaseTeam(bestMatch);
    }
    // Strip "Inning N" / "Innings N" suffix (case-insensitive).
    s = s.replaceAll(
        RegExp(r'\s+innings?\s*\d*\s*$', caseSensitive: false), '');
    // A comma-joined label ("A,B") is two teams, not one: keep the
    // last segment, which is the side closest to the innings marker.
    if (s.contains(',')) {
      s = s.split(',').last.trim();
    }
    return titleCaseTeam(s);
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
