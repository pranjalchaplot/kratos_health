import 'package:app_usage/app_usage.dart';
import 'package:flutter/foundation.dart';

class ScreenTimeService {
  /// Fetches app usage stats for today (from midnight to now).
  static Future<List<AppUsageInfo>> getTodayAppUsage() async {
    try {
      DateTime endDate = DateTime.now();
      DateTime startDate = DateTime(endDate.year, endDate.month, endDate.day);
      
      List<AppUsageInfo> infoList = await AppUsage().getAppUsage(startDate, endDate);
      return infoList;
    } catch (exception) {
      if (kDebugMode) {
        print('ScreenTimeService error: $exception');
      }
      return [];
    }
  }

  /// Calculates total Screen-On Time (in Duration) for today across all tracked apps.
  static Future<Duration> getTodayTotalScreenTime() async {
    List<AppUsageInfo> usages = await getTodayAppUsage();
    Duration total = Duration.zero;
    for (var info in usages) {
      total += info.usage;
    }
    return total;
  }

  /// Formats duration into readable format e.g. "4h 25m"
  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}
