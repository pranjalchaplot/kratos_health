import 'dart:convert';

class UserGoals {
  int caloriesGoal;
  int proteinGoal;
  int carbsGoal;
  int fatsGoal;
  int stepsGoal;
  double waterGoal;
  double sleepGoal;
  int digitalGoalHours;

  double? weightKg;
  double? heightCm;
  int? age;
  String? primaryFocus;
  String? userName;

  UserGoals({
    this.caloriesGoal = 3200,
    this.proteinGoal = 180,
    this.carbsGoal = 250,
    this.fatsGoal = 70,
    this.stepsGoal = 10000,
    this.waterGoal = 3.5,
    this.sleepGoal = 8.5,
    this.digitalGoalHours = 10,
    this.weightKg,
    this.heightCm,
    this.age,
    this.primaryFocus,
    this.userName,
  });

  Map<String, dynamic> toJson() {
    return {
      'caloriesGoal': caloriesGoal,
      'proteinGoal': proteinGoal,
      'carbsGoal': carbsGoal,
      'fatsGoal': fatsGoal,
      'stepsGoal': stepsGoal,
      'waterGoal': waterGoal,
      'sleepGoal': sleepGoal,
      'digitalGoalHours': digitalGoalHours,
      'weightKg': weightKg,
      'heightCm': heightCm,
      'age': age,
      'primaryFocus': primaryFocus,
      'userName': userName,
    };
  }

  factory UserGoals.fromJson(Map<String, dynamic> json) {
    return UserGoals(
      caloriesGoal: (json['caloriesGoal'] as num?)?.toInt() ?? 3200,
      proteinGoal: (json['proteinGoal'] as num?)?.toInt() ?? 180,
      carbsGoal: (json['carbsGoal'] as num?)?.toInt() ?? 250,
      fatsGoal: (json['fatsGoal'] as num?)?.toInt() ?? 70,
      stepsGoal: (json['stepsGoal'] as num?)?.toInt() ?? 10000,
      waterGoal: (json['waterGoal'] as num?)?.toDouble() ?? 3.5,
      sleepGoal: (json['sleepGoal'] as num?)?.toDouble() ?? 8.5,
      digitalGoalHours: (json['digitalGoalHours'] as num?)?.toInt() ?? 10,
      weightKg: (json['weightKg'] as num?)?.toDouble(),
      heightCm: (json['heightCm'] as num?)?.toDouble(),
      age: (json['age'] as num?)?.toInt(),
      primaryFocus: json['primaryFocus'] as String?,
      userName: json['userName'] as String?,
    );
  }

  String encode() => jsonEncode(toJson());

  factory UserGoals.decode(String str) => UserGoals.fromJson(jsonDecode(str));
}

