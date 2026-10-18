import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/match.dart';
import '../models/player.dart';
import '../models/venue.dart';
import '../utils/constants.dart';
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

class ApiService {
  final MockDataService _mock = MockDataService();
  final List<CricketProvider> _providers;

  _CacheEntry<List<CricketMatch>>? _matchesCache;
  final Map<String, _CacheEntry<CricketMatch>> _detailCache = {};
  final Map<String, _CacheEntry<Player>> _playerCache = {};
  _CacheEntry<List<Map<String, dynamic>>>? _seriesCache;

  /// Last provider that successfully answered (debug / UI label).
  String lastSource = 'mock';

  ApiService({List<CricketProvider>? providers, http.Client? client})
      : _providers = providers ??
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
    for (final p in _providers) {
      if (!p.isConfigured) continue;
      try {
        final result = await p.fetchMatches();
        if (result != null && result.isNotEmpty) {
          // Opportunistic cross-check vs cached other-provider data.
          if (_matchesCache != null &&
              _matchesCache!.source != p.name) {
            crossCheckMatches(result, _matchesCache!.value);
          }
          lastSource = p.name;
          _matchesCache = _CacheEntry<List<CricketMatch>>(
            result,
            DateTime.now().add(AppConstants.liveCacheTtl),
            p.name,
          );
          return result;
        }
      } catch (_) {
        continue; // next provider
      }
    }
    if (_matchesCache != null) return _matchesCache!.value;
    lastSource = 'mock';
    return _mock.matches();
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
    }
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
    for (final p in _providers) {
      if (!p.isConfigured) continue;
      try {
        final result = await p.fetchPlayer(playerId);
        if (result != null) {
          lastSource = p.name;
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

  Future<List<Player>> fetchPlayers() async {
    // No free tier offers a bulk player endpoint; reuse the curated
    // list and let fetchPlayer enrich one-by-one on profile open.
    return _mock.players();
  }

  Future<List<Venue>> fetchVenues() async => _mock.venues();
}
