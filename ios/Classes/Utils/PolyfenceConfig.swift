import Foundation

/**
 * Centralized configuration management for Polyfence iOS
 * Single responsibility: Runtime configuration and persistence
 * Ported from Android PolyfenceConfig.kt
 */
class PolyfenceConfig {
    
    // MARK: - Constants
    private static let TAG = "PolyfenceConfig"
    private static let PREFS_NAME = "polyfence_config"
    
    // Default GPS Configuration
    static let DEFAULT_GPS_INTERVAL_MS: TimeInterval = 5.0 // 5 seconds - balanced
    static let DEFAULT_GPS_ACCURACY_THRESHOLD: Double = 100.0
    static let DEFAULT_MIN_UPDATE_INTERVAL_MS: TimeInterval = 1.0
    static let DEFAULT_MAX_UPDATE_DELAY_MS: TimeInterval = 6.0
    static let MIN_UPDATE_DISTANCE_METERS: Double = 10.0
    
    // Zone Validation Configuration
    static let DEFAULT_CONFIDENCE_POINTS: Int = 2
    static let DEFAULT_CONFIDENCE_TIMEOUT_MS: TimeInterval = 10.0
    static let DEFAULT_REQUIRE_CONFIRMATION: Bool = true
    static let LARGE_ZONE_RADIUS_THRESHOLD_METERS: Double = 200.0
    static let MIN_SINGLE_POINT_ZONE_RADIUS_METERS: Double = 50.0
    static let MIN_POLYGON_POINTS: Int = 3
    
    // Speed and Movement Thresholds
    static let HIGH_SPEED_THRESHOLD_KMH: Double = 40.0
    static let SPEED_MS_TO_KMH_MULTIPLIER: Double = 3.6
    
    // GPS Health and Recovery
    static let MAX_GPS_FAILURES_BEFORE_COOLDOWN: Int = 2
    static let MIN_GPS_FAILURES_FOR_RECOVERY: Int = 3
    static let MAX_GPS_FAILURES_FOR_RECOVERY: Int = 5
    static let GPS_HEALTH_CHECK_TIMEOUT_MS: TimeInterval = 120.0 // 2 minutes
    static let HEALTH_CHECK_INTERVAL_MS: TimeInterval = 30.0 // 30 seconds
    static let GPS_RESTART_DELAY_MS: TimeInterval = 3.0 // 3 seconds
    static let SERVICE_RESTART_DELAY_MS: TimeInterval = 5.0 // 5 seconds
    
    // GPS Restart Configuration
    static let MIN_GPS_RESTART_INTERVAL_MS: TimeInterval = 10.0 // 10 seconds
    static let MIN_UPDATE_RESTART_INTERVAL_MS: TimeInterval = 5.0 // 5 seconds
    static let MAX_UPDATE_RESTART_DELAY_MS: TimeInterval = 15.0 // 15 seconds
    
    // System Defaults
    static let DEFAULT_BATTERY_LEVEL: Double = 100.0
    static let MOCK_CPU_USAGE_PERCENT: Double = 5.0
    static let DEVICE_ID_RANDOM_RANGE: Int = 10000
    static let FOREGROUND_NOTIFICATION_ID: Int = 1001
    static let APP_VERSION: String = "1.0.0"
    
    // Validation Ranges
    static let MIN_GPS_INTERVAL_MS: TimeInterval = 1.0
    static let MAX_GPS_INTERVAL_MS: TimeInterval = 60.0
    static let MIN_ACCURACY_THRESHOLD: Double = 1.0
    static let MAX_ACCURACY_THRESHOLD: Double = 500.0
    static let MIN_CONFIDENCE_POINTS: Int = 1
    static let MAX_CONFIDENCE_POINTS: Int = 5
    
    // Calculation Factors
    static let MIN_UPDATE_INTERVAL_FACTOR: TimeInterval = 2.0 // minInterval = gpsInterval / 2
    static let MAX_UPDATE_DELAY_FACTOR: TimeInterval = 2.0 // maxDelay = gpsInterval * 2
    
    // MARK: - Properties
    private let userDefaults = UserDefaults.standard
    
    // GPS Configuration
    var gpsIntervalMs: TimeInterval {
        get {
            return userDefaults.double(forKey: "gps_interval_ms")
        }
        set {
            userDefaults.set(newValue, forKey: "gps_interval_ms")
        }
    }
    
    var gpsAccuracyThreshold: Double {
        get {
            return userDefaults.double(forKey: "gps_accuracy_threshold")
        }
        set {
            userDefaults.set(newValue, forKey: "gps_accuracy_threshold")
        }
    }
    
    var minUpdateIntervalMs: TimeInterval {
        get {
            return userDefaults.double(forKey: "min_update_interval_ms")
        }
        set {
            userDefaults.set(newValue, forKey: "min_update_interval_ms")
        }
    }
    
    var maxUpdateDelayMs: TimeInterval {
        get {
            return userDefaults.double(forKey: "max_update_delay_ms")
        }
        set {
            userDefaults.set(newValue, forKey: "max_update_delay_ms")
        }
    }
    
    // Validation Configuration
    var requireConfirmation: Bool {
        get {
            return userDefaults.bool(forKey: "require_confirmation")
        }
        set {
            userDefaults.set(newValue, forKey: "require_confirmation")
        }
    }
    
    var confidencePoints: Int {
        get {
            return userDefaults.integer(forKey: "confidence_points")
        }
        set {
            userDefaults.set(newValue, forKey: "confidence_points")
        }
    }
    
    var confidenceTimeoutMs: TimeInterval {
        get {
            return userDefaults.double(forKey: "confidence_timeout_ms")
        }
        set {
            userDefaults.set(newValue, forKey: "confidence_timeout_ms")
        }
    }
    
    // MARK: - Initialization
    
    init() {
        // Set default values if not already set
        if userDefaults.object(forKey: "gps_interval_ms") == nil {
            gpsIntervalMs = PolyfenceConfig.DEFAULT_GPS_INTERVAL_MS
        }
        if userDefaults.object(forKey: "gps_accuracy_threshold") == nil {
            gpsAccuracyThreshold = PolyfenceConfig.DEFAULT_GPS_ACCURACY_THRESHOLD
        }
        if userDefaults.object(forKey: "min_update_interval_ms") == nil {
            minUpdateIntervalMs = PolyfenceConfig.DEFAULT_MIN_UPDATE_INTERVAL_MS
        }
        if userDefaults.object(forKey: "max_update_delay_ms") == nil {
            maxUpdateDelayMs = PolyfenceConfig.DEFAULT_MAX_UPDATE_DELAY_MS
        }
        if userDefaults.object(forKey: "require_confirmation") == nil {
            requireConfirmation = PolyfenceConfig.DEFAULT_REQUIRE_CONFIRMATION
        }
        if userDefaults.object(forKey: "confidence_points") == nil {
            confidencePoints = PolyfenceConfig.DEFAULT_CONFIDENCE_POINTS
        }
        if userDefaults.object(forKey: "confidence_timeout_ms") == nil {
            confidenceTimeoutMs = PolyfenceConfig.DEFAULT_CONFIDENCE_TIMEOUT_MS
        }
    }
    
    // MARK: - Public Methods
    
    /**
     * Validate and correct configuration values
     */
    func validateAndCorrect() {
        // Ensure GPS interval is reasonable
        if gpsIntervalMs < PolyfenceConfig.MIN_GPS_INTERVAL_MS || gpsIntervalMs > PolyfenceConfig.MAX_GPS_INTERVAL_MS {
            gpsIntervalMs = PolyfenceConfig.DEFAULT_GPS_INTERVAL_MS
        }
        
        // Ensure accuracy threshold is reasonable
        if gpsAccuracyThreshold < PolyfenceConfig.MIN_ACCURACY_THRESHOLD || gpsAccuracyThreshold > PolyfenceConfig.MAX_ACCURACY_THRESHOLD {
            gpsAccuracyThreshold = PolyfenceConfig.DEFAULT_GPS_ACCURACY_THRESHOLD
        }
        
        // Ensure confidence points are reasonable
        if confidencePoints < PolyfenceConfig.MIN_CONFIDENCE_POINTS || confidencePoints > PolyfenceConfig.MAX_CONFIDENCE_POINTS {
            confidencePoints = PolyfenceConfig.DEFAULT_CONFIDENCE_POINTS
        }
        
        // Ensure min update interval is less than GPS interval
        if minUpdateIntervalMs >= gpsIntervalMs {
            minUpdateIntervalMs = gpsIntervalMs / PolyfenceConfig.MIN_UPDATE_INTERVAL_FACTOR
        }
        
        // Ensure max update delay is greater than GPS interval
        if maxUpdateDelayMs <= gpsIntervalMs {
            maxUpdateDelayMs = gpsIntervalMs * PolyfenceConfig.MAX_UPDATE_DELAY_FACTOR
        }
        
        // Configuration validated successfully
    }
    
    /**
     * Get configuration as dictionary
     */
    func getConfiguration() -> [String: Any] {
        return [
            "gps_interval_ms": gpsIntervalMs,
            "gps_accuracy_threshold": gpsAccuracyThreshold,
            "min_update_interval_ms": minUpdateIntervalMs,
            "max_update_delay_ms": maxUpdateDelayMs,
            "require_confirmation": requireConfirmation,
            "confidence_points": confidencePoints,
            "confidence_timeout_ms": confidenceTimeoutMs
        ]
    }
    
    /**
     * Update configuration from dictionary
     */
    func updateConfiguration(_ configMap: [String: Any]) {
        if let gpsInterval = configMap["gps_interval_ms"] as? Double {
            gpsIntervalMs = gpsInterval
        }
        
        if let accuracyThreshold = configMap["gps_accuracy_threshold"] as? Double {
            gpsAccuracyThreshold = accuracyThreshold
        }
        
        if let minUpdateInterval = configMap["min_update_interval_ms"] as? Double {
            minUpdateIntervalMs = minUpdateInterval
        }
        
        if let maxUpdateDelay = configMap["max_update_delay_ms"] as? Double {
            maxUpdateDelayMs = maxUpdateDelay
        }
        
        if let requireConf = configMap["require_confirmation"] as? Bool {
            requireConfirmation = requireConf
        }
        
        if let confPoints = configMap["confidence_points"] as? Int {
            confidencePoints = confPoints
        }
        
        if let confTimeout = configMap["confidence_timeout_ms"] as? Double {
            confidenceTimeoutMs = confTimeout
        }
        
        // Validate after update
        validateAndCorrect()
        
        // Configuration updated successfully
    }
    
    /**
     * Reset configuration to defaults
     */
    func resetConfiguration() {
        gpsIntervalMs = PolyfenceConfig.DEFAULT_GPS_INTERVAL_MS
        gpsAccuracyThreshold = PolyfenceConfig.DEFAULT_GPS_ACCURACY_THRESHOLD
        minUpdateIntervalMs = PolyfenceConfig.DEFAULT_MIN_UPDATE_INTERVAL_MS
        maxUpdateDelayMs = PolyfenceConfig.DEFAULT_MAX_UPDATE_DELAY_MS
        requireConfirmation = PolyfenceConfig.DEFAULT_REQUIRE_CONFIRMATION
        confidencePoints = PolyfenceConfig.DEFAULT_CONFIDENCE_POINTS
        confidenceTimeoutMs = PolyfenceConfig.DEFAULT_CONFIDENCE_TIMEOUT_MS
        
        // Configuration reset successfully
    }
} 