import '../models/user_goals.dart';
import '../models/exercise_set.dart';

class CalorieCalculatorService {
  /// Core Calorie Engine formula:
  /// correction   = (userBMR / 24) / userWeightKg
  /// calories     = MET * userWeightKg * durationHr * correction
  static double calculateCaloriesEngine({
    required double met,
    required double userWeightKg,
    required double userBmr,
    required double durationMin,
  }) {
    if (userWeightKg <= 0 || durationMin <= 0 || userBmr <= 0) return 0.0;
    final durationHr = durationMin / 60.0;
    final correction = (userBmr / 24.0) / userWeightKg;
    final rawCalories = met * userWeightKg * durationHr * correction;
    return double.parse(rawCalories.toStringAsFixed(1));
  }

  /// BMR via Mifflin-St Jeor Equation
  static double calculateBMREngine({
    required double weightKg,
    required double heightCm,
    required int age,
    required String sex,
  }) {
    final base = (10.0 * weightKg) + (6.25 * heightCm) - (5.0 * age);
    final val = sex.toLowerCase() == 'female' ? base - 161.0 : base + 5.0;
    return double.parse(val.toStringAsFixed(1));
  }

  /// Calculate daily Basal Metabolic Rate (BMR) based on formula setting in UserGoals
  static int calculateBmr(UserGoals goals) {
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
        if (gender == 'female') {
          return (447.593 + (9.247 * weight) + (3.098 * height) - (4.330 * age)).round();
        } else if (gender == 'male') {
          return (88.362 + (13.397 * weight) + (4.799 * height) - (5.677 * age)).round();
        } else {
          return (268.0 + (11.32 * weight) + (3.95 * height) - (5.0 * age)).round();
        }

      case 'katch':
        final lbm = weight * (1.0 - (bodyFat / 100.0));
        return (370.0 + (21.6 * lbm)).round();

      case 'cunningham':
        final lbm = weight * (1.0 - (bodyFat / 100.0));
        return (500.0 + (22.0 * lbm)).round();

      case 'mifflin':
      default:
        return calculateBMREngine(
          weightKg: weight,
          heightCm: height,
          age: age,
          sex: gender,
        ).round();
    }
  }

  /// Hourly BMR rate
  static double calculateHourlyBmr(UserGoals goals) {
    final bmr = calculateBmr(goals);
    return bmr / 24.0;
  }

  /// Per-second BMR burn rate
  static double calculateBmrPerSecond(UserGoals goals) {
    final bmr = calculateBmr(goals);
    return bmr / 86400.0;
  }

  /// Calculates precise real-time BMR calories burnt so far today
  static double calculatePreciseBmrBurntSoFar(UserGoals goals, DateTime date) {
    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    final isPast = date.isBefore(DateTime(now.year, now.month, now.day));

    final bmrDaily = calculateBmr(goals).toDouble();

    if (isPast) {
      return bmrDaily;
    } else if (isToday) {
      final secondsPassed = (now.hour * 3600) + (now.minute * 60) + now.second + (now.millisecond / 1000.0);
      final bmrPerSec = calculateBmrPerSecond(goals);
      return (secondsPassed * bmrPerSec).clamp(0.0, bmrDaily);
    } else {
      return 0.0;
    }
  }

  /// Calculates real-time BMR calories burnt so far today based on current local time
  static int calculateBmrBurntSoFar(UserGoals goals, DateTime date) {
    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    final isPast = date.isBefore(DateTime(now.year, now.month, now.day));

    final bmrDaily = calculateBmr(goals);

    if (isPast) {
      return bmrDaily;
    } else if (isToday) {
      final hoursPassed = now.hour + (now.minute / 60.0);
      final fraction = (hoursPassed / 24.0).clamp(0.0, 1.0);
      return (bmrDaily * fraction).round();
    } else {
      return 0;
    }
  }

  // --- CARDIO ENGINE ---

  static final Map<String, List<Map<String, double>>> cardioSpeedTables = {
    'running': [
      {'maxMph': 5.0, 'met': 8.0},
      {'maxMph': 6.0, 'met': 9.8},
      {'maxMph': 7.0, 'met': 11.0},
      {'maxMph': 8.0, 'met': 11.8},
      {'maxMph': 9.0, 'met': 12.8},
      {'maxMph': 10.0, 'met': 14.5},
      {'maxMph': double.infinity, 'met': 16.0},
    ],
    'walking': [
      {'maxMph': 2.0, 'met': 2.8},
      {'maxMph': 3.0, 'met': 3.5},
      {'maxMph': 3.5, 'met': 4.3},
      {'maxMph': 4.0, 'met': 5.0},
      {'maxMph': double.infinity, 'met': 6.5},
    ],
    'cycling': [
      {'maxMph': 10.0, 'met': 4.0},
      {'maxMph': 12.0, 'met': 6.8},
      {'maxMph': 14.0, 'met': 8.0},
      {'maxMph': 16.0, 'met': 10.0},
      {'maxMph': 19.0, 'met': 12.0},
      {'maxMph': double.infinity, 'met': 15.8},
    ],
  };

  static final Map<String, Map<String, double>> cardioEffortTables = {
    'swimming': {'light': 6.0, 'moderate': 8.3, 'vigorous': 9.8},
    'rowing': {'light': 4.8, 'moderate': 7.0, 'vigorous': 8.5, 'max': 12.0},
    'hiit': {'moderate': 8.0, 'vigorous': 10.0, 'max': 12.8},
    'stairclimber': {'moderate': 8.0, 'vigorous': 9.8},
    'jumprope': {'slow': 8.8, 'moderate': 11.0, 'fast': 12.3},
  };

  static String _normalizeName(String name) {
    return name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  /// Calculates Cardio Calories using personalized BMR correction
  static double getCardioCalories({
    required String exercise,
    required double durationMin,
    double? speedMph,
    String? effort,
    required double userWeightKg,
    required double userBmr,
  }) {
    final normKey = _normalizeName(exercise);
    double met = 7.0;

    if (cardioSpeedTables.containsKey(normKey)) {
      final speed = speedMph ?? (normKey == 'running' ? 6.0 : normKey == 'walking' ? 3.0 : 12.0);
      final tiers = cardioSpeedTables[normKey]!;
      final tier = tiers.firstWhere(
        (t) => speed <= t['maxMph']!,
        orElse: () => tiers.last,
      );
      met = tier['met']!;
    } else if (cardioEffortTables.containsKey(normKey)) {
      final effortTable = cardioEffortTables[normKey]!;
      final effKey = (effort ?? 'moderate').toLowerCase();
      met = effortTable[effKey] ?? effortTable['moderate'] ?? 7.0;
    } else {
      // Fallback to general cardio MET if name not matched strictly
      met = getCardioMet(exercise, effort ?? 'moderate');
    }

    return calculateCaloriesEngine(
      met: met,
      userWeightKg: userWeightKg,
      userBmr: userBmr,
      durationMin: durationMin,
    );
  }

  /// Legacy / Quick Cardio adapter
  static int calculateCardioCalories({
    required String cardioType,
    required String intensity,
    required int durationMinutes,
    required double weightKg,
    double? speedMph,
    double? userBmr,
  }) {
    if (durationMinutes <= 0) return 0;
    final bmr = userBmr ?? (weightKg * 24.0);
    return getCardioCalories(
      exercise: cardioType,
      durationMin: durationMinutes.toDouble(),
      speedMph: speedMph,
      effort: intensity,
      userWeightKg: weightKg,
      userBmr: bmr,
    ).round();
  }

  /// Get MET value for Cardio types
  static double getCardioMet(String cardioType, String intensity) {
    final normKey = _normalizeName(cardioType);
    final effKey = intensity.toLowerCase();

    if (cardioSpeedTables.containsKey(normKey)) {
      final speed = normKey == 'running' ? 6.0 : normKey == 'walking' ? 3.0 : 12.0;
      final tiers = cardioSpeedTables[normKey]!;
      return tiers.firstWhere((t) => speed <= t['maxMph']!, orElse: () => tiers.last)['met']!;
    } else if (cardioEffortTables.containsKey(normKey)) {
      final effortTable = cardioEffortTables[normKey]!;
      return effortTable[effKey] ?? effortTable['moderate'] ?? 7.0;
    }

    double baseMet = 7.0;
    if (normKey.contains('run')) {
      baseMet = 8.5;
    } else if (normKey.contains('cycl') || normKey.contains('bike')) {
      baseMet = 7.5;
    } else if (normKey.contains('swim')) {
      baseMet = 8.0;
    } else if (normKey.contains('row')) {
      baseMet = 7.0;
    } else if (normKey.contains('hiit')) {
      baseMet = 9.5;
    } else if (normKey.contains('walk')) {
      baseMet = 3.5;
    } else if (normKey.contains('stair')) {
      baseMet = 8.8;
    } else if (normKey.contains('rope')) {
      baseMet = 11.0;
    }

    if (effKey.contains('low') || effKey.contains('light')) {
      baseMet *= 0.8;
    } else if (effKey.contains('high') || effKey.contains('vigorous')) {
      baseMet *= 1.2;
    } else if (effKey.contains('extreme') || effKey.contains('max')) {
      baseMet *= 1.4;
    }

    return baseMet;
  }

  // --- STRENGTH ENGINE ---

  static final Map<String, Map<String, double>> strengthMetTable = {
    'benchpress': {'light': 3.5, 'moderate': 5.0, 'heavy': 6.0},
    'squat': {'light': 5.0, 'moderate': 6.0, 'heavy': 8.0},
    'deadlift': {'light': 5.5, 'moderate': 7.0, 'heavy': 9.0},
    'overheadpress': {'light': 3.5, 'moderate': 5.0, 'heavy': 6.0},
    'pullups': {'light': 4.0, 'moderate': 6.0, 'heavy': 8.0},
    'bicepcurl': {'light': 2.5, 'moderate': 3.5, 'heavy': 4.5},
    'barbellrow': {'light': 4.0, 'moderate': 5.5, 'heavy': 7.0},
    'latpulldown': {'light': 3.5, 'moderate': 5.0, 'heavy': 6.0},
    'legpress': {'light': 4.0, 'moderate': 5.5, 'heavy': 7.0},
    'lunges': {'light': 4.0, 'moderate': 5.5, 'heavy': 7.0},
    'hipthrust': {'light': 4.0, 'moderate': 5.5, 'heavy': 7.0},
    'romaniandeadlift': {'light': 5.0, 'moderate': 6.5, 'heavy': 8.0},
    'dumbbellshoulderpress': {'light': 3.5, 'moderate': 5.0, 'heavy': 6.0},
    'dips': {'light': 4.0, 'moderate': 6.0, 'heavy': 7.5},
  };

  static String getStrengthTier(double loadRatio) {
    if (loadRatio < 0.3) return 'light';
    if (loadRatio < 0.6) return 'moderate';
    return 'heavy';
  }

  static final Map<String, double> customEffortMet = {
    'light': 3.5,
    'moderate': 5.0,
    'vigorous': 7.0,
  };

  /// Calculates strength exercise calories per set with BMR correction
  static Map<String, dynamic> getStrengthCalories({
    required String exercise,
    required List<ExerciseSet> setsData,
    required double userBodyweightKg,
    required double userBmr,
    double secPerRep = 3.0,
    double restSecPerSet = 60.0,
    bool includeRest = false,
  }) {
    final normKey = _normalizeName(exercise);
    final table = strengthMetTable[normKey];
    if (table == null) {
      throw ArgumentError('Unknown strength exercise: $exercise');
    }

    double totalCalories = 0.0;
    final breakdown = <Map<String, dynamic>>[];

    for (int i = 0; i < setsData.length; i++) {
      final set = setsData[i];
      final loadRatio = set.weightKg / userBodyweightKg;
      final tier = getStrengthTier(loadRatio);
      final met = table[tier] ?? 5.0;
      final workMin = (set.reps * secPerRep) / 60.0;
      final restMin = includeRest && i < setsData.length - 1 ? restSecPerSet / 60.0 : 0.0;
      final durationMin = workMin + restMin;

      final calories = calculateCaloriesEngine(
        met: met,
        userWeightKg: userBodyweightKg,
        userBmr: userBmr,
        durationMin: durationMin,
      );

      totalCalories += calories;
      breakdown.add({
        'setNumber': i + 1,
        'reps': set.reps,
        'weightKg': set.weightKg,
        'met': met,
        'calories': calories,
      });
    }

    return {
      'totalCalories': double.parse(totalCalories.toStringAsFixed(1)),
      'breakdown': breakdown,
    };
  }

  /// Calculates custom exercise calories for exercises not in table
  static double getCustomExerciseCalories({
    String effort = 'moderate',
    required List<ExerciseSet> setsData,
    required double userBodyweightKg,
    required double userBmr,
    double secPerRep = 3.0,
  }) {
    final met = customEffortMet[effort.toLowerCase()] ?? customEffortMet['moderate']!;
    final totalReps = setsData.fold(0, (sum, s) => sum + s.reps);
    final durationMin = (totalReps * secPerRep) / 60.0;
    return calculateCaloriesEngine(
      met: met,
      userWeightKg: userBodyweightKg,
      userBmr: userBmr,
      durationMin: durationMin,
    );
  }

  /// Legacy adapter for Strength workouts
  static int calculateExerciseCalories({
    required String exerciseName,
    required List<ExerciseSet> sets,
    required int durationMinutes,
    required double weightKg,
    double? userBmr,
    bool includeRest = false,
  }) {
    final bmr = userBmr ?? (weightKg * 24.0);
    final normKey = _normalizeName(exerciseName);

    if (strengthMetTable.containsKey(normKey)) {
      final res = getStrengthCalories(
        exercise: exerciseName,
        setsData: sets,
        userBodyweightKg: weightKg,
        userBmr: bmr,
        includeRest: includeRest,
      );
      return (res['totalCalories'] as double).round();
    } else {
      return getCustomExerciseCalories(
        effort: 'moderate',
        setsData: sets,
        userBodyweightKg: weightKg,
        userBmr: bmr,
      ).round();
    }
  }

  // --- STEP ENGINE ---

  /// Calculates Step Calories using distance, duration at pace, and BMR correction
  static double getStepCalories({
    required int steps,
    required double userWeightKg,
    required double userBmr,
    double? userHeightCm,
    double? strideM,
    double avgSpeedMph = 3.0,
  }) {
    if (steps <= 0) return 0.0;
    // Use height-adjusted stride (heightCm * 0.414 / 100) if available, else 0.762m
    final actualStride = strideM ?? (userHeightCm != null && userHeightCm > 0 ? (userHeightCm * 0.414 / 100.0) : 0.762);
    final distanceKm = (steps * actualStride) / 1000.0;
    final durationHr = distanceKm / (avgSpeedMph * 1.60934);
    const met = 3.5;
    return calculateCaloriesEngine(
      met: met,
      userWeightKg: userWeightKg,
      userBmr: userBmr,
      durationMin: durationHr * 60.0,
    );
  }

  /// Legacy steps adapter
  static int calculateStepsCalories(int steps, double weightKg, {double? userBmr, double? userHeightCm}) {
    if (steps <= 0) return 0;
    final bmr = userBmr ?? (weightKg * 24.0);
    return getStepCalories(
      steps: steps,
      userWeightKg: weightKg,
      userBmr: bmr,
      userHeightCm: userHeightCm,
    ).round();
  }
}
