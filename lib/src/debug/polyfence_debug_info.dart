/// Comprehensive debug information about the Polyfence plugin state.
///
/// Returned by [PolyfenceService.debugInfo] for troubleshooting and monitoring.
///
/// **Example:**
/// ```dart
/// final debug = await Polyfence.instance.debugInfo();
/// print('Zones: ${debug.zones.activeZones}');
/// print('GPS accuracy: ${debug.systemStatus.lastKnownAccuracy}m');
/// print('Battery drain: ${debug.battery.estimatedHourlyDrain}%/hr');
/// ```
class PolyfenceDebugInfo {
  /// Current system and permission status.
  final PolyfenceSystemStatus systemStatus;

  /// Performance metrics (uptime, detections, latency).
  final PolyfencePerformanceMetrics performance;

  /// Battery usage metrics.
  final PolyfenceBatteryMetrics battery;

  /// Zone statistics.
  final PolyfenceZoneStatus zones;

  /// Recent errors for troubleshooting.
  final List<PolyfenceErrorSummary> recentErrors;

  /// Creates debug info with all metrics.
  PolyfenceDebugInfo({
    required this.systemStatus,
    required this.performance,
    required this.battery,
    required this.zones,
    required this.recentErrors,
  });

  /// Creates debug info from a platform channel map.
  ///
  /// Safely handles missing or null nested maps by falling back to empty maps.
  factory PolyfenceDebugInfo.fromMap(Map<String, dynamic> map) {
    return PolyfenceDebugInfo(
      systemStatus: PolyfenceSystemStatus.fromMap(
        Map<String, dynamic>.from(map['systemStatus'] ?? {}),
      ),
      performance: PolyfencePerformanceMetrics.fromMap(
        Map<String, dynamic>.from(map['performance'] ?? {}),
      ),
      battery: PolyfenceBatteryMetrics.fromMap(
        Map<String, dynamic>.from(map['battery'] ?? {}),
      ),
      zones: PolyfenceZoneStatus.fromMap(
        Map<String, dynamic>.from(map['zones'] ?? {}),
      ),
      recentErrors: (map['recentErrors'] as List?)
              ?.map((e) =>
                  PolyfenceErrorSummary.fromMap(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
    );
  }

  /// Converts to a map for serialization.
  Map<String, dynamic> toMap() {
    return {
      'systemStatus': systemStatus.toMap(),
      'performance': performance.toMap(),
      'battery': battery.toMap(),
      'zones': zones.toMap(),
      'recentErrors': recentErrors.map((e) => e.toMap()).toList(),
    };
  }
}

/// System status including permissions, GPS state, and versions.
class PolyfenceSystemStatus {
  /// Whether location permission has been granted.
  final bool isLocationPermissionGranted;

  /// Whether background location access is enabled.
  final bool isBackgroundLocationEnabled;

  /// Whether battery optimization is disabled (Android).
  final bool isBatteryOptimizationDisabled;

  /// Whether GPS/location services are enabled on the device.
  final bool isGpsEnabled;

  /// Whether a wake lock is currently held (Android).
  final bool isWakeLockAcquired;

  /// Last known GPS accuracy in meters (-1 if unknown).
  final double lastKnownAccuracy;

  /// When the last location update was received.
  final DateTime lastLocationUpdate;

  /// OS version (e.g., "Android 14", "iOS 17.2").
  final String platformVersion;

  /// Polyfence plugin version.
  final String pluginVersion;

  /// Creates system status.
  PolyfenceSystemStatus({
    required this.isLocationPermissionGranted,
    required this.isBackgroundLocationEnabled,
    required this.isBatteryOptimizationDisabled,
    required this.isGpsEnabled,
    required this.isWakeLockAcquired,
    required this.lastKnownAccuracy,
    required this.lastLocationUpdate,
    required this.platformVersion,
    required this.pluginVersion,
  });

  /// Creates system status from a platform channel map.
  factory PolyfenceSystemStatus.fromMap(Map<String, dynamic> map) {
    return PolyfenceSystemStatus(
      isLocationPermissionGranted: map['isLocationPermissionGranted'] ?? false,
      isBackgroundLocationEnabled: map['isBackgroundLocationEnabled'] ?? false,
      isBatteryOptimizationDisabled:
          map['isBatteryOptimizationDisabled'] ?? false,
      isGpsEnabled: map['isGpsEnabled'] ?? false,
      isWakeLockAcquired: map['isWakeLockAcquired'] ?? false,
      lastKnownAccuracy: (map['lastKnownAccuracy'] ?? -1.0).toDouble(),
      lastLocationUpdate: DateTime.fromMillisecondsSinceEpoch(
        map['lastLocationUpdate'] ?? 0,
      ),
      platformVersion: map['platformVersion'] ?? 'Unknown',
      pluginVersion: map['pluginVersion'] ?? 'Unknown',
    );
  }

  /// Converts to a map for serialization.
  Map<String, dynamic> toMap() {
    return {
      'isLocationPermissionGranted': isLocationPermissionGranted,
      'isBackgroundLocationEnabled': isBackgroundLocationEnabled,
      'isBatteryOptimizationDisabled': isBatteryOptimizationDisabled,
      'isGpsEnabled': isGpsEnabled,
      'isWakeLockAcquired': isWakeLockAcquired,
      'lastKnownAccuracy': lastKnownAccuracy,
      'lastLocationUpdate': lastLocationUpdate.millisecondsSinceEpoch,
      'platformVersion': platformVersion,
      'pluginVersion': pluginVersion,
    };
  }
}

/// Performance metrics for monitoring plugin health.
class PolyfencePerformanceMetrics {
  /// How long the plugin has been running.
  final Duration uptime;

  /// Total number of GPS location updates received.
  final int totalLocationUpdates;

  /// Total number of zone entry/exit detections.
  final int totalZoneDetections;

  /// Average time in milliseconds to detect zone crossings.
  final double averageDetectionLatency;

  /// Estimated memory usage in megabytes.
  final int memoryUsageMB;

  /// Estimated CPU usage percentage.
  final double cpuUsagePercent;

  /// Number of times the background service was restarted.
  final int restartCount;

  /// Creates performance metrics.
  PolyfencePerformanceMetrics({
    required this.uptime,
    required this.totalLocationUpdates,
    required this.totalZoneDetections,
    required this.averageDetectionLatency,
    required this.memoryUsageMB,
    required this.cpuUsagePercent,
    required this.restartCount,
  });

  /// Creates performance metrics from a platform channel map.
  factory PolyfencePerformanceMetrics.fromMap(Map<String, dynamic> map) {
    return PolyfencePerformanceMetrics(
      uptime: Duration(milliseconds: map['uptime'] ?? 0),
      totalLocationUpdates: map['totalLocationUpdates'] ?? 0,
      totalZoneDetections: map['totalZoneDetections'] ?? 0,
      averageDetectionLatency:
          (map['averageDetectionLatency'] ?? 0.0).toDouble(),
      memoryUsageMB: map['memoryUsageMB'] ?? 0,
      cpuUsagePercent: (map['cpuUsagePercent'] ?? 0.0).toDouble(),
      restartCount: map['restartCount'] ?? 0,
    );
  }

  /// Converts to a map for serialization.
  Map<String, dynamic> toMap() {
    return {
      'uptime': uptime.inMilliseconds,
      'totalLocationUpdates': totalLocationUpdates,
      'totalZoneDetections': totalZoneDetections,
      'averageDetectionLatency': averageDetectionLatency,
      'memoryUsageMB': memoryUsageMB,
      'cpuUsagePercent': cpuUsagePercent,
      'restartCount': restartCount,
    };
  }
}

/// Battery usage metrics for monitoring power consumption.
class PolyfenceBatteryMetrics {
  /// Estimated battery drain per hour as a percentage.
  final double estimatedHourlyDrain;

  /// Percentage of time GPS has been actively polling.
  final int gpsActiveTimePercent;

  /// Number of times the device was woken from sleep.
  final int wakeUpCount;

  /// Whether the device is currently charging.
  final bool isCharging;

  /// Current battery level (0-100).
  final int batteryLevel;

  /// Total time the plugin has been actively tracking.
  final Duration totalActiveTime;

  /// Creates battery metrics.
  PolyfenceBatteryMetrics({
    required this.estimatedHourlyDrain,
    required this.gpsActiveTimePercent,
    required this.wakeUpCount,
    required this.isCharging,
    required this.batteryLevel,
    required this.totalActiveTime,
  });

  /// Creates battery metrics from a platform channel map.
  factory PolyfenceBatteryMetrics.fromMap(Map<String, dynamic> map) {
    return PolyfenceBatteryMetrics(
      estimatedHourlyDrain: (map['estimatedHourlyDrain'] ?? 0.0).toDouble(),
      gpsActiveTimePercent: map['gpsActiveTimePercent'] ?? 0,
      wakeUpCount: map['wakeUpCount'] ?? 0,
      isCharging: map['isCharging'] ?? false,
      batteryLevel: map['batteryLevel'] ?? 0,
      totalActiveTime: Duration(milliseconds: map['totalActiveTime'] ?? 0),
    );
  }

  /// Converts to a map for serialization.
  Map<String, dynamic> toMap() {
    return {
      'estimatedHourlyDrain': estimatedHourlyDrain,
      'gpsActiveTimePercent': gpsActiveTimePercent,
      'wakeUpCount': wakeUpCount,
      'isCharging': isCharging,
      'batteryLevel': batteryLevel,
      'totalActiveTime': totalActiveTime.inMilliseconds,
    };
  }
}

/// Statistics about monitored zones.
class PolyfenceZoneStatus {
  /// Total number of active zones being monitored.
  final int activeZones;

  /// Number of circle zones.
  final int circleZones;

  /// Number of polygon zones.
  final int polygonZones;

  /// When zones were last updated.
  final DateTime lastZoneUpdate;

  /// Map of zone IDs to their event counts.
  final Map<String, int> zoneEventCounts;

  /// Creates zone status.
  PolyfenceZoneStatus({
    required this.activeZones,
    required this.circleZones,
    required this.polygonZones,
    required this.lastZoneUpdate,
    required this.zoneEventCounts,
  });

  /// Creates zone status from a platform channel map.
  factory PolyfenceZoneStatus.fromMap(Map<String, dynamic> map) {
    return PolyfenceZoneStatus(
      activeZones: map['activeZones'] ?? 0,
      circleZones: map['circleZones'] ?? 0,
      polygonZones: map['polygonZones'] ?? 0,
      lastZoneUpdate: DateTime.fromMillisecondsSinceEpoch(
        map['lastZoneUpdate'] ?? 0,
      ),
      zoneEventCounts: Map<String, int>.from(map['zoneEventCounts'] ?? {}),
    );
  }

  /// Converts to a map for serialization.
  Map<String, dynamic> toMap() {
    return {
      'activeZones': activeZones,
      'circleZones': circleZones,
      'polygonZones': polygonZones,
      'lastZoneUpdate': lastZoneUpdate.millisecondsSinceEpoch,
      'zoneEventCounts': zoneEventCounts,
    };
  }
}

/// Summary of an error for the debug info error list.
class PolyfenceErrorSummary {
  /// Error type as a string.
  final String type;

  /// Human-readable error message.
  final String message;

  /// When the error occurred.
  final DateTime timestamp;

  /// Optional correlation ID.
  final String? correlationId;

  /// Additional error context.
  final Map<String, dynamic> context;

  /// Creates an error summary.
  PolyfenceErrorSummary({
    required this.type,
    required this.message,
    required this.timestamp,
    this.correlationId,
    required this.context,
  });

  /// Creates an error summary from a platform channel map.
  factory PolyfenceErrorSummary.fromMap(Map<String, dynamic> map) {
    return PolyfenceErrorSummary(
      type: map['type'] ?? 'unknown',
      message: map['message'] ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        map['timestamp'] ?? 0,
      ),
      correlationId: map['correlationId'],
      context: Map<String, dynamic>.from(map['context'] ?? {}),
    );
  }

  /// Converts to a map for serialization.
  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'message': message,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'correlationId': correlationId,
      'context': context,
    };
  }
}
