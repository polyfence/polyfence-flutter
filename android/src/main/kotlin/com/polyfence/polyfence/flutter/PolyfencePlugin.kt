package com.polyfence.polyfence.flutter

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.annotation.NonNull
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import com.polyfence.polyfence.core.LocationTracker
import com.polyfence.polyfence.core.PolyfenceErrorManager
import com.polyfence.polyfence.core.PolyfenceDebugCollector
import com.polyfence.polyfence.configuration.SmartGpsConfig
import com.polyfence.polyfence.configuration.SmartGpsConfigFactory
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import android.util.Log
import java.util.Locale

/**
 * Clean Flutter plugin bridge
 * Single responsibility: Flutter ↔ LocationTracker communication
 */
class PolyfencePlugin: FlutterPlugin, MethodCallHandler, ActivityAware {
    
    companion object {
        private const val METHOD_CHANNEL = "polyfence"
        private const val LOCATION_CHANNEL = "polyfence/location"
        private const val GEOFENCE_CHANNEL = "polyfence/geofence"
        private const val PERFORMANCE_CHANNEL = "polyfence/performance"
        private const val PREFS_NAME = "polyfence_state"
        private const val KEY_TRACKING_ENABLED = "tracking_enabled"
        
        // Separate event sinks
        private var locationSink: EventChannel.EventSink? = null
        private var geofenceSink: EventChannel.EventSink? = null
        private var performanceSink: EventChannel.EventSink? = null
        private var methodChannelRef: MethodChannel? = null

        fun getMethodChannel(): MethodChannel? = methodChannelRef
        
        // Tracking state management
        fun isTrackingEnabled(context: Context): Boolean {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            return prefs.getBoolean(KEY_TRACKING_ENABLED, false)
        }
        
        fun setTrackingEnabled(context: Context, enabled: Boolean) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().putBoolean(KEY_TRACKING_ENABLED, enabled).apply()
        }

        private fun buildStatusPayload(context: Context): Map<String, Any?> {
            val tracking = isTrackingEnabled(context)
            val zonesCount = try {
                val persistence = com.polyfence.polyfence.core.ZonePersistence(context)
                persistence.getZoneCount()
            } catch (e: Exception) { 0 }
            return mapOf(
                "type" to "status",
                "trackingEnabled" to tracking,
                "zonesCount" to zonesCount,
                "profile" to null, // optional, filled in future phases
                "lastAccuracy" to null,
                "timestamp" to System.currentTimeMillis()
            )
        }
        
        /**
         * Send location updates to dedicated location channel
         */
        fun sendLocationUpdate(locationData: Map<String, Any>) {
            locationSink?.success(locationData)
        }
        
        /**
         * Send geofence events to dedicated geofence channel
         * Includes GPS coordinates for apps that need to sync events with backend APIs
         */
        fun sendGeofenceEvent(
            zoneId: String,
            zoneName: String,
            eventType: String,
            latitude: Double,
            longitude: Double,
            detectionTimeMs: Double = 0.0,
            gpsAccuracy: Double = 0.0
        ) {
            val event = mapOf(
                "zoneId" to zoneId,
                "zoneName" to zoneName,
                "eventType" to eventType,
                "timestamp" to System.currentTimeMillis(),
                "latitude" to latitude,
                "longitude" to longitude,
                "detectionTimeMs" to detectionTimeMs,
                "gpsAccuracy" to gpsAccuracy
            )
            geofenceSink?.success(event)
        }

        /** Send status to performance channel */
        fun sendStatus(context: Context) {
            val payload = buildStatusPayload(context)
            performanceSink?.success(payload)
        }
        
        /**
         * Send performance events to dedicated performance channel
         */
        fun sendPerformanceEvent(event: Map<String, Any>) {
            performanceSink?.success(event)
        }

    }
    
    private lateinit var methodChannel: MethodChannel
    private lateinit var locationChannel: EventChannel
    private lateinit var geofenceChannel: EventChannel
    private lateinit var performanceChannel: EventChannel
    private lateinit var context: Context
    
    
    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        
        // Initialize error manager
        PolyfenceErrorManager.initialize(flutterPluginBinding.binaryMessenger)
        
        // Setup method channel
        methodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, METHOD_CHANNEL)
        methodChannelRef = methodChannel
        methodChannel.setMethodCallHandler(this)
        
        
        // Setup location event channel
        locationChannel = EventChannel(flutterPluginBinding.binaryMessenger, LOCATION_CHANNEL)
        locationChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                locationSink = events
            }
            override fun onCancel(arguments: Any?) {
                locationSink = null
            }
        })
        
        // Setup geofence event channel
        geofenceChannel = EventChannel(flutterPluginBinding.binaryMessenger, GEOFENCE_CHANNEL)
        geofenceChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                geofenceSink = events
            }
            override fun onCancel(arguments: Any?) {
                geofenceSink = null
            }
        })
        
        // Setup performance event channel
        performanceChannel = EventChannel(flutterPluginBinding.binaryMessenger, PERFORMANCE_CHANNEL)
        performanceChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                performanceSink = events
            }
            override fun onCancel(arguments: Any?) {
                performanceSink = null
            }
        })

    }
    
    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "initialize" -> {
                // Extract arguments from Flutter
                val args = call.arguments<Map<String, Any>>()
                val configDict = args?.get("config") as? Map<String, Any>
                
                // Extract plugin version from config if provided
                val version = configDict?.get("pluginVersion") as? String
                if (version != null) {
                    PolyfenceDebugCollector.setPluginVersion(version)
                }
                
                // Handle disableAlertNotifications config
                val disableAlerts = configDict?.get("disableAlertNotifications") as? Boolean ?: false
                LocationTracker.setAlertNotificationsEnabled(!disableAlerts)
                
                result.success(null)
            }
            
            "startTracking" -> {
                setTrackingEnabled(context, true)
                startLocationTracking()
                sendStatus(context)
                result.success(null)
            }
            
            "stopTracking" -> {
                setTrackingEnabled(context, false)
                stopLocationTracking()
                sendStatus(context)
                result.success(null)
            }
            
            "addZone" -> {
                val zoneData = call.arguments as? Map<String, Any>
                if (zoneData != null) {
                    addZone(zoneData)
                    sendStatus(context)
                    result.success(null)
                } else {
                    result.error("INVALID_ZONE", "Zone data is required", null)
                }
            }
            
            "removeZone" -> {
                val zoneId = call.argument<String>("zoneId")
                if (zoneId != null) {
                    removeZone(zoneId)
                    sendStatus(context)
                    result.success(null)
                } else {
                    result.error("INVALID_ZONE_ID", "Zone ID is required", null)
                }
            }
            
            "clearAllZones" -> {
                clearAllZones()
                sendStatus(context)
                result.success(null)
            }
            
            "requestPermissions" -> {
                result.success(hasAllRequiredPerms(context))
            }
            
            "isLocationServiceEnabled" -> {
                // Location services status checked by system
                // Service status check managed by LocationTracker
                result.success(true)
            }
            
            "getConfiguration" -> {
                val config = getConfiguration()
                result.success(config)
            }
            
            "resetConfiguration" -> {
                resetConfiguration()
                result.success(null)
            }
            
            "checkBatteryOptimization" -> {
                checkBatteryOptimization(result)
            }
            
            "requestBatteryOptimization" -> {
                requestBatteryOptimizationExemption(result)
            }
            
            "getDebugInfo" -> {
                try {
                    val debugInfo = PolyfenceDebugCollector.collectDebugInfo(context)
                    result.success(debugInfo)
                } catch (e: Exception) {
                    Log.e("PolyfencePlugin", "Failed to get debug info: ${e.message}")
                    result.error("DEBUG_INFO_FAILED", e.message, null)
                }
            }
            
            "getErrorHistory" -> {
                try {
                    val timeRangeMs = call.argument<Long>("timeRangeMs")
                    val errorTypes = call.argument<List<String>>("errorTypes")
                    val history = PolyfenceDebugCollector.getErrorHistory(timeRangeMs, errorTypes)
                    result.success(history)
                } catch (e: Exception) {
                    Log.e("PolyfencePlugin", "Failed to get error history: ${e.message}")
                    result.error("ERROR_HISTORY_FAILED", e.message, null)
                }
            }
            
            "updateConfiguration" -> {
                try {
                    val configMap = call.arguments as? Map<String, Any>
                    if (configMap != null) {
                        val smartConfig = SmartGpsConfigFactory.fromMap(configMap)
                        LocationTracker.updateSmartConfiguration(smartConfig)
                        updateConfiguration(configMap)
                        result.success(null)
                    } else {
                        result.error("INVALID_CONFIG", "Configuration data is required", null)
                    }
                } catch (e: Exception) {
                    Log.e("PolyfencePlugin", "Failed to update configuration: ${e.message}")
                    result.error("CONFIG_UPDATE_FAILED", e.message, null)
                }
            }
            
            "getCurrentConfiguration" -> {
                try {
                    val config = LocationTracker.getCurrentSmartConfiguration()
                    val configMap = SmartGpsConfigFactory.toMap(config)
                    result.success(configMap)
                } catch (e: Exception) {
                    Log.e("PolyfencePlugin", "Failed to get current configuration: ${e.message}")
                    result.error("CONFIG_GET_FAILED", e.message, null)
                }
            }

            "setAccuracyProfile" -> {
                val profileName = call.arguments as? String
                if (profileName.isNullOrBlank()) {
                    result.error("INVALID_PROFILE", "Accuracy profile is required", null)
                } else {
                    setAccuracyProfile(profileName)
                    result.success(null)
                }
            }

            else -> {
                result.notImplemented()
            }
        }
    }
    
    private fun hasAllRequiredPerms(context: Context): Boolean {
        val fine = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        val coarse = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
        val bgOk = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_BACKGROUND_LOCATION) == PackageManager.PERMISSION_GRANTED
        } else true
        // API 34 (Android 14) requires FOREGROUND_SERVICE_LOCATION permission
        // Use SDK_INT >= 34 instead of UPSIDE_DOWN_CAKE constant (not available in older SDKs)
        val fgsOk = if (Build.VERSION.SDK_INT >= 34) {
            ContextCompat.checkSelfPermission(context, Manifest.permission.FOREGROUND_SERVICE_LOCATION) == PackageManager.PERMISSION_GRANTED
        } else true
        return (fine || coarse) && bgOk && fgsOk
    }
    
    private fun startLocationTracking() {
        val intent = Intent(context, LocationTracker::class.java).apply {
            action = LocationTracker.ACTION_START_TRACKING
        }
        context.startForegroundService(intent)
    }
    
    private fun stopLocationTracking() {
        val intent = Intent(context, LocationTracker::class.java).apply {
            action = LocationTracker.ACTION_STOP_TRACKING
        }
        context.startService(intent)
    }
    
    private fun addZone(zoneData: Map<String, Any>) {
        val zoneId = zoneData["id"] as? String ?: return
        val zoneName = zoneData["name"] as? String ?: "Unknown Zone"
        
        // Persist zone even when tracking is currently OFF so it can be restored on start
        if (!isTrackingEnabled(context)) {
            try {
                val persistence = com.polyfence.polyfence.core.ZonePersistence(context)
                persistence.saveZone(zoneId, zoneName, zoneData)
            } catch (e: Exception) {
                Log.w("PolyfencePlugin", "Failed to persist zone $zoneId: ${e.message}")
            }
            // Defer adding to engine until tracking is started
            return
        }
        
        val intent = Intent(context, LocationTracker::class.java).apply {
            action = LocationTracker.ACTION_ADD_ZONE
            putExtra("zoneId", zoneId)
            putExtra("zoneName", zoneName)
            putExtra("zoneData", HashMap(zoneData))
        }
        context.startService(intent)
    }
    
    private fun removeZone(zoneId: String) {
        val intent = Intent(context, LocationTracker::class.java).apply {
            action = LocationTracker.ACTION_REMOVE_ZONE
            putExtra("zoneId", zoneId)
        }
        context.startService(intent)
    }
    
    private fun clearAllZones() {
        val intent = Intent(context, LocationTracker::class.java).apply {
            action = LocationTracker.ACTION_CLEAR_ZONES
        }
        context.startService(intent)
    }

    private fun updateConfiguration(configMap: Map<String, Any>) {
        val intent = Intent(context, LocationTracker::class.java).apply {
            action = LocationTracker.ACTION_UPDATE_CONFIG
            putExtra("config", HashMap(configMap))
        }
        context.startService(intent)
    }

    private fun getConfiguration(): Map<String, Any> {
        val config = LocationTracker.getCurrentSmartConfiguration()
        return SmartGpsConfigFactory.toMap(config)
    }

    private fun resetConfiguration() {
        val intent = Intent(context, LocationTracker::class.java).apply {
            action = "RESET_CONFIG"
        }
        context.startService(intent)
    }

    private fun setAccuracyProfile(profileName: String) {
        val normalized = profileName
            .trim()
            .uppercase(Locale.US)
            .replace(Regex("[^A-Z0-9]"), "")

        val targetProfile = SmartGpsConfig.AccuracyProfile.values().firstOrNull { profile ->
            profile.name.uppercase(Locale.US).replace("_", "") == normalized
        } ?: SmartGpsConfig.AccuracyProfile.MAX_ACCURACY

        val currentConfig = LocationTracker.getCurrentSmartConfiguration()
        val updatedConfig = currentConfig.copy(accuracyProfile = targetProfile)

        LocationTracker.updateSmartConfiguration(updatedConfig)
        val configMap = SmartGpsConfigFactory.toMap(updatedConfig)
        updateConfiguration(configMap)
    }
    
    // Battery Optimization Methods
    
    private fun checkBatteryOptimization(result: Result) {
        try {
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            val isOptimized = powerManager.isIgnoringBatteryOptimizations(context.packageName)
            
            val resultMap = mapOf(
                "isOptimized" to isOptimized,
                "canRequest" to canRequestBatteryOptimization()
            )
            
            // Report battery optimization status to developer error stream
            if (!isOptimized) {
                PolyfenceErrorManager.reportBatteryError(
                    context, 
                    "battery_optimization_required",
                    "Battery optimization is enabled and may affect background location tracking"
                )
            }
            
            result.success(resultMap)
        } catch (e: Exception) {
            Log.e("PolyfencePlugin", "Failed to check battery optimization: ${e.message}")
            PolyfenceErrorManager.reportError(
                "battery_check_failed",
                "Failed to check battery optimization status: ${e.message}",
                mapOf("platform" to "android", "error" to (e.message ?: "Unknown error"))
            )
            result.error("BATTERY_CHECK_FAILED", e.message, null)
        }
    }
    
    private fun requestBatteryOptimizationExemption(result: Result) {
        try {
            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                data = Uri.parse("package:${context.packageName}")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            
            context.startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            Log.e("PolyfencePlugin", "Failed to request battery optimization exemption: ${e.message}")
            result.error("BATTERY_REQUEST_FAILED", e.message, null)
        }
    }
    
    private fun canRequestBatteryOptimization(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            powerManager.isIgnoringBatteryOptimizations(context.packageName).not()
        } else {
            false
        }
    }
    
    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        locationChannel.setStreamHandler(null)
        geofenceChannel.setStreamHandler(null)
        locationSink = null
        geofenceSink = null
    }
    
    // ActivityAware implementation - minimal for now
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {}
    override fun onDetachedFromActivityForConfigChanges() {}
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {}
    override fun onDetachedFromActivity() {}
}
