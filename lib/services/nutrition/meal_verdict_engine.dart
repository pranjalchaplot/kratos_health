import 'package:flutter/material.dart';

enum MealVerdictTag {
  superClean,
  highProtein,
  lightClean,
  balanced,
  highCarb,
  highFat,
  highCal,
}

class MealVerdict {
  final MealVerdictTag tag;
  final String label;
  final Color color;
  final IconData icon;
  final String description;

  const MealVerdict({
    required this.tag,
    required this.label,
    required this.color,
    required this.icon,
    required this.description,
  });

  /// Evaluates the nutritional verdict of a meal or food item using a multi-dimensional,
  /// clinical & whole-food aware algorithm rather than a simplistic binary ratio.
  static MealVerdict evaluate({
    required num calories,
    required num protein,
    required num carbs,
    required num fats,
  }) {
    final cal = calories.toDouble();
    final p = protein.toDouble();
    final c = carbs.toDouble();
    final f = fats.toDouble();

    // 1. Zero / Minimal Calorie Items (Water, Diet Soda, Unsweetened Tea/Coffee)
    if (cal <= 30.0) {
      return const MealVerdict(
        tag: MealVerdictTag.lightClean,
        label: 'HYDRATING / LIGHT',
        color: Color(0xFFD4F84D), // Electric Lime
        icon: Icons.eco_rounded,
        description: 'Virtually zero calorie or clean hydration.',
      );
    }

    // 2. Low-Calorie Whole Foods & Light Snacks (Fruits, Veggies, Salads, Coconut Water)
    // E.g., Banana (~89 kcal, 1g P, 0.3g F), Apple (52 kcal), Berries, Citrus, Cucumber.
    // Whole fruits are nutrient-dense whole foods with minimal fat, not "high cal"!
    if (cal <= 180.0 && f <= 5.0 && p < 12.0) {
      return const MealVerdict(
        tag: MealVerdictTag.lightClean,
        label: 'LIGHT & CLEAN',
        color: Color(0xFFD4F84D), // Electric Lime
        icon: Icons.eco_rounded,
        description: 'Low-calorie whole food with minimal fat.',
      );
    }

    // 3. High Protein / Super Clean Meals
    // High protein density: >=25g protein or ratio < 10 (at least 10% of total calories from protein)
    final ratio = p > 0 ? cal / p : double.infinity;

    if (p >= 25.0 || (p >= 15.0 && ratio < 10.0)) {
      return const MealVerdict(
        tag: MealVerdictTag.superClean,
        label: 'SUPER CLEAN',
        color: Color(0xFFFFC700), // Luminous Amber Gold
        icon: Icons.keyboard_double_arrow_up_rounded,
        description: 'Exceptional protein density with lean macros.',
      );
    }

    if (p >= 18.0 || (p >= 12.0 && ratio <= 14.0)) {
      return const MealVerdict(
        tag: MealVerdictTag.highProtein,
        label: 'HIGH PROTEIN',
        color: Color(0xFF00E676), // Neon Emerald
        icon: Icons.fitness_center_rounded,
        description: 'Strong protein support for muscle recovery.',
      );
    }

    // 4. Excessive Calorie Density / Heavy Junk Meals
    // Either absolute high calories (>= 600 kcal) or high energy density with poor protein and high fat
    if (cal >= 600.0 || (cal >= 450.0 && ratio > 24.0 && f >= 18.0) || (cal >= 350.0 && p < 6.0 && f >= 20.0)) {
      return const MealVerdict(
        tag: MealVerdictTag.highCal,
        label: 'HIGH CAL',
        color: Color(0xFFFF4848), // Vivid Crimson
        icon: Icons.arrow_downward_rounded,
        description: 'Calorie-dense meal; consider moderating portions.',
      );
    }

    // 5. Balanced Wholesome Meals (The Indian Home Meal Sweet Spot: e.g. Roti + Dal + Sabzi)
    // Calories 180 - 550, decent protein (>= 10g), moderate fat (<= 22g), ratio <= 32 or good protein
    if (cal <= 550.0 && p >= 10.0 && f <= 22.0 && (ratio <= 32.0 || p >= 14.0)) {
      return const MealVerdict(
        tag: MealVerdictTag.balanced,
        label: 'BALANCED',
        color: Color(0xFF00E5FF), // Electric Cyan
        icon: Icons.balance_rounded,
        description: 'Well-rounded distribution of carbs, protein, and healthy fats.',
      );
    }

    // 6. High Fat Skew
    // If fat is high (>= 22g or fat calories > 55% of total calories)
    if (f >= 22.0 || (cal > 180.0 && (f * 9.0) / cal > 0.55)) {
      return const MealVerdict(
        tag: MealVerdictTag.highFat,
        label: 'HIGH FAT',
        color: Color(0xFFFF9100), // Punchy Orange
        icon: Icons.opacity_rounded,
        description: 'Higher proportion of dietary fats.',
      );
    }

    // 7. High Carb / Sweet Skew
    // If carbs are very high (>= 45g, or > 65% of calories from carb) with low protein
    if ((c >= 45.0 || (cal > 120.0 && (c * 4.0) / cal > 0.65)) && ratio > 20.0) {
      return const MealVerdict(
        tag: MealVerdictTag.highCarb,
        label: 'HIGH CARB',
        color: Color(0xFFFFB300), // Warm Amber
        icon: Icons.bolt_rounded,
        description: 'High in carbohydrates; good for quick energy.',
      );
    }

    // 8. Moderate / Light Fallback
    if (cal <= 250.0) {
      return const MealVerdict(
        tag: MealVerdictTag.lightClean,
        label: 'LIGHT & CLEAN',
        color: Color(0xFFD4F84D),
        icon: Icons.eco_rounded,
        description: 'Light and moderate portion size.',
      );
    }

    // Default to Balanced for moderate composite meals
    return const MealVerdict(
      tag: MealVerdictTag.balanced,
      label: 'BALANCED',
      color: Color(0xFF00E5FF),
      icon: Icons.balance_rounded,
      description: 'Satisfying meal with moderate macronutrient split.',
    );
  }
}
