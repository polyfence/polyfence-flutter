package com.polyfence.polyfence.core

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import java.util.Calendar

/**
 * Manages scheduled tracking based on time windows
 * Automatically starts/stops LocationTracker at configured times
 */
class TrackingScheduler(private val context: Context) {

    companion object {
        private const val TAG = "TrackingScheduler"
        private const val PREFS_NAME = "polyfence_schedule"
        private const val KEY_SCHEDULE_ENABLED = "schedule_enabled"
        private const val KEY_TIME_WINDOWS = "time_windows"
        private const val KEY_START_IMMEDIATELY = "start_immediately_if_in_window"

        const val ACTION_SCHEDULE_START = "com.polyfence.SCHEDULE_START"
        const val ACTION_SCHEDULE_STOP = "com.polyfence.SCHEDULE_STOP"

        private const val REQUEST_CODE_START = 1001
        private const val REQUEST_CODE_STOP = 1002
    }

    private val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    private val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

    /**
     * Data class representing a time of day
     */
    data class TimeOfDay(val hour: Int, val minute: Int) {
        fun toMinutesFromMidnight(): Int = hour * 60 + minute

        companion object {
            fun fromMap(map: Map<String, Any>?): TimeOfDay? {
                if (map == null) return null
                val hour = (map["hour"] as? Number)?.toInt() ?: return null
                val minute = (map["minute"] as? Number)?.toInt() ?: return null
                return TimeOfDay(hour, minute)
            }
        }
    }

    /**
     * Data class representing a time window when tracking should be active
     */
    data class TimeWindow(
        val startTime: TimeOfDay,
        val endTime: TimeOfDay,
        val daysOfWeek: List<Int> = emptyList() // 1=Monday, 7=Sunday, empty=all days
    ) {
        companion object {
            fun fromMap(map: Map<String, Any>): TimeWindow? {
                val startTime = TimeOfDay.fromMap(map["startTime"] as? Map<String, Any>) ?: return null
                val endTime = TimeOfDay.fromMap(map["endTime"] as? Map<String, Any>) ?: return null
                val daysOfWeek = (map["daysOfWeek"] as? List<*>)?.mapNotNull { (it as? Number)?.toInt() } ?: emptyList()
                return TimeWindow(startTime, endTime, daysOfWeek)
            }
        }
    }

    /**
     * Schedule settings configuration
     */
    data class ScheduleConfig(
        val enabled: Boolean = false,
        val timeWindows: List<TimeWindow> = emptyList(),
        val startImmediatelyIfInWindow: Boolean = true
    ) {
        companion object {
            fun fromMap(map: Map<String, Any>?): ScheduleConfig {
                if (map == null) return ScheduleConfig()

                val enabled = map["enabled"] as? Boolean ?: false
                val startImmediately = map["startImmediatelyIfInWindow"] as? Boolean ?: true
                val windowsList = (map["timeWindows"] as? List<*>)?.mapNotNull { windowMap ->
                    TimeWindow.fromMap(windowMap as? Map<String, Any> ?: return@mapNotNull null)
                } ?: emptyList()

                return ScheduleConfig(enabled, windowsList, startImmediately)
            }
        }
    }

    private var config = ScheduleConfig()

    /**
     * Update schedule configuration
     * @param configMap Configuration map from Flutter
     */
    fun updateConfig(configMap: Map<String, Any>?) {
        config = ScheduleConfig.fromMap(configMap)
        saveConfig()

        if (config.enabled) {
            Log.d(TAG, "Schedule enabled with ${config.timeWindows.size} time windows")

            // Check if we should start tracking now
            if (config.startImmediatelyIfInWindow && isCurrentlyInScheduledWindow()) {
                Log.d(TAG, "Currently in scheduled window - starting tracking")
                startTracking()
            } else if (!isCurrentlyInScheduledWindow()) {
                Log.d(TAG, "Not in scheduled window - stopping tracking")
                stopTracking()
            }

            // Schedule next alarm
            scheduleNextAlarm()
        } else {
            Log.d(TAG, "Schedule disabled - cancelling alarms")
            cancelAlarms()
        }
    }

    /**
     * Check if current time is within any scheduled window
     */
    fun isCurrentlyInScheduledWindow(): Boolean {
        if (!config.enabled || config.timeWindows.isEmpty()) {
            return true // No schedule = always active
        }

        val now = Calendar.getInstance()
        val currentMinutes = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
        val currentDayOfWeek = getDayOfWeekIso(now) // 1=Monday, 7=Sunday

        for (window in config.timeWindows) {
            // Check if today is an allowed day
            if (window.daysOfWeek.isNotEmpty() && currentDayOfWeek !in window.daysOfWeek) {
                continue
            }

            val startMinutes = window.startTime.toMinutesFromMidnight()
            val endMinutes = window.endTime.toMinutesFromMidnight()

            // Handle windows that span midnight
            val isInWindow = if (endMinutes > startMinutes) {
                // Normal window (e.g., 09:00 - 17:00)
                currentMinutes in startMinutes until endMinutes
            } else {
                // Window spans midnight (e.g., 22:00 - 06:00)
                currentMinutes >= startMinutes || currentMinutes < endMinutes
            }

            if (isInWindow) {
                return true
            }
        }

        return false
    }

    /**
     * Get the next schedule event (start or stop) time
     * Returns pair of (timestamp in millis, isStartEvent)
     */
    fun getNextScheduleEvent(): Pair<Long, Boolean>? {
        if (!config.enabled || config.timeWindows.isEmpty()) {
            return null
        }

        val now = Calendar.getInstance()
        val inWindow = isCurrentlyInScheduledWindow()

        var nextEventTime: Long = Long.MAX_VALUE
        var isStartEvent = !inWindow // If in window, next event is stop; if out, next is start

        for (window in config.timeWindows) {
            // Find next start time
            val nextStart = getNextOccurrence(window.startTime, window.daysOfWeek, now)
            // Find next end time
            val nextEnd = getNextOccurrence(window.endTime, window.daysOfWeek, now)

            if (inWindow && nextEnd < nextEventTime) {
                nextEventTime = nextEnd
                isStartEvent = false
            }

            if (!inWindow && nextStart < nextEventTime) {
                nextEventTime = nextStart
                isStartEvent = true
            }
        }

        return if (nextEventTime == Long.MAX_VALUE) null else Pair(nextEventTime, isStartEvent)
    }

    /**
     * Schedule the next alarm for start/stop
     */
    private fun scheduleNextAlarm() {
        cancelAlarms()

        val nextEvent = getNextScheduleEvent() ?: return
        val (nextTime, isStart) = nextEvent

        val action = if (isStart) ACTION_SCHEDULE_START else ACTION_SCHEDULE_STOP
        val requestCode = if (isStart) REQUEST_CODE_START else REQUEST_CODE_STOP

        val intent = Intent(context, ScheduleReceiver::class.java).apply {
            this.action = action
        }

        val pendingIntent = PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Use setExactAndAllowWhileIdle for reliable delivery
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, nextTime, pendingIntent)
        } else {
            alarmManager.setExact(AlarmManager.RTC_WAKEUP, nextTime, pendingIntent)
        }

        val eventType = if (isStart) "START" else "STOP"
        val nextCal = Calendar.getInstance().apply { timeInMillis = nextTime }
        Log.d(TAG, "Scheduled $eventType alarm for ${nextCal.time}")
    }

    /**
     * Cancel all scheduled alarms
     */
    private fun cancelAlarms() {
        listOf(REQUEST_CODE_START, REQUEST_CODE_STOP).forEach { requestCode ->
            val action = if (requestCode == REQUEST_CODE_START) ACTION_SCHEDULE_START else ACTION_SCHEDULE_STOP
            val intent = Intent(context, ScheduleReceiver::class.java).apply {
                this.action = action
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                requestCode,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            alarmManager.cancel(pendingIntent)
        }
        Log.d(TAG, "Cancelled all schedule alarms")
    }

    /**
     * Get next occurrence of a time on allowed days
     */
    private fun getNextOccurrence(time: TimeOfDay, daysOfWeek: List<Int>, from: Calendar): Long {
        val cal = from.clone() as Calendar
        cal.set(Calendar.HOUR_OF_DAY, time.hour)
        cal.set(Calendar.MINUTE, time.minute)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)

        // If time has already passed today, start checking from tomorrow
        if (cal.timeInMillis <= from.timeInMillis) {
            cal.add(Calendar.DAY_OF_YEAR, 1)
        }

        // If no specific days, return the calculated time
        if (daysOfWeek.isEmpty()) {
            return cal.timeInMillis
        }

        // Find next matching day
        for (i in 0 until 7) {
            val dayOfWeek = getDayOfWeekIso(cal)
            if (dayOfWeek in daysOfWeek) {
                return cal.timeInMillis
            }
            cal.add(Calendar.DAY_OF_YEAR, 1)
        }

        return cal.timeInMillis
    }

    /**
     * Convert Calendar day of week to ISO format (1=Monday, 7=Sunday)
     */
    private fun getDayOfWeekIso(cal: Calendar): Int {
        val calDay = cal.get(Calendar.DAY_OF_WEEK)
        return when (calDay) {
            Calendar.MONDAY -> 1
            Calendar.TUESDAY -> 2
            Calendar.WEDNESDAY -> 3
            Calendar.THURSDAY -> 4
            Calendar.FRIDAY -> 5
            Calendar.SATURDAY -> 6
            Calendar.SUNDAY -> 7
            else -> 1
        }
    }

    /**
     * Start tracking via LocationTracker service
     */
    private fun startTracking() {
        val intent = Intent(context, LocationTracker::class.java).apply {
            action = LocationTracker.ACTION_START_TRACKING
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(intent)
        } else {
            context.startService(intent)
        }
    }

    /**
     * Stop tracking via LocationTracker service
     */
    private fun stopTracking() {
        val intent = Intent(context, LocationTracker::class.java).apply {
            action = LocationTracker.ACTION_STOP_TRACKING
        }
        context.startService(intent)
    }

    /**
     * Handle schedule alarm fired
     */
    fun handleAlarm(isStart: Boolean) {
        if (isStart) {
            Log.d(TAG, "Schedule START alarm fired - starting tracking")
            startTracking()
        } else {
            Log.d(TAG, "Schedule STOP alarm fired - stopping tracking")
            stopTracking()
        }

        // Schedule the next alarm
        scheduleNextAlarm()
    }

    /**
     * Save configuration to SharedPreferences
     */
    private fun saveConfig() {
        prefs.edit().apply {
            putBoolean(KEY_SCHEDULE_ENABLED, config.enabled)
            putBoolean(KEY_START_IMMEDIATELY, config.startImmediatelyIfInWindow)
            // Time windows serialized as JSON string for simplicity
            val windowsJson = config.timeWindows.joinToString(";") { window ->
                "${window.startTime.hour},${window.startTime.minute}|${window.endTime.hour},${window.endTime.minute}|${window.daysOfWeek.joinToString(",")}"
            }
            putString(KEY_TIME_WINDOWS, windowsJson)
            apply()
        }
    }

    /**
     * Load configuration from SharedPreferences
     */
    fun loadConfig() {
        val enabled = prefs.getBoolean(KEY_SCHEDULE_ENABLED, false)
        val startImmediately = prefs.getBoolean(KEY_START_IMMEDIATELY, true)
        val windowsJson = prefs.getString(KEY_TIME_WINDOWS, "") ?: ""

        val timeWindows = if (windowsJson.isNotEmpty()) {
            windowsJson.split(";").mapNotNull { windowStr ->
                try {
                    val parts = windowStr.split("|")
                    if (parts.size < 2) return@mapNotNull null

                    val startParts = parts[0].split(",")
                    val endParts = parts[1].split(",")
                    val days = if (parts.size > 2 && parts[2].isNotEmpty()) {
                        parts[2].split(",").mapNotNull { it.toIntOrNull() }
                    } else emptyList()

                    TimeWindow(
                        TimeOfDay(startParts[0].toInt(), startParts[1].toInt()),
                        TimeOfDay(endParts[0].toInt(), endParts[1].toInt()),
                        days
                    )
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to parse time window: $windowStr", e)
                    null
                }
            }
        } else emptyList()

        config = ScheduleConfig(enabled, timeWindows, startImmediately)

        if (config.enabled) {
            Log.d(TAG, "Loaded schedule config with ${config.timeWindows.size} windows")
            scheduleNextAlarm()
        }
    }

    /**
     * Check if scheduling is enabled
     */
    fun isEnabled(): Boolean = config.enabled
}

/**
 * BroadcastReceiver for schedule alarms
 */
class ScheduleReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val scheduler = TrackingScheduler(context)

        when (intent.action) {
            TrackingScheduler.ACTION_SCHEDULE_START -> {
                scheduler.handleAlarm(isStart = true)
            }
            TrackingScheduler.ACTION_SCHEDULE_STOP -> {
                scheduler.handleAlarm(isStart = false)
            }
            Intent.ACTION_BOOT_COMPLETED -> {
                // Restore schedule after device reboot
                scheduler.loadConfig()
            }
        }
    }
}
