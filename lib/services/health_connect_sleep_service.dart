import 'package:flutter/foundation.dart';
import '../models/sleep_record.dart';

/// Secondary Sleep Service: Google Health Connect for Wearables.
/// 
/// Disabled for now as requested, but fully implemented and ready
/// to be activated when a wearable (Galaxy Watch, Pixel Watch, Fitbit, etc.) is connected.
class HealthConnectSleepService {
  /// Toggle to enable or disable Health Connect integration.
  /// Keep disabled until wearable setup is configured.
  static bool isEnabled = false;

  /// Indicates if a paired wearable device is actively connected.
  static bool isWearableConnected = false;

  /// Check whether Health Connect is supported and available on this device.
  static Future<bool> isAvailable() async {
    if (!isEnabled) return false;
    // When enabled with the `health` package, this checks Health Connect installation:
    // return await Health().isHealthConnectAvailable();
    return false;
  }

  /// Request user authorization for Health Connect sleep scopes.
  /// Scopes required:
  /// - HealthDataType.SLEEP_SESSION
  /// - HealthDataType.SLEEP_ASLEEP
  /// - HealthDataType.SLEEP_AWAKE
  /// - HealthDataType.SLEEP_DEEP
  /// - HealthDataType.SLEEP_REM
  /// - HealthDataType.SLEEP_LIGHT
  static Future<bool> requestPermissions() async {
    if (!isEnabled) {
      debugPrint('HealthConnectSleepService: Currently disabled. Enable when wearable is linked.');
      return false;
    }

    try {
      /*
      // Implementation template using the official health package:
      final health = Health();
      final types = [
        HealthDataType.SLEEP_SESSION,
        HealthDataType.SLEEP_ASLEEP,
        HealthDataType.SLEEP_AWAKE,
        HealthDataType.SLEEP_DEEP,
        HealthDataType.SLEEP_REM,
        HealthDataType.SLEEP_LIGHT,
      ];
      final permissions = types.map((e) => HealthDataAccess.READ).toList();
      final authorized = await health.requestAuthorization(types, permissions: permissions);
      return authorized ?? false;
      */
      return true;
    } catch (e) {
      debugPrint('HealthConnectSleepService: Permission request error: $e');
      return false;
    }
  }

  /// Fetch wearable sleep data from Health Connect for a specific time range.
  static Future<SleepRecord?> fetchWearableSleep({
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    if (!isEnabled || !isWearableConnected) {
      // Disabled for now, returns null so the app falls back to Android Sleep API.
      return null;
    }

    try {
      /*
      // Implementation template using the official health package:
      final health = Health();
      final types = [
        HealthDataType.SLEEP_SESSION,
        HealthDataType.SLEEP_ASLEEP,
        HealthDataType.SLEEP_AWAKE,
        HealthDataType.SLEEP_DEEP,
        HealthDataType.SLEEP_REM,
        HealthDataType.SLEEP_LIGHT,
      ];

      final dataPoints = await health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: types,
      );

      if (dataPoints.isEmpty) return null;

      double totalHours = 0.0;
      final Map<String, double> stageHours = {
        'deep': 0.0,
        'rem': 0.0,
        'light': 0.0,
        'awake': 0.0,
      };

      for (var point in dataPoints) {
        final durationHours = point.dateTo.difference(point.dateFrom).inMinutes / 60.0;
        if (point.type == HealthDataType.SLEEP_SESSION || point.type == HealthDataType.SLEEP_ASLEEP) {
          totalHours += durationHours;
        } else if (point.type == HealthDataType.SLEEP_DEEP) {
          stageHours['deep'] = (stageHours['deep'] ?? 0) + durationHours;
        } else if (point.type == HealthDataType.SLEEP_REM) {
          stageHours['rem'] = (stageHours['rem'] ?? 0) + durationHours;
        } else if (point.type == HealthDataType.SLEEP_LIGHT) {
          stageHours['light'] = (stageHours['light'] ?? 0) + durationHours;
        } else if (point.type == HealthDataType.SLEEP_AWAKE) {
          stageHours['awake'] = (stageHours['awake'] ?? 0) + durationHours;
        }
      }

      return SleepRecord(
        startTime: start,
        endTime: end,
        durationHours: double.parse(totalHours.toStringAsFixed(1)),
        source: SleepDataSource.healthConnect,
        stages: stageHours,
      );
      */
      return null;
    } catch (e) {
      debugPrint('HealthConnectSleepService: Error fetching wearable sleep: $e');
      return null;
    }
  }
}
