import Foundation
import UserNotifications
import BackgroundTasks

/**
 * Manages scheduled tracking based on time windows
 * Automatically starts/stops LocationTracker at configured times
 */
class TrackingScheduler {

    // MARK: - Constants
    private static let TAG = "TrackingScheduler"
    private static let PREFS_KEY_SCHEDULE_ENABLED = "polyfence_schedule_enabled"
    private static let PREFS_KEY_TIME_WINDOWS = "polyfence_time_windows"
    private static let PREFS_KEY_START_IMMEDIATELY = "polyfence_start_immediately"

    // MARK: - Singleton
    static let shared = TrackingScheduler()

    // MARK: - Types

    /// Represents a time of day
    struct TimeOfDay {
        let hour: Int
        let minute: Int

        func toMinutesFromMidnight() -> Int {
            return hour * 60 + minute
        }

        static func fromMap(_ map: [String: Any]?) -> TimeOfDay? {
            guard let map = map,
                  let hour = map["hour"] as? Int,
                  let minute = map["minute"] as? Int else {
                return nil
            }
            return TimeOfDay(hour: hour, minute: minute)
        }
    }

    /// Represents a time window when tracking should be active
    struct TimeWindow {
        let startTime: TimeOfDay
        let endTime: TimeOfDay
        let daysOfWeek: [Int] // 1=Monday, 7=Sunday, empty=all days

        static func fromMap(_ map: [String: Any]) -> TimeWindow? {
            guard let startTime = TimeOfDay.fromMap(map["startTime"] as? [String: Any]),
                  let endTime = TimeOfDay.fromMap(map["endTime"] as? [String: Any]) else {
                return nil
            }
            let daysOfWeek = (map["daysOfWeek"] as? [Int]) ?? []
            return TimeWindow(startTime: startTime, endTime: endTime, daysOfWeek: daysOfWeek)
        }
    }

    /// Schedule configuration
    struct ScheduleConfig {
        var enabled: Bool = false
        var timeWindows: [TimeWindow] = []
        var startImmediatelyIfInWindow: Bool = true

        static func fromMap(_ map: [String: Any]?) -> ScheduleConfig {
            guard let map = map else { return ScheduleConfig() }

            let enabled = map["enabled"] as? Bool ?? false
            let startImmediately = map["startImmediatelyIfInWindow"] as? Bool ?? true
            let windowsList = (map["timeWindows"] as? [[String: Any]])?.compactMap { TimeWindow.fromMap($0) } ?? []

            return ScheduleConfig(enabled: enabled, timeWindows: windowsList, startImmediatelyIfInWindow: startImmediately)
        }
    }

    // MARK: - Properties
    private var config = ScheduleConfig()
    private var checkTimer: Timer?
    private weak var locationTracker: LocationTracker?

    // MARK: - Initialization
    private init() {}

    // MARK: - Public Methods

    /**
     * Set the LocationTracker reference for starting/stopping tracking
     */
    func setLocationTracker(_ tracker: LocationTracker) {
        self.locationTracker = tracker
    }

    /**
     * Update schedule configuration
     */
    func updateConfig(_ configMap: [String: Any]?) {
        config = ScheduleConfig.fromMap(configMap)
        saveConfig()

        if config.enabled {
            NSLog("[\(Self.TAG)] Schedule enabled with \(config.timeWindows.count) time windows")

            // Check if we should start tracking now
            if config.startImmediatelyIfInWindow && isCurrentlyInScheduledWindow() {
                NSLog("[\(Self.TAG)] Currently in scheduled window - starting tracking")
                startTracking()
            } else if !isCurrentlyInScheduledWindow() {
                NSLog("[\(Self.TAG)] Not in scheduled window - stopping tracking")
                stopTracking()
            }

            // Start periodic check timer
            startCheckTimer()
        } else {
            NSLog("[\(Self.TAG)] Schedule disabled - stopping timer")
            stopCheckTimer()
        }
    }

    /**
     * Check if current time is within any scheduled window
     */
    func isCurrentlyInScheduledWindow() -> Bool {
        if !config.enabled || config.timeWindows.isEmpty {
            return true // No schedule = always active
        }

        let now = Date()
        let calendar = Calendar.current
        let currentMinutes = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
        let currentDayOfWeek = getDayOfWeekIso(now) // 1=Monday, 7=Sunday

        for window in config.timeWindows {
            // Check if today is an allowed day
            if !window.daysOfWeek.isEmpty && !window.daysOfWeek.contains(currentDayOfWeek) {
                continue
            }

            let startMinutes = window.startTime.toMinutesFromMidnight()
            let endMinutes = window.endTime.toMinutesFromMidnight()

            // Handle windows that span midnight
            let isInWindow: Bool
            if endMinutes > startMinutes {
                // Normal window (e.g., 09:00 - 17:00)
                isInWindow = currentMinutes >= startMinutes && currentMinutes < endMinutes
            } else {
                // Window spans midnight (e.g., 22:00 - 06:00)
                isInWindow = currentMinutes >= startMinutes || currentMinutes < endMinutes
            }

            if isInWindow {
                return true
            }
        }

        return false
    }

    /**
     * Check if scheduling is enabled
     */
    func isEnabled() -> Bool {
        return config.enabled
    }

    /**
     * Load configuration from UserDefaults (called on app launch)
     */
    func loadConfig() {
        let defaults = UserDefaults.standard

        let enabled = defaults.bool(forKey: Self.PREFS_KEY_SCHEDULE_ENABLED)
        let startImmediately = defaults.bool(forKey: Self.PREFS_KEY_START_IMMEDIATELY)
        let windowsJson = defaults.string(forKey: Self.PREFS_KEY_TIME_WINDOWS) ?? ""

        var timeWindows: [TimeWindow] = []
        if !windowsJson.isEmpty {
            let windowStrings = windowsJson.split(separator: ";")
            for windowStr in windowStrings {
                let parts = windowStr.split(separator: "|")
                guard parts.count >= 2 else { continue }

                let startParts = parts[0].split(separator: ",")
                let endParts = parts[1].split(separator: ",")
                guard startParts.count == 2, endParts.count == 2,
                      let startHour = Int(startParts[0]),
                      let startMinute = Int(startParts[1]),
                      let endHour = Int(endParts[0]),
                      let endMinute = Int(endParts[1]) else { continue }

                var days: [Int] = []
                if parts.count > 2 && !parts[2].isEmpty {
                    days = parts[2].split(separator: ",").compactMap { Int($0) }
                }

                let window = TimeWindow(
                    startTime: TimeOfDay(hour: startHour, minute: startMinute),
                    endTime: TimeOfDay(hour: endHour, minute: endMinute),
                    daysOfWeek: days
                )
                timeWindows.append(window)
            }
        }

        config = ScheduleConfig(enabled: enabled, timeWindows: timeWindows, startImmediatelyIfInWindow: startImmediately)

        if config.enabled {
            NSLog("[\(Self.TAG)] Loaded schedule config with \(config.timeWindows.count) windows")
            startCheckTimer()
        }
    }

    // MARK: - Private Methods

    /**
     * Start the periodic check timer
     */
    private func startCheckTimer() {
        stopCheckTimer()

        // Check every minute
        checkTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.checkSchedule()
        }
        RunLoop.main.add(checkTimer!, forMode: .common)

        NSLog("[\(Self.TAG)] Schedule check timer started")
    }

    /**
     * Stop the periodic check timer
     */
    private func stopCheckTimer() {
        checkTimer?.invalidate()
        checkTimer = nil
    }

    /**
     * Check current schedule and start/stop tracking accordingly
     */
    private func checkSchedule() {
        let shouldTrack = isCurrentlyInScheduledWindow()
        let isTracking = locationTracker != nil

        if shouldTrack && !isTracking {
            NSLog("[\(Self.TAG)] Entered scheduled window - starting tracking")
            startTracking()
        } else if !shouldTrack && isTracking {
            NSLog("[\(Self.TAG)] Left scheduled window - stopping tracking")
            stopTracking()
        }
    }

    /**
     * Start tracking via LocationTracker
     */
    private func startTracking() {
        DispatchQueue.main.async { [weak self] in
            self?.locationTracker?.startTracking()
        }
    }

    /**
     * Stop tracking via LocationTracker
     */
    private func stopTracking() {
        DispatchQueue.main.async { [weak self] in
            self?.locationTracker?.stopTracking()
        }
    }

    /**
     * Convert Date to ISO day of week (1=Monday, 7=Sunday)
     */
    private func getDayOfWeekIso(_ date: Date) -> Int {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        // Calendar.weekday: 1=Sunday, 2=Monday, ..., 7=Saturday
        // Convert to ISO: 1=Monday, 7=Sunday
        switch weekday {
        case 1: return 7  // Sunday
        case 2: return 1  // Monday
        case 3: return 2  // Tuesday
        case 4: return 3  // Wednesday
        case 5: return 4  // Thursday
        case 6: return 5  // Friday
        case 7: return 6  // Saturday
        default: return 1
        }
    }

    /**
     * Save configuration to UserDefaults
     */
    private func saveConfig() {
        let defaults = UserDefaults.standard

        defaults.set(config.enabled, forKey: Self.PREFS_KEY_SCHEDULE_ENABLED)
        defaults.set(config.startImmediatelyIfInWindow, forKey: Self.PREFS_KEY_START_IMMEDIATELY)

        // Serialize time windows
        let windowsJson = config.timeWindows.map { window in
            let days = window.daysOfWeek.map { String($0) }.joined(separator: ",")
            return "\(window.startTime.hour),\(window.startTime.minute)|\(window.endTime.hour),\(window.endTime.minute)|\(days)"
        }.joined(separator: ";")
        defaults.set(windowsJson, forKey: Self.PREFS_KEY_TIME_WINDOWS)

        defaults.synchronize()
    }
}
