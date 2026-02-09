import Foundation
import CoreLocation
import UserNotifications
import UIKit

/**
 * Background location tracking service for iOS
 * Single responsibility: GPS updates → GeofenceEngine → Notifications
 * Ported from Android LocationTracker.kt
 */
class LocationTracker: NSObject {
    
    // MARK: - Constants
    private static let TAG = "LocationTracker"
    private static let NOTIFICATION_ID = 1001
    private static let CHANNEL_ID = "polyfence_tracking"
    private static let GEOFENCE_CHANNEL_ID = "polyfence_alerts"
    
    // MARK: - Properties
    private var locationManager: CLLocationManager?
    private let geofenceEngine = GeofenceEngine()
    private var zonePersistence: ZonePersistence?
    private var config: PolyfenceConfig?
    
    // Error Recovery Properties
    private var lastLocationTime: TimeInterval = 0
    private var consecutiveGpsFailures: Int = 0
    private var isRunning: Bool = false
    private var pendingStartAfterAuthorization: Bool = false
    
    // CRITICAL: Prevent auto-tracking to match Android behavior
    private var trackingEnabled: Bool = false
    private var fallbackTimer: Timer?
    private let geofenceQueue = DispatchQueue(label: "polyfence.geofence", qos: .userInitiated)

    // P9: Track last location where zone check was performed
    private var lastZoneCheckLocation: CLLocation?
    private let minMovementForZoneCheckMeters: CLLocationDistance = 5.0  // Only recheck zones if moved >5m

    // P4: Defer GPS start until zones exist
    private var gpsStartDeferred: Bool = false

    // P11: Throttle Flutter callbacks when stationary
    private var lastFlutterCallbackTime: TimeInterval = 0
    private let stationaryFlutterCallbackInterval: TimeInterval = 30.0  // 30s when stationary
    // CPU usage tracking state
    private var prevCpuTotal: UInt32 = 0
    private var prevCpuIdle: UInt32 = 0
    
    // Notification properties
    private var notificationCenter: UNUserNotificationCenter?
    private var healthTimer: Timer?
    
    // Background Task Management
    private var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid
    
    // Callbacks
    private var locationCallback: (([String: Any]) -> Void)?
    private var geofenceCallback: ((String, String, String, Double, Double, Double, Double) -> Void)?
    
    // Smart GPS Configuration
    private var smartConfig = SmartGpsConfig()
    private var currentGpsInterval: TimeInterval = 5.0
    private var isStationary: Bool = false
    private var lastKnownLocation: CLLocation?
    
    // Runtime Status Emission
    private var lastEmittedStatus: [String: Any] = [:]
    private var lastStatusEmitTime: TimeInterval = 0
    
    // Alert Notifications Control
    private var alertNotificationsEnabled: Bool = true

    // Activity Recognition
    private var activityRecognitionManager: ActivityRecognitionManager?
    private var activitySettings: ActivitySettings = ActivitySettings()
    private var currentActivity: ActivityType = .unknown

    override init() {
        super.init()
        // Initialize persistence first so it's available for geofence engine
        zonePersistence = ZonePersistence()
        setupLocationManager()
        setupNotificationCenter()
        setupGeofenceEngine()

        // Initialize tracking scheduler and load saved config
        TrackingScheduler.shared.setLocationTracker(self)
        TrackingScheduler.shared.loadConfig()
    }
    
    // MARK: - Setup Methods
    
    private func setupLocationManager() {
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        // P2/P3: Use smartConfig defaults for initial setup (BALANCED profile by default)
        locationManager?.desiredAccuracy = smartConfig.getCLLocationAccuracy()
        locationManager?.distanceFilter = smartConfig.getDistanceFilter()
        locationManager?.pausesLocationUpdatesAutomatically = smartConfig.shouldPauseAutomatically()
        locationManager?.activityType = .otherNavigation
        
        if #available(iOS 9.0, *) {
            locationManager?.allowsBackgroundLocationUpdates = true
        }
    }
    
    private func setupNotificationCenter() {
        notificationCenter = UNUserNotificationCenter.current()
        
        // REMOVED delegate to fix background notifications
        // Setting delegate breaks background delivery - let iOS handle automatically
        // notificationCenter?.delegate = self
        
        // Request standard notification permissions (no critical alerts)
        notificationCenter?.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        
        createNotificationCategories()
    }
    
    private func setupGeofenceEngine() {
        // Setup geofence engine callback
        geofenceEngine.setEventCallback { [weak self] zoneId, eventType, location, detectionTimeMs in
            self?.handleGeofenceEvent(zoneId: zoneId, eventType: eventType, location: location, detectionTimeMs: detectionTimeMs)
        }

        // Wire up zone persistence for state recovery across service restarts
        if let persistence = zonePersistence {
            geofenceEngine.setZonePersistence(persistence)
        }

        // Configure validation using config (opt for immediate detection to verify pipeline)
        geofenceEngine.setValidationConfig(requireConfirmation: false, confirmationPoints: 1)

        // Set GPS accuracy threshold from config (default: 100m for platform parity)
        let accuracyThreshold = config?.gpsAccuracyThreshold ?? PolyfenceConfig.DEFAULT_GPS_ACCURACY_THRESHOLD
        geofenceEngine.setGpsAccuracyThreshold(accuracyThreshold)
    }

    // Track if first location after restart has been processed
    private var firstLocationAfterRestart = true
    
    // MARK: - Public Methods
    
    /**
     * Start location tracking
     */
    func startTracking() {
        guard locationManager != nil else { 
            return 
        }
        
        isRunning = true
        trackingEnabled = true
        firstLocationAfterRestart = true  // Reset for state reconciliation

        // Begin background task
        beginBackgroundTask()
        healthTimer?.invalidate()
        healthTimer = Timer.scheduledTimer(withTimeInterval: 12 * 60, repeats: true) { [weak self] _ in
            guard let self = self, self.isRunning else { return }
            UIDevice.current.isBatteryMonitoringEnabled = true
            let battery = self.getBatteryLevel()
            let charging = UIDevice.current.batteryState == .charging || UIDevice.current.batteryState == .full
            let gpsActive = Date().timeIntervalSince1970 - self.lastLocationTime < 60.0
            let payload: [String: Any] = [
                "type": "system_health",
                "battery_level": battery,
                "is_charging": charging,
                "gps_active": gpsActive,
                "gps_status": gpsActive ? "active" : "idle",
                "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
            ]
            // Send health timer data on main thread
            DispatchQueue.main.async {
            }
        }
        RunLoop.main.add(healthTimer!, forMode: .common)
        fallbackTimer?.invalidate()
        fallbackTimer = nil
        // Request permissions if needed
        let authorizationStatus = CLLocationManager.authorizationStatus()
        
        if authorizationStatus == .notDetermined {
            pendingStartAfterAuthorization = true
            DispatchQueue.main.async { [weak self] in
                self?.locationManager?.requestWhenInUseAuthorization()
            }
            return
        }
        
        guard authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse else {
            return
        }
        
        guard CLLocationManager.locationServicesEnabled() else {
            return
        }
        
        startLocationUpdatesFlow()
    }
    
    /**
     * Stop location tracking
     */
    func stopTracking() {
        guard let locationManager = locationManager else { return }
        
        isRunning = false
        trackingEnabled = false
        healthTimer?.invalidate()
        healthTimer = nil
        fallbackTimer?.invalidate()
        fallbackTimer = nil
        locationManager.stopUpdatingLocation()
        
        if #available(iOS 9.0, *) {
            locationManager.stopMonitoringSignificantLocationChanges()
        }
        
        // End background task
        endBackgroundTask()

        // Stop activity recognition
        activityRecognitionManager?.stop()

        // Location tracking stopped
    }
    
    // MARK: - Background Task Management
    
    private func beginBackgroundTask() {
        backgroundTaskId = UIApplication.shared.beginBackgroundTask(withName: "PolyfenceLocationTracking") {
            self.endBackgroundTask()
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTaskId != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskId)
            backgroundTaskId = .invalid
        }
    }
    
    /**
     * Add zone for monitoring
     */
    func addZone(zoneId: String, zoneName: String, zoneData: [String: Any]) {
        geofenceQueue.async { [weak self] in
            guard let self = self else { return }
            do {
                try self.geofenceEngine.addZone(zoneId: zoneId, zoneName: zoneName, zoneData: zoneData)
                // Save to persistent storage
                self.zonePersistence?.saveZone(zoneId: zoneId, zoneName: zoneName, zoneData: zoneData)

                // Check CLLocationManager health after zone addition
                DispatchQueue.main.async {
                    self.checkLocationManagerHealth()

                    // P4: If GPS was deferred, start it now that we have zones
                    if self.gpsStartDeferred && self.isRunning {
                        NSLog("[LocationTracker] P4: First zone added - starting deferred GPS")
                        self.gpsStartDeferred = false
                        self.startGpsUpdates()
                    }
                }
            } catch {
                // Failed to add zone
            }
        }
    }
    
    /**
     * Remove zone from monitoring
     */
    func removeZone(zoneId: String) {
        geofenceQueue.async { [weak self] in
            self?.geofenceEngine.removeZone(zoneId: zoneId)
        }
        zonePersistence?.removeZone(zoneId: zoneId)
    }
    
    /**
     * Clear all zones
     */
    func clearAllZones() {
        geofenceQueue.async { [weak self] in
            self?.geofenceEngine.clearAllZones()
        }
        zonePersistence?.clearAllZones()
    }
    
    /**
     * Set callbacks
     */
    func setLocationCallback(_ callback: @escaping ([String: Any]) -> Void) {
        locationCallback = callback
    }
    
    func setGeofenceCallback(_ callback: @escaping (String, String, String, Double, Double, Double, Double) -> Void) {
        geofenceCallback = callback
    }
    
    /**
     * Set whether alert notifications should be shown
     */
    func setAlertNotificationsEnabled(_ enabled: Bool) {
        alertNotificationsEnabled = enabled
        NSLog("[LocationTracker] Alert notifications \(enabled ? "enabled" : "disabled")")
    }
    
    /**
     * Request permissions using the same CLLocationManager instance
     */
    func requestPermissions(always: Bool = false) {
        let status = CLLocationManager.authorizationStatus()
        if status == .notDetermined {
            pendingStartAfterAuthorization = false
            DispatchQueue.main.async { [weak self] in
                if always { self?.locationManager?.requestAlwaysAuthorization() }
                else { self?.locationManager?.requestWhenInUseAuthorization() }
            }
            return
        }
        if always && status == .authorizedWhenInUse {
            DispatchQueue.main.async { [weak self] in
                self?.locationManager?.requestAlwaysAuthorization()
            }
        }
    }
    
    /**
     * Get last known location as a dictionary compatible with Flutter
     */
    func getLastKnownLocationData() -> [String: Any]? {
        guard let loc = locationManager?.location else { return nil }
        return [
            "latitude": loc.coordinate.latitude,
            "longitude": loc.coordinate.longitude,
            "accuracy": loc.horizontalAccuracy,
            "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
        ]
    }
    
    // MARK: - Private Methods
    
    private func startLocationUpdatesFlow() {
        guard let locationManager = locationManager else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Restore zones from storage FIRST (before deciding whether to start GPS)
            self.restoreZonesFromStorage()

            // P4: Only start GPS if zones exist, otherwise defer
            if !self.geofenceEngine.hasZones() {
                NSLog("[LocationTracker] P4: No zones registered - deferring GPS start until zones are added")
                self.gpsStartDeferred = true
                return
            }

            self.startGpsUpdates()
        }
    }

    /**
     * P4: Start actual GPS updates (called when zones exist)
     */
    private func startGpsUpdates() {
        guard let locationManager = locationManager else { return }

        locationManager.startUpdatingLocation()
        locationManager.requestLocation()
        if let lastKnown = locationManager.location {
            self.lastLocationTime = Date().timeIntervalSince1970
            self.sendLocationToFlutter(location: lastKnown)
        }
        if #available(iOS 9.0, *) {
            locationManager.startMonitoringSignificantLocationChanges()
        }
        // Start a fallback timer to keep requesting location until fixes flow
        self.startFallbackTimer()

        // Ensure activity recognition is started if enabled but not running
        if activitySettings.enabled && activityRecognitionManager == nil {
            NSLog("[LocationTracker] Restarting activity recognition on tracking start")
            updateActivityRecognition(activitySettings)
        }

        NSLog("[LocationTracker] GPS updates started with profile: \(smartConfig.accuracyProfile)")
    }

    /**
     * Restore zones from storage on service start
     */
    private func restoreZonesFromStorage() {
        guard let zonePersistence = zonePersistence else { return }

        do {
            let savedZones = try zonePersistence.loadAllZones()
            geofenceQueue.sync { [weak self] in
                guard let self = self else { return }
                for (_, zoneInfo) in savedZones {
                    let (id, name, data) = zoneInfo
                    if self.geofenceEngine.getZoneName(id) != nil {
                        continue
                    }
                    do {
                        try self.geofenceEngine.addZone(zoneId: id, zoneName: name, zoneData: data)
                    } catch {
                        // Failed to restore zone
                    }
                }

                // Load persisted zone states AFTER zones are loaded
                // This restores the "inside/outside" state from before service restart
                self.geofenceEngine.loadPersistedZoneStates()
            }

            NSLog("[LocationTracker] Restored \(savedZones.count) zones from storage")
        } catch {
            // Failed to restore zones
        }
    }
    
    /**
     * Handle geofence events safely on main thread
     */
    private func handleGeofenceEvent(zoneId: String, eventType: String, location: CLLocation, detectionTimeMs: Double) {
        
        // CRITICAL: Only process geofence events if tracking is explicitly enabled
        guard trackingEnabled else {
            return
        }
        
        // Get zone name from GeofenceEngine
        let zoneName = geofenceEngine.getZoneName(zoneId) ?? zoneId
        
        // Use the detection duration passed from GeofenceEngine (already in milliseconds)
        // This is the actual time it took to detect the geofence event, not GPS age
        
        // Get GPS accuracy
        let gpsAccuracy = location.horizontalAccuracy
        
        // Send event to Flutter on main thread
        DispatchQueue.main.async {
            self.geofenceCallback?(zoneId, zoneName, eventType, detectionTimeMs, gpsAccuracy, location.coordinate.latitude, location.coordinate.longitude)
        }
        
        // Show notification with proper zone name
        showGeofenceNotification(eventType: eventType, zoneId: zoneId, zoneName: zoneName)
        
        // Emit lightweight system health snapshot on zone change
        let battery = getBatteryLevel()
        UIDevice.current.isBatteryMonitoringEnabled = true
        let charging = UIDevice.current.batteryState == .charging || UIDevice.current.batteryState == .full
        let health: [String: Any] = [
            "type": "system_health",
            "gps_status": "active",
            "gps_accuracy": location.horizontalAccuracy,
            "battery_level": battery,
            "is_charging": charging,
            "gps_active": true,
            "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
        ]
        // Send health data on main thread
        DispatchQueue.main.async {
        }
    }
    
    /**
     * Send location to Flutter safely on main thread
     */
    private func sendLocationToFlutter(location: CLLocation) {
        let activityName = currentActivity.rawValue.lowercased()
        let locationData: [String: Any] = [
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude,
            "accuracy": location.horizontalAccuracy,
            "timestamp": Int64(Date().timeIntervalSince1970 * 1000),
            "speed": location.speed >= 0 ? location.speed * 3.6 : 0.0, // Convert m/s to km/h
            "activity": activityName // Include current activity type
        ]

        // CRITICAL: Send on main thread
        DispatchQueue.main.async {
            self.locationCallback?(locationData)
        }
    }
    
    /**
     * Show geofence notification with standardized content
     */
    private func showGeofenceNotification(eventType: String, zoneId: String, zoneName: String) {
        guard isRunning else { return }
        guard alertNotificationsEnabled else { return }  // Respect disableAlertNotifications config
        let title = eventType == "ENTER" ? "Entered Zone" : "Exited Zone"
        let message = zoneName // Use zone name instead of ID
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        
        // Standardized notification configuration
        content.sound = .default  // Standard default sound
        content.badge = 1
        
        // iOS 15+ time-sensitive interruption level (not critical)
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
            content.relevanceScore = 1.0
        }
        
        // Metadata for tracking
        content.userInfo = [
            "zoneId": zoneId,
            "zoneName": zoneName,
            "eventType": eventType,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        // Use appropriate category
        content.categoryIdentifier = eventType == "ENTER" ? "POLYFENCE_ZONE_ENTRY" : "POLYFENCE_ZONE_EXIT"
        
        // Immediate local delivery (trigger = nil)
        let request = UNNotificationRequest(
            identifier: "geofence-\(zoneId)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil  // Immediate delivery
        )
        
        notificationCenter?.add(request) { error in
            DispatchQueue.main.async {
                if let error = error {
                    // Notification delivery failed
                } else {
                    // Notification posted successfully
                }
            }
        }
    }
    
    /**
     * Create notification categories
     */
    private func createNotificationCategories() {
        // Tracking notification (low priority)
        let trackingCategory = UNNotificationCategory(
            identifier: "POLYFENCE_TRACKING",
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        
        // Zone entry notification
        let entryCategory = UNNotificationCategory(
            identifier: "POLYFENCE_ZONE_ENTRY",
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        
        // Zone exit notification
        let exitCategory = UNNotificationCategory(
            identifier: "POLYFENCE_ZONE_EXIT",
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        
        notificationCenter?.setNotificationCategories([trackingCategory, entryCategory, exitCategory])
    }
    
    /**
     * Get device ID
     */
    private func getPolyfenceDeviceId() -> String {
        let userDefaults = UserDefaults.standard
        var deviceId = userDefaults.string(forKey: "polyfence_device_id")
        
        if deviceId == nil {
            let timestamp = Date().timeIntervalSince1970
            let random = Int(timestamp.truncatingRemainder(dividingBy: 10000))
            deviceId = "polyfence-\(Int(timestamp))-\(String(format: "%04d", random))"
            userDefaults.set(deviceId, forKey: "polyfence_device_id")
        }
        
        return deviceId ?? UUID().uuidString
    }
    
    /**
     * Get battery level
     */
    private func getBatteryLevel() -> Double {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let batteryLevel = UIDevice.current.batteryLevel
        return batteryLevel >= 0 ? Double(batteryLevel * 100) : 100.0
    }
    
    /**
     * Get CPU usage (mock implementation)
     */
    private func getCpuUsage() -> Double {
        // System-wide CPU usage based on host CPU load counters
        var size = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        var cpuLoad = host_cpu_load_info()
        let result = withUnsafeMutablePointer(to: &cpuLoad) { ptr -> kern_return_t in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(size)) { intPtr in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, intPtr, &size)
            }
        }
        guard result == KERN_SUCCESS else { return 0.0 }
        let user = cpuLoad.cpu_ticks.0
        let nice = cpuLoad.cpu_ticks.1
        let system = cpuLoad.cpu_ticks.2
        let idle = cpuLoad.cpu_ticks.3
        let idleAll = idle
        let total = user &+ nice &+ system &+ idleAll
        let totald = total &- prevCpuTotal
        let idled = idleAll &- prevCpuIdle
        prevCpuTotal = total
        prevCpuIdle = idleAll
        if totald > 0 {
            let usage = Double(totald &- idled) / Double(totald) * 100.0
            return Double(round(10 * usage) / 10)
        }
        return 0.0
    }
    
    /**
     * Handle GPS restart (error recovery)
     */
    private func handleGpsRestart() {
        guard let locationManager = locationManager else { return }
        
        // Stop current location updates
        locationManager.stopUpdatingLocation()
        
        // Use more conservative settings on restart
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            guard let self = self, self.isRunning else { return }
            
            // Use balanced power accuracy for restart
            locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            locationManager.distanceFilter = 20.0 // 20 meters minimum movement
            
            locationManager.startUpdatingLocation()
            
            if #available(iOS 9.0, *) {
                locationManager.startMonitoringSignificantLocationChanges()
            }
        }
    }

    /**
     * P7: Start a fallback timer to request single-shot locations if stale
     * Changed from repeating (15s) to non-repeating (30s) - only fires when truly needed
     */
    private func startFallbackTimer() {
        fallbackTimer?.invalidate()
        // P7: Non-repeating timer at 30s - reschedules itself only after location received
        fallbackTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { [weak self] _ in
            guard let self = self, self.isRunning else { return }
            let now = Date().timeIntervalSince1970
            let secondsSinceLast = now - self.lastLocationTime
            if secondsSinceLast > 30.0 {
                // P7: Only request if truly stale (30s without update)
                print("\(Self.TAG): Fallback timer triggered - requesting location")
                self.locationManager?.requestLocation()
            }
            // P7: Reschedule for next check
            self.startFallbackTimer()
        }
        RunLoop.main.add(fallbackTimer!, forMode: .common)
    }

    /**
     * P7: Reset fallback timer after receiving a location update
     * Called from locationManager:didUpdateLocations to prevent unnecessary fallback triggers
     */
    private func resetFallbackTimer() {
        if isRunning {
            startFallbackTimer()
        }
    }
    
    /**
     * Handle permission loss
     */
    private func handlePermissionLoss() {
        stopTracking()
    }
    
    /**
     * Check if CLLocationManager is still healthy
     */
    private func checkLocationManagerHealth() {
        guard locationManager != nil else {
            return
        }
        
        // Test if we can still get location updates
        let testLocation = locationManager?.location
        if testLocation == nil {
            // LocationManager no longer providing location
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationTracker: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // CRITICAL: Only process locations if tracking is explicitly enabled
        guard trackingEnabled, let location = locations.last, isRunning else {
            return
        }

        // STATE RECOVERY: On first valid location after service restart,
        // reconcile persisted zone states with actual location.
        // This fires RECOVERY_ENTER/RECOVERY_EXIT for any mismatches.
        if firstLocationAfterRestart {
            firstLocationAfterRestart = false
            NSLog("[LocationTracker] First location after restart - reconciling zone states")
            geofenceQueue.sync { [weak self] in
                self?.geofenceEngine.reconcileZoneStates(location)
            }
        }

        // Update movement state for smart GPS
        updateMovementState(location)

        // Log proximity debug info
        logProximityDebugInfo(location)

        // Update health tracking
        lastLocationTime = Date().timeIntervalSince1970
        consecutiveGpsFailures = 0

        // P7: Reset fallback timer since we received a valid location
        resetFallbackTimer()

        // P11: Throttle Flutter callbacks when stationary to reduce overhead
        let currentTime = Date().timeIntervalSince1970
        let timeSinceLastCallback = currentTime - lastFlutterCallbackTime
        let shouldSendToFlutter: Bool
        if isStationary {
            // When stationary, only send updates every 30s
            shouldSendToFlutter = timeSinceLastCallback >= stationaryFlutterCallbackInterval
        } else {
            // When moving, send every update
            shouldSendToFlutter = true
        }

        if shouldSendToFlutter {
            sendLocationToFlutter(location: location)
            lastFlutterCallbackTime = currentTime
        }

        // Emit runtime status periodically (parity with Android)
        emitRuntimeStatus()

        // P9: Only check geofences if moved significantly since last check
        let shouldCheckZones: Bool
        if let lastLoc = lastZoneCheckLocation {
            shouldCheckZones = location.distance(from: lastLoc) > minMovementForZoneCheckMeters
        } else {
            shouldCheckZones = true  // Always check on first location
        }

        if shouldCheckZones {
            // Run geofence check on geofence queue to avoid concurrency issues
            geofenceQueue.async { [weak self] in
                guard let self = self else { return }
                self.geofenceEngine.checkLocation(location)
            }
            lastZoneCheckLocation = location
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        consecutiveGpsFailures += 1
        
        // Report GPS error to developer stream
        PolyfenceErrorManager.shared.reportGpsError(
            type: "gps_error",
            details: error.localizedDescription
        )
        
        // Handle GPS failure recovery
        if consecutiveGpsFailures >= 3 && consecutiveGpsFailures <= 5 {
            handleGpsRestart()
        }
    }
    
    // iOS < 14 callback
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        handleAuthorizationChange(status: status)
    }

    // iOS 14+ callback
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status: CLAuthorizationStatus
        if #available(iOS 14.0, *) {
            status = manager.authorizationStatus
        } else {
            status = CLLocationManager.authorizationStatus()
        }
        handleAuthorizationChange(status: status)
    }

    private func handleAuthorizationChange(status: CLAuthorizationStatus) {
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            if isRunning {
                if pendingStartAfterAuthorization {
                    pendingStartAfterAuthorization = false
                    startLocationUpdatesFlow()
                }
            }
        case .denied, .restricted:
            handlePermissionLoss()
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        // Started monitoring region
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        // Entered region
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        // Exited region
    }
    
    // MARK: - Smart GPS Configuration Methods
    
    /**
     * Update smart GPS configuration
     */
    /**
     * Set GPS accuracy threshold for GeofenceEngine
     */
    func setGpsAccuracyThreshold(_ threshold: Double) {
        geofenceEngine.setGpsAccuracyThreshold(threshold)
    }

    /**
     * Configure dwell detection
     * @param enabled Whether dwell detection is enabled
     * @param thresholdMs How long (milliseconds) device must stay in zone before DWELL fires
     */
    func setDwellConfig(enabled: Bool, thresholdMs: Int) {
        // Convert milliseconds to seconds for iOS
        let thresholdSeconds = TimeInterval(thresholdMs) / 1000.0
        geofenceEngine.setDwellConfig(enabled: enabled, thresholdSeconds: thresholdSeconds)
    }

    /**
     * Configure zone clustering for large zone sets
     * @param enabled Whether clustering is enabled
     * @param activeRadiusMeters Radius to check zones within
     * @param refreshDistanceMeters Distance to move before refreshing active cluster
     */
    func setClusterConfig(enabled: Bool, activeRadiusMeters: Double, refreshDistanceMeters: Double) {
        geofenceEngine.setClusterConfig(enabled: enabled, activeRadiusMeters: activeRadiusMeters, refreshDistanceMeters: refreshDistanceMeters)
    }

    /**
     * Configure scheduled tracking
     * @param scheduleSettings Schedule configuration map from Flutter
     */
    func setScheduleConfig(_ scheduleSettings: [String: Any]?) {
        TrackingScheduler.shared.setLocationTracker(self)
        TrackingScheduler.shared.updateConfig(scheduleSettings)
    }

    /**
     * Configure activity recognition
     * @param activitySettingsMap Activity configuration map from Flutter
     */
    func setActivityConfig(_ activitySettingsMap: [String: Any]?) {
        guard let settingsMap = activitySettingsMap else {
            // Disable activity recognition if no settings provided
            activityRecognitionManager?.stop()
            activitySettings = ActivitySettings()
            currentActivity = .unknown
            return
        }

        let newSettings = ActivitySettings.fromMap(settingsMap)
        updateActivityRecognition(newSettings)
    }

    /**
     * Update activity recognition settings
     */
    private func updateActivityRecognition(_ newSettings: ActivitySettings) {
        activitySettings = newSettings

        if newSettings.enabled {
            // Initialize manager if needed
            if activityRecognitionManager == nil {
                activityRecognitionManager = ActivityRecognitionManager()
            }

            // Start activity recognition with callback
            activityRecognitionManager?.start(settings: newSettings) { [weak self] activity, confidence in
                guard let self = self else { return }
                NSLog("[\(Self.TAG)] Activity changed: \(activity) (confidence: \(confidence)%)")
                self.currentActivity = activity
                // Update GPS settings when activity changes
                if self.trackingEnabled {
                    DispatchQueue.main.async {
                        self.updateLocationManagerSettings()
                    }
                }
            }
        } else {
            // Stop activity recognition
            activityRecognitionManager?.stop()
            currentActivity = .unknown
        }
    }

    func updateSmartConfiguration(_ config: SmartGpsConfig) {
        self.smartConfig = config
        
        // Apply configuration if tracking is active
        if trackingEnabled {
            updateLocationManagerSettings()
        }
        
        config.logConfiguration(tag: Self.TAG)
    }
    
    /**
     * Get current smart GPS configuration
     */
    func getCurrentSmartConfiguration() -> SmartGpsConfig {
        return smartConfig
    }

    /**
     * Get current zone states from GeofenceEngine
     * Returns which zones the plugin believes the device is currently inside
     * @return Dictionary of zoneId to isInside state
     */
    func getCurrentZoneStates() -> [String: Bool] {
        return geofenceEngine.getCurrentZoneStates()
    }

    /**
     * Update location manager settings based on smart configuration
     */
    private func updateLocationManagerSettings() {
        guard let locationManager = locationManager else { return }
        
        let accuracy = smartConfig.getCLLocationAccuracy()
        let distanceFilter = smartConfig.getDistanceFilter()
        
        locationManager.desiredAccuracy = accuracy
        locationManager.distanceFilter = distanceFilter
        locationManager.pausesLocationUpdatesAutomatically = smartConfig.shouldPauseAutomatically()
        
        print("\(Self.TAG): Updated GPS settings - accuracy: \(accuracy), distanceFilter: \(distanceFilter)")

        // Emit status after GPS configuration changes
        emitRuntimeStatus()
    }
    
    /**
     * Calculate current GPS interval based on smart configuration
     */
    private func calculateCurrentInterval() -> TimeInterval {
        switch smartConfig.updateStrategy {
        case .continuous:
            return smartConfig.getBaseUpdateInterval()
        case .proximityBased:
            return calculateProximityBasedInterval()
        case .movementBased:
            return calculateMovementBasedInterval()
        case .intelligent:
            return calculateIntelligentInterval()
        }
    }
    
    /**
     * Calculate interval based on proximity to zones
     */
    private func calculateProximityBasedInterval() -> TimeInterval {
        guard let proximitySettings = smartConfig.proximitySettings,
              let lastLocation = lastKnownLocation else {
            return smartConfig.getBaseUpdateInterval()
        }
        
        // Calculate distance to nearest zone
        let nearestZoneDistance = calculateDistanceToNearestZone(lastLocation)
        
        switch nearestZoneDistance {
        case 0...proximitySettings.nearZoneThresholdMeters:
            print("\(Self.TAG): Near zone (\(nearestZoneDistance)m) - using high frequency")
            return proximitySettings.nearZoneUpdateIntervalMs
        case proximitySettings.farZoneThresholdMeters...:
            print("\(Self.TAG): Far from zones (\(nearestZoneDistance)m) - using low frequency")
            return proximitySettings.farZoneUpdateIntervalMs
        default:
            // Interpolate for medium distances
            let ratio = (nearestZoneDistance - proximitySettings.nearZoneThresholdMeters) /
                       (proximitySettings.farZoneThresholdMeters - proximitySettings.nearZoneThresholdMeters)
            
            let intervalDiff = proximitySettings.farZoneUpdateIntervalMs - proximitySettings.nearZoneUpdateIntervalMs
            let interpolatedInterval = proximitySettings.nearZoneUpdateIntervalMs + (ratio * intervalDiff)
            
            print("\(Self.TAG): Medium distance (\(nearestZoneDistance)m) - using interpolated interval: \(interpolatedInterval)s")
            return interpolatedInterval
        }
    }
    
    /**
     * Calculate interval based on movement state
     */
    private func calculateMovementBasedInterval() -> TimeInterval {
        guard let movementSettings = smartConfig.movementSettings else {
            return smartConfig.getBaseUpdateInterval()
        }
        
        return isStationary ? movementSettings.stationaryUpdateIntervalMs : movementSettings.movingUpdateIntervalMs
    }
    
    /**
     * Calculate interval using intelligent combination of factors
     *
     * HIERARCHY: Proximity is king - when near a zone, fast updates regardless of battery/activity.
     * Battery and activity savings only apply when FAR from zones.
     */
    private func calculateIntelligentInterval() -> TimeInterval {
        let proximitySettings = smartConfig.proximitySettings

        // Check if we're near a zone - proximity is king
        if let settings = proximitySettings, let location = lastKnownLocation {
            let nearestZoneDistance = calculateDistanceToNearestZone(location)

            if nearestZoneDistance <= settings.nearZoneThresholdMeters {
                // NEAR zone - use fast updates, ignore battery/activity savings
                let proximityInterval = calculateProximityBasedInterval()
                print("\(Self.TAG): Near zone (\(nearestZoneDistance)m) - proximity is king: \(proximityInterval)s")
                return proximityInterval
            }
        }

        // FAR from zones - now we can optimize for battery/activity
        let movementInterval = calculateMovementBasedInterval()
        let batteryInterval = calculateBatteryBasedInterval()
        let activityInterval = calculateActivityBasedInterval()

        // When far from zones, use the most battery-friendly (longest) interval
        let result = max(movementInterval, batteryInterval, activityInterval)
        print("\(Self.TAG): Far from zones - using longest interval: \(result)s (movement=\(movementInterval), battery=\(batteryInterval), activity=\(activityInterval))")
        return result
    }

    /**
     * Calculate interval based on detected activity type
     * Only applies when activity recognition is enabled
     */
    private func calculateActivityBasedInterval() -> TimeInterval {
        guard activitySettings.enabled else {
            return smartConfig.getBaseUpdateInterval()
        }

        return activitySettings.getIntervalForActivity(currentActivity)
    }
    
    /**
     * Calculate interval based on battery level
     */
    private func calculateBatteryBasedInterval() -> TimeInterval {
        guard let batterySettings = smartConfig.batterySettings else {
            return smartConfig.getBaseUpdateInterval()
        }
        
        UIDevice.current.isBatteryMonitoringEnabled = true
        let batteryLevel = Int(UIDevice.current.batteryLevel * 100)
        
        if batteryLevel <= batterySettings.criticalBatteryThreshold && batterySettings.pauseOnCriticalBattery {
            return TimeInterval.greatestFiniteMagnitude // Pause GPS
        } else if batteryLevel <= batterySettings.lowBatteryThreshold {
            return batterySettings.lowBatteryUpdateIntervalMs
        } else {
            return smartConfig.getBaseUpdateInterval()
        }
    }
    
    /**
     * Calculate distance to nearest zone
     */
    private func calculateDistanceToNearestZone(_ location: CLLocation) -> Double {
        do {
            // Get current zones from GeofenceEngine
            let zones = geofenceEngine.getCurrentZones()
            guard !zones.isEmpty else {
                return Double.greatestFiniteMagnitude // No zones configured
            }
            
            var nearestDistance = Double.greatestFiniteMagnitude
            
            for zone in zones {
                let distance: Double
                
                if zone.isCircle {
                    distance = calculateDistanceToCircleZone(location: location, zone: zone)
                } else if zone.isPolygon {
                    distance = calculateDistanceToPolygonZone(location: location, zone: zone)
                } else {
                    distance = Double.greatestFiniteMagnitude
                }
                
                if distance < nearestDistance {
                    nearestDistance = distance
                }
            }
            
            print("\(Self.TAG): Nearest zone distance: \(nearestDistance)m")
            return nearestDistance
            
        } catch {
            print("\(Self.TAG): Error calculating zone distance: \(error.localizedDescription)")
            return Double.greatestFiniteMagnitude // Fallback to no optimization
        }
    }
    
    /**
     * Calculate distance to circle zone boundary
     */
    private func calculateDistanceToCircleZone(location: CLLocation, zone: Zone) -> Double {
        guard let center = zone.center, let radius = zone.radius else {
            return Double.greatestFiniteMagnitude
        }
        
        let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
        let distanceToCenter = location.distance(from: centerLocation)
        
        // Distance to zone boundary (0 if inside zone)
        return max(0.0, distanceToCenter - radius)
    }
    
    /**
     * Calculate distance to polygon zone boundary
     */
    private func calculateDistanceToPolygonZone(location: CLLocation, zone: Zone) -> Double {
        let currentPoint = CLLocationCoordinate2D(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        let points = zone.points
        
        guard !points.isEmpty else { return Double.greatestFiniteMagnitude }
        
        // Check if inside polygon first
        if isPointInPolygon(point: currentPoint, polygon: points) {
            return 0.0 // Inside zone
        }
        
        // Calculate distance to nearest polygon edge
        var nearestDistance = Double.greatestFiniteMagnitude
        
        for i in points.indices {
            let p1 = points[i]
            let p2 = points[(i + 1) % points.count]
            
            let distance = distanceFromPointToLineSegment(point: currentPoint, lineStart: p1, lineEnd: p2)
            if distance < nearestDistance {
                nearestDistance = distance
            }
        }
        
        return nearestDistance
    }
    
    /**
     * Calculate distance from point to line segment
     */
    private func distanceFromPointToLineSegment(
        point: CLLocationCoordinate2D,
        lineStart: CLLocationCoordinate2D,
        lineEnd: CLLocationCoordinate2D
    ) -> Double {
        // Calculate perpendicular distance from point to line segment
        let A = point.latitude - lineStart.latitude
        let B = point.longitude - lineStart.longitude
        let C = lineEnd.latitude - lineStart.latitude
        let D = lineEnd.longitude - lineStart.longitude
        
        let dot = A * C + B * D
        let lenSq = C * C + D * D
        
        if lenSq == 0.0 {
            // Line segment is a point
            return calculateDistance(point1: point, point2: lineStart)
        }
        
        let param = dot / lenSq
        
        let closest: CLLocationCoordinate2D
        if param < 0 {
            closest = lineStart
        } else if param > 1 {
            closest = lineEnd
        } else {
            closest = CLLocationCoordinate2D(
                latitude: lineStart.latitude + param * C,
                longitude: lineStart.longitude + param * D
            )
        }
        
        return calculateDistance(point1: point, point2: closest)
    }
    
    /**
     * Calculate distance between two CLLocationCoordinate2D points using Haversine formula
     */
    private func calculateDistance(point1: CLLocationCoordinate2D, point2: CLLocationCoordinate2D) -> Double {
        let EARTH_RADIUS_METERS = 6371000.0
        let dLat = (point2.latitude - point1.latitude) * .pi / 180
        let dLng = (point2.longitude - point1.longitude) * .pi / 180
        
        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(point1.latitude * .pi / 180) * cos(point2.latitude * .pi / 180) *
                sin(dLng / 2) * sin(dLng / 2)
        
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return EARTH_RADIUS_METERS * c
    }
    
    /**
     * Point-in-polygon detection using ray casting algorithm
     */
    private func isPointInPolygon(point: CLLocationCoordinate2D, polygon: [CLLocationCoordinate2D]) -> Bool {
        var intersections = 0
        let x = point.longitude
        let y = point.latitude
        
        for i in polygon.indices {
            let p1 = polygon[i]
            let p2 = polygon[(i + 1) % polygon.count]
            
            if ((p1.latitude > y) != (p2.latitude > y)) &&
               (x < (p2.longitude - p1.longitude) * (y - p1.latitude) / (p2.latitude - p1.latitude) + p1.longitude) {
                intersections += 1
            }
        }
        
        return intersections % 2 == 1
    }
    
    /**
     * Log proximity debug information for testing
     */
    private func logProximityDebugInfo(_ location: CLLocation) {
        if smartConfig.enableDebugLogging {
            let distance = calculateDistanceToNearestZone(location)
            let interval = calculateProximityBasedInterval()
            
            print("\(Self.TAG): Proximity Debug:")
            print("  - Distance to nearest zone: \(distance)m")
            print("  - GPS interval: \(interval)s")
            print("  - Update strategy: \(smartConfig.updateStrategy)")
            print("  - Zones count: \(geofenceEngine.getZoneCount())")
        }
    }
    
    /**
     * Update movement state based on location changes
     */
    private func updateMovementState(_ location: CLLocation) {
        lastKnownLocation = location
        let currentTime = Date().timeIntervalSince1970
        guard let movementSettings = smartConfig.movementSettings else {
            lastLocationTime = currentTime
            return
        }
        
        if lastLocationTime > 0 {
            let timeDiff = currentTime - lastLocationTime
            let distance = lastKnownLocation?.distance(from: location) ?? 0
            
            // Check if device is stationary
            if timeDiff >= movementSettings.stationaryThresholdMs {
                if distance < movementSettings.movementThresholdMeters {
                    if !isStationary {
                        isStationary = true
                        print("\(Self.TAG): Device is now stationary")
                        updateLocationManagerSettings() // Update GPS settings (also emits status)
                    }
                } else {
                    if isStationary {
                        isStationary = false
                        print("\(Self.TAG): Device is now moving")
                        updateLocationManagerSettings() // Update GPS settings (also emits status)
                    }
                }
            }
        }
        
        lastLocationTime = currentTime
    }
    
    // MARK: - Battery Level Detection
    
    /**
     * Get current battery level percentage (as Int)
     */
    private func getBatteryLevelInt() -> Int {
        UIDevice.current.isBatteryMonitoringEnabled = true
        return Int(UIDevice.current.batteryLevel * 100)
    }
    
    /**
     * Get current battery mode based on level and settings
     */
    private func getCurrentBatteryMode() -> String {
        let batteryLevel = getBatteryLevelInt()
        guard let batterySettings = smartConfig.batterySettings else { return "normal" }
        
        switch batteryLevel {
        case ...batterySettings.criticalBatteryThreshold:
            return "critical"
        case ...batterySettings.lowBatteryThreshold:
            return "low"
        default:
            return "normal"
        }
    }
    
    // MARK: - Runtime Status Emission

    /**
     * Emit runtime status to Flutter via performance stream
     * Parity with Android LocationTracker.emitRuntimeStatus()
     */
    private func emitRuntimeStatus() {
        guard let location = lastKnownLocation else { return }

        let status: [String: Any] = [
            "strategy": smartConfig.updateStrategy.rawValue,
            "intervalMs": Int(currentGpsInterval * 1000),
            "accuracyProfile": smartConfig.accuracyProfile.rawValue,
            "nearestZoneDistanceM": calculateDistanceToNearestZone(location),
            "isStationary": isStationary,
            "batteryMode": getCurrentBatteryMode(),
            "gpsAccuracy": location.horizontalAccuracy,
            "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
        ]

        // Only emit if status changed or 30 seconds elapsed
        let currentTime = Date().timeIntervalSince1970
        let timeSinceLastEmit = currentTime - lastStatusEmitTime

        // Compare status dictionaries (simplified comparison - check key values)
        let statusChanged = !NSDictionary(dictionary: status).isEqual(to: lastEmittedStatus)

        if statusChanged || timeSinceLastEmit >= 30.0 {
            // Send via existing performance event channel
            let event: [String: Any] = [
                "type": "runtime_status",
                "data": status
            ]
            PolyfencePlugin.sendPerformanceEvent(event: event)
            lastEmittedStatus = status
            lastStatusEmitTime = currentTime
            NSLog("[LocationTracker] Runtime status emitted: \(status)")
        }
    }

}
