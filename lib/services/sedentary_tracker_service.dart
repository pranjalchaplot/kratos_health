import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import '../models/reminder_settings.dart';
import 'notification_service.dart';

/// Sensor-driven Sedentary Detection Service.
/// Continuously monitors Sensor.TYPE_STEP_COUNTER (via Pedometer).
/// If inactivity exceeds [sedentaryIntervalMinutes] during daytime hours,
/// sends an alert. Requires at least [sedentaryStepThreshold] (default: 20 steps)
/// to reset the inactivity timer.
class SedentaryTrackerService {
  static final SedentaryTrackerService _instance = SedentaryTrackerService._internal();
  factory SedentaryTrackerService() => _instance;
  SedentaryTrackerService._internal();

  StreamSubscription<StepCount>? _stepSubscription;
  Timer? _tickerTimer;

  DateTime _lastMovementTime = DateTime.now();
  int _baselineSteps = -1;
  int _lastKnownSteps = -1;
  bool _isMonitoring = false;

  // Reference to current settings and notification dispatcher
  ReminderSettings? _settings;
  Function(String category)? _onAlertSent;
  Function(String category)? _onMovementAcknowledged;

  DateTime get lastMovementTime => _lastMovementTime;
  int get inactiveMinutes => DateTime.now().difference(_lastMovementTime).inMinutes;
  int get stepsInCurrentCycle => (_lastKnownSteps != -1 && _baselineSteps != -1) 
      ? (_lastKnownSteps - _baselineSteps).clamp(0, 999999) 
      : 0;
  bool get isMonitoring => _isMonitoring;

  /// Start monitoring step counter sensor
  Future<void> startMonitoring({
    required ReminderSettings settings,
    required Function(String category) onAlertSent,
    required Function(String category) onMovementAcknowledged,
  }) async {
    _settings = settings;
    _onAlertSent = onAlertSent;
    _onMovementAcknowledged = onMovementAcknowledged;

    if (_isMonitoring) return;

    final hasPermission = await NotificationService().isPermissionGranted();
    if (kDebugMode) {
      print('SedentaryTrackerService: starting sensor monitoring. Notification permission: $hasPermission');
    }

    _lastMovementTime = DateTime.now();
    _baselineSteps = -1;
    _lastKnownSteps = -1;

    try {
      _stepSubscription?.cancel();
      _stepSubscription = Pedometer.stepCountStream.listen(
        _onStepReceived,
        onError: (err) {
          if (kDebugMode) print('SedentaryTrackerService Pedometer stream error: $err');
        },
      );
      _isMonitoring = true;

      // Start periodic ticker (every 30 seconds) to evaluate inactivity
      _tickerTimer?.cancel();
      _tickerTimer = Timer.periodic(const Duration(seconds: 30), (_) => _checkInactivity());
    } catch (e) {
      if (kDebugMode) print('Failed to subscribe to Pedometer in SedentaryTrackerService: $e');
    }
  }

  /// Update active settings (e.g., when user changes interval or daytime window)
  void updateSettings(ReminderSettings newSettings) {
    _settings = newSettings;
  }

  void _onStepReceived(StepCount event) {
    final currentSteps = event.steps;
    _lastKnownSteps = currentSteps;

    if (_baselineSteps == -1) {
      _baselineSteps = currentSteps;
      _lastMovementTime = DateTime.now();
      return;
    }

    final delta = currentSteps - _baselineSteps;
    final threshold = _settings?.sedentaryStepThreshold ?? 20;

    // If user has taken required steps to break sedentary cycle
    if (delta >= threshold) {
      if (kDebugMode) {
        print('SedentaryTrackerService: Movement detected! ($delta steps >= $threshold). Resetting timer.');
      }
      _baselineSteps = currentSteps;
      _lastMovementTime = DateTime.now();

      // Automatically acknowledge and unpause sedentary state
      _onMovementAcknowledged?.call('sedentary');
    }
  }

  void _checkInactivity() {
    if (!_isMonitoring || _settings == null || !_settings!.sedentaryEnabled) return;

    final now = DateTime.now();
    final currentHour = now.hour;

    // Respect daytime active window (e.g. 09:00 - 21:00)
    if (currentHour < _settings!.sedentaryStartHour || currentHour >= _settings!.sedentaryEndHour) {
      return;
    }

    final elapsedMins = now.difference(_lastMovementTime).inMinutes;
    final intervalMins = _settings!.sedentaryIntervalMinutes;

    if (elapsedMins >= intervalMins) {
      // Check Smart Adaptive Throttling:
      // 1. Is sedentary already pending (unattended)?
      // 2. Is global circuit breaker active (>= 2 unanswered)?
      if (_settings!.canSendReminder('sedentary')) {
        if (kDebugMode) {
          print('Sedentary alert triggered: inactive for $elapsedMins mins.');
        }

        NotificationService().showSedentaryAlert(inactiveMinutes: elapsedMins);
        _onAlertSent?.call('sedentary');
      }
    }
  }

  /// Manual reset (e.g. user acknowledged from UI)
  void resetInactivityTimer() {
    _lastMovementTime = DateTime.now();
    if (_lastKnownSteps != -1) {
      _baselineSteps = _lastKnownSteps;
    }
  }

  void stopMonitoring() {
    _stepSubscription?.cancel();
    _tickerTimer?.cancel();
    _stepSubscription = null;
    _tickerTimer = null;
    _isMonitoring = false;
  }
}
