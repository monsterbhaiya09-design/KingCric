import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// Display-text rules (FIX UX): provider data arrives in mixed case
/// ("odi", "t20", "bulgaria women") and raw codes must never reach
/// the screen. ONE place owns the mapping so every screen agrees:
/// format codes render as ODI / T20 / Test / T10, names render in
/// Title Case without ever corrupting acronyms or mixed-case names.
class DisplayText {
  static const _formats = {
    'test': 'Test',
    'odi': 'ODI',
    't20': 'T20',
    't20i': 'T20I',
    't10': 'T10',
    'the hundred': 'The Hundred',
    'hundred': 'The Hundred',
    'first class': 'First Class',
    'first-class': 'First Class',
    'list a': 'List A',
  };

  /// Format code -> display label. Unknown codes fall back to
  /// Title Case (never raw lowercase).
  static String formatLabel(String input) {
    final key = input.trim().toLowerCase();
    if (key.isEmpty) return input;
    return _formats[key] ?? titleCase(input);
  }

  /// Safe Title Case: only words that are uniformly cased AND long
  /// enough to be real words change ("bulgaria women" ->
  /// "Bulgaria Women"). Short acronyms ("IPL", "ODI") and
  /// mixed-case proper names ("McCullum", "de Kock") are left
  /// untouched, so title-casing can never corrupt a real name.
  static String titleCase(String input) {
    return input.split(' ').map((word) {
      return word.split('-').map((part) {
        final hasLetter = part.contains(RegExp(r'[A-Za-z]'));
        if (!hasLetter || part.length < 4) return part;
        final upper = part == part.toUpperCase();
        final lower = part == part.toLowerCase();
        if (!upper && !lower) return part;
        return part[0].toUpperCase() + part.substring(1).toLowerCase();
      }).join('-');
    }).join(' ');
  }
}

/// V2 premium shared widgets: gradient cards, live pulse, stat bars,
/// section headers. No new dependencies — pure Flutter.

/// Gold-bordered gradient card wrapper.
class KingGradientCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool hero;
  final VoidCallback? onTap;
  const KingGradientCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.hero = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      decoration: hero ? AppTheme.heroCard() : AppTheme.premiumCard(),
      padding: padding,
      child: child,
    );
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: content,
    );
  }
}

/// LIVE dot with glow. Deliberately NOT an infinite
/// AnimationController.repeat — a repeating controller never settles,
/// so pumpAndSettle in widget tests times out and the app burns CPU
/// on a background tab. The one-shot scale-in + static glow still
/// reads as "live" without an endless ticker.
class LivePulseDot extends StatelessWidget {
  const LivePulseDot({super.key});
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.6, end: 1.0),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutBack,
      builder: (_, t, __) {
        return Container(
          width: 10 + 2 * t,
          height: 10 + 2 * t,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.liveRed,
            boxShadow: [
              BoxShadow(
                color: AppTheme.liveRed.withValues(alpha: 0.55),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// LIVE pill with pulse.
class LivePill extends StatelessWidget {
  final String label;
  const LivePill({super.key, this.label = 'LIVE'});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF3B30), Color(0xFFC81E1E)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.liveRed.withValues(alpha: 0.5),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LivePulseDot(),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2)),
        ],
      ),
    );
  }
}

/// Horizontal stat bar: label + animated fill + value. No overflow:
/// value is right-aligned with fixed width, label flexes.
class StatBar extends StatelessWidget {
  final String label;
  final String value;
  final double fraction; // 0..1, clamped
  final Color color;
  const StatBar({
    super.key,
    required this.label,
    required this.value,
    required this.fraction,
    this.color = AppTheme.gold,
  });

  @override
  Widget build(BuildContext context) {
    final f = fraction.clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
              ),
              const SizedBox(width: 8),
              Text(value,
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: f),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) {
                return LinearProgressIndicator(
                  value: v,
                  minHeight: 8,
                  backgroundColor: AppTheme.navyCard3,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Premium section header — clean modern style (FIX UX): smaller
/// title, Material icon only (no emoji headers anywhere), and a
/// short thin gold accent bar instead of a heavy gold rule.
class PremiumSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  const PremiumSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: AppTheme.goldLight),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2)),
              ),
            ],
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(subtitle!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12)),
          ],
          const SizedBox(height: 6),
          Container(
            height: 2,
            width: 40,
            decoration: BoxDecoration(
              gradient: AppTheme.goldGradient,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

/// Gradient avatar with initials — thin gold ring (FIX UX): the
/// old thick gradient + heavy glow read as cartoon; a 1.5px ring
/// with a soft shadow keeps the King identity without the bulk.
class KingAvatar extends StatelessWidget {
  final String name;
  final double radius;
  const KingAvatar({super.key, required this.name, this.radius = 28});
  @override
  Widget build(BuildContext context) {
    final initials = name.isEmpty
        ? '?'
        : name
            .split(' ')
            .where((w) => w.isNotEmpty)
            .take(2)
            .map((w) => w[0].toUpperCase())
            .join();
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.navyCard2,
        border: Border.all(
            color: AppTheme.gold.withValues(alpha: 0.55), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(initials,
          maxLines: 1,
          overflow: TextOverflow.clip,
          style: TextStyle(
              color: AppTheme.goldLight,
              fontSize: radius * 0.62,
              fontWeight: FontWeight.w900)),
    );
  }
}

/// Small gold chip for format / league / role.
class GoldChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  const GoldChip({super.key, required this.label, this.icon});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: AppTheme.goldLight),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppTheme.goldSoft,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

/// Scoreboard table header cell.
class ScoreHeaderCell extends StatelessWidget {
  final String label;
  final double width;
  final TextAlign align;
  const ScoreHeaderCell(this.label,
      {super.key, this.width = 48, this.align = TextAlign.right});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(label,
          textAlign: align,
          maxLines: 1,
          overflow: TextOverflow.clip,
          style: const TextStyle(
              color: AppTheme.goldLight,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5)),
    );
  }
}

/// One row of a scoreboard table — fixed column widths + horizontal
/// scroll parent, so nothing truncates or overflows.
class ScoreRow extends StatelessWidget {
  final List<Widget> cells;
  final bool highlighted;
  const ScoreRow({super.key, required this.cells, this.highlighted = false});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
      decoration: BoxDecoration(
        color: highlighted
            ? AppTheme.gold.withValues(alpha: 0.10)
            : Colors.transparent,
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
        ),
      ),
      child: Row(children: cells),
    );
  }
}

/// Animated number that counts up — used for big scores.
class AnimatedScore extends StatelessWidget {
  final int value;
  final TextStyle? style;
  const AnimatedScore({super.key, required this.value, this.style});
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => Text('${v.round()}',
          maxLines: 1,
          overflow: TextOverflow.clip,
          style: style ??
              const TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textPrimary)),
    );
  }
}

/// Simple donut: draws a gold arc for a 0..1 fraction (no dependency).
class GoldDonut extends StatelessWidget {
  final double fraction;
  final double size;
  final String center;
  final Color color;
  const GoldDonut({
    super.key,
    required this.fraction,
    this.size = 72,
    required this.center,
    this.color = AppTheme.gold,
  });
  @override
  Widget build(BuildContext context) {
    final f = fraction.clamp(0.0, 1.0);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _DonutPainter(fraction: f, color: color),
          ),
          Text(center,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: const TextStyle(
                  fontWeight: FontWeight.w900, fontSize: 18)),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final double fraction;
  final Color color;
  _DonutPainter({required this.fraction, required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final bg = Paint()
      ..color = AppTheme.navyCard3
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect.deflate(4), 0, 2 * math.pi, false, bg);
    final fg = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect.deflate(4), -math.pi / 2, 2 * math.pi * fraction,
        false, fg);
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.fraction != fraction || old.color != color;
}
