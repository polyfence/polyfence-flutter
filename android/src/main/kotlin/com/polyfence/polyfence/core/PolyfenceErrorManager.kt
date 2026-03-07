package com.polyfence.polyfence.core

import android.content.Context
import android.os.PowerManager
import android.util.Log
import java.util.UUID

/**
 * Manages error reporting to developers.
 * Framework-agnostic — receives a plain callback from the bridge layer.
 */
class PolyfenceErrorManager {
    companion object {
        private const val TAG = "PolyfenceErrorManager"
        private var errorSink: ((Map<String, Any>) -> Unit)? = null

        fun initialize(errorCallback: (Map<String, Any>) -> Unit) {
            errorSink = errorCallback
            Log.d(TAG, "Error callback registered")
        }

        fun dispose() {
            errorSink = null
            Log.d(TAG, "Error callback cleared")
        }

        fun reportError(
            type: String,
            message: String,
            context: Map<String, Any> = emptyMap(),
            correlationId: String? = null
        ) {
            val errorMap = mapOf(
                "type" to type,
                "message" to message,
                "context" to context,
                "timestamp" to System.currentTimeMillis(),
                "correlationId" to (correlationId ?: UUID.randomUUID().toString())
            )

            // Send to developer error stream
            errorSink?.invoke(errorMap)
            Log.d(TAG, "Error reported: $type - $message")
        }
        
        fun reportGpsError(context: Context, errorType: String, details: String = "") {
            val contextMap = mutableMapOf<String, Any>(
                "platform" to "android",
                "details" to details
            )
            
            // Add battery optimization status if available
            try {
                val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                contextMap["batteryOptimizationDisabled"] = 
                    powerManager.isIgnoringBatteryOptimizations(context.packageName)
            } catch (e: Exception) {
                Log.w(TAG, "Could not check battery optimization status: ${e.message}")
            }
            
            reportError(
                type = errorType,
                message = getErrorMessage(errorType, details),
                context = contextMap
            )
        }
        
        fun reportServiceError(errorType: String, details: String = "") {
            val contextMap = mapOf(
                "platform" to "android",
                "details" to details
            )
            
            reportError(
                type = errorType,
                message = getErrorMessage(errorType, details),
                context = contextMap
            )
        }
        
        fun reportBatteryError(context: Context, errorType: String, details: String = "") {
            val contextMap = mapOf(
                "platform" to "android",
                "details" to details,
                "batteryOptimizationRequired" to true
            )
            
            reportError(
                type = errorType,
                message = getErrorMessage(errorType, details),
                context = contextMap
            )
        }
        
        private fun getErrorMessage(errorType: String, details: String): String {
            return when (errorType) {
                "gps_timeout" -> "GPS signal timeout - location services may be disabled or weak signal"
                "gps_permission_denied" -> "Location permission was denied - please grant location access"
                "gps_service_disabled" -> "Location services are disabled - please enable GPS"
                "gps_accuracy_poor" -> "GPS accuracy is poor - may affect geofence detection reliability"
                "service_start_failed" -> "Failed to start location tracking service"
                "service_killed" -> "Location service was terminated by system - may need battery optimization bypass"
                "service_restart_failed" -> "Failed to restart location service after crash"
                "battery_optimization_required" -> "Battery optimization bypass required for reliable background operation"
                "low_battery" -> "Low battery detected - location tracking may be limited"
                "zone_validation_failed" -> "Zone validation failed: $details"
                "zone_storage_failed" -> "Failed to store zone data: $details"
                "zone_load_failed" -> "Failed to load zone data: $details"
                "network_timeout" -> "Network timeout - analytics upload may be delayed"
                "analytics_upload_failed" -> "Failed to upload analytics data: $details"
                "permission_revoked" -> "Location permission was revoked while tracking"
                "memory_low" -> "Low memory detected - may affect performance"
                else -> "Unknown error occurred: $errorType - $details"
            }
        }
    }
}
