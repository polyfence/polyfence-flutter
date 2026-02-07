import Foundation
import CoreMotion

/**
 * Manages activity recognition using CoreMotion
 * Detects user activity (still, walking, running, cycling, driving)
 * and notifies listeners when activity changes
 */
class ActivityRecognitionManager {

    private static let TAG = "ActivityRecognition"

    // Motion activity manager
    private let motionActivityManager = CMMotionActivityManager()
    private let operationQueue = OperationQueue()

    // Current state
    private var currentActivity: ActivityType = .unknown
    private var currentConfidence: Int = 0
    private var isEnabled: Bool = false
    private var settings: ActivitySettings = ActivitySettings()

    // Debounce handling
    private var pendingActivityChange: ActivityType?
    private var debounceTimer: Timer?

    // Callback for activity changes
    private var onActivityChanged: ((ActivityType, Int) -> Void)?

    init() {
        operationQueue.name = "com.polyfence.activityRecognition"
        operationQueue.maxConcurrentOperationCount = 1
    }

    /**
     * Start activity recognition
     */
    func start(settings: ActivitySettings, callback: @escaping (ActivityType, Int) -> Void) {
        guard settings.enabled else {
            NSLog("[\(Self.TAG)] Activity recognition disabled in settings")
            return
        }

        guard CMMotionActivityManager.isActivityAvailable() else {
            NSLog("[\(Self.TAG)] Activity recognition not available on this device")
            return
        }

        guard hasPermission() else {
            NSLog("[\(Self.TAG)] Activity recognition permission not granted")
            return
        }

        self.settings = settings
        self.onActivityChanged = callback
        self.isEnabled = true

        // Start activity updates
        motionActivityManager.startActivityUpdates(to: operationQueue) { [weak self] activity in
            guard let self = self, let activity = activity else { return }
            self.handleActivityUpdate(activity)
        }

        NSLog("[\(Self.TAG)] Activity recognition started")
    }

    /**
     * Stop activity recognition
     */
    func stop() {
        guard isEnabled else { return }

        // Cancel pending debounce
        debounceTimer?.invalidate()
        debounceTimer = nil
        pendingActivityChange = nil

        // Stop activity updates
        motionActivityManager.stopActivityUpdates()

        isEnabled = false
        currentActivity = .unknown
        currentConfidence = 0

        NSLog("[\(Self.TAG)] Activity recognition stopped")
    }

    /**
     * Update settings
     */
    func updateSettings(_ newSettings: ActivitySettings) {
        let wasEnabled = settings.enabled
        settings = newSettings

        if !wasEnabled && newSettings.enabled {
            // Was disabled, now enabled - start
            if let callback = onActivityChanged {
                start(settings: newSettings, callback: callback)
            }
        } else if wasEnabled && !newSettings.enabled {
            // Was enabled, now disabled - stop
            stop()
        }
    }

    /**
     * Get current detected activity
     */
    func getCurrentActivity() -> ActivityType {
        return currentActivity
    }

    /**
     * Get current activity confidence
     */
    func getCurrentConfidence() -> Int {
        return currentConfidence
    }

    /**
     * Check if activity recognition is running
     */
    func isRunning() -> Bool {
        return isEnabled
    }

    /**
     * Check if activity recognition permission is granted
     */
    func hasPermission() -> Bool {
        let status = CMMotionActivityManager.authorizationStatus()
        return status == .authorized
    }

    /**
     * Handle activity update from CoreMotion
     */
    private func handleActivityUpdate(_ activity: CMMotionActivity) {
        let newActivity = mapToActivityType(activity)
        let confidence = mapConfidence(activity.confidence)

        NSLog("[\(Self.TAG)] Detected: \(newActivity) (confidence: \(confidence)%)")

        // Check confidence threshold
        guard confidence >= settings.confidenceThreshold else {
            NSLog("[\(Self.TAG)] Confidence below threshold (\(settings.confidenceThreshold)%), ignoring")
            return
        }

        // Check if activity changed
        if newActivity != currentActivity {
            applyDebounce(newActivity: newActivity, confidence: confidence)
        }
    }

    /**
     * Apply debounce before confirming activity change
     */
    private func applyDebounce(newActivity: ActivityType, confidence: Int) {
        // Cancel any pending change
        debounceTimer?.invalidate()

        // If same as pending, reset timer
        if newActivity == pendingActivityChange {
            NSLog("[\(Self.TAG)] Same activity pending, resetting debounce timer")
        }

        pendingActivityChange = newActivity

        // Schedule debounce timer on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.debounceTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(self.settings.debounceSeconds), repeats: false) { [weak self] _ in
                guard let self = self else { return }

                if self.pendingActivityChange == newActivity {
                    NSLog("[\(Self.TAG)] Activity confirmed after debounce: \(newActivity)")
                    self.currentActivity = newActivity
                    self.currentConfidence = confidence
                    self.onActivityChanged?(newActivity, confidence)
                }

                self.pendingActivityChange = nil
                self.debounceTimer = nil
            }

            NSLog("[\(Self.TAG)] Debounce started: \(self.settings.debounceSeconds)s for \(newActivity)")
        }
    }

    /**
     * Map CMMotionActivity to our ActivityType enum
     */
    private func mapToActivityType(_ activity: CMMotionActivity) -> ActivityType {
        // Priority order: automotive > cycling > running > walking > stationary
        if activity.automotive {
            return .driving
        } else if activity.cycling {
            return .cycling
        } else if activity.running {
            return .running
        } else if activity.walking {
            return .walking
        } else if activity.stationary {
            return .still
        } else {
            return .unknown
        }
    }

    /**
     * Map CMMotionActivityConfidence to percentage
     */
    private func mapConfidence(_ confidence: CMMotionActivityConfidence) -> Int {
        switch confidence {
        case .low:
            return 33
        case .medium:
            return 66
        case .high:
            return 100
        @unknown default:
            return 0
        }
    }
}
