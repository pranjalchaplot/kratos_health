package com.example.kratos_app

import android.Manifest
import android.app.AppOpsManager
import android.app.PendingIntent
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.PowerManager
import android.os.Process
import android.provider.Settings
import android.util.Log
import androidx.core.content.ContextCompat
import com.google.android.gms.location.ActivityRecognition
import com.google.android.gms.location.ActivityTransition
import com.google.android.gms.location.ActivityTransitionRequest
import com.google.android.gms.location.DetectedActivity
import com.google.android.gms.location.SleepSegmentRequest
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar
import java.util.Date

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.soma/sleep"
    private val ACTIVITY_CHANNEL = "com.soma/activity_transition"
    private val TAG = "SomaMainActivity"
    private val SLEEP_REQUEST_CODE = 4210
    private val ACTIVITY_REQUEST_CODE = 4220

    companion object {
        private val SYSTEM_EXCLUDED_PACKAGES = hashSetOf(
            "com.android.systemui",
            "android",
            "com.google.android.apps.nexuslauncher",
            "com.google.android.launcher",
            "com.sec.android.app.launcher",
            "com.miui.home",
            "com.oppo.launcher",
            "com.huawei.android.launcher",
            "com.oneplus.launcher",
            "com.teslacoilsw.launcher",
            "ch.deletescape.lawnchair",
            "com.google.android.inputmethod.latin",
            "com.samsung.android.honeyboard",
            "com.touchtype.swiftkey",
            "com.google.android.gms",
            "com.google.android.googlequicksearchbox",
            "com.google.android.permissioncontroller",
            "com.android.settings"
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkUsageStatsPermission" -> {
                    checkUsageStatsPermission(result)
                }
                "openUsageAccessSettings" -> {
                    openUsageAccessSettings(result)
                }
                "getTodayScreenTime" -> {
                    getTodayScreenTime(result)
                }
                "startSleepTracking" -> {
                    startSleepTracking(result)
                }
                "stopSleepTracking" -> {
                    stopSleepTracking(result)
                }
                "isSleepTrackingActive" -> {
                    val prefs = SleepReceiver.getPrefs(this)
                    result.success(prefs.getBoolean(SleepReceiver.KEY_TRACKING_ENABLED, false))
                }
                "getLastSleepSegment" -> {
                    getLastSleepSegment(result)
                }
                "simulateSleepData" -> {
                    val hours = (call.argument<Double>("hours") ?: 7.5)
                    simulateSleepSegment(hours, result)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ACTIVITY_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startTracking" -> {
                    startActivityTransitionTracking(result)
                }
                "stopTracking" -> {
                    stopActivityTransitionTracking(result)
                }
                "isTrackingActive" -> {
                    val prefs = ActivityTransitionReceiver.getPrefs(this)
                    result.success(prefs.getBoolean(ActivityTransitionReceiver.KEY_TRACKING_ENABLED, false))
                }
                "getPendingDetectedActivity" -> {
                    getPendingDetectedActivity(result)
                }
                "clearPendingDetectedActivity" -> {
                    clearPendingDetectedActivity(result)
                }
                "simulateDetectedActivity" -> {
                    val type = call.argument<String>("type") ?: "running"
                    val durationMins = call.argument<Int>("durationMinutes") ?: 25
                    val distanceKm = call.argument<Double>("distanceKm")
                    simulateDetectedActivity(type, durationMins, distanceKm, result)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun checkUsageStatsPermission(result: MethodChannel.Result) {
        try {
            val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
            val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                appOps.unsafeCheckOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    Process.myUid(),
                    packageName
                )
            } else {
                @Suppress("DEPRECATION")
                appOps.checkOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    Process.myUid(),
                    packageName
                )
            }
            result.success(mode == AppOpsManager.MODE_ALLOWED)
        } catch (e: Exception) {
            Log.e(TAG, "Error checking usage stats permission: ${e.message}", e)
            result.success(false)
        }
    }

    private fun openUsageAccessSettings(result: MethodChannel.Result) {
        try {
            val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Error opening usage access settings: ${e.message}", e)
            result.success(false)
        }
    }

    private fun getLauncherPackages(): Set<String> {
        val launcherPackages = mutableSetOf<String>()
        try {
            val intent = Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_HOME)
            }
            val resolveInfos = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.queryIntentActivities(
                    intent,
                    PackageManager.ResolveInfoFlags.of(0L)
                )
            } else {
                @Suppress("DEPRECATION")
                packageManager.queryIntentActivities(intent, 0)
            }
            for (info in resolveInfos) {
                info.activityInfo?.packageName?.let { launcherPackages.add(it) }
            }
            val defaultResolve = packageManager.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY)
            defaultResolve?.activityInfo?.packageName?.let { launcherPackages.add(it) }
        } catch (e: Exception) {
            Log.e(TAG, "Error resolving launcher packages: ${e.message}")
        }
        return launcherPackages
    }

    private fun getLaunchablePackages(): Set<String> {
        val launchable = mutableSetOf<String>()
        try {
            val intent = Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_LAUNCHER)
            }
            val resolveInfos = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.queryIntentActivities(
                    intent,
                    PackageManager.ResolveInfoFlags.of(0L)
                )
            } else {
                @Suppress("DEPRECATION")
                packageManager.queryIntentActivities(intent, 0)
            }
            for (info in resolveInfos) {
                info.activityInfo?.packageName?.let { launchable.add(it) }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error resolving launchable packages: ${e.message}")
        }
        return launchable
    }

    private fun isExcludedPackage(
        pkg: String?,
        launcherPackages: Set<String>,
        launchablePackages: Set<String>
    ): Boolean {
        if (pkg.isNullOrBlank()) return true
        val lower = pkg.lowercase()
        if (launcherPackages.contains(pkg) || launcherPackages.contains(lower)) return true
        if (SYSTEM_EXCLUDED_PACKAGES.contains(lower)) return true
        if (lower.startsWith("com.android.wallpaper") || lower.startsWith("com.google.android.apps.wallpaper")) return true
        if (lower == "android" || lower == "com.android.systemui") return true
        // Exclude internal OS packages, background providers, and transparent activities that lack a launchable intent
        if (launchablePackages.isNotEmpty() && !launchablePackages.contains(pkg) && pkg != packageName) {
            return true
        }
        return false
    }

    private fun getTodayScreenTime(result: MethodChannel.Result) {
        try {
            val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
            val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                appOps.unsafeCheckOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    Process.myUid(),
                    packageName
                )
            } else {
                @Suppress("DEPRECATION")
                appOps.checkOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    Process.myUid(),
                    packageName
                )
            }
            if (mode != AppOpsManager.MODE_ALLOWED) {
                Log.w(TAG, "ScreenTime: Usage stats permission not allowed")
                result.success(hashMapOf(
                    "totalTimeMillis" to 0L,
                    "eventCount" to 0,
                    "apps" to emptyList<Map<String, Any>>()
                ))
                return
            }

            // 1. Boundary Alignment: Local Midnight explicitly at 00:00:00.000
            val calendar = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            val startTime = calendar.timeInMillis
            val endTime = System.currentTimeMillis()
            Log.i(TAG, "ScreenTime: Window start = ${Date(startTime)} ($startTime), end = ${Date(endTime)} ($endTime)")

            // 2. Filter Launchers and Non-Launchable System Packages
            val launcherPackages = getLauncherPackages()
            val launchablePackages = getLaunchablePackages()
            Log.i(TAG, "ScreenTime: Excluded launcher packages: $launcherPackages")
            Log.i(TAG, "ScreenTime: Total launchable packages registered: ${launchablePackages.size}")

            // 3. Raw UsageEvents Transition Tracking (MOVE_TO_FOREGROUND & MOVE_TO_BACKGROUND)
            val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val usageEvents = usageStatsManager.queryEvents(startTime, endTime)

            var currentForegroundPackage: String? = null
            var currentForegroundStartTime: Long = 0L
            val perAppUsageMap = mutableMapOf<String, Long>()
            var totalScreenTimeMs = 0L
            var eventCount = 0

            val event = UsageEvents.Event()
            while (usageEvents.hasNextEvent()) {
                usageEvents.getNextEvent(event)
                eventCount++
                val eventType = event.eventType
                val pkg = event.packageName ?: ""
                val time = event.timeStamp
                val clampedTime = time.coerceIn(startTime, endTime)

                when (eventType) {
                    1 -> { // UsageEvents.Event.ACTIVITY_RESUMED / MOVE_TO_FOREGROUND
                        if (currentForegroundPackage != null) {
                            if (clampedTime > currentForegroundStartTime && !isExcludedPackage(currentForegroundPackage, launcherPackages, launchablePackages)) {
                                val sessionDuration = clampedTime - currentForegroundStartTime
                                perAppUsageMap[currentForegroundPackage!!] = (perAppUsageMap[currentForegroundPackage!!] ?: 0L) + sessionDuration
                                totalScreenTimeMs += sessionDuration
                            }
                        }
                        currentForegroundPackage = pkg
                        currentForegroundStartTime = clampedTime
                    }
                    2 -> { // UsageEvents.Event.ACTIVITY_PAUSED / MOVE_TO_BACKGROUND
                        if (currentForegroundPackage == pkg) {
                            if (clampedTime > currentForegroundStartTime && !isExcludedPackage(pkg, launcherPackages, launchablePackages)) {
                                val sessionDuration = clampedTime - currentForegroundStartTime
                                perAppUsageMap[pkg] = (perAppUsageMap[pkg] ?: 0L) + sessionDuration
                                totalScreenTimeMs += sessionDuration
                            }
                            currentForegroundPackage = null
                            currentForegroundStartTime = 0L
                        } else if (currentForegroundPackage == null) {
                            // If this was the first event of today, app was active across midnight
                            if (clampedTime > startTime && !isExcludedPackage(pkg, launcherPackages, launchablePackages)) {
                                val sessionDuration = clampedTime - startTime
                                if (sessionDuration in 1..(4 * 3600 * 1000)) {
                                    perAppUsageMap[pkg] = (perAppUsageMap[pkg] ?: 0L) + sessionDuration
                                    totalScreenTimeMs += sessionDuration
                                }
                            }
                        }
                    }
                    16, 18 -> { // SCREEN_NON_INTERACTIVE or KEYGUARD_SHOWN (Screen locked / turned off)
                        if (currentForegroundPackage != null) {
                            if (clampedTime > currentForegroundStartTime && !isExcludedPackage(currentForegroundPackage, launcherPackages, launchablePackages)) {
                                val sessionDuration = clampedTime - currentForegroundStartTime
                                perAppUsageMap[currentForegroundPackage!!] = (perAppUsageMap[currentForegroundPackage!!] ?: 0L) + sessionDuration
                                totalScreenTimeMs += sessionDuration
                            }
                            currentForegroundPackage = null
                            currentForegroundStartTime = 0L
                        }
                    }
                }
            }

            // Close trailing active session if user is currently using the device right now
            if (currentForegroundPackage != null && !isExcludedPackage(currentForegroundPackage, launcherPackages, launchablePackages)) {
                val powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager
                val isInteractive = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT_WATCH) {
                    powerManager?.isInteractive ?: true
                } else {
                    @Suppress("DEPRECATION")
                    powerManager?.isScreenOn ?: true
                }
                if (isInteractive && endTime > currentForegroundStartTime) {
                    val sessionDuration = endTime - currentForegroundStartTime
                    if (sessionDuration in 1..(2 * 3600 * 1000)) {
                        perAppUsageMap[currentForegroundPackage!!] = (perAppUsageMap[currentForegroundPackage!!] ?: 0L) + sessionDuration
                        totalScreenTimeMs += sessionDuration
                    }
                }
            }

            val hours = totalScreenTimeMs / (1000 * 3600)
            val minutes = (totalScreenTimeMs % (1000 * 3600)) / (1000 * 60)
            Log.i(TAG, "ScreenTime: Processed $eventCount events. Total screen time: ${hours}h ${minutes}m (${totalScreenTimeMs}ms)")
            Log.i(TAG, "ScreenTime: Tracked active apps breakdown (${perAppUsageMap.size} packages):")
            for ((appPkg, usageMs) in perAppUsageMap) {
                val appMins = usageMs / (1000 * 60)
                Log.d(TAG, "   -> $appPkg: ${appMins}m (${usageMs}ms)")
            }

            val appList = perAppUsageMap.map { (pkg, usageMs) ->
                hashMapOf(
                    "packageName" to pkg,
                    "usageMillis" to usageMs
                )
            }

            val resultMap = hashMapOf(
                "totalTimeMillis" to totalScreenTimeMs,
                "startTimeMillis" to startTime,
                "endTimeMillis" to endTime,
                "eventCount" to eventCount,
                "apps" to appList
            )
            result.success(resultMap)
        } catch (e: Exception) {
            Log.e(TAG, "Error calculating screen time: ${e.message}", e)
            result.error("ERROR", e.message, null)
        }
    }

    private fun getSleepPendingIntent(): PendingIntent {
        val intent = Intent(this, SleepReceiver::class.java)
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        return PendingIntent.getBroadcast(this, SLEEP_REQUEST_CODE, intent, flags)
    }

    private fun startSleepTracking(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val permissionCheck = ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.ACTIVITY_RECOGNITION
            )
            if (permissionCheck != PackageManager.PERMISSION_GRANTED) {
                result.error("PERMISSION_DENIED", "ACTIVITY_RECOGNITION permission is required", null)
                return
            }
        }

        try {
            val pendingIntent = getSleepPendingIntent()
            val request = SleepSegmentRequest.getDefaultSleepSegmentRequest()

            ActivityRecognition.getClient(this)
                .requestSleepSegmentUpdates(pendingIntent, request)
                .addOnSuccessListener {
                    Log.i(TAG, "Successfully subscribed to Android Sleep Segment API")
                    SleepReceiver.getPrefs(this).edit()
                        .putBoolean(SleepReceiver.KEY_TRACKING_ENABLED, true)
                        .apply()
                    result.success(true)
                }
                .addOnFailureListener { error ->
                    Log.e(TAG, "Failed to subscribe to Sleep Segment API: ${error.message}", error)
                    result.error("SUBSCRIPTION_FAILED", error.message, null)
                }
        } catch (e: Exception) {
            Log.e(TAG, "Exception starting sleep tracking: ${e.message}", e)
            result.error("EXCEPTION", e.message, null)
        }
    }

    private fun stopSleepTracking(result: MethodChannel.Result) {
        try {
            val pendingIntent = getSleepPendingIntent()
            ActivityRecognition.getClient(this)
                .removeSleepSegmentUpdates(pendingIntent)
                .addOnSuccessListener {
                    Log.i(TAG, "Successfully stopped Android Sleep Segment updates")
                    SleepReceiver.getPrefs(this).edit()
                        .putBoolean(SleepReceiver.KEY_TRACKING_ENABLED, false)
                        .apply()
                    result.success(true)
                }
                .addOnFailureListener { error ->
                    Log.e(TAG, "Failed to remove Sleep Segment updates: ${error.message}", error)
                    result.error("REMOVE_FAILED", error.message, null)
                }
        } catch (e: Exception) {
            Log.e(TAG, "Exception stopping sleep tracking: ${e.message}", e)
            result.error("EXCEPTION", e.message, null)
        }
    }

    private fun getLastSleepSegment(result: MethodChannel.Result) {
        val prefs = SleepReceiver.getPrefs(this)
        val startTime = prefs.getLong(SleepReceiver.KEY_LAST_START_TIME, -1L)
        val endTime = prefs.getLong(SleepReceiver.KEY_LAST_END_TIME, -1L)
        val durationMins = prefs.getInt(SleepReceiver.KEY_LAST_DURATION_MINUTES, 0)
        val status = prefs.getInt(SleepReceiver.KEY_LAST_STATUS, 0)
        val updatedAt = prefs.getLong(SleepReceiver.KEY_LAST_UPDATED_AT, 0L)

        if (startTime == -1L || endTime == -1L || durationMins <= 0) {
            result.success(null)
            return
        }

        val map = hashMapOf(
            "startTimeMillis" to startTime,
            "endTimeMillis" to endTime,
            "durationMinutes" to durationMins,
            "durationHours" to (durationMins / 60.0),
            "status" to status,
            "updatedAt" to updatedAt
        )
        result.success(map)
    }

    private fun simulateSleepSegment(hours: Double, result: MethodChannel.Result) {
        val now = System.currentTimeMillis()
        val durationMillis = (hours * 3600 * 1000).toLong()
        val startTime = now - durationMillis
        val endTime = now

        SleepReceiver.saveSleepSegment(
            this,
            startTime,
            endTime,
            durationMillis,
            0 // STATUS_SUCCESSFUL
        )

        val durationMinutes = (durationMillis / (1000 * 60)).toInt()
        val map = hashMapOf(
            "startTimeMillis" to startTime,
            "endTimeMillis" to endTime,
            "durationMinutes" to durationMinutes,
            "durationHours" to hours,
            "status" to 0,
            "updatedAt" to now
        )
        result.success(map)
    }

    private fun getActivityPendingIntent(): PendingIntent {
        val intent = Intent(this, ActivityTransitionReceiver::class.java)
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        return PendingIntent.getBroadcast(this, ACTIVITY_REQUEST_CODE, intent, flags)
    }

    private fun startActivityTransitionTracking(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val permissionCheck = ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.ACTIVITY_RECOGNITION
            )
            if (permissionCheck != PackageManager.PERMISSION_GRANTED) {
                result.error("PERMISSION_DENIED", "ACTIVITY_RECOGNITION permission is required", null)
                return
            }
        }

        try {
            val transitions = ArrayList<ActivityTransition>()

            // 1. RUNNING
            transitions.add(
                ActivityTransition.Builder()
                    .setActivityType(DetectedActivity.RUNNING)
                    .setActivityTransition(ActivityTransition.ACTIVITY_TRANSITION_ENTER)
                    .build()
            )
            transitions.add(
                ActivityTransition.Builder()
                    .setActivityType(DetectedActivity.RUNNING)
                    .setActivityTransition(ActivityTransition.ACTIVITY_TRANSITION_EXIT)
                    .build()
            )

            // 2. WALKING
            transitions.add(
                ActivityTransition.Builder()
                    .setActivityType(DetectedActivity.WALKING)
                    .setActivityTransition(ActivityTransition.ACTIVITY_TRANSITION_ENTER)
                    .build()
            )
            transitions.add(
                ActivityTransition.Builder()
                    .setActivityType(DetectedActivity.WALKING)
                    .setActivityTransition(ActivityTransition.ACTIVITY_TRANSITION_EXIT)
                    .build()
            )

            // 3. ON_BICYCLE
            transitions.add(
                ActivityTransition.Builder()
                    .setActivityType(DetectedActivity.ON_BICYCLE)
                    .setActivityTransition(ActivityTransition.ACTIVITY_TRANSITION_ENTER)
                    .build()
            )
            transitions.add(
                ActivityTransition.Builder()
                    .setActivityType(DetectedActivity.ON_BICYCLE)
                    .setActivityTransition(ActivityTransition.ACTIVITY_TRANSITION_EXIT)
                    .build()
            )

            val request = ActivityTransitionRequest(transitions)
            val pendingIntent = getActivityPendingIntent()

            ActivityRecognition.getClient(this)
                .requestActivityTransitionUpdates(request, pendingIntent)
                .addOnSuccessListener {
                    Log.i(TAG, "Successfully subscribed to Activity Transition updates")
                    ActivityTransitionReceiver.getPrefs(this).edit()
                        .putBoolean(ActivityTransitionReceiver.KEY_TRACKING_ENABLED, true)
                        .apply()
                    result.success(true)
                }
                .addOnFailureListener { error ->
                    Log.e(TAG, "Failed to subscribe to Activity Transition updates: ${error.message}", error)
                    result.error("SUBSCRIPTION_FAILED", error.message, null)
                }
        } catch (e: Exception) {
            Log.e(TAG, "Exception starting activity transition updates: ${e.message}", e)
            result.error("EXCEPTION", e.message, null)
        }
    }

    private fun stopActivityTransitionTracking(result: MethodChannel.Result) {
        try {
            val pendingIntent = getActivityPendingIntent()
            ActivityRecognition.getClient(this)
                .removeActivityTransitionUpdates(pendingIntent)
                .addOnSuccessListener {
                    Log.i(TAG, "Successfully removed Activity Transition updates")
                    ActivityTransitionReceiver.getPrefs(this).edit()
                        .putBoolean(ActivityTransitionReceiver.KEY_TRACKING_ENABLED, false)
                        .apply()
                    result.success(true)
                }
                .addOnFailureListener { error ->
                    Log.e(TAG, "Failed to remove Activity Transition updates: ${error.message}", error)
                    result.error("REMOVE_FAILED", error.message, null)
                }
        } catch (e: Exception) {
            Log.e(TAG, "Exception stopping activity transition updates: ${e.message}", e)
            result.error("EXCEPTION", e.message, null)
        }
    }

    private fun getPendingDetectedActivity(result: MethodChannel.Result) {
        val pending = ActivityTransitionReceiver.getPendingActivity(this)
        result.success(pending)
    }

    private fun clearPendingDetectedActivity(result: MethodChannel.Result) {
        ActivityTransitionReceiver.clearPendingActivity(this)
        result.success(true)
    }

    private fun simulateDetectedActivity(
        type: String,
        durationMins: Int,
        distanceKm: Double?,
        result: MethodChannel.Result
    ) {
        val now = System.currentTimeMillis()
        val durationSeconds = durationMins * 60
        val startTime = now - (durationSeconds * 1000L)
        val endTime = now

        val hours = durationMins / 60.0
        val dist = distanceKm ?: when (type.lowercase()) {
            "running" -> hours * 8.5
            "walking" -> hours * 4.8
            "cycling" -> hours * 18.0
            else -> hours * 5.5
        }

        val calories = when (type.lowercase()) {
            "running" -> (9.8 * 75.0 * hours).toInt()
            "walking" -> (3.8 * 75.0 * hours).toInt()
            "cycling" -> (7.5 * 75.0 * hours).toInt()
            else -> (6.0 * 75.0 * hours).toInt()
        }

        val steps = when (type.lowercase()) {
            "running" -> durationMins * 155
            "walking" -> durationMins * 110
            "cycling" -> 0
            else -> durationMins * 125
        }

        ActivityTransitionReceiver.saveDetectedActivity(
            context = this,
            type = type,
            startTimeMillis = startTime,
            endTimeMillis = endTime,
            durationSeconds = durationSeconds,
            distanceKm = dist,
            calories = calories,
            steps = steps
        )

        val map = hashMapOf(
            "type" to type,
            "startTimeMillis" to startTime,
            "endTimeMillis" to endTime,
            "durationMinutes" to durationMins,
            "durationSeconds" to durationSeconds,
            "distanceKm" to dist,
            "calories" to calories,
            "steps" to steps,
            "isLogged" to false
        )
        result.success(map)
    }
}
