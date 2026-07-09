package io.polyfence.polyfence.flutter

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.SharedPreferences
import android.location.LocationManager
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
import io.polyfence.core.LocationTracker
import io.polyfence.core.PolyfenceCoreDelegate
import io.polyfence.core.PolyfenceErrorManager
import io.polyfence.core.PolyfenceDebugCollector
import io.polyfence.core.ZonePersistence
import io.polyfence.core.configuration.ActivitySettings
import io.polyfence.core.configuration.SmartGpsConfig
import io.polyfence.core.configuration.SmartGpsConfigFactory
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
        private const val ERROR_CHANNEL = "polyfence/error"
        private const val PERFORMANCE_CHANNEL = "polyfence/performance"
        private const val PREFS_NAME = "polyfence_state"
        private const val KEY_TRACKING_ENABLED = "tracking_enabled"
        
        // Separate event sinks
        private var locationSink: EventChannel.EventSink? = null
        private var geofenceSink: EventChannel.EventSink? = null
        private var errorSink: EventChannel.EventSink? = null
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
                val persistence = ZonePersistence(context)
                persistence.getZoneCount()
            } catch (e: Exception) { 0 }
            // Populate profile + lastAccuracy from polyfence-core rather
            // than hardcoding null — otherwise consumers reading
            // status.profile and status.lastAccuracy see null regardless
            // of runtime state, which suggests data is unavailable when
            // it isn't.
            val profile = LocationTracker.getCurrentSmartConfiguration().accuracyProfile.name
            val lastAccuracy = LocationTracker.getLastKnownAccuracy()?.toDouble()
            return mapOf(
                "type" to "status",
                "trackingEnabled" to tracking,
                "zonesCount" to zonesCount,
                "profile" to profile,
                "lastAccuracy" to lastAccuracy, // null until first GPS fix
                "timestamp" to System.currentTimeMillis()
            )
        }
        
        /** Send status to performance channel */
        fun sendStatus(context: Context) {
            val payload = buildStatusPayload(context)
            performanceSink?.success(payload)
        }

    }
    
    private lateinit var methodChannel: MethodChannel
    private lateinit var locationChannel: EventChannel
    private lateinit var geofenceChannel: EventChannel
    private lateinit var errorChannel: EventChannel
    private lateinit var performanceChannel: EventChannel
    private lateinit var context: Context


    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext

        // Setup error event channel — bridges core PolyfenceErrorManager to Flutter
        errorChannel = EventChannel(flutterPluginBinding.binaryMessenger, ERROR_CHANNEL)
        errorChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                errorSink = events
                PolyfenceErrorManager.initialize { errorMap ->
                    events?.success(errorMap)
                }
                Log.d("PolyfencePlugin", "Error stream listener connected")
            }
            override fun onCancel(arguments: Any?) {
                errorSink = null
                PolyfenceErrorManager.dispose()
                Log.d("PolyfencePlugin", "Error stream listener disconnected")
            }
        })
        
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
                // Reset the persisted tracking_enabled SharedPref on every
                // fresh initialize() to defeat upgrade-poisoning. A previous
                // install that was tracking when the app was killed leaves
                // tracking_enabled=true in prefs; without this reset the
                // new install would silently resume tracking on next boot
                // without the consumer calling startTracking(). Consumers
                // must explicitly call startTracking() to set it back to
                // true.
                setTrackingEnabled(context, false)

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

                // Tag telemetry with bridge platform
                LocationTracker.setBridgePlatform("flutter")

                // Wire up delegate so core sends events back to Flutter
                LocationTracker.setPendingCoreDelegate(coreDelegate)

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
                val enabled = try {
                    val locationManager = context.getSystemService(Context.LOCATION_SERVICE) as? LocationManager
                    locationManager?.let {
                        it.isProviderEnabled(LocationManager.GPS_PROVIDER) ||
                        it.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
                    } ?: false
                } catch (e: Exception) {
                    Log.e("PolyfencePlugin", "Error checking location services: ${e.message}")
                    false
                }
                result.success(enabled)
            }
            
            "getConfiguration" -> {
                val config = getConfiguration()
                result.success(config)
            }
            
            "resetConfiguration" -> {
                // resetConfiguration routes through updateConfiguration,
                // which delegates to LocationTracker.applyConfigurationDirect.
                // The service-not-running fallback there still uses
                // startService and bubbles Android 8+ background-restriction
                // IllegalStateException. Without a try/catch the exception
                // unwinds through the MethodChannel handler and leaves the
                // Dart Future hanging. Match the RN Android
                // CONFIG_RESET_FAILED contract.
                try {
                    resetConfiguration()
                    result.success(null)
                } catch (e: Exception) {
                    Log.e("PolyfencePlugin", "Failed to reset configuration: ${e.message}")
                    result.error("CONFIG_RESET_FAILED", e.message, null)
                }
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
                        // Route only through the merge-aware Intent
                        // path. Do NOT pre-derive a SmartGpsConfig from
                        // the partial incoming map and push it via
                        // updateSmartConfiguration in parallel —
                        // SmartGpsConfigFactory.fromMap on a partial
                        // map has no way to distinguish "caller omitted
                        // this key" from "caller wants the default",
                        // so it silently resets every unspecified
                        // field (BALANCED / CONTINUOUS / null nested
                        // settings). The Intent handler in
                        // LocationTracker.updateConfigurationFromMap
                        // reads the current smartConfig, merges the
                        // incoming partial over it, then applies. iOS
                        // uses the same core merge method — cross-
                        // platform parity, no per-bridge extras
                        // cascade.
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
            
            "setAccuracyProfile" -> {
                val profileName = call.arguments as? String
                if (profileName.isNullOrBlank()) {
                    result.error("INVALID_PROFILE", "Accuracy profile is required", null)
                } else {
                    setAccuracyProfile(profileName)
                    result.success(null)
                }
            }

            "getCurrentZoneStates" -> {
                try {
                    val states = LocationTracker.getCurrentZoneStates()
                    result.success(states)
                } catch (e: Exception) {
                    Log.e("PolyfencePlugin", "Failed to get zone states: ${e.message}")
                    result.error("ZONE_STATES_FAILED", e.message, null)
                }
            }

            "getSessionTelemetry" -> {
                try {
                    val telemetry = LocationTracker.getSessionTelemetry()
                    val sessionData = HashMap<String, Any?>(telemetry)
                    sessionData["deviceCategory"] = getDeviceCategory()
                    sessionData["osVersionMajor"] = Build.VERSION.SDK_INT
                    result.success(sessionData)
                } catch (e: Exception) {
                    Log.e("PolyfencePlugin", "Failed to get session telemetry: ${e.message}")
                    result.error("TELEMETRY_FAILED", e.message, null)
                }
            }

            else -> {
                result.notImplemented()
            }
        }
    }
    
    /**
     * Returns a bucketed device category (not exact model) for ML telemetry.
     */
    private fun getDeviceCategory(): String {
        val manufacturer = Build.MANUFACTURER.lowercase(Locale.ROOT)
        val model = Build.MODEL.lowercase(Locale.ROOT)
        return when {
            manufacturer.contains("samsung") -> when {
                model.contains("sm-s9") || model.contains("sm-s24") || model.contains("sm-s23") || model.contains("sm-f") -> "samsung_flagship"
                model.contains("sm-a5") || model.contains("sm-a7") || model.contains("sm-a3") -> "samsung_mid"
                else -> "samsung_other"
            }
            manufacturer.contains("google") || manufacturer.contains("pixel") -> "google_pixel"
            manufacturer.contains("xiaomi") || manufacturer.contains("redmi") -> "xiaomi"
            manufacturer.contains("huawei") -> "huawei"
            manufacturer.contains("oneplus") -> "oneplus"
            manufacturer.contains("oppo") -> "oppo"
            manufacturer.contains("vivo") -> "vivo"
            else -> "android_other"
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
                val persistence = ZonePersistence(context)
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

    /**
     * Apply a configuration update on the running LocationTracker
     * Service. Uses core's applyConfigurationDirect helper. When the
     * Service is already running, apply is synchronous — the
     * MethodChannel result reaches Dart after the mutation lands and
     * an immediately-following getConfiguration() call observes the
     * new state without an explicit wait. When no Service instance
     * is running, applyConfigurationDirect falls back to a
     * startService Intent with the same transport as before. Read
     * after-write is NOT guaranteed on that fallback path; callers
     * that depend on immediate observability must ensure the Service
     * is running first (via initialize + startTracking).
     *
     * pendingActivitySettings is stamped up front so it survives the
     * companion static across service lifecycle in the not-running
     * fallback path.
     *
     * startService failures propagate. On Android 8+ background
     * restrictions (Doze / app-standby / battery saver) startService
     * throws IllegalStateException; swallowing would let the
     * MethodChannel resolve as success while nothing was applied.
     * Bubble instead so updateConfiguration.catchError(...) on the
     * Dart side fires.
     */
    private fun updateConfiguration(configMap: Map<String, Any>) {
        val activitySettingsMap = configMap["activitySettings"] as? Map<String, Any>
        if (activitySettingsMap != null) {
            val activitySettings = ActivitySettings.fromMap(activitySettingsMap)
            LocationTracker.setPendingActivitySettings(activitySettings)
        }

        LocationTracker.applyConfigurationDirect(context, configMap)
    }

    private fun getConfiguration(): Map<String, Any> {
        // Use the composed 12-key shape from
        // LocationTracker.getCurrentConfigurationMap rather than the
        // 6-key SmartGpsConfig.toMap shape — the five extra fields
        // (gpsAccuracyThreshold, dwellSettings, clusterSettings,
        // scheduleSettings, activitySettings) live on GeofenceEngine /
        // TrackingScheduler / the running instance and can only be
        // assembled at the LocationTracker level. Pass the plugin's
        // context so the scheduler can rehydrate its on-disk snapshot
        // when the service hasn't started yet.
        return LocationTracker.getCurrentConfigurationMap(context)
    }

    private fun resetConfiguration() {
        // Route through the same UPDATE_CONFIG + full-default-map
        // path RN Android uses so every subsystem (SmartGpsConfig +
        // dwell / cluster / schedule / activity + alert flag)
        // actually resets. LocationTracker never handled a bespoke
        // RESET_CONFIG Intent action — sending one would make
        // resetConfiguration() a silent no-op.
        val configMap = LocationTracker.buildDefaultConfigurationMap()
        updateConfiguration(configMap)
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

            // startActivity is fire-and-forget. There is no synchronous
            // mechanism on Android to observe whether the user tapped
            // Allow or Deny in the system dialog, so returning a
            // boolean outcome would be misleading. Consumers must
            // re-poll batteryOptimizationStatus() after
            // AppLifecycleState.resumed to detect what the user chose.
            context.startActivity(intent)
            result.success(null)
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
    
    // PolyfenceCoreDelegate — bridges core events to Flutter EventChannel sinks
    private val coreDelegate = object : PolyfenceCoreDelegate {
        override fun onLocationUpdate(locationData: Map<String, Any>) {
            locationSink?.success(locationData)
        }

        override fun onGeofenceEvent(eventData: Map<String, Any>) {
            geofenceSink?.success(eventData)
        }

        override fun onPerformanceEvent(performanceData: Map<String, Any>) {
            performanceSink?.success(performanceData)
        }

        override fun onError(errorData: Map<String, Any>) {
            errorSink?.success(errorData)
        }

        override fun isTrackingEnabled(): Boolean {
            return isTrackingEnabled(context)
        }
    }

    // ActivityAware implementation - minimal for now
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {}
    override fun onDetachedFromActivityForConfigChanges() {}
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {}
    override fun onDetachedFromActivity() {}
}
