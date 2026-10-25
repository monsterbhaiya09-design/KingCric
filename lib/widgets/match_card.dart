import 'package:flutter/material.dart';
import '../models/match.dart';
import '../utils/app_theme.dart';
import 'premium_widgets.dart';

/// Shared match card — ONE component used by Home AND Leagues
/// (reference rule: never two diverging cards).
///
/// Canonical layout (CricketLineX / Cricbuzz / Crex pattern):
/// status pill + League • Format → fixture title (max 2 lines) →
/// venue (1 line) → ONE row per team: name left, score right →
/// ONE equation/result/starts line → single CTA.
///
/// Status pill ALWAYS derives from [CricketMatch.isEffectivelyLive]
/// + [isCompleted] — the same truth the Home filter uses — so a live
/// match can never again show an UPCOMING pill.
/// Upcoming cards show NO score rows (a match that has not started
/// has no score). Finished cards show both scores + result line.
class KingMatchCard extends StatelessWidget {
  final CricketMatch match;
  final VoidCallback onTap;
  const KingMatchCard({super.key, required this.match, required this.onTap});

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// Human label for a [CricketMatch.source] value. Unknown
  /// provider strings pass through unchanged (never blank).
  /// Empty source (older cache / untagged) renders as 'Unknown' —
  /// every card shows a source label, so an untagged card can never
  /// be mistaken for verified real data.
  static String _sourceLabel(String source) {
    if (source.trim().isEmpty) return 'Unknown';
    switch (source.toLowerCase()) {
      case 'demo':
      case 'mock':
        return 'Demo';
      case 'cricapi':
        return 'CricAPI';
      case 'sportscore':
        return 'SportScore';
      case 'thesportsdb':
        return 'TheSportsDB';
      case 'elitesport':
        return 'EliteSport';
      case 'entitysport':
        return 'EntitySport';
      case 'cricsheet':
        return 'Cricsheet';
      case 'merged':
        return 'Live APIs';
      default:
        return source;
    }
  }

  /// Demo/mock cards get an amber source label so they are visually
  /// distinct from verified provider cards at a glance.
  static bool _isDemoSource(String source) {
    final s = source.toLowerCase();
    return s == 'demo' || s == 'mock';
  }

  /// Title Case for display names (FIX UX: now shared via
  /// [DisplayText] so every screen agrees; format codes are NOT
  /// title-cased here — use [DisplayText.formatLabel] for those).
  static String _titleCase(String input) => DisplayText.titleCase(input);

  String _startsLine(DateTime start) {
    final now = DateTime.now();
    final local = start.toLocal();
    final sameDay = now.year == local.year &&
        now.month == local.month &&
        now.day == local.day;
    final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final ampm = local.hour < 12 ? 'AM' : 'PM';
    final time = '$hour12:${local.minute.toString().padLeft(2, '0')} $ampm';
    if (sameDay) return 'Starts: Today, $time';
    return 'Starts: ${local.day} ${_months[local.month - 1]}, $time';
  }

  @override
  Widget build(BuildContext context) {
    final m = match;
    final live = m.isEffectivelyLive;
    final upcoming = !live && !m.isCompleted;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: live ? AppTheme.heroCard() : AppTheme.premiumCard(),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (live) const LivePill(),
                  if (!live)
                    GoldChip(label: m.isCompleted ? 'RESULT' : 'UPCOMING'),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                        '${_titleCase(m.league)} • ${DisplayText.formatLabel(m.format)}',
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12)),
                  ),
                  if (m.lastBall.isNotEmpty)
                    Text('Last: ${m.lastBall}',
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppTheme.goldLight,
                            fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 10),
              Text(_titleCase(m.title),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 19, fontWeight: FontWeight.w800)),
              if (m.venueName.isNotEmpty) ...[
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 13, color: AppTheme.textSecondary),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(_titleCase(m.venueName),
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12)),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              // Upcoming: NO score rows — a match that has not started
              // has no score (reference rule H4).
              if (!upcoming)
                for (final s in m.scores)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(_titleCase(s.team),
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 15)),
                        ),
                        const SizedBox(width: 8),
                        Text(s.display,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 17,
                                color: AppTheme.goldLight)),
                      ],
                    ),
                  ),
              if (upcoming)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(_startsLine(m.startTime),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w700)),
                ),
              if (m.result.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(m.result,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppTheme.goldSoft,
                          fontWeight: FontWeight.w700)),
                ),
              // FIX UX: each row guarded on its OWN data. The old
              // code showed the Bowling row whenever the Batting
              // row had data, leaving a blank "Bowling:" label.
              if (m.currentBatter.isNotEmpty && live) ...[
                const Divider(color: Colors.white12, height: 20),
                Text('Batting: ${m.currentBatter}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12)),
              ],
              if (m.currentBowler.isNotEmpty && live) ...[
                const SizedBox(height: 2),
                Text('Bowling: ${m.currentBowler}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary)),
              ],
              // SQUAD B: per-card source label — ALWAYS rendered.
              // Demo can never masquerade as real: 'demo' = bundled
              // demo fixture (amber label), 'CricAPI' / 'SportScore'
              // / ... = the provider that supplied this card,
              // 'Unknown' = older/untagged cache (never guessed).
              const SizedBox(height: 6),
              Text('Source: ${_sourceLabel(m.source)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: _isDemoSource(m.source)
                          ? AppTheme.amber
                          : AppTheme.textSecondary,
                      fontSize: 11)),
              const SizedBox(height: 6),
              // SQUAD B: honest CTA — an upcoming match HAS no
              // scorecard yet, so it must not promise one. Upcoming
              // cards invite to match details; live/finished cards
              // invite to the full scorecard.
              Row(
                children: [
                  const Icon(Icons.arrow_forward,
                      size: 14, color: AppTheme.goldLight),
                  const SizedBox(width: 4),
                  // MERGE v6: CTA row must never overflow at phone
                  // widths (390dp test showed a 94px RenderFlex
                  // overflow — mostly the test font's wide glyphs,
                  // but a large accessibility text scale overflows
                  // for real). The first label flexes with ellipsis
                  // and pushes the trailing label right, so no
                  // Spacer is needed (Spacer + Expanded would split
                  // the free space and strand the trailing label
                  // mid-card).
                  Expanded(
                    child: Text(
                        upcoming
                            ? 'Tap for match details'
                            : 'Tap for FULL scorecard',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppTheme.goldLight,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 8),
                  Text(upcoming ? 'Details →' : 'Scorecard →',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppTheme.gold, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
