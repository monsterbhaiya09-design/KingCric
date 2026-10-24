import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/match.dart';
import '../services/api_service.dart';
import '../utils/app_theme.dart';
import '../utils/strings.dart';
import '../utils/constants.dart';
import '../widgets/language_toggle.dart';
import '../widgets/empty_state.dart';
import '../widgets/match_card.dart';
import '../widgets/premium_widgets.dart';
import 'match_detail_screen.dart';

/// V2 Home — PREMIUM King look: gradient hero, live pulse, bold scores,
/// gold borders, animated match cards. Same navigation, richer visuals.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ApiService _api;
  final TextEditingController _searchController = TextEditingController();
  List<CricketMatch> _matches = [];
  bool _loading = true;
  bool _offline = false;
  bool _loadingMatches = false;
  String _filter = 'live';
  String _query = '';
  String _formatFilter = 'All';
  DateTime? _lastUpdated;

  @override
  void initState() {
    super.initState();
    _api = ApiService();
    // MATCH-CENTRIC: Home shows matches ONLY. Players appear only
    // inside a match (Squad tab) — no Trending Players section here.
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// [force] = user explicitly pulled / tapped Refresh: bypass the
  /// 10-min cache, otherwise a refresh inside the TTL window was a
  /// no-op and the user saw the same stale list (reported bug).
  Future<void> _load({bool force = false}) async {
    if (_loadingMatches) return;
    _loadingMatches = true;
    // Only show the full-page spinner on first load; refreshes keep
    // the last verified list on screen (G4 offline behaviour).
    if (_matches.isEmpty) {
      setState(() => _loading = true);
    }
    try {
      final m = await _api.fetchMatches(forceRefresh: force);
      // Upcoming fixtures live in a separate 60-min cache (they are
      // NOT in CricAPI /currentMatches). Merge them in so the
      // Upcoming tab is real, not empty.
      final upcoming = await _api.fetchUpcoming(forceRefresh: force);
      final merged = ApiService.mergeMatches([m, upcoming]);
      if (!mounted) return;
      setState(() {
        _matches = merged;
        _loading = false;
        _offline = false;
        // SQUAD B: "Last updated" shows the SERVICE's own fetch
        // timestamp, not the wall clock. A cache/mock serve must not
        // advance the clock and pretend the data is fresh. Falls back
        // to the previous timestamp, then to now on first load.
        _lastUpdated =
            _api.lastMatchesUpdated ?? _lastUpdated ?? DateTime.now();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        // Keep last verified data; say so (G4). Only "offline" if we
        // already have data — otherwise the empty state explains it.
        _offline = _matches.isNotEmpty;
      });
    } finally {
      _loadingMatches = false;
    }
  }

  List<CricketMatch> get _visible {
    var list = _matches.where((m) {
      // V3 BUG FIX: use isEffectivelyLive — a match with scores on the
      // board is live even if a provider mislabelled it upcoming.
      if (_filter == 'live') return m.isEffectivelyLive;
      if (_filter == 'upcoming') {
        return m.status == MatchStatus.upcoming && !m.isEffectivelyLive;
      }
      return m.isCompleted;
    }).toList();
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      // H6: search team / league / venue / full fixture title.
      list = list
          .where((m) =>
              m.teamA.toLowerCase().contains(q) ||
              m.teamB.toLowerCase().contains(q) ||
              m.title.toLowerCase().contains(q) ||
              m.league.toLowerCase().contains(q) ||
              m.venueName.toLowerCase().contains(q))
          .toList();
    }
    // Format filter (All / Test / ODI / T20 / T10).
    if (_formatFilter != 'All') {
      list = list.where((m) => m.format == _formatFilter).toList();
    }
    // Sort: Live = most recently updated first; Upcoming = start
    // time ascending; Finished = end/start time descending.
    if (_filter == 'live') {
      list.sort((a, b) => (b.lastUpdated ?? b.startTime)
          .compareTo(a.lastUpdated ?? a.startTime));
    } else if (_filter == 'upcoming') {
      list.sort((a, b) => a.startTime.compareTo(b.startTime));
    } else {
      list.sort((a, b) => b.startTime.compareTo(a.startTime));
    }
    return list;
  }

  /// H1: when the Live tab is empty, the next upcoming match is shown
  /// directly below the empty state — never a dead blank screen.
  /// Respects the format filter; ignores the text query (the query
  /// empty state has its own message).
  CricketMatch? get _nextUpcoming {
    final upcoming = _matches
        .where((m) =>
            m.status == MatchStatus.upcoming && !m.isEffectivelyLive)
        .toList();
    if (_formatFilter != 'All') {
      upcoming.retainWhere((m) => m.format == _formatFilter);
    }
    if (upcoming.isEmpty) return null;
    upcoming.sort((a, b) => a.startTime.compareTo(b.startTime));
    return upcoming.first;
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    return RefreshIndicator(
      onRefresh: () => _load(force: true),
      // Always scrollable so pull-to-refresh works even with a
      // short list (otherwise a 1-card list can never refresh).
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(14),
        children: [
          // Premium header — gold crown + gradient title.
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.heroCard(),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: AppTheme.goldGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.gold.withValues(alpha: 0.5),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Text('👑',
                      style: TextStyle(fontSize: 26)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // V3 BUG FIX: "King..." truncation. FittedBox
                      // scales "KingCric" down instead of ellipsising
                      // it, so the full app name always shows.
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(lang.t('app_name'),
                            maxLines: 1,
                            softWrap: false,
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5)),
                      ),
                      Text(lang.t('tagline'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppTheme.goldSoft, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const LanguageToggle(),
              ],
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _query = v),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: lang.t('search_hint'),
              prefixIcon: const Icon(Icons.search, color: AppTheme.goldLight),
              // Clear button: one tap resets the filter (no dead query).
              suffixIcon: _query.isEmpty
                  ? null
                  : Semantics(
                      button: true,
                      label: lang.isHindi ? 'खोज साफ़ करें' : 'Clear search',
                      child: IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        tooltip: lang.isHindi ? 'साफ़ करें' : 'Clear',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
                    ),
              filled: true,
              fillColor: AppTheme.navyCard,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                      color: AppTheme.gold.withValues(alpha: 0.35))),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                      color: AppTheme.gold.withValues(alpha: 0.25))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppTheme.gold)),
            ),
          ),
          const SizedBox(height: 10),
          // SQUAD B: four banners, four DISTINCT looks — never silent
          // degrade, never two states in the same amber box.
          // (a) No key configured -> demo mode by construction.
          // (b) Server-side quota exhausted -> last verified data +
          // explicit quota message. (c) Last fetch fell back to
          // demo/stale (all providers down) -> demo banner
          // REGARDLESS of key presence. (d) Offline -> last
          // verified data stays on screen, user told why stale.
          if (_api.quotaState == QuotaState.keyMissing)
            _HomeBanner(
              color: AppTheme.red,
              icon: Icons.key_off,
              semanticsLabel: 'API key missing, showing demo data',
              child: Text(lang.t('mock_mode'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12)),
            ),
          if (_api.quotaState == QuotaState.quotaExhausted && !_loading)
            const _HomeBanner(
              color: AppTheme.amber,
              icon: Icons.hourglass_bottom,
              semanticsLabel:
                  'Daily API quota exhausted, showing last verified data',
              child: Text(
                  'Daily API quota exhausted (server reported 0 hits '
                  'left) — showing last verified data. Live data '
                  'resumes when the daily quota resets. Pull to '
                  'refresh later.',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12)),
            ),
          if (_api.quotaState != QuotaState.quotaExhausted &&
              _api.lastFetchWasMock &&
              !_loading)
            const _HomeBanner(
              color: AppTheme.textMuted,
              icon: Icons.info_outline,
              semanticsLabel:
                  'Live data unavailable, showing demo data',
              child: Text(
                  'Live data unavailable right now — showing demo / '
                  'last verified data. Pull to refresh later.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12)),
            ),
          if (_offline)
            _HomeBanner(
              color: AppTheme.blue,
              icon: Icons.wifi_off,
              semanticsLabel: 'Offline, showing last verified data',
              child: Text(lang.t('offline_banner'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12)),
            ),
          const SizedBox(height: 12),
          // V3 BUG FIX: SegmentedButton wrapped "Upcoming" as
          // "Upcomin g" on narrow screens. Custom tabs with FittedBox
          // scale labels down instead of wrapping them.
          _FilterTabs(
            filter: _filter,
            onChanged: (v) => setState(() => _filter = v),
          ),
          const SizedBox(height: 10),
          // Freshness signal (CricketLineX / Cricbuzz pattern):
          // "Last updated HH:MM" + manual Refresh, always visible.
          Row(
            children: [
              Expanded(
                child: Text(
                  _lastUpdated == null
                      ? lang.t('updating')
                      : '${lang.t('last_updated_prefix')} ${_lastUpdated!.hour.toString().padLeft(2, '0')}:${_lastUpdated!.minute.toString().padLeft(2, '0')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12),
                ),
              ),
              TextButton.icon(
                onPressed: () => _load(force: true),
                icon: const Icon(Icons.refresh, size: 16),
                label: Text(lang.t('refresh')),
                // Final P: 48dp tap target for the manual refresh.
                style: TextButton.styleFrom(
                    minimumSize: const Size(0, 48)),
              ),
            ],
          ),
          // Format chips (Test / ODI / T20 / T10) — reference pattern.
          // 'All' is localised; format codes are universal abbreviations.
          // Semantics: each chip announces its state for screen readers.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                'All',
                ...AppConstants.formats,
              ]
                  .map((f) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Semantics(
                          button: true,
                          selected: _formatFilter == f,
                          label: f == 'All'
                              ? lang.t('all')
                              : '${lang.t('format_filter_label')} $f',
                          child: ChoiceChip(
                            label: Text(f == 'All' ? lang.t('all') : f),
                            selected: _formatFilter == f,
                            // G6: 48dp tap target.
                            materialTapTargetSize:
                                MaterialTapTargetSize.padded,
                            onSelected: (_) =>
                                setState(() => _formatFilter = f),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
          PremiumSectionHeader(
              title: lang.t('matches'), icon: Icons.sports_cricket),
          if (_loading)
            const Center(child: CircularProgressIndicator()),
          // Empty states — three distinct, honest cases (H1/H6):
          // (a) text query with no hit, (b) Live empty → next match
          // below, (c) Upcoming/Finished genuinely empty.
          if (!_loading && _visible.isEmpty) ...[
            // Final P: designed EmptyState replaces the plain-text
            // line. Same three honest cases, same messages — one
            // icon + one line + ONE action, never fake data.
            if (_query.isNotEmpty)
              EmptyState(
                icon: Icons.search_off,
                message: "${lang.t('no_matches_found')} '$_query'",
                // No 'clear_search' string key exists (strings.dart
                // is out of scope), so mirror the search field's own
                // inline Clear wording instead of a missing key.
                actionLabel: lang.isHindi ? 'साफ़ करें' : 'Clear',
                onAction: () {
                  _searchController.clear();
                  setState(() => _query = '');
                },
              )
            else
              EmptyState(
                icon: _filter == 'live'
                    ? Icons.sports_cricket
                    : Icons.event_busy,
                message: _filter == 'live'
                    ? lang.t('no_live_matches')
                    : lang.t('no_matches_section'),
                actionLabel: lang.t('refresh'),
                onAction: () => _load(force: true),
              ),
            if (_filter == 'live' && _query.isEmpty)
              ...(() {
                final next = _nextUpcoming;
                if (next == null) return <Widget>[];
                return <Widget>[
                  PremiumSectionHeader(
                      title: lang.t('next_up'), icon: Icons.schedule),
                  KingMatchCard(
                      match: next,
                      onTap: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    MatchDetailScreen(match: next)));
                      }),
                ];
              })(),
          ],
          for (final m in _visible)
            KingMatchCard(
                match: m,
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              MatchDetailScreen(match: m)));
                }),
          const AdPlaceholder(),
          // MATCH-CENTRIC: no Trending Players on Home. Players live
          // inside their match (Squad tab). Browse all players via
          // the Stats tab if needed.
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
                lang.t('home_players_hint'),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

/// One status banner with a DISTINCT look per state (SQUAD B):
/// colour + icon + semantics label differ, so key-missing,
/// quota-exhausted, demo-fallback and offline can never be confused
/// with each other. The banner is a live region for screen readers.
class _HomeBanner extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String semanticsLabel;
  final Widget child;
  const _HomeBanner({
    required this.color,
    required this.icon,
    required this.semanticsLabel,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: semanticsLabel,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

/// Filter tabs (Live / Upcoming / Recent) that never wrap their
/// labels: each label is a single-line FittedBox that scales down on
/// narrow screens instead of breaking mid-word ("Upcomin g").
class _FilterTabs extends StatelessWidget {
  final String filter;
  final ValueChanged<String> onChanged;
  const _FilterTabs({required this.filter, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    // CricketLineX wording: Live / Upcoming / Finished (not "Recent"
    // — Finished = done, unambiguous).
    final tabs = <(String, String)>[
      ('live', lang.t('live')),
      ('upcoming', lang.t('upcoming')),
      ('finished', lang.t('finished')),
    ];
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.navyCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: filter == tabs[i].$1,
                label: tabs[i].$2,
                child: InkWell(
                onTap: () => onChanged(tabs[i].$1),
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  // G6: 48dp tap target (12 vertical padding + text).
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 12),
                  decoration: BoxDecoration(
                    color: filter == tabs[i].$1
                        ? AppTheme.gold
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  alignment: Alignment.center,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      (filter == tabs[i].$1 ? '✓ ' : '') + tabs[i].$2,
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: filter == tabs[i].$1
                            ? Colors.black
                            : AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

