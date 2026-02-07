package com.polyfence.polyfence.core

import android.location.Location
import android.util.Log
import java.util.concurrent.ConcurrentHashMap
import kotlin.math.*
import kotlin.math.abs
import io.flutter.plugin.common.MethodChannel

/**
 * Core geofencing detection engine
 * Single responsibility: GPS location → zone detection → events
 */
class GeofenceEngine {
    companion object {
        private const val TAG = "GeofenceEngine"
        private const val EARTH_RADIUS_METERS = 6371000.0

        // State recovery event types
        const val EVENT_RECOVERY_ENTER = "RECOVERY_ENTER"
        const val EVENT_RECOVERY_EXIT = "RECOVERY_EXIT"

        // Dwell event type
        const val EVENT_DWELL = "DWELL"

        // Default dwell threshold (5 minutes)
        const val DEFAULT_DWELL_THRESHOLD_MS = 300000L
        
        /**
         * Calculate distance between two points using Haversine formula
         */
        private fun calculateDistance(point1: LatLng, point2: LatLng): Double {
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
    }
    
    // Thread-safe zone storage
    private val zones = ConcurrentHashMap<String, ZoneData>()
    private val zoneStates = ConcurrentHashMap<String, Boolean>()

    // Confidence tracking for zone state validation
    private val zoneConfidence = ConcurrentHashMap<String, ZoneConfidence>()

    // Dwell time tracking: zoneId -> entry timestamp (ms)
    private val zoneEntryTimes = ConcurrentHashMap<String, Long>()
    // Track which zones have already fired dwell events this session
    private val dwellEventsFired = ConcurrentHashMap<String, Boolean>()
    // Dwell threshold in milliseconds (configurable)
    private var dwellThresholdMs = DEFAULT_DWELL_THRESHOLD_MS
    // Whether dwell detection is enabled
    private var dwellEnabled = true
    
    // Configuration for validation
    private var requireConfirmation = true
    private var confirmationPoints = 2
    private var confirmationTimeoutMs = 10000L // 10 seconds
    
    // GPS accuracy threshold in meters (default: 100m for platform parity)
    private var gpsAccuracyThreshold = 100.0f

    // Zone clustering configuration
    private var clusteringEnabled = false
    private var clusterActiveRadiusMeters = 5000.0
    private var clusterRefreshDistanceMeters = 1000.0
    private var clusterCenterLat: Double? = null
    private var clusterCenterLng: Double? = null
    private val activeZoneIds = ConcurrentHashMap.newKeySet<String>()

    // Event callback - includes detection time in milliseconds
    private var eventCallback: ((String, String, Location, Double) -> Unit)? = null

    // Zone state persistence (injected by LocationTracker)
    private var zonePersistence: ZonePersistence? = null

    // Track if state was recovered from persistence on startup
    private var stateRecoveredFromPersistence = false
    
    
    /**
     * Zone confidence tracking
     */
    private data class ZoneConfidence(
        var insideCount: Int = 0,
        var outsideCount: Int = 0,
        var lastDetection: Long = 0L,
        var confirmedState: Boolean = false
    )
    
    /**
     * Add zone for monitoring
     */
    fun addZone(zoneId: String, zoneName: String, zoneData: Map<String, Any>) {
        try {
            val zone = ZoneData.fromMap(zoneId, zoneName, zoneData)
            zones[zoneId] = zone
            zoneStates[zoneId] = false // Initially outside
        } catch (e: Exception) {
            Log.e(TAG, "Failed to add zone $zoneId: ${e.message}")
            throw IllegalArgumentException("Invalid zone data for $zoneId", e)
        }
    }
    
    /**
     * Remove zone from monitoring
     */
    fun removeZone(zoneId: String) {
        zones.remove(zoneId)
        zoneStates.remove(zoneId)
        zoneConfidence.remove(zoneId)
        zoneEntryTimes.remove(zoneId)
        dwellEventsFired.remove(zoneId)

        // Remove persisted state
        zonePersistence?.removeZoneState(zoneId)
    }

    /**
     * Clear all zones
     */
    fun clearAllZones() {
        zones.clear()
        zoneStates.clear()
        zoneConfidence.clear()
        zoneEntryTimes.clear()
        dwellEventsFired.clear()

        // Clear persisted states
        zonePersistence?.clearAllZoneStates()
    }

    /**
 * Get zone name by ID
 */
fun getZoneName(zoneId: String): String? {
    return zones[zoneId]?.name
}
    
    /**
     * Enhanced configuration method
     */
    fun setValidationConfig(requireConfirmation: Boolean, confirmationPoints: Int, timeoutMs: Long = 10000L) {
        this.requireConfirmation = requireConfirmation
        this.confirmationPoints = confirmationPoints
        this.confirmationTimeoutMs = timeoutMs
    }
    
    /**
     * Set GPS accuracy threshold in meters
     * Locations with accuracy worse than this are rejected
     * Default: 100m (matches iOS for platform parity)
     */
    fun setGpsAccuracyThreshold(threshold: Float) {
        this.gpsAccuracyThreshold = threshold
    }

    /**
     * Configure dwell detection
     * @param enabled Whether dwell detection is enabled
     * @param thresholdMs How long (ms) device must stay in zone before DWELL fires
     */
    fun setDwellConfig(enabled: Boolean, thresholdMs: Long = DEFAULT_DWELL_THRESHOLD_MS) {
        this.dwellEnabled = enabled
        this.dwellThresholdMs = thresholdMs
        Log.d(TAG, "Dwell config: enabled=$enabled, threshold=${thresholdMs}ms")
    }

    /**
     * Configure zone clustering for large zone sets
     * @param enabled Whether clustering is enabled (default: false)
     * @param activeRadiusMeters Radius to check zones within (default: 5000m)
     * @param refreshDistanceMeters Distance to move before refreshing active cluster (default: 1000m)
     */
    fun setClusterConfig(enabled: Boolean, activeRadiusMeters: Double = 5000.0, refreshDistanceMeters: Double = 1000.0) {
        this.clusteringEnabled = enabled
        this.clusterActiveRadiusMeters = activeRadiusMeters
        this.clusterRefreshDistanceMeters = refreshDistanceMeters
        // Reset cluster center to force refresh on next location update
        this.clusterCenterLat = null
        this.clusterCenterLng = null
        this.activeZoneIds.clear()
        Log.d(TAG, "Cluster config: enabled=$enabled, activeRadius=${activeRadiusMeters}m, refreshDistance=${refreshDistanceMeters}m")
    }

    /**
     * Check if cluster needs to be refreshed based on movement from cluster center
     */
    private fun shouldRefreshCluster(location: Location): Boolean {
        val centerLat = clusterCenterLat ?: return true
        val centerLng = clusterCenterLng ?: return true

        val distance = calculateDistance(
            LatLng(centerLat, centerLng),
            LatLng(location.latitude, location.longitude)
        )
        return distance >= clusterRefreshDistanceMeters
    }

    /**
     * Refresh the active zone cluster around the given location
     */
    private fun refreshCluster(location: Location) {
        clusterCenterLat = location.latitude
        clusterCenterLng = location.longitude
        activeZoneIds.clear()

        val userLocation = LatLng(location.latitude, location.longitude)
        var activatedCount = 0

        zones.forEach { (zoneId, zone) ->
            val zoneCenter = zone.calculateCenter()
            val distance = calculateDistance(userLocation, zoneCenter)

            // Include zone if its center is within active radius
            // Also include zones whose boundary might intersect (add zone radius buffer)
            val effectiveRadius = clusterActiveRadiusMeters + (zone.radius ?: 0.0)
            if (distance <= effectiveRadius) {
                activeZoneIds.add(zoneId)
                activatedCount++
            }
        }

        Log.d(TAG, "Cluster refreshed at (${location.latitude}, ${location.longitude}): $activatedCount of ${zones.size} zones active")
    }

    /**
     * Get zones to check based on clustering configuration
     */
    private fun getZonesToCheck(): Map<String, ZoneData> {
        return if (clusteringEnabled && activeZoneIds.isNotEmpty()) {
            zones.filterKeys { it in activeZoneIds }
        } else {
            zones
        }
    }
    
    /**
     * Update GPS accuracy threshold
     */
    fun setAccuracyThreshold(threshold: Float) {
        // GPS accuracy threshold implementation
    }
    
    /**
     * Set callback for zone events
     * Callback receives: zoneId, eventType, location, detectionTimeMs
     */
    fun setEventCallback(callback: (String, String, Location, Double) -> Unit) {
        eventCallback = callback
    }

    /**
     * Set zone persistence for state recovery across service restarts
     */
    fun setZonePersistence(persistence: ZonePersistence) {
        this.zonePersistence = persistence
    }

    /**
     * Load persisted zone states on service restart
     * Should be called after zones are loaded but before location updates start
     */
    fun loadPersistedZoneStates() {
        val persistence = zonePersistence ?: return

        if (!persistence.hasPersistedZoneStates()) {
            Log.d(TAG, "No persisted zone states found (fresh install or data wipe)")
            stateRecoveredFromPersistence = false
            return
        }

        val persistedStates = persistence.loadZoneStates()
        if (persistedStates.isEmpty()) {
            Log.d(TAG, "Persisted zone states empty")
            stateRecoveredFromPersistence = false
            return
        }

        // Only load states for zones that are currently registered
        var loadedCount = 0
        persistedStates.forEach { (zoneId, isInside) ->
            if (zones.containsKey(zoneId)) {
                zoneStates[zoneId] = isInside
                loadedCount++
                Log.d(TAG, "Restored state for zone $zoneId: ${if (isInside) "INSIDE" else "OUTSIDE"}")
            }
        }

        stateRecoveredFromPersistence = loadedCount > 0
        Log.i(TAG, "Loaded $loadedCount persisted zone states (${persistedStates.count { it.value }} were inside)")
    }

    /**
     * Reconcile zone states with current location after service restart
     * Fires RECOVERY_ENTER/RECOVERY_EXIT events for mismatches
     * Should be called with first valid location after restart
     */
    fun reconcileZoneStates(location: Location) {
        if (!stateRecoveredFromPersistence) {
            // No persisted state - establish initial state and fire ENTER events for zones we're inside
            Log.d(TAG, "No persisted state - establishing initial state from current location")
            val checkStartTime = System.nanoTime()
            zones.forEach { (zoneId, zone) ->
                val isInside = zone.contains(location)
                zoneStates[zoneId] = isInside

                // Fire ENTER event for zones we're currently inside (fresh install behavior)
                if (isInside) {
                    val detectionTimeMs = (System.nanoTime() - checkStartTime) / 1_000_000.0
                    Log.i(TAG, "Initial state: inside zone $zoneId -> firing ENTER")
                    eventCallback?.invoke(zoneId, "ENTER", location, detectionTimeMs)
                }
            }
            persistAllZoneStates()
            return
        }

        Log.i(TAG, "Reconciling zone states with current location...")
        val checkStartTime = System.nanoTime()
        var reconciliationCount = 0

        zones.forEach { (zoneId, zone) ->
            val persistedState = zoneStates[zoneId] ?: false
            val actualState = zone.contains(location)

            if (persistedState != actualState) {
                reconciliationCount++
                zoneStates[zoneId] = actualState

                val detectionTimeMs = (System.nanoTime() - checkStartTime) / 1_000_000.0

                if (actualState) {
                    // Was outside (persisted), now inside (actual) -> fire RECOVERY_ENTER
                    Log.w(TAG, "State mismatch for zone $zoneId: was OUTSIDE, now INSIDE -> firing RECOVERY_ENTER")
                    eventCallback?.invoke(zoneId, EVENT_RECOVERY_ENTER, location, detectionTimeMs)
                } else {
                    // Was inside (persisted), now outside (actual) -> fire RECOVERY_EXIT
                    Log.w(TAG, "State mismatch for zone $zoneId: was INSIDE, now OUTSIDE -> firing RECOVERY_EXIT")
                    eventCallback?.invoke(zoneId, EVENT_RECOVERY_EXIT, location, detectionTimeMs)
                }
            }
        }

        if (reconciliationCount > 0) {
            Log.i(TAG, "Reconciled $reconciliationCount zone state mismatches")
            persistAllZoneStates()
        } else {
            Log.d(TAG, "All zone states match current location - no reconciliation needed")
        }

        stateRecoveredFromPersistence = false // Reset flag after reconciliation
    }

    /**
     * Persist all current zone states (called after reconciliation or bulk changes)
     */
    private fun persistAllZoneStates() {
        val persistence = zonePersistence ?: return
        persistence.saveZoneStates(zoneStates.toMap())
    }

    /**
     * Persist single zone state change (called on each transition)
     */
    private fun persistZoneState(zoneId: String, isInside: Boolean) {
        val persistence = zonePersistence ?: return
        persistence.saveZoneState(zoneId, isInside)
    }

    /**
     * Get current zone states for health check API
     */
    fun getCurrentZoneStates(): Map<String, Boolean> {
        return zoneStates.toMap()
    }

    /**
     * Check if state was recovered from persistence on last startup
     */
    fun wasStateRecoveredFromPersistence(): Boolean {
        return stateRecoveredFromPersistence
    }
    
    
    
    /**
     * Enhanced check location with precise timing
     */
    fun checkLocation(location: Location) {
        if (!isValidLocation(location)) {
            return
        }

        // Handle clustering: refresh active zones if needed
        if (clusteringEnabled) {
            if (shouldRefreshCluster(location)) {
                refreshCluster(location)
            }
        }

        val overallStartTime = System.nanoTime()
        val speed = if (location.hasSpeed()) location.speed * 3.6 else 0.0 // Convert m/s to km/h

        var zoneCheckCount = 0
        var totalAlgorithmTime = 0L
        var totalConfidenceTime = 0L

        // Use clustered zones if enabled, otherwise all zones
        val zonesToCheck = getZonesToCheck()

        zonesToCheck.forEach { (zoneId, zone) ->
            zoneCheckCount++
            val zoneCheckStartTime = System.nanoTime() // Start timing for this zone
            val currentState = zoneStates[zoneId] ?: false
            
            // Precise algorithm timing
            val algorithmStartTime = System.nanoTime()
            val isInside = zone.contains(location)
            val algorithmDuration = System.nanoTime() - algorithmStartTime
            totalAlgorithmTime += algorithmDuration

            // Smart validation: Use confirmation based on speed and zone characteristics
            val useConfirmation = if (requireConfirmation) {
                shouldUseConfirmation(speed, zone.radius)
            } else {
                false
            }

            val stateChanged: Boolean
            if (useConfirmation) {
                val confidenceStartTime = System.nanoTime()
                stateChanged = processWithConfidence(zoneId, zone, isInside, currentState, System.currentTimeMillis(), location, zoneCheckStartTime)
                val confidenceDuration = System.nanoTime() - confidenceStartTime
                totalConfidenceTime += confidenceDuration
            } else {
                // Original logic for immediate detection
                stateChanged = processImmediate(zoneId, zone, isInside, currentState, location, zoneCheckStartTime)
            }

        }

    }
    
    // Smart validation: Single point for obvious cases, 2-point for edge cases
    fun shouldUseConfirmation(speed: Double, zoneRadius: Double?): Boolean {
        return when {
            // Large zones always need confirmation (reduce false positives)
            zoneRadius != null && zoneRadius > 200 -> true
            
            // High speed + reasonable zones = single point OK
            speed > 40 && (zoneRadius == null || zoneRadius > 50) -> false
            
            // Default: Use 2-point for reliability
            else -> true
        }
    }
    
    /**
     * Process with confidence validation - returns true if state changed
     */
    private fun processWithConfidence(
        zoneId: String, 
        zone: ZoneData, 
        isInside: Boolean, 
        currentState: Boolean, 
        currentTime: Long,
        location: Location,
        checkStartTime: Long
    ): Boolean {
        val confidence = zoneConfidence.getOrPut(zoneId) { ZoneConfidence() }
        
        // Update confidence counters
        if (isInside) {
            confidence.insideCount++
            confidence.outsideCount = 0
        } else {
            confidence.outsideCount++
            confidence.insideCount = 0
        }
        
        confidence.lastDetection = currentTime
        
        // Check if we have enough confidence for state change
        val requiredCount = confirmationPoints
        val hasConfidence = if (isInside) {
            confidence.insideCount >= requiredCount
        } else {
            confidence.outsideCount >= requiredCount
        }
        
        // State change with confidence
        if (hasConfidence && currentState != isInside) {
            zoneStates[zoneId] = isInside
            confidence.confirmedState = isInside

            // Persist state change immediately (write-through)
            persistZoneState(zoneId, isInside)

            // Calculate detection time: from start of zone check to now (in milliseconds)
            val detectionTimeMs = (System.nanoTime() - checkStartTime) / 1_000_000.0

            val eventType = if (isInside) "ENTER" else "EXIT"
            eventCallback?.invoke(zoneId, eventType, location, detectionTimeMs)

            // Handle dwell tracking on state change
            handleDwellStateChange(zoneId, isInside, location, checkStartTime)

            // Reset confidence after successful event
            confidence.insideCount = 0
            confidence.outsideCount = 0

            return true // State changed
        }

        // Timeout: reset confidence if no consistent readings
        if (currentTime - confidence.lastDetection > confirmationTimeoutMs) {
            confidence.insideCount = 0
            confidence.outsideCount = 0
        }

        // Check for dwell even if no state change (still inside)
        if (currentState && isInside && dwellEnabled) {
            checkAndFireDwell(zoneId, location, checkStartTime)
        }

        return false // No state change
    }
    
    /**
     * Original immediate processing - returns true if state changed
     */
    private fun processImmediate(
        zoneId: String,
        zone: ZoneData,
        isInside: Boolean,
        currentState: Boolean,
        location: Location,
        checkStartTime: Long
    ): Boolean {
        if (currentState != isInside) {
            zoneStates[zoneId] = isInside

            // Persist state change immediately (write-through)
            persistZoneState(zoneId, isInside)

            // Calculate detection time: from start of zone check to now (in milliseconds)
            val detectionTimeMs = (System.nanoTime() - checkStartTime) / 1_000_000.0

            val eventType = if (isInside) "ENTER" else "EXIT"
            eventCallback?.invoke(zoneId, eventType, location, detectionTimeMs)

            // Handle dwell tracking on state change
            handleDwellStateChange(zoneId, isInside, location, checkStartTime)

            return true // State changed
        } else if (isInside && dwellEnabled) {
            // Still inside - check for dwell
            checkAndFireDwell(zoneId, location, checkStartTime)
        }
        return false // No state change
    }

    /**
     * Handle dwell tracking when zone state changes
     */
    private fun handleDwellStateChange(zoneId: String, isInside: Boolean, location: Location, checkStartTime: Long) {
        if (!dwellEnabled) return

        if (isInside) {
            // Entered zone - start tracking dwell time
            zoneEntryTimes[zoneId] = System.currentTimeMillis()
            dwellEventsFired.remove(zoneId) // Reset dwell flag for new entry
            Log.d(TAG, "Dwell tracking started for zone $zoneId")
        } else {
            // Exited zone - stop tracking dwell time
            zoneEntryTimes.remove(zoneId)
            dwellEventsFired.remove(zoneId)
            Log.d(TAG, "Dwell tracking stopped for zone $zoneId")
        }
    }

    /**
     * Check if dwell threshold reached and fire DWELL event
     */
    private fun checkAndFireDwell(zoneId: String, location: Location, checkStartTime: Long) {
        // Skip if dwell already fired for this zone entry
        if (dwellEventsFired[zoneId] == true) return

        val entryTime = zoneEntryTimes[zoneId] ?: return
        val dwellDuration = System.currentTimeMillis() - entryTime

        if (dwellDuration >= dwellThresholdMs) {
            // Mark as fired to prevent duplicate events
            dwellEventsFired[zoneId] = true

            val detectionTimeMs = (System.nanoTime() - checkStartTime) / 1_000_000.0

            Log.i(TAG, "DWELL event for zone $zoneId after ${dwellDuration}ms")
            eventCallback?.invoke(zoneId, EVENT_DWELL, location, detectionTimeMs)
        }
    }
    
    /**
     * Validate GPS location
     * Uses configurable GPS accuracy threshold (default: 100m)
     * This ensures platform parity with iOS
     */
    private fun isValidLocation(location: Location): Boolean {
        return location.hasAccuracy() && 
               location.accuracy <= gpsAccuracyThreshold &&
               location.latitude != 0.0 && 
               location.longitude != 0.0
    }
    
    /**
     * Zone data container
     */
    private data class ZoneData(
        val id: String,
        val name: String,
        val type: ZoneType,
        val center: LatLng? = null,
        val radius: Double? = null,
        val polygon: List<LatLng>? = null
    ) {
        
        fun contains(location: Location): Boolean {
            val point = LatLng(location.latitude, location.longitude)

            return when (type) {
                ZoneType.CIRCLE -> {
                    val zoneCenter = center ?: return false
                    val zoneRadius = radius ?: return false
                    val distance = calculateDistance(point, zoneCenter)
                    distance <= zoneRadius
                }
                ZoneType.POLYGON -> {
                    val zonePolygon = polygon ?: return false
                    isPointInPolygon(point, zonePolygon)
                }
            }
        }

        /**
         * Calculate the center point of this zone for clustering calculations
         * For circles: returns center
         * For polygons: returns centroid (average of all points)
         */
        fun calculateCenter(): LatLng {
            return when (type) {
                ZoneType.CIRCLE -> center ?: LatLng(0.0, 0.0)
                ZoneType.POLYGON -> {
                    val points = polygon ?: return LatLng(0.0, 0.0)
                    if (points.isEmpty()) return LatLng(0.0, 0.0)
                    val avgLat = points.sumOf { it.latitude } / points.size
                    val avgLng = points.sumOf { it.longitude } / points.size
                    LatLng(avgLat, avgLng)
                }
            }
        }
        
        
        companion object {
            fun fromMap(id: String, name: String, data: Map<String, Any>): ZoneData {
                val type = when (data["type"] as? String) {
                    "circle" -> ZoneType.CIRCLE
                    "polygon" -> ZoneType.POLYGON
                    else -> throw IllegalArgumentException("Invalid zone type")
                }
                
                return when (type) {
                    ZoneType.CIRCLE -> {
                        val center = data["center"] as? Map<*, *>
                            ?: throw IllegalArgumentException("Circle zone missing center")
                        val lat = (center["latitude"] as? Number)?.toDouble()
                            ?: throw IllegalArgumentException("Circle center missing latitude")
                        val lng = (center["longitude"] as? Number)?.toDouble()
                            ?: throw IllegalArgumentException("Circle center missing longitude")
                        val radius = (data["radius"] as? Number)?.toDouble()
                            ?: throw IllegalArgumentException("Circle zone missing radius")
                        
                        ZoneData(id, name, type, LatLng(lat, lng), radius, null)
                    }
                    ZoneType.POLYGON -> {
                        val polygonData = data["polygon"] as? List<*>
                            ?: throw IllegalArgumentException("Polygon zone missing coordinates")
                        
                        val points = polygonData.mapNotNull { point ->
                            val pointMap = point as? Map<*, *> ?: return@mapNotNull null
                            val lat = (pointMap["latitude"] as? Number)?.toDouble() ?: return@mapNotNull null
                            val lng = (pointMap["longitude"] as? Number)?.toDouble() ?: return@mapNotNull null
                            LatLng(lat, lng)
                        }
                        
                        if (points.size < 3) {
                            throw IllegalArgumentException("Polygon must have at least 3 points")
                        }
                        
                        ZoneData(id, name, type, null, null, points)
                    }
                }
            }
        }
    }
    
    enum class ZoneType {
        CIRCLE, POLYGON
    }
    
    data class LatLng(val latitude: Double, val longitude: Double)
    



    /**
     * Calculate distance from zone boundary
     */
    private fun calculateDistanceFromBoundary(zone: ZoneData, location: Location): Double {
        return when (zone.type) {
            ZoneType.CIRCLE -> {
                val center = zone.center ?: return Double.MAX_VALUE
                val radius = zone.radius ?: return Double.MAX_VALUE
                val distance = calculateDistance(
                    LatLng(location.latitude, location.longitude),
                    center
                )
                abs(distance - radius)
            }
            ZoneType.POLYGON -> {
                // For polygon, return 0.0 as boundary distance calculation is complex
                0.0
            }
        }
    }

    /**
     * Get zone complexity metric
     */
    private fun getZoneComplexity(zone: ZoneData): Int {
        return when (zone.type) {
            ZoneType.CIRCLE -> 1
            ZoneType.POLYGON -> zone.polygon?.size ?: 1
        }
    }

    
    /**
     * Calculate confidence based on GPS accuracy
     */
    private fun calculateConfidence(accuracy: Float): Double {
        return when {
            accuracy <= 10.0f -> 0.95
            accuracy <= 20.0f -> 0.85
            accuracy <= 50.0f -> 0.70
            accuracy <= 100.0f -> 0.50
            else -> 0.30
        }
    }

    private fun accuracyToConfidence(accuracyMeters: Float, confirmed: Boolean): Double {
        var base = (100.0 - accuracyMeters.toDouble()) / 100.0
        if (base < 0.0) base = 0.0
        if (base > 1.0) base = 1.0
        if (confirmed) base = (base + 0.05).coerceAtMost(1.0)
        return String.format(java.util.Locale.US, "%.2f", base).toDouble()
    }
    
    // ============================================================================
    // ZONE ACCESS FOR PROXIMITY CALCULATION
    // ============================================================================
    
    /**
     * Get current zones for proximity calculation
     */
    fun getCurrentZones(): List<Zone> {
        return zones.values.map { zoneData ->
            Zone(
                id = zoneData.id,
                name = zoneData.name,
                type = zoneData.type,
                center = zoneData.center,
                radius = zoneData.radius,
                points = zoneData.polygon ?: emptyList()
            )
        }
    }
    
    /**
     * Thread-safe zone count
     */
    @Synchronized
    fun getZoneCount(): Int = zones.size
    
    /**
     * Check if any zones are configured
     */
    @Synchronized
    fun hasZones(): Boolean = zones.isNotEmpty()
    
    /**
     * Zone data class for proximity calculation
     */
    data class Zone(
        val id: String,
        val name: String,
        val type: ZoneType,
        val center: LatLng?,
        val radius: Double?,
        val points: List<LatLng>
    ) {
        val isCircle: Boolean get() = type == ZoneType.CIRCLE
        val isPolygon: Boolean get() = type == ZoneType.POLYGON
    }

}