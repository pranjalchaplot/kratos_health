import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/daily_log.dart';
import '../models/log_entry.dart';
import '../models/user_goals.dart';

class KratosProvider extends ChangeNotifier {
  DateTime _selectedDate = DateTime.now();
  int _currentTabIndex = 0;
  UserGoals _userGoals = UserGoals();
  final Map<String, DailyLog> _logsMap = {};
  bool _isLoading = true;

  DateTime get selectedDate => _selectedDate;
  int get currentTabIndex => _currentTabIndex;
  UserGoals get userGoals => _userGoals;
  bool get isLoading => _isLoading;

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

  KratosProvider() {
    init();
  }

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load Goals
      final goalsStr = prefs.getString('kratos_user_goals');
      if (goalsStr != null) {
        _userGoals = UserGoals.decode(goalsStr);
      }

      // Load Daily Logs
      final logsJsonStr = prefs.getString('kratos_daily_logs');
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
      await prefs.setString('kratos_user_goals', _userGoals.encode());

      final Map<String, dynamic> logsExport = {};
      _logsMap.forEach((key, log) {
        logsExport[key] = log.toJson();
      });
      await prefs.setString('kratos_daily_logs', jsonEncode(logsExport));
    } catch (e) {
      debugPrint('Error saving data: $e');
    }
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

  Future<void> clearAllData() async {
    _logsMap.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('kratos_daily_logs');
    final todayKey = _formatKey(DateTime.now());
    _logsMap[todayKey] = DailyLog.empty(DateTime.now(), _userGoals);
    notifyListeners();
    await saveToPrefs();
  }
}
