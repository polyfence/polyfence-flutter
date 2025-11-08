package com.polyfence.polyfence.utils

import android.content.Context
import android.content.SharedPreferences
import android.util.Log

/**
 * Centralized configuration management for Polyfence
 * Single responsibility: Runtime configuration and persistence
 */
class PolyfenceConfig(context: Context) {
    
    companion object {
        private const val TAG = "PolyfenceConfig"
        private const val PREFS_NAME = "polyfence_config"
        
        // Default GPS Configuration
        const val DEFAULT_GPS_INTERVAL_MS = 5000L // 5 seconds - balanced
        const val DEFAULT_GPS_ACCURACY_THRESHOLD = 100.0f
        const val DEFAULT_MIN_UPDATE_INTERVAL_MS = 1000L
        const val DEFAULT_MAX_UPDATE_DELAY_MS = 6000L
        const val MIN_UPDATE_DISTANCE_METERS = 10f
        
        // Zone Validation Configuration
        const val DEFAULT_CONFIDENCE_POINTS = 2
        const val DEFAULT_CONFIDENCE_TIMEOUT_MS = 10000L
        const val DEFAULT_REQUIRE_CONFIRMATION = true
        const val LARGE_ZONE_RADIUS_THRESHOLD_METERS = 200.0
        const val MIN_SINGLE_POINT_ZONE_RADIUS_METERS = 50.0
        const val MIN_POLYGON_POINTS = 3
        
        // Speed and Movement Thresholds
        const val HIGH_SPEED_THRESHOLD_KMH = 40.0
        const val SPEED_MS_TO_KMH_MULTIPLIER = 3.6
        
        // GPS Health and Recovery
        const val MAX_GPS_FAILURES_BEFORE_COOLDOWN = 2
        const val MIN_GPS_FAILURES_FOR_RECOVERY = 3
        const val MAX_GPS_FAILURES_FOR_RECOVERY = 5
        const val GPS_HEALTH_CHECK_TIMEOUT_MS = 120000L // 2 minutes
        const val HEALTH_CHECK_INTERVAL_MS = 30000L // 30 seconds
        const val GPS_RESTART_DELAY_MS = 3000L // 3 seconds
        const val SERVICE_RESTART_DELAY_MS = 5000L // 5 seconds
        
        // GPS Restart Configuration
        const val MIN_GPS_RESTART_INTERVAL_MS = 10000L // 10 seconds
        const val MIN_UPDATE_RESTART_INTERVAL_MS = 5000L // 5 seconds
        const val MAX_UPDATE_RESTART_DELAY_MS = 15000L // 15 seconds
        
        // System Defaults
        const val DEFAULT_BATTERY_LEVEL = 100.0
        const val DEVICE_ID_RANDOM_RANGE = 10000
        const val FOREGROUND_NOTIFICATION_ID = 1001
        const val APP_VERSION = "1.0.0"
        
        // Validation Ranges
        const val MIN_GPS_INTERVAL_MS = 1000L
        const val MAX_GPS_INTERVAL_MS = 60000L
        const val MIN_ACCURACY_THRESHOLD = 1.0f
        const val MAX_ACCURACY_THRESHOLD = 500.0f
        const val MIN_CONFIDENCE_POINTS = 1
        const val MAX_CONFIDENCE_POINTS = 5
        
        // Calculation Factors
        const val MIN_UPDATE_INTERVAL_FACTOR = 2L // minInterval = gpsInterval / 2
        const val MAX_UPDATE_DELAY_FACTOR = 2L // maxDelay = gpsInterval * 2
        
        // Cache Configuration
        const val DEFAULT_LRU_INITIAL_CAPACITY = 16
        const val DEFAULT_LRU_LOAD_FACTOR = 0.75f
    }
    
    private val prefs: SharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    
    // GPS Configuration
    var gpsIntervalMs: Long
        get() = prefs.getLong("gps_interval_ms", DEFAULT_GPS_INTERVAL_MS)
        set(value) {
            prefs.edit().putLong("gps_interval_ms", value).apply()
        }
    
    var gpsAccuracyThreshold: Float
        get() = prefs.getFloat("gps_accuracy_threshold", DEFAULT_GPS_ACCURACY_THRESHOLD)
        set(value) {
            prefs.edit().putFloat("gps_accuracy_threshold", value).apply()
        }
    
    var minUpdateIntervalMs: Long
        get() = prefs.getLong("min_update_interval_ms", DEFAULT_MIN_UPDATE_INTERVAL_MS)
        set(value) {
            prefs.edit().putLong("min_update_interval_ms", value).apply()
        }
    
    var maxUpdateDelayMs: Long
        get() = prefs.getLong("max_update_delay_ms", DEFAULT_MAX_UPDATE_DELAY_MS)
        set(value) {
            prefs.edit().putLong("max_update_delay_ms", value).apply()
        }
    
    // Validation Configuration
    var requireConfirmation: Boolean
        get() = prefs.getBoolean("require_confirmation", DEFAULT_REQUIRE_CONFIRMATION)
        set(value) {
            prefs.edit().putBoolean("require_confirmation", value).apply()
        }
    
    var confidencePoints: Int
        get() = prefs.getInt("confidence_points", DEFAULT_CONFIDENCE_POINTS)
        set(value) {
            prefs.edit().putInt("confidence_points", value).apply()
        }
    
    var confidenceTimeoutMs: Long
        get() = prefs.getLong("confidence_timeout_ms", DEFAULT_CONFIDENCE_TIMEOUT_MS)
        set(value) {
            prefs.edit().putLong("confidence_timeout_ms", value).apply()
        }
    
    /**
     * Reset all configuration to defaults
     */
    fun resetToDefaults() {
        prefs.edit().clear().apply()
    }
    
    /**
     * Get current configuration as a map for debugging
     */
    fun getConfigurationMap(): Map<String, Any> {
        return mapOf(
            "gps_interval_ms" to gpsIntervalMs,
            "gps_accuracy_threshold" to gpsAccuracyThreshold,
            "min_update_interval_ms" to minUpdateIntervalMs,
            "max_update_delay_ms" to maxUpdateDelayMs,
            "require_confirmation" to requireConfirmation,
            "confidence_points" to confidencePoints,
            "confidence_timeout_ms" to confidenceTimeoutMs
        )
    }
    
    /**
     * Update configuration from a map (useful for Flutter integration)
     */
    fun updateFromMap(configMap: Map<String, Any>) {
        try {
            configMap["gps_interval_ms"]?.let { 
                if (it is Number) gpsIntervalMs = it.toLong() 
            }
            configMap["gps_accuracy_threshold"]?.let { 
                if (it is Number) gpsAccuracyThreshold = it.toFloat() 
            }
            configMap["min_update_interval_ms"]?.let { 
                if (it is Number) minUpdateIntervalMs = it.toLong() 
            }
            configMap["max_update_delay_ms"]?.let { 
                if (it is Number) maxUpdateDelayMs = it.toLong() 
            }
            configMap["require_confirmation"]?.let { 
                if (it is Boolean) requireConfirmation = it 
            }
            configMap["confidence_points"]?.let { 
                if (it is Number) confidencePoints = it.toInt() 
            }
            configMap["confidence_timeout_ms"]?.let { 
                if (it is Number) confidenceTimeoutMs = it.toLong() 
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to update configuration: ${e.message}")
        }
    }
    
    /**
     * Validate configuration values
     */
    fun validateAndCorrect(): Boolean {
        var corrected = false
        
        // Ensure GPS interval is reasonable
        if (gpsIntervalMs < MIN_GPS_INTERVAL_MS || gpsIntervalMs > MAX_GPS_INTERVAL_MS) {
            gpsIntervalMs = DEFAULT_GPS_INTERVAL_MS
            corrected = true
        }
        
        // Ensure accuracy threshold is reasonable
        if (gpsAccuracyThreshold < MIN_ACCURACY_THRESHOLD || gpsAccuracyThreshold > MAX_ACCURACY_THRESHOLD) {
            gpsAccuracyThreshold = DEFAULT_GPS_ACCURACY_THRESHOLD
            corrected = true
        }
        
        // Ensure confidence points is reasonable
        if (confidencePoints < MIN_CONFIDENCE_POINTS || confidencePoints > MAX_CONFIDENCE_POINTS) {
            confidencePoints = DEFAULT_CONFIDENCE_POINTS
            corrected = true
        }
        
        // Ensure min interval is less than main interval
        if (minUpdateIntervalMs >= gpsIntervalMs) {
            minUpdateIntervalMs = gpsIntervalMs / MIN_UPDATE_INTERVAL_FACTOR
            corrected = true
        }
        
        // Ensure max delay is greater than main interval
        if (maxUpdateDelayMs <= gpsIntervalMs) {
            maxUpdateDelayMs = gpsIntervalMs * MAX_UPDATE_DELAY_FACTOR
            corrected = true
        }
        
        if (corrected) {
            Log.w(TAG, "Configuration values corrected")
        }
        
        return !corrected
    }
    
    /**
     * Log current configuration for debugging
     */
    fun logCurrentConfig() {
    }
}