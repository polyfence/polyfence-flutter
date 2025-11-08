package com.polyfence.polyfence.utils

import android.content.Context
import android.content.Intent
import android.location.LocationManager as AndroidLocationManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.app.ActivityCompat
import android.Manifest
import com.polyfence.polyfence.core.PolyfenceErrorManager

/**
 * Handles error recovery and resilience for Polyfence
 * Single responsibility: Monitor and recover from failures
 */
class PolyfenceErrorRecovery(private val context: Context) {
    
    companion object {
        private const val TAG = "PolyfenceErrorRecovery"
        private const val GPS_CHECK_INTERVAL = 30000L // 30 seconds
        private const val PERMISSION_CHECK_INTERVAL = 60000L // 1 minute
        private const val MAX_RESTART_ATTEMPTS = 3
        private const val RESTART_COOLDOWN = 300000L // 5 minutes
    }
    
    private var isMonitoring = false
    private var restartAttempts = 0
    private var lastRestartTime = 0L
    private val recoveryHandler = Handler(Looper.getMainLooper())
    
    // Recovery callbacks
    private var onGpsFailure: (() -> Unit)? = null
    private var onPermissionLost: (() -> Unit)? = null
    private var onServiceRestart: (() -> Unit)? = null
    
    /**
     * Start monitoring for errors
     */
    fun startMonitoring(
        onGpsFailure: () -> Unit,
        onPermissionLost: () -> Unit,
        onServiceRestart: () -> Unit
    ) {
        if (isMonitoring) return
        
        this.onGpsFailure = onGpsFailure
        this.onPermissionLost = onPermissionLost
        this.onServiceRestart = onServiceRestart
        
        isMonitoring = true
        scheduleChecks()
        
    }
    
    /**
     * Stop monitoring
     */
    fun stopMonitoring() {
        isMonitoring = false
        recoveryHandler.removeCallbacksAndMessages(null)
    }
    
    /**
     * Handle GPS service failures
     */
    fun handleGpsFailure() {
        Log.w(TAG, "GPS failure detected - attempting recovery")
        
        if (isLocationServiceEnabled()) {
            onGpsFailure?.invoke()
        } else {
            Log.e(TAG, "Location services disabled - cannot recover GPS")
            // Report to developer error stream
            PolyfenceErrorManager.reportGpsError(context, "gps_service_disabled")
            // Could notify user or attempt to open location settings
        }
    }
    
    /**
     * Handle permission revocation
     */
    fun handlePermissionLoss() {
        Log.w(TAG, "Location permission lost - stopping tracking")
        // Report to developer error stream
        PolyfenceErrorManager.reportGpsError(context, "gps_permission_denied")
        onPermissionLost?.invoke()
    }
    
    /**
     * Handle service crashes/kills
     */
    fun handleServiceCrash() {
        val currentTime = System.currentTimeMillis()
        
        // Prevent restart spam
        if (currentTime - lastRestartTime < RESTART_COOLDOWN) {
            Log.w(TAG, "Service restart cooldown active - skipping restart")
            return
        }
        
        if (restartAttempts >= MAX_RESTART_ATTEMPTS) {
            Log.e(TAG, "Max restart attempts reached - service restart disabled")
            // Report to developer error stream
            PolyfenceErrorManager.reportServiceError("service_restart_failed", "Max restart attempts reached")
            return
        }
        
        restartAttempts++
        lastRestartTime = currentTime
        
        Log.w(TAG, "Service crash detected - attempting restart (attempt $restartAttempts)")
        
        // Report to developer error stream
        PolyfenceErrorManager.reportServiceError("service_killed", "Service crashed, attempting restart")
        
        // Delayed restart to avoid immediate crash loop
        recoveryHandler.postDelayed({
            onServiceRestart?.invoke()
        }, 5000) // 5 second delay
    }
    
    /**
     * Reset restart attempts (call when service runs successfully for a while)
     */
    fun resetRestartAttempts() {
        restartAttempts = 0
    }
    
    /**
     * Check if location services are enabled
     */
    fun isLocationServiceEnabled(): Boolean {
        return try {
            val locationManager = context.getSystemService(Context.LOCATION_SERVICE) as AndroidLocationManager
            locationManager.isProviderEnabled(AndroidLocationManager.GPS_PROVIDER) ||
            locationManager.isProviderEnabled(AndroidLocationManager.NETWORK_PROVIDER)
        } catch (e: Exception) {
            Log.e(TAG, "Error checking location services: ${e.message}")
            false
        }
    }
    
    /**
     * Check if location permissions are granted
     */
    fun hasLocationPermissions(): Boolean {
        return try {
            val fineLocation = ActivityCompat.checkSelfPermission(
                context, Manifest.permission.ACCESS_FINE_LOCATION
            ) == android.content.pm.PackageManager.PERMISSION_GRANTED
            
            val coarseLocation = ActivityCompat.checkSelfPermission(
                context, Manifest.permission.ACCESS_COARSE_LOCATION
            ) == android.content.pm.PackageManager.PERMISSION_GRANTED
            
            val backgroundLocation = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                ActivityCompat.checkSelfPermission(
                    context, Manifest.permission.ACCESS_BACKGROUND_LOCATION
                ) == android.content.pm.PackageManager.PERMISSION_GRANTED
            } else {
                true
            }
            
            (fineLocation || coarseLocation) && backgroundLocation
        } catch (e: Exception) {
            Log.e(TAG, "Error checking permissions: ${e.message}")
            false
        }
    }
    
    /**
     * Get system health status
     */
    fun getSystemStatus(): SystemStatus {
        return SystemStatus(
            gpsEnabled = isLocationServiceEnabled(),
            permissionsGranted = hasLocationPermissions(),
            restartAttempts = restartAttempts,
            isMonitoring = isMonitoring
        )
    }
    
    // Private methods
    
    private fun scheduleChecks() {
        if (!isMonitoring) return
        
        // Schedule GPS check
        recoveryHandler.postDelayed({
            performGpsCheck()
            scheduleChecks() // Reschedule
        }, GPS_CHECK_INTERVAL)
        
        // Schedule permission check
        recoveryHandler.postDelayed({
            performPermissionCheck()
        }, PERMISSION_CHECK_INTERVAL)
    }
    
    private fun performGpsCheck() {
        if (!isLocationServiceEnabled()) {
            handleGpsFailure()
        }
    }
    
    private fun performPermissionCheck() {
        if (!hasLocationPermissions()) {
            handlePermissionLoss()
        }
    }
    
    /**
     * System status data class
     */
    data class SystemStatus(
        val gpsEnabled: Boolean,
        val permissionsGranted: Boolean,
        val restartAttempts: Int,
        val isMonitoring: Boolean
    )
}