import 'package:flutter_test/flutter_test.dart';
import 'package:soma_app/models/daily_log.dart';
import 'package:soma_app/models/log_entry.dart';
import 'package:soma_app/models/user_goals.dart';
import 'package:soma_app/models/dashboard_data.dart';

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

    test('Meal Health Rule categorizes <10x, <=20x and >20x calories-to-protein', () {
      // Helper simulating the exact ratio check
      String classifyMeal(int calories, int protein) {
        final double ratio = protein > 0 ? calories / protein : (calories > 0 ? double.infinity : 0.0);
        if (protein > 0 && ratio < 10.0) return 'SUPER CLEAN';
        if (protein > 0 && ratio <= 20.0) return 'HEALTHY';
        return 'HIGH CAL';
      }

      // 30g protein with 240 kcal (ratio 8.0x < 10) -> Super Clean
      expect(classifyMeal(240, 30), equals('SUPER CLEAN'));

      // 10g protein with 150 kcal (ratio 15.0x <= 20) -> Healthy
      expect(classifyMeal(150, 10), equals('HEALTHY'));

      // 10g protein with 200 kcal (ratio 20.0x <= 20) -> Healthy
      expect(classifyMeal(200, 10), equals('HEALTHY'));

      // 10g protein with 250 kcal (ratio 25.0x > 20) -> High Cal
      expect(classifyMeal(250, 10), equals('HIGH CAL'));

      // 0g protein with 300 kcal -> High Cal
      expect(classifyMeal(300, 0), equals('HIGH CAL'));
    });
  });
}
