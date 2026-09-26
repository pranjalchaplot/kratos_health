import 'dart:convert';
import 'log_entry.dart';
import 'user_goals.dart';

class DailyLog {
  final DateTime date;
  List<LogEntry> entries;

  // Goals associated with this day
  int caloriesGoal;
  int proteinGoal;
  int carbsGoal;
  int fatsGoal;
  int stepsGoal;
  double waterGoal;
  double sleepGoal;
  int digitalGoalHours;

  // Manual overrides/additions if any
  int additionalCalories;
  int additionalSteps;
  double additionalWater;
  double additionalSleep;
  int digitalHours;
  int digitalMinutes;

  DailyLog({
    required this.date,
    List<LogEntry>? entries,
    UserGoals? goals,
    this.caloriesGoal = 3200,
    this.proteinGoal = 180,
    this.carbsGoal = 250,
    this.fatsGoal = 70,
    this.stepsGoal = 10000,
    this.waterGoal = 3.5,
    this.sleepGoal = 8.5,
    this.digitalGoalHours = 10,
    this.additionalCalories = 0,
    this.additionalSteps = 0,
    this.additionalWater = 0.0,
    this.additionalSleep = 0.0,
    this.digitalHours = 4,
    this.digitalMinutes = 12,
  }) : entries = entries ?? [];

  // Date key in format YYYY-MM-DD
  String get dateKey =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  // Dynamic getters calculated from entries + additions
  int get caloriesBurned {
    int total = additionalCalories;
    for (var entry in entries) {
      if (entry.type == LogType.meal || entry.type == LogType.activity) {
        total += entry.calories;
      }
    }
    return total;
  }

  int get protein {
    int total = 0;
    for (var entry in entries) {
      if (entry.type == LogType.meal) {
        total += entry.protein;
      }
    }
    return total;
  }

  int get carbs {
    int total = 0;
    for (var entry in entries) {
      if (entry.type == LogType.meal) {
        total += entry.carbs;
      }
    }
    return total;
  }

  int get fats {
    int total = 0;
    for (var entry in entries) {
      if (entry.type == LogType.meal) {
        total += entry.fats;
      }
    }
    return total;
  }

  int get steps {
    int total = additionalSteps;
    for (var entry in entries) {
      if (entry.type == LogType.activity) {
        total += entry.count;
      }
    }
    return total;
  }

  double get water {
    double total = additionalWater;
    for (var entry in entries) {
      if (entry.type == LogType.water) {
        total += entry.amount;
      }
    }
    return double.parse(total.toStringAsFixed(2));
  }

  double get sleep {
    double total = additionalSleep;
    for (var entry in entries) {
      if (entry.type == LogType.sleep) {
        total += entry.amount;
      }
    }
    return double.parse(total.toStringAsFixed(1));
  }

  // Progress calculations clamped 0.0 -> 1.0
  double get caloriesProgress => caloriesGoal > 0
      ? (caloriesBurned / caloriesGoal).clamp(0.0, 1.0)
      : 0.0;

  double get proteinProgress =>
      proteinGoal > 0 ? (protein / proteinGoal).clamp(0.0, 1.0) : 0.0;

  double get carbsProgress =>
      carbsGoal > 0 ? (carbs / carbsGoal).clamp(0.0, 1.0) : 0.0;

  double get fatsProgress =>
      fatsGoal > 0 ? (fats / fatsGoal).clamp(0.0, 1.0) : 0.0;

  double get stepsProgress =>
      stepsGoal > 0 ? (steps / stepsGoal).clamp(0.0, 1.0) : 0.0;

  double get waterProgress =>
      waterGoal > 0 ? (water / waterGoal).clamp(0.0, 1.0) : 0.0;

  double get sleepProgress =>
      sleepGoal > 0 ? (sleep / sleepGoal).clamp(0.0, 1.0) : 0.0;

  double get digitalProgress {
    final totalMinutes = (digitalHours * 60) + digitalMinutes;
    final goalMinutes = digitalGoalHours * 60;
    return goalMinutes > 0
        ? (totalMinutes / goalMinutes).clamp(0.0, 1.0)
        : 0.0;
  }

  void applyGoals(UserGoals goals) {
    caloriesGoal = goals.caloriesGoal;
    proteinGoal = goals.proteinGoal;
    carbsGoal = goals.carbsGoal;
    fatsGoal = goals.fatsGoal;
    stepsGoal = goals.stepsGoal;
    waterGoal = goals.waterGoal;
    sleepGoal = goals.sleepGoal;
    digitalGoalHours = goals.digitalGoalHours;
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'entries': entries.map((e) => e.toJson()).toList(),
      'caloriesGoal': caloriesGoal,
      'proteinGoal': proteinGoal,
      'carbsGoal': carbsGoal,
      'fatsGoal': fatsGoal,
      'stepsGoal': stepsGoal,
      'waterGoal': waterGoal,
      'sleepGoal': sleepGoal,
      'digitalGoalHours': digitalGoalHours,
      'additionalCalories': additionalCalories,
      'additionalSteps': additionalSteps,
      'additionalWater': additionalWater,
      'additionalSleep': additionalSleep,
      'digitalHours': digitalHours,
      'digitalMinutes': digitalMinutes,
    };
  }

  factory DailyLog.fromJson(Map<String, dynamic> json) {
    return DailyLog(
      date: DateTime.parse(json['date'] as String),
      entries: (json['entries'] as List<dynamic>?)
              ?.map((e) => LogEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      caloriesGoal: (json['caloriesGoal'] as num?)?.toInt() ?? 3200,
      proteinGoal: (json['proteinGoal'] as num?)?.toInt() ?? 180,
      carbsGoal: (json['carbsGoal'] as num?)?.toInt() ?? 250,
      fatsGoal: (json['fatsGoal'] as num?)?.toInt() ?? 70,
      stepsGoal: (json['stepsGoal'] as num?)?.toInt() ?? 10000,
      waterGoal: (json['waterGoal'] as num?)?.toDouble() ?? 3.5,
      sleepGoal: (json['sleepGoal'] as num?)?.toDouble() ?? 8.5,
      digitalGoalHours: (json['digitalGoalHours'] as num?)?.toInt() ?? 10,
      additionalCalories: (json['additionalCalories'] as num?)?.toInt() ?? 0,
      additionalSteps: (json['additionalSteps'] as num?)?.toInt() ?? 0,
      additionalWater: (json['additionalWater'] as num?)?.toDouble() ?? 0.0,
      additionalSleep: (json['additionalSleep'] as num?)?.toDouble() ?? 0.0,
      digitalHours: (json['digitalHours'] as num?)?.toInt() ?? 4,
      digitalMinutes: (json['digitalMinutes'] as num?)?.toInt() ?? 12,
    );
  }

  // Create initial demo log for today if first launch
  factory DailyLog.initialDemo(DateTime targetDate, UserGoals goals) {
    final log = DailyLog(
      date: targetDate,
      caloriesGoal: goals.caloriesGoal,
      proteinGoal: goals.proteinGoal,
      carbsGoal: goals.carbsGoal,
      fatsGoal: goals.fatsGoal,
      stepsGoal: goals.stepsGoal,
      waterGoal: goals.waterGoal,
      sleepGoal: goals.sleepGoal,
      digitalGoalHours: goals.digitalGoalHours,
      digitalHours: 4,
      digitalMinutes: 12,
    );

    // Seed realistic sample entries
    log.entries = [
      LogEntry(
        id: '1',
        timestamp: targetDate.add(const Duration(hours: 8)),
        type: LogType.meal,
        title: 'Oatmeal & Protein Shake',
        subtitle: 'Breakfast',
        calories: 550,
        protein: 42,
        carbs: 65,
        fats: 12,
      ),
      LogEntry(
        id: '2',
        timestamp: targetDate.add(const Duration(hours: 9)),
        type: LogType.water,
        title: 'Morning Water',
        subtitle: '750ml Intake',
        amount: 0.75,
      ),
      LogEntry(
        id: '3',
        timestamp: targetDate.add(const Duration(hours: 11)),
        type: LogType.activity,
        title: 'Morning Upper Body Workout',
        subtitle: 'Hypertrophy Session',
        calories: 420,
        count: 3200,
      ),
      LogEntry(
        id: '4',
        timestamp: targetDate.add(const Duration(hours: 13)),
        type: LogType.meal,
        title: 'Grilled Chicken Bowl',
        subtitle: 'Lunch',
        calories: 780,
        protein: 65,
        carbs: 85,
        fats: 18,
      ),
      LogEntry(
        id: '5',
        timestamp: targetDate.add(const Duration(hours: 14)),
        type: LogType.water,
        title: 'Afternoon Hydration',
        subtitle: '1000ml Intake',
        amount: 1.0,
      ),
      LogEntry(
        id: '6',
        timestamp: targetDate.add(const Duration(hours: 7)),
        type: LogType.sleep,
        title: 'Night Sleep',
        subtitle: 'Deep Recovery',
        amount: 7.5,
      ),
      LogEntry(
        id: '7',
        timestamp: targetDate.add(const Duration(hours: 17)),
        type: LogType.activity,
        title: 'Evening Walk',
        subtitle: 'Cardio',
        calories: 210,
        count: 5232,
      ),
      LogEntry(
        id: '8',
        timestamp: targetDate.add(const Duration(hours: 18)),
        type: LogType.meal,
        title: 'Salmon & Quinoa',
        subtitle: 'Dinner',
        calories: 700,
        protein: 35,
        carbs: 60,
        fats: 24,
      ),
      LogEntry(
        id: '9',
        timestamp: targetDate.add(const Duration(hours: 19)),
        type: LogType.water,
        title: 'Evening Hydration',
        subtitle: '350ml Intake',
        amount: 0.35,
      ),
    ];

    return log;
  }

  String encode() => jsonEncode(toJson());
  factory DailyLog.decode(String str) => DailyLog.fromJson(jsonDecode(str));
}
