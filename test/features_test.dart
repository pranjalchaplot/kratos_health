import 'package:flutter_test/flutter_test.dart';
import 'package:soma_app/models/daily_log.dart';
import 'package:soma_app/models/log_entry.dart';
import 'package:soma_app/models/user_goals.dart';
import 'package:soma_app/models/dashboard_data.dart';

import 'package:soma_app/services/nutrition/meal_verdict_engine.dart';

void main() {
  group('Calorie Deficit & Trend Tests', () {
    test('Calculates calorie deficit correctly as Total Burn - Consumption', () {
      final goals = UserGoals(
        weightKg: 75.0,
        heightCm: 180.0,
        age: 25,
        gender: 'male',
        caloriesGoal: 2500,
      );

      final today = DateTime.now();
      final log = DailyLog.empty(today, goals);

      // Log meal: 500 kcal
      log.entries.add(LogEntry(
        id: '1',
        timestamp: today,
        type: LogType.meal,
        title: 'Lunch',
        calories: 500,
        protein: 30,
        carbs: 45,
        fats: 15,
      ));

      // Log workout: 400 kcal
      log.entries.add(LogEntry(
        id: '2',
        timestamp: today,
        type: LogType.activity,
        title: 'Cardio',
        calories: 400,
      ));

      final data = DashboardData.fromDailyLog(log, goals, 1, 0);

      expect(data.caloriesConsumed, equals(500));
      expect(data.caloriesBurned, equals(400));
      // Calorie deficit = totalCaloriesBurned - caloriesConsumed
      expect(data.calorieDeficit, equals(data.totalCaloriesBurned - 500));
    });

    test('Computes Today vs Yesterday trend direction (up / down / neutral)', () {
      final goals = UserGoals();
      final todayDate = DateTime.now();
      final yesterdayDate = todayDate.subtract(const Duration(days: 1));

      final todayLog = DailyLog.empty(todayDate, goals);
      todayLog.additionalSteps = 8000;
      todayLog.additionalWater = 2.5;
      todayLog.additionalSleep = 7.0;

      final yesterdayLog = DailyLog.empty(yesterdayDate, goals);
      yesterdayLog.additionalSteps = 5000;
      yesterdayLog.additionalWater = 3.0;
      yesterdayLog.additionalSleep = 7.0;

      final data = DashboardData.fromDailyLog(
        todayLog,
        goals,
        2,
        0,
        yesterdayLog: yesterdayLog,
      );

      expect(data.hasYesterdayData, isTrue);
      // Steps: 8000 vs 5000 -> Increased (up)
      expect(data.stepsTrend, equals(MetricTrend.up));
      expect(data.stepsDelta, equals(3000));

      // Water: 2.5 vs 3.0 -> Decreased (down)
      expect(data.waterTrend, equals(MetricTrend.down));
      expect(data.waterDelta, equals(-0.5));

      // Sleep: 7.0 vs 7.0 -> Neutral
      expect(data.sleepTrend, equals(MetricTrend.neutral));
      expect(data.sleepDelta, equals(0.0));
    });

    test('Meal Health Verdict categorizes whole foods, balanced meals, high protein, and high cal accurately', () {
      // 1. High Protein Lean meal: 30g protein with 240 kcal -> SUPER CLEAN
      final superClean = MealVerdict.evaluate(calories: 240, protein: 30, carbs: 10, fats: 4);
      expect(superClean.tag, equals(MealVerdictTag.superClean));
      expect(superClean.label, equals('SUPER CLEAN'));

      // 2. Whole Food Fruit: 1 Banana (89 kcal, 1.1g protein, 23g carbs, 0.3g fat) -> LIGHT & CLEAN (NOT High Cal!)
      final banana = MealVerdict.evaluate(calories: 89, protein: 1.1, carbs: 23, fats: 0.3);
      expect(banana.tag, equals(MealVerdictTag.lightClean));
      expect(banana.label, equals('LIGHT & CLEAN'));

      // 3. Apple (52 kcal, 0.3g protein, 14g carbs, 0.2g fat) -> LIGHT & CLEAN
      final apple = MealVerdict.evaluate(calories: 52, protein: 0.3, carbs: 14, fats: 0.2);
      expect(apple.tag, equals(MealVerdictTag.lightClean));

      // 4. Balanced Home Meal: 3 Rotis & Urad Dal (485 kcal, 17g protein, 70g carbs, 15g fat) -> BALANCED
      final balancedMeal = MealVerdict.evaluate(calories: 485, protein: 17, carbs: 70, fats: 15);
      expect(balancedMeal.tag, equals(MealVerdictTag.balanced));
      expect(balancedMeal.label, equals('BALANCED'));

      // 5. High Calorie Junk / Overload: 700 kcal, 12g protein, 80g carbs, 35g fat -> HIGH CAL
      final highCal = MealVerdict.evaluate(calories: 700, protein: 12, carbs: 80, fats: 35);
      expect(highCal.tag, equals(MealVerdictTag.highCal));
      expect(highCal.label, equals('HIGH CAL'));

      // 6. Zero / Hydrating Drink: 0 kcal diet drink -> HYDRATING / LIGHT
      final dietDrink = MealVerdict.evaluate(calories: 0, protein: 0, carbs: 0, fats: 0);
      expect(dietDrink.tag, equals(MealVerdictTag.lightClean));
    });
  });
}
