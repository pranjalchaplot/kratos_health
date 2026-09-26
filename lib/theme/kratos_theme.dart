import 'package:flutter/material.dart';

/// Kratos Design System Colors
class KratosColors {
  // Surface colors
  static const Color surface = Color(0xFF131313);
  static const Color surfaceDim = Color(0xFF131313);
  static const Color surfaceBright = Color(0xFF3A3939);
  static const Color surfaceContainerLowest = Color(0xFF0E0E0E);
  static const Color surfaceContainerLow = Color(0xFF1C1B1B);
  static const Color surfaceContainer = Color(0xFF201F1F);
  static const Color surfaceContainerHigh = Color(0xFF2A2A2A);
  static const Color surfaceContainerHighest = Color(0xFF353534);
  static const Color surfaceVariant = Color(0xFF353534);

  // On-Surface colors
  static const Color onSurface = Color(0xFFE5E2E1);
  static const Color onSurfaceVariant = Color(0xFFC5C9AE);

  // Primary colors (Electric Lime)
  static const Color primary = Color(0xFFFEFFEC);
  static const Color primaryContainer = Color(0xFFC6F135);
  static const Color onPrimary = Color(0xFF293500);
  static const Color onPrimaryContainer = Color(0xFF556B00);

  // Secondary colors
  static const Color secondary = Color(0xFFC8C6C5);
  static const Color secondaryContainer = Color(0xFF474746);
  static const Color onSecondary = Color(0xFF303030);
  static const Color onSecondaryContainer = Color(0xFFB6B5B4);

  // Tertiary
  static const Color tertiary = Color(0xFFFEFEFE);

  // Error
  static const Color error = Color(0xFFFFB4AB);

  // Outline
  static const Color outline = Color(0xFF8E937B);
  static const Color outlineVariant = Color(0xFF444934);

  // Background
  static const Color background = Color(0xFF131313);
  static const Color onBackground = Color(0xFFE5E2E1);

  // Card colors (from design system doc)
  static const Color cardBackground = Color(0xFF1A1A1A);
  static const Color cardBorder = Color(0xFF2A2A2A);
}

/// Kratos Design System Theme
class KratosTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: KratosColors.background,
      colorScheme: const ColorScheme.dark(
        surface: KratosColors.surface,
        primary: KratosColors.primaryContainer,
        onPrimary: KratosColors.onPrimary,
        secondary: KratosColors.secondary,
        onSecondary: KratosColors.onSecondary,
        error: KratosColors.error,
        onSurface: KratosColors.onSurface,
      ),
      textTheme: const TextTheme(
        // Display - 48px, 800, Geist
        displayLarge: TextStyle(
          fontFamily: 'Geist',
          fontSize: 48,
          fontWeight: FontWeight.w800,
          height: 1.1,
          letterSpacing: -1.92, // -0.04em
          color: KratosColors.onSurface,
        ),
        // Headline Large - 32px, 700, Geist
        headlineLarge: TextStyle(
          fontFamily: 'Geist',
          fontSize: 32,
          fontWeight: FontWeight.w700,
          height: 1.2,
          letterSpacing: -0.64, // -0.02em
          color: KratosColors.onSurface,
        ),
        // Headline Medium - 24px, 700, Geist (mobile headline)
        headlineMedium: TextStyle(
          fontFamily: 'Geist',
          fontSize: 24,
          fontWeight: FontWeight.w700,
          height: 1.2,
          color: KratosColors.onSurface,
        ),
        // Title Large - 20px, 600, Geist
        titleLarge: TextStyle(
          fontFamily: 'Geist',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          height: 1.4,
          color: KratosColors.onSurface,
        ),
        // Body Large - 16px, 400, Geist
        bodyLarge: TextStyle(
          fontFamily: 'Geist',
          fontSize: 16,
          fontWeight: FontWeight.w400,
          height: 1.6,
          color: KratosColors.onSurface,
        ),
        // Body Medium - 14px, 400, Geist
        bodyMedium: TextStyle(
          fontFamily: 'Geist',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.5,
          color: KratosColors.onSurface,
        ),
        // Label Large - data-lg: 24px, 700, Geist
        labelLarge: TextStyle(
          fontFamily: 'Geist',
          fontSize: 24,
          fontWeight: FontWeight.w700,
          height: 1.0,
          letterSpacing: -0.48, // -0.02em
          color: KratosColors.onSurface,
        ),
        // Label Small - label-caps: 12px, 700, JetBrains Mono
        labelSmall: TextStyle(
          fontFamily: 'JetBrains Mono',
          fontSize: 12,
          fontWeight: FontWeight.w700,
          height: 1.0,
          letterSpacing: 1.2, // 0.1em
          color: KratosColors.onSurface,
        ),
      ),
    );
  }
}
