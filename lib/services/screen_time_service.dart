import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AppScreenUsage {
  final String packageName;
  final Duration usage;

  const AppScreenUsage({
    required this.packageName,
    required this.usage,
  });
}

class ScreenTimeService {
  static const MethodChannel _channel = MethodChannel('com.soma/sleep');

  /// Check if Usage Stats / Digital Wellbeing permission is granted by user.
  /// This check is passive, instant, and never prompts or redirects.
  static Future<bool> isPermissionGranted() async {
    try {
      final bool? granted = await _channel.invokeMethod<bool>('checkUsageStatsPermission');
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Explicitly open Android Usage Access Settings screen.
  static Future<bool> openUsageSettings() async {
    try {
      final bool? success = await _channel.invokeMethod<bool>('openUsageAccessSettings');
      return success ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Calculates total Screen-On Time (in Duration) for today across tracked user apps.
  /// Queries raw Android UsageEvents (MOVE_TO_FOREGROUND and MOVE_TO_BACKGROUND transitions)
  /// starting explicitly from local midnight (00:00:00) to now, perfectly filtering out
  /// system UI, keyboards, launchers, and background services to align with Digital Wellbeing.
  static Future<Duration> getTodayTotalScreenTime() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getTodayScreenTime');
      if (result != null && result.containsKey('totalTimeMillis')) {
        final totalMillis = (result['totalTimeMillis'] as num).toInt();
        return Duration(milliseconds: totalMillis);
      }
    } catch (exception) {
      if (kDebugMode) {
        print('ScreenTimeService getTodayTotalScreenTime error: $exception');
      }
    }
    return Duration.zero;
  }

  /// Fetches per-app usage breakdown for today from raw UsageEvents.
  static Future<List<AppScreenUsage>> getTodayAppUsage() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getTodayScreenTime');
      if (result != null && result['apps'] is List) {
        final list = result['apps'] as List;
        return list.map((item) {
          final map = Map<String, dynamic>.from(item as Map);
          return AppScreenUsage(
            packageName: map['packageName'] as String? ?? '',
            usage: Duration(milliseconds: (map['usageMillis'] as num? ?? 0).toInt()),
          );
        }).toList();
      }
    } catch (exception) {
      if (kDebugMode) {
        print('ScreenTimeService getTodayAppUsage error: $exception');
      }
    }
    return [];
  }

  /// Formats duration into readable format e.g. "1h 4m"
  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}
