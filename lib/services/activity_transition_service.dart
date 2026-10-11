import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/detected_activity_record.dart';
import '../widgets/detected_activity_prompt_sheet.dart';

/// Background Activity Transition Service
///
/// Communicates with Google Play Services Activity Transition API via Kotlin
/// method channel to passively detect when the user starts/finishes running,
/// walking, or cycling in the background without needing the app open.
class ActivityTransitionService {
  static const MethodChannel _channel = MethodChannel('com.soma/activity_transition');
  static bool _isCheckingPrompt = false;

  /// Check if the required Activity Recognition runtime permission is granted.
  static Future<bool> isPermissionGranted() async {
    final status = await Permission.activityRecognition.status;
    return status.isGranted;
  }

  /// Request Activity Recognition permission from the user.
  static Future<bool> requestPermission() async {
    final status = await Permission.activityRecognition.request();
    if (status.isPermanentlyDenied) {
      await openAppSettings();
    }
    return status.isGranted;
  }

  /// Start listening for Android Activity Transition updates in the background.
  static Future<bool> startTracking() async {
    try {
      final granted = await isPermissionGranted();
      if (!granted) {
        final req = await requestPermission();
        if (!req) {
          debugPrint('ActivityTransitionService: Permission denied.');
          return false;
        }
      }

      final bool? success = await _channel.invokeMethod<bool>('startTracking');
      debugPrint('ActivityTransitionService: startTracking result = $success');
      return success ?? false;
    } catch (e) {
      debugPrint('ActivityTransitionService: Error starting tracking: $e');
      return false;
    }
  }

  /// Stop listening for activity transitions.
  static Future<bool> stopTracking() async {
    try {
      final bool? success = await _channel.invokeMethod<bool>('stopTracking');
      return success ?? false;
    } catch (e) {
      debugPrint('ActivityTransitionService: Error stopping tracking: $e');
      return false;
    }
  }

  /// Check if background activity transition tracking is currently active.
  static Future<bool> isTrackingActive() async {
    try {
      final bool? active = await _channel.invokeMethod<bool>('isTrackingActive');
      return active ?? false;
    } catch (e) {
      debugPrint('ActivityTransitionService: Error checking active state: $e');
      return false;
    }
  }

  /// Retrieve any pending unlogged detected activity.
  static Future<DetectedActivityRecord?> getPendingDetectedActivity() async {
    try {
      final dynamic raw = await _channel.invokeMethod('getPendingDetectedActivity');
      if (raw != null && raw is Map) {
        return DetectedActivityRecord.fromMap(raw);
      }
      return null;
    } catch (e) {
      debugPrint('ActivityTransitionService: Error getting pending detected activity: $e');
      return null;
    }
  }

  /// Clear the pending detected activity once logged or dismissed.
  static Future<bool> clearPendingDetectedActivity() async {
    try {
      final bool? success = await _channel.invokeMethod<bool>('clearPendingDetectedActivity');
      return success ?? false;
    } catch (e) {
      debugPrint('ActivityTransitionService: Error clearing pending activity: $e');
      return false;
    }
  }

  /// Simulate a background detected session (e.g. running for 25 mins) for rapid verification.
  static Future<DetectedActivityRecord?> simulateDetectedActivity({
    String type = 'running',
    int durationMinutes = 24,
    double? distanceKm,
  }) async {
    try {
      final dynamic raw = await _channel.invokeMethod('simulateDetectedActivity', {
        'type': type,
        'durationMinutes': durationMinutes,
        'distanceKm': distanceKm,
      });
      if (raw != null && raw is Map) {
        return DetectedActivityRecord.fromMap(raw);
      }
      return null;
    } catch (e) {
      debugPrint('ActivityTransitionService: Error simulating detected activity: $e');
      return null;
    }
  }

  /// Check if there is a pending detected activity and display the interactive confirmation prompt sheet.
  static Future<void> checkAndShowPrompt(BuildContext context) async {
    if (_isCheckingPrompt) return;
    _isCheckingPrompt = true;

    try {
      final record = await getPendingDetectedActivity();
      if (record != null && !record.isLogged && context.mounted) {
        await DetectedActivityPromptSheet.show(context, record: record);
      }
    } catch (e) {
      debugPrint('ActivityTransitionService: checkAndShowPrompt error: $e');
    } finally {
      _isCheckingPrompt = false;
    }
  }
}
