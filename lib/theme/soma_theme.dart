import 'package:flutter/material.dart';
import 'soma_fonts.dart';

export 'soma_fonts.dart';

/// Soma Design System Colors
class SomaColors {
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
    );
  }
}

/// Aliases for backwards compatibility during migration
typedef KratosColors = SomaColors;
typedef KratosTheme = SomaTheme;
