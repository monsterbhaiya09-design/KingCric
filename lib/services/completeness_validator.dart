import '../models/match.dart';
import '../models/player.dart';

/// Data completeness — zero compromise.
///
/// Rules (from requirements):
/// 1. Never show wrong data. If two sources disagree, do NOT guess —
///    mark the record unverified and keep the last verified value.
/// 2. Totals must reconcile: batting runs in an innings must equal the
///    sum of individual batting entries; wickets must match.
/// 3. A player profile is "complete" only when it has: overall stats,
///    at least one format breakdown, recent form, and a last-updated
///    timestamp. Anything else is shown as "verifying", never as fact.
class CompletenessValidator {
  /// Compare two copies of the same match (two free sources).
  /// Returns true when the core facts agree. Status is compared
  /// EFFECTIVELY (completed / effectively-live), not by the raw
  /// [MatchStatus] field — one provider may say upcoming while
  /// another says live for the same in-progress match.
  static bool matchesAgree(CricketMatch a, CricketMatch b) {
    if (a.teamA != b.teamA || a.teamB != b.teamB) return false;
    if (a.isCompleted != b.isCompleted) return false;
    if (a.isEffectivelyLive != b.isEffectivelyLive) return false;
    if (a.scores.length != b.scores.length) return false;
    for (var i = 0; i < a.scores.length; i++) {
      if (a.scores[i].runs != b.scores[i].runs ||
          a.scores[i].wickets != b.scores[i].wickets) {
        return false;
      }
    }
    return true;
  }

  /// Reconcile an innings: sum of batting entries must equal total.
  /// Small extras (wides/no-balls) make an exact match impossible, so
  /// we allow a tolerance that scales with the total: a flat 15 runs
  /// for short innings, plus ~5% for big totals (a Test innings can
  /// legitimately carry >15 extras). Wickets must still match.
  static bool inningsReconciles(CricketMatch m) {
    for (final inn in m.innings) {
      final sum =
          inn.batting.fold<int>(0, (acc, e) => acc + e.runs);
      final tolerance = 15 + (inn.total ~/ 20);
      if ((inn.total - sum).abs() > tolerance) return false;
      final wkts =
          inn.batting.where((e) => !e.notOut).length;
      if (inn.wickets != 0 && wkts != inn.wickets && inn.wickets < 10) {
        // Did-not-bat entries are absent from mock data; only enforce
        // when the card actually lists 11 batters.
        if (inn.batting.length >= 11) return false;
      }
    }
    return true;
  }

  /// Is this player profile complete enough to present as fact?
  /// Honesty rules (Squad E): a demo / mock / partial profile is
  /// NEVER complete, even if it carries full-looking numbers —
  /// mock players have curated stats. Only a profile whose source
  /// computed real stats (e.g. Cricsheet) with dataComplete=true
  /// can be complete.
  static bool isPlayerComplete(Player p) {
    if (!p.dataComplete) return false;
    final src = p.source.trim().toLowerCase();
    if (src == 'demo' || src == 'mock' || src == 'partial') {
      return false;
    }
    if (p.name.isEmpty || p.id.isEmpty) return false;
    if (p.battingByFormat.isEmpty) return false;
    if (p.battingOverall().matches == 0) return false;
    if (p.recentForm.isEmpty) return false;
    if (p.lastUpdated == null) return false;
    // Staleness: a completed-match update older than 24h is stale.
    if (DateTime.now().difference(p.lastUpdated!).inHours > 24) {
      return false;
    }
    return true;
  }

  /// Honest completeness label for a profile. 'Complete' only from
  /// [isPlayerComplete]; demo/mock sources are 'Demo' even with
  /// full-looking numbers; everything else is 'Partial'. The UI
  /// must render this label, never invent 'Complete' from stats.
  static String completenessLabel(Player p) {
    if (isPlayerComplete(p)) return 'Complete';
    final src = p.source.trim().toLowerCase();
    if (src == 'demo' || src == 'mock') return 'Demo';
    return 'Partial';
  }

  /// Merge two sources: prefer the one that reconciles. If neither
  /// reconciles, return the first (last verified) and flag incomplete.
  static ({CricketMatch match, bool verified}) pickVerifiedMatch(
    CricketMatch primary,
    CricketMatch? secondary,
  ) {
    if (secondary == null) {
      return (
        match: primary,
        verified: inningsReconciles(primary),
      );
    }
    if (matchesAgree(primary, secondary)) {
      return (match: primary, verified: true);
    }
    // Disagreement: keep primary only if it reconciles on its own.
    if (inningsReconciles(primary)) {
      return (match: primary, verified: false);
    }
    if (inningsReconciles(secondary)) {
      return (match: secondary, verified: false);
    }
    return (match: primary, verified: false);
  }
}
