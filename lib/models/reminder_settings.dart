import 'dart:convert';

/// Represents user notification preferences and adaptive throttling state.
class ReminderSettings {
  // Sedentary (Sensor-driven)
  bool sedentaryEnabled;
  int sedentaryIntervalMinutes;
  int sedentaryStepThreshold;
  int sedentaryStartHour;
  int sedentaryEndHour;

  // Hydration
  bool hydrationEnabled;
  int hydrationIntervalMinutes;

  // Screen Time & Digital Wellness
  bool continuousScreenTimeEnabled;
  int continuousScreenTimeLimitMinutes;
  bool digitalBudgetEnabled;

  // Nutrition, Recovery & Streaks
  bool mealLoggingEnabled;
  bool bedtimeReminderEnabled;
  bool streakSaverEnabled;
  bool stepProgressEnabled;

  // Adaptive Throttling & Circuit Breaker State
  int totalUnattendedCount;
  Map<String, bool> categoryPending;

  ReminderSettings({
    this.sedentaryEnabled = true,
    this.sedentaryIntervalMinutes = 60,
    this.sedentaryStepThreshold = 20,
    this.sedentaryStartHour = 9,
    this.sedentaryEndHour = 21,
    this.hydrationEnabled = true,
    this.hydrationIntervalMinutes = 90,
    this.continuousScreenTimeEnabled = true,
    this.continuousScreenTimeLimitMinutes = 45,
    this.digitalBudgetEnabled = true,
    this.mealLoggingEnabled = true,
    this.bedtimeReminderEnabled = true,
    this.streakSaverEnabled = true,
    this.stepProgressEnabled = true,
    this.totalUnattendedCount = 0,
    Map<String, bool>? categoryPending,
  }) : categoryPending = categoryPending ?? {};

  /// Check if notification system is currently in circuit breaker quiet mode
  bool get isCircuitBreakerActive => totalUnattendedCount >= 2;

  /// Check if a specific category can send an alert
  bool canSendReminder(String category) {
    if (isCircuitBreakerActive) return false;
    if (categoryPending[category] == true) return false;
    return true;
  }

  /// Mark a notification of [category] as sent and increment unattended count
  void recordSent(String category) {
    categoryPending[category] = true;
    totalUnattendedCount++;
  }

  /// Reset all unattended counters when user acknowledges any alert or interacts
  void acknowledgeAll() {
    totalUnattendedCount = 0;
    categoryPending.clear();
  }

  /// Acknowledge specific category
  void acknowledgeCategory(String category) {
    if (categoryPending[category] == true) {
      categoryPending[category] = false;
      if (totalUnattendedCount > 0) totalUnattendedCount--;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'sedentaryEnabled': sedentaryEnabled,
      'sedentaryIntervalMinutes': sedentaryIntervalMinutes,
      'sedentaryStepThreshold': sedentaryStepThreshold,
      'sedentaryStartHour': sedentaryStartHour,
      'sedentaryEndHour': sedentaryEndHour,
      'hydrationEnabled': hydrationEnabled,
      'hydrationIntervalMinutes': hydrationIntervalMinutes,
      'continuousScreenTimeEnabled': continuousScreenTimeEnabled,
      'continuousScreenTimeLimitMinutes': continuousScreenTimeLimitMinutes,
      'digitalBudgetEnabled': digitalBudgetEnabled,
      'mealLoggingEnabled': mealLoggingEnabled,
      'bedtimeReminderEnabled': bedtimeReminderEnabled,
      'streakSaverEnabled': streakSaverEnabled,
      'stepProgressEnabled': stepProgressEnabled,
      'totalUnattendedCount': totalUnattendedCount,
      'categoryPending': categoryPending,
    };
  }

  factory ReminderSettings.fromJson(Map<String, dynamic> json) {
    Map<String, bool> parsedCategoryPending = {};
    if (json['categoryPending'] is Map) {
      (json['categoryPending'] as Map).forEach((k, v) {
        parsedCategoryPending[k.toString()] = v == true;
      });
    }

    return ReminderSettings(
      sedentaryEnabled: json['sedentaryEnabled'] as bool? ?? true,
      sedentaryIntervalMinutes: (json['sedentaryIntervalMinutes'] as num?)?.toInt() ?? 60,
      sedentaryStepThreshold: (json['sedentaryStepThreshold'] as num?)?.toInt() ?? 20,
      sedentaryStartHour: (json['sedentaryStartHour'] as num?)?.toInt() ?? 9,
      sedentaryEndHour: (json['sedentaryEndHour'] as num?)?.toInt() ?? 21,
      hydrationEnabled: json['hydrationEnabled'] as bool? ?? true,
      hydrationIntervalMinutes: (json['hydrationIntervalMinutes'] as num?)?.toInt() ?? 90,
      continuousScreenTimeEnabled: json['continuousScreenTimeEnabled'] as bool? ?? true,
      continuousScreenTimeLimitMinutes: (json['continuousScreenTimeLimitMinutes'] as num?)?.toInt() ?? 45,
      digitalBudgetEnabled: json['digitalBudgetEnabled'] as bool? ?? true,
      mealLoggingEnabled: json['mealLoggingEnabled'] as bool? ?? true,
      bedtimeReminderEnabled: json['bedtimeReminderEnabled'] as bool? ?? true,
      streakSaverEnabled: json['streakSaverEnabled'] as bool? ?? true,
      stepProgressEnabled: json['stepProgressEnabled'] as bool? ?? true,
      totalUnattendedCount: (json['totalUnattendedCount'] as num?)?.toInt() ?? 0,
      categoryPending: parsedCategoryPending,
    );
  }

  String encode() => jsonEncode(toJson());

  factory ReminderSettings.decode(String str) {
    try {
      return ReminderSettings.fromJson(jsonDecode(str));
    } catch (_) {
      return ReminderSettings();
    }
  }

  ReminderSettings copyWith({
    bool? sedentaryEnabled,
    int? sedentaryIntervalMinutes,
    int? sedentaryStepThreshold,
    int? sedentaryStartHour,
    int? sedentaryEndHour,
    bool? hydrationEnabled,
    int? hydrationIntervalMinutes,
    bool? continuousScreenTimeEnabled,
    int? continuousScreenTimeLimitMinutes,
    bool? digitalBudgetEnabled,
    bool? mealLoggingEnabled,
    bool? bedtimeReminderEnabled,
    bool? streakSaverEnabled,
    bool? stepProgressEnabled,
    int? totalUnattendedCount,
    Map<String, bool>? categoryPending,
  }) {
    return ReminderSettings(
      sedentaryEnabled: sedentaryEnabled ?? this.sedentaryEnabled,
      sedentaryIntervalMinutes: sedentaryIntervalMinutes ?? this.sedentaryIntervalMinutes,
      sedentaryStepThreshold: sedentaryStepThreshold ?? this.sedentaryStepThreshold,
      sedentaryStartHour: sedentaryStartHour ?? this.sedentaryStartHour,
      sedentaryEndHour: sedentaryEndHour ?? this.sedentaryEndHour,
      hydrationEnabled: hydrationEnabled ?? this.hydrationEnabled,
      hydrationIntervalMinutes: hydrationIntervalMinutes ?? this.hydrationIntervalMinutes,
      continuousScreenTimeEnabled: continuousScreenTimeEnabled ?? this.continuousScreenTimeEnabled,
      continuousScreenTimeLimitMinutes: continuousScreenTimeLimitMinutes ?? this.continuousScreenTimeLimitMinutes,
      digitalBudgetEnabled: digitalBudgetEnabled ?? this.digitalBudgetEnabled,
      mealLoggingEnabled: mealLoggingEnabled ?? this.mealLoggingEnabled,
      bedtimeReminderEnabled: bedtimeReminderEnabled ?? this.bedtimeReminderEnabled,
      streakSaverEnabled: streakSaverEnabled ?? this.streakSaverEnabled,
      stepProgressEnabled: stepProgressEnabled ?? this.stepProgressEnabled,
      totalUnattendedCount: totalUnattendedCount ?? this.totalUnattendedCount,
      categoryPending: categoryPending ?? Map.from(this.categoryPending),
    );
  }
}
