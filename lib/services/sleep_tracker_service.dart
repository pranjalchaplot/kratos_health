import 'package:flutter/foundation.dart';
import '../models/sleep_record.dart';
import 'android_sleep_service.dart';
import 'health_connect_sleep_service.dart';

/// Unified Sleep Tracking Service for SOMA.
/// 
/// Primary Source: Android Sleep Segment API (Google Play Services)
/// Secondary Source: Health Connect (Prepared for wearable integration, disabled by default)
class SleepTrackerService {
  /// Toggle whether wearable integration (Health Connect) should take priority.
  /// Defaults to false so Android Sleep API (phone sensors) is the primary source.
  static bool useWearableHealthConnect = false;

  /// Check if the required permissions for sleep tracking are granted.
  static Future<bool> isPermissionGranted() async {
    if (useWearableHealthConnect && HealthConnectSleepService.isEnabled) {
      return await HealthConnectSleepService.requestPermissions();
    }
    return await AndroidSleepService.isPermissionGranted();
  }

  /// Request sleep tracking permissions.
  static Future<bool> requestPermission() async {
    if (useWearableHealthConnect && HealthConnectSleepService.isEnabled) {
      return await HealthConnectSleepService.requestPermissions();
    }
    return await AndroidSleepService.requestPermission();
  }

  /// Initialize and start sleep tracking background services.
  static Future<bool> startTracking() async {
    if (useWearableHealthConnect && HealthConnectSleepService.isEnabled) {
      debugPrint('SleepTrackerService: Wearable Health Connect mode active.');
      return true;
    }

    // Default & Primary: Android Sleep Segment API
    debugPrint('SleepTrackerService: Starting Android Sleep API tracking (primary phone sensor)...');
    return await AndroidSleepService.startSleepTracking();
  }

  /// Stop sleep tracking services.
  static Future<bool> stopTracking() async {
    return await AndroidSleepService.stopSleepTracking();
  }

  /// Retrieve today's recorded sleep session.
  /// Evaluates Health Connect first (if wearable enabled), then Android Sleep API.
  static Future<SleepRecord?> getTodaySleep() async {
    // 1. Check wearable / Health Connect if enabled
    if (useWearableHealthConnect && HealthConnectSleepService.isEnabled) {
      final wearableSleep = await HealthConnectSleepService.fetchWearableSleep();
      if (wearableSleep != null && wearableSleep.durationHours > 0) {
        return wearableSleep;
      }
    }

    // 2. Primary source: Android Sleep API
    final phoneSleep = await AndroidSleepService.getLastSleepSegment();
    if (phoneSleep != null) {
      // Ensure the sleep segment is relevant (ended within the last 24 hours)
      final now = DateTime.now();
      final difference = now.difference(phoneSleep.endTime);
      if (difference.inHours <= 24) {
        return phoneSleep;
      }
    }

    return null;
  }

  /// Simulate a detected sleep event for testing purposes.
  static Future<SleepRecord?> simulateSleep({double hours = 7.5}) async {
    return await AndroidSleepService.simulateSleepSegment(hours: hours);
  }
}
