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
    // V3 BUG FIX: the old toggle (crown emoji + two padded chips) was
    // wide enough to squeeze the "KingCric" header into "King...".
    // Compact chips, no duplicate crown (the header already has one).
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ChoiceChip(
          label: const Text('EN'),
          labelStyle: const TextStyle(fontSize: 12),
          labelPadding: const EdgeInsets.symmetric(horizontal: 2),
          visualDensity: VisualDensity.compact,
          selected: !lang.isHindi,
          onSelected: (_) => lang.set(AppLanguage.english),
          selectedColor: AppTheme.gold,
        ),
        const SizedBox(width: 4),
        ChoiceChip(
          label: const Text('हिं'),
          labelStyle: const TextStyle(fontSize: 12),
          labelPadding: const EdgeInsets.symmetric(horizontal: 2),
          visualDensity: VisualDensity.compact,
          selected: lang.isHindi,
          onSelected: (_) => lang.set(AppLanguage.hindi),
          selectedColor: AppTheme.gold,
        ),
      ],
    );
  }
}

/// Ad slot. A placeholder is not an ad — until a REAL AdMob banner
/// widget exists, this renders NOTHING (SizedBox.shrink), never a
/// fake "Ad placeholder" box or any developer text. Checklist §8.17:
/// no dev text in the release build, even when an AdMob unit id is
/// configured — the real banner widget replaces this class then.
class AdPlaceholder extends StatelessWidget {
  const AdPlaceholder({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
