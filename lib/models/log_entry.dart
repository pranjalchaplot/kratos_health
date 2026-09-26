import 'exercise_set.dart';

enum LogType { meal, water, activity, sleep, digital }

class LogEntry {
  final String id;
  final DateTime timestamp;
  final LogType type;
  final String title;
  final String? subtitle;
  final int calories;
  final int protein;
  final int carbs;
  final int fats;
  final double amount; // for water (L) or sleep (h)
  final int count; // for steps

  // Extended Activity Tracker fields
  final String? activityCategory; // 'steps', 'cardio', 'exercise'
  final String? exerciseName;
  final List<ExerciseSet>? sets;
  final String? cardioType;
  final String? intensity;
  final int? durationMinutes;
  final double? distanceKm;

  LogEntry({
    required this.id,
    required this.timestamp,
    required this.type,
    required this.title,
    this.subtitle,
    this.calories = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fats = 0,
    this.amount = 0.0,
    this.count = 0,
    this.activityCategory,
    this.exerciseName,
    this.sets,
    this.cardioType,
    this.intensity,
    this.durationMinutes,
    this.distanceKm,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'type': type.name,
      'title': title,
      'subtitle': subtitle,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fats': fats,
      'amount': amount,
      'count': count,
      'activityCategory': activityCategory,
      'exerciseName': exerciseName,
      'sets': sets?.map((s) => s.toJson()).toList(),
      'cardioType': cardioType,
      'intensity': intensity,
      'durationMinutes': durationMinutes,
      'distanceKm': distanceKm,
    };
  }

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    return LogEntry(
      id: json['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      type: LogType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => LogType.meal,
      ),
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String?,
      calories: (json['calories'] as num?)?.toInt() ?? 0,
      protein: (json['protein'] as num?)?.toInt() ?? 0,
      carbs: (json['carbs'] as num?)?.toInt() ?? 0,
      fats: (json['fats'] as num?)?.toInt() ?? 0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      count: (json['count'] as num?)?.toInt() ?? 0,
      activityCategory: json['activityCategory'] as String?,
      exerciseName: json['exerciseName'] as String?,
      sets: (json['sets'] as List<dynamic>?)
          ?.map((s) => ExerciseSet.fromJson(s as Map<String, dynamic>))
          .toList(),
      cardioType: json['cardioType'] as String?,
      intensity: json['intensity'] as String?,
      durationMinutes: (json['durationMinutes'] as num?)?.toInt(),
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
    );
  }
}
