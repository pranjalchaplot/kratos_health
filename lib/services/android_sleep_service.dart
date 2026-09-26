import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/sleep_record.dart';

/// Primary Sleep Service: Communicates with Android's Google Play Services Sleep Segment API.
/// Does not require a smartwatch/wearable because the phone's sensors detect stillness,
/// ambient light, screen off duration, and charging state.
class AndroidSleepService {
  static const MethodChannel _channel = MethodChannel('com.soma/sleep');

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

  /// Start listening for Android Sleep Segment updates.
  static Future<bool> startSleepTracking() async {
    try {
      final granted = await isPermissionGranted();
      if (!granted) {
        final req = await requestPermission();
        if (!req) {
          debugPrint('AndroidSleepService: Activity Recognition permission denied.');
          return false;
        }
      }

      final bool? success = await _channel.invokeMethod<bool>('startSleepTracking');
      debugPrint('AndroidSleepService: startSleepTracking result = $success');
      return success ?? false;
    } catch (e) {
      debugPrint('AndroidSleepService: Error starting sleep tracking: $e');
      return false;
    }
  }

  /// Stop listening for Android Sleep Segment updates.
  static Future<bool> stopSleepTracking() async {
    try {
      final bool? success = await _channel.invokeMethod<bool>('stopSleepTracking');
      return success ?? false;
    } catch (e) {
      debugPrint('AndroidSleepService: Error stopping sleep tracking: $e');
      return false;
    }
  }

  /// Check if sleep tracking is currently active in the native Android layer.
  static Future<bool> isTrackingActive() async {
    try {
      final bool? active = await _channel.invokeMethod<bool>('isSleepTrackingActive');
      return active ?? false;
    } catch (e) {
      debugPrint('AndroidSleepService: Error checking tracking status: $e');
      return false;
    }
  }

  /// Fetch the latest sleep segment detected by Android.
  static Future<SleepRecord?> getLastSleepSegment() async {
    try {
      final dynamic raw = await _channel.invokeMethod('getLastSleepSegment');
      if (raw == null) return null;

      final map = Map<String, dynamic>.from(raw as Map);
      final startTimeMillis = map['startTimeMillis'] as int;
      final endTimeMillis = map['endTimeMillis'] as int;
      final durationHours = (map['durationHours'] as num).toDouble();
      final status = map['status'] as int?;

      return SleepRecord(
        startTime: DateTime.fromMillisecondsSinceEpoch(startTimeMillis),
        endTime: DateTime.fromMillisecondsSinceEpoch(endTimeMillis),
        durationHours: durationHours,
        source: SleepDataSource.androidSleepApi,
        status: status,
      );
    } catch (e) {
      debugPrint('AndroidSleepService: Error getting last sleep segment: $e');
      return null;
    }
  }

  /// Helper to simulate a sleep segment for testing and verification without waiting overnight.
  static Future<SleepRecord?> simulateSleepSegment({double hours = 7.5}) async {
    try {
      final dynamic raw = await _channel.invokeMethod('simulateSleepData', {'hours': hours});
      if (raw == null) return null;

      final map = Map<String, dynamic>.from(raw as Map);
      final startTimeMillis = map['startTimeMillis'] as int;
      final endTimeMillis = map['endTimeMillis'] as int;
      final durationHours = (map['durationHours'] as num).toDouble();

      return SleepRecord(
        startTime: DateTime.fromMillisecondsSinceEpoch(startTimeMillis),
        endTime: DateTime.fromMillisecondsSinceEpoch(endTimeMillis),
        durationHours: durationHours,
        source: SleepDataSource.androidSleepApi,
        status: 0,
      );
    } catch (e) {
      debugPrint('AndroidSleepService: Error simulating sleep segment: $e');
      return null;
    }
  }
}
