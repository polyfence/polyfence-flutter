import Foundation
import CoreLocation
import UIKit

/**
 * Core geofencing detection engine for iOS
 * Single responsibility: GPS location → zone detection → events
 * Ported from Android GeofenceEngine.kt
 */
class GeofenceEngine {
    
    // MARK: - Constants
    internal static let EARTH_RADIUS_METERS: Double = 6371000.0
    private static let TAG = "GeofenceEngine"

    // State recovery event types
    static let EVENT_RECOVERY_ENTER = "RECOVERY_ENTER"
    static let EVENT_RECOVERY_EXIT = "RECOVERY_EXIT"

    // Dwell event type
    static let EVENT_DWELL = "DWELL"

    // Default dwell threshold (5 minutes)
    static let DEFAULT_DWELL_THRESHOLD_MS: TimeInterval = 300.0 // 300 seconds = 5 minutes
    
    // MARK: - Properties
    // Synchronization for thread-safe access to zone data/state
    private let syncQueue = DispatchQueue(label: "com.polyfence.GeofenceEngine.sync")
    private var zones: [String: ZoneData] = [:]
    private var zoneStates: [String: Bool] = [:]
    private var zoneConfidence: [String: ZoneConfidence] = [:]

    // Dwell time tracking: zoneId -> entry timestamp (seconds since epoch)
    private var zoneEntryTimes: [String: TimeInterval] = [:]
    // Track which zones have already fired dwell events this session
    private var dwellEventsFired: [String: Bool] = [:]
    // Dwell threshold in seconds (configurable)
    private var dwellThresholdSeconds: TimeInterval = GeofenceEngine.DEFAULT_DWELL_THRESHOLD_MS
    // Whether dwell detection is enabled
    private var dwellEnabled: Bool = true
    
    // Configuration for validation
    private var requireConfirmation: Bool = true
    private var confirmationPoints: Int = 2
    private var confirmationTimeoutMs: TimeInterval = 10.0 // 10 seconds
    
    // GPS accuracy threshold in meters (default: 100m to match Android)
    private var gpsAccuracyThreshold: Double = 100.0

    // Zone clustering configuration
    private var clusteringEnabled: Bool = false
    private var clusterActiveRadiusMeters: Double = 5000.0
    private var clusterRefreshDistanceMeters: Double = 1000.0
    private var clusterCenterLat: Double?
    private var clusterCenterLng: Double?
    private var activeZoneIds: Set<String> = []

    // Event callbacks - includes detection time in milliseconds
    private var eventCallback: ((String, String, CLLocation, Double) -> Void)?

    // Performance tracking
    private var performanceMetrics: [String: Double] = [:]

    // Zone state persistence (injected by LocationTracker)
    private var zonePersistence: ZonePersistence?

    // Track if state was recovered from persistence on startup
    private var stateRecoveredFromPersistence = false
    
    /**
     * Zone confidence tracking (ported from Android)
     */
    private class ZoneConfidence {
        var insideCount: Int = 0
        var outsideCount: Int = 0
        var lastDetection: TimeInterval = 0
        var confirmedState: Bool = false
    }
    
    // MARK: - Public Methods
    
    /**
     * Set callback for geofence events
     * Callback receives: zoneId, eventType, location, detectionTimeMs
     */
    func setEventCallback(_ callback: @escaping (String, String, CLLocation, Double) -> Void) {
        eventCallback = callback
    }
    
    /**
     * Configure validation settings
     */
    func setValidationConfig(requireConfirmation: Bool, confirmationPoints: Int) {
        self.requireConfirmation = requireConfirmation
        self.confirmationPoints = confirmationPoints
    }
    
    /**
     * Set GPS accuracy threshold in meters
     * Locations with accuracy worse than this are rejected
     * Default: 100m (matches Android for platform parity)
     */
    func setGpsAccuracyThreshold(_ threshold: Double) {
        self.gpsAccuracyThreshold = threshold
    }

    /**
     * Configure dwell detection
     * @param enabled Whether dwell detection is enabled
     * @param thresholdSeconds How long (seconds) device must stay in zone before DWELL fires
     */
    func setDwellConfig(enabled: Bool, thresholdSeconds: TimeInterval = GeofenceEngine.DEFAULT_DWELL_THRESHOLD_MS) {
        self.dwellEnabled = enabled
        self.dwellThresholdSeconds = thresholdSeconds
        NSLog("[\(GeofenceEngine.TAG)] Dwell config: enabled=\(enabled), threshold=\(thresholdSeconds)s")
    }

    /**
     * Configure zone clustering for large zone sets
     * @param enabled Whether clustering is enabled (default: false)
     * @param activeRadiusMeters Radius to check zones within (default: 5000m)
     * @param refreshDistanceMeters Distance to move before refreshing active cluster (default: 1000m)
     */
    func setClusterConfig(enabled: Bool, activeRadiusMeters: Double = 5000.0, refreshDistanceMeters: Double = 1000.0) {
        self.clusteringEnabled = enabled
        self.clusterActiveRadiusMeters = activeRadiusMeters
        self.clusterRefreshDistanceMeters = refreshDistanceMeters
        // Reset cluster center to force refresh on next location update
        self.clusterCenterLat = nil
        self.clusterCenterLng = nil
        self.activeZoneIds.removeAll()
        NSLog("[\(GeofenceEngine.TAG)] Cluster config: enabled=\(enabled), activeRadius=\(activeRadiusMeters)m, refreshDistance=\(refreshDistanceMeters)m")
    }

    /**
     * Check if cluster needs to be refreshed based on movement from cluster center
     */
    private func shouldRefreshCluster(_ location: CLLocation) -> Bool {
        guard let centerLat = clusterCenterLat, let centerLng = clusterCenterLng else {
            return true
        }

        let clusterCenter = CLLocation(latitude: centerLat, longitude: centerLng)
        let distance = location.distance(from: clusterCenter)
        return distance >= clusterRefreshDistanceMeters
    }

    /**
     * Refresh the active zone cluster around the given location
     */
    private func refreshCluster(_ location: CLLocation) {
        clusterCenterLat = location.coordinate.latitude
        clusterCenterLng = location.coordinate.longitude
        activeZoneIds.removeAll()

        var activatedCount = 0

        for (zoneId, zone) in zones {
            let zoneCenter = zone.calculateCenter()
            let zoneCenterLocation = CLLocation(latitude: zoneCenter.latitude, longitude: zoneCenter.longitude)
            let distance = location.distance(from: zoneCenterLocation)

            // Include zone if its center is within active radius
            // Also include zones whose boundary might intersect (add zone radius buffer)
            let effectiveRadius = clusterActiveRadiusMeters + (zone.radius ?? 0.0)
            if distance <= effectiveRadius {
                activeZoneIds.insert(zoneId)
                activatedCount += 1
            }
        }

        NSLog("[\(GeofenceEngine.TAG)] Cluster refreshed at (\(location.coordinate.latitude), \(location.coordinate.longitude)): \(activatedCount) of \(zones.count) zones active")
    }

    /**
     * Get zones to check based on clustering configuration
     */
    private func getZonesToCheck() -> [String: ZoneData] {
        if clusteringEnabled && !activeZoneIds.isEmpty {
            return zones.filter { activeZoneIds.contains($0.key) }
        } else {
            return zones
        }
    }

    /**
     * Set zone persistence for state recovery across service restarts
     */
    func setZonePersistence(_ persistence: ZonePersistence) {
        self.zonePersistence = persistence
    }

    /**
     * Load persisted zone states on service restart
     * Should be called after zones are loaded but before location updates start
     */
    func loadPersistedZoneStates() {
        guard let persistence = zonePersistence else { return }

        guard persistence.hasPersistedZoneStates() else {
            NSLog("[\(GeofenceEngine.TAG)] No persisted zone states found (fresh install or data wipe)")
            stateRecoveredFromPersistence = false
            return
        }

        let persistedStates = persistence.loadZoneStates()
        guard !persistedStates.isEmpty else {
            NSLog("[\(GeofenceEngine.TAG)] Persisted zone states empty")
            stateRecoveredFromPersistence = false
            return
        }

        // Only load states for zones that are currently registered
        var loadedCount = 0
        syncQueue.sync {
            for (zoneId, isInside) in persistedStates {
                if self.zones[zoneId] != nil {
                    self.zoneStates[zoneId] = isInside
                    loadedCount += 1
                    NSLog("[\(GeofenceEngine.TAG)] Restored state for zone \(zoneId): \(isInside ? "INSIDE" : "OUTSIDE")")
                }
            }
        }

        stateRecoveredFromPersistence = loadedCount > 0
        let insideCount = persistedStates.values.filter { $0 }.count
        NSLog("[\(GeofenceEngine.TAG)] Loaded \(loadedCount) persisted zone states (\(insideCount) were inside)")
    }

    /**
     * Reconcile zone states with current location after service restart
     * Fires RECOVERY_ENTER/RECOVERY_EXIT events for mismatches
     * Should be called with first valid location after restart
     */
    func reconcileZoneStates(_ location: CLLocation) {
        if !stateRecoveredFromPersistence {
            // No persisted state - establish initial state and fire ENTER events for zones we're inside
            NSLog("[\(GeofenceEngine.TAG)] No persisted state - establishing initial state from current location")
            let checkStartTime = CFAbsoluteTimeGetCurrent()
            let snapshot: [(String, ZoneData)] = syncQueue.sync { self.zones.map { ($0.key, $0.value) } }
            for (zoneId, zone) in snapshot {
                let isInside = zone.contains(location)
                syncQueue.sync { self.zoneStates[zoneId] = isInside }

                // Fire ENTER event for zones we're currently inside (fresh install behavior)
                if isInside {
                    let detectionTimeMs = (CFAbsoluteTimeGetCurrent() - checkStartTime) * 1000.0
                    NSLog("[\(GeofenceEngine.TAG)] Initial state: inside zone \(zoneId) -> firing ENTER")
                    eventCallback?(zoneId, "ENTER", location, detectionTimeMs)
                }
            }
            persistAllZoneStates()
            return
        }

        NSLog("[\(GeofenceEngine.TAG)] Reconciling zone states with current location...")
        let checkStartTime = CFAbsoluteTimeGetCurrent()
        var reconciliationCount = 0

        let snapshot: [(String, ZoneData)] = syncQueue.sync { self.zones.map { ($0.key, $0.value) } }
        for (zoneId, zone) in snapshot {
            let persistedState = syncQueue.sync { self.zoneStates[zoneId] ?? false }
            let actualState = zone.contains(location)

            if persistedState != actualState {
                reconciliationCount += 1
                syncQueue.sync { self.zoneStates[zoneId] = actualState }

                let detectionTimeMs = (CFAbsoluteTimeGetCurrent() - checkStartTime) * 1000.0

                if actualState {
                    // Was outside (persisted), now inside (actual) -> fire RECOVERY_ENTER
                    NSLog("[\(GeofenceEngine.TAG)] State mismatch for zone \(zoneId): was OUTSIDE, now INSIDE -> firing RECOVERY_ENTER")
                    eventCallback?(zoneId, GeofenceEngine.EVENT_RECOVERY_ENTER, location, detectionTimeMs)
                } else {
                    // Was inside (persisted), now outside (actual) -> fire RECOVERY_EXIT
                    NSLog("[\(GeofenceEngine.TAG)] State mismatch for zone \(zoneId): was INSIDE, now OUTSIDE -> firing RECOVERY_EXIT")
                    eventCallback?(zoneId, GeofenceEngine.EVENT_RECOVERY_EXIT, location, detectionTimeMs)
                }
            }
        }

        if reconciliationCount > 0 {
            NSLog("[\(GeofenceEngine.TAG)] Reconciled \(reconciliationCount) zone state mismatches")
            persistAllZoneStates()
        } else {
            NSLog("[\(GeofenceEngine.TAG)] All zone states match current location - no reconciliation needed")
        }

        stateRecoveredFromPersistence = false // Reset flag after reconciliation
    }

    /**
     * Persist all current zone states (called after reconciliation or bulk changes)
     */
    private func persistAllZoneStates() {
        guard let persistence = zonePersistence else { return }
        let states = syncQueue.sync { self.zoneStates }
        persistence.saveZoneStates(states)
    }

    /**
     * Persist single zone state change (called on each transition)
     */
    private func persistZoneState(zoneId: String, isInside: Bool) {
        guard let persistence = zonePersistence else { return }
        persistence.saveZoneState(zoneId: zoneId, isInside: isInside)
    }

    /**
     * Get current zone states for health check API
     */
    func getCurrentZoneStates() -> [String: Bool] {
        return syncQueue.sync { self.zoneStates }
    }

    /**
     * Check if state was recovered from persistence on last startup
     */
    func wasStateRecoveredFromPersistence() -> Bool {
        return stateRecoveredFromPersistence
    }
    
    /**
     * Add zone for monitoring
     */
    func addZone(zoneId: String, zoneName: String, zoneData: [String: Any]) throws {
        let memoryBefore = getCurrentMemoryUsage()

        do {
            let zone = try ZoneData.fromMap(zoneId: zoneId, zoneName: zoneName, zoneData: zoneData)
            
            // Move zone storage to background thread to avoid blocking location service
            DispatchQueue.global(qos: .userInitiated).async {
                self.syncQueue.sync {
                    self.zones[zoneId] = zone
                    self.zoneStates[zoneId] = false // Initially outside
                    // Reset any previous confidence state if re-adding
                    self.zoneConfidence[zoneId] = ZoneConfidence()
                }
                
                // Memory monitoring after zone add
                let memoryAfter = self.getCurrentMemoryUsage()
                let memoryDelta = memoryAfter - memoryBefore
                let totalZones = self.syncQueue.sync { self.zones.count }
            }
            
        } catch {
            throw error
        }
    }
    
    /**
     * Remove zone from monitoring
     */
    func removeZone(zoneId: String) {
        syncQueue.sync {
            self.zones.removeValue(forKey: zoneId)
            self.zoneStates.removeValue(forKey: zoneId)
            self.zoneConfidence.removeValue(forKey: zoneId)
            self.zoneEntryTimes.removeValue(forKey: zoneId)
            self.dwellEventsFired.removeValue(forKey: zoneId)
        }

        // Remove persisted state
        zonePersistence?.removeZoneState(zoneId: zoneId)
    }

    /**
     * Clear all zones
     */
    func clearAllZones() {
        syncQueue.sync {
            self.zones.removeAll()
            self.zoneStates.removeAll()
            self.zoneConfidence.removeAll()
            self.zoneEntryTimes.removeAll()
            self.dwellEventsFired.removeAll()
        }

        // Clear persisted states
        zonePersistence?.clearAllZoneStates()
    }
    
    /**
     * Get zone name by ID
     */
    func getZoneName(_ zoneId: String) -> String? {
        return syncQueue.sync { self.zones[zoneId]?.zoneName }
    }
    
    /**
     * Enhanced check location (ported from Android)
     */
    func checkLocation(_ location: CLLocation) {
        guard isValidLocation(location) else { return }

        // Handle clustering: refresh active zones if needed
        if clusteringEnabled {
            if shouldRefreshCluster(location) {
                syncQueue.sync {
                    refreshCluster(location)
                }
            }
        }

        // Take a snapshot of current zones to avoid concurrent modification during iteration
        // Use clustered zones if enabled, otherwise all zones
        let snapshot: [(String, ZoneData)] = syncQueue.sync {
            let zonesToCheck = self.getZonesToCheck()
            return zonesToCheck.map { ($0.key, $0.value) }
        }
        let overallStartTime = CFAbsoluteTimeGetCurrent()
        let speed = location.speed * 3.6 // Convert m/s to km/h

        var zoneCheckCount = 0
        var totalAlgorithmTime: TimeInterval = 0
        var totalConfidenceTime: TimeInterval = 0

        for (zoneId, zone) in snapshot {
            zoneCheckCount += 1
            let zoneStartTime = CFAbsoluteTimeGetCurrent()
            let currentState = syncQueue.sync { self.zoneStates[zoneId] ?? false }
            
            // Precise algorithm timing
            let algorithmStartTime = CFAbsoluteTimeGetCurrent()
            let isInside = zone.contains(location)
            let algorithmDuration = CFAbsoluteTimeGetCurrent() - algorithmStartTime
            totalAlgorithmTime += algorithmDuration
            let zoneTime = (CFAbsoluteTimeGetCurrent() - zoneStartTime) * 1000
            
            // Smart validation: Use confirmation based on speed and zone characteristics
            let useConfirmation = requireConfirmation ? shouldUseConfirmation(speed: speed, zoneRadius: zone.radius) : false
            
            let stateChanged: Bool
            if useConfirmation {
                let confidenceStartTime = CFAbsoluteTimeGetCurrent()
                stateChanged = processWithConfidence(zoneId: zoneId, zone: zone, isInside: isInside, currentState: currentState, currentTime: Date().timeIntervalSince1970, location: location, checkStartTime: zoneStartTime)
                let confidenceDuration = CFAbsoluteTimeGetCurrent() - confidenceStartTime
                totalConfidenceTime += confidenceDuration
            } else {
                // Original logic for immediate detection
                stateChanged = processImmediate(zoneId: zoneId, zone: zone, isInside: isInside, currentState: currentState, location: location, checkStartTime: zoneStartTime)
            }
            
        }
        
        let overallDuration = CFAbsoluteTimeGetCurrent() - overallStartTime
    }
    
    // MARK: - Private Methods
    
    /**
     * Calculate distance between two points using Haversine formula (ported from Android)
     */
    private func calculateDistance(point1: CLLocationCoordinate2D, point2: CLLocationCoordinate2D) -> Double {
        let dLat = (point2.latitude - point1.latitude) * .pi / 180
        let dLng = (point2.longitude - point1.longitude) * .pi / 180
        
        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(point1.latitude * .pi / 180) * cos(point2.latitude * .pi / 180) *
                sin(dLng / 2) * sin(dLng / 2)
        
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return GeofenceEngine.EARTH_RADIUS_METERS * c
    }
    
    /**
     * Point-in-polygon detection using ray casting algorithm (ported from Android)
     */
    private func isPointInPolygon(point: CLLocationCoordinate2D, polygon: [CLLocationCoordinate2D]) -> Bool {
        var intersections = 0
        let x = point.longitude
        let y = point.latitude
        
        for i in 0..<polygon.count {
            let p1 = polygon[i]
            let p2 = polygon[(i + 1) % polygon.count]
            
            if (((p1.latitude > y) != (p2.latitude > y)) &&
                (x < (p2.longitude - p1.longitude) * (y - p1.latitude) / (p2.latitude - p1.latitude) + p1.longitude)) {
                intersections += 1
            }
        }
        
        return intersections % 2 == 1
    }
    
    /**
     * Smart validation: Single point for obvious cases, 2-point for edge cases (ported from Android)
     */
    private func shouldUseConfirmation(speed: Double, zoneRadius: Double?) -> Bool {
        // Large zones always need confirmation (reduce false positives)
        if let radius = zoneRadius, radius > 200 {
            return true
        }
        
        // High speed + reasonable zones = single point OK
        if speed > 40 && (zoneRadius == nil || zoneRadius! > 50) {
            return false
        }
        
        // Default: Use 2-point for reliability
        return true
    }
    
    /**
     * Process with confidence validation - returns true if state changed (ported from Android)
     */
    private func processWithConfidence(zoneId: String, zone: ZoneData, isInside: Bool, currentState: Bool, currentTime: TimeInterval, location: CLLocation, checkStartTime: CFAbsoluteTime) -> Bool {
        let confidence = syncQueue.sync { self.zoneConfidence[zoneId] ?? ZoneConfidence() }
        // Persist confidence across calls
        syncQueue.sync { self.zoneConfidence[zoneId] = confidence }
        
        // Update confidence counters
        if isInside {
            confidence.insideCount += 1
            confidence.outsideCount = 0
        } else {
            confidence.outsideCount += 1
            confidence.insideCount = 0
        }
        
        confidence.lastDetection = currentTime
        
        // Check if we have enough confidence for state change
        let requiredCount = confirmationPoints
        let hasConfidence = isInside ? confidence.insideCount >= requiredCount : confidence.outsideCount >= requiredCount
        
            // State change with confidence
        if hasConfidence && currentState != isInside {
            syncQueue.sync {
                self.zoneStates[zoneId] = isInside
                self.zoneConfidence[zoneId]?.confirmedState = isInside
            }

            // Persist state change immediately (write-through)
            persistZoneState(zoneId: zoneId, isInside: isInside)

            // Calculate detection time: from start of zone check to now (in milliseconds)
            let detectionTimeMs = (CFAbsoluteTimeGetCurrent() - checkStartTime) * 1000.0

            let eventType = isInside ? "ENTER" : "EXIT"
            eventCallback?(zoneId, eventType, location, detectionTimeMs)

            // Handle dwell tracking on state change
            handleDwellStateChange(zoneId: zoneId, isInside: isInside, location: location, checkStartTime: checkStartTime)

            // Reset confidence after successful event
            syncQueue.sync {
                self.zoneConfidence[zoneId]?.insideCount = 0
                self.zoneConfidence[zoneId]?.outsideCount = 0
            }

            return true // State changed
        }

        // Timeout: reset confidence if no consistent readings
        if currentTime - confidence.lastDetection > confirmationTimeoutMs {
            syncQueue.sync {
                self.zoneConfidence[zoneId]?.insideCount = 0
                self.zoneConfidence[zoneId]?.outsideCount = 0
            }
        }

        // Check for dwell even if no state change (still inside)
        if currentState && isInside && dwellEnabled {
            checkAndFireDwell(zoneId: zoneId, location: location, checkStartTime: checkStartTime)
        }

        return false // No state change
    }
    
    /**
     * Process immediate detection without confidence validation
     */
    private func processImmediate(zoneId: String, zone: ZoneData, isInside: Bool, currentState: Bool, location: CLLocation, checkStartTime: CFAbsoluteTime) -> Bool {
        do {
            // Check what happens when we detect a state change
            if isInside != currentState {
                handleStateChange(zoneId: zoneId, zoneName: zone.zoneName, isInside: isInside, location: location)

                syncQueue.sync { self.zoneStates[zoneId] = isInside }

                // Persist state change immediately (write-through)
                persistZoneState(zoneId: zoneId, isInside: isInside)

                // Calculate detection time: from start of zone check to now (in milliseconds)
                let detectionTimeMs = (CFAbsoluteTimeGetCurrent() - checkStartTime) * 1000.0

                let eventType = isInside ? "ENTER" : "EXIT"
                eventCallback?(zoneId, eventType, location, detectionTimeMs)

                // Handle dwell tracking on state change
                handleDwellStateChange(zoneId: zoneId, isInside: isInside, location: location, checkStartTime: checkStartTime)

                return true
            } else if isInside && dwellEnabled {
                // Still inside - check for dwell
                checkAndFireDwell(zoneId: zoneId, location: location, checkStartTime: checkStartTime)
            }

            return false
        } catch {
            return false
        }
    }

    /**
     * Handle dwell tracking when zone state changes
     */
    private func handleDwellStateChange(zoneId: String, isInside: Bool, location: CLLocation, checkStartTime: CFAbsoluteTime) {
        guard dwellEnabled else { return }

        syncQueue.sync {
            if isInside {
                // Entered zone - start tracking dwell time
                self.zoneEntryTimes[zoneId] = Date().timeIntervalSince1970
                self.dwellEventsFired.removeValue(forKey: zoneId) // Reset dwell flag for new entry
                NSLog("[\(GeofenceEngine.TAG)] Dwell tracking started for zone \(zoneId)")
            } else {
                // Exited zone - stop tracking dwell time
                self.zoneEntryTimes.removeValue(forKey: zoneId)
                self.dwellEventsFired.removeValue(forKey: zoneId)
                NSLog("[\(GeofenceEngine.TAG)] Dwell tracking stopped for zone \(zoneId)")
            }
        }
    }

    /**
     * Check if dwell threshold reached and fire DWELL event
     */
    private func checkAndFireDwell(zoneId: String, location: CLLocation, checkStartTime: CFAbsoluteTime) {
        // Check if dwell already fired for this zone entry
        let alreadyFired = syncQueue.sync { self.dwellEventsFired[zoneId] == true }
        guard !alreadyFired else { return }

        guard let entryTime = syncQueue.sync(execute: { self.zoneEntryTimes[zoneId] }) else { return }

        let dwellDuration = Date().timeIntervalSince1970 - entryTime

        if dwellDuration >= dwellThresholdSeconds {
            // Mark as fired to prevent duplicate events
            syncQueue.sync { self.dwellEventsFired[zoneId] = true }

            let detectionTimeMs = (CFAbsoluteTimeGetCurrent() - checkStartTime) * 1000.0

            NSLog("[\(GeofenceEngine.TAG)] DWELL event for zone \(zoneId) after \(dwellDuration)s")
            eventCallback?(zoneId, GeofenceEngine.EVENT_DWELL, location, detectionTimeMs)
        }
    }
    
    /**
     * Handle state change safely
     */
    private func handleStateChange(zoneId: String, zoneName: String, isInside: Bool, location: CLLocation) {
        // Update state safely
        syncQueue.sync {
            self.zoneStates[zoneId] = isInside
        }
        
        // Geofence events are dispatched on the main thread in processImmediate/processWithConfidence.
    }
    
    /**
     * Validate location quality
     * Uses configurable GPS accuracy threshold (default: 100m)
     * This ensures platform parity with Android
     */
    private func isValidLocation(_ location: CLLocation) -> Bool {
        return location.horizontalAccuracy > 0 && location.horizontalAccuracy < gpsAccuracyThreshold
    }
    
    /**
     * Calculate confidence based on location accuracy
     */
    private func calculateConfidence(_ accuracy: CLLocationAccuracy) -> Double {
        return max(0.0, min(1.0, 1.0 - (accuracy / 100.0)))
    }
    
    /**
     * Get current memory usage in MB
     */
    private func getCurrentMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / 1024.0 / 1024.0
        } else {
            return 0.0
        }
    }
    
    // MARK: - Zone Access for Proximity Calculation
    
    /**
     * Get current zones for proximity calculation
     */
    func getCurrentZones() -> [Zone] {
        return syncQueue.sync {
            return zones.values.map { zoneData in
                Zone(
                    id: zoneData.zoneId,
                    name: zoneData.zoneName,
                    type: zoneData.type,
                    center: zoneData.center,
                    radius: zoneData.radius,
                    points: zoneData.polygon ?? []
                )
            }
        }
    }
    
    /**
     * Thread-safe zone count
     */
    func getZoneCount() -> Int {
        return syncQueue.sync { return zones.count }
    }
    
    /**
     * Check if any zones are configured
     */
    func hasZones() -> Bool {
        return syncQueue.sync { return !zones.isEmpty }
    }
    
}

// MARK: - Zone Data Models


class ZoneData {
    let zoneId: String
    let zoneName: String
    let type: ZoneType
    let center: CLLocationCoordinate2D?
    let radius: Double?
    let polygon: [CLLocationCoordinate2D]?
    
    init(zoneId: String, zoneName: String, type: ZoneType, center: CLLocationCoordinate2D? = nil, radius: Double? = nil, polygon: [CLLocationCoordinate2D]? = nil) {
        self.zoneId = zoneId
        self.zoneName = zoneName
        self.type = type
        self.center = center
        self.radius = radius
        self.polygon = polygon
    }
    
    /**
     * Check if location is inside this zone
     */
    func contains(_ location: CLLocation) -> Bool {
        switch type {
        case .circle:
            guard let center = center, let radius = radius else { return false }
            let distance = calculateDistance(point1: center, point2: location.coordinate)
            return distance <= radius

        case .polygon:
            guard let polygon = polygon else { return false }
            return isPointInPolygon(point: location.coordinate, polygon: polygon)
        }
    }

    /**
     * Calculate the center point of this zone for clustering calculations
     * For circles: returns center
     * For polygons: returns centroid (average of all points)
     */
    func calculateCenter() -> CLLocationCoordinate2D {
        switch type {
        case .circle:
            guard let center = center else { return CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0) }
            return CLLocationCoordinate2D(latitude: center.latitude, longitude: center.longitude)
        case .polygon:
            guard let points = polygon, !points.isEmpty else { return CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0) }
            let avgLat = points.map { $0.latitude }.reduce(0, +) / Double(points.count)
            let avgLng = points.map { $0.longitude }.reduce(0, +) / Double(points.count)
            return CLLocationCoordinate2D(latitude: avgLat, longitude: avgLng)
        }
    }
    
    /**
     * Calculate distance between two points using Haversine formula
     */
    private func calculateDistance(point1: CLLocationCoordinate2D, point2: CLLocationCoordinate2D) -> Double {
        let dLat = (point2.latitude - point1.latitude) * .pi / 180
        let dLng = (point2.longitude - point1.longitude) * .pi / 180
        
        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(point1.latitude * .pi / 180) * cos(point2.latitude * .pi / 180) *
                sin(dLng / 2) * sin(dLng / 2)
        
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return GeofenceEngine.EARTH_RADIUS_METERS * c
    }
    
    /**
     * Point-in-polygon detection using ray casting algorithm
     */
    private func isPointInPolygon(point: CLLocationCoordinate2D, polygon: [CLLocationCoordinate2D]) -> Bool {
        var intersections = 0
        let x = point.longitude
        let y = point.latitude
        
        for i in 0..<polygon.count {
            let p1 = polygon[i]
            let p2 = polygon[(i + 1) % polygon.count]
            
            if (((p1.latitude > y) != (p2.latitude > y)) &&
                (x < (p2.longitude - p1.longitude) * (y - p1.latitude) / (p2.latitude - p1.latitude) + p1.longitude)) {
                intersections += 1
            }
        }
        
        return intersections % 2 == 1
    }
    
    /**
     * Create ZoneData from map (ported from Android)
     */
    static func fromMap(zoneId: String, zoneName: String, zoneData: [String: Any]) throws -> ZoneData {
        guard let typeString = zoneData["type"] as? String else {
            throw NSError(domain: "GeofenceEngine", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing zone type"])
        }
        
        let type: ZoneType
        let center: CLLocationCoordinate2D?
        let radius: Double?
        let polygon: [CLLocationCoordinate2D]?
        
        if typeString == "circle" {
            type = .circle
            // Accept multiple center formats; numbers or strings
            let centerData = zoneData["center"] as? [String: Any]
            func parseDouble(_ any: Any?) -> Double? {
                if let n = any as? NSNumber { return n.doubleValue }
                if let s = any as? String { return Double(s) }
                return nil
            }
            let lat: Double? = parseDouble(centerData?["latitude"]) ?? parseDouble(centerData?["lat"]) ?? parseDouble(zoneData["latitude"]) ?? parseDouble(zoneData["lat"])
            let lng: Double? = parseDouble(centerData?["longitude"]) ?? parseDouble(centerData?["lng"]) ?? parseDouble(zoneData["longitude"]) ?? parseDouble(zoneData["lng"])
            let rad: Double? = parseDouble(zoneData["radius"])
            guard let latUnwrapped = lat, let lngUnwrapped = lng, let radiusUnwrapped = rad else {
                throw NSError(domain: "GeofenceEngine", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid circle zone data"])
            }
            center = CLLocationCoordinate2D(latitude: latUnwrapped, longitude: lngUnwrapped)
            radius = radiusUnwrapped
            polygon = nil
            
        } else if typeString == "polygon" {
            type = .polygon
            // Accept either "points" (iOS expectation) OR "polygon" (Flutter/Android model)
            let pointsArray = (zoneData["points"] as? [[String: Any]]) ?? (zoneData["polygon"] as? [[String: Any]])
            var parsedPoints: [CLLocationCoordinate2D] = []
            if let pointsData = pointsArray {
                func parseDouble(_ any: Any?) -> Double? {
                    if let n = any as? NSNumber { return n.doubleValue }
                    if let s = any as? String { return Double(s) }
                    return nil
                }
                parsedPoints = pointsData.compactMap { pointData -> CLLocationCoordinate2D? in
                    let lat = parseDouble(pointData["latitude"]) ?? parseDouble(pointData["lat"]) 
                    let lng = parseDouble(pointData["longitude"]) ?? parseDouble(pointData["lng"]) 
                    guard let lat = lat, let lng = lng else { return nil }
                    return CLLocationCoordinate2D(latitude: lat, longitude: lng)
                }
            } else if let coordsAny = zoneData["coordinates"] {
                // Accept GeoJSON-like coordinates: either [[lng,lat], ...] or [[[lng,lat], ...]] (first ring)
                if let coordinateArray = coordsAny as? [[Double]], let first = coordinateArray.first, first.count == 2 {
                    parsedPoints = coordinateArray.compactMap { pair -> CLLocationCoordinate2D? in
                        guard pair.count == 2 else { return nil }
                        let lng = pair[0]
                        let lat = pair[1]
                        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
                    }
                } else if let ringsArray = coordsAny as? [[[Double]]], let firstRing = ringsArray.first {
                    parsedPoints = firstRing.compactMap { pair -> CLLocationCoordinate2D? in
                        guard pair.count == 2 else { return nil }
                        let lng = pair[0]
                        let lat = pair[1]
                        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
                    }
                }
            }
            let points = parsedPoints
            
            guard points.count >= 3 else {
                throw NSError(domain: "GeofenceEngine", code: 4, userInfo: [NSLocalizedDescriptionKey: "Polygon must have at least 3 points"])
            }
            
            center = nil
            radius = nil
            polygon = points
            
        } else {
            throw NSError(domain: "GeofenceEngine", code: 5, userInfo: [NSLocalizedDescriptionKey: "Unknown zone type: \(typeString)"])
        }
        
        return ZoneData(zoneId: zoneId, zoneName: zoneName, type: type, center: center, radius: radius, polygon: polygon)
    }
    
    /**
     * Parse GeoJSON-style coordinates into CLLocationCoordinate2D array
     * Supports [[lng,lat], ...] or [[[lng,lat], ...]] (first ring)
     */
    private static func parseGeoJsonCoordinates(_ any: Any) -> [CLLocationCoordinate2D] {
        var coords: [CLLocationCoordinate2D] = []
        // Case 1: [[lng,lat], ...]
        if let arr = any as? [[NSNumber]], let first = arr.first, first.count == 2 {
            for pair in arr {
                let lng = pair[0].doubleValue
                let lat = pair[1].doubleValue
                coords.append(CLLocationCoordinate2D(latitude: lat, longitude: lng))
            }
            return coords
        }
        // Case 2: [[[lng,lat], ...]] (rings) -> take first ring
        if let rings = any as? [[[NSNumber]]], let ring = rings.first {
            for pair in ring where pair.count == 2 {
                let lng = pair[0].doubleValue
                let lat = pair[1].doubleValue
                coords.append(CLLocationCoordinate2D(latitude: lat, longitude: lng))
            }
            return coords
        }
        // Case 3: [[Double]]
        if let arrD = any as? [[Double]], let first = arrD.first, first.count == 2 {
            for pair in arrD {
                let lng = pair[0]
                let lat = pair[1]
                coords.append(CLLocationCoordinate2D(latitude: lat, longitude: lng))
            }
            return coords
        }
        // Case 4: [[[Double]]]
        if let ringsD = any as? [[[Double]]], let ring = ringsD.first {
            for pair in ring where pair.count == 2 {
                let lng = pair[0]
                let lat = pair[1]
                coords.append(CLLocationCoordinate2D(latitude: lat, longitude: lng))
            }
            return coords
        }
        return coords
    }

}

// MARK: - Helper Structures

/**
 * Simple lat/lng container for distance calculations
 * Used by clustering logic
 */
struct LatLng {
    let latitude: Double
    let longitude: Double
} 