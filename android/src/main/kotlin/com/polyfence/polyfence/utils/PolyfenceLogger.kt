package com.polyfence.polyfence.utils

import android.util.Log

/**
 * Standardized logging for plugin operations
 * Single responsibility: Consistent log format across components
 */
object PolyfenceLogger {
    private const val TAG = "Polyfence"
    
    fun logZoneEvent(eventType: String, zoneId: String, accuracy: Double) {
        Log.d(TAG, "ZONE_EVENT|$eventType|$zoneId|$accuracy|${System.currentTimeMillis()}")
    }

    fun logPerformance(operation: String, duration: Long) {
        Log.d(TAG, "PERF|$operation|${duration}ms")
    }
    
    fun logError(component: String, error: String) {
        Log.e(TAG, "ERROR|$component|$error")
    }
}