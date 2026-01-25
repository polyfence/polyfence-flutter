import Foundation
import CoreLocation

/**
 * Smart GPS Configuration System for Polyfence iOS
 * Provides flexible GPS accuracy/battery profiles for different use cases
 */
struct SmartGpsConfig {
    let accuracyProfile: AccuracyProfile
    let updateStrategy: UpdateStrategy
    let proximitySettings: ProximitySettings?
    let movementSettings: MovementSettings?
    let batterySettings: BatterySettings?
    let enableDebugLogging: Bool
    
    enum AccuracyProfile: String, CaseIterable {
        case maxAccuracy = "MAX_ACCURACY"
        case balanced = "BALANCED"
        case batteryOptimal = "BATTERY_OPTIMAL"
        case adaptive = "ADAPTIVE"
    }
    
    enum UpdateStrategy: String, CaseIterable {
        case continuous = "CONTINUOUS"
        case proximityBased = "PROXIMITY_BASED"
        case movementBased = "MOVEMENT_BASED"
        case intelligent = "INTELLIGENT"
    }
    
    init(
        accuracyProfile: AccuracyProfile = .balanced,  // P2: Changed from maxAccuracy for better battery
        updateStrategy: UpdateStrategy = .continuous,
        proximitySettings: ProximitySettings? = nil,
        movementSettings: MovementSettings? = nil,
        batterySettings: BatterySettings? = nil,
        enableDebugLogging: Bool = false
    ) {
        self.accuracyProfile = accuracyProfile
        self.updateStrategy = updateStrategy
        self.proximitySettings = proximitySettings
        self.movementSettings = movementSettings
        self.batterySettings = batterySettings
        self.enableDebugLogging = enableDebugLogging
    }
    
    /**
     * Get CLLocationAccuracy based on accuracy profile
     */
    func getCLLocationAccuracy() -> CLLocationAccuracy {
        switch accuracyProfile {
        case .maxAccuracy:
            return kCLLocationAccuracyBest
        case .balanced:
            return kCLLocationAccuracyNearestTenMeters
        case .batteryOptimal:
            return kCLLocationAccuracyHundredMeters
        case .adaptive:
            return kCLLocationAccuracyNearestTenMeters
        }
    }
    
    /**
     * Get distance filter for GPS updates
     */
    func getDistanceFilter() -> CLLocationDistance {
        switch accuracyProfile {
        case .maxAccuracy:
            return 10.0  // 10 meters
        case .balanced:
            return 20.0  // 20 meters
        case .batteryOptimal:
            return 50.0  // 50 meters
        case .adaptive:
            return 20.0  // 20 meters
        }
    }
    
    /**
     * Get base update interval based on accuracy profile
     */
    func getBaseUpdateInterval() -> TimeInterval {
        switch accuracyProfile {
        case .maxAccuracy:
            return 5.0      // 5 seconds
        case .balanced:
            return 10.0     // 10 seconds
        case .batteryOptimal:
            return 30.0     // 30 seconds
        case .adaptive:
            return 10.0     // 10 seconds
        }
    }
    
    /**
     * Whether to pause location updates automatically
     */
    func shouldPauseAutomatically() -> Bool {
        switch accuracyProfile {
        case .maxAccuracy:
            return false
        case .balanced:
            return true
        case .batteryOptimal:
            return true
        case .adaptive:
            return true
        }
    }
    
    /**
     * Log configuration for debugging
     */
    func logConfiguration(tag: String) {
        if enableDebugLogging {
            print("\(tag): Smart GPS Config - profile: \(accuracyProfile), strategy: \(updateStrategy)")
            if let proximity = proximitySettings {
                print("\(tag): Proximity - near: \(proximity.nearZoneThresholdMeters)m, far: \(proximity.farZoneThresholdMeters)m")
            }
            if let movement = movementSettings {
                print("\(tag): Movement - stationary: \(movement.stationaryThresholdMs)ms, moving: \(movement.movingUpdateIntervalMs)ms")
            }
            if let battery = batterySettings {
                print("\(tag): Battery - low: \(battery.lowBatteryThreshold)%, critical: \(battery.criticalBatteryThreshold)%")
            }
        }
    }
}

/**
 * Proximity-based optimization settings
 */
struct ProximitySettings {
    let nearZoneThresholdMeters: Double
    let farZoneThresholdMeters: Double
    let nearZoneUpdateIntervalMs: TimeInterval
    let farZoneUpdateIntervalMs: TimeInterval
    
    init(
        nearZoneThresholdMeters: Double = 500.0,
        farZoneThresholdMeters: Double = 2000.0,
        nearZoneUpdateIntervalMs: TimeInterval = 5.0,
        farZoneUpdateIntervalMs: TimeInterval = 60.0
    ) {
        self.nearZoneThresholdMeters = nearZoneThresholdMeters
        self.farZoneThresholdMeters = farZoneThresholdMeters
        self.nearZoneUpdateIntervalMs = nearZoneUpdateIntervalMs
        self.farZoneUpdateIntervalMs = farZoneUpdateIntervalMs
    }
    
    static func fromMap(_ map: [String: Any]) -> ProximitySettings {
        return ProximitySettings(
            nearZoneThresholdMeters: (map["nearZoneThresholdMeters"] as? NSNumber)?.doubleValue ?? 500.0,
            farZoneThresholdMeters: (map["farZoneThresholdMeters"] as? NSNumber)?.doubleValue ?? 2000.0,
            nearZoneUpdateIntervalMs: (map["nearZoneUpdateIntervalMs"] as? NSNumber)?.doubleValue ?? 5000.0 / 1000.0,
            farZoneUpdateIntervalMs: (map["farZoneUpdateIntervalMs"] as? NSNumber)?.doubleValue ?? 60000.0 / 1000.0
        )
    }
    
    func toMap() -> [String: Any] {
        return [
            "nearZoneThresholdMeters": nearZoneThresholdMeters,
            "farZoneThresholdMeters": farZoneThresholdMeters,
            "nearZoneUpdateIntervalMs": nearZoneUpdateIntervalMs * 1000.0,
            "farZoneUpdateIntervalMs": farZoneUpdateIntervalMs * 1000.0
        ]
    }
}

/**
 * Movement-based optimization settings
 */
struct MovementSettings {
    let stationaryThresholdMs: TimeInterval
    let movementThresholdMeters: Double
    let stationaryUpdateIntervalMs: TimeInterval
    let movingUpdateIntervalMs: TimeInterval
    
    init(
        stationaryThresholdMs: TimeInterval = 300.0,     // 5 minutes
        movementThresholdMeters: Double = 50.0,
        stationaryUpdateIntervalMs: TimeInterval = 120.0, // 2 minutes
        movingUpdateIntervalMs: TimeInterval = 10.0      // 10 seconds
    ) {
        self.stationaryThresholdMs = stationaryThresholdMs
        self.movementThresholdMeters = movementThresholdMeters
        self.stationaryUpdateIntervalMs = stationaryUpdateIntervalMs
        self.movingUpdateIntervalMs = movingUpdateIntervalMs
    }
    
    static func fromMap(_ map: [String: Any]) -> MovementSettings {
        return MovementSettings(
            stationaryThresholdMs: (map["stationaryThresholdMs"] as? NSNumber)?.doubleValue ?? 300000.0 / 1000.0,
            movementThresholdMeters: (map["movementThresholdMeters"] as? NSNumber)?.doubleValue ?? 50.0,
            stationaryUpdateIntervalMs: (map["stationaryUpdateIntervalMs"] as? NSNumber)?.doubleValue ?? 120000.0 / 1000.0,
            movingUpdateIntervalMs: (map["movingUpdateIntervalMs"] as? NSNumber)?.doubleValue ?? 10000.0 / 1000.0
        )
    }
    
    func toMap() -> [String: Any] {
        return [
            "stationaryThresholdMs": stationaryThresholdMs * 1000.0,
            "movementThresholdMeters": movementThresholdMeters,
            "stationaryUpdateIntervalMs": stationaryUpdateIntervalMs * 1000.0,
            "movingUpdateIntervalMs": movingUpdateIntervalMs * 1000.0
        ]
    }
}

/**
 * Battery-aware optimization settings
 */
struct BatterySettings {
    let lowBatteryThreshold: Int
    let criticalBatteryThreshold: Int
    let lowBatteryUpdateIntervalMs: TimeInterval
    let pauseOnCriticalBattery: Bool
    
    init(
        lowBatteryThreshold: Int = 20,
        criticalBatteryThreshold: Int = 10,
        lowBatteryUpdateIntervalMs: TimeInterval = 30.0,  // 30 seconds
        pauseOnCriticalBattery: Bool = true
    ) {
        self.lowBatteryThreshold = lowBatteryThreshold
        self.criticalBatteryThreshold = criticalBatteryThreshold
        self.lowBatteryUpdateIntervalMs = lowBatteryUpdateIntervalMs
        self.pauseOnCriticalBattery = pauseOnCriticalBattery
    }
    
    static func fromMap(_ map: [String: Any]) -> BatterySettings {
        return BatterySettings(
            lowBatteryThreshold: (map["lowBatteryThreshold"] as? NSNumber)?.intValue ?? 20,
            criticalBatteryThreshold: (map["criticalBatteryThreshold"] as? NSNumber)?.intValue ?? 10,
            lowBatteryUpdateIntervalMs: (map["lowBatteryUpdateIntervalMs"] as? NSNumber)?.doubleValue ?? 30000.0 / 1000.0,
            pauseOnCriticalBattery: (map["pauseOnCriticalBattery"] as? NSNumber)?.boolValue ?? true
        )
    }
    
    func toMap() -> [String: Any] {
        return [
            "lowBatteryThreshold": lowBatteryThreshold,
            "criticalBatteryThreshold": criticalBatteryThreshold,
            "lowBatteryUpdateIntervalMs": lowBatteryUpdateIntervalMs * 1000.0,
            "pauseOnCriticalBattery": pauseOnCriticalBattery
        ]
    }
}

/**
 * Factory for creating SmartGpsConfig from Flutter data
 */
struct SmartGpsConfigFactory {
    static func fromMap(_ map: [String: Any]) -> SmartGpsConfig {
        let accuracyProfile = parseEnum(
            map["accuracyProfile"] as? String,
            allCases: SmartGpsConfig.AccuracyProfile.allCases,
            fallback: SmartGpsConfig.AccuracyProfile.balanced  // P2: Changed default fallback to balanced
        )
        let updateStrategy = parseEnum(
            map["updateStrategy"] as? String,
            allCases: SmartGpsConfig.UpdateStrategy.allCases,
            fallback: SmartGpsConfig.UpdateStrategy.continuous
        )
        
        let proximitySettings = map["proximitySettings"] != nil ? 
            ProximitySettings.fromMap(map["proximitySettings"] as! [String: Any]) : nil
        
        let movementSettings = map["movementSettings"] != nil ? 
            MovementSettings.fromMap(map["movementSettings"] as! [String: Any]) : nil
        
        let batterySettings = map["batterySettings"] != nil ? 
            BatterySettings.fromMap(map["batterySettings"] as! [String: Any]) : nil
        
        let enableDebugLogging = map["enableDebugLogging"] as? Bool ?? false
        
        return SmartGpsConfig(
            accuracyProfile: accuracyProfile,
            updateStrategy: updateStrategy,
            proximitySettings: proximitySettings,
            movementSettings: movementSettings,
            batterySettings: batterySettings,
            enableDebugLogging: enableDebugLogging
        )
    }
    
    static func toMap(_ config: SmartGpsConfig) -> [String: Any] {
        var map: [String: Any] = [
            "accuracyProfile": config.accuracyProfile.rawValue,
            "updateStrategy": config.updateStrategy.rawValue,
            "enableDebugLogging": config.enableDebugLogging
        ]
        
        if let proximity = config.proximitySettings {
            map["proximitySettings"] = proximity.toMap()
        }
        
        if let movement = config.movementSettings {
            map["movementSettings"] = movement.toMap()
        }
        
        if let battery = config.batterySettings {
            map["batterySettings"] = battery.toMap()
        }
        
        return map
    }

    private static func parseEnum<T: CaseIterable & RawRepresentable>(_ value: String?, allCases: T.AllCases, fallback: T) -> T where T.RawValue == String {
        guard let value = value else { return fallback }
        let normalized = normalize(value)

        for candidate in allCases {
            if let enumCase = candidate as? T, normalize(enumCase.rawValue) == normalized {
                return enumCase
            }
        }

        return fallback
    }

    private static func normalize(_ value: String) -> String {
        let uppercased = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let filtered = uppercased.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
        return String(String.UnicodeScalarView(filtered))
    }
}
