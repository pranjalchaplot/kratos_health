import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'soma_theme.dart';

/// Central Core Fonts & Typography Helper for SOMA.
///
/// Defines:
/// - [primary]: Plus Jakarta Sans (ultra-clean, modern geometric grotesque sans-serif)
/// - [secondary] / [mono]: JetBrains Mono (high-tech biometric telemetry, numbers, metrics, HUD labels)
/// - [display]: Space Grotesk (futuristic, bold performance headers and badges)
class SomaFonts {
  // --- Font Family Names ---
  /// Primary font family name (Plus Jakarta Sans)
  static String? get primaryFamily => GoogleFonts.plusJakartaSans().fontFamily;

  /// Secondary / Monospace font family name (JetBrains Mono)
  static String? get secondaryFamily => GoogleFonts.jetBrainsMono().fontFamily;

  /// Alias for secondary font family name
  static String? get monoFamily => secondaryFamily;

  /// Display / Accent font family name (Space Grotesk)
  static String? get displayFamily => GoogleFonts.spaceGrotesk().fontFamily;

  // --- Dynamic Style Builders ---

  /// Builds a [TextStyle] using the Primary Font (Plus Jakarta Sans).
  /// Perfect for headings, titles, buttons, body copy, and general UI.
  static TextStyle primary({
    TextStyle? textStyle,
    Color? color,
    Color? backgroundColor,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    TextBaseline? textBaseline,
    double? height,
    Locale? locale,
    Paint? foreground,
    Paint? background,
    List<Shadow>? shadows,
    List<FontFeature>? fontFeatures,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
  }) {
    return GoogleFonts.plusJakartaSans(
      textStyle: textStyle,
      color: color,
      backgroundColor: backgroundColor,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      textBaseline: textBaseline,
      height: height,
      locale: locale,
      foreground: foreground,
      background: background,
      shadows: shadows,
      fontFeatures: fontFeatures,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationStyle: decorationStyle,
      decorationThickness: decorationThickness,
    );
  }

  /// Builds a [TextStyle] using the Secondary / Monospace Font (JetBrains Mono).
  /// Perfect for biometrics, calories, timers, sets/reps, telemetry stats, and badges.
  static TextStyle secondary({
    TextStyle? textStyle,
    Color? color,
    Color? backgroundColor,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    TextBaseline? textBaseline,
    double? height,
    Locale? locale,
    Paint? foreground,
    Paint? background,
    List<Shadow>? shadows,
    List<FontFeature>? fontFeatures,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
  }) {
    return GoogleFonts.jetBrainsMono(
      textStyle: textStyle,
      color: color,
      backgroundColor: backgroundColor,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      textBaseline: textBaseline,
      height: height,
      locale: locale,
      foreground: foreground,
      background: background,
      shadows: shadows,
      fontFeatures: fontFeatures,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationStyle: decorationStyle,
      decorationThickness: decorationThickness,
    );
  }

  /// Alias for [secondary] font builder (JetBrains Mono).
  static TextStyle mono({
    TextStyle? textStyle,
    Color? color,
    Color? backgroundColor,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    TextBaseline? textBaseline,
    double? height,
    Locale? locale,
    Paint? foreground,
    Paint? background,
    List<Shadow>? shadows,
    List<FontFeature>? fontFeatures,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
  }) =>
      secondary(
        textStyle: textStyle,
        color: color,
        backgroundColor: backgroundColor,
        fontSize: fontSize,
        fontWeight: fontWeight,
        fontStyle: fontStyle,
        letterSpacing: letterSpacing,
        wordSpacing: wordSpacing,
        textBaseline: textBaseline,
        height: height,
        locale: locale,
        foreground: foreground,
        background: background,
        shadows: shadows,
        fontFeatures: fontFeatures,
        decoration: decoration,
        decorationColor: decorationColor,
        decorationStyle: decorationStyle,
        decorationThickness: decorationThickness,
      );

  /// Builds a [TextStyle] using the futuristic Display Font (Space Grotesk).
  /// Great for hero titles, motivational quotes, and banner headings.
  static TextStyle display({
    TextStyle? textStyle,
    Color? color,
    Color? backgroundColor,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    TextBaseline? textBaseline,
    double? height,
    Locale? locale,
    Paint? foreground,
    Paint? background,
    List<Shadow>? shadows,
    List<FontFeature>? fontFeatures,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
  }) {
    return GoogleFonts.spaceGrotesk(
      textStyle: textStyle,
      color: color,
      backgroundColor: backgroundColor,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      textBaseline: textBaseline,
      height: height,
      locale: locale,
      foreground: foreground,
      background: background,
      shadows: shadows,
      fontFeatures: fontFeatures,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationStyle: decorationStyle,
      decorationThickness: decorationThickness,
    );
  }

  // --- Ready-to-Use Typography Presets ---

  // Primary Font Presets (Plus Jakarta Sans)
  static TextStyle get displayLarge => primary(
        fontSize: 48,
        fontWeight: FontWeight.w800,
        height: 1.1,
        letterSpacing: -1.92,
        color: SomaColors.onSurface,
      );

  static TextStyle get headlineLarge => primary(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: -0.64,
        color: SomaColors.onSurface,
      );

  static TextStyle get headlineMedium => primary(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: -0.32,
        color: SomaColors.onSurface,
      );

  static TextStyle get headlineSmall => primary(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 1.3,
        color: SomaColors.onSurface,
      );

  static TextStyle get titleLarge => primary(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: SomaColors.onSurface,
      );

  static TextStyle get titleMedium => primary(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: SomaColors.onSurface,
      );

  static TextStyle get titleSmall => primary(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: SomaColors.onSurface,
      );

  static TextStyle get bodyLarge => primary(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: SomaColors.onSurface,
      );

  static TextStyle get bodyMedium => primary(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: SomaColors.onSurface,
  );

  static TextStyle get bodySmall => primary(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: SomaColors.onSecondaryContainer,
  );

  static TextStyle get labelLarge => primary(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    color: SomaColors.onSurface,
  );

  // Secondary Font Presets (JetBrains Mono)
  static TextStyle get labelCaps => secondary(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
    color: SomaColors.onSecondaryContainer,
  );

  static TextStyle get metricHuge => secondary(
    fontSize: 36,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.0,
    height: 1.0,
    color: SomaColors.onSurface,
  );

  static TextStyle get metricLarge => secondary(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.0,
    color: SomaColors.onSurface,
  );

  static TextStyle get metricMedium => secondary(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    color: SomaColors.onSurface,
  );

  static TextStyle get metricSmall => secondary(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: SomaColors.onSurface,
  );

  static TextStyle get dataReadout => secondary(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.4,
    color: SomaColors.onSurface,
  );

  // --- Theme Generator ---

  /// Builds a complete [TextTheme] for SOMA using the primary and secondary fonts.
  static TextTheme createTextTheme([Color defaultTextColor = SomaColors.onSurface]) {
    final base = ThemeData.dark().textTheme;
    final primaryTheme = GoogleFonts.plusJakartaSansTextTheme(base).apply(
      bodyColor: defaultTextColor,
      displayColor: defaultTextColor,
    );

    return primaryTheme.copyWith(
      displayLarge: displayLarge.copyWith(color: defaultTextColor),
      headlineLarge: headlineLarge.copyWith(color: defaultTextColor),
      headlineMedium: headlineMedium.copyWith(color: defaultTextColor),
      headlineSmall: headlineSmall.copyWith(color: defaultTextColor),
      titleLarge: titleLarge.copyWith(color: defaultTextColor),
      titleMedium: titleMedium.copyWith(color: defaultTextColor),
      titleSmall: titleSmall.copyWith(color: defaultTextColor),
      bodyLarge: bodyLarge.copyWith(color: defaultTextColor),
      bodyMedium: bodyMedium.copyWith(color: defaultTextColor),
      bodySmall: bodySmall,
      labelLarge: labelLarge.copyWith(color: defaultTextColor),
      labelMedium: primary(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: defaultTextColor,
      ),
      labelSmall: labelCaps,
    );
  }
}

/// Global aliases
typedef AppFonts = SomaFonts;
typedef KratosFonts = SomaFonts;
