import 'package:flutter/material.dart';

/// King theme: dark navy + royal gold. Clean cards, never a raw dump.
class AppTheme {
  static const Color navy = Color(0xFF0B1026);
  static const Color navyCard = Color(0xFF151B38);
  static const Color navyCard2 = Color(0xFF1D2450);
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldLight = Color(0xFFFFD700);
  static const Color goldDark = Color(0xFF9C7E1A);
  static const Color textPrimary = Color(0xFFF5F0E1);
  static const Color textSecondary = Color(0xFFB8BDD4);
  static const Color green = Color(0xFF2ECC71);
  static const Color amber = Color(0xFFF39C12);
  static const Color red = Color(0xFFE74C3C);

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: navy,
        primaryColor: gold,
        colorScheme: const ColorScheme.dark(
          primary: gold,
          secondary: goldLight,
          surface: navyCard,
          // background removed: deprecated in Flutter 3.47, use surface instead.
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
            fontWeight: FontWeight.w800,
          ),
        ),
        cardTheme: CardThemeData(
          color: navyCard,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: gold.withValues(alpha: 0.25)),
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
              color: textPrimary, fontWeight: FontWeight.w800, fontSize: 22),
          titleMedium: TextStyle(
              color: textPrimary, fontWeight: FontWeight.w700, fontSize: 16),
          bodyMedium: TextStyle(color: textPrimary, fontSize: 14),
          bodySmall: TextStyle(color: textSecondary, fontSize: 12),
          labelSmall: TextStyle(color: textSecondary, fontSize: 11),
        ),
      );
}
