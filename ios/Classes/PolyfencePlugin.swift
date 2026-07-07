import Flutter
import UIKit
import CoreLocation
import UserNotifications
import PolyfenceCore

public class PolyfencePlugin: NSObject, FlutterPlugin {
    
    // MARK: - Singleton
    private static var sharedInstance: PolyfencePlugin?
    
    // MARK: - Properties
    private var locationTracker: LocationTracker?
    private var zonePersistence: ZonePersistence?
    // No cached `PolyfenceConfig` field: getConfiguration reads
    // exclusively from locationTracker.getCurrentConfigurationMap()
    // and updateConfiguration routes through the core method, so an
    // instance field would be orphan scaffolding whose only cost is
    // wasted startup work (NSUserDefaults read).
    
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
        // Callers pass nil on addZone / removeZone / clearAllZones —
        // the status event isn't caused by a start/stop, so fall back
        // to querying the real state instead of reporting false.
        // Matches RN parity (polyfence-react-native/ios/PolyfenceModule.swift).
        let tracking = trackingEnabled ?? (locationTracker?.isTracking() ?? false)
        // Populate profile + lastAccuracy from polyfence-core rather
        // than hardcoding nil — otherwise consumers reading
        // status.profile and status.lastAccuracy see null regardless
        // of runtime state, which suggests data is unavailable when
        // it isn't.
        let profile: Any = locationTracker?.getCurrentSmartConfiguration().accuracyProfile.rawValue ?? NSNull()
        let lastAccuracy: Any = locationTracker?.getLastKnownAccuracy() ?? NSNull()
        let payload: [String: Any] = [
            "type": "status",
            "trackingEnabled": tracking,
            "zonesCount": zonesCount,
            "profile": profile,
            "lastAccuracy": lastAccuracy,
            "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
        ]
        PolyfencePlugin.sendPerformanceEvent(event: payload)
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
        case "setAccuracyProfile":
            setAccuracyProfile(arguments: call.arguments, result: result)
        case "getCurrentZoneStates":
            getCurrentZoneStates(result: result)
        case "getSessionTelemetry":
            getSessionTelemetry(result: result)
        case "requestBatteryOptimization":
            // iOS does not have a battery-optimization-exemption dialog —
            // the concept is Android-only. No-op so the cross-platform
            // contract resolves cleanly on both platforms.
            result(nil)
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

            // Initialize persistence
            zonePersistence = ZonePersistence()

            // Initialize location tracker
            locationTracker = LocationTracker()

            // Tag telemetry with bridge platform
            locationTracker?.setBridgePlatform("flutter")

            // Handle disableAlertNotifications config
            if let args = arguments as? [String: Any],
               let configDict = args["config"] as? [String: Any],
               let disableAlerts = configDict["disableAlertNotifications"] as? Bool {
                locationTracker?.setAlertNotificationsEnabled(!disableAlerts)
            }
            
            // Setup callbacks
            locationTracker?.setLocationCallback { [weak self] locationData in
                self?.locationSink?(locationData)
            }
            
            locationTracker?.setGeofenceCallback { [weak self] eventData in
                // Terse geofence event log
                let eventType = eventData["eventType"] as? String ?? "?"
                let zoneName = eventData["zoneName"] as? String ?? ""
                let zoneId = eventData["zoneId"] as? String ?? ""
                let displayName = zoneName.isEmpty ? zoneId : zoneName
                NSLog("PF: EVENT %@ zone=%@ ts=%lld", eventType, displayName, Int64(Date().timeIntervalSince1970 * 1000))

                if let sink = self?.geofenceSink {
                    sink(eventData)
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

        // Use the composed 12-key shape from
        // LocationTracker.getCurrentConfigurationMap rather than the
        // 6-key SmartGpsConfig.toMap shape — the five extra fields
        // (gpsAccuracyThreshold, dwellSettings, clusterSettings,
        // scheduleSettings, activitySettings) live on GeofenceEngine /
        // TrackingScheduler.shared / the tracker instance and can only
        // be assembled at the LocationTracker level.
        let configMap = locationTracker.getCurrentConfigurationMap()
        result(configMap)
    }
    
    private func updateConfiguration(arguments: Any?, result: @escaping FlutterResult) {
        guard let configMap = arguments as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid configuration data", details: nil))
            return
        }

        // Guard the tracker explicitly to match RN iOS and every
        // other config method in this plugin — optional chaining
        // would silently succeed when a caller invokes
        // updateConfiguration before initialize().
        guard let locationTracker = locationTracker else {
            result(FlutterError(
                code: "NO_LOCATION_TRACKER",
                message: "Location tracker not initialized",
                details: nil
            ))
            return
        }

        // Delegate to the core's single-source
        // updateConfigurationFromMap, which merges the SmartGpsConfig
        // portion, applies the six extras subsystems
        // (gpsAccuracyThreshold, dwell, cluster, schedule, activity,
        // disableAlertNotifications), and keeps the field coverage in
        // lockstep with Kotlin's identically-named method. No
        // surrounding do/catch — the core method doesn't throw.
        locationTracker.updateConfigurationFromMap(configMap)
        result(nil)
    }
    
    private func resetConfiguration(result: @escaping FlutterResult) {
        // Route through the core `LocationTracker.resetSmartConfiguration()`
        // which resets the full 12-field surface (SmartGpsConfig +
        // dwell / cluster / gpsAccuracyThreshold + TrackingScheduler +
        // activitySettings + alertNotifications). Anything less (e.g.
        // clearing NSUserDefaults keys directly) would leave subsystems
        // that live outside NSUserDefaults at whatever the caller had
        // configured — inconsistent with RN iOS and both Android
        // bridges.
        guard let locationTracker = locationTracker else {
            result(FlutterError(code: "NO_LOCATION_TRACKER", message: "Location tracker not initialized", details: nil))
            return
        }

        locationTracker.resetSmartConfiguration()
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

    private func getCurrentZoneStates(result: @escaping FlutterResult) {
        guard let locationTracker = locationTracker else {
            result(FlutterError(code: "NO_LOCATION_TRACKER", message: "Location tracker not initialized", details: nil))
            return
        }

        let states = locationTracker.getCurrentZoneStates()
        result(states)
    }

    private func getSessionTelemetry(result: @escaping FlutterResult) {
        guard let locationTracker = locationTracker else {
            result(FlutterError(code: "NO_LOCATION_TRACKER", message: "Not initialized", details: nil))
            return
        }
        var telemetry = locationTracker.getSessionTelemetryData()
        telemetry["deviceCategory"] = Self.getDeviceCategory()
        telemetry["osVersionMajor"] = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        telemetry["chargingDuringSession"] = UIDevice.current.batteryState == .charging || UIDevice.current.batteryState == .full
        result(telemetry)
    }

    /**
     * Returns a bucketed device category (not exact model) for ML telemetry.
     */
    private static func getDeviceCategory() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0) ?? "unknown"
            }
        }

        if machine.hasPrefix("iPhone") {
            let parts = machine.replacingOccurrences(of: "iPhone", with: "").split(separator: ",")
            if let major = Int(parts.first ?? "") {
                if major >= 15 { return "iphone_flagship" }
                if major >= 12 { return "iphone_standard" }
                return "iphone_older"
            }
        }
        if machine.hasPrefix("iPad") { return "ipad" }
        return "ios_other"
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
                // Bridge error manager to Flutter via closure wrapper
                PolyfenceErrorManager.shared.initialize(errorCallback: { data in events(data) })
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
                PolyfenceErrorManager.shared.initialize(errorCallback: { data in events(data) })
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
                PolyfenceErrorManager.shared.dispose()
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
            PolyfenceErrorManager.shared.dispose()
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
