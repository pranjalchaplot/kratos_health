import '../models/user_goals.dart';
import '../models/exercise_set.dart';

class CalorieCalculatorService {
  /// Calculate daily Basal Metabolic Rate (BMR) based on formula setting in UserGoals
  static int calculateBmr(UserGoals goals) {
    // Custom BMR override
    if (goals.bmrFormula == 'custom' && goals.customBmr != null && goals.customBmr! > 0) {
      return goals.customBmr!;
    }

    final weight = goals.weightKg ?? 75.0;
    final height = goals.heightCm ?? 178.0;
    final age = goals.age ?? 25;
    final gender = (goals.gender ?? 'male').toLowerCase();
    final bodyFat = goals.bodyFatPercentage ?? 15.0;

    switch (goals.bmrFormula) {
      case 'harris':
        // Revised Harris-Benedict (1984 Roza & Shizgal)
        if (gender == 'female') {
          return (447.593 + (9.247 * weight) + (3.098 * height) - (4.330 * age)).round();
        } else if (gender == 'male') {
          return (88.362 + (13.397 * weight) + (4.799 * height) - (5.677 * age)).round();
        } else {
          return (268.0 + (11.32 * weight) + (3.95 * height) - (5.0 * age)).round();
        }

      case 'katch':
        // Katch-McArdle: BMR = 370 + 21.6 * (Lean Body Mass in kg)
        final lbm = weight * (1.0 - (bodyFat / 100.0));
        return (370.0 + (21.6 * lbm)).round();

      case 'cunningham':
        // Cunningham: BMR = 500 + 22 * (Lean Body Mass in kg)
        final lbm = weight * (1.0 - (bodyFat / 100.0));
        return (500.0 + (22.0 * lbm)).round();

      case 'mifflin':
      default:
        // Mifflin-St Jeor Equation (Gold Standard)
        // Male: 10*W + 6.25*H - 5*A + 5
        // Female: 10*W + 6.25*H - 5*A - 161
        // Neutral: 10*W + 6.25*H - 5*A - 78
        double base = (10.0 * weight) + (6.25 * height) - (5.0 * age);
        if (gender == 'female') {
          return (base - 161.0).round();
        } else if (gender == 'male') {
          return (base + 5.0).round();
        } else {
          return (base - 78.0).round();
        }
    }
  }

  /// Hourly BMR rate
  static double calculateHourlyBmr(UserGoals goals) {
    final bmr = calculateBmr(goals);
    return bmr / 24.0;
  }

  /// Calculates real-time BMR calories burnt so far today based on current local time (or target date)
  static int calculateBmrBurntSoFar(UserGoals goals, DateTime date) {
    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    final isPast = date.isBefore(DateTime(now.year, now.month, now.day));

    final bmrDaily = calculateBmr(goals);

    if (isPast) {
      // Past day: Full 24 hours of BMR
      return bmrDaily;
    } else if (isToday) {
      // Current day: Fraction of 24h passed so far
      final hoursPassed = now.hour + (now.minute / 60.0);
      final fraction = (hoursPassed / 24.0).clamp(0.0, 1.0);
      return (bmrDaily * fraction).round();
    } else {
      // Future day: 0 BMR burnt so far
      return 0;
    }
  }

  /// Calculate steps calorie burn based on step count and user body weight
  static int calculateStepsCalories(int steps, double weightKg) {
    if (steps <= 0) return 0;
    // Standard energy expenditure per step: ~0.00045 kcal/step per kg of body mass
    final cal = steps * weightKg * 0.00045;
    return cal.round();
  }

  /// Get MET value for Cardio types
  static double getCardioMet(String cardioType, String intensity) {
    final type = cardioType.toLowerCase();
    final level = intensity.toLowerCase();

    double baseMet = 7.0; // default moderate cardio

    if (type.contains('run')) {
      baseMet = 8.5;
    } else if (type.contains('cycl') || type.contains('bike')) {
      baseMet = 7.5;
    } else if (type.contains('swim')) {
      baseMet = 8.0;
    } else if (type.contains('row')) {
      baseMet = 7.0;
    } else if (type.contains('hiit') || type.contains('crossfit')) {
      baseMet = 9.5;
    } else if (type.contains('walk')) {
      baseMet = 3.5;
    } else if (type.contains('stair') || type.contains('climb')) {
      baseMet = 8.8;
    } else if (type.contains('rope') || type.contains('jump')) {
      baseMet = 11.0;
    }

    if (level.contains('low') || level.contains('light')) {
      baseMet *= 0.8;
    } else if (level.contains('high') || level.contains('vigorous')) {
      baseMet *= 1.2;
    } else if (level.contains('extreme') || level.contains('max')) {
      baseMet *= 1.4;
    }

    return baseMet;
  }

  /// Calculate Cardio calories burned: MET * Weight(kg) * Duration(hours)
  static int calculateCardioCalories({
    required String cardioType,
    required String intensity,
    required int durationMinutes,
    required double weightKg,
  }) {
    if (durationMinutes <= 0) return 0;
    final met = getCardioMet(cardioType, intensity);
    final hours = durationMinutes / 60.0;
    final cal = met * weightKg * hours;
    return cal.round();
  }

  /// Calculate Exercise / Strength Workout calories burned:
  /// Combines Metabolic exertion duration + total mechanical volume lifted (Sets * Reps * Weight)
  static int calculateExerciseCalories({
    required String exerciseName,
    required List<ExerciseSet> sets,
    required int durationMinutes,
    required double weightKg,
  }) {
    // Base exertion MET for resistance training (~5.0 METs)
    final hours = durationMinutes > 0 ? durationMinutes / 60.0 : (sets.length * 3.0) / 60.0;
    double exertionCalories = 5.0 * weightKg * hours;

    // Total mechanical volume work: Sum(reps * weightKg)
    double totalVolumeKg = 0.0;
    for (var set in sets) {
      totalVolumeKg += (set.reps * set.weightKg);
    }

    // Work efficiency factor: ~0.0003 kcal per kg lifted per 70kg athlete
    double volumeWorkCalories = totalVolumeKg * 0.0003 * (weightKg / 70.0);

    return (exertionCalories + volumeWorkCalories).round();
  }
}
