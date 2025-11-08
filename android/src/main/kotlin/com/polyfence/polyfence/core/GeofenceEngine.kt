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
    
    // Configuration for validation
    private var requireConfirmation = true
    private var confirmationPoints = 2
    private var confirmationTimeoutMs = 10000L // 10 seconds
    
    // Event callback
    private var eventCallback: ((String, String, Location) -> Unit)? = null
    
    
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
    }
    
    /**
     * Clear all zones
     */
    fun clearAllZones() {
        zones.clear()
        zoneStates.clear()
        zoneConfidence.clear()
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
     * Update GPS accuracy threshold
     */
    fun setAccuracyThreshold(threshold: Float) {
        // GPS accuracy threshold implementation
    }
    
    /**
     * Set callback for zone events
     */
    fun setEventCallback(callback: (String, String, Location) -> Unit) {
        eventCallback = callback
    }
    
    
    
    /**
     * Enhanced check location with precise timing
     */
    fun checkLocation(location: Location) {
        if (!isValidLocation(location)) {
            return
        }

        val overallStartTime = System.nanoTime()
        val speed = if (location.hasSpeed()) location.speed * 3.6 else 0.0 // Convert m/s to km/h

        var zoneCheckCount = 0
        var totalAlgorithmTime = 0L
        var totalConfidenceTime = 0L

        zones.forEach { (zoneId, zone) ->
            zoneCheckCount++
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
                stateChanged = processWithConfidence(zoneId, zone, isInside, currentState, System.currentTimeMillis(), location)
                val confidenceDuration = System.nanoTime() - confidenceStartTime
                totalConfidenceTime += confidenceDuration
            } else {
                // Original logic for immediate detection
                stateChanged = processImmediate(zoneId, zone, isInside, currentState, location)
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
        location: Location
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
            
            val eventType = if (isInside) "ENTER" else "EXIT"
            eventCallback?.invoke(zoneId, eventType, location)
            
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
        location: Location
    ): Boolean {
        if (currentState != isInside) {
            zoneStates[zoneId] = isInside
            val eventType = if (isInside) "ENTER" else "EXIT"
            eventCallback?.invoke(zoneId, eventType, location)
            return true // State changed
        }
        return false // No state change
    }
    
    /**
     * Validate GPS location
     */
    private fun isValidLocation(location: Location): Boolean {
    return location.hasAccuracy() && 
           location.accuracy <= 100.0f && // Changed from 50.0f to 100.0f
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