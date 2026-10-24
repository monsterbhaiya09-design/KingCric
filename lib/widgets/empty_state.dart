import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// Designed empty state (Final P) — replaces plain-text "no matches"
/// lines on Home tabs and no-results states.
///
/// Structure: gold icon in a navy disc + ONE honest line + ONE action
/// button (Retry / Refresh / Clear). It never invents data: the
/// message says what is missing, the button is the only action, and
/// there is deliberately no second button and no fake suggestion.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: AppTheme.emptyStateDecoration(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: AppTheme.goldGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.gold.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(icon, size: 30, color: Colors.black),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          // ONE action only, 48dp tap target.
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(actionLabel),
              style: AppTheme.goldFilledButton,
            ),
          ),
        ],
      ),
    );
  }
}
