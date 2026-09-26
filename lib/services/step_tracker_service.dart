import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StepTrackerService {
  static StreamSubscription<StepCount>? _stepSubscription;
  static int _todayBaselineSteps = -1;
  static String? _baselineDate;

  /// Check if physical activity permission is granted
  static Future<bool> isPermissionGranted() async {
    final status = await Permission.activityRecognition.status;
    return status.isGranted;
  }

  /// Request physical activity permission from system
  static Future<bool> requestPermission() async {
    final status = await Permission.activityRecognition.request();
    if (status.isPermanentlyDenied) {
      openAppSettings();
    }
    return status.isGranted;
  }

  /// Initialize and start step counter stream listening if permission is granted.
  /// Callback [onStepsUpdated] receives the live step count calculated for today.
  static Future<void> startListening({
    required Function(int todaySteps) onStepsUpdated,
    Function(dynamic error)? onError,
  }) async {
    final granted = await isPermissionGranted();
    if (!granted) {
      if (kDebugMode) {
        print('StepTrackerService: Activity Recognition permission not granted.');
      }
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final todayKey = _formatTodayKey();
    _baselineDate = prefs.getString('kratos_step_baseline_date');
    _todayBaselineSteps = prefs.getInt('kratos_step_baseline_val') ?? -1;

    // Reset baseline if today is a new calendar day
    if (_baselineDate != todayKey) {
      _baselineDate = todayKey;
      _todayBaselineSteps = -1;
      await prefs.setString('kratos_step_baseline_date', todayKey);
      await prefs.setInt('kratos_step_baseline_val', -1);
    }

    _stepSubscription?.cancel();
    _stepSubscription = Pedometer.stepCountStream.listen(
      (StepCount event) async {
        final currentSensorSteps = event.steps;

        // If baseline is not set or sensor was reset (e.g., after phone reboot)
        if (_todayBaselineSteps == -1 || currentSensorSteps < _todayBaselineSteps) {
          _todayBaselineSteps = currentSensorSteps;
          await prefs.setInt('kratos_step_baseline_val', _todayBaselineSteps);
        }

        int stepsToday = currentSensorSteps - _todayBaselineSteps;
        if (stepsToday < 0) stepsToday = 0;

        onStepsUpdated(stepsToday);
      },
      onError: (error) {
        if (kDebugMode) {
          print('StepTrackerService Pedometer error: $error');
        }
        if (onError != null) {
          onError(error);
        }
      },
    );
  }

  static void stopListening() {
    _stepSubscription?.cancel();
    _stepSubscription = null;
  }

  static String _formatTodayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
