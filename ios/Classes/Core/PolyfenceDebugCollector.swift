import Foundation
import CoreLocation
import UIKit

/**
 * Collects debug information for the Polyfence plugin
 * Provides system status, performance metrics, and error history
 */
class PolyfenceDebugCollector {
    static let shared = PolyfenceDebugCollector()
    
    private var performanceMetrics: [String: Any] = [:]
    private var errorHistory: [[String: Any]] = []
    private var sessionStartTime = Date()
    
    private init() {}
    
    func collectDebugInfo() -> [String: Any] {
        return [
            "systemStatus": collectSystemStatus(),
            "performance": collectPerformanceMetrics(),
            "battery": collectBatteryMetrics(),
            "zones": collectZoneStatus(),
            "recentErrors": getRecentErrors()
        ]
    }
    
    private func collectSystemStatus() -> [String: Any] {
        let locationManager = CLLocationManager()
        
        return [
            "isLocationPermissionGranted": CLLocationManager.authorizationStatus() == .authorizedAlways || CLLocationManager.authorizationStatus() == .authorizedWhenInUse,
            "isBackgroundLocationEnabled": CLLocationManager.authorizationStatus() == .authorizedAlways,
            "isBatteryOptimizationDisabled": true, // iOS doesn't have battery optimization like Android
            "isGpsEnabled": CLLocationManager.locationServicesEnabled(),
            "isWakeLockAcquired": false, // iOS doesn't use wake locks
            "lastKnownAccuracy": performanceMetrics["lastAccuracy"] as? Double ?? -1.0,
            "lastLocationUpdate": (performanceMetrics["lastLocationUpdate"] as? Date ?? Date()).timeIntervalSince1970 * 1000,
            "platformVersion": UIDevice.current.systemVersion,
            "pluginVersion": "0.2.4"
        ]
    }
    
    private func collectPerformanceMetrics() -> [String: Any] {
        let uptime = Date().timeIntervalSince(sessionStartTime) * 1000 // Convert to milliseconds
        
        return [
            "uptime": Int(uptime),
            "totalLocationUpdates": performanceMetrics["locationUpdateCount"] as? Int ?? 0,
            "totalZoneDetections": performanceMetrics["zoneDetectionCount"] as? Int ?? 0,
            "averageDetectionLatency": performanceMetrics["avgDetectionLatency"] as? Double ?? 0.0,
            "memoryUsageMB": getMemoryUsage(),
            "cpuUsagePercent": 0.0, // CPU usage is complex to get on iOS
            "restartCount": performanceMetrics["restartCount"] as? Int ?? 0
        ]
    }
    
    private func collectBatteryMetrics() -> [String: Any] {
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        return [
            "estimatedHourlyDrain": 0.0,
            "gpsActiveTimePercent": 0,
            "wakeUpCount": 0,
            "isCharging": UIDevice.current.batteryState == .charging,
            "batteryLevel": Int(UIDevice.current.batteryLevel * 100),
            "totalActiveTime": Int(Date().timeIntervalSince(sessionStartTime) * 1000)
        ]
    }
    
    private func collectZoneStatus() -> [String: Any] {
        return [
            "activeZones": performanceMetrics["activeZones"] as? Int ?? 0,
            "circleZones": performanceMetrics["circleZones"] as? Int ?? 0,
            "polygonZones": performanceMetrics["polygonZones"] as? Int ?? 0,
            "lastZoneUpdate": (performanceMetrics["lastZoneUpdate"] as? Date ?? Date()).timeIntervalSince1970 * 1000,
            "zoneEventCounts": performanceMetrics["zoneEventCounts"] as? [String: Int] ?? [:]
        ]
    }
    
    private func getRecentErrors() -> [[String: Any]] {
        return errorHistory
    }
    
    func getErrorHistory(timeRangeMs: Int64?, errorTypes: [String]?) -> [[String: Any]] {
        var filteredErrors = errorHistory
        
        // Filter by time range
        if let timeRangeMs = timeRangeMs {
            let cutoffTime = Date().timeIntervalSince1970 * 1000 - Double(timeRangeMs)
            filteredErrors = filteredErrors.filter { error in
                let timestamp = error["timestamp"] as? Double ?? 0
                return timestamp >= cutoffTime
            }
        }
        
        // Filter by error types
        if let errorTypes = errorTypes, !errorTypes.isEmpty {
            filteredErrors = filteredErrors.filter { error in
                let type = error["type"] as? String
                return errorTypes.contains(type ?? "")
            }
        }
        
        return filteredErrors
    }
    
    // Helper methods for recording metrics
    func recordLocationUpdate(accuracy: Double) {
        performanceMetrics["lastAccuracy"] = accuracy
        performanceMetrics["lastLocationUpdate"] = Date()
        let count = performanceMetrics["locationUpdateCount"] as? Int ?? 0
        performanceMetrics["locationUpdateCount"] = count + 1
    }
    
    func recordZoneDetection(latencyMs: Int64) {
        let count = performanceMetrics["zoneDetectionCount"] as? Int ?? 0
        performanceMetrics["zoneDetectionCount"] = count + 1
        
        let avgLatency = performanceMetrics["avgDetectionLatency"] as? Double ?? 0.0
        let newAvg = count > 0 ? ((avgLatency * Double(count - 1)) + Double(latencyMs)) / Double(count) : Double(latencyMs)
        performanceMetrics["avgDetectionLatency"] = newAvg
    }
    
    func addErrorToHistory(_ error: [String: Any]) {
        errorHistory.append(error)
        // Keep history size manageable
        if errorHistory.count > 100 {
            errorHistory.removeFirst()
        }
    }
    
    private func getMemoryUsage() -> Int {
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
            return Int(info.resident_size / 1024 / 1024) // Convert to MB
        }
        return 0
    }
}
