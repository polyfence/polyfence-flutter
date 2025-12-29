package com.polyfence.polyfence.core

import android.content.Context
import android.content.pm.PackageManager
import android.location.LocationManager as AndroidLocationManager
import android.os.Build
import android.os.PowerManager
import android.os.Process
import android.os.Debug
import androidx.core.app.ActivityCompat
import android.Manifest
import java.io.RandomAccessFile
import java.util.concurrent.ConcurrentHashMap

/**
 * Collects comprehensive debug information for developers
 * Integrates with existing analytics and error systems
 */
class PolyfenceDebugCollector {
    companion object {
        private val performanceMetrics = ConcurrentHashMap<String, Any>()
        private val errorHistory = mutableListOf<Map<String, Any>>()
        private var sessionStartTime = System.currentTimeMillis()
        private var lastLocationUpdateTime = 0L
        private var lastKnownAccuracy = -1.0
        private var locationUpdateCount = 0
        private var zoneDetectionCount = 0
        private var totalDetectionLatency = 0.0
        private var restartCount = 0
        private var pluginVersion: String? = null // Stored from Flutter during initialization
        
        fun collectDebugInfo(context: Context): Map<String, Any> {
            return mapOf(
                "systemStatus" to collectSystemStatus(context),
                "performance" to collectPerformanceMetrics(),
                "battery" to collectBatteryMetrics(context),
                "zones" to collectZoneStatus(),
                "recentErrors" to getRecentErrors()
            )
        }
        
        private fun collectSystemStatus(context: Context): Map<String, Any> {
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            val locationManager = context.getSystemService(Context.LOCATION_SERVICE) as AndroidLocationManager
            
            return mapOf(
                "isLocationPermissionGranted" to hasLocationPermission(context),
                "isBackgroundLocationEnabled" to hasBackgroundLocationPermission(context),
                "isBatteryOptimizationDisabled" to powerManager.isIgnoringBatteryOptimizations(context.packageName),
                "isGpsEnabled" to isGpsEnabled(locationManager),
                "isWakeLockAcquired" to isWakeLockAcquired(),
                "lastKnownAccuracy" to lastKnownAccuracy,
                "lastLocationUpdate" to lastLocationUpdateTime,
                "platformVersion" to Build.VERSION.RELEASE,
                "pluginVersion" to getPluginVersion()
            )
        }
        
        private fun collectPerformanceMetrics(): Map<String, Any> {
            val runtime = Runtime.getRuntime()
            val usedMemory = (runtime.totalMemory() - runtime.freeMemory()) / 1024 / 1024
            
            return mapOf(
                "uptime" to (System.currentTimeMillis() - sessionStartTime),
                "totalLocationUpdates" to locationUpdateCount,
                "totalZoneDetections" to zoneDetectionCount,
                "averageDetectionLatency" to if (zoneDetectionCount > 0) totalDetectionLatency / zoneDetectionCount else 0.0,
                "memoryUsageMB" to usedMemory.toInt(),
                "cpuUsagePercent" to getCpuUsage(),
                "restartCount" to restartCount
            )
        }
        
        private fun collectBatteryMetrics(context: Context): Map<String, Any> {
            val batteryManager = context.getSystemService(Context.BATTERY_SERVICE) as android.os.BatteryManager
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            
            return mapOf(
                "estimatedHourlyDrain" to estimateBatteryDrain(),
                "gpsActiveTimePercent" to calculateGpsActiveTimePercent(),
                "wakeUpCount" to getWakeUpCount(),
                "isCharging" to isCharging(batteryManager),
                "batteryLevel" to getBatteryLevel(batteryManager),
                "totalActiveTime" to (System.currentTimeMillis() - sessionStartTime)
            )
        }
        
        private fun collectZoneStatus(): Map<String, Any> {
            // This would integrate with the actual zone management system
            return mapOf(
                "activeZones" to 0, // Would get from actual zone manager
                "circleZones" to 0,
                "polygonZones" to 0,
                "lastZoneUpdate" to System.currentTimeMillis(),
                "zoneEventCounts" to emptyMap<String, Int>()
            )
        }
        
        private fun getRecentErrors(): List<Map<String, Any>> {
            return errorHistory.takeLast(10) // Last 10 errors
        }
        
        fun recordLocationUpdate(accuracy: Double) {
            lastKnownAccuracy = accuracy
            lastLocationUpdateTime = System.currentTimeMillis()
            locationUpdateCount++
        }
        
        fun recordZoneDetection(latencyMs: Long) {
            zoneDetectionCount++
            totalDetectionLatency += latencyMs
        }
        
        fun recordError(errorType: String, message: String, context: Map<String, Any> = emptyMap()) {
            val errorEntry = mapOf(
                "type" to errorType,
                "message" to message,
                "timestamp" to System.currentTimeMillis(),
                "context" to context
            )
            errorHistory.add(errorEntry)
            
            // Keep only last 100 errors
            if (errorHistory.size > 100) {
                errorHistory.removeAt(0)
            }
        }
        
        fun recordRestart() {
            restartCount++
        }
        
        fun getErrorHistory(timeRangeMs: Long?, errorTypes: List<String>?): List<Map<String, Any>> {
            var filteredErrors = errorHistory.toMutableList()
            
            // Filter by time range
            if (timeRangeMs != null) {
                val cutoffTime = System.currentTimeMillis() - timeRangeMs
                filteredErrors = filteredErrors.filter { 
                    (it["timestamp"] as Long) >= cutoffTime 
                }.toMutableList()
            }
            
            // Filter by error types
            if (errorTypes != null && errorTypes.isNotEmpty()) {
                filteredErrors = filteredErrors.filter { 
                    errorTypes.contains(it["type"])
                }.toMutableList()
            }
            
            return filteredErrors
        }
        
        // Helper methods
        
        private fun hasLocationPermission(context: Context): Boolean {
            return ActivityCompat.checkSelfPermission(
                context, Manifest.permission.ACCESS_FINE_LOCATION
            ) == PackageManager.PERMISSION_GRANTED ||
            ActivityCompat.checkSelfPermission(
                context, Manifest.permission.ACCESS_COARSE_LOCATION
            ) == PackageManager.PERMISSION_GRANTED
        }
        
        private fun hasBackgroundLocationPermission(context: Context): Boolean {
            return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                ActivityCompat.checkSelfPermission(
                    context, Manifest.permission.ACCESS_BACKGROUND_LOCATION
                ) == PackageManager.PERMISSION_GRANTED
            } else {
                true
            }
        }
        
        private fun isGpsEnabled(locationManager: AndroidLocationManager): Boolean {
            return locationManager.isProviderEnabled(AndroidLocationManager.GPS_PROVIDER) ||
                   locationManager.isProviderEnabled(AndroidLocationManager.NETWORK_PROVIDER)
        }
        
        private fun isWakeLockAcquired(): Boolean {
            // This would check if our wake lock is currently held
            // For now, return false as we don't have direct access to the wake lock instance
            return false
        }
        
        /**
         * Set plugin version from Flutter (called during initialization)
         */
        fun setPluginVersion(version: String) {
            pluginVersion = version
        }
        
        private fun getPluginVersion(): String {
            return pluginVersion ?: "unknown" // Use stored version from Flutter, fallback to "unknown"
        }
        
        private fun getCpuUsage(): Double {
            return try {
                val reader = RandomAccessFile("/proc/stat", "r")
                val load = reader.readLine()
                reader.close()
                
                val toks = load.split(" ".toRegex()).dropLastWhile { it.isEmpty() }.toTypedArray()
                val idle1 = toks[4].toLong()
                val cpu1 = toks[1].toLong() + toks[2].toLong() + toks[3].toLong() + toks[5].toLong() + toks[6].toLong() + toks[7].toLong() + toks[8].toLong()
                
                Thread.sleep(360)
                
                val reader2 = RandomAccessFile("/proc/stat", "r")
                val load2 = reader2.readLine()
                reader2.close()
                
                val toks2 = load2.split(" ".toRegex()).dropLastWhile { it.isEmpty() }.toTypedArray()
                val idle2 = toks2[4].toLong()
                val cpu2 = toks2[1].toLong() + toks2[2].toLong() + toks2[3].toLong() + toks2[5].toLong() + toks2[6].toLong() + toks2[7].toLong() + toks2[8].toLong()
                
                val cpuUsage = (cpu2 - cpu1).toDouble() / ((cpu2 + idle2) - (cpu1 + idle1)) * 100.0
                cpuUsage.coerceIn(0.0, 100.0)
            } catch (e: Exception) {
                0.0
            }
        }
        
        private fun estimateBatteryDrain(): Double {
            // Simple estimation based on GPS usage
            val gpsActiveTime = (System.currentTimeMillis() - sessionStartTime) / 1000.0 / 3600.0 // hours
            return gpsActiveTime * 5.0 // Estimated 5% per hour for GPS
        }
        
        private fun calculateGpsActiveTimePercent(): Int {
            val totalTime = System.currentTimeMillis() - sessionStartTime
            val gpsActiveTime = totalTime // Assume GPS is always active when tracking
            return ((gpsActiveTime.toDouble() / totalTime) * 100).toInt()
        }
        
        private fun getWakeUpCount(): Int {
            // This would track wake-up events
            return 0
        }
        
        private fun isCharging(batteryManager: android.os.BatteryManager): Boolean {
            return batteryManager.isCharging
        }
        
        private fun getBatteryLevel(batteryManager: android.os.BatteryManager): Int {
            return batteryManager.getIntProperty(android.os.BatteryManager.BATTERY_PROPERTY_CAPACITY)
        }
    }
}
