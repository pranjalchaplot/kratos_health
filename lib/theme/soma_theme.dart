import 'package:flutter/material.dart';
import 'soma_fonts.dart';

export 'soma_fonts.dart';

/// Soma Design System Colors - Obsidian Dark Palette with Electric Lime Accent
class SomaColors {
  // Obsidian Surface Hierarchy
  static const Color background = Color(0xFF0C0C0E);
  static const Color surface = Color(0xFF131316);
  static const Color surfaceDim = Color(0xFF0F0F11);
  static const Color surfaceBright = Color(0xFF28282D);
  static const Color surfaceContainerLowest = Color(0xFF080809);
  static const Color surfaceContainerLow = Color(0xFF161619);
  static const Color surfaceContainer = Color(0xFF1B1B1F);
  static const Color surfaceContainerHigh = Color(0xFF232328);
  static const Color surfaceContainerHighest = Color(0xFF2C2C33);
  static const Color surfaceVariant = Color(0xFF24242A);

  // Cards & Elevation
  static const Color cardBackground = Color(0xFF161619);
  static const Color cardBorder = Color(0xFF27272D);
  static const Color cardBorderSubtle = Color(0xFF1E1E24);
  static const Color cardElevated = Color(0xFF1E1E23);

  // On-Surface Typography & Neutrals
  static const Color onSurface = Color(0xFFF4F4F6);
  static const Color onSurfaceVariant = Color(0xFFA1A1AA);
  static const Color onBackground = Color(0xFFF4F4F6);
  static const Color secondary = Color(0xFFA1A1AA);
  static const Color secondaryContainer = Color(0xFF323238);
  static const Color onSecondary = Color(0xFF1A1A1E);
  static const Color onSecondaryContainer = Color(0xFF71717A);

  // Primary Accent (Electric Lime)
  static const Color primary = Color(0xFFD4F84D);
  static const Color primaryContainer = Color(0xFFC6F135);
  static const Color primaryGlow = Color(0x33C6F135);
  static const Color onPrimary = Color(0xFF121800);
  static const Color onPrimaryContainer = Color(0xFF1C2600);

  // Semantic Metric Accents
  static const Color accentCyan = Color(0xFF38E1FF); // Hydration
  static const Color accentPurple = Color(0xFFB388FF); // Sleep
  static const Color accentAmber = Color(0xFFFFB020); // Digital Screen Time
  static const Color accentCoral = Color(0xFFFF5C5C); // Cardio / Intense Activity
  static const Color accentGreen = Color(0xFF4ADE80); // Success / Nutrition target met

  // Tertiary & Functional
  static const Color tertiary = Color(0xFFFFFFFF);
  static const Color error = Color(0xFFFF6B6B);
  static const Color outline = Color(0xFF3F3F46);
  static const Color outlineVariant = Color(0xFF27272A);
}

/// Soma Design System Theme
class SomaTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: SomaColors.background,
      colorScheme: const ColorScheme.dark(
        surface: SomaColors.surface,
        primary: SomaColors.primaryContainer,
        onPrimary: SomaColors.onPrimary,
        secondary: SomaColors.secondary,
        onSecondary: SomaColors.onSecondary,
        error: SomaColors.error,
        onSurface: SomaColors.onSurface,
      ),
      textTheme: SomaFonts.createTextTheme(SomaColors.onSurface),
      cardTheme: CardThemeData(
        color: SomaColors.cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: SomaColors.cardBorder, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: SomaColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: SomaColors.primaryContainer,
          foregroundColor: Colors.black,
          elevation: 0,
          textStyle: SomaFonts.primary(fontSize: 15, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
    );
  }
}

/// Aliases for backwards compatibility during migration
typedef KratosColors = SomaColors;
typedef KratosTheme = SomaTheme;
