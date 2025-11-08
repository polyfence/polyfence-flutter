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
    
    // MARK: - Properties
    // Synchronization for thread-safe access to zone data/state
    private let syncQueue = DispatchQueue(label: "com.polyfence.GeofenceEngine.sync")
    private var zones: [String: ZoneData] = [:]
    private var zoneStates: [String: Bool] = [:]
    private var zoneConfidence: [String: ZoneConfidence] = [:]
    
    // Configuration for validation
    private var requireConfirmation: Bool = true
    private var confirmationPoints: Int = 2
    private var confirmationTimeoutMs: TimeInterval = 10.0 // 10 seconds
    
    // Event callbacks
    private var eventCallback: ((String, String, CLLocation) -> Void)?
    
    // Performance tracking
    private var performanceMetrics: [String: Double] = [:]
    
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
     */
    func setEventCallback(_ callback: @escaping (String, String, CLLocation) -> Void) {
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
     * Add zone for monitoring
     */
    func addZone(zoneId: String, zoneName: String, zoneData: [String: Any]) throws {
        // Memory monitoring
        let memoryBefore = getCurrentMemoryUsage()
        
        // Zone count limit test
        let currentZoneCount = syncQueue.sync { zones.count }
        if currentZoneCount >= 50 {
            return
        }
        
        let zoneType = zoneData["type"] as? String ?? "unknown"
        
        if zoneType == "polygon" {
            if let coordinates = zoneData["coordinates"] as? [[Double]] {
                if coordinates.count > 50 {
                    // Large polygon detected - might cause memory issues
                }
            } else if let coords = zoneData["coords"] as? [[Double]] {
                // Found coords array
            } else if let polygonObjects = zoneData["polygon"] as? [[String: Any]] {
                // New format: array of objects { latitude: "..", longitude: ".." }
                var count = 0
                for point in polygonObjects {
                    if let latStr = point["latitude"] as? String,
                       let lonStr = point["longitude"] as? String,
                       Double(latStr) != nil, Double(lonStr) != nil {
                        count += 1
                    } else if let latNum = point["latitude"] as? NSNumber,
                              let lonNum = point["longitude"] as? NSNumber {
                        _ = latNum.doubleValue; _ = lonNum.doubleValue
                        count += 1
                    }
                }
            } else if let polygon = zoneData["polygon"] as? [[Double]] {
                // Found polygon array
            }
        }
        
        if zoneType == "circle" {
            // New format: center { latitude: "..", longitude: ".." }
            var lat: Double? = nil
            var lon: Double? = nil
            if let center = zoneData["center"] as? [String: Any] {
                if let latStr = center["latitude"] as? String, let latD = Double(latStr) {
                    lat = latD
                } else if let latNum = center["latitude"] as? NSNumber {
                    lat = latNum.doubleValue
                } else if let latNum = center["lat"] as? NSNumber {
                    lat = latNum.doubleValue
                } else if let latStr = center["lat"] as? String, let latD = Double(latStr) {
                    lat = latD
                }
                if let lonStr = center["longitude"] as? String, let lonD = Double(lonStr) {
                    lon = lonD
                } else if let lonNum = center["longitude"] as? NSNumber {
                    lon = lonNum.doubleValue
                } else if let lonNum = center["lng"] as? NSNumber {
                    lon = lonNum.doubleValue
                } else if let lonStr = center["lng"] as? String, let lonD = Double(lonStr) {
                    lon = lonD
                }
            }
            if lat == nil || lon == nil {
                // Fallback to top-level fields if provided
                if let latStr = zoneData["latitude"] as? String, let latD = Double(latStr) {
                    lat = latD
                } else if let latNum = zoneData["latitude"] as? NSNumber {
                    lat = latNum.doubleValue
                }
                if let lonStr = zoneData["longitude"] as? String, let lonD = Double(lonStr) {
                    lon = lonD
                } else if let lonNum = zoneData["longitude"] as? NSNumber {
                    lon = lonNum.doubleValue
                }
            }
            var radius: Double = 0
            if let rStr = zoneData["radius"] as? String, let r = Double(rStr) { radius = r }
            else if let rNum = zoneData["radius"] as? NSNumber { radius = rNum.doubleValue }
            if let lat = lat, let lon = lon {
                // Circle at \(lat), \(lon) with radius \(radius)m
            } else {
                // ERROR - No valid coordinates found for circle!
            }
        }
        
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
        }
    }
    
    /**
     * Clear all zones
     */
    func clearAllZones() {
        syncQueue.sync {
            self.zones.removeAll()
            self.zoneStates.removeAll()
            self.zoneConfidence.removeAll()
        }
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
        
        // Take a snapshot of current zones to avoid concurrent modification during iteration
        let snapshot: [(String, ZoneData)] = syncQueue.sync { self.zones.map { ($0.key, $0.value) } }
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
            // Performance warning for slow zones
            let zoneTime = (CFAbsoluteTimeGetCurrent() - zoneStartTime) * 1000
            if zoneTime > 10 {
                // Zone check took too long - potential performance issue
            }
            
            // Smart validation: Use confirmation based on speed and zone characteristics
            let useConfirmation = requireConfirmation ? shouldUseConfirmation(speed: speed, zoneRadius: zone.radius) : false
            
            let stateChanged: Bool
            if useConfirmation {
                let confidenceStartTime = CFAbsoluteTimeGetCurrent()
                stateChanged = processWithConfidence(zoneId: zoneId, zone: zone, isInside: isInside, currentState: currentState, currentTime: Date().timeIntervalSince1970, location: location)
                let confidenceDuration = CFAbsoluteTimeGetCurrent() - confidenceStartTime
                totalConfidenceTime += confidenceDuration
            } else {
                // Original logic for immediate detection
                stateChanged = processImmediate(zoneId: zoneId, zone: zone, isInside: isInside, currentState: currentState, location: location)
                if stateChanged {
                    // Zone state changed
                }
            }
            
        }
        
        let overallDuration = CFAbsoluteTimeGetCurrent() - overallStartTime
        if zoneCheckCount > 0 {
            // Geofence check completed
        }
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
    private func processWithConfidence(zoneId: String, zone: ZoneData, isInside: Bool, currentState: Bool, currentTime: TimeInterval, location: CLLocation) -> Bool {
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
            
            let eventType = isInside ? "ENTER" : "EXIT"
            eventCallback?(zoneId, eventType, location)
            
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
        
        return false // No state change
    }
    
    /**
     * Process immediate detection without confidence validation
     */
    private func processImmediate(zoneId: String, zone: ZoneData, isInside: Bool, currentState: Bool, location: CLLocation) -> Bool {
        do {
            // Check what happens when we detect a state change
            if isInside != currentState {
                handleStateChange(zoneId: zoneId, zoneName: zone.zoneName, isInside: isInside, location: location)
                
                syncQueue.sync { self.zoneStates[zoneId] = isInside }
                
                let eventType = isInside ? "ENTER" : "EXIT"
                eventCallback?(zoneId, eventType, location)
            }
            
            return isInside != currentState
        } catch {
            return false
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
        
        // Send notification safely (disabled for testing)
        do {
            sendNotification(zoneName: zoneName, eventType: isInside ? "ENTER" : "EXIT")
        } catch {
            // Notification failed
        }
        
        // Geofence events will be dispatched on the main thread in processImmediate/processWithConfidence.
    }
    
    /**
     * Send notification (disabled for testing)
     */
    private func sendNotification(zoneName: String, eventType: String) {
        // Notification disabled for testing
        return
    }
    
    /**
     * Validate location quality
     */
    private func isValidLocation(_ location: CLLocation) -> Bool {
        return location.horizontalAccuracy > 0 && location.horizontalAccuracy < 500
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