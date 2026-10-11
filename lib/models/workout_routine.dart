import 'dart:convert';

class RoutineExercise {
  final String name;
  final int defaultSets;
  final int defaultReps;
  final double defaultWeightKg;
  final String? notes;

  RoutineExercise({
    required this.name,
    this.defaultSets = 3,
    this.defaultReps = 10,
    this.defaultWeightKg = 0.0,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'defaultSets': defaultSets,
        'defaultReps': defaultReps,
        'defaultWeightKg': defaultWeightKg,
        'notes': notes,
      };

  factory RoutineExercise.fromJson(Map<String, dynamic> json) => RoutineExercise(
        name: json['name'] as String? ?? 'Exercise',
        defaultSets: (json['defaultSets'] as num?)?.toInt() ?? 3,
        defaultReps: (json['defaultReps'] as num?)?.toInt() ?? 10,
        defaultWeightKg: (json['defaultWeightKg'] as num?)?.toDouble() ?? 0.0,
        notes: json['notes'] as String?,
      );
}

class WorkoutRoutine {
  final String id;
  final String name;
  final String category; // 'split', 'cardio', 'mobility', 'custom'
  final String description;
  final int targetDurationMinutes;
  final List<RoutineExercise> exercises;
  final bool isPreset;

  WorkoutRoutine({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    this.targetDurationMinutes = 45,
    required this.exercises,
    this.isPreset = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'description': description,
        'targetDurationMinutes': targetDurationMinutes,
        'exercises': exercises.map((e) => e.toJson()).toList(),
        'isPreset': isPreset,
      };

  factory WorkoutRoutine.fromJson(Map<String, dynamic> json) => WorkoutRoutine(
        id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: json['name'] as String? ?? 'Custom Routine',
        category: json['category'] as String? ?? 'custom',
        description: json['description'] as String? ?? '',
        targetDurationMinutes: (json['targetDurationMinutes'] as num?)?.toInt() ?? 45,
        exercises: (json['exercises'] as List<dynamic>?)
                ?.map((e) => RoutineExercise.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        isPreset: json['isPreset'] as bool? ?? false,
      );

  String encode() => jsonEncode(toJson());
  factory WorkoutRoutine.decode(String str) => WorkoutRoutine.fromJson(jsonDecode(str));

  // --- Standard Built-in Athletic Presets ---
  static List<WorkoutRoutine> get builtInPresets => [
        WorkoutRoutine(
          id: 'preset_push_split',
          name: 'Push Split (Chest & Triceps)',
          category: 'split',
          description: 'Upper body anterior chain hypertrophy focusing on pressing strength.',
          targetDurationMinutes: 50,
          isPreset: true,
          exercises: [
            RoutineExercise(name: 'Bench Press', defaultSets: 3, defaultReps: 10, defaultWeightKg: 60.0),
            RoutineExercise(name: 'Overhead Press', defaultSets: 3, defaultReps: 8, defaultWeightKg: 40.0),
            RoutineExercise(name: 'Incline DB Press', defaultSets: 3, defaultReps: 12, defaultWeightKg: 22.0),
            RoutineExercise(name: 'Dips', defaultSets: 3, defaultReps: 12, defaultWeightKg: 0.0),
          ],
        ),
        WorkoutRoutine(
          id: 'preset_pull_split',
          name: 'Pull Split (Back & Biceps)',
          category: 'split',
          description: 'Posterior chain recruitment for lat width, rhomboid density & pull power.',
          targetDurationMinutes: 50,
          isPreset: true,
          exercises: [
            RoutineExercise(name: 'Deadlift', defaultSets: 3, defaultReps: 6, defaultWeightKg: 100.0),
            RoutineExercise(name: 'Barbell Row', defaultSets: 3, defaultReps: 10, defaultWeightKg: 60.0),
            RoutineExercise(name: 'Lat Pulldown', defaultSets: 3, defaultReps: 12, defaultWeightKg: 55.0),
            RoutineExercise(name: 'Bicep Curl', defaultSets: 3, defaultReps: 12, defaultWeightKg: 14.0),
          ],
        ),
        WorkoutRoutine(
          id: 'preset_leg_split',
          name: 'Leg Split (Quads & Hamstrings)',
          category: 'split',
          description: 'Lower body foundation: maximal motor unit activation and femoral strength.',
          targetDurationMinutes: 55,
          isPreset: true,
          exercises: [
            RoutineExercise(name: 'Squat', defaultSets: 3, defaultReps: 8, defaultWeightKg: 80.0),
            RoutineExercise(name: 'Romanian Deadlift', defaultSets: 3, defaultReps: 10, defaultWeightKg: 70.0),
            RoutineExercise(name: 'Leg Press', defaultSets: 3, defaultReps: 12, defaultWeightKg: 140.0),
            RoutineExercise(name: 'Lunges', defaultSets: 3, defaultReps: 12, defaultWeightKg: 20.0),
          ],
        ),
        WorkoutRoutine(
          id: 'preset_cardio_hiit',
          name: 'Cardio & Conditioning Blast',
          category: 'cardio',
          description: 'VO2 max conditioning, aerobic threshold capacity, and cardiovascular resilience.',
          targetDurationMinutes: 35,
          isPreset: true,
          exercises: [
            RoutineExercise(name: 'Running', defaultSets: 1, defaultReps: 1, defaultWeightKg: 0.0),
            RoutineExercise(name: 'Jump Rope', defaultSets: 3, defaultReps: 100, defaultWeightKg: 0.0),
            RoutineExercise(name: 'HIIT Intervals', defaultSets: 4, defaultReps: 1, defaultWeightKg: 0.0),
          ],
        ),
        WorkoutRoutine(
          id: 'preset_mobility_core',
          name: 'Morning Mobility & Core Flow',
          category: 'mobility',
          description: 'Joint de-stiffening, spine decompression, and core stabilization.',
          targetDurationMinutes: 20,
          isPreset: true,
          exercises: [
            RoutineExercise(name: 'Planks', defaultSets: 3, defaultReps: 60, defaultWeightKg: 0.0),
            RoutineExercise(name: 'Hip Thrust', defaultSets: 3, defaultReps: 15, defaultWeightKg: 0.0),
          ],
        ),
      ];
}
