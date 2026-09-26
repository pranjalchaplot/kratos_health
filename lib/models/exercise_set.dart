import 'dart:convert';

class ExerciseSet {
  int setNumber;
  int reps;
  double weightKg;

  ExerciseSet({
    required this.setNumber,
    required this.reps,
    required this.weightKg,
  });

  Map<String, dynamic> toJson() {
    return {
      'setNumber': setNumber,
      'reps': reps,
      'weightKg': weightKg,
    };
  }

  factory ExerciseSet.fromJson(Map<String, dynamic> json) {
    return ExerciseSet(
      setNumber: (json['setNumber'] as num?)?.toInt() ?? 1,
      reps: (json['reps'] as num?)?.toInt() ?? 10,
      weightKg: (json['weightKg'] as num?)?.toDouble() ?? 0.0,
    );
  }

  String encode() => jsonEncode(toJson());
  factory ExerciseSet.decode(String str) => ExerciseSet.fromJson(jsonDecode(str));
}
