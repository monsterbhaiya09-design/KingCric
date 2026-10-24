import 'package:flutter/material.dart';

/// King theme V2 — PREMIUM: dark navy + royal gold, gradients,
/// gold borders, deep shadows. No more plain flat cards.
class AppTheme {
  static const Color navy = Color(0xFF0B1026);
  static const Color navyDeep = Color(0xFF070B1D);
  static const Color navyCard = Color(0xFF151B38);
  static const Color navyCard2 = Color(0xFF1D2450);
  static const Color navyCard3 = Color(0xFF232B5E);
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldLight = Color(0xFFFFD700);
  static const Color goldSoft = Color(0xFFFFE98A);
  static const Color goldDark = Color(0xFF9C7E1A);
  static const Color textPrimary = Color(0xFFF5F0E1);
  static const Color textSecondary = Color(0xFFB8BDD4);
  static const Color textMuted = Color(0xFF8A90B0);
  static const Color green = Color(0xFF2ECC71);
  static const Color greenDark = Color(0xFF1E9E52);
  static const Color amber = Color(0xFFF39C12);
  static const Color red = Color(0xFFE74C3C);
  static const Color liveRed = Color(0xFFFF3B30);
  static const Color blue = Color(0xFF4DA3FF);

  // Premium gradients.
  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFFFD700), Color(0xFFD4AF37), Color(0xFF9C7E1A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient navyGradient = LinearGradient(
    colors: [Color(0xFF1D2450), Color(0xFF0B1026)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF1D2450), Color(0xFF151B38)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient liveGradient = LinearGradient(
    colors: [Color(0xFF2B1A3D), Color(0xFF151B38)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient goldBorderGradient = LinearGradient(
    colors: [Color(0xFFFFD700), Color(0xFFD4AF37)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static BoxDecoration premiumCard({bool goldBorder = true, double radius = 18}) {
    return BoxDecoration(
      gradient: cardGradient,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: goldBorder ? gold.withValues(alpha: 0.45) : Colors.white12,
        width: goldBorder ? 1.2 : 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.45),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: gold.withValues(alpha: 0.08),
          blurRadius: 24,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  /// Gold filled button (Final P): gold background, black label —
  /// readable on navy, used by EmptyState's single action.
  static ButtonStyle get goldFilledButton => FilledButton.styleFrom(
        backgroundColor: gold,
        foregroundColor: Colors.black,
        textStyle: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
        minimumSize: const Size(0, 48),
      );

  /// Designed empty-state card: navy gradient + soft gold border.
  static BoxDecoration emptyStateDecoration() {
    return BoxDecoration(
      gradient: cardGradient,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: gold.withValues(alpha: 0.35), width: 1),
    );
  }

  static BoxDecoration heroCard() {    return BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF2A1E4A), Color(0xFF151B38), Color(0xFF0B1026)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: gold.withValues(alpha: 0.6), width: 1.4),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.5),
          blurRadius: 22,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color: gold.withValues(alpha: 0.18),
          blurRadius: 32,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: navy,
        primaryColor: gold,
        colorScheme: const ColorScheme.dark(
          primary: gold,
          secondary: goldLight,
          surface: navyCard,
          onPrimary: Colors.black,
          onSurface: textPrimary,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: navy,
          foregroundColor: textPrimary,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.3,
          ),
        ),
        cardTheme: CardThemeData(
          color: navyCard,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: gold.withValues(alpha: 0.35)),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: navyCard2,
          selectedColor: gold,
          labelStyle: const TextStyle(color: textPrimary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        tabBarTheme: const TabBarThemeData(
          labelColor: goldLight,
          unselectedLabelColor: textSecondary,
          indicatorColor: gold,
        ),
        textTheme: const TextTheme(
          headlineSmall: TextStyle(
              color: textPrimary, fontWeight: FontWeight.w900, fontSize: 22),
          titleLarge: TextStyle(
              color: textPrimary, fontWeight: FontWeight.w900, fontSize: 20),
          titleMedium: TextStyle(
              color: textPrimary, fontWeight: FontWeight.w800, fontSize: 16),
          bodyMedium: TextStyle(color: textPrimary, fontSize: 14),
          bodySmall: TextStyle(color: textSecondary, fontSize: 12),
          labelSmall: TextStyle(color: textSecondary, fontSize: 11),
        ),
      );
}
