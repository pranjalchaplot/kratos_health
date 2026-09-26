import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/daily_log.dart';
import '../models/log_entry.dart';
import '../models/user_goals.dart';
import '../models/exercise_set.dart';
import '../services/screen_time_service.dart';
import '../services/step_tracker_service.dart';
import '../services/sleep_tracker_service.dart';

class SomaProvider extends ChangeNotifier {
  DateTime _selectedDate = DateTime.now();
  int _currentTabIndex = 0;
  UserGoals _userGoals = UserGoals();
  final Map<String, DailyLog> _logsMap = {};
  bool _isLoading = true;
  bool _isOnboardingCompleted = false;
  bool _isStepPermissionGranted = false;
  bool _isSleepTrackingActive = false;

  DateTime get selectedDate => _selectedDate;
  int get currentTabIndex => _currentTabIndex;
  UserGoals get userGoals => _userGoals;
  bool get isLoading => _isLoading;
  bool get isOnboardingCompleted => _isOnboardingCompleted;
  bool get isStepPermissionGranted => _isStepPermissionGranted;
  bool get isSleepTrackingActive => _isSleepTrackingActive;

  String _formatKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // Get active day log for the selected date
  DailyLog get currentLog {
    final key = _formatKey(_selectedDate);
    if (!_logsMap.containsKey(key)) {
      _logsMap[key] = DailyLog.empty(_selectedDate, _userGoals);
    }
    return _logsMap[key]!;
  }

  // Active day index in week (0 for Mon, 6 for Sun)
  int get activeDayIndex => (_selectedDate.weekday - 1) % 7;

  // Active streak calculation (consecutive days with actual recorded activity)
  int get streak {
    int count = 0;
    DateTime checkDate = DateTime.now();
    while (true) {
      final key = _formatKey(checkDate);
      final log = _logsMap[key];
      if (log != null && (log.entries.isNotEmpty || log.caloriesBurned > 0 || log.steps > 0 || log.water > 0 || log.sleep > 0)) {
        count++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return count;
  }

  SomaProvider() {
    init();
  }

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load Onboarding Status (fallback to kratos key for seamless migration)
      _isOnboardingCompleted = prefs.getBool('soma_onboarding_completed') ?? prefs.getBool('kratos_onboarding_completed') ?? false;

      // Load Goals
      final goalsStr = prefs.getString('soma_user_goals') ?? prefs.getString('kratos_user_goals');
      if (goalsStr != null) {
        _userGoals = UserGoals.decode(goalsStr);
      }

      // Load Daily Logs
      final logsJsonStr = prefs.getString('soma_daily_logs') ?? prefs.getString('kratos_daily_logs');
      if (logsJsonStr != null) {
        final Map<String, dynamic> decoded = jsonDecode(logsJsonStr);
        decoded.forEach((key, value) {
          _logsMap[key] = DailyLog.fromJson(Map<String, dynamic>.from(value));
        });
      }

      // Ensure today has a clean log
      final todayKey = _formatKey(DateTime.now());
      if (!_logsMap.containsKey(todayKey)) {
        _logsMap[todayKey] = DailyLog.empty(DateTime.now(), _userGoals);
        await saveToPrefs();
      }

      // Sync & start step tracker listening if permission already granted
      await syncStepTrackingFromDevice();

      // Sync & start sleep tracking from primary Android Sleep API
      await syncSleepTrackingFromDevice();
    } catch (e) {
      debugPrint('Error loading saved data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('soma_onboarding_completed', _isOnboardingCompleted);
      await prefs.setString('soma_user_goals', _userGoals.encode());

      final Map<String, dynamic> logsExport = {};
      _logsMap.forEach((key, log) {
        logsExport[key] = log.toJson();
      });
      await prefs.setString('soma_daily_logs', jsonEncode(logsExport));
    } catch (e) {
      debugPrint('Error saving data: $e');
    }
  }

  Future<void> completeOnboarding(UserGoals newGoals) async {
    _userGoals = newGoals;
    _isOnboardingCompleted = true;
    currentLog.applyGoals(newGoals);
    notifyListeners();
    await saveToPrefs();
    
    // Automatically fetch Digital Wellbeing, Steps & Sleep after onboarding
    await syncScreenTimeFromDevice();
    await syncStepTrackingFromDevice();
    await syncSleepTrackingFromDevice();
  }

  Future<void> resetOnboarding() async {
    _isOnboardingCompleted = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('soma_onboarding_completed', false);
    await prefs.setBool('kratos_onboarding_completed', false);
    notifyListeners();
  }

  Future<void> clearAllData() async {
    _logsMap.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('soma_daily_logs');
    await prefs.remove('kratos_daily_logs');
    final todayKey = _formatKey(DateTime.now());
    _logsMap[todayKey] = DailyLog.empty(DateTime.now(), _userGoals);
    notifyListeners();
    await saveToPrefs();
  }

  void setTab(int index) {
    _currentTabIndex = index;
    notifyListeners();
  }

  void selectDate(DateTime date) {
    _selectedDate = date;
    final key = _formatKey(date);
    if (!_logsMap.containsKey(key)) {
      _logsMap[key] = DailyLog(
        date: date,
        caloriesGoal: _userGoals.caloriesGoal,
        proteinGoal: _userGoals.proteinGoal,
        carbsGoal: _userGoals.carbsGoal,
        fatsGoal: _userGoals.fatsGoal,
        stepsGoal: _userGoals.stepsGoal,
        waterGoal: _userGoals.waterGoal,
        sleepGoal: _userGoals.sleepGoal,
        digitalGoalHours: _userGoals.digitalGoalHours,
      );
    }
    notifyListeners();
  }

  void selectDayByIndex(int dayIndex) {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final targetDate = monday.add(Duration(days: dayIndex));
    selectDate(targetDate);
  }

  // --- Logging actions ---

  Future<void> logWater(double amountLiters, {String title = 'Water Intake', String? customSubtitle}) async {
    final ml = (amountLiters * 1000).round();
    final glasses = amountLiters / 0.25;
    final glassesStr = glasses % 1 == 0 ? glasses.toInt().toString() : glasses.toStringAsFixed(1);
    final defaultSubtitle = '$ml ml ($glassesStr ${glassesStr == '1' ? 'glass' : 'glasses'})';

    final entry = LogEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      type: LogType.water,
      title: title,
      subtitle: customSubtitle ?? defaultSubtitle,
      amount: amountLiters,
    );
    currentLog.entries.insert(0, entry);
    notifyListeners();
    await saveToPrefs();
  }

  Future<void> logMeal({
    required String name,
    required String mealType,
    required int calories,
    required int protein,
    required int carbs,
    required int fats,
  }) async {
    final entry = LogEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      type: LogType.meal,
      title: name,
      subtitle: mealType,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fats: fats,
    );
    currentLog.entries.insert(0, entry);
    notifyListeners();
    await saveToPrefs();
  }

  Future<void> logSteps({
    required int steps,
    required int calories,
  }) async {
    final entry = LogEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      type: LogType.activity,
      title: 'Daily Steps',
      subtitle: '$steps steps',
      calories: calories,
      count: steps,
      activityCategory: 'steps',
    );
    currentLog.entries.insert(0, entry);
    notifyListeners();
    await saveToPrefs();
  }

  Future<void> logActivity({
    required String title,
    required int steps,
    required int calories,
  }) async {
    final entry = LogEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      type: LogType.activity,
      title: title,
      subtitle: '$steps steps',
      calories: calories,
      count: steps,
      activityCategory: 'steps',
    );
    currentLog.entries.insert(0, entry);
    notifyListeners();
    await saveToPrefs();
  }

  Future<void> logCardio({
    required String cardioType,
    required String intensity,
    required int durationMinutes,
    double? distanceKm,
    required int calories,
  }) async {
    final distStr = distanceKm != null && distanceKm > 0 ? ' • ${distanceKm.toStringAsFixed(1)} km' : '';
    final entry = LogEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      type: LogType.activity,
      title: '$cardioType Cardio',
      subtitle: '$durationMinutes mins ($intensity)$distStr',
      calories: calories,
      activityCategory: 'cardio',
      cardioType: cardioType,
      intensity: intensity,
      durationMinutes: durationMinutes,
      distanceKm: distanceKm,
    );
    currentLog.entries.insert(0, entry);
    notifyListeners();
    await saveToPrefs();
  }

  Future<void> logExercise({
    required String exerciseName,
    required List<ExerciseSet> sets,
    required int durationMinutes,
    required int calories,
  }) async {
    final totalReps = sets.fold(0, (sum, s) => sum + s.reps);
    final maxWeight = sets.fold(0.0, (max, s) => s.weightKg > max ? s.weightKg : max);
    final maxWeightStr = maxWeight % 1 == 0 ? maxWeight.toInt().toString() : maxWeight.toStringAsFixed(1);
    
    final entry = LogEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      type: LogType.activity,
      title: exerciseName,
      subtitle: '${sets.length} sets • $totalReps total reps (Max: ${maxWeightStr}kg)',
      calories: calories,
      activityCategory: 'exercise',
      exerciseName: exerciseName,
      sets: sets,
      durationMinutes: durationMinutes,
    );
    currentLog.entries.insert(0, entry);
    notifyListeners();
    await saveToPrefs();
  }

  Future<void> logSleep(double hours) async {
    final entry = LogEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      type: LogType.sleep,
      title: 'Sleep Record',
      subtitle: '${hours.toStringAsFixed(1)} hours',
      amount: hours,
    );
    currentLog.entries.insert(0, entry);
    notifyListeners();
    await saveToPrefs();
  }

  Future<void> logDigital(int hours, int minutes) async {
    currentLog.digitalHours = hours;
    currentLog.digitalMinutes = minutes;
    notifyListeners();
    await saveToPrefs();
  }

  Future<bool> syncScreenTimeFromDevice() async {
    try {
      final total = await ScreenTimeService.getTodayTotalScreenTime();
      if (total > Duration.zero) {
        final hours = total.inHours;
        final minutes = total.inMinutes.remainder(60);
        await logDigital(hours, minutes);
        return true;
      }
    } catch (e) {
      debugPrint('Screen time sync failed: $e');
    }
    return false;
  }

  Future<bool> syncStepTrackingFromDevice() async {
    try {
      final granted = await StepTrackerService.isPermissionGranted();
      _isStepPermissionGranted = granted;
      if (granted) {
        await StepTrackerService.startListening(
          onStepsUpdated: (todaySteps) {
            final todayKey = _formatKey(DateTime.now());
            if (_logsMap.containsKey(todayKey)) {
              _logsMap[todayKey]!.additionalSteps = todaySteps;
              notifyListeners();
            }
          },
        );
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Step tracking sync failed: $e');
    }
    return false;
  }

  Future<bool> requestStepPermission() async {
    try {
      final granted = await StepTrackerService.requestPermission();
      _isStepPermissionGranted = granted;
      if (granted) {
        await syncStepTrackingFromDevice();
      }
      notifyListeners();
      return granted;
    } catch (e) {
      debugPrint('Step permission request error: $e');
      return false;
    }
  }

  Future<bool> syncSleepTrackingFromDevice() async {
    try {
      final granted = await SleepTrackerService.isPermissionGranted();
      if (granted) {
        _isSleepTrackingActive = await SleepTrackerService.startTracking();
        final sleepRecord = await SleepTrackerService.getTodaySleep();
        if (sleepRecord != null && sleepRecord.durationHours > 0) {
          final todayKey = _formatKey(DateTime.now());
          if (_logsMap.containsKey(todayKey)) {
            final todayLog = _logsMap[todayKey]!;
            if (todayLog.sleep == 0 || todayLog.additionalSleep == 0) {
              todayLog.additionalSleep = sleepRecord.durationHours;
              await saveToPrefs();
              notifyListeners();
            }
          }
          return true;
        }
      }
    } catch (e) {
      debugPrint('Sleep tracking sync failed: $e');
    }
    return false;
  }

  Future<bool> requestSleepPermission() async {
    try {
      final granted = await SleepTrackerService.requestPermission();
      if (granted) {
        await syncSleepTrackingFromDevice();
      }
      notifyListeners();
      return granted;
    } catch (e) {
      debugPrint('Sleep permission request error: $e');
      return false;
    }
  }

  Future<void> simulateSleepForTesting([double hours = 7.5]) async {
    final record = await SleepTrackerService.simulateSleep(hours: hours);
    if (record != null) {
      final todayKey = _formatKey(DateTime.now());
      if (_logsMap.containsKey(todayKey)) {
        _logsMap[todayKey]!.additionalSleep = record.durationHours;
        await saveToPrefs();
        notifyListeners();
      }
    }
  }

  Future<void> deleteLogEntry(String id) async {
    currentLog.entries.removeWhere((e) => e.id == id);
    notifyListeners();
    await saveToPrefs();
  }

  Future<void> updateGoals(UserGoals newGoals) async {
    _userGoals = newGoals;
    currentLog.applyGoals(newGoals);
    notifyListeners();
    await saveToPrefs();
  }
}

/// Typedef for backwards compatibility
typedef KratosProvider = SomaProvider;
