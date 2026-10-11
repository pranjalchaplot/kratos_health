import 'daily_log.dart';
import 'user_goals.dart';
import '../services/calorie_calculator_service.dart';

enum MetricTrend { up, down, neutral }

/// Adapter class that bridges DailyLog to the Dashboard UI components
class DashboardData {
  final int streak;
  final int activeDayIndex;
  final int caloriesBurned; // Active calories
  final int bmrBurntSoFar;
  final int bmrDaily;
  final int totalCaloriesBurned;
  final int caloriesConsumed; // Meal intake
  final int caloriesGoal;
  final int protein;
  final int proteinGoal;
  final int carbs;
  final int carbsGoal;
  final int fats;
  final int fatsGoal;
  final int steps;
  final int stepsGoal;
  final double water;
  final double waterGoal;
  final double sleep;
  final double sleepGoal;
  final int digitalHours;
  final int digitalMinutes;
  final int digitalGoalHours;

  // Yesterday comparison metrics
  final bool hasYesterdayData;
  final int stepsDelta;
  final double waterDelta;
  final double sleepDelta;
  final int screenMinutesDelta;
  final int deficitDelta;
  final int burnDelta;
  final int intakeDelta;

  DashboardData({
    required this.streak,
    required this.activeDayIndex,
    required this.caloriesBurned,
    required this.bmrBurntSoFar,
    required this.bmrDaily,
    required this.totalCaloriesBurned,
    required this.caloriesConsumed,
    required this.caloriesGoal,
    required this.protein,
    required this.proteinGoal,
    required this.carbs,
    required this.carbsGoal,
    required this.fats,
    required this.fatsGoal,
    required this.steps,
    required this.stepsGoal,
    required this.water,
    required this.waterGoal,
    required this.sleep,
    required this.sleepGoal,
    required this.digitalHours,
    required this.digitalMinutes,
    required this.digitalGoalHours,
    this.hasYesterdayData = false,
    this.stepsDelta = 0,
    this.waterDelta = 0.0,
    this.sleepDelta = 0.0,
    this.screenMinutesDelta = 0,
    this.deficitDelta = 0,
    this.burnDelta = 0,
    this.intakeDelta = 0,
  });

  int get calorieDeficit => totalCaloriesBurned - caloriesConsumed;

  MetricTrend get stepsTrend =>
      stepsDelta > 0 ? MetricTrend.up : (stepsDelta < 0 ? MetricTrend.down : MetricTrend.neutral);
  MetricTrend get waterTrend =>
      waterDelta > 0.05 ? MetricTrend.up : (waterDelta < -0.05 ? MetricTrend.down : MetricTrend.neutral);
  MetricTrend get sleepTrend =>
      sleepDelta > 0.05 ? MetricTrend.up : (sleepDelta < -0.05 ? MetricTrend.down : MetricTrend.neutral);
  MetricTrend get screenTrend =>
      screenMinutesDelta > 0 ? MetricTrend.up : (screenMinutesDelta < 0 ? MetricTrend.down : MetricTrend.neutral);
  MetricTrend get deficitTrend =>
      deficitDelta > 0 ? MetricTrend.up : (deficitDelta < 0 ? MetricTrend.down : MetricTrend.neutral);

  factory DashboardData.fromDailyLog(
    DailyLog log,
    UserGoals goals,
    int streak,
    int activeDayIndex, {
    DailyLog? yesterdayLog,
  }) {
    final activeBurn = log.activeCaloriesBurned;
    final bmrSoFar = CalorieCalculatorService.calculateBmrBurntSoFar(goals, log.date);
    final bmrFull = CalorieCalculatorService.calculateBmr(goals);
    final totalBurn = activeBurn + bmrSoFar;
    final consumed = log.caloriesConsumed;

    final hasYesterday = yesterdayLog != null;
    int stepsDelta = 0;
    double waterDelta = 0.0;
    double sleepDelta = 0.0;
    int screenMinutesDelta = 0;
    int deficitDelta = 0;
    int burnDelta = 0;
    int intakeDelta = 0;

    if (yesterdayLog != null) {
      final yActive = yesterdayLog.activeCaloriesBurned;
      final yBmr = CalorieCalculatorService.calculateBmrBurntSoFar(goals, yesterdayLog.date);
      final yBurn = yActive + yBmr;
      final yConsumed = yesterdayLog.caloriesConsumed;
      final yDeficit = yBurn - yConsumed;

      stepsDelta = log.steps - yesterdayLog.steps;
      waterDelta = double.parse((log.water - yesterdayLog.water).toStringAsFixed(2));
      sleepDelta = double.parse((log.sleep - yesterdayLog.sleep).toStringAsFixed(1));
      screenMinutesDelta = ((log.digitalHours * 60) + log.digitalMinutes) -
          ((yesterdayLog.digitalHours * 60) + yesterdayLog.digitalMinutes);
      deficitDelta = (totalBurn - consumed) - yDeficit;
      burnDelta = totalBurn - yBurn;
      intakeDelta = consumed - yConsumed;
    }

    return DashboardData(
      streak: streak,
      activeDayIndex: activeDayIndex,
      caloriesBurned: activeBurn,
      bmrBurntSoFar: bmrSoFar,
      bmrDaily: bmrFull,
      totalCaloriesBurned: totalBurn,
      caloriesConsumed: consumed,
      caloriesGoal: log.caloriesGoal,
      protein: log.protein,
      proteinGoal: log.proteinGoal,
      carbs: log.carbs,
      carbsGoal: log.carbsGoal,
      fats: log.fats,
      fatsGoal: log.fatsGoal,
      steps: log.steps,
      stepsGoal: log.stepsGoal,
      water: log.water,
      waterGoal: log.waterGoal,
      sleep: log.sleep,
      sleepGoal: log.sleepGoal,
      digitalHours: log.digitalHours,
      digitalMinutes: log.digitalMinutes,
      digitalGoalHours: log.digitalGoalHours,
      hasYesterdayData: hasYesterday,
      stepsDelta: stepsDelta,
      waterDelta: waterDelta,
      sleepDelta: sleepDelta,
      screenMinutesDelta: screenMinutesDelta,
      deficitDelta: deficitDelta,
      burnDelta: burnDelta,
      intakeDelta: intakeDelta,
    );
  }

  // Initial zeroed data fallback
  factory DashboardData.empty() {
    return DashboardData(
      streak: 0,
      activeDayIndex: 0,
      caloriesBurned: 0,
      bmrBurntSoFar: 0,
      bmrDaily: 1800,
      totalCaloriesBurned: 0,
      caloriesConsumed: 0,
      caloriesGoal: 3200,
      protein: 0,
      proteinGoal: 180,
      carbs: 0,
      carbsGoal: 250,
      fats: 0,
      fatsGoal: 70,
      steps: 0,
      stepsGoal: 10000,
      water: 0.0,
      waterGoal: 3.5,
      sleep: 0.0,
      sleepGoal: 8.5,
      digitalHours: 0,
      digitalMinutes: 0,
      digitalGoalHours: 10,
    );
  }

  double get caloriesProgress => caloriesGoal > 0 ? (totalCaloriesBurned / caloriesGoal).clamp(0.0, 1.0) : 0.0;
  double get deficitProgress => caloriesGoal > 0 ? (calorieDeficit / caloriesGoal).clamp(0.0, 1.0) : 0.0;
  double get proteinProgress => proteinGoal > 0 ? (protein / proteinGoal).clamp(0.0, 1.0) : 0.0;
  double get carbsProgress => carbsGoal > 0 ? (carbs / carbsGoal).clamp(0.0, 1.0) : 0.0;
  double get fatsProgress => fatsGoal > 0 ? (fats / fatsGoal).clamp(0.0, 1.0) : 0.0;
  double get stepsProgress => stepsGoal > 0 ? (steps / stepsGoal).clamp(0.0, 1.0) : 0.0;
  double get waterProgress => waterGoal > 0 ? (water / waterGoal).clamp(0.0, 1.0) : 0.0;
  double get sleepProgress => sleepGoal > 0 ? (sleep / sleepGoal).clamp(0.0, 1.0) : 0.0;
  
  double get digitalProgress {
    final totalMinutes = (digitalHours * 60) + digitalMinutes;
    final goalMinutes = digitalGoalHours * 60;
    return goalMinutes > 0 ? (totalMinutes / goalMinutes).clamp(0.0, 1.0) : 0.0;
  }
}
