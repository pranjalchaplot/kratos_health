package com.example.kratos_app

import android.Manifest
import android.app.AppOpsManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Process
import android.provider.Settings
import android.util.Log
import androidx.core.content.ContextCompat
import com.google.android.gms.location.ActivityRecognition
import com.google.android.gms.location.SleepSegmentRequest
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.soma/sleep"
    private val TAG = "SomaMainActivity"
    private val SLEEP_REQUEST_CODE = 4210

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
}
