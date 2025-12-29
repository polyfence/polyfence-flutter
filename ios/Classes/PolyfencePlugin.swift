import Flutter
import UIKit
import CoreLocation
import UserNotifications

public class PolyfencePlugin: NSObject, FlutterPlugin {
    
    // MARK: - Singleton
    private static var sharedInstance: PolyfencePlugin?
    
    // MARK: - Properties
    private var locationTracker: LocationTracker?
    private var zonePersistence: ZonePersistence?
    private var config: PolyfenceConfig?
    
    // Event channels
    private var locationChannel: FlutterEventChannel?
    private var geofenceChannel: FlutterEventChannel?
    private var errorChannel: FlutterEventChannel?
    private var performanceChannel: FlutterEventChannel?
    
    // Event sinks
    private var locationSink: FlutterEventSink?
    private var geofenceSink: FlutterEventSink?
    private var errorSink: FlutterEventSink?
    private var performanceSink: FlutterEventSink?
    
    // MARK: - Flutter Plugin Registration
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let methodChannel = FlutterMethodChannel(name: "polyfence", binaryMessenger: registrar.messenger())
        let locationChannel = FlutterEventChannel(name: "polyfence/location", binaryMessenger: registrar.messenger())
        let geofenceChannel = FlutterEventChannel(name: "polyfence/geofence", binaryMessenger: registrar.messenger())
        let errorChannel = FlutterEventChannel(name: "polyfence/error", binaryMessenger: registrar.messenger())
        let performanceChannel = FlutterEventChannel(name: "polyfence/performance", binaryMessenger: registrar.messenger())
        
        let instance = PolyfencePlugin()
        sharedInstance = instance
        
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        
        locationChannel.setStreamHandler(instance)
        geofenceChannel.setStreamHandler(instance)
        errorChannel.setStreamHandler(instance)
        performanceChannel.setStreamHandler(instance)
        
        instance.locationChannel = locationChannel
        instance.geofenceChannel = geofenceChannel
        instance.errorChannel = errorChannel
        instance.performanceChannel = performanceChannel
    }
    
    // MARK: - Static Event Sending Methods
    
    /**
     * Send performance events to dedicated performance channel
     */
    public static func sendPerformanceEvent(event: [String: Any]) {
        sharedInstance?.performanceSink?(event)
    }

    private func emitStatus(trackingEnabled: Bool?) {
        let zonesCount = (try? zonePersistence?.getZoneCount()) ?? 0
        let payload: [String: Any?] = [
            "type": "status",
            "trackingEnabled": trackingEnabled ?? false,
            "zonesCount": zonesCount,
            "profile": nil,
            "lastAccuracy": nil,
            "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
        ]
        PolyfencePlugin.sendPerformanceEvent(event: payload as [String : Any])
    }
    
    // MARK: - Method Channel Handler
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            initialize(arguments: call.arguments, result: result)
        case "requestPermissions":
            let args = call.arguments as? [String: Any]
            let always = (args?["always"] as? Bool) ?? false
            requestLocationPermissions(always: always, result: result)
        case "startTracking":
            startLocationTracking(result: result)
            emitStatus(trackingEnabled: true)
        case "stopTracking":
            stopLocationTracking(result: result)
            emitStatus(trackingEnabled: false)
        case "addZone":
            addZone(arguments: call.arguments, result: result)
            emitStatus(trackingEnabled: nil)
        case "removeZone":
            removeZone(arguments: call.arguments, result: result)
            emitStatus(trackingEnabled: nil)
        case "clearAllZones":
            clearAllZones(result: result)
            emitStatus(trackingEnabled: nil)
        case "isLocationServiceEnabled":
            result(CLLocationManager.locationServicesEnabled())
        case "getConfiguration":
            getConfiguration(result: result)
        case "updateConfiguration":
            updateConfiguration(arguments: call.arguments, result: result)
        case "resetConfiguration":
            resetConfiguration(result: result)
        case "getDebugInfo":
            getDebugInfo(result: result)
        case "getErrorHistory":
            getErrorHistory(arguments: call.arguments, result: result)
        case "getCurrentConfiguration":
            getCurrentConfiguration(result: result)
        case "setAccuracyProfile":
            setAccuracyProfile(arguments: call.arguments, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - Private Methods
    
    private func initialize(arguments: Any?, result: @escaping FlutterResult) {
        do {
            // Extract plugin version from config if provided
            if let args = arguments as? [String: Any],
               let configDict = args["config"] as? [String: Any],
               let version = configDict["pluginVersion"] as? String {
                PolyfenceDebugCollector.shared.setPluginVersion(version)
            }
            
            // Initialize configuration
            config = PolyfenceConfig()
            config?.validateAndCorrect()
            
            // Initialize persistence
            zonePersistence = ZonePersistence()
            
            // Initialize location tracker
            locationTracker = LocationTracker()
            
            // Setup callbacks
            locationTracker?.setLocationCallback { [weak self] locationData in
                self?.locationSink?(locationData)
            }
            
            locationTracker?.setGeofenceCallback { [weak self] zoneId, zoneName, eventType, detectionTimeMs, gpsAccuracy, latitude, longitude in
                let event: [String: Any] = [
                    "zoneId": zoneId,
                    "zoneName": zoneName,
                    "eventType": eventType,
                    "timestamp": Int64(Date().timeIntervalSince1970 * 1000),
                    "detectionTimeMs": detectionTimeMs,
                    "gpsAccuracy": gpsAccuracy,
                    "latitude": latitude,
                    "longitude": longitude,
                    "accuracy": gpsAccuracy
                ]
                
                // Terse geofence event log
                let displayName = zoneName.isEmpty ? zoneId : zoneName
                let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
                print("PF: EVENT \(eventType) zone=\(displayName) ts=\(timestamp)")
                
                if let sink = self?.geofenceSink {
                    sink(event)
                }
            }
            
            result(nil)
        } catch {
            result(FlutterError(code: "INITIALIZATION_FAILED", message: error.localizedDescription, details: nil))
        }
    }
    
    private func requestLocationPermissions(always: Bool, result: @escaping FlutterResult) {
        guard let locationTracker = locationTracker else {
            result(FlutterError(code: "NO_LOCATION_TRACKER", message: "Location tracker not initialized", details: nil))
            return
        }
        // Request location permissions using the same manager inside LocationTracker
        locationTracker.requestPermissions(always: always)
        let authorizationStatus = CLLocationManager.authorizationStatus()
        let granted = (authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse || authorizationStatus == .notDetermined)
        result(granted)

        // Notification permissions handled by LocationTracker
    }
    
    private func startLocationTracking(result: @escaping FlutterResult) {
        guard let locationTracker = locationTracker else {
            result(FlutterError(code: "NO_LOCATION_TRACKER", message: "Location tracker not initialized", details: nil))
            return
        }
        
        locationTracker.startTracking()
        result(nil)
    }
    
    private func stopLocationTracking(result: @escaping FlutterResult) {
        guard let locationTracker = locationTracker else {
            result(FlutterError(code: "NO_LOCATION_TRACKER", message: "Location tracker not initialized", details: nil))
            return
        }
        
        locationTracker.stopTracking()
        result(nil)
    }
    
    private func addZone(arguments: Any?, result: @escaping FlutterResult) {
        guard let zoneData = arguments as? [String: Any],
              let zoneId = zoneData["id"] as? String,
              let zoneName = zoneData["name"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid zone data", details: nil))
            return
        }
        
        guard let locationTracker = locationTracker else {
            result(FlutterError(code: "NO_LOCATION_TRACKER", message: "Location tracker not initialized", details: nil))
            return
        }
        
        do {
            locationTracker.addZone(zoneId: zoneId, zoneName: zoneName, zoneData: zoneData)
            result(nil)
        } catch {
            result(FlutterError(code: "ZONE_ADDITION_FAILED", message: error.localizedDescription, details: nil))
        }
    }
    
    private func removeZone(arguments: Any?, result: @escaping FlutterResult) {
        guard let args = arguments as? [String: Any],
              let zoneId = args["zoneId"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid zone ID", details: nil))
            return
        }
        
        guard let locationTracker = locationTracker else {
            result(FlutterError(code: "NO_LOCATION_TRACKER", message: "Location tracker not initialized", details: nil))
            return
        }
        
        locationTracker.removeZone(zoneId: zoneId)
        result(nil)
    }
    
    private func clearAllZones(result: @escaping FlutterResult) {
        guard let locationTracker = locationTracker else {
            result(FlutterError(code: "NO_LOCATION_TRACKER", message: "Location tracker not initialized", details: nil))
            return
        }
        
        locationTracker.clearAllZones()
        result(nil)
    }
    
    private func getConfiguration(result: @escaping FlutterResult) {
        guard let locationTracker = locationTracker else {
            result(FlutterError(code: "NO_LOCATION_TRACKER", message: "Location tracker not initialized", details: nil))
            return
        }

        let smartConfig = locationTracker.getCurrentSmartConfiguration()
        let configMap = SmartGpsConfigFactory.toMap(smartConfig)
        result(configMap)
    }
    
    private func updateConfiguration(arguments: Any?, result: @escaping FlutterResult) {
        guard let configMap = arguments as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid configuration data", details: nil))
            return
        }
        
        do {
            let smartConfig = SmartGpsConfigFactory.fromMap(configMap)
            config?.updateConfiguration(configMap)
            locationTracker?.updateSmartConfiguration(smartConfig)
            
            // Update GPS accuracy threshold in GeofenceEngine if provided
            if let gpsAccuracyThreshold = configMap["gpsAccuracyThreshold"] as? Double {
                locationTracker?.setGpsAccuracyThreshold(gpsAccuracyThreshold)
                config?.gpsAccuracyThreshold = gpsAccuracyThreshold
            }
            
            result(nil)
        } catch {
            result(FlutterError(code: "CONFIG_UPDATE_FAILED", message: "Failed to update smart GPS configuration: \(error.localizedDescription)", details: nil))
        }
    }
    
    private func getCurrentConfiguration(result: @escaping FlutterResult) {
        guard let locationTracker = locationTracker else {
            result(FlutterError(code: "NO_LOCATION_TRACKER", message: "Location tracker not initialized", details: nil))
            return
        }
        
        // Get smart GPS configuration
        let smartConfig = locationTracker.getCurrentSmartConfiguration()
        let configMap = SmartGpsConfigFactory.toMap(smartConfig)
        result(configMap)
    }
    
    private func resetConfiguration(result: @escaping FlutterResult) {
        guard let config = config else {
            result(FlutterError(code: "NO_CONFIG", message: "Configuration not initialized", details: nil))
            return
        }
        
        config.resetConfiguration()
        result(nil)
    }

    private func setAccuracyProfile(arguments: Any?, result: @escaping FlutterResult) {
        guard let profileName = arguments as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Accuracy profile value required", details: nil))
            return
        }

        guard let locationTracker = locationTracker else {
            result(FlutterError(code: "NO_LOCATION_TRACKER", message: "Location tracker not initialized", details: nil))
            return
        }

        let normalized = normalizeEnumValue(profileName)
        let currentConfig = locationTracker.getCurrentSmartConfiguration()
        let targetProfile = SmartGpsConfig.AccuracyProfile.allCases.first(where: {
            normalizeEnumValue($0.rawValue) == normalized
        }) ?? .maxAccuracy

        let updatedConfig = SmartGpsConfig(
            accuracyProfile: targetProfile,
            updateStrategy: currentConfig.updateStrategy,
            proximitySettings: currentConfig.proximitySettings,
            movementSettings: currentConfig.movementSettings,
            batterySettings: currentConfig.batterySettings,
            enableDebugLogging: currentConfig.enableDebugLogging
        )

        locationTracker.updateSmartConfiguration(updatedConfig)
        result(nil)
    }

    private func normalizeEnumValue(_ value: String) -> String {
        let uppercased = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let filtered = uppercased.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
        return String(String.UnicodeScalarView(filtered))
    }
}

// MARK: - Flutter Stream Handler

extension PolyfencePlugin: FlutterStreamHandler {
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        // Determine which channel based on argument from Dart
        if let arg = arguments as? String {
            switch arg {
            case "location":
                locationSink = events
                // Emit last known location immediately if available
                if let last = locationTracker?.getLastKnownLocationData() {
                    events(last)
                }
            case "geofence":
                geofenceSink = events
            case "error":
                errorSink = events
                // Initialize error manager with the event sink
                PolyfenceErrorManager.shared.initialize(eventSink: events)
            case "performance":
                performanceSink = events
            default:
                locationSink = events
            }
        } else {
            // Fallback: if no arg provided, attach to first available slot
            if locationSink == nil {
                locationSink = events
            } else if geofenceSink == nil {
                geofenceSink = events
            } else if errorSink == nil {
                errorSink = events
                PolyfenceErrorManager.shared.initialize(eventSink: events)
            } else if performanceSink == nil {
                performanceSink = events
            }
        }
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        // Clear sink based on argument from Dart
        if let arg = arguments as? String {
            switch arg {
            case "location":
                locationSink = nil
            case "geofence":
                geofenceSink = nil
            case "error":
                errorSink = nil
            case "performance":
                performanceSink = nil
            default:
                break
            }
        } else {
            // Fallback: clear all sinks
            locationSink = nil
            geofenceSink = nil
            errorSink = nil
            performanceSink = nil
        }
        return nil
    }
    
    // MARK: - Debug Methods
    
    private func getDebugInfo(result: @escaping FlutterResult) {
        let debugInfo: [String: Any] = [
            "systemStatus": [
                "isLocationPermissionGranted": CLLocationManager.authorizationStatus() == .authorizedAlways || CLLocationManager.authorizationStatus() == .authorizedWhenInUse,
                "isBackgroundLocationEnabled": CLLocationManager.authorizationStatus() == .authorizedAlways,
                "isBatteryOptimizationDisabled": true, // iOS doesn't have battery optimization
                "isGpsEnabled": CLLocationManager.locationServicesEnabled(),
                "isWakeLockAcquired": false, // iOS doesn't use wake locks
                "lastKnownAccuracy": -1.0,
                "lastLocationUpdate": Date().timeIntervalSince1970 * 1000,
                "platformVersion": UIDevice.current.systemVersion,
                "pluginVersion": PolyfenceDebugCollector.shared.pluginVersion ?? "unknown"
            ],
            "performance": [
                "uptime": 0,
                "totalLocationUpdates": 0,
                "totalZoneDetections": 0,
                "averageDetectionLatency": 0.0,
                "memoryUsageMB": 0,
                "cpuUsagePercent": 0.0,
                "restartCount": 0
            ],
            "battery": [
                "estimatedHourlyDrain": 0.0,
                "gpsActiveTimePercent": 0,
                "wakeUpCount": 0,
                "isCharging": UIDevice.current.batteryState == .charging,
                "batteryLevel": Int(UIDevice.current.batteryLevel * 100),
                "totalActiveTime": 0
            ],
            "zones": [
                "activeZones": 0,
                "circleZones": 0,
                "polygonZones": 0,
                "lastZoneUpdate": Date().timeIntervalSince1970 * 1000,
                "zoneEventCounts": [:]
            ],
            "recentErrors": []
        ]
        result(debugInfo)
    }
    
    private func getErrorHistory(arguments: Any?, result: @escaping FlutterResult) {
        result([])
    }
}
