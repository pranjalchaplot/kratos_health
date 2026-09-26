import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/models/user_goals.dart';
import 'package:kratos_app/models/exercise_set.dart';
import 'package:kratos_app/services/calorie_calculator_service.dart';

void main() {
  group('CalorieCalculatorService Tests', () {
    test('Calculates BMR using Mifflin-St Jeor equation correctly', () {
      final maleGoals = UserGoals(
        weightKg: 80.0,
        heightCm: 180.0,
        age: 25,
        gender: 'male',
        bmrFormula: 'mifflin',
      );
      // 10*80 + 6.25*180 - 5*25 + 5 = 800 + 1125 - 125 + 5 = 1805
      expect(CalorieCalculatorService.calculateBmr(maleGoals), equals(1805));

      final femaleGoals = UserGoals(
        weightKg: 60.0,
        heightCm: 165.0,
        age: 30,
        gender: 'female',
        bmrFormula: 'mifflin',
      );
      // 10*60 + 6.25*165 - 5*30 - 161 = 600 + 1031.25 - 150 - 161 = 1320.25 -> 1320
      expect(CalorieCalculatorService.calculateBmr(femaleGoals), equals(1320));
    });

    test('Calculates BMR using Harris-Benedict formula', () {
      final goals = UserGoals(
        weightKg: 75.0,
        heightCm: 175.0,
        age: 28,
        gender: 'male',
        bmrFormula: 'harris',
      );
      expect(CalorieCalculatorService.calculateBmr(goals), greaterThan(1500));
    });

    test('Calculates custom manual BMR', () {
      final goals = UserGoals(
        bmrFormula: 'custom',
        customBmr: 1950,
      );
      expect(CalorieCalculatorService.calculateBmr(goals), equals(1950));
    });

    test('Calculates Steps Calorie Burn accurately', () {
      final cal = CalorieCalculatorService.calculateStepsCalories(10000, 75.0);
      // 10000 * 75 * 0.00045 = 337.5 -> 338
      expect(cal, equals(338));
    });

    test('Calculates Cardio Calorie Burn accurately', () {
      final cal = CalorieCalculatorService.calculateCardioCalories(
        cardioType: 'Running',
        intensity: 'Moderate',
        durationMinutes: 30,
        weightKg: 75.0,
      );
      expect(cal, greaterThan(250));
    });

    test('Calculates Exercise Strength Calorie Burn incorporating workload volume', () {
      final sets = [
        ExerciseSet(setNumber: 1, reps: 10, weightKg: 80.0),
        ExerciseSet(setNumber: 2, reps: 10, weightKg: 80.0),
        ExerciseSet(setNumber: 3, reps: 10, weightKg: 80.0),
      ];
      final cal = CalorieCalculatorService.calculateExerciseCalories(
        exerciseName: 'Bench Press',
        sets: sets,
        durationMinutes: 30,
        weightKg: 80.0,
      );
      expect(cal, greaterThan(150));
    });
  });
}
