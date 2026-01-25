package com.polyfence.polyfence.configuration

import android.os.Build
import android.util.Log
import com.google.android.gms.location.Priority
import java.util.Locale

/**
 * Smart GPS Configuration System for Polyfence
 * Provides flexible GPS accuracy/battery profiles for different use cases
 */
data class SmartGpsConfig(
    val accuracyProfile: AccuracyProfile = AccuracyProfile.BALANCED,  // P2: Changed from MAX_ACCURACY for better battery
    val updateStrategy: UpdateStrategy = UpdateStrategy.CONTINUOUS,
    val proximitySettings: ProximitySettings? = null,
    val movementSettings: MovementSettings? = null,
    val batterySettings: BatterySettings? = null,
    val enableDebugLogging: Boolean = false
) {
    
    enum class AccuracyProfile {
        MAX_ACCURACY,      // Current behavior - highest accuracy, highest battery
        BALANCED,          // Balanced accuracy/battery for most use cases
        BATTERY_OPTIMAL,   // Prioritizes battery life over precision
        ADAPTIVE          // Automatically adjusts based on context
    }
    
    enum class UpdateStrategy {
        CONTINUOUS,        // Current behavior - regular intervals
        PROXIMITY_BASED,   // Adjust frequency based on zone distance
        MOVEMENT_BASED,    // Adjust based on device movement
        INTELLIGENT        // Combine proximity + movement + battery awareness
    }
    
    /**
     * Get Android LocationRequest priority based on accuracy profile
     */
    fun getLocationPriority(): Int = when (accuracyProfile) {
        AccuracyProfile.MAX_ACCURACY -> Priority.PRIORITY_HIGH_ACCURACY
        AccuracyProfile.BALANCED -> Priority.PRIORITY_BALANCED_POWER_ACCURACY
        AccuracyProfile.BATTERY_OPTIMAL -> Priority.PRIORITY_LOW_POWER
        AccuracyProfile.ADAPTIVE -> Priority.PRIORITY_BALANCED_POWER_ACCURACY
    }
    
    /**
     * Get base update interval based on accuracy profile
     */
    fun getBaseUpdateInterval(): Long = when (accuracyProfile) {
        AccuracyProfile.MAX_ACCURACY -> 5000L      // Current behavior - 5 seconds
        AccuracyProfile.BALANCED -> 10000L         // 10 seconds
        AccuracyProfile.BATTERY_OPTIMAL -> 30000L  // 30 seconds
        AccuracyProfile.ADAPTIVE -> 10000L         // Base for adaptive
    }
    
    /**
     * Get distance filter for GPS updates in meters
     * P1: Android now has per-profile distance filter (parity with iOS)
     * Only receive updates when device moves more than this distance
     */
    fun getDistanceFilter(): Float = when (accuracyProfile) {
        AccuracyProfile.MAX_ACCURACY -> 0f       // Every update for maximum precision
        AccuracyProfile.BALANCED -> 10f          // 10 meters - good balance
        AccuracyProfile.BATTERY_OPTIMAL -> 25f   // 25 meters - prioritize battery
        AccuracyProfile.ADAPTIVE -> 10f          // 10 meters base
    }
    
    /**
     * Whether to wait for accurate location
     */
    fun shouldWaitForAccurateLocation(): Boolean = when (accuracyProfile) {
        AccuracyProfile.MAX_ACCURACY -> true
        AccuracyProfile.BALANCED -> false
        AccuracyProfile.BATTERY_OPTIMAL -> false
        AccuracyProfile.ADAPTIVE -> false
    }
    
    /**
     * Log configuration for debugging
     */
    fun logConfiguration(tag: String) {
        if (enableDebugLogging) {
            Log.d(tag, "Smart GPS Config: profile=$accuracyProfile, strategy=$updateStrategy")
            proximitySettings?.let { 
                Log.d(tag, "Proximity: near=${it.nearZoneThresholdMeters}m, far=${it.farZoneThresholdMeters}m")
            }
            movementSettings?.let {
                Log.d(tag, "Movement: stationary=${it.stationaryThresholdMs}ms, moving=${it.movingUpdateIntervalMs}ms")
            }
            batterySettings?.let {
                Log.d(tag, "Battery: low=${it.lowBatteryThreshold}%, critical=${it.criticalBatteryThreshold}%")
            }
        }
    }
}

/**
 * Proximity-based optimization settings
 */
data class ProximitySettings(
    val nearZoneThresholdMeters: Double = 500.0,
    val farZoneThresholdMeters: Double = 2000.0,
    val nearZoneUpdateIntervalMs: Long = 5000L,
    val farZoneUpdateIntervalMs: Long = 60000L
) {
    companion object {
        fun fromMap(map: Map<String, Any>): ProximitySettings {
            return ProximitySettings(
                nearZoneThresholdMeters = (map["nearZoneThresholdMeters"] as? Number)?.toDouble() ?: 500.0,
                farZoneThresholdMeters = (map["farZoneThresholdMeters"] as? Number)?.toDouble() ?: 2000.0,
                nearZoneUpdateIntervalMs = (map["nearZoneUpdateIntervalMs"] as? Number)?.toLong() ?: 5000L,
                farZoneUpdateIntervalMs = (map["farZoneUpdateIntervalMs"] as? Number)?.toLong() ?: 60000L
            )
        }
    }
    
    fun toMap(): Map<String, Any> {
        return mapOf(
            "nearZoneThresholdMeters" to nearZoneThresholdMeters,
            "farZoneThresholdMeters" to farZoneThresholdMeters,
            "nearZoneUpdateIntervalMs" to nearZoneUpdateIntervalMs,
            "farZoneUpdateIntervalMs" to farZoneUpdateIntervalMs
        )
    }
}

/**
 * Movement-based optimization settings
 */
data class MovementSettings(
    val stationaryThresholdMs: Long = 300000L,     // 5 minutes
    val movementThresholdMeters: Double = 50.0,
    val stationaryUpdateIntervalMs: Long = 120000L, // 2 minutes
    val movingUpdateIntervalMs: Long = 10000L      // 10 seconds
) {
    companion object {
        fun fromMap(map: Map<String, Any>): MovementSettings {
            return MovementSettings(
                stationaryThresholdMs = (map["stationaryThresholdMs"] as? Number)?.toLong() ?: 300000L,
                movementThresholdMeters = (map["movementThresholdMeters"] as? Number)?.toDouble() ?: 50.0,
                stationaryUpdateIntervalMs = (map["stationaryUpdateIntervalMs"] as? Number)?.toLong() ?: 120000L,
                movingUpdateIntervalMs = (map["movingUpdateIntervalMs"] as? Number)?.toLong() ?: 10000L
            )
        }
    }
    
    fun toMap(): Map<String, Any> {
        return mapOf(
            "stationaryThresholdMs" to stationaryThresholdMs,
            "movementThresholdMeters" to movementThresholdMeters,
            "stationaryUpdateIntervalMs" to stationaryUpdateIntervalMs,
            "movingUpdateIntervalMs" to movingUpdateIntervalMs
        )
    }
}

/**
 * Battery-aware optimization settings
 */
data class BatterySettings(
    val lowBatteryThreshold: Int = 20,
    val criticalBatteryThreshold: Int = 10,
    val lowBatteryUpdateIntervalMs: Long = 30000L,  // 30 seconds
    val pauseOnCriticalBattery: Boolean = true
) {
    companion object {
        fun fromMap(map: Map<String, Any>): BatterySettings {
            return BatterySettings(
                lowBatteryThreshold = (map["lowBatteryThreshold"] as? Number)?.toInt() ?: 20,
                criticalBatteryThreshold = (map["criticalBatteryThreshold"] as? Number)?.toInt() ?: 10,
                lowBatteryUpdateIntervalMs = (map["lowBatteryUpdateIntervalMs"] as? Number)?.toLong() ?: 30000L,
                pauseOnCriticalBattery = map["pauseOnCriticalBattery"] as? Boolean ?: true
            )
        }
    }
    
    fun toMap(): Map<String, Any> {
        return mapOf(
            "lowBatteryThreshold" to lowBatteryThreshold,
            "criticalBatteryThreshold" to criticalBatteryThreshold,
            "lowBatteryUpdateIntervalMs" to lowBatteryUpdateIntervalMs,
            "pauseOnCriticalBattery" to pauseOnCriticalBattery
        )
    }
}

/**
 * P5: Device detection utilities for manufacturer-specific optimizations
 */
object DeviceOptimization {
    /**
     * Check if device is Samsung (aggressive battery management)
     */
    fun isSamsungDevice(): Boolean {
        return Build.MANUFACTURER.equals("samsung", ignoreCase = true)
    }

    /**
     * Check if device has aggressive battery management (Samsung, Xiaomi, Huawei, etc.)
     */
    fun hasAggressiveBatteryManagement(): Boolean {
        val manufacturer = Build.MANUFACTURER.lowercase(Locale.US)
        return manufacturer in listOf("samsung", "xiaomi", "huawei", "oppo", "vivo", "oneplus")
    }

    /**
     * Get recommended default profile based on device manufacturer
     * Samsung and similar devices with aggressive battery management
     * should use BALANCED by default to avoid excessive drain
     */
    fun getRecommendedDefaultProfile(): SmartGpsConfig.AccuracyProfile {
        return if (hasAggressiveBatteryManagement()) {
            SmartGpsConfig.AccuracyProfile.BALANCED
        } else {
            SmartGpsConfig.AccuracyProfile.BALANCED  // Always BALANCED as new default
        }
    }

    /**
     * Log device info for debugging battery issues
     */
    fun logDeviceInfo(tag: String) {
        Log.d(tag, "Device: ${Build.MANUFACTURER} ${Build.MODEL}, Android ${Build.VERSION.RELEASE}")
        Log.d(tag, "Aggressive battery management: ${hasAggressiveBatteryManagement()}")
    }
}

/**
 * Companion object for creating SmartGpsConfig from Flutter data
 */
object SmartGpsConfigFactory {

    fun fromMap(map: Map<String, Any>): SmartGpsConfig {
        val accuracyProfile = parseEnum(
            map["accuracyProfile"] as? String,
            SmartGpsConfig.AccuracyProfile.values(),
            SmartGpsConfig.AccuracyProfile.BALANCED  // P2: Changed default fallback to BALANCED
        )
        
        val updateStrategy = parseEnum(
            map["updateStrategy"] as? String,
            SmartGpsConfig.UpdateStrategy.values(),
            SmartGpsConfig.UpdateStrategy.CONTINUOUS
        )
        
        val proximitySettings = map["proximitySettings"]?.let { 
            ProximitySettings.fromMap(it as Map<String, Any>) 
        }
        
        val movementSettings = map["movementSettings"]?.let { 
            MovementSettings.fromMap(it as Map<String, Any>) 
        }
        
        val batterySettings = map["batterySettings"]?.let { 
            BatterySettings.fromMap(it as Map<String, Any>) 
        }
        
        val enableDebugLogging = map["enableDebugLogging"] as? Boolean ?: false
        
        return SmartGpsConfig(
            accuracyProfile = accuracyProfile,
            updateStrategy = updateStrategy,
            proximitySettings = proximitySettings,
            movementSettings = movementSettings,
            batterySettings = batterySettings,
            enableDebugLogging = enableDebugLogging
        )
    }
    
    fun toMap(config: SmartGpsConfig): Map<String, Any> {
        val map = mutableMapOf<String, Any>(
            "accuracyProfile" to config.accuracyProfile.name,
            "updateStrategy" to config.updateStrategy.name,
            "enableDebugLogging" to config.enableDebugLogging
        )
        
        config.proximitySettings?.let { map["proximitySettings"] = it.toMap() }
        config.movementSettings?.let { map["movementSettings"] = it.toMap() }
        config.batterySettings?.let { map["batterySettings"] = it.toMap() }
        
        return map
    }
    
    private fun <T : Enum<T>> parseEnum(
        rawValue: String?,
        candidates: Array<T>,
        fallback: T
    ): T {
        if (rawValue.isNullOrBlank()) return fallback
        
        val normalized = rawValue
            .trim()
            .uppercase(Locale.US)
            .replace(Regex("[^A-Z0-9]"), "")
        
        return candidates.firstOrNull {
            it.name.uppercase(Locale.US).replace("_", "") == normalized
        } ?: fallback
    }
}
