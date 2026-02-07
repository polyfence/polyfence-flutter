package com.polyfence.polyfence.core

import android.Manifest
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.content.ContextCompat
import com.google.android.gms.location.ActivityRecognition
import com.google.android.gms.location.ActivityRecognitionClient
import com.google.android.gms.location.ActivityRecognitionResult
import com.google.android.gms.location.DetectedActivity
import com.polyfence.polyfence.configuration.ActivitySettings
import com.polyfence.polyfence.configuration.ActivityType

/**
 * Manages activity recognition using Google Play Services
 * Detects user activity (still, walking, running, cycling, driving)
 * and notifies listeners when activity changes
 */
class ActivityRecognitionManager(private val context: Context) {

    companion object {
        private const val TAG = "ActivityRecognition"
        private const val ACTION_ACTIVITY_UPDATE = "com.polyfence.ACTIVITY_UPDATE"
        private const val DETECTION_INTERVAL_MS = 10_000L // 10 seconds
    }

    // Activity recognition client
    private var activityRecognitionClient: ActivityRecognitionClient? = null
    private var pendingIntent: PendingIntent? = null
    private var activityReceiver: ActivityReceiver? = null

    // Current state
    private var currentActivity: ActivityType = ActivityType.UNKNOWN
    private var currentConfidence: Int = 0
    private var isEnabled: Boolean = false
    private var settings: ActivitySettings = ActivitySettings()

    // Debounce handling
    private val handler = Handler(Looper.getMainLooper())
    private var pendingActivityChange: ActivityType? = null
    private var debounceRunnable: Runnable? = null

    // Callback for activity changes
    private var onActivityChanged: ((ActivityType, Int) -> Unit)? = null

    /**
     * Start activity recognition
     */
    fun start(activitySettings: ActivitySettings, callback: (ActivityType, Int) -> Unit) {
        if (!activitySettings.enabled) {
            Log.d(TAG, "Activity recognition disabled in settings")
            return
        }

        if (!hasPermission()) {
            Log.w(TAG, "Activity recognition permission not granted")
            return
        }

        if (!isPlayServicesAvailable()) {
            Log.w(TAG, "Google Play Services not available")
            return
        }

        settings = activitySettings
        onActivityChanged = callback
        isEnabled = true

        try {
            activityRecognitionClient = ActivityRecognition.getClient(context)

            // Create PendingIntent for activity updates
            val intent = Intent(ACTION_ACTIVITY_UPDATE).apply {
                setPackage(context.packageName)
            }

            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }

            pendingIntent = PendingIntent.getBroadcast(context, 0, intent, flags)

            // Register broadcast receiver
            activityReceiver = ActivityReceiver()
            val filter = IntentFilter(ACTION_ACTIVITY_UPDATE)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                context.registerReceiver(activityReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                context.registerReceiver(activityReceiver, filter)
            }

            // Request activity updates
            activityRecognitionClient?.requestActivityUpdates(
                DETECTION_INTERVAL_MS,
                pendingIntent!!
            )?.addOnSuccessListener {
                Log.i(TAG, "Activity recognition started")
            }?.addOnFailureListener { e ->
                Log.e(TAG, "Failed to start activity recognition: ${e.message}")
            }

        } catch (e: Exception) {
            Log.e(TAG, "Error starting activity recognition: ${e.message}")
        }
    }

    /**
     * Stop activity recognition
     */
    fun stop() {
        if (!isEnabled) return

        try {
            // Cancel pending debounce
            debounceRunnable?.let { handler.removeCallbacks(it) }
            debounceRunnable = null
            pendingActivityChange = null

            // Remove activity updates
            pendingIntent?.let { pi ->
                activityRecognitionClient?.removeActivityUpdates(pi)
                    ?.addOnSuccessListener {
                        Log.i(TAG, "Activity recognition stopped")
                    }
            }

            // Unregister receiver
            activityReceiver?.let {
                try {
                    context.unregisterReceiver(it)
                } catch (e: Exception) {
                    // Already unregistered
                }
            }

            activityReceiver = null
            pendingIntent = null
            isEnabled = false
            currentActivity = ActivityType.UNKNOWN
            currentConfidence = 0

        } catch (e: Exception) {
            Log.e(TAG, "Error stopping activity recognition: ${e.message}")
        }
    }

    /**
     * Update settings
     */
    fun updateSettings(activitySettings: ActivitySettings) {
        val wasEnabled = settings.enabled
        settings = activitySettings

        if (!wasEnabled && activitySettings.enabled) {
            // Was disabled, now enabled - start
            onActivityChanged?.let { start(activitySettings, it) }
        } else if (wasEnabled && !activitySettings.enabled) {
            // Was enabled, now disabled - stop
            stop()
        }
    }

    /**
     * Get current detected activity
     */
    fun getCurrentActivity(): ActivityType = currentActivity

    /**
     * Get current activity confidence
     */
    fun getCurrentConfidence(): Int = currentConfidence

    /**
     * Check if activity recognition is running
     */
    fun isRunning(): Boolean = isEnabled

    /**
     * Check if activity recognition permission is granted
     */
    fun hasPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.ACTIVITY_RECOGNITION
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            // Permission not required before Android 10
            true
        }
    }

    /**
     * Check if Google Play Services is available
     */
    private fun isPlayServicesAvailable(): Boolean {
        return try {
            val availability = com.google.android.gms.common.GoogleApiAvailability.getInstance()
            val result = availability.isGooglePlayServicesAvailable(context)
            result == com.google.android.gms.common.ConnectionResult.SUCCESS
        } catch (e: Exception) {
            Log.w(TAG, "Error checking Play Services: ${e.message}")
            false
        }
    }

    /**
     * Handle activity result from broadcast
     */
    private fun handleActivityResult(result: ActivityRecognitionResult) {
        val mostProbable = result.mostProbableActivity
        val newActivity = mapToActivityType(mostProbable.type)
        val confidence = mostProbable.confidence

        Log.d(TAG, "Detected: $newActivity (confidence: $confidence%)")

        // Check confidence threshold
        if (confidence < settings.confidenceThreshold) {
            Log.d(TAG, "Confidence below threshold (${settings.confidenceThreshold}%), ignoring")
            return
        }

        // Check if activity changed
        if (newActivity != currentActivity) {
            // Apply debounce
            applyDebounce(newActivity, confidence)
        }
    }

    /**
     * Apply debounce before confirming activity change
     */
    private fun applyDebounce(newActivity: ActivityType, confidence: Int) {
        // Cancel any pending change
        debounceRunnable?.let { handler.removeCallbacks(it) }

        // If same as pending, reset timer
        if (newActivity == pendingActivityChange) {
            Log.d(TAG, "Same activity pending, resetting debounce timer")
        }

        pendingActivityChange = newActivity

        debounceRunnable = Runnable {
            if (pendingActivityChange == newActivity) {
                Log.i(TAG, "Activity confirmed after debounce: $newActivity")
                currentActivity = newActivity
                currentConfidence = confidence
                onActivityChanged?.invoke(newActivity, confidence)
            }
            pendingActivityChange = null
            debounceRunnable = null
        }

        handler.postDelayed(debounceRunnable!!, settings.debounceSeconds * 1000L)
        Log.d(TAG, "Debounce started: ${settings.debounceSeconds}s for $newActivity")
    }

    /**
     * Map DetectedActivity type to our ActivityType enum
     */
    private fun mapToActivityType(type: Int): ActivityType {
        return when (type) {
            DetectedActivity.STILL -> ActivityType.STILL
            DetectedActivity.WALKING -> ActivityType.WALKING
            DetectedActivity.RUNNING -> ActivityType.RUNNING
            DetectedActivity.ON_BICYCLE -> ActivityType.CYCLING
            DetectedActivity.IN_VEHICLE -> ActivityType.DRIVING
            DetectedActivity.ON_FOOT -> ActivityType.WALKING // Treat on_foot as walking
            else -> ActivityType.UNKNOWN
        }
    }

    /**
     * Broadcast receiver for activity updates
     */
    inner class ActivityReceiver : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action == ACTION_ACTIVITY_UPDATE) {
                if (ActivityRecognitionResult.hasResult(intent)) {
                    val result = ActivityRecognitionResult.extractResult(intent)
                    if (result != null) {
                        handleActivityResult(result)
                    }
                }
            }
        }
    }
}
