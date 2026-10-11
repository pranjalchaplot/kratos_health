import 'dart:async';
import '../models/daily_log.dart';
import '../models/reminder_settings.dart';
import '../models/user_goals.dart';
import 'notification_service.dart';

/// Master background and lifecycle-aware reminder scheduler for SOMA.
/// Evaluates hydration intervals, continuous screen sessions, meal nudges,
/// sleep preparation, and streak protection with adaptive throttling.
class ReminderSchedulerService {
  static final ReminderSchedulerService _instance = ReminderSchedulerService._internal();
  factory ReminderSchedulerService() => _instance;
  ReminderSchedulerService._internal();

  Timer? _schedulerTimer;
  DateTime _lastHydrationReminder = DateTime.now();
  DateTime _continuousSessionStart = DateTime.now();

  // Flags to prevent multiple triggers in same calendar day window
  String? _lastLunchAlertDate;
  String? _lastDinnerAlertDate;
  String? _lastBedtimeAlertDate;
  String? _lastStreakAlertDate;
  String? _lastStepProgressDate;

  // External references
  ReminderSettings? _settings;
  DailyLog Function()? _getCurrentLog;
  UserGoals Function()? _getUserGoals;
  int Function()? _getCurrentStreak;
  Function(String category)? _onAlertSent;

  DateTime get continuousSessionStart => _continuousSessionStart;
  int get continuousSessionMinutes => DateTime.now().difference(_continuousSessionStart).inMinutes;

  /// Start periodic scheduler
  void start({
    required ReminderSettings settings,
    required DailyLog Function() getCurrentLog,
    required UserGoals Function() getUserGoals,
    required int Function() getCurrentStreak,
    required Function(String category) onAlertSent,
  }) {
    _settings = settings;
    _getCurrentLog = getCurrentLog;
    _getUserGoals = getUserGoals;
    _getCurrentStreak = getCurrentStreak;
    _onAlertSent = onAlertSent;

    _continuousSessionStart = DateTime.now();
    _schedulerTimer?.cancel();
    _schedulerTimer = Timer.periodic(const Duration(seconds: 45), (_) => _evaluateReminders());
  }

  void updateSettings(ReminderSettings settings) {
    _settings = settings;
  }

  /// Reset continuous screen time session (e.g. app reopened after backgrounding)
  void resetContinuousSession() {
    _continuousSessionStart = DateTime.now();
  }

  /// Mark water as logged (resets hydration interval)
  void notifyWaterLogged() {
    _lastHydrationReminder = DateTime.now();
  }

  void _evaluateReminders() {
    if (_settings == null || _getCurrentLog == null || _getUserGoals == null) return;

    final now = DateTime.now();
    final todayKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final currentLog = _getCurrentLog!();
    final goals = _getUserGoals!();

    // ----------------------------------------------------
    // 1. Smart Hydration Reminder
    // ----------------------------------------------------
    if (_settings!.hydrationEnabled) {
      final currentWater = currentLog.water;
      final targetWater = goals.waterGoal;

      // Auto-mute if water goal already achieved today
      if (currentWater < targetWater) {
        final elapsedMinutes = now.difference(_lastHydrationReminder).inMinutes;
        final intervalMinutes = _settings!.hydrationIntervalMinutes;

        // Active between 08:00 and 22:00
        if (now.hour >= 8 && now.hour <= 22 && elapsedMinutes >= intervalMinutes) {
          if (_settings!.canSendReminder('hydration')) {
            NotificationService().showHydrationReminder(
              currentLiters: currentWater,
              goalLiters: targetWater,
            );
            _lastHydrationReminder = now;
            _onAlertSent?.call('hydration');
          }
        }
      }
    }

    // ----------------------------------------------------
    // 2. Continuous Screen Time Alert
    // ----------------------------------------------------
    if (_settings!.continuousScreenTimeEnabled) {
      final sessionMins = now.difference(_continuousSessionStart).inMinutes;
      final limitMins = _settings!.continuousScreenTimeLimitMinutes;

      if (sessionMins >= limitMins) {
        if (_settings!.canSendReminder('continuous_screen')) {
          NotificationService().showContinuousScreenAlert(sessionMinutes: sessionMins);
          _onAlertSent?.call('continuous_screen');
        }
      }
    }

    // ----------------------------------------------------
    // 3. Daily Digital Budget Alert
    // ----------------------------------------------------
    if (_settings!.digitalBudgetEnabled) {
      final screenHours = currentLog.digitalHours;
      final budgetHours = goals.digitalGoalHours;

      if (screenHours >= budgetHours && budgetHours > 0) {
        if (_settings!.canSendReminder('digital_budget')) {
          NotificationService().showDigitalBudgetAlert(
            currentHours: screenHours,
            budgetHours: budgetHours,
          );
          _onAlertSent?.call('digital_budget');
        }
      }
    }

    // ----------------------------------------------------
    // 4. Meal & Protein Logging Nudges (Lunch & Dinner)
    // ----------------------------------------------------
    if (_settings!.mealLoggingEnabled) {
      // Lunch check (13:00 - 14:00)
      if (now.hour == 13 && _lastLunchAlertDate != todayKey) {
        final hasEntries = currentLog.entries.isNotEmpty;
        if (!hasEntries && _settings!.canSendReminder('lunch_nudge')) {
          NotificationService().showMealLoggingNudge(mealName: 'Lunch');
          _lastLunchAlertDate = todayKey;
          _onAlertSent?.call('lunch_nudge');
        }
      }

      // Dinner check (20:00 - 21:00)
      if (now.hour == 20 && _lastDinnerAlertDate != todayKey) {
        final calories = currentLog.caloriesConsumed;
        if (calories < (goals.caloriesGoal * 0.7) && _settings!.canSendReminder('dinner_nudge')) {
          NotificationService().showMealLoggingNudge(mealName: 'Dinner');
          _lastDinnerAlertDate = todayKey;
          _onAlertSent?.call('dinner_nudge');
        }
      }
    }

    // ----------------------------------------------------
    // 5. Afternoon Step Pace Check (17:00)
    // ----------------------------------------------------
    if (_settings!.stepProgressEnabled) {
      if (now.hour == 17 && _lastStepProgressDate != todayKey) {
        final steps = currentLog.steps;
        final target = goals.stepsGoal;
        if (steps < (target * 0.5) && _settings!.canSendReminder('step_progress')) {
          NotificationService().showStepProgressAlert(
            currentSteps: steps,
            goalSteps: target,
          );
          _lastStepProgressDate = todayKey;
          _onAlertSent?.call('step_progress');
        }
      }
    }

    // ----------------------------------------------------
    // 6. Streak Saver & Daily Reflection (21:30)
    // ----------------------------------------------------
    if (_settings!.streakSaverEnabled) {
      if (now.hour == 21 && now.minute >= 30 && _lastStreakAlertDate != todayKey) {
        final hasActivity = currentLog.entries.isNotEmpty ||
            currentLog.caloriesBurned > 0 ||
            currentLog.water > 0;
        if (!hasActivity && _settings!.canSendReminder('streak_saver')) {
          final streak = _getCurrentStreak?.call() ?? 0;
          NotificationService().showStreakSaverAlert(currentStreak: streak);
          _lastStreakAlertDate = todayKey;
          _onAlertSent?.call('streak_saver');
        }
      }
    }

    // ----------------------------------------------------
    // 7. Bedtime Wind-Down Alert
    // ----------------------------------------------------
    if (_settings!.bedtimeReminderEnabled) {
      // Typically 22:30 or 45 mins before calculated bedtime
      if (now.hour == 22 && now.minute >= 15 && _lastBedtimeAlertDate != todayKey) {
        if (_settings!.canSendReminder('bedtime')) {
          NotificationService().showBedtimeAlert(targetTime: '23:00');
          _lastBedtimeAlertDate = todayKey;
          _onAlertSent?.call('bedtime');
        }
      }
    }
  }

  void stop() {
    _schedulerTimer?.cancel();
    _schedulerTimer = null;
  }
}
