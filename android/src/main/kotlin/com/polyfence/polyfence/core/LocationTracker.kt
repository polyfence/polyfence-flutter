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
    }
    
    private var fusedLocationClient: FusedLocationProviderClient? = null
    private var locationCallback: LocationCallback? = null
    private val geofenceEngine = GeofenceEngine()
    private lateinit var zonePersistence: ZonePersistence
    private lateinit var config: PolyfenceConfig
    
    // Error Recovery Properties
    private lateinit var errorRecovery: PolyfenceErrorRecovery
    private var healthCheckHandler: android.os.Handler? = null
    private var lastLocationTime: Long = 0L
    private var consecutiveGpsFailures: Int = 0
    
    // Wake Lock Management
    private var wakeLock: PowerManager.WakeLock? = null
    private var isWakeLockAcquired = false
    
    // Smart GPS Configuration
    private var smartConfig: SmartGpsConfig = SmartGpsConfig()
    private var currentGpsInterval: Long = 5000L
    private var isStationary: Boolean = false
    private var lastKnownLocation: android.location.Location? = null
    
    // Runtime Status Emission
    private var lastEmittedStatus = mapOf<String, Any>()
    private var lastStatusEmitTime = 0L
    
    override fun onCreate() {
        super.onCreate()
        
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
        geofenceEngine.setEventCallback { zoneId, eventType, location ->
            handleGeofenceEvent(zoneId, eventType, location)
        }

        
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
                if (!isRunning) {
                    stopSelf()
                    return START_NOT_STICKY
                }
                removeZone(intent)
            }
            ACTION_CLEAR_ZONES -> {
                if (!isRunning) {
                    stopSelf()
                    return START_NOT_STICKY
                }
                clearZones()
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
        val fgsOk = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            ContextCompat.checkSelfPermission(this, Manifest.permission.FOREGROUND_SERVICE_LOCATION) == PackageManager.PERMISSION_GRANTED
        } else true
        return (fine || coarse) && bgOk && fgsOk
    }
    
    private fun startTracking() {
        // Verify permissions before starting foreground service
        if (!hasLocationPerms()) {
            Log.e(TAG, "Cannot start foreground service - missing permissions")
            stopSelf()
            return
        }
        
        isRunning = true
        startForeground(NOTIFICATION_ID, createTrackingNotification())
        
        // Acquire wake lock before starting location requests
        acquireWakeLock()
        
        // Restore zones from storage ONLY when tracking starts
        restoreZonesFromStorage()
        
        // Start error monitoring
        startHealthMonitoring()
        
        // Use smart GPS configuration for location request
        val priority = smartConfig.getLocationPriority()
        val interval = calculateCurrentInterval()
        
        val locationRequest = LocationRequest.Builder(priority, interval)
            .setMinUpdateIntervalMillis(interval / 2)
            .setMaxUpdateDelayMillis(interval * 2)
            .setWaitForAccurateLocation(smartConfig.shouldWaitForAccurateLocation())
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
        } catch (e: SecurityException) {
            Log.e(TAG, "Location permission denied: ${e.message}")
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
        
        stopForeground(true)
        stopSelf()
    }
    
    private fun addZone(intent: Intent) {
        val zoneId = intent.getStringExtra("zoneId") ?: return
        val zoneName = intent.getStringExtra("zoneName") ?: "Unknown Zone"
        val zoneData = intent.getSerializableExtra("zoneData") as? Map<String, Any> ?: return
        
        // Add to engine
        geofenceEngine.addZone(zoneId, zoneName, zoneData)
        
        // Save to persistent storage
        zonePersistence.saveZone(zoneId, zoneName, zoneData)
        
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
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to restore zones: ${e.message}")
        }
    }
    
private fun handleGeofenceEvent(zoneId: String, eventType: String, location: android.location.Location) {
    // Get zone name from GeofenceEngine
    val zoneName = geofenceEngine.getZoneName(zoneId) ?: zoneId
    
    // Calculate detection time (simplified - time since last location update)
    val detectionTimeMs = if (location.time > 0) {
        (System.currentTimeMillis() - location.time).toDouble()
    } else {
        0.0
    }
    
    // Get GPS accuracy
    val gpsAccuracy = if (location.hasAccuracy()) location.accuracy.toDouble() else 0.0
    
    // Send event to Flutter with detection metrics
    PolyfencePlugin.sendGeofenceEvent(zoneId, zoneName, eventType, detectionTimeMs, gpsAccuracy)
    
    // Terse geofence event log
    val displayName = if (zoneName.isNotEmpty()) zoneName else zoneId
    Log.i(TAG, "PF: EVENT $eventType zone=$displayName ts=${System.currentTimeMillis()}")
    
    // Show notification with proper zone name
    showGeofenceNotification(eventType, zoneId, zoneName)
    
}
    
    private fun sendLocationToFlutter(location: android.location.Location) {
        val locationData = mapOf(
            "latitude" to location.latitude,
            "longitude" to location.longitude,
            "accuracy" to location.accuracy.toDouble(),
            "timestamp" to System.currentTimeMillis(),
            "speed" to (if (location.hasSpeed()) location.speed * 3.6 else 0.0) // Convert m/s to km/h
        )
        PolyfencePlugin.sendLocationUpdate(locationData)
    }
    
    private fun showGeofenceNotification(eventType: String, zoneId: String, zoneName: String) {
    if (!isRunning) return
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
        errorRecovery.stopMonitoring()
        healthCheckHandler?.removeCallbacksAndMessages(null)
        // Ensure wake lock is released
        releaseWakeLock()
    }
    
    // Wake Lock Management Methods
    
    private fun acquireWakeLock() {
        try {
            if (wakeLock == null) {
                val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                wakeLock = powerManager.newWakeLock(
                    PowerManager.PARTIAL_WAKE_LOCK,
                    "Polyfence:LocationTracking"
                )
            }
            
            if (!isWakeLockAcquired) {
                // Use indefinite wake lock for foreground service
                // Properly released in releaseWakeLock() when tracking stops
                wakeLock?.acquire()
                isWakeLockAcquired = true
                Log.d(TAG, "Wake lock acquired for location tracking")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to acquire wake lock: ${e.message}")
            // Wake lock failure is not critical - service can still run
        }
    }
    
    private fun releaseWakeLock() {
        try {
            if (isWakeLockAcquired) {
                wakeLock?.release()
                isWakeLockAcquired = false
                Log.d(TAG, "Wake lock released")
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
                
                // Update movement state for smart GPS
                updateMovementState(location)
                
                // Log proximity debug info
                logProximityDebugInfo(location)
                
                // Update health tracking
                lastLocationTime = System.currentTimeMillis()
                consecutiveGpsFailures = 0
                
                // Reset error recovery attempts on successful location
                errorRecovery.resetRestartAttempts()
                
                // Send to Flutter
                sendLocationToFlutter(location)
                
                // Check geofences (only when tracking is active)
                geofenceEngine.checkLocation(location)
            }
        }
        
        override fun onLocationAvailability(locationAvailability: LocationAvailability) {
            if (!locationAvailability.isLocationAvailable) {
                Log.w(TAG, "Location availability lost")
                consecutiveGpsFailures++
                
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
    
    private fun startHealthMonitoring() {
        // Existing health checks
        healthCheckHandler?.removeCallbacksAndMessages(null)
        healthCheckHandler?.postDelayed(object : Runnable {
            override fun run() {
                if (!isRunning) return
                try {
                    // Collect battery/charging
                    val bm = getSystemService(Context.BATTERY_SERVICE) as android.os.BatteryManager
                    val level = bm.getIntProperty(android.os.BatteryManager.BATTERY_PROPERTY_CAPACITY).toDouble()
                    val isCharging = bm.isCharging

                    // GPS active heuristic: receiving updates recently
                    val gpsActive = (System.currentTimeMillis() - lastLocationTime) < 60_000

                    val health = mapOf(
                        "type" to "system_health",
                        "battery_level" to level,
                        "is_charging" to isCharging,
                        "gps_active" to gpsActive,
                        "timestamp" to System.currentTimeMillis(),
                        "gps_status" to if (gpsActive) "active" else "idle"
                    )
                } catch (e: Exception) {
                    Log.e(TAG, "Health snapshot failed: ${e.message}")
                }
                // Re-schedule ~12 minutes
                healthCheckHandler?.postDelayed(this, 12 * 60 * 1000L)
            }
        }, 12 * 60 * 1000L)
    }
    
    private fun checkGpsHealth() {
    healthCheckHandler?.postDelayed({
        if (isRunning) {
            val currentTime = System.currentTimeMillis()
            val timeSinceLastLocation = currentTime - lastLocationTime
            
            // Only trigger health check restart if NO recent restart attempts
            if (timeSinceLastLocation > 120000L && lastLocationTime > 0) {
                Log.w(TAG, "GPS health check failed - no location for ${timeSinceLastLocation}ms")
                
                // Only trigger if not too many failures
                if (consecutiveGpsFailures >= 3 && consecutiveGpsFailures <= 5) {
                    Log.w(TAG, "Health check triggering GPS recovery")
                    errorRecovery.handleGpsFailure()
                } else {
                }
            }
            
            // Schedule next health check
            checkGpsHealth()
        }
    }, 30000L)
}
    
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
                    Priority.PRIORITY_BALANCED_POWER_ACCURACY, // 🔧 Less demanding
                    maxOf(config.gpsIntervalMs * 2, 10000L)    // 🔧 Double interval, min 10s
                ).apply {
                    setMinUpdateIntervalMillis(maxOf(config.minUpdateIntervalMs * 2, 5000L))
                    setMaxUpdateDelayMillis(maxOf(config.maxUpdateDelayMs * 2, 15000L))
                    setWaitForAccurateLocation(false)
                    setMinUpdateDistanceMeters(10f) // 🔧 Only update if moved 10 meters
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
                } catch (e: SecurityException) {
                    Log.e(TAG, "GPS restart failed - permission denied: ${e.message}")
                    errorRecovery.handlePermissionLoss()
                }
            }
        }, 3000L) // 🔧 3 second delay instead of 2
        
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
            Log.d(TAG, "🔧 Android received configMap: $configMap")
            val accuracyProfileRaw = configMap["accuracyProfile"] as? String
            val updateStrategyRaw = configMap["updateStrategy"] as? String
            Log.d(TAG, "🔧 Android raw values: accuracyProfile='$accuracyProfileRaw', updateStrategy='$updateStrategyRaw'")
            
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
        } catch (e: Exception) {
            Log.e(TAG, "Failed to update configuration: ${e.message}")
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
     * Calculate interval using intelligent combination of factors
     */
    private fun calculateIntelligentInterval(): Long {
        val proximityInterval = calculateProximityBasedInterval()
        val movementInterval = calculateMovementBasedInterval()
        val batteryInterval = calculateBatteryBasedInterval()
        
        // Use the most conservative (longest) interval
        return maxOf(proximityInterval, movementInterval, batteryInterval)
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
     * Update movement state based on location changes
     */
    private fun updateMovementState(location: android.location.Location) {
        lastKnownLocation = location
        val currentTime = System.currentTimeMillis()
        val movementSettings = smartConfig.movementSettings

        if (movementSettings == null) {
            lastLocationTime = currentTime
            return
        }
        
        if (lastLocationTime > 0) {
            val timeDiff = currentTime - lastLocationTime
            val distance = lastKnownLocation?.let { 
                location.distanceTo(it) 
            } ?: 0f
            
            // Check if device is stationary
            if (timeDiff >= movementSettings.stationaryThresholdMs) {
                if (distance < movementSettings.movementThresholdMeters) {
                    if (!isStationary) {
                        isStationary = true
                        Log.d(TAG, "Device is now stationary")
                        updateLocationRequest() // Update GPS interval
                        emitRuntimeStatus() // Emit status on movement state change
                    }
                } else if (isStationary) {
                    isStationary = false
                    Log.d(TAG, "Device is now moving")
                    updateLocationRequest() // Update GPS interval
                    emitRuntimeStatus() // Emit status on movement state change
                }
            }
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
        
        val status = mapOf(
            "strategy" to smartConfig.updateStrategy.name,
            "intervalMs" to currentGpsInterval,
            "accuracyProfile" to smartConfig.accuracyProfile.name,
            "nearestZoneDistanceM" to calculateDistanceToNearestZone(location),
            "isStationary" to isStationary,
            "batteryMode" to getCurrentBatteryMode(),
            "gpsAccuracy" to location.accuracy,
            "timestamp" to System.currentTimeMillis()
        )
        
        // Only emit if status changed or 30 seconds elapsed
        val timeSinceLastEmit = System.currentTimeMillis() - lastStatusEmitTime
        if (status != lastEmittedStatus || timeSinceLastEmit >= 30000) {
            // Send via existing performance event channel
            PolyfencePlugin.sendPerformanceEvent(mapOf(
                "type" to "runtime_status",
                "data" to status
            ))
            lastEmittedStatus = status
            lastStatusEmitTime = System.currentTimeMillis()
            Log.d(TAG, "Runtime status emitted: $status")
        }
    }
}
