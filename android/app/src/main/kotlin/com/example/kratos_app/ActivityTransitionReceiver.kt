package com.example.kratos_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.android.gms.location.ActivityTransition
import com.google.android.gms.location.ActivityTransitionResult
import com.google.android.gms.location.DetectedActivity

class ActivityTransitionReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "SomaActivityReceiver"
        const val PREFS_NAME = "soma_activity_prefs"
        const val CHANNEL_ID = "soma_activity_channel"
        const val NOTIFICATION_ID = 2001
        const val NOTIFICATION_REQUEST_CODE = 2002

        // Pref Keys
        const val KEY_ACTIVE_SESSION_TYPE = "active_session_type"
        const val KEY_ACTIVE_SESSION_START = "active_session_start"
        const val KEY_TRACKING_ENABLED = "activity_transition_tracking_enabled"

        // Pending Unlogged Activity Keys
        const val KEY_PENDING_HAS_ACTIVITY = "pending_has_activity"
        const val KEY_PENDING_TYPE = "pending_type"
        const val KEY_PENDING_START_TIME = "pending_start_time"
        const val KEY_PENDING_END_TIME = "pending_end_time"
        const val KEY_PENDING_DURATION_MINS = "pending_duration_mins"
        const val KEY_PENDING_DURATION_SECS = "pending_duration_secs"
        const val KEY_PENDING_DISTANCE_KM = "pending_distance_km"
        const val KEY_PENDING_CALORIES = "pending_calories"
        const val KEY_PENDING_STEPS = "pending_steps"
        const val KEY_PENDING_LOGGED = "pending_logged"

        fun getPrefs(context: Context): SharedPreferences {
            return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        }

        fun saveDetectedActivity(
            context: Context,
            type: String,
            startTimeMillis: Long,
            endTimeMillis: Long,
            durationSeconds: Int,
            distanceKm: Double,
            calories: Int,
            steps: Int
        ) {
            val durationMins = Math.max(1, (durationSeconds / 60))
            val prefs = getPrefs(context)
            prefs.edit()
                .putBoolean(KEY_PENDING_HAS_ACTIVITY, true)
                .putString(KEY_PENDING_TYPE, type)
                .putLong(KEY_PENDING_START_TIME, startTimeMillis)
                .putLong(KEY_PENDING_END_TIME, endTimeMillis)
                .putInt(KEY_PENDING_DURATION_MINS, durationMins)
                .putInt(KEY_PENDING_DURATION_SECS, durationSeconds)
                .putFloat(KEY_PENDING_DISTANCE_KM, distanceKm.toFloat())
                .putInt(KEY_PENDING_CALORIES, calories)
                .putInt(KEY_PENDING_STEPS, steps)
                .putBoolean(KEY_PENDING_LOGGED, false)
                .apply()

            Log.i(TAG, "Saved detected activity: $type for $durationMins mins (~$distanceKm km)")
            showActivityNotification(context, type, durationMins, distanceKm, calories, steps, startTimeMillis, endTimeMillis)
        }

        fun getPendingActivity(context: Context): Map<String, Any>? {
            val prefs = getPrefs(context)
            val hasActivity = prefs.getBoolean(KEY_PENDING_HAS_ACTIVITY, false)
            val isLogged = prefs.getBoolean(KEY_PENDING_LOGGED, false)

            if (!hasActivity || isLogged) {
                return null
            }

            return mapOf(
                "type" to (prefs.getString(KEY_PENDING_TYPE, "running") ?: "running"),
                "startTimeMillis" to prefs.getLong(KEY_PENDING_START_TIME, 0L),
                "endTimeMillis" to prefs.getLong(KEY_PENDING_END_TIME, 0L),
                "durationMinutes" to prefs.getInt(KEY_PENDING_DURATION_MINS, 0),
                "durationSeconds" to prefs.getInt(KEY_PENDING_DURATION_SECS, 0),
                "distanceKm" to prefs.getFloat(KEY_PENDING_DISTANCE_KM, 0.0f).toDouble(),
                "calories" to prefs.getInt(KEY_PENDING_CALORIES, 0),
                "steps" to prefs.getInt(KEY_PENDING_STEPS, 0),
                "isLogged" to false
            )
        }

        fun clearPendingActivity(context: Context) {
            val prefs = getPrefs(context)
            prefs.edit()
                .putBoolean(KEY_PENDING_HAS_ACTIVITY, false)
                .putBoolean(KEY_PENDING_LOGGED, true)
                .apply()
            Log.i(TAG, "Cleared pending detected activity")
        }

        fun showActivityNotification(
            context: Context,
            type: String,
            durationMins: Int,
            distanceKm: Double,
            calories: Int,
            steps: Int,
            startTimeMillis: Long,
            endTimeMillis: Long
        ) {
            try {
                val notificationManager =
                    context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    val channel = NotificationChannel(
                        CHANNEL_ID,
                        "Live Activity & Workout Detection",
                        NotificationManager.IMPORTANCE_HIGH
                    ).apply {
                        description = "Sensor-driven auto-detection for runs, walks, and workouts"
                        enableVibration(true)
                        setShowBadge(true)
                    }
                    notificationManager.createNotificationChannel(channel)
                }

                val intent = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
                    putExtra("action", "ACTION_VIEW_DETECTED_ACTIVITY")
                    putExtra("activity_type", type)
                    putExtra("duration_minutes", durationMins)
                    putExtra("distance_km", distanceKm)
                    putExtra("calories", calories)
                    putExtra("steps", steps)
                    putExtra("start_time", startTimeMillis)
                    putExtra("end_time", endTimeMillis)
                }

                val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
                } else {
                    PendingIntent.FLAG_UPDATE_CURRENT
                }

                val pendingIntent = PendingIntent.getActivity(
                    context,
                    NOTIFICATION_REQUEST_CODE,
                    intent,
                    flags
                )

                val displayTitle = when (type.lowercase()) {
                    "running" -> "🏃 Running Session Detected!"
                    "walking" -> "🚶 Brisk Walk Detected!"
                    "cycling" -> "🚴 Cycling Session Detected!"
                    else -> "⚡ Active Session Detected!"
                }

                val distanceFormatted = String.format("%.2f", distanceKm)
                val summaryText = "$durationMins mins • ~$distanceFormatted km • ~$calories kcal"

                val notification = NotificationCompat.Builder(context, CHANNEL_ID)
                    .setSmallIcon(R.mipmap.ic_launcher)
                    .setContentTitle(displayTitle)
                    .setContentText("$summaryText. Tap to review & add to log.")
                    .setStyle(
                        NotificationCompat.BigTextStyle()
                            .bigText("We detected a $durationMins-minute $type session (~$distanceFormatted km, ~$calories kcal, ~$steps steps). Tap to review and confirm adding to your SOMA log.")
                    )
                    .setPriority(NotificationCompat.PRIORITY_HIGH)
                    .setAutoCancel(true)
                    .setContentIntent(pendingIntent)
                    .build()

                notificationManager.notify(NOTIFICATION_ID, notification)
                Log.i(TAG, "Successfully posted activity detection notification: $displayTitle")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to post activity notification: ${e.message}", e)
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent?) {
        if (intent == null) return

        if (!ActivityTransitionResult.hasResult(intent)) {
            Log.d(TAG, "Received intent with no ActivityTransitionResult")
            return
        }

        val result = ActivityTransitionResult.extractResult(intent) ?: return
        val prefs = getPrefs(context)

        for (event in result.transitionEvents) {
            val activityType = event.activityType
            val transitionType = event.transitionType
            val now = System.currentTimeMillis()

            Log.i(TAG, "Transition Event: activityType=$activityType, transitionType=$transitionType")

            if (transitionType == ActivityTransition.ACTIVITY_TRANSITION_ENTER) {
                // User started activity: record start time and activity type
                prefs.edit()
                    .putInt(KEY_ACTIVE_SESSION_TYPE, activityType)
                    .putLong(KEY_ACTIVE_SESSION_START, now)
                    .apply()
                Log.i(TAG, "Started tracking activity: $activityType at $now")
            } else if (transitionType == ActivityTransition.ACTIVITY_TRANSITION_EXIT) {
                // User stopped activity
                val activeType = prefs.getInt(KEY_ACTIVE_SESSION_TYPE, -1)
                val startTime = prefs.getLong(KEY_ACTIVE_SESSION_START, -1L)

                if (startTime != -1L && activeType == activityType) {
                    val durationMillis = now - startTime
                    val durationSeconds = (durationMillis / 1000).toInt()
                    val durationMins = durationSeconds / 60

                    // Clean up active session
                    prefs.edit()
                        .remove(KEY_ACTIVE_SESSION_TYPE)
                        .remove(KEY_ACTIVE_SESSION_START)
                        .apply()

                    // Minimum threshold: at least 60 seconds of activity to be considered
                    if (durationSeconds >= 60) {
                        val typeString = when (activityType) {
                            DetectedActivity.RUNNING -> "running"
                            DetectedActivity.WALKING -> "walking"
                            DetectedActivity.ON_BICYCLE -> "cycling"
                            else -> "workout"
                        }

                        // Estimations: default 75kg
                        val hours = durationSeconds / 3600.0
                        val (distanceKm, calories, steps) = when (activityType) {
                            DetectedActivity.RUNNING -> {
                                val dist = hours * 8.5
                                val cal = (9.8 * 75.0 * hours).toInt()
                                val st = (durationMins * 155)
                                Triple(dist, cal, st)
                            }
                            DetectedActivity.WALKING -> {
                                val dist = hours * 4.8
                                val cal = (3.8 * 75.0 * hours).toInt()
                                val st = (durationMins * 110)
                                Triple(dist, cal, st)
                            }
                            DetectedActivity.ON_BICYCLE -> {
                                val dist = hours * 18.0
                                val cal = (7.5 * 75.0 * hours).toInt()
                                val st = 0
                                Triple(dist, cal, st)
                            }
                            else -> {
                                val dist = hours * 5.0
                                val cal = (6.0 * 75.0 * hours).toInt()
                                val st = (durationMins * 120)
                                Triple(dist, cal, st)
                            }
                        }

                        saveDetectedActivity(
                            context = context,
                            type = typeString,
                            startTimeMillis = startTime,
                            endTimeMillis = now,
                            durationSeconds = durationSeconds,
                            distanceKm = distanceKm,
                            calories = calories,
                            steps = steps
                        )
                    } else {
                        Log.d(TAG, "Ignored brief activity burst ($durationSeconds s < 60s)")
                    }
                }
            }
        }
    }
}
