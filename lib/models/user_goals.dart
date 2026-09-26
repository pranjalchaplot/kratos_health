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

  UserGoals({
    this.caloriesGoal = 3200,
    this.proteinGoal = 180,
    this.carbsGoal = 250,
    this.fatsGoal = 70,
    this.stepsGoal = 10000,
    this.waterGoal = 3.5,
    this.sleepGoal = 8.5,
    this.digitalGoalHours = 10,
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
    );
  }

  String encode() => jsonEncode(toJson());

  factory UserGoals.decode(String str) => UserGoals.fromJson(jsonDecode(str));
}
