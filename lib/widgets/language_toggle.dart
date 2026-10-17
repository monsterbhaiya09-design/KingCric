import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/app_theme.dart';
import '../utils/strings.dart';

/// Hindi ⇄ English toggle. Logo mark: Crown + Bat-Ball (decided).
class LanguageToggle extends StatelessWidget {
  const LanguageToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('👑', style: TextStyle(fontSize: 20)),
        const SizedBox(width: 4),
        ChoiceChip(
          label: const Text('EN'),
          selected: !lang.isHindi,
          onSelected: (_) => lang.set(AppLanguage.english),
          selectedColor: AppTheme.gold,
        ),
        const SizedBox(width: 6),
        ChoiceChip(
          label: const Text('हिं'),
          selected: lang.isHindi,
          onSelected: (_) => lang.set(AppLanguage.hindi),
          selectedColor: AppTheme.gold,
        ),
      ],
    );
  }
}

/// Ad placeholder — shows only until a real AdMob unit id is set.
/// Never shows a fake "ad" that looks like content.
class AdPlaceholder extends StatelessWidget {
  const AdPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.navyCard2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.3)),
      ),
      child: Text(
        context.tr('ad_placeholder'),
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
      ),
    );
  }
}
