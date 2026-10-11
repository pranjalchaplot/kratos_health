import 'package:app_usage/app_usage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

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

  /// Known Android system, launcher, keyboard, and background services
  /// that Digital Wellbeing filters out of user screen time.
  static const Set<String> _systemExclusionPackages = {
    'com.android.systemui',
    'com.google.android.apps.nexuslauncher',
    'com.google.android.launcher',
    'com.sec.android.app.launcher',
    'com.miui.home',
    'com.oppo.launcher',
    'com.huawei.android.launcher',
    'com.oneplus.launcher',
    'com.teslacoilsw.launcher',
    'ch.deletescape.lawnchair',
    'com.google.android.inputmethod.latin',
    'com.samsung.android.honeyboard',
    'com.touchtype.swiftkey',
    'com.google.android.gms',
    'com.google.android.googlequicksearchbox',
    'com.android.settings',
    'android',
  };

  /// Fetches app usage stats for today (strictly from local midnight 00:00:00 to now),
  /// filtering out background system services and launchers.
  static Future<List<AppUsageInfo>> getTodayAppUsage() async {
    try {
      final now = DateTime.now();
      // Ensure strict local midnight bounds
      final startDate = DateTime(now.year, now.month, now.day, 0, 0, 0, 0);
      final endDate = now;
      
      final rawList = await AppUsage().getAppUsage(startDate, endDate);
      
      // Filter out system launchers, keyboards, wallpaper engines, and 0-duration entries
      final filteredList = rawList.where((info) {
        if (info.usage <= Duration.zero) return false;
        final pkg = info.packageName.toLowerCase();
        if (_systemExclusionPackages.contains(pkg)) return false;
        if (pkg.startsWith('com.android.wallpaper') || pkg.startsWith('com.google.android.apps.wallpaper')) {
          return false;
        }
        return true;
      }).toList();

      return filteredList;
    } catch (exception) {
      if (kDebugMode) {
        print('ScreenTimeService error: $exception');
      }
      return [];
    }
  }

  /// Calculates total Screen-On Time (in Duration) for today across tracked user apps.
  static Future<Duration> getTodayTotalScreenTime() async {
    final usages = await getTodayAppUsage();
    Duration total = Duration.zero;
    for (final info in usages) {
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
