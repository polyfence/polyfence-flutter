package com.polyfence.polyfence.core

import android.Manifest
import android.app.*
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.IBinder
import android.os.Looper
import android.os.BatteryManager
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.google.android.gms.location.*
import com.polyfence.polyfence.flutter.PolyfencePlugin
import com.polyfence.polyfence.utils.PolyfenceConfig
import com.polyfence.polyfence.utils.PolyfenceErrorRecovery
import com.polyfence.polyfence.configuration.SmartGpsConfig
import com.polyfence.polyfence.configuration.SmartGpsConfigFactory
import com.polyfence.polyfence.configuration.DeviceOptimization
import com.polyfence.polyfence.configuration.ActivitySettings
import com.polyfence.polyfence.configuration.ActivityType
import com.polyfence.polyfence.core.GeofenceEngine.LatLng
import com.polyfence.polyfence.core.GeofenceEngine.ZoneType
import kotlin.math.*

/**
 * Simple GPS tracking service
 * Single responsibility: GPS updates → GeofenceEngine → Notifications
 */
class LocationTracker : Service() {
    
    companion object {
        private const val TAG = "LocationTracker"
        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_ID = "polyfence_tracking"
        private const val GEOFENCE_CHANNEL_ID = "polyfence_alerts"
        
        const val ACTION_START_TRACKING = "START_TRACKING"
        const val ACTION_STOP_TRACKING = "STOP_TRACKING"
        const val ACTION_ADD_ZONE = "ADD_ZONE"
        const val ACTION_REMOVE_ZONE = "REMOVE_ZONE"
        const val ACTION_CLEAR_ZONES = "CLEAR_ZONES"
        const val ACTION_UPDATE_CONFIG = "UPDATE_CONFIG"
        
        var isRunning = false
            private set
            
        // Smart GPS Configuration
        private var currentSmartConfig: SmartGpsConfig = SmartGpsConfig()
        
        // Alert Notifications Control
        private var alertNotificationsEnabled = true

        // Tracking Scheduler for time-based tracking
        private var trackingScheduler: TrackingScheduler? = null

        // Current instance reference for accessing zone states
        private var currentInstance: LocationTracker? = null

        // Pending activity settings (stored until tracking starts)
        private var pendingActivitySettings: ActivitySettings? = null

        /**
         * Store activity settings to be applied when tracking starts
         */
        fun setPendingActivitySettings(settings: ActivitySettings) {
            pendingActivitySettings = settings
            Log.d(TAG, "Stored pending activity settings: enabled=${settings.enabled}")
            // If service is already running, apply immediately
            currentInstance?.updateActivityRecognition(settings)
        }

        /**
         * Get current zone states from the active service instance
         * Returns which zones the plugin believes the device is currently inside
         * @return Map of zoneId to isInside state, or empty map if service not running
         */
        fun getCurrentZoneStates(): Map<String, Boolean> {
            return currentInstance?.geofenceEngine?.getCurrentZoneStates() ?: emptyMap()
        }

        /**
         * Update smart GPS configuration
         */
        fun updateSmartConfiguration(config: SmartGpsConfig) {
            currentSmartConfig = config
            Log.d(TAG, "Updated smart GPS configuration: $config")
        }
        
        /**
         * Get current smart GPS configuration
         */
        fun getCurrentSmartConfiguration(): SmartGpsConfig {
            return currentSmartConfig
        }
        
        /**
         * Set whether alert notifications should be shown
         */
        fun setAlertNotificationsEnabled(enabled: Boolean) {
            alertNotificationsEnabled = enabled
            Log.d(TAG, "Alert notifications ${if (enabled) "enabled" else "disabled"}")
        }

        /**
         * Update schedule configuration for time-based tracking
         */
        fun setScheduleConfig(context: Context, scheduleSettings: Map<String, Any>?) {
            if (trackingScheduler == null) {
                trackingScheduler = TrackingScheduler(context)
            }
            trackingScheduler?.updateConfig(scheduleSettings)
            Log.d(TAG, "Schedule config updated")
        }

        /**
         * Check if currently within a scheduled tracking window
         */
        fun isInScheduledWindow(): Boolean {
            return trackingScheduler?.isCurrentlyInScheduledWindow() ?: true
        }

        /**
         * Check if scheduling is enabled
         */
        fun isScheduleEnabled(): Boolean {
            return trackingScheduler?.isEnabled() ?: false
        }
    }
    
    private var fusedLocationClient: FusedLocationProviderClient? = null
    private var locationCallback: LocationCallback? = null
    private val geofenceEngine = GeofenceEngine()
    private lateinit var zonePersistence: ZonePersistence
    private lateinit var config: PolyfenceConfig
    
    // Error Recovery Properties
    private lateinit var errorRecovery: PolyfenceErrorRecovery
    private var healthCheckHandler: android.os.Handler? = null
    private var pendingSmartConfigReapplyRunnable: Runnable? = null
    private var lastLocationTime: Long = 0L
    private var consecutiveGpsFailures: Int = 0

    // GPS Health Tracking
    private var currentGpsAccuracy: Float? = null
    private val gpsAvailabilityDropTimestamps = mutableListOf<Long>()
    private var lastGpsUnreliableErrorTime: Long = 0L
    private val GPS_UNRELIABLE_ERROR_COOLDOWN_MS = 60_000L // Emit error max once per minute
    
    // Wake Lock Management
    private var wakeLock: PowerManager.WakeLock? = null
    private var isWakeLockAcquired = false
    private var wakeLockAcquireTime: Long = 0L
    // P10: Wake lock duration now tied to accuracy profile (calculated dynamically)

    /**
     * P10: Get wake lock duration based on accuracy profile
     * More aggressive profiles get shorter wake locks to limit battery impact
     */
    private fun getWakeLockDuration(): Long = when (smartConfig.accuracyProfile) {
        SmartGpsConfig.AccuracyProfile.MAX_ACCURACY -> 12 * 60 * 60 * 1000L   // 12 hours - max tracking
        SmartGpsConfig.AccuracyProfile.BALANCED -> 8 * 60 * 60 * 1000L        // 8 hours - balanced
        SmartGpsConfig.AccuracyProfile.BATTERY_OPTIMAL -> 4 * 60 * 60 * 1000L // 4 hours - battery priority
        SmartGpsConfig.AccuracyProfile.ADAPTIVE -> 6 * 60 * 60 * 1000L        // 6 hours - adaptive
    }

    // Smart GPS Configuration
    private var smartConfig: SmartGpsConfig = SmartGpsConfig()
    private var currentGpsInterval: Long = 5000L
    private var isStationary: Boolean = false

    // Movement tracking for stationary detection (independent of movementSettings)
    private var lastMovementLocation: android.location.Location? = null
    private var lastMovementTime: Long = 0L

    // P9: Track last location where zone check was performed
    private var lastZoneCheckLocation: android.location.Location? = null
    private val MIN_MOVEMENT_FOR_ZONE_CHECK_METERS = 5.0f  // Only recheck zones if moved >5m
    private var lastKnownLocation: android.location.Location? = null
    
    // Runtime Status Emission
    private var lastEmittedStatus = mapOf<String, Any>()
    private var lastStatusEmitTime = 0L

    // P6: Consolidated health monitoring (replaces separate permission/GPS checks)
    // Combined health check runs every 60s instead of separate 30s GPS + 60s permission checks
    private var combinedHealthCheckHandler: android.os.Handler? = null
    private val combinedHealthCheckInterval = 60_000L  // 60 seconds (unified interval)

    // P11: Throttle Flutter callbacks when stationary
    private var lastFlutterCallbackTime = 0L
    private val stationaryFlutterCallbackInterval = 30_000L  // 30s when stationary (vs every update when moving)

    // Activity Recognition
    private var activityRecognitionManager: ActivityRecognitionManager? = null
    private var activitySettings: ActivitySettings = ActivitySettings()
    private var currentActivity: ActivityType = ActivityType.UNKNOWN

    override fun onCreate() {
        super.onCreate()

        // Set current instance for static access to zone states
        currentInstance = this

        // P5: Log device info for debugging battery issues on Samsung/etc
        DeviceOptimization.logDeviceInfo(TAG)

        // Initialize configuration
        config = PolyfenceConfig(this)
        config.validateAndCorrect()
        
        // Initialize persistence
        zonePersistence = ZonePersistence(this)
        
        // Initialize location client
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
        
        // Initialize error recovery
        errorRecovery = PolyfenceErrorRecovery(this)
        healthCheckHandler = android.os.Handler(Looper.getMainLooper())
        
        // Setup geofence engine callback
        geofenceEngine.setEventCallback { zoneId, eventType, location, detectionTimeMs ->
            handleGeofenceEvent(zoneId, eventType, location, detectionTimeMs)
        }

        // Wire up zone persistence for state recovery across service restarts
        geofenceEngine.setZonePersistence(zonePersistence)

        // Configure validation using config
        geofenceEngine.setValidationConfig(
            requireConfirmation = config.requireConfirmation,
            confirmationPoints = config.confidencePoints
        )
        
        // Set GPS accuracy threshold from config (default: 100m for platform parity)
        geofenceEngine.setGpsAccuracyThreshold(config.gpsAccuracyThreshold)
        
        // Setup location callback with recovery
        setupLocationCallbackWithRecovery()
        
        // Initialize smart GPS configuration
        initializeSmartConfiguration()

        createNotificationChannels()

        // Initialize tracking scheduler and restore saved config
        if (trackingScheduler == null) {
            trackingScheduler = TrackingScheduler(this)
        }
        trackingScheduler?.loadConfig()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START_TRACKING -> {
                if (!hasLocationPerms()) {
                    Log.w(TAG, "Missing runtime permissions for location/FGS; not starting tracking")
                    return START_NOT_STICKY // do not restart
                }
                startTracking()
            }
            ACTION_STOP_TRACKING -> stopTracking()
            ACTION_ADD_ZONE -> {
                // CRITICAL GUARD: Don't process zone operations if not tracking
                if (!isRunning) {
                    stopSelf()
                    return START_NOT_STICKY
                }
                addZone(intent)
            }
            ACTION_REMOVE_ZONE -> {
                // Allow zone removal even when tracking is stopped
                // This ensures persistence is updated regardless of service state
                removeZone(intent)
                // Stop service if it's not actively tracking
                if (!isRunning) {
                    stopSelf()
                    return START_NOT_STICKY
                }
            }
            ACTION_CLEAR_ZONES -> {
                // Allow clearing zones even when tracking is stopped
                // This ensures persistence is updated regardless of service state
                clearZones()
                // Stop service if it's not actively tracking
                if (!isRunning) {
                    stopSelf()
                    return START_NOT_STICKY
                }
            }
            ACTION_UPDATE_CONFIG -> {
                val configMap = intent.getSerializableExtra("config") as? Map<String, Any>
                if (configMap != null) {
                    updateConfigurationFromMap(configMap)
                }
            }
        }
        return START_STICKY
    }
    
    private fun hasLocationPerms(): Boolean {
        val fine = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        val coarse = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
        val bgOk = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_BACKGROUND_LOCATION) == PackageManager.PERMISSION_GRANTED
        } else true
        // API 34 (Android 14) requires FOREGROUND_SERVICE_LOCATION permission
        // Use SDK_INT >= 34 instead of UPSIDE_DOWN_CAKE constant (not available in older SDKs)
        val fgsOk = if (Build.VERSION.SDK_INT >= 34) {
            ContextCompat.checkSelfPermission(this, Manifest.permission.FOREGROUND_SERVICE_LOCATION) == PackageManager.PERMISSION_GRANTED
        } else true
        return (fine || coarse) && bgOk && fgsOk
    }
    
    // P4: Track if GPS start is deferred waiting for zones
    private var gpsStartDeferred = false

    private fun startTracking() {
        // Verify permissions before starting foreground service
        if (!hasLocationPerms()) {
            Log.e(TAG, "Cannot start foreground service - missing permissions")
            stopSelf()
            return
        }

        isRunning = true
        firstLocationAfterRestart = true  // Reset for state reconciliation
        startForeground(NOTIFICATION_ID, createTrackingNotification())

        // Acquire wake lock before starting location requests
        acquireWakeLock()

        // Restore zones from storage ONLY when tracking starts
        restoreZonesFromStorage()

        // P6: Start combined health monitoring (replaces separate GPS + permission checks)
        startCombinedHealthMonitoring()

        // Apply any pending activity settings that were set before tracking started
        pendingActivitySettings?.let { pending ->
            Log.d(TAG, "Applying pending activity settings: enabled=${pending.enabled}")
            activitySettings = pending
            pendingActivitySettings = null
        }

        // Ensure activity recognition is started if enabled but not running
        // Must be before the zones check since activity recognition is independent of zones
        if (activitySettings.enabled && activityRecognitionManager == null) {
            Log.d(TAG, "Starting activity recognition on tracking start")
            updateActivityRecognition(activitySettings)
        }

        // P4: Only start GPS if zones exist, otherwise defer
        if (!geofenceEngine.hasZones()) {
            Log.d(TAG, "P4: No zones registered - deferring GPS start until zones are added")
            gpsStartDeferred = true
            return
        }

        startGpsUpdates()
    }

    /**
     * P4: Start GPS location updates (extracted for deferred start)
     */
    private fun startGpsUpdates() {
        gpsStartDeferred = false

        // Use smart GPS configuration for location request
        val priority = smartConfig.getLocationPriority()
        val interval = calculateCurrentInterval()

        val locationRequest = LocationRequest.Builder(priority, interval)
            .setMinUpdateIntervalMillis(interval / 2)
            .setMaxUpdateDelayMillis(interval * 2)
            .setWaitForAccurateLocation(smartConfig.shouldWaitForAccurateLocation())
            .setMinUpdateDistanceMeters(smartConfig.getDistanceFilter())  // P1: Apply distance filter from profile
            .build()

        try {
            val callback = locationCallback ?: run {
                Log.e(TAG, "LocationCallback is null - cannot start location updates")
                return
            }
            fusedLocationClient?.requestLocationUpdates(
                locationRequest,
                callback,
                Looper.getMainLooper()
            )
            Log.d(TAG, "GPS updates started with profile: ${smartConfig.accuracyProfile}")
        } catch (e: SecurityException) {
            Log.e(TAG, "Location permission denied: ${e.message}")
            PolyfenceErrorManager.reportError(
                "permission_revoked",
                "Location permission was revoked - SecurityException during GPS start",
                mapOf("platform" to "android", "error" to (e.message ?: ""), "timestamp" to System.currentTimeMillis())
            )
            errorRecovery.handlePermissionLoss()
            stopSelf()
        }
    }

    private fun stopTracking() {
        
        isRunning = false
        locationCallback?.let { callback ->
            fusedLocationClient?.removeLocationUpdates(callback)
        }
        
        // Release wake lock before stopping
        releaseWakeLock()
        
        // Stop error monitoring
        errorRecovery.stopMonitoring()
        healthCheckHandler?.removeCallbacksAndMessages(null)

        // P6: Stop combined health monitoring
        stopCombinedHealthMonitoring()

        // Stop activity recognition
        activityRecognitionManager?.stop()

        stopForeground(true)
        stopSelf()
    }

    /**
     * P6: Combined health monitoring - consolidates GPS health + permission checks
     * Runs every 60 seconds instead of separate 30s GPS + 60s permission timers
     * Reduces timer overhead from 4 timers to 2 (this + wake lock check)
     */
    private fun startCombinedHealthMonitoring() {
        combinedHealthCheckHandler = android.os.Handler(Looper.getMainLooper())
        combinedHealthCheckHandler?.postDelayed(object : Runnable {
            override fun run() {
                if (!isRunning) return

                // === Permission Check (was separate 60s timer) ===
                if (!hasLocationPerms()) {
                    Log.w(TAG, "P6: Location permission revoked - stopping tracking gracefully")
                    PolyfenceErrorManager.reportError(
                        "permission_revoked",
                        "Location permission was revoked by user during tracking",
                        mapOf("platform" to "android", "timestamp" to System.currentTimeMillis())
                    )
                    stopTracking()
                    return
                }

                // === GPS Health Check (was separate 30s timer) ===
                val currentTime = System.currentTimeMillis()
                val timeSinceLastLocation = currentTime - lastLocationTime

                if (timeSinceLastLocation > 120_000L && lastLocationTime > 0) {
                    Log.w(TAG, "P6: GPS health check - no location for ${timeSinceLastLocation / 1000}s")

                    if (consecutiveGpsFailures in 3..5) {
                        Log.w(TAG, "P6: Triggering GPS recovery")
                        errorRecovery.handleGpsFailure()
                    }
                }

                // === System Health Snapshot (was separate 12min timer, now piggybacks) ===
                try {
                    val bm = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
                    val level = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY).toDouble()
                    val isCharging = bm.isCharging
                    val gpsActive = timeSinceLastLocation < 60_000

                    Log.d(TAG, "P6: Health - battery=${level}%, charging=$isCharging, gps=$gpsActive")
                } catch (e: Exception) {
                    Log.e(TAG, "P6: Health snapshot failed: ${e.message}")
                }

                // Schedule next combined check
                if (isRunning) {
                    combinedHealthCheckHandler?.postDelayed(this, combinedHealthCheckInterval)
                }
            }
        }, combinedHealthCheckInterval)

        Log.d(TAG, "P6: Combined health monitoring started - checking every ${combinedHealthCheckInterval / 1000}s")
    }

    /**
     * P6: Stop combined health monitoring
     */
    private fun stopCombinedHealthMonitoring() {
        combinedHealthCheckHandler?.removeCallbacksAndMessages(null)
        combinedHealthCheckHandler = null
        Log.d(TAG, "P6: Combined health monitoring stopped")
    }

    private fun addZone(intent: Intent) {
        val zoneId = intent.getStringExtra("zoneId") ?: return
        val zoneName = intent.getStringExtra("zoneName") ?: "Unknown Zone"
        val zoneData = intent.getSerializableExtra("zoneData") as? Map<String, Any> ?: return

        // Add to engine
        geofenceEngine.addZone(zoneId, zoneName, zoneData)

        // Save to persistent storage
        zonePersistence.saveZone(zoneId, zoneName, zoneData)

        // P4: Start GPS if it was deferred waiting for zones
        if (gpsStartDeferred && isRunning && geofenceEngine.hasZones()) {
            Log.d(TAG, "P4: First zone added - starting deferred GPS updates")
            startGpsUpdates()
        }
    }
    
    private fun removeZone(intent: Intent) {
        val zoneId = intent.getStringExtra("zoneId") ?: return
        
        // Remove from engine
        geofenceEngine.removeZone(zoneId)
        
        // Remove from persistent storage
        zonePersistence.removeZone(zoneId)
        
    }
    
    private fun clearZones() {
        // Clear from engine
        geofenceEngine.clearAllZones()
        
        // Clear from persistent storage
        zonePersistence.clearAllZones()
        
    }

    // Restore zones from storage on service start
    private fun restoreZonesFromStorage() {
        try {
            val savedZones = zonePersistence.loadAllZones()

            savedZones.forEach { (zoneId, zoneInfo) ->
                val (id, name, data) = zoneInfo
                geofenceEngine.addZone(id, name, data)
            }

            // Load persisted zone states AFTER zones are loaded
            // This restores the "inside/outside" state from before service restart
            geofenceEngine.loadPersistedZoneStates()

            Log.i(TAG, "Restored ${savedZones.size} zones from storage")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to restore zones: ${e.message}")
        }
    }

    // Track if first location after restart has been processed
    private var firstLocationAfterRestart = true
    
private fun handleGeofenceEvent(zoneId: String, eventType: String, location: android.location.Location, detectionTimeMs: Double) {
    // Get zone name from GeofenceEngine
    val zoneName = geofenceEngine.getZoneName(zoneId) ?: zoneId
    
    // Use the detection duration passed from GeofenceEngine (already in milliseconds)
    // This is the actual time it took to detect the geofence event, not GPS age
    
    // Get GPS accuracy
    val gpsAccuracy = if (location.hasAccuracy()) location.accuracy.toDouble() else 0.0

    // Send event to Flutter with detection metrics and GPS coordinates
    PolyfencePlugin.sendGeofenceEvent(
        zoneId = zoneId,
        zoneName = zoneName,
        eventType = eventType,
        latitude = location.latitude,
        longitude = location.longitude,
        detectionTimeMs = detectionTimeMs,
        gpsAccuracy = gpsAccuracy
    )
    
    // Terse geofence event log
    val displayName = if (zoneName.isNotEmpty()) zoneName else zoneId
    Log.i(TAG, "PF: EVENT $eventType zone=$displayName detection=${detectionTimeMs}ms ts=${System.currentTimeMillis()}")
    
    // Show notification with proper zone name
    showGeofenceNotification(eventType, zoneId, zoneName)
    
}
    
    private fun sendLocationToFlutter(location: android.location.Location) {
        val locationData = mapOf(
            "latitude" to location.latitude,
            "longitude" to location.longitude,
            "accuracy" to location.accuracy.toDouble(),
            "timestamp" to System.currentTimeMillis(),
            "speed" to (if (location.hasSpeed()) location.speed * 3.6 else 0.0), // Convert m/s to km/h
            "activity" to currentActivity.name.lowercase() // Include current activity type
        )
        PolyfencePlugin.sendLocationUpdate(locationData)
    }
    
    private fun showGeofenceNotification(eventType: String, zoneId: String, zoneName: String) {
    if (!isRunning) return
    if (!alertNotificationsEnabled) return  // Respect disableAlertNotifications config
    val title = if (eventType == "ENTER") "Entered Zone" else "Exited Zone"
    val message = zoneName // Use zone name instead of ID
    
    // Create PendingIntent to reuse existing app task when notification is tapped
    // Use dynamic package resolution instead of hardcoded class name
    val intent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
        flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
    } ?: Intent().apply {
        setPackage(packageName)
        flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
    }
    
    val pendingIntent = PendingIntent.getActivity(
        this,
        0,
        intent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )
    
    val notification = NotificationCompat.Builder(this, GEOFENCE_CHANNEL_ID)
        .setContentTitle(title)
        .setContentText(message)
        .setSmallIcon(android.R.drawable.ic_menu_mylocation)
        .setContentIntent(pendingIntent) // Opens app on tap
        .setAutoCancel(true) // Dismisses notification on tap
        .setPriority(NotificationCompat.PRIORITY_HIGH)
        .setDefaults(NotificationCompat.DEFAULT_ALL)
        .build()
    
    val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    notificationManager.notify(System.currentTimeMillis().toInt(), notification)
}
    
    private fun createTrackingNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Polyfence Active")
            .setContentText("Monitoring geofence zones")
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setOngoing(true)
            .setSilent(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }
    
    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            
            // Tracking channel (low priority)
            val trackingChannel = NotificationChannel(
                CHANNEL_ID,
                "Location Tracking",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Background location tracking"
                setSound(null, null)
            }
            
            // Geofence alerts (high priority)
            val alertChannel = NotificationChannel(
                GEOFENCE_CHANNEL_ID,
                "Geofence Alerts",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Zone entry and exit notifications"
                enableVibration(true)
                enableLights(true)
                // ADD THIS LINE - Missing sound configuration
                setSound(android.provider.Settings.System.DEFAULT_NOTIFICATION_URI, null)
                setVibrationPattern(longArrayOf(0, 500, 200, 500))
            }
            
            notificationManager.createNotificationChannel(trackingChannel)
            notificationManager.createNotificationChannel(alertChannel)
        }
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    override fun onDestroy() {
        super.onDestroy()
        isRunning = false
        currentInstance = null  // Clear instance reference
        errorRecovery.stopMonitoring()
        healthCheckHandler?.removeCallbacksAndMessages(null)
        // Stop activity recognition and unregister receiver
        activityRecognitionManager?.stop()
        activityRecognitionManager = null
        // Ensure wake lock is released
        releaseWakeLock()
    }
    
    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        
        Log.i(TAG, "App task removed - cleaning up wake lock and stopping tracking")
        
        // Release wake lock when user swipes app away or force-stops
        releaseWakeLock()
        
        // Stop tracking gracefully
        if (isRunning) {
            stopTracking()
        }
    }
    
    // Wake Lock Management Methods
    
    /**
     * Schedule health check to detect and release zombie wake locks
     * Checks if wake lock has exceeded maximum duration and force-releases if needed
     * Also handles auto-renewal if tracking continues beyond timeout
     */
    private fun scheduleWakeLockHealthCheck() {
        healthCheckHandler?.removeCallbacksAndMessages(null)
        
        // Check every hour, or when approaching timeout (whichever is sooner)
        val checkInterval = 60 * 60 * 1000L // 1 hour
        
        healthCheckHandler?.postDelayed({
            if (wakeLock?.isHeld == true && isWakeLockAcquired) {
                val wakeLockDuration = getWakeLockDuration()  // P10: Use profile-based duration
                val age = System.currentTimeMillis() - wakeLockAcquireTime
                val remainingTime = wakeLockDuration - age

                // If wake lock is approaching expiration (within 1 hour) and tracking is still active, renew it
                if (remainingTime < 60 * 60 * 1000L && isRunning) {
                    Log.i(TAG, "P10: Wake lock approaching timeout (${remainingTime / 1000 / 60}min remaining) - auto-renewing")

                    // Release old wake lock and re-acquire with profile-based timeout
                    releaseWakeLock()
                    acquireWakeLock()
                    return@postDelayed
                }

                // If wake lock exceeded timeout (shouldn't happen with Android's built-in timeout, but safety net)
                if (age > wakeLockDuration) {
                    Log.w(TAG, "P10: Wake lock exceeded ${wakeLockDuration / 1000 / 60 / 60}h timeout - force releasing")
                    
                    // Report error to Flutter layer
                    PolyfenceErrorManager.reportError(
                        "wake_lock_timeout",
                        "Wake lock held beyond timeout - released automatically",
                        mapOf(
                            "platform" to "android",
                            "duration_hours" to (age / 1000 / 60 / 60),
                            "timestamp" to System.currentTimeMillis()
                        )
                    )
                    
                    // Force release wake lock
                    releaseWakeLock()
                    
                    // If tracking is still active, re-acquire wake lock (auto-renewal)
                    if (isRunning) {
                        Log.i(TAG, "Re-acquiring wake lock for continued tracking")
                        acquireWakeLock()
                    }
                } else {
                    // Wake lock still valid - schedule next check
                    val nextCheckTime = remainingTime.coerceAtMost(checkInterval)
                    healthCheckHandler?.postDelayed({
                        scheduleWakeLockHealthCheck()
                    }, nextCheckTime)
                }
            }
        }, checkInterval)
    }
    
    private fun acquireWakeLock() {
        try {
            // Release any existing lock first (defensive)
            releaseWakeLock()
            
            if (wakeLock == null) {
                val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                wakeLock = powerManager.newWakeLock(
                    PowerManager.PARTIAL_WAKE_LOCK,
                    "Polyfence:LocationTracking"
                )
            }
            
            if (!isWakeLockAcquired) {
                // P10: Acquire wake lock with profile-based timeout for battery safety
                // More aggressive profiles get shorter wake locks
                val wakeLockDuration = getWakeLockDuration()
                wakeLock?.acquire(wakeLockDuration)
                isWakeLockAcquired = true
                wakeLockAcquireTime = System.currentTimeMillis()

                Log.i(TAG, "P10: Wake lock acquired with ${wakeLockDuration / 1000 / 60 / 60}h timeout (profile: ${smartConfig.accuracyProfile})")
                
                // Schedule health check to monitor wake lock age
                scheduleWakeLockHealthCheck()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to acquire wake lock: ${e.message}")
            // Wake lock failure is not critical - service can still run
        }
    }
    
    private fun releaseWakeLock() {
        try {
            if (isWakeLockAcquired) {
                val holdDuration = if (wakeLockAcquireTime > 0) {
                    System.currentTimeMillis() - wakeLockAcquireTime
                } else {
                    0L
                }
                
                wakeLock?.release()
                isWakeLockAcquired = false
                wakeLockAcquireTime = 0L
                
                // Cancel health check when wake lock is released
                healthCheckHandler?.removeCallbacksAndMessages(null)
                
                Log.i(TAG, "Wake lock released after ${holdDuration / 1000 / 60}min")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to release wake lock: ${e.message}")
        }
    }
    
    // Error Recovery Methods
    
    private fun setupLocationCallbackWithRecovery() {
    locationCallback = object : LocationCallback() {
        override fun onLocationResult(locationResult: LocationResult) {
            locationResult.lastLocation?.let { location ->
                // Guard clause: only process if tracking is active (iOS parity)
                if (!isRunning) {
                    return
                }

                // STATE RECOVERY: On first valid location after service restart,
                // reconcile persisted zone states with actual location.
                // This fires RECOVERY_ENTER/RECOVERY_EXIT for any mismatches.
                if (firstLocationAfterRestart) {
                    firstLocationAfterRestart = false
                    Log.i(TAG, "First location after restart - reconciling zone states")
                    geofenceEngine.reconcileZoneStates(location)
                }

                // Update movement state for smart GPS
                updateMovementState(location)

                // Log proximity debug info
                logProximityDebugInfo(location)

                // Update GPS health tracking
                lastLocationTime = System.currentTimeMillis()
                consecutiveGpsFailures = 0
                currentGpsAccuracy = if (location.hasAccuracy()) location.accuracy else null

                // Check for unreliable GPS (large accuracy swings, poor accuracy)
                checkGpsReliability(location)

                // Reset error recovery attempts on successful location
                errorRecovery.resetRestartAttempts()

                // P11: Throttle Flutter callbacks when stationary to reduce overhead
                val currentTime = System.currentTimeMillis()
                val timeSinceLastCallback = currentTime - lastFlutterCallbackTime
                val shouldSendToFlutter = if (isStationary) {
                    // When stationary, only send updates every 30s
                    timeSinceLastCallback >= stationaryFlutterCallbackInterval
                } else {
                    // When moving, send every update
                    true
                }

                if (shouldSendToFlutter) {
                    sendLocationToFlutter(location)
                    lastFlutterCallbackTime = currentTime
                }

                // P9: Only check geofences if moved significantly since last check
                val shouldCheckZones = lastZoneCheckLocation?.let { lastLoc ->
                    location.distanceTo(lastLoc) > MIN_MOVEMENT_FOR_ZONE_CHECK_METERS
                } ?: true  // Always check on first location

                if (shouldCheckZones) {
                    geofenceEngine.checkLocation(location)
                    lastZoneCheckLocation = location
                }
            }
        }
        
        override fun onLocationAvailability(locationAvailability: LocationAvailability) {
            if (!locationAvailability.isLocationAvailable) {
                Log.w(TAG, "Location availability lost")
                consecutiveGpsFailures++

                // Track GPS availability drop for health metrics
                val currentTime = System.currentTimeMillis()
                gpsAvailabilityDropTimestamps.add(currentTime)
                cleanupOldGpsDrops(currentTime)

                // Emit gpsUnreliable error if we've had multiple drops recently
                val drops5Min = getGpsAvailabilityDrops5Min()
                if (drops5Min >= 3) {
                    emitGpsUnreliableError(drops5Min)
                }
                
                // Trigger recovery for GPS failures (up to 5 consecutive failures)
                // After 5 failures, stop trying to avoid battery drain
                if (consecutiveGpsFailures <= 5) {
                    errorRecovery.handleGpsFailure()
                } else {
                    Log.w(TAG, "Too many consecutive GPS failures ($consecutiveGpsFailures), stopping recovery attempts")
                }
            }
        }
    }
}
    
    // P6: Old startHealthMonitoring() and checkGpsHealth() removed
    // Functionality consolidated into startCombinedHealthMonitoring()

    // Recovery Actions
    
    private fun handleGpsRestart() {
    Log.w(TAG, "Attempting GPS restart")
    
    try {
        // Stop current location updates
        locationCallback?.let { callback ->
            fusedLocationClient?.removeLocationUpdates(callback)
        }
        
        // Use more conservative settings on restart
        healthCheckHandler?.postDelayed({
            if (isRunning) {
                val locationRequest = LocationRequest.Builder(
                    Priority.PRIORITY_BALANCED_POWER_ACCURACY,
                    maxOf(config.gpsIntervalMs * 2, 10000L)
                ).apply {
                    setMinUpdateIntervalMillis(maxOf(config.minUpdateIntervalMs * 2, 5000L))
                    setMaxUpdateDelayMillis(maxOf(config.maxUpdateDelayMs * 2, 15000L))
                    setWaitForAccurateLocation(false)
                    setMinUpdateDistanceMeters(10f)
                }.build()
                
                try {
                    val callback = locationCallback
                    if (callback == null) {
                        Log.e(TAG, "LocationCallback is null - cannot restart GPS")
                        return@postDelayed
                    }
                    fusedLocationClient?.requestLocationUpdates(
                        locationRequest,
                        callback,
                        Looper.getMainLooper()
                    )

                    // Reapply smart GPS configuration after recovery stabilizes
                    if (smartConfig.updateStrategy != SmartGpsConfig.UpdateStrategy.CONTINUOUS) {
                        pendingSmartConfigReapplyRunnable?.let {
                            healthCheckHandler?.removeCallbacks(it)
                        }
                        val runnable = Runnable {
                            pendingSmartConfigReapplyRunnable = null
                            if (isRunning) {
                                Log.d(TAG, "Reapplying smart GPS configuration after recovery")
                                updateLocationRequest()
                            }
                        }
                        pendingSmartConfigReapplyRunnable = runnable
                        Log.d(TAG, "GPS recovery: will reapply smart config in 10s")
                        healthCheckHandler?.postDelayed(runnable, 10000L)
                    }
                } catch (e: SecurityException) {
                    Log.e(TAG, "GPS restart failed - permission denied: ${e.message}")
                    PolyfenceErrorManager.reportError(
                        "permission_revoked",
                        "Location permission was revoked - SecurityException during GPS restart",
                        mapOf("platform" to "android", "error" to (e.message ?: ""), "timestamp" to System.currentTimeMillis())
                    )
                    errorRecovery.handlePermissionLoss()
                }
            }
        }, 3000L)
        
    } catch (e: Exception) {
        Log.e(TAG, "GPS restart failed: ${e.message}")
    }
}
    
    private fun handlePermissionLoss() {
        Log.e(TAG, "Location permission lost - stopping service")
        stopTracking()
    }
    
    private fun handleServiceRestart() {
        Log.w(TAG, "Restarting LocationTracker service")
        
        // Create restart intent
        val restartIntent = Intent(this, LocationTracker::class.java).apply {
            action = ACTION_START_TRACKING
        }
        
        try {
            startService(restartIntent)
        } catch (e: Exception) {
            Log.e(TAG, "Service restart failed: ${e.message}")
        }
    }
    
    // ============================================================================
    // GPS HEALTH MONITORING
    // ============================================================================

    /**
     * Check GPS reliability based on accuracy and consistency
     */
    private fun checkGpsReliability(location: android.location.Location) {
        if (!location.hasAccuracy()) return

        val accuracy = location.accuracy

        // Detect unreliable GPS: accuracy > 150m is considered unreliable
        // Android FLP can feed locations with 500m+ accuracy during signal loss
        if (accuracy > 150.0f) {
            emitGpsUnreliableError(getGpsAvailabilityDrops5Min(), accuracy.toDouble())
        }
    }

    /**
     * Remove GPS availability drop timestamps older than 5 minutes
     */
    private fun cleanupOldGpsDrops(currentTime: Long) {
        val fiveMinutesAgo = currentTime - 300_000L
        gpsAvailabilityDropTimestamps.removeAll { it < fiveMinutesAgo }
    }

    /**
     * Get number of GPS availability drops in the last 5 minutes
     */
    private fun getGpsAvailabilityDrops5Min(): Int {
        val currentTime = System.currentTimeMillis()
        cleanupOldGpsDrops(currentTime)
        return gpsAvailabilityDropTimestamps.size
    }

    /**
     * Emit gpsUnreliable error (with cooldown to prevent spam)
     */
    private fun emitGpsUnreliableError(drops: Int, accuracy: Double? = null) {
        val currentTime = System.currentTimeMillis()
        if (currentTime - lastGpsUnreliableErrorTime < GPS_UNRELIABLE_ERROR_COOLDOWN_MS) {
            return // Cooldown active - don't spam errors
        }

        lastGpsUnreliableErrorTime = currentTime

        val message = if (accuracy != null) {
            "GPS signal unreliable - poor accuracy (${accuracy.toInt()}m)"
        } else {
            "GPS signal unreliable - $drops availability drops in last 5 minutes"
        }

        val context = mutableMapOf<String, Any>(
            "platform" to "android",
            "drops5Min" to drops,
            "timestamp" to currentTime
        )

        if (accuracy != null) {
            context["accuracy"] = accuracy
        }

        Log.w(TAG, "GPS unreliable: drops=$drops, accuracy=$accuracy")

        PolyfenceErrorManager.reportError(
            "gps_unreliable",
            message,
            context
        )
    }

    // ============================================================================
    // SMART GPS CONFIGURATION METHODS
    // ============================================================================
    
    /**
     * Update smart GPS configuration
     */
    fun updateSmartConfiguration(config: SmartGpsConfig) {
        this.smartConfig = config
        currentSmartConfig = config
        
        // Apply configuration immediately if tracking is active
        if (isRunning) {
            updateLocationRequest()
        }
        
        config.logConfiguration(TAG)
    }

    private fun updateConfigurationFromMap(configMap: Map<String, Any>) {
        try {
            val accuracyProfileRaw = configMap["accuracyProfile"] as? String
            val updateStrategyRaw = configMap["updateStrategy"] as? String
            
            val newConfig = SmartGpsConfigFactory.fromMap(configMap)
            updateSmartConfiguration(newConfig)
            Log.d(TAG, "Configuration updated from Flutter: profile=${newConfig.accuracyProfile}, strategy=${newConfig.updateStrategy}")
            
            // Update GPS accuracy threshold in GeofenceEngine if provided
            val gpsAccuracyThreshold = configMap["gpsAccuracyThreshold"] as? Number
            if (gpsAccuracyThreshold != null) {
                geofenceEngine.setGpsAccuracyThreshold(gpsAccuracyThreshold.toFloat())
                config.gpsAccuracyThreshold = gpsAccuracyThreshold.toFloat()
                Log.d(TAG, "GPS accuracy threshold updated to ${gpsAccuracyThreshold}m")
            }

            // Update dwell configuration if provided
            val dwellSettings = configMap["dwellSettings"] as? Map<String, Any>
            if (dwellSettings != null) {
                val dwellEnabled = dwellSettings["enabled"] as? Boolean ?: true
                val dwellThresholdMs = (dwellSettings["dwellThresholdMs"] as? Number)?.toLong()
                    ?: GeofenceEngine.DEFAULT_DWELL_THRESHOLD_MS
                geofenceEngine.setDwellConfig(dwellEnabled, dwellThresholdMs)
                Log.d(TAG, "Dwell config updated: enabled=$dwellEnabled, threshold=${dwellThresholdMs}ms")
            }

            // Update cluster configuration if provided
            val clusterSettings = configMap["clusterSettings"] as? Map<String, Any>
            if (clusterSettings != null) {
                val clusterEnabled = clusterSettings["enabled"] as? Boolean ?: false
                val activeRadiusMeters = (clusterSettings["activeRadiusMeters"] as? Number)?.toDouble() ?: 5000.0
                val refreshDistanceMeters = (clusterSettings["refreshDistanceMeters"] as? Number)?.toDouble() ?: 1000.0
                geofenceEngine.setClusterConfig(clusterEnabled, activeRadiusMeters, refreshDistanceMeters)
                Log.d(TAG, "Cluster config updated: enabled=$clusterEnabled, activeRadius=${activeRadiusMeters}m, refreshDistance=${refreshDistanceMeters}m")
            }

            // Update schedule configuration if provided
            val scheduleSettings = configMap["scheduleSettings"] as? Map<String, Any>
            if (scheduleSettings != null) {
                setScheduleConfig(this, scheduleSettings)
                Log.d(TAG, "Schedule config updated from configuration")
            }

            // Update activity recognition configuration if provided
            val activitySettingsMap = configMap["activitySettings"] as? Map<String, Any>
            if (activitySettingsMap != null) {
                val newActivitySettings = ActivitySettings.fromMap(activitySettingsMap)
                updateActivityRecognition(newActivitySettings)
                Log.d(TAG, "Activity config updated: enabled=${newActivitySettings.enabled}")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to update configuration: ${e.message}")
        }
    }

    /**
     * Update activity recognition settings
     */
    private fun updateActivityRecognition(newSettings: ActivitySettings) {
        activitySettings = newSettings

        if (newSettings.enabled) {
            // Initialize manager if needed
            if (activityRecognitionManager == null) {
                activityRecognitionManager = ActivityRecognitionManager(this)
            }

            // Start activity recognition with callback
            activityRecognitionManager?.start(newSettings) { activity, confidence ->
                Log.i(TAG, "Activity changed: $activity (confidence: $confidence%)")
                currentActivity = activity
                // Update GPS interval when activity changes
                if (isRunning) {
                    updateLocationRequest()
                }
            }
        } else {
            // Stop activity recognition
            activityRecognitionManager?.stop()
            currentActivity = ActivityType.UNKNOWN
        }
    }
    
    /**
     * Initialize smart configuration from static config
     */
    private fun initializeSmartConfiguration() {
        smartConfig = getCurrentSmartConfiguration()
    }
    
    /**
     * Update location request based on current smart configuration
     */
    private fun updateLocationRequest() {
        val priority = smartConfig.getLocationPriority()
        val interval = calculateCurrentInterval()

        val locationRequest = LocationRequest.Builder(priority, interval)
            .setMinUpdateIntervalMillis(interval / 2)
            .setMaxUpdateDelayMillis(interval * 2)
            .setWaitForAccurateLocation(smartConfig.shouldWaitForAccurateLocation())
            .setMinUpdateDistanceMeters(smartConfig.getDistanceFilter())  // P1: Apply distance filter from profile
            .build()
        
        // Stop current location updates
        locationCallback?.let { callback ->
            fusedLocationClient?.removeLocationUpdates(callback)
        }
        
        // Start new location updates with new configuration
        try {
            fusedLocationClient?.requestLocationUpdates(
                locationRequest,
                locationCallback ?: createLocationCallback(),
                Looper.getMainLooper()
            )
            
            currentGpsInterval = interval
            Log.d(TAG, "Updated GPS: priority=$priority, interval=${interval}ms")
            
            // Emit status after GPS configuration changes
            emitRuntimeStatus()
        } catch (e: SecurityException) {
            Log.e(TAG, "Security exception updating location request: ${e.message}")
            PolyfenceErrorManager.reportError(
                "permission_revoked",
                "Location permission was revoked - SecurityException during GPS update",
                mapOf("platform" to "android", "error" to (e.message ?: ""), "timestamp" to System.currentTimeMillis())
            )
            errorRecovery.handlePermissionLoss()
            stopSelf()
        }
    }
    
    /**
     * Calculate current GPS interval based on smart configuration
     */
    private fun calculateCurrentInterval(): Long {
        return when (smartConfig.updateStrategy) {
            SmartGpsConfig.UpdateStrategy.CONTINUOUS -> smartConfig.getBaseUpdateInterval()
            SmartGpsConfig.UpdateStrategy.PROXIMITY_BASED -> calculateProximityBasedInterval()
            SmartGpsConfig.UpdateStrategy.MOVEMENT_BASED -> calculateMovementBasedInterval()
            SmartGpsConfig.UpdateStrategy.INTELLIGENT -> calculateIntelligentInterval()
        }
    }
    
    /**
     * Calculate interval based on proximity to zones
     */
    private fun calculateProximityBasedInterval(): Long {
        val proximitySettings = smartConfig.proximitySettings ?: return smartConfig.getBaseUpdateInterval()
        val lastLocation = lastKnownLocation ?: return smartConfig.getBaseUpdateInterval()
        
        // Calculate distance to nearest zone
        val nearestZoneDistance = calculateDistanceToNearestZone(lastLocation)
        
        return when {
            nearestZoneDistance <= proximitySettings.nearZoneThresholdMeters -> {
                Log.d(TAG, "Near zone (${nearestZoneDistance}m) - using high frequency")
                proximitySettings.nearZoneUpdateIntervalMs
            }
            nearestZoneDistance >= proximitySettings.farZoneThresholdMeters -> {
                Log.d(TAG, "Far from zones (${nearestZoneDistance}m) - using low frequency")
                proximitySettings.farZoneUpdateIntervalMs
            }
            else -> {
                // Medium distance - interpolate between near and far intervals
                val ratio = (nearestZoneDistance - proximitySettings.nearZoneThresholdMeters) / 
                           (proximitySettings.farZoneThresholdMeters - proximitySettings.nearZoneThresholdMeters)
                
                val intervalDiff = proximitySettings.farZoneUpdateIntervalMs - proximitySettings.nearZoneUpdateIntervalMs
                val interpolatedInterval = proximitySettings.nearZoneUpdateIntervalMs + (ratio * intervalDiff).toLong()
                
                Log.d(TAG, "Medium distance (${nearestZoneDistance}m) - using interpolated interval: ${interpolatedInterval}ms")
                interpolatedInterval
            }
        }
    }
    
    /**
     * Calculate interval based on movement state
     */
    private fun calculateMovementBasedInterval(): Long {
        val movementSettings = smartConfig.movementSettings ?: return smartConfig.getBaseUpdateInterval()
        
        return if (isStationary) {
            movementSettings.stationaryUpdateIntervalMs
        } else {
            movementSettings.movingUpdateIntervalMs
        }
    }
    
    /**
     * Calculate interval using intelligent combination of factors.
     *
     * HIERARCHY (fixed):
     * - When near a zone AND moving → fast proximity interval (detect entry/exit quickly)
     * - When near a zone AND stationary → respect stationary interval (save battery at home)
     * - When far from all zones → use most battery-friendly interval
     */
    private fun calculateIntelligentInterval(): Long {
        val proximitySettings = smartConfig.proximitySettings
        val lastLocation = lastKnownLocation
        var proximityInterval: Long? = null

        // Check if we're near a zone
        if (proximitySettings != null && lastLocation != null) {
            val nearestZoneDistance = calculateDistanceToNearestZone(lastLocation)

            if (nearestZoneDistance <= proximitySettings.nearZoneThresholdMeters) {
                proximityInterval = calculateProximityBasedInterval()
                Log.d(TAG, "Near zone (${nearestZoneDistance}m) - proximity interval: ${proximityInterval}ms, isStationary=$isStationary")
            }
        }

        // Collect other strategy intervals
        val movementInterval = calculateMovementBasedInterval()
        val batteryInterval = calculateBatteryBasedInterval()
        val activityInterval = calculateActivityBasedInterval()

        // Near a zone AND stationary → respect stationary interval to save battery
        if (proximityInterval != null && isStationary) {
            val stationaryInterval = smartConfig.movementSettings?.stationaryUpdateIntervalMs ?: 120_000L
            val result = maxOf(proximityInterval, stationaryInterval)
            Log.d(TAG, "Near zone but stationary - using: ${result}ms (proximity=$proximityInterval, stationary=$stationaryInterval)")
            return result
        }

        // Near a zone AND moving → proximity wins (fast updates for entry/exit detection)
        if (proximityInterval != null) {
            return proximityInterval
        }

        // Far from zones → use the most battery-friendly (longest) interval
        val result = maxOf(movementInterval, batteryInterval, activityInterval)
        Log.d(TAG, "Far from zones - using longest interval: ${result}ms (movement=$movementInterval, battery=$batteryInterval, activity=$activityInterval)")
        return result
    }

    /**
     * Calculate interval based on detected activity type
     * Only applies when activity recognition is enabled
     */
    private fun calculateActivityBasedInterval(): Long {
        if (!activitySettings.enabled) {
            return smartConfig.getBaseUpdateInterval()
        }

        return activitySettings.getIntervalForActivity(currentActivity)
    }
    
    /**
     * Calculate interval based on battery level
     */
    private fun calculateBatteryBasedInterval(): Long {
        val batterySettings = smartConfig.batterySettings ?: return smartConfig.getBaseUpdateInterval()
        
        try {
            val batteryManager = getSystemService(Context.BATTERY_SERVICE) as android.os.BatteryManager
            val batteryLevel = batteryManager.getIntProperty(android.os.BatteryManager.BATTERY_PROPERTY_CAPACITY)
            
            return when {
                batteryLevel <= batterySettings.criticalBatteryThreshold && batterySettings.pauseOnCriticalBattery -> 
                    Long.MAX_VALUE // Pause GPS
                batteryLevel <= batterySettings.lowBatteryThreshold -> 
                    batterySettings.lowBatteryUpdateIntervalMs
                else -> smartConfig.getBaseUpdateInterval()
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to get battery level: ${e.message}")
            return smartConfig.getBaseUpdateInterval()
        }
    }
    
    /**
     * Calculate distance to nearest zone
     */
    private fun calculateDistanceToNearestZone(location: android.location.Location): Double {
        try {
            // Get current zones from GeofenceEngine
            val zones = geofenceEngine.getCurrentZones()
            if (zones.isEmpty()) {
                return Double.MAX_VALUE // No zones configured
            }
            
            var nearestDistance = Double.MAX_VALUE
            
            for (zone in zones) {
                val distance = when {
                    zone.isCircle -> calculateDistanceToCircleZone(location, zone)
                    zone.isPolygon -> calculateDistanceToPolygonZone(location, zone)
                    else -> Double.MAX_VALUE
                }
                
                if (distance < nearestDistance) {
                    nearestDistance = distance
                }
            }
            
            Log.d(TAG, "Nearest zone distance: ${nearestDistance}m")
            return nearestDistance
            
        } catch (e: Exception) {
            Log.e(TAG, "Error calculating zone distance: ${e.message}")
            return Double.MAX_VALUE // Fallback to no optimization
        }
    }
    
    /**
     * Calculate distance to circle zone boundary
     */
    private fun calculateDistanceToCircleZone(
        location: android.location.Location, 
        zone: GeofenceEngine.Zone
    ): Double {
        val center = zone.center ?: return Double.MAX_VALUE
        val radius = zone.radius ?: return Double.MAX_VALUE
        
        val centerLocation = android.location.Location("").apply {
            latitude = center.latitude
            longitude = center.longitude
        }
        
        val distanceToCenter = location.distanceTo(centerLocation).toDouble()
        
        // Distance to zone boundary (0 if inside zone)
        return maxOf(0.0, distanceToCenter - radius)
    }
    
    /**
     * Calculate distance to polygon zone boundary
     */
    private fun calculateDistanceToPolygonZone(
        location: android.location.Location,
        zone: GeofenceEngine.Zone
    ): Double {
        val currentPoint = LatLng(location.latitude, location.longitude)
        val points = zone.points
        
        if (points.isEmpty()) return Double.MAX_VALUE
        
        // Check if inside polygon first
        if (isPointInPolygon(currentPoint, points)) {
            return 0.0 // Inside zone
        }
        
        // Calculate distance to nearest polygon edge
        var nearestDistance = Double.MAX_VALUE
        
        for (i in points.indices) {
            val p1 = points[i]
            val p2 = points[(i + 1) % points.size]
            
            val distance = distanceFromPointToLineSegment(currentPoint, p1, p2)
            if (distance < nearestDistance) {
                nearestDistance = distance
            }
        }
        
        return nearestDistance
    }
    
    /**
     * Calculate distance from point to line segment
     */
    private fun distanceFromPointToLineSegment(
        point: LatLng,
        lineStart: LatLng, 
        lineEnd: LatLng
    ): Double {
        // Calculate perpendicular distance from point to line segment
        val A = point.latitude - lineStart.latitude
        val B = point.longitude - lineStart.longitude
        val C = lineEnd.latitude - lineStart.latitude
        val D = lineEnd.longitude - lineStart.longitude
        
        val dot = A * C + B * D
        val lenSq = C * C + D * D
        
        if (lenSq == 0.0) {
            // Line segment is a point
            return calculateDistance(point, lineStart)
        }
        
        val param = dot / lenSq
        
        val closest = when {
            param < 0.0 -> lineStart
            param > 1.0 -> lineEnd
            else -> LatLng(
                lineStart.latitude + param * C,
                lineStart.longitude + param * D
            )
        }
        
        return calculateDistance(point, closest)
    }
    
    /**
     * Calculate distance between two LatLng points using Haversine formula
     */
    private fun calculateDistance(point1: LatLng, point2: LatLng): Double {
        val EARTH_RADIUS_METERS = 6371000.0
        val dLat = Math.toRadians(point2.latitude - point1.latitude)
        val dLng = Math.toRadians(point2.longitude - point1.longitude)
        
        val a = sin(dLat / 2).pow(2) +
                cos(Math.toRadians(point1.latitude)) * cos(Math.toRadians(point2.latitude)) *
                sin(dLng / 2).pow(2)
        
        val c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return EARTH_RADIUS_METERS * c
    }
    
    /**
     * Point-in-polygon detection using ray casting algorithm
     */
    private fun isPointInPolygon(point: LatLng, polygon: List<LatLng>): Boolean {
        var intersections = 0
        val x = point.longitude
        val y = point.latitude
        
        for (i in polygon.indices) {
            val p1 = polygon[i]
            val p2 = polygon[(i + 1) % polygon.size]
            
            if (((p1.latitude > y) != (p2.latitude > y)) &&
                (x < (p2.longitude - p1.longitude) * (y - p1.latitude) / (p2.latitude - p1.latitude) + p1.longitude)) {
                intersections++
            }
        }
        
        return intersections % 2 == 1
    }
    
    /**
     * Log proximity debug information for testing
     */
    private fun logProximityDebugInfo(location: android.location.Location) {
        if (smartConfig.enableDebugLogging) {
            val distance = calculateDistanceToNearestZone(location)
            val interval = calculateProximityBasedInterval()
            
            Log.i(TAG, """
                Proximity Debug:
                - Distance to nearest zone: ${distance}m
                - GPS interval: ${interval}ms
                - Update strategy: ${smartConfig.updateStrategy}
                - Zones count: ${geofenceEngine.getZoneCount()}
            """.trimIndent())
        }
    }
    
    /**
     * Update movement state based on location changes.
     *
     * Stationary detection always runs using sensible defaults, even when
     * movementSettings is null. This ensures isStationary is always accurate,
     * which is critical for INTELLIGENT strategy and P11 callback throttling.
     */
    private fun updateMovementState(location: android.location.Location) {
        lastKnownLocation = location
        val currentTime = System.currentTimeMillis()
        val movementSettings = smartConfig.movementSettings

        // Always compute stationary state — use defaults when movementSettings is null
        val moveThreshold = movementSettings?.movementThresholdMeters?.toFloat() ?: 50.0f
        val timeThreshold = movementSettings?.stationaryThresholdMs ?: 300_000L

        // Distance from last significant movement position (not from lastKnownLocation,
        // which was just overwritten above — comparing to itself would always yield 0)
        val distance = lastMovementLocation?.let { location.distanceTo(it) } ?: Float.MAX_VALUE

        if (distance > moveThreshold) {
            // Significant movement detected — update movement anchor
            lastMovementLocation = location
            lastMovementTime = currentTime
            if (isStationary) {
                isStationary = false
                Log.d(TAG, "Device started moving (moved ${String.format("%.1f", distance)}m)")
                updateLocationRequest()
                emitRuntimeStatus()
            }
        } else if (lastMovementTime > 0 && currentTime - lastMovementTime >= timeThreshold) {
            // No significant movement for threshold duration
            if (!isStationary) {
                isStationary = true
                Log.d(TAG, "Device is now stationary (no movement > ${moveThreshold}m in ${timeThreshold / 1000}s)")
                updateLocationRequest()
                emitRuntimeStatus()
            }
        }

        // Initialize movement tracking on first location
        if (lastMovementLocation == null) {
            lastMovementLocation = location
            lastMovementTime = currentTime
        }

        lastLocationTime = currentTime
    }
    
    /**
     * Create location callback for smart GPS configuration
     */
    private fun createLocationCallback(): LocationCallback {
        return object : LocationCallback() {
            override fun onLocationResult(locationResult: LocationResult) {
                locationResult.lastLocation?.let { location ->
                    // Guard clause: only process if tracking is active
                    if (!isRunning) {
                        return
                    }
                    
                    // Update movement state for smart GPS
                    updateMovementState(location)
                    
                    // Update health tracking
                    lastLocationTime = System.currentTimeMillis()
                    consecutiveGpsFailures = 0
                    
                    // Process location with geofence engine
                    geofenceEngine.checkLocation(location)
                    
                    // Send location update to Flutter
                    sendLocationToFlutter(location)
                    
                    // Emit status periodically
                    emitRuntimeStatus()
                }
            }
            
            override fun onLocationAvailability(locationAvailability: LocationAvailability) {
                if (!locationAvailability.isLocationAvailable) {
                    Log.w(TAG, "Location availability lost")
                    consecutiveGpsFailures++
                    
                    if (consecutiveGpsFailures >= 3) {
                        errorRecovery.handleGpsFailure()
                    }
                }
            }
        }
    }
    
    // ============================================================================
    // BATTERY LEVEL DETECTION
    // ============================================================================
    
    /**
     * Get current battery level percentage
     */
    private fun getBatteryLevel(): Int {
        return try {
            val batteryManager = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
            batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get battery level: ${e.message}")
            100 // Default to full battery on error
        }
    }
    
    /**
     * Get current battery mode based on level and settings
     */
    private fun getCurrentBatteryMode(): String {
        val batteryLevel = getBatteryLevel()
        val batterySettings = smartConfig.batterySettings ?: return "normal"
        
        return when {
            batteryLevel <= batterySettings.criticalBatteryThreshold -> "critical"
            batteryLevel <= batterySettings.lowBatteryThreshold -> "low"
            else -> "normal"
        }
    }
    
    // ============================================================================
    // RUNTIME STATUS EMISSION
    // ============================================================================
    
    /**
     * Emit runtime status to Flutter via performance stream
     */
    private fun emitRuntimeStatus() {
        val location = lastKnownLocation ?: return
        val currentTime = System.currentTimeMillis()

        // Calculate seconds since last GPS fix
        val secondsSinceLastFix = if (lastLocationTime > 0) {
            ((currentTime - lastLocationTime) / 1000).toInt()
        } else {
            0
        }
        
        val status = mutableMapOf<String, Any>(
            "strategy" to smartConfig.updateStrategy.name,
            "intervalMs" to currentGpsInterval,
            "accuracyProfile" to smartConfig.accuracyProfile.name,
            "nearestZoneDistanceM" to calculateDistanceToNearestZone(location),
            "isStationary" to isStationary,
            "batteryMode" to getCurrentBatteryMode(),
            "gpsAccuracy" to location.accuracy,
            "timestamp" to currentTime,
            // New GPS health fields
            "secondsSinceLastGpsFix" to secondsSinceLastFix,
            "gpsAvailabilityDrops5Min" to getGpsAvailabilityDrops5Min()
        )

        // Add currentGpsAccuracy if available
        currentGpsAccuracy?.let {
            status["currentGpsAccuracy"] = it.toDouble()
        }
        
        // Only emit if status changed or 30 seconds elapsed
        val timeSinceLastEmit = currentTime - lastStatusEmitTime
        if (status != lastEmittedStatus || timeSinceLastEmit >= 30000) {
            // Send via existing performance event channel
            PolyfencePlugin.sendPerformanceEvent(mapOf(
                "type" to "runtime_status",
                "data" to status
            ))
            lastEmittedStatus = status
            lastStatusEmitTime = currentTime
            Log.d(TAG, "Runtime status emitted: $status")
        }
    }
}
