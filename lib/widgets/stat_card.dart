import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// One labelled stat in a clean card — never a raw table dump.
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  const StatCard({super.key, required this.label, required this.value, this.sub});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 11)),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
            if (sub != null) ...[
              const SizedBox(height: 2),
              Text(sub!,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 11)),
            ],
          ],
        ),
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
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        if (subtitle != null)
          Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }
}
