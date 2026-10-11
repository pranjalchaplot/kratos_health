import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

/// Central Notification Service managing Android notification channels,
/// high-importance banners, quick action buttons, custom user alert sound,
/// and respective vector icons for each notification category.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  // Custom audio alert sound (android/app/src/main/res/raw/notification_alert_sound.mp3)
  static const RawResourceAndroidNotificationSound _somaSound =
      RawResourceAndroidNotificationSound('notification_alert_sound');

  // Callback registered by SomaProvider when notification action is tapped
  Function(String actionId, String? payload)? onActionReceived;

  // Channel IDs
  static const String channelSedentaryId = 'soma_sedentary_channel';
  static const String channelHydrationId = 'soma_hydration_channel';
  static const String channelWellbeingId = 'soma_wellbeing_channel';

  // Notification IDs
  static const int idSedentary = 1001;
  static const int idHydration = 1002;
  static const int idContinuousScreen = 1003;
  static const int idDigitalBudget = 1004;
  static const int idMealNudge = 1005;
  static const int idBedtime = 1006;
  static const int idStreakSaver = 1007;
  static const int idStepProgress = 1008;

  // Action IDs
  static const String actionAdd250ml = 'action_add_250ml';
  static const String actionAdd500ml = 'action_add_500ml';
  static const String actionAcknowledge = 'action_acknowledge';

  /// Initialize local notification plugin and channels
  Future<void> init({Function(String actionId, String? payload)? onAction}) async {
    if (_isInitialized) return;
    onActionReceived = onAction;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );

    await _createNotificationChannels();
    _isInitialized = true;
  }

  /// Create dedicated Android notification channels with custom sound
  Future<void> _createNotificationChannels() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return;

    // 1. Sedentary Channel
    const sedentaryChannel = AndroidNotificationChannel(
      channelSedentaryId,
      'Movement & Inactivity Alerts',
      description: 'Sensor-driven reminders when sitting for extended periods',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
      sound: _somaSound,
    );

    // 2. Hydration Channel
    const hydrationChannel = AndroidNotificationChannel(
      channelHydrationId,
      'Hydration Reminders',
      description: 'Water intake nudges with quick-log action buttons',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
      sound: _somaSound,
    );

    // 3. Wellbeing Channel
    const wellbeingChannel = AndroidNotificationChannel(
      channelWellbeingId,
      'Performance & Wellbeing',
      description: 'Sleep wind-down, screen time, meal logs, and streak protection',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
      sound: _somaSound,
    );

    await androidPlugin.createNotificationChannel(sedentaryChannel);
    await androidPlugin.createNotificationChannel(hydrationChannel);
    await androidPlugin.createNotificationChannel(wellbeingChannel);
  }

  /// Check if notification permissions are granted
  Future<bool> isPermissionGranted() async {
    final status = await Permission.notification.status;
    return status.isGranted;
  }

  /// Request runtime notification permission (Android 13+)
  Future<bool> requestPermissions() async {
    final status = await Permission.notification.request();
    if (status.isPermanentlyDenied) {
      await openAppSettings();
    }
    return status.isGranted;
  }

  void _handleNotificationResponse(NotificationResponse response) {
    final actionId = response.actionId;
    final payload = response.payload;
    if (kDebugMode) {
      print('NotificationResponse received: actionId=$actionId, payload=$payload');
    }
    if (actionId != null && onActionReceived != null) {
      onActionReceived!(actionId, payload);
    } else if (onActionReceived != null) {
      onActionReceived!(actionAcknowledge, payload);
    }
  }

  /// Show Sedentary Alert with ic_notif_walk icon
  Future<void> showSedentaryAlert({required int inactiveMinutes}) async {
    const androidDetails = AndroidNotificationDetails(
      channelSedentaryId,
      'Movement & Inactivity Alerts',
      channelDescription: 'Sensor-driven reminders when sitting for extended periods',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_notif_walk',
      largeIcon: DrawableResourceAndroidBitmap('ic_notif_walk'),
      color: Color(0xFFEF4444),
      category: AndroidNotificationCategory.reminder,
      playSound: true,
      sound: _somaSound,
    );

    await _plugin.show(
      id: idSedentary,
      title: 'Break the Stagnation ⚡',
      body: '$inactiveMinutes mins of physical inactivity. Re-engage your kinetic chain — take 20 brisk steps to reset.',
      notificationDetails: const NotificationDetails(android: androidDetails),
      payload: 'sedentary',
    );
  }

  /// Show Hydration Reminder with ic_notif_water icon and interactive buttons
  Future<void> showHydrationReminder({
    required double currentLiters,
    required double goalLiters,
  }) async {
    final remaining = (goalLiters - currentLiters).clamp(0.0, goalLiters);
    final androidDetails = AndroidNotificationDetails(
      channelHydrationId,
      'Hydration Reminders',
      channelDescription: 'Water intake nudges with quick-log action buttons',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_notif_water',
      largeIcon: const DrawableResourceAndroidBitmap('ic_notif_water'),
      color: const Color(0xFF38BDF8),
      category: AndroidNotificationCategory.reminder,
      playSound: true,
      sound: _somaSound,
      actions: const [
        AndroidNotificationAction(
          actionAdd250ml,
          '+250 ml',
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          actionAdd500ml,
          '+500 ml',
          showsUserInterface: true,
        ),
      ],
    );

    await _plugin.show(
      id: idHydration,
      title: 'Fuel Your Output 💧',
      body: 'Hydration status: ${currentLiters.toStringAsFixed(1)}L / ${goalLiters.toStringAsFixed(1)}L banked today (${remaining.toStringAsFixed(1)}L remaining). Fuel up to sustain peak output.',
      notificationDetails: NotificationDetails(android: androidDetails),
      payload: 'hydration',
    );
  }

  /// Show Continuous Screen Time Alert with ic_notif_screen icon
  Future<void> showContinuousScreenAlert({required int sessionMinutes}) async {
    const androidDetails = AndroidNotificationDetails(
      channelWellbeingId,
      'Performance & Wellbeing',
      channelDescription: 'Continuous Screen Time Alert',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_notif_screen',
      largeIcon: DrawableResourceAndroidBitmap('ic_notif_screen'),
      color: Color(0xFFF59E0B),
      category: AndroidNotificationCategory.reminder,
      playSound: true,
      sound: _somaSound,
    );

    await _plugin.show(
      id: idContinuousScreen,
      title: 'Cognitive Reset 👁️',
      body: 'Continuous focus block: $sessionMinutes mins. Shift your focal depth — look at the horizon for 20s to ease neural fatigue.',
      notificationDetails: const NotificationDetails(android: androidDetails),
      payload: 'continuous_screen',
    );
  }

  /// Show Daily Screen Time Budget Alert with ic_notif_screen icon
  Future<void> showDigitalBudgetAlert({
    required int currentHours,
    required int budgetHours,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      channelWellbeingId,
      'Performance & Wellbeing',
      channelDescription: 'Daily Digital Wellbeing Alert',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_notif_screen',
      largeIcon: DrawableResourceAndroidBitmap('ic_notif_screen'),
      color: Color(0xFFF97316),
      category: AndroidNotificationCategory.reminder,
      playSound: true,
      sound: _somaSound,
    );

    await _plugin.show(
      id: idDigitalBudget,
      title: 'Digital Budget Capped 📱',
      body: 'Daily screen time reached ${currentHours}h (Target: ${budgetHours}h). Disconnect to prioritize physical rest and recovery.',
      notificationDetails: const NotificationDetails(android: androidDetails),
      payload: 'digital_budget',
    );
  }

  /// Show Meal & Protein Logging Nudge with ic_notif_meal icon
  Future<void> showMealLoggingNudge({required String mealName}) async {
    const androidDetails = AndroidNotificationDetails(
      channelWellbeingId,
      'Performance & Wellbeing',
      channelDescription: 'Meal Logging Reminders',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_notif_meal',
      largeIcon: DrawableResourceAndroidBitmap('ic_notif_meal'),
      color: Color(0xFF10B981),
      category: AndroidNotificationCategory.reminder,
      playSound: true,
      sound: _somaSound,
    );

    await _plugin.show(
      id: idMealNudge,
      title: 'Refuel Your Engine 🥗',
      body: 'Lock in your $mealName macros. High performance is built in the kitchen — hit your daily protein mark.',
      notificationDetails: const NotificationDetails(android: androidDetails),
      payload: 'meal_nudge',
    );
  }

  /// Show Bedtime Wind-Down Alert with ic_notif_bed icon
  Future<void> showBedtimeAlert({required String targetTime}) async {
    const androidDetails = AndroidNotificationDetails(
      channelWellbeingId,
      'Performance & Wellbeing',
      channelDescription: 'Sleep Preparation Alert',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_notif_bed',
      largeIcon: DrawableResourceAndroidBitmap('ic_notif_bed'),
      color: Color(0xFF818CF8),
      category: AndroidNotificationCategory.reminder,
      playSound: true,
      sound: _somaSound,
    );

    await _plugin.show(
      id: idBedtime,
      title: 'Recovery Protocol Initiated 🌙',
      body: 'Target sleep at $targetTime. Dim ambient lighting, drop cortisol, and prime your central nervous system for recovery.',
      notificationDetails: const NotificationDetails(android: androidDetails),
      payload: 'bedtime',
    );
  }

  /// Show Streak Saver Alert with ic_notif_flame icon
  Future<void> showStreakSaverAlert({required int currentStreak}) async {
    const androidDetails = AndroidNotificationDetails(
      channelWellbeingId,
      'Performance & Wellbeing',
      channelDescription: 'Daily Streak Protection Alert',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_notif_flame',
      largeIcon: DrawableResourceAndroidBitmap('ic_notif_flame'),
      color: Color(0xFFEC4899),
      category: AndroidNotificationCategory.reminder,
      playSound: true,
      sound: _somaSound,
    );

    final streakText = currentStreak > 0 ? '$currentStreak-day streak' : 'active streak';
    await _plugin.show(
      id: idStreakSaver,
      title: 'Defend the Streak 🔥',
      body: 'Discipline is forged daily. Don\'t let your $streakText slip away — log your training and fuel before midnight.',
      notificationDetails: const NotificationDetails(android: androidDetails),
      payload: 'streak_saver',
    );
  }

  /// Show Afternoon Step Progress Check with ic_notif_steps icon
  Future<void> showStepProgressAlert({
    required int currentSteps,
    required int goalSteps,
  }) async {
    final pct = ((currentSteps / (goalSteps > 0 ? goalSteps : 1)) * 100).toInt();
    const androidDetails = AndroidNotificationDetails(
      channelWellbeingId,
      'Performance & Wellbeing',
      channelDescription: 'Daily Step Pace Alert',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_notif_steps',
      largeIcon: DrawableResourceAndroidBitmap('ic_notif_steps'),
      color: Color(0xFF22C55E),
      category: AndroidNotificationCategory.reminder,
      playSound: true,
      sound: _somaSound,
    );

    await _plugin.show(
      id: idStepProgress,
      title: 'Accelerate Your Pace 👟',
      body: 'Pacing check: $currentSteps / $goalSteps steps ($pct%). Clear the afternoon plateau with a brisk movement block.',
      notificationDetails: const NotificationDetails(android: androidDetails),
      payload: 'step_progress',
    );
  }

  /// Cancel specific notification
  Future<void> cancel(int id) async {
    await _plugin.cancel(id: id);
  }

  /// Cancel all active notifications
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
