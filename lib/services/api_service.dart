import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/match.dart';
import '../models/player.dart';
import '../models/venue.dart';
import '../utils/constants.dart';
import 'cricsheet_service.dart';
import 'mock_data_service.dart';
import 'providers/cricapi_provider.dart';
import 'providers/cricket_provider.dart';
import 'providers/elitesport_provider.dart';
import 'providers/entitysport_provider.dart';
import 'providers/sportscore_provider.dart';
import 'providers/thesportsdb_provider.dart';

/// Multi-source free-API layer — ONE interface, ALL free providers.
///
/// NEVER scrapes Cricbuzz / Cricinfo / Crex / Cricmetrics.
/// Talks only to free providers' documented JSON APIs. Keys come from
/// --dart-define (never hard-coded). See API-SETUP.md for the full
/// provider table, signup steps, and GitHub secrets.
///
/// ORDER (primary -> fallback):
///  1. CricAPI / CricketData.org — primary, full scorecards (needs key)
///  2. EliteSport — secondary, live + scorecard (needs key, testing tier)
///  3. EntitySport — tertiary, sample competitions (needs dev token)
///  4. SportScore — keyless backstop, scores only (+ attribution)
///  5. TheSportsDB — keyless metadata backstop (schedules, leagues)
///  6. Cache (last verified) -> Mock demo data (always works offline)
///
/// PLAYER DEEP STATS (fetchPlayer only): Cricsheet open ball-by-ball
/// data is tried FIRST — it is offline, costs zero quota, and is the
/// ONLY source in the stack that returns REAL calculated career /
/// vs-opponent / venue / matchup stats (see cricsheet_service.dart).
/// A Cricsheet-built profile has source='cricsheet' +
/// dataComplete=true + sourceMatches = dataset size, and is labelled
/// in the UI as real-but-sample-scoped. Provider basic profiles
/// (dataComplete=false) and mock demo profiles are only used when
/// Cricsheet has no data for that player. Never present demo as real.
///
/// CROSS-CHECK: when the primary succeeds, the orchestrator does NOT
/// burn quota re-fetching from every provider. It compares the
/// primary result against the CACHED result from another provider when
/// one exists (e.g. a previous fetch); on a score mismatch it keeps
/// the primary, logs the mismatch, and never crashes. If the primary
/// fails / is capped / is unconfigured, the next provider is tried.
///
/// QUOTA SAFETY: per-provider daily caps (see constants) + TTL caches
/// (live 10 min, completed 60 min). NEVER poll every 45s.
///
/// Screens use ONLY this class — they never learn which provider
/// answered. Swapping / adding a provider never touches a screen.
class _CacheEntry<T> {
  final T value;
  final DateTime expiresAt;
  final String source;
  _CacheEntry(this.value, this.expiresAt, this.source);
  bool get fresh => DateTime.now().isBefore(expiresAt);
}

/// Server-side quota state for the keyed providers (CricAPI).
/// - [keyMissing]: no keyed provider is configured — the app is in
///   demo/backstop mode by construction, not by failure.
/// - [quotaExhausted]: a provider's last response said the server
///   quota is gone (hitsLeft == 0 / quota error). Stop calling it.
/// - [ok]: at least one provider reported remaining quota.
/// - [unknown]: key configured but no provider has reported quota
///   yet (no successful call so far). UI shows no banner.
enum QuotaState { ok, keyMissing, quotaExhausted, unknown }

class ApiService {
  final MockDataService _mock = MockDataService();
  final List<CricketProvider> _providers;
  final CricsheetService? _cricsheetInjected;
  final bool _loadCricsheetSample;
  Future<CricsheetService>? _cricsheetFuture;

  _CacheEntry<List<CricketMatch>>? _matchesCache;
  final Map<String, _CacheEntry<CricketMatch>> _detailCache = {};
  final Map<String, _CacheEntry<Player>> _playerCache = {};
  _CacheEntry<List<Map<String, dynamic>>>? _seriesCache;

  /// Last provider that successfully answered (debug / UI label).
  String lastSource = 'mock';

  // ---- Smooth updates (stale-while-revalidate, dedup, freshness) ----
  // See smooth_update.dart for the full design. These fields let
  // screens show "Last updated HH:MM" from the service's own clock
  // instead of inventing a timestamp per screen.
  final List<void Function(List<CricketMatch>)> _matchesListeners = [];
  DateTime? lastMatchesUpdated;
  DateTime? lastDetailUpdated;
  DateTime? lastSeriesUpdated;
  DateTime? lastPlayerUpdated;

  /// Subscribe to fresh match lists (SWR background refresh +
  /// AutoUpdateService ticks). Listeners get the NEW list; they must
  /// never throw (a listener crash must not break the fetch path).
  void addMatchesListener(void Function(List<CricketMatch>) fn) =>
      _matchesListeners.add(fn);
  void removeMatchesListener(void Function(List<CricketMatch>) fn) =>
      _matchesListeners.remove(fn);

  void _notifyMatchesListeners(List<CricketMatch> fresh) {
    for (final fn in List.of(_matchesListeners)) {
      try {
        fn(fresh);
      } catch (_) {}
    }
  }

  /// TTL for one match: completed data never changes (60 min cache,
  /// effectively "never re-fetch"), live/upcoming use the 10-min
  /// live TTL. Re-fetching a finished scorecard is pure quota waste.
  static Duration ttlForMatch(CricketMatch m) =>
      m.status == MatchStatus.completed
          ? AppConstants.completedCacheTtl
          : AppConstants.liveCacheTtl;

  /// In-flight deduplication: concurrent callers (pull-to-refresh +
  /// auto-update tick + screen rebuild) share ONE network request
  /// instead of firing duplicates that burn quota and flicker the UI.
  Future<List<CricketMatch>>? _matchesInFlight;
  final Map<String, Future<CricketMatch?>> _scorecardInFlight = {};

  ApiService(
      {List<CricketProvider>? providers,
      http.Client? client,
      CricsheetService? cricsheet,
      bool loadCricsheetSample = true})
      : _cricsheetInjected = cricsheet,
        _loadCricsheetSample = loadCricsheetSample,
        _providers = providers ??
            [
              CricApiProvider(client: client),
              EliteSportProvider(client: client),
              EntitySportProvider(client: client),
              SportScoreProvider(client: client),
              TheSportsDbProvider(client: client),
            ];

  /// Providers that can run right now (keys present / keyless).
  List<CricketProvider> get configuredProviders =>
      _providers.where((p) => p.isConfigured).toList();

  /// True when a KEYED provider is configured (CricAPI / EliteSport /
  /// EntitySport). The Home screen uses this for the Demo banner:
  /// keyless backstops (SportScore / TheSportsDB) improve coverage but
  /// are backstop-grade, so the app still shows Demo until a real key
  /// is added. See [hasBackstop].
  bool get isLive =>
      AppConstants.hasApiKey ||
      AppConstants.eliteSportApiKey.isNotEmpty ||
      AppConstants.entitySportApiKey.isNotEmpty;

  /// True when any provider (keyed or keyless backstop) can run.
  bool get hasBackstop => configuredProviders.isNotEmpty;

  /// True when the primary (CricAPI) key is present — full scorecards.
  bool get hasPrimaryKey => AppConstants.hasApiKey;

  /// FIX-7: quota state from the providers' SERVER-side reports
  /// (see [CricketProvider.serverHitsLeft]), never from the
  /// in-memory hit counters alone. Screens show a DISTINCT banner
  /// for [QuotaState.keyMissing] vs [QuotaState.quotaExhausted]
  /// instead of silently degrading to demo data.
  QuotaState get quotaState {
    if (!isLive) return QuotaState.keyMissing;
    var sawQuotaInfo = false;
    for (final p in _providers) {
      if (!p.isConfigured) continue;
      if (p.quotaExhausted) return QuotaState.quotaExhausted;
      if (p.serverHitsLeft != null) sawQuotaInfo = true;
    }
    return sawQuotaInfo ? QuotaState.ok : QuotaState.unknown;
  }

  /// Resolved provider player ids, keyed by display name
  /// ("Virat Kohli" -> "253802"). Name resolution costs a hit, so it
  /// is cached for the session. Never stores keys.
  final Map<String, String> _playerIdCache = {};

  /// Lazily-loaded Cricsheet service (bundled sample, parsed once).
  /// Never throws: load failure -> empty service (no Cricsheet data).
  Future<CricsheetService> _cricsheet() {
    if (_cricsheetInjected != null) {
      return Future.value(_cricsheetInjected);
    }
    _cricsheetFuture ??= _loadCricsheetSample
        ? CricsheetService.loadBundled()
        : Future.value(CricsheetService.empty());
    return _cricsheetFuture!;
  }

  /// How many Cricsheet matches back the player profiles (0 = sample
  /// failed to load). For the UI source label. Never throws.
  Future<int> get cricsheetMatchCount async {
    try {
      return (await _cricsheet()).matchCount;
    } catch (_) {
      return 0;
    }
  }

  /// CRICSHEET-WIRING: Cricsheet-backed Squad / H2H / Venue /
  /// Matchups for a match. Screens call these — they never touch
  /// CricsheetService directly. All never throw: failure returns
  /// empty / zero / null and the screen falls back to mock /
  /// scorecard data with an honest label.

  /// Full Cricsheet squads for both teams, keyed by team name.
  /// [gender] ('male' / 'female') separates men's and women's
  /// squads, which Cricsheet stores under the same team names.
  Future<Map<String, List<Player>>> cricsheetSquadsFor(
      String teamA, String teamB,
      {String? format, String? gender}) async {
    try {
      final cs = await _cricsheet();
      return cs.squadForTeams(teamA, teamB,
          format: format, gender: gender);
    } catch (_) {
      return {teamA: const [], teamB: const []};
    }
  }

  /// Cricsheet team H2H: {matches, teamAWins, teamBWins, noResult}.
  Future<Map<String, int>> cricsheetHeadToHead(
      String teamA, String teamB,
      {String? format, String? gender}) async {
    try {
      final cs = await _cricsheet();
      return cs.teamHeadToHead(teamA, teamB,
          format: format, gender: gender);
    } catch (_) {
      return const {
        'matches': 0,
        'teamAWins': 0,
        'teamBWins': 0,
        'noResult': 0,
      };
    }
  }

  /// Cricsheet venue stats, or null when no bundled match was
  /// played at [venueName].
  Future<VenueStats?> cricsheetVenueStats(String venueName,
      {String? gender}) async {
    try {
      return (await _cricsheet()).venueStats(venueName, gender: gender);
    } catch (_) {
      return null;
    }
  }

  /// FINAL D — Ball-level data for visual-live widgets (ball strip,
  /// over summaries). Order of sources, cheapest + freshest first:
  /// 1. CricAPI live ball data — ONLY when the provider actually
  ///    returned per-ball events (totals-only yields empty and
  ///    falls through; the call is skipped entirely when the key
  ///    is missing or quota is exhausted, so it never burns quota
  ///    or flips the Home quota/demo banners).
  /// 2. Cricsheet bundled match on the same teams + format + day —
  ///    real deliveries, labelled 'cricsheet' with the dataset date.
  /// 3. Empty [MatchBallData] (hasBallData false) — widgets render
  ///    an honest no-data state, never synthesised balls. Never
  ///    throws. Pitch / weather are NOT part of this: free
  ///    providers supply neither, and the Venue tab keeps its
  ///    honest "Not available from free providers yet" lines.
  Future<MatchBallData> fetchBallData(CricketMatch match) async {
    try {
      for (final p in _providers) {
        if (p is CricApiProvider &&
            p.isConfigured &&
            !p.quotaExhausted) {
          final live = await p.fetchBallData(match.id);
          if (live.hasBallData) return live;
          break;
        }
      }
    } catch (_) {}
    try {
      final cs = await _cricsheet();
      return cs.ballDataForTeams(
        match.teamA,
        match.teamB,
        format: match.format,
        date: match.startTime,
      );
    } catch (_) {
      return const MatchBallData.empty();
    }
  }

  /// Cricsheet cross-squad bowler-vs-batter matchups for two
  /// resolved squads (bowler in one squad, batter in the other).
  Future<List<Matchup>> cricsheetCrossMatchups(
      List<Player> squadA, List<Player> squadB) async {
    try {
      return (await _cricsheet()).crossSquadMatchups(squadA, squadB);
    } catch (_) {
      return const [];
    }
  }

  int get cacheEntryCount =>
      (_matchesCache == null ? 0 : 1) +
      _detailCache.length +
      _playerCache.length +
      (_seriesCache == null ? 0 : 1);

  /// Per-provider hit counters, for quota debugging (never exposes keys).
  Map<String, int> get providerHits =>
      {for (final p in _providers) p.name: p.hitsToday};

  void clearCache() {
    _matchesCache = null;
    _detailCache.clear();
    _playerCache.clear();
    _seriesCache = null;
    _upcomingCache = null;
  }

  /// Cross-check helper: compare two match lists on (id -> runs).
  /// Returns true when they agree on every shared match. On mismatch
  /// the caller keeps the primary and logs — never throws, never
  /// replaces verified data with unverified data.
  static bool crossCheckMatches(
      List<CricketMatch> primary, List<CricketMatch> other) {
    try {
      final otherById = {for (final m in other) m.id: m};
      for (final m in primary) {
        final o = otherById[m.id];
        if (o == null) continue;
        for (var i = 0; i < m.scores.length && i < o.scores.length; i++) {
          if (m.scores[i].runs != o.scores[i].runs ||
              m.scores[i].wickets != o.scores[i].wickets) {
            debugPrint(
                'KingCric cross-check MISMATCH ${m.id}: '
                'primary ${m.scores[i].runs}/${m.scores[i].wickets} vs '
                'other ${o.scores[i].runs}/${o.scores[i].wickets}');
            return false;
          }
        }
      }
      return true;
    } catch (_) {
      return true; // cross-check must never break the fetch path
    }
  }

  /// Checks whether the PRIMARY key is accepted (1 cheap call).
  /// Falls back to "any configured provider answers" when no
  /// primary key is set. False = stay in demo/backstop mode, never crash.
  Future<bool> testApiKeyValidity({String? key}) async {
    // Explicit key = test CricAPI with it (used by Settings screen).
    if (key != null && key.trim().isNotEmpty) {
      // Test via a throwaway CricAPI-shaped call is not possible
      // without rebuilding the provider with the key (keys are
      // compile-time defines), so we report "configured key works"
      // based on the compiled-in provider instead.
      return _providers.first.testKey();
    }
    for (final p in _providers) {
      if (!p.isConfigured) continue;
      try {
        if (await p.testKey()) return true;
      } catch (_) {}
    }
    return false;
  }

  Future<List<CricketMatch>> fetchMatches(
      {bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _matchesCache != null &&
        _matchesCache!.fresh) {
      return _matchesCache!.value;
    }
    // Share one in-flight request across concurrent callers.
    final inFlight = _matchesInFlight;
    if (!forceRefresh && inFlight != null) return inFlight;
    final future = _fetchMatchesUncached();
    _matchesInFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_matchesInFlight, future)) _matchesInFlight = null;
    }
  }

  /// Merge several providers' match lists into ONE list.
  ///
  /// ROOT-CAUSE FIX (Live incomplete): the old code returned the FIRST
  /// provider's non-empty list and never looked at the others, so if
  /// CricAPI returned 1 live match the app showed 1 live match even
  /// when other providers knew more. Now every configured provider
  /// is asked and the results are merged.
  ///
  /// SINGLE DEFINITION: richness + dedupe live ONLY in [MatchMerge]
  /// (models/match.dart). This method is a thin pairwise loop over
  /// [MatchMerge.mergeCandidates] / [MatchMerge.pickRicher] — it
  /// must never re-implement richness, dedupe keys, or league
  /// compatibility, so every merge in the app uses ONE definition.
  /// - Same match from TWO providers merges; the RICHER entry wins.
  ///   The merged entry keeps the richer entry's id/scores/innings
  ///   so the scorecard fetch (keyed by id) still works.
  /// - Two DISTINCT matches from ONE provider (same teams/day/
  ///   format/league but different non-empty provider ids —
  ///   double-header, men + women, two series the same day) are
  ///   KEPT as two cards. Provider ids are not comparable ACROSS
  ///   providers (CricAPI uuid vs SportScore numeric vs TheSportsDB
  ///   idEvent), so id-based distinctness is only applied within
  ///   one provider.
  /// - A provider that reports no/generic league ('' /
  ///   'International' / 'Cricket') merges into the same fixture
  ///   reported WITH a league by a different provider — otherwise
  ///   every cross-provider fixture would double up.
  /// [providerNames], when given, must parallel [lists] (the
  /// orchestrator passes them). When omitted — Home merges its two
  /// already-merged lists [live, upcoming] this way — the effective
  /// provider falls back to each entry's own [CricketMatch.source],
  /// which providers tag. That fallback is what keeps same-teams/
  /// same-day double-headers distinct on the Home path too: without
  /// it the same-provider + different-id rule could not fire and
  /// the second fixture would collapse into the first.
  static List<CricketMatch> mergeMatches(
      List<List<CricketMatch>> lists,
      {List<String>? providerNames}) {
    final out = <CricketMatch>[];
    final outProviders = <String>[];
    for (var li = 0; li < lists.length; li++) {
      final listProvider =
          (providerNames != null && li < providerNames.length)
              ? providerNames[li]
              : null;
      for (final m in lists[li]) {
        final provider = listProvider ?? m.source;
        var mergedIndex = -1;
        for (var i = 0; i < out.length; i++) {
          if (MatchMerge.mergeCandidates(
            out[i],
            m,
            providerA: outProviders[i],
            providerB: provider,
          )) {
            mergedIndex = i;
            break;
          }
        }
        if (mergedIndex < 0) {
          out.add(m);
          outProviders.add(provider);
        } else {
          final kept = MatchMerge.pickRicher(out[mergedIndex], m);
          if (identical(kept, m)) outProviders[mergedIndex] = provider;
          out[mergedIndex] = kept;
        }
      }
    }
    return out;
  }



  Future<List<CricketMatch>> _fetchMatchesUncached() async {
    final collected = <List<CricketMatch>>[];
    final contributing = <String>[];
    for (final p in _providers) {
      if (!p.isConfigured) continue;
      try {
        final result = await p.fetchMatches();
        if (result != null && result.isNotEmpty) {
          collected.add(result);
          contributing.add(p.name);
        }
      } catch (_) {
        continue; // next provider
      }
    }
    if (collected.isNotEmpty) {
      final merged = mergeMatches(collected, providerNames: contributing);
      // Opportunistic cross-check vs cached other-provider data.
      if (_matchesCache != null) {
        crossCheckMatches(merged, _matchesCache!.value);
      }
      lastSource = contributing.length == 1 ? contributing.single : 'merged';
      lastMatchesUpdated = DateTime.now();
      _matchesCache = _CacheEntry<List<CricketMatch>>(
        merged,
        DateTime.now().add(AppConstants.liveCacheTtl),
        lastSource,
      );
      _notifyMatchesListeners(merged);
      debugPrint(
          'KingCric ApiService fetchMatches: providers=$contributing merged=${merged.length}');
      return merged;
    }
    if (_matchesCache != null) {
      // FIX-7: warm-cache stale path. The old code returned the stale
      // cache WITHOUT touching lastSource, so the quota/demo banner
      // never showed and stale data looked live. Stale cache served
      // after every provider failed IS a mock-grade fallback: say so.
      lastSource = 'mock';
      debugPrint(
          'KingCric ApiService fetchMatches: all providers empty — serving stale cache, lastSource=mock');
      return _matchesCache!.value;
    }
    lastSource = 'mock';
    return _mock.matches();
  }

  /// True when the last fetch fell back to mock/demo data even
  /// though a key is configured — i.e. quota exhausted / all
  /// providers down. Screens use this for an honest banner instead
  /// of silently showing demo as live.
  bool get lastFetchWasMock => lastSource == 'mock';

  _CacheEntry<List<CricketMatch>>? _upcomingCache;

  /// Upcoming fixtures from every provider that has a fixtures
  /// endpoint (CricAPI /matches, EliteSport /fixtures), merged +
  /// deduped the same way as [fetchMatches]. TheSportsDB has NO real
  /// fixtures endpoint in the free V1 API — its fetchUpcoming
  /// returns [] with zero calls (the old searchevents.php keyword
  /// title-search was junk as fixtures and is disabled).
  /// Cached 60 min: upcoming fixtures barely change, and CricAPI's
  /// 100-hits/day quota must not be spent re-fetching them every
  /// 10-min live refresh. Returns [] (never mock) when no provider
  /// has fixtures — the Home list already carries any mock upcoming.
  Future<List<CricketMatch>> fetchUpcoming(
      {bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _upcomingCache != null &&
        _upcomingCache!.fresh) {
      return _upcomingCache!.value;
    }
    final collected = <List<CricketMatch>>[];
    final contributing = <String>[];
    for (final p in _providers) {
      if (!p.isConfigured) continue;
      try {
        final result = await p.fetchUpcoming();
        if (result != null && result.isNotEmpty) {
          collected.add(result);
          contributing.add(p.name);
        }
      } catch (_) {
        continue;
      }
    }
    if (collected.isNotEmpty) {
      final merged = mergeMatches(collected, providerNames: contributing);
      debugPrint(
          'KingCric ApiService fetchUpcoming: providers=$contributing merged=${merged.length}');
      _upcomingCache = _CacheEntry<List<CricketMatch>>(
        merged,
        DateTime.now().add(const Duration(minutes: 60)),
        'merged',
      );
      return merged;
    }
    if (_upcomingCache != null) return _upcomingCache!.value;
    return const [];
  }

  /// Stale-while-revalidate: returns the cached list IMMEDIATELY
  /// (never blank), then refreshes in the background and calls
  /// [onUpdated] with the fresh list. If there is no cache, behaves
  /// like a normal fetch. Screens show the old list + a small
  /// "refreshing" indicator while the background fetch runs — no
  /// full-screen spinner, no flicker.
  Future<List<CricketMatch>> refreshMatchesInBackground(
      {void Function(List<CricketMatch>)? onUpdated}) async {
    final cached = _matchesCache;
    if (cached != null) {
      // Fire-and-forget: errors keep the cached data.
      unawaited(fetchMatches(forceRefresh: true).then((fresh) {
        onUpdated?.call(fresh);
      }).catchError((_) {}));
      return cached.value;
    }
    final fresh = await fetchMatches(forceRefresh: true);
    onUpdated?.call(fresh);
    return fresh;
  }

  Future<CricketMatch?> fetchMatchDetail(String matchId,
      {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _detailCache[matchId];
      if (cached != null && cached.fresh) return cached.value;
    }
    final viaScorecard = await fetchScorecard(matchId,
        forceRefresh: forceRefresh);
    if (viaScorecard != null) {
      final ttl = viaScorecard.status == MatchStatus.completed
          ? AppConstants.completedCacheTtl
          : AppConstants.liveCacheTtl;
      _detailCache[matchId] = _CacheEntry<CricketMatch>(
        viaScorecard,
        DateTime.now().add(ttl),
        lastSource,
      );
      return viaScorecard;
    }
    final all = await fetchMatches(forceRefresh: forceRefresh);
    for (final m in all) {
      if (m.id == matchId) {
        _detailCache[matchId] = _CacheEntry<CricketMatch>(
          m,
          DateTime.now().add(AppConstants.liveCacheTtl),
          lastSource,
        );
        return m;
      }
    }
    return null;
  }

  Future<CricketMatch?> fetchScorecard(String matchId,
      {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _detailCache[matchId];
      if (cached != null && cached.fresh) return cached.value;
      final inFlight = _scorecardInFlight[matchId];
      if (inFlight != null) return inFlight;
    }
    // Cache the fetched scorecard (completed = 60 min, live = 10 min)
    // so repeated opens of the same match do NOT burn quota, and
    // concurrent callers share one request.
    final future = _fetchScorecardUncached(matchId);
    _scorecardInFlight[matchId] = future;
    try {
      final result = await future;
      if (result != null) {
        lastDetailUpdated = DateTime.now();
        final ttl = result.status == MatchStatus.completed
            ? AppConstants.completedCacheTtl
            : AppConstants.liveCacheTtl;
        _detailCache[matchId] = _CacheEntry<CricketMatch>(
          result,
          DateTime.now().add(ttl),
          lastSource,
        );
      }
      return result;
    } finally {
      if (identical(_scorecardInFlight[matchId], future)) {
        _scorecardInFlight.remove(matchId);
      }
    }
  }

  Future<CricketMatch?> _fetchScorecardUncached(String matchId) async {
    for (final p in _providers) {
      if (!p.isConfigured) continue;
      try {
        final result = await p.fetchScorecard(matchId);
        if (result != null) {
          lastSource = p.name;
          return result;
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> fetchSeries(
      {bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _seriesCache != null &&
        _seriesCache!.fresh) {
      return _seriesCache!.value;
    }
    for (final p in _providers) {
      if (!p.isConfigured) continue;
      try {
        final result = await p.fetchSeries();
        if (result != null && result.isNotEmpty) {
          lastSource = p.name;
          lastSeriesUpdated = DateTime.now();
          _seriesCache = _CacheEntry<List<Map<String, dynamic>>>(
            result,
            DateTime.now().add(AppConstants.completedCacheTtl),
            p.name,
          );
          return result;
        }
      } catch (_) {
        continue;
      }
    }
    if (_seriesCache != null) return _seriesCache!.value;
    return _mockSeries();
  }

  List<Map<String, dynamic>> _mockSeries() => const [
        {'id': 's-intl', 'name': 'International', 'matches': 3},
        {'id': 's-ipl', 'name': 'IPL', 'matches': 1},
        {'id': 's-bbl', 'name': 'Big Bash', 'matches': 1},
      ];

  Future<Player?> fetchPlayer(String playerId,
      {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _playerCache[playerId];
      if (cached != null && cached.fresh) return cached.value;
    }
    // 0. Cricsheet FIRST (offline, zero quota): real calculated stats.
    try {
      final cs = await _cricsheet();
      final real = cs.playerById(playerId);
      if (real != null) {
        lastSource = 'cricsheet';
        lastPlayerUpdated = DateTime.now();
        _playerCache[playerId] = _CacheEntry<Player>(
          real,
          DateTime.now().add(AppConstants.completedCacheTtl),
          'cricsheet',
        );
        return real;
      }
    } catch (_) {}
    // FIX-7: providers need their OWN player id (CricAPI: numeric).
    // A display name ('Virat Kohli', 'scorecard-Aiden Markram') is
    // resolved to that id first — sending a name verbatim to
    // `players_info?id=` could never match. Resolution is cached.
    for (final p in _providers) {
      if (!p.isConfigured) continue;
      try {
        var pid = playerId;
        if (!_isNumericId(pid)) {
          final display = _displayName(pid);
          pid = _playerIdCache[display] ?? '';
          if (pid.isEmpty) {
            final resolved = await p.resolvePlayerId(display);
            if (resolved == null || resolved.isEmpty) continue;
            pid = resolved;
            _playerIdCache[display] = pid;
          }
        }
        final result = await p.fetchPlayer(pid);
        if (result != null) {
          lastSource = p.name;
          lastPlayerUpdated = DateTime.now();
          _playerCache[playerId] = _CacheEntry<Player>(
            result,
            DateTime.now().add(AppConstants.completedCacheTtl),
            p.name,
          );
          return result;
        }
      } catch (_) {
        continue;
      }
    }
    return _mock.playerById(playerId);
  }

  static bool _isNumericId(String s) => RegExp(r'^\d+$').hasMatch(s.trim());

  /// 'scorecard-Aiden Markram' -> 'Aiden Markram'. Anything else
  /// passes through unchanged.
  static String _displayName(String idOrName) {
    const prefix = 'scorecard-';
    if (idOrName.startsWith(prefix)) {
      return idOrName.substring(prefix.length);
    }
    return idOrName;
  }

  Future<List<Player>> fetchPlayers() async {
    // No free tier offers a bulk player endpoint; reuse the curated
    // list and let fetchPlayer enrich one-by-one on profile open.
    return _mock.players();
  }

  Future<List<Venue>> fetchVenues() async => _mock.venues();
}
