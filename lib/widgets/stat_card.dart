import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// V2 premium stat card: gradient, gold value, optional bar.
/// Never overflows — value ellipsised, sub wrapped.
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final double? barFraction;
  const StatCard(
      {super.key,
      required this.label,
      required this.value,
      this.sub,
      this.barFraction});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.premiumCard(radius: 14),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 11)),
          const SizedBox(height: 4),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: AppTheme.goldLight,
                  fontSize: 21,
                  fontWeight: FontWeight.w900)),
          if (sub != null) ...[
            const SizedBox(height: 2),
            Text(sub!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 11)),
          ],
          if (barFraction != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: barFraction!.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: AppTheme.navyCard3,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppTheme.gold),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A titled section with context (e.g. "vs Pakistan — T20").
class Section extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;
  const Section(
      {super.key, required this.title, this.subtitle, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium),
        if (subtitle != null)
          Text(subtitle!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }
}
