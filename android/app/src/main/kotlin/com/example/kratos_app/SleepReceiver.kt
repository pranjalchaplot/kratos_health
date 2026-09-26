package com.example.kratos_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.util.Log
import com.google.android.gms.location.SleepClassifyEvent
import com.google.android.gms.location.SleepSegmentEvent

class SleepReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "KratosSleepReceiver"
        const val PREFS_NAME = "kratos_sleep_prefs"
        const val KEY_LAST_START_TIME = "last_sleep_start_time"
        const val KEY_LAST_END_TIME = "last_sleep_end_time"
        const val KEY_LAST_DURATION_MINUTES = "last_sleep_duration_minutes"
        const val KEY_LAST_STATUS = "last_sleep_status"
        const val KEY_LAST_UPDATED_AT = "last_sleep_updated_at"
        const val KEY_TRACKING_ENABLED = "sleep_tracking_enabled"

        fun getPrefs(context: Context): SharedPreferences {
            return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        }

        fun saveSleepSegment(
            context: Context,
            startTimeMillis: Long,
            endTimeMillis: Long,
            durationMillis: Long,
            status: Int
        ) {
            val durationMinutes = (durationMillis / (1000 * 60)).toInt()
            val prefs = getPrefs(context)
            prefs.edit()
                .putLong(KEY_LAST_START_TIME, startTimeMillis)
                .putLong(KEY_LAST_END_TIME, endTimeMillis)
                .putInt(KEY_LAST_DURATION_MINUTES, durationMinutes)
                .putInt(KEY_LAST_STATUS, status)
                .putLong(KEY_LAST_UPDATED_AT, System.currentTimeMillis())
                .apply()

            Log.i(
                TAG,
                "Saved Sleep Segment: Start=$startTimeMillis, End=$endTimeMillis, Duration=$durationMinutes mins, Status=$status"
            )
        }
    }

    override fun onReceive(context: Context, intent: Intent?) {
        if (intent == null) return

        // 1. Process Segment Events (Actual detected sleep intervals)
        if (SleepSegmentEvent.hasEvents(intent)) {
            val segmentEvents = SleepSegmentEvent.extractEvents(intent)
            Log.d(TAG, "Received ${segmentEvents.size} sleep segment events")
            for (event in segmentEvents) {
                val start = event.startTimeMillis
                val end = event.endTimeMillis
                val duration = event.segmentDurationMillis
                val status = event.status

                // STATUS_SUCCESSFUL = 0, STATUS_MISSING_DATA = 1, STATUS_NOT_DETECTED = 2
                if (status == SleepSegmentEvent.STATUS_SUCCESSFUL) {
                    saveSleepSegment(context, start, end, duration, status)
                } else {
                    Log.w(TAG, "Sleep segment completed with non-success status: $status")
                }
            }
        }

        // 2. Process Classification Events (Live continuous confidence/stillness)
        if (SleepClassifyEvent.hasEvents(intent)) {
            val classifyEvents = SleepClassifyEvent.extractEvents(intent)
            for (event in classifyEvents) {
                Log.d(
                    TAG,
                    "SleepClassifyEvent: Confidence=${event.confidence}%, Motion=${event.motion}, Light=${event.light}"
                )
            }
        }
    }
}
