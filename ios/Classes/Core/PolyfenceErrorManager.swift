import Foundation
import Flutter

/**
 * Manages error reporting to Flutter developers
 * Integrates with existing error handling systems
 */
class PolyfenceErrorManager {
    static let shared = PolyfenceErrorManager()
    private var eventSink: FlutterEventSink?
    
    private init() {}
    
    func initialize(eventSink: @escaping FlutterEventSink) {
        self.eventSink = eventSink
        print("PolyfenceErrorManager: Error stream listener connected")
    }
    
    func reportError(
        type: String,
        message: String,
        context: [String: Any] = [:],
        correlationId: String? = nil
    ) {
        let errorData: [String: Any] = [
            "type": type,
            "message": message,
            "context": context,
            "timestamp": Int64(Date().timeIntervalSince1970 * 1000),
            "correlationId": correlationId ?? UUID().uuidString
        ]
        
        eventSink?(errorData)
        print("PolyfenceErrorManager: Error reported to Flutter: \(type) - \(message)")
    }
    
    func reportGpsError(type: String, details: String = "") {
        let context: [String: Any] = [
            "platform": "ios",
            "details": details
        ]
        
        reportError(
            type: type,
            message: getErrorMessage(type: type, details: details),
            context: context
        )
    }
    
    func reportServiceError(type: String, details: String = "") {
        let context: [String: Any] = [
            "platform": "ios",
            "details": details
        ]
        
        reportError(
            type: type,
            message: getErrorMessage(type: type, details: details),
            context: context
        )
    }
    
    func reportBatteryError(type: String, details: String = "") {
        let context: [String: Any] = [
            "platform": "ios",
            "details": details,
            "batteryOptimizationRequired": true
        ]
        
        reportError(
            type: type,
            message: getErrorMessage(type: type, details: details),
            context: context
        )
    }
    
    private func getErrorMessage(type: String, details: String) -> String {
        switch type {
        case "gps_timeout":
            return "GPS signal timeout - location services may be disabled or weak signal"
        case "gps_permission_denied":
            return "Location permission was denied - please grant location access"
        case "gps_service_disabled":
            return "Location services are disabled - please enable GPS"
        case "gps_accuracy_poor":
            return "GPS accuracy is poor - may affect geofence detection reliability"
        case "service_start_failed":
            return "Failed to start location tracking service"
        case "service_killed":
            return "Location service was terminated by system - may need background app refresh"
        case "service_restart_failed":
            return "Failed to restart location service after crash"
        case "battery_optimization_required":
            return "Background app refresh may be required for reliable background operation"
        case "low_battery":
            return "Low battery detected - location tracking may be limited"
        case "zone_validation_failed":
            return "Zone validation failed: \(details)"
        case "zone_storage_failed":
            return "Failed to store zone data: \(details)"
        case "zone_load_failed":
            return "Failed to load zone data: \(details)"
        case "network_timeout":
            return "Network timeout - analytics upload may be delayed"
        case "analytics_upload_failed":
            return "Failed to upload analytics data: \(details)"
        case "permission_revoked":
            return "Location permission was revoked while tracking"
        case "memory_low":
            return "Low memory detected - may affect performance"
        default:
            return "Unknown error occurred: \(type) - \(details)"
        }
    }
}
