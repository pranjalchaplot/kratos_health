import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/models/user_goals.dart';
import 'package:kratos_app/models/exercise_set.dart';
import 'package:kratos_app/services/calorie_calculator_service.dart';

void main() {
  group('CalorieCalculatorService & Engine Tests', () {
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

    test('Engine calculateCalories matches exact BMR correction ratio math', () {
      // met: 10.0, weight: 75kg, bmr: 1800, duration: 60min (1 hr)
      // durationHr = 1.0, correction = (1800 / 24) / 75 = 75 / 75 = 1.0
      // calories = 10 * 75 * 1.0 * 1.0 = 750.0
      final cal = CalorieCalculatorService.calculateCaloriesEngine(
        met: 10.0,
        userWeightKg: 75.0,
        userBmr: 1800.0,
        durationMin: 60.0,
      );
      expect(cal, equals(750.0));
    });

    test('Engine Cardio Speed table lookups (Running, Walking, Cycling)', () {
      final runningCal = CalorieCalculatorService.getCardioCalories(
        exercise: 'Running',
        durationMin: 30.0,
        speedMph: 7.0, // MET 11.0
        userWeightKg: 70.0,
        userBmr: 1680.0, // correction = (1680/24)/70 = 70/70 = 1.0
      );
      // 11.0 * 70 * 0.5 * 1.0 = 385.0
      expect(runningCal, equals(385.0));

      final walkingCal = CalorieCalculatorService.getCardioCalories(
        exercise: 'Walking',
        durationMin: 60.0,
        speedMph: 3.0, // MET 3.5
        userWeightKg: 80.0,
        userBmr: 1920.0, // correction = (1920/24)/80 = 80/80 = 1.0
      );
      // 3.5 * 80 * 1.0 * 1.0 = 280.0
      expect(walkingCal, equals(280.0));
    });

    test('Engine Cardio Effort table lookups (Swimming, HIIT, Jump Rope)', () {
      final hiitCal = CalorieCalculatorService.getCardioCalories(
        exercise: 'HIIT',
        durationMin: 20.0,
        effort: 'vigorous', // MET 10.0
        userWeightKg: 75.0,
        userBmr: 1800.0,
      );
      // 10.0 * 75 * (20/60) * 1.0 = 250.0
      expect(hiitCal, equals(250.0));
    });

    test('Engine Strength set-by-set MET tier classification and calories', () {
      final sets = [
        ExerciseSet(setNumber: 1, reps: 10, weightKg: 20.0), // 20/80 = 0.25 (light, MET 3.5)
        ExerciseSet(setNumber: 2, reps: 10, weightKg: 40.0), // 40/80 = 0.50 (moderate, MET 5.0)
        ExerciseSet(setNumber: 3, reps: 10, weightKg: 60.0), // 60/80 = 0.75 (heavy, MET 6.0)
      ];

      final res = CalorieCalculatorService.getStrengthCalories(
        exercise: 'Bench Press',
        setsData: sets,
        userBodyweightKg: 80.0,
        userBmr: 1920.0, // correction = (1920/24)/80 = 1.0
      );

      expect(res['totalCalories'], greaterThan(0));
      final breakdown = res['breakdown'] as List<Map<String, dynamic>>;
      expect(breakdown.length, equals(3));
      expect(breakdown[0]['met'], equals(3.5));
      expect(breakdown[1]['met'], equals(5.0));
      expect(breakdown[2]['met'], equals(6.0));
    });

    test('Engine Step Calories calculation', () {
      final cal = CalorieCalculatorService.getStepCalories(
        steps: 10000,
        userWeightKg: 75.0,
        userBmr: 1800.0,
        userHeightCm: 180.0,
      );
      expect(cal, greaterThan(200.0));
    });
  });
}
