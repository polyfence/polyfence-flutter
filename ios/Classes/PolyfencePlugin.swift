import Flutter
import UIKit
import CoreLocation
import UserNotifications
import PolyfenceCore

public class PolyfencePlugin: NSObject, FlutterPlugin, PolyfenceCoreDelegate {
    
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

    deinit {
        if let observer = terminationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        locationTracker?.setBridgeAttached(false)
        LocationTracker.setEventListenerActive(false)
        locationTracker?.coreDelegate = nil
    }
    
    // MARK: - Flutter Plugin Registration
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let methodChannel = FlutterMethodChannel(name: "polyfence", binaryMessenger: registrar.messenger())
        let locationChannel = FlutterEventChannel(name: "polyfence/location", binaryMessenger: registrar.messenger())
        let geofenceChannel = FlutterEventChannel(name: "polyfence/geofence", binaryMessenger: registrar.messenger())
        let errorChannel = FlutterEventChannel(name: "polyfence/error", binaryMessenger: registrar.messenger())
        let performanceChannel = FlutterEventChannel(name: "polyfence/performance", binaryMessenger: registrar.messenger())
        
        // Declare that this bridge owns the listener-live signal, before any
        // tracker is constructed. Core would otherwise treat delegate
        // registration as a direct-Swift consumer subscribing and replay the
        // durable queue during initialize() — into a Dart stream the app has
        // not subscribed to yet.
        LocationTracker.setEventListenerActive(false)

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
        case "stopTracking":
            stopLocationTracking(result: result)
        case "addZone":
            addZone(arguments: call.arguments, result: result)
        case "removeZone":
            removeZone(arguments: call.arguments, result: result)
        case "clearAllZones":
            clearAllZones(result: result)
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
        case "drainPendingEvents":
            drainPendingEvents(result: result)
        case "pendingEventsDroppedCount":
            pendingEventsDroppedCount(result: result)
        case "setEventListenerActive":
            let active = (call.arguments as? [String: Any])?["active"] as? Bool ?? false
            LocationTracker.setEventListenerActive(active)
            result(nil)
        case "dispose":
            signalBridgeDetached()
            result(nil)
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

            // Apply all remaining tracking config fields (accuracyProfile,
            // updateStrategy, gpsAccuracyThreshold, nested settings, etc.).
            // Strip plugin-only keys that have dedicated handlers above so
            // they are not double-processed by updateConfigurationFromMap.
            if let args = arguments as? [String: Any],
               let configDict = args["config"] as? [String: Any] {
                var gpsConfig = configDict
                gpsConfig.removeValue(forKey: "pluginVersion")
                gpsConfig.removeValue(forKey: "disableAlertNotifications")
                if !gpsConfig.isEmpty {
                    locationTracker?.updateConfigurationFromMap(gpsConfig)
                }
            }

            // Wire the plugin as core's delegate. Geofence + location events
            // flow through PolyfenceCoreDelegate methods (onGeofenceEvent
            // etc.), which routes to the Flutter EventChannel sink. Using
            // the delegate — not setGeofenceCallback / setLocationCallback —
            // preserves core's XOR contract: when the queue is enabled
            // (pendingEventsQueueSize > 0), core delivers via the delegate
            // OR persists to disk, never both. The direct-Swift callbacks
            // fire unconditionally and would double-emit every event.
            locationTracker?.coreDelegate = self

            // Start in the "not-yet-listening" state so any geofence event
            // that fires between initialize returning and the geofence
            // FlutterStreamHandler's first onListen lands in the durable
            // pending-events queue (when opted in) instead of core
            // delivering to a nil sink. Core's own default is `true`, which
            // would mis-classify this window as live-delivery and silently
            // drop the event; onListen flips this back to `true` when the
            // Dart-side subscription is up.
            locationTracker?.setBridgeAttached(false)
            observeTerminationForBridgeDetach()

            result(nil)
        } catch {
            result(FlutterError(code: "INITIALIZATION_FAILED", message: error.localizedDescription, details: nil))
        }
    }

    // MARK: - PolyfenceCoreDelegate

    public func onGeofenceEvent(_ eventData: [String: Any]) {
        let eventType = eventData["eventType"] as? String ?? "?"
        let zoneName = eventData["zoneName"] as? String ?? ""
        let zoneId = eventData["zoneId"] as? String ?? ""
        let displayName = zoneName.isEmpty ? zoneId : zoneName
        NSLog("PF: EVENT %@ zone=%@ ts=%lld", eventType, displayName, Int64(Date().timeIntervalSince1970 * 1000))
        // FlutterEventSink is main-thread-only; core already dispatches
        // delegate callbacks on main.
        geofenceSink?(eventData)
    }

    public func onLocationUpdate(_ locationData: [String: Any]) {
        locationSink?(locationData)
    }

    public func onPerformanceEvent(_ performanceData: [String: Any]) {
        performanceSink?(performanceData)
    }

    public func onError(_ errorData: [String: Any]) {
        errorSink?(errorData)
    }

    public func isTrackingEnabled() -> Bool {
        return locationTracker?.isTracking() ?? false
    }

    /// Register a one-shot observer that detaches the bridge when the host
    /// app is about to terminate. The paired queue-persist path only kicks in
    /// when core knows the bridge is gone; without this hook a foreground
    /// termination would let events fire after the app is dead but before the
    /// process is fully torn down, and they would drop at the delegate boundary.
    private var terminationObserver: NSObjectProtocol?
    private func observeTerminationForBridgeDetach() {
        if terminationObserver != nil { return }
        terminationObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.signalBridgeDetached()
        }
    }

    /// Signal to core that the bridge's delivery sink is no longer receiving,
    /// so subsequent geofence events land in the durable queue (when opted-in
    /// via pendingEventsQueueSize > 0) instead of dropping.
    private func signalBridgeDetached() {
        locationTracker?.setBridgeAttached(false)
        LocationTracker.setEventListenerActive(false)
    }

    private func drainPendingEvents(result: @escaping FlutterResult) {
        guard let locationTracker = locationTracker else {
            result([[String: Any]]())
            return
        }
        let raw = locationTracker.drainPendingEvents()
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        let enriched: [[String: Any]] = raw.map { event in
            var out = event
            let capturedTs: Int64
            if let ts = event["timestamp"] as? Int64 {
                capturedTs = ts
            } else if let n = event["timestamp"] as? NSNumber {
                capturedTs = n.int64Value
            } else {
                capturedTs = nowMs
            }
            out["deliveredLate"] = true
            out["capturedTs"] = capturedTs
            out["queuedDurationMs"] = max(0, nowMs - capturedTs)
            return out
        }
        result(enriched)
    }

    private func pendingEventsDroppedCount(result: @escaping FlutterResult) {
        guard let locationTracker = locationTracker else {
            result(0)
            return
        }
        result(locationTracker.pendingEventsDroppedCount())
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
                // The geofence sink is the load-bearing signal for the
                // durable pending-events queue: when it goes away, core
                // must persist; when it comes back, core must live-deliver.
                // Tie setBridgeAttached to onListen / onCancel so a Dart
                // stream unsubscribe / re-subscribe cycle correctly flips
                // core's persist gate — initialize / dispose are not
                // granular enough on their own.
                locationTracker?.setBridgeAttached(true)
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
                locationTracker?.setBridgeAttached(true)
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
                // Sink for geofence events is gone — signal core to persist
                // to the durable queue (when pendingEventsQueueSize > 0)
                // instead of delivering via the delegate that no longer has
                // a Flutter sink to forward to.
                locationTracker?.setBridgeAttached(false)
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
            locationTracker?.setBridgeAttached(false)
            errorSink = nil
            PolyfenceErrorManager.shared.dispose()
            performanceSink = nil
        }
        return nil
    }
    
    // MARK: - Debug Methods
    
    private func getDebugInfo(result: @escaping FlutterResult) {
        // All bridges share a single collector so the debugInfo()
        // payload has one authoritative source. Location and
        // zone-detection counters (`totalLocationUpdates`,
        // `totalZoneDetections`, `averageDetectionLatency`) are `0`
        // until polyfence-core's LocationTracker calls the collector's
        // `recordLocationUpdate` / `recordZoneDetection` accessors.
        result(PolyfenceDebugCollector.shared.collectDebugInfo())
    }
    
    private func getErrorHistory(arguments: Any?, result: @escaping FlutterResult) {
        // Flutter's Swift codec surfaces Dart ints as NSNumber; reading
        // through NSNumber's `.int64Value` accepts any numeric shape
        // Flutter delivers without a type-specific downcast.
        let args = arguments as? [String: Any]
        let timeRangeMs = (args?["timeRangeMs"] as? NSNumber)?.int64Value
        let errorTypes = args?["errorTypes"] as? [String]
        let history = PolyfenceDebugCollector.shared.getErrorHistory(
            timeRangeMs: timeRangeMs,
            errorTypes: errorTypes
        )
        result(history)
    }
}
