import 'package:flutter/foundation.dart';

/// Comprehensive debug information about the Polyfence plugin state.
///
/// Returned by [PolyfenceService.debugInfo] for troubleshooting and monitoring.
///
/// **Example:**
/// ```dart
/// final debug = await Polyfence.instance.debugInfo();
/// print('Zones: ${debug.zones.activeZones}');
/// print('GPS accuracy: ${debug.systemStatus.lastKnownAccuracy}m');
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

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PolyfenceDebugInfo &&
        other.systemStatus == systemStatus &&
        other.performance == performance &&
        other.battery == battery &&
        other.zones == zones &&
        listEquals(other.recentErrors, recentErrors);
  }

  @override
  int get hashCode => Object.hash(
        systemStatus,
        performance,
        battery,
        zones,
        Object.hashAll(recentErrors),
      );

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
  ///
  /// Null on iOS, which has no battery-optimisation exemption to report.
  final bool? isBatteryOptimizationDisabled;

  /// Whether GPS/location services are enabled on the device.
  final bool isGpsEnabled;

  /// Whether a wake lock is currently held (Android).
  ///
  /// Null on iOS, which has no wake locks, and on Android when no tracking
  /// service is running — nothing could then be holding one.
  final bool? isWakeLockAcquired;

  /// Last known GPS accuracy in meters (-1 if unknown).
  final double lastKnownAccuracy;

  /// When the last location update was received.
  final DateTime lastLocationUpdate;

  /// OS version (e.g., "Android 14", "iOS 17.2").
  final String platformVersion;

  /// Polyfence plugin version.
  final String pluginVersion;

  /// State of the most recent OS wake-fence registration attempt, or `null`
  /// when no registration has been attempted — which is what a consumer with
  /// [PolyfenceConfiguration.osGeofenceWakeEnabled] off always sees, and what
  /// distinguishes "not opted in" from "opted in and failing".
  final OsGeofenceRegistrationHealth? osGeofenceRegistrationHealth;

  /// Creates system status.
  PolyfenceSystemStatus({
    required this.isLocationPermissionGranted,
    required this.isBackgroundLocationEnabled,
    this.isBatteryOptimizationDisabled,
    required this.isGpsEnabled,
    this.isWakeLockAcquired,
    required this.lastKnownAccuracy,
    required this.lastLocationUpdate,
    required this.platformVersion,
    required this.pluginVersion,
    this.osGeofenceRegistrationHealth,
  });

  /// Creates system status from a platform channel map.
  factory PolyfenceSystemStatus.fromMap(Map<String, dynamic> map) {
    final health = map['osGeofenceRegistrationHealth'];
    return PolyfenceSystemStatus(
      isLocationPermissionGranted: map['isLocationPermissionGranted'] ?? false,
      isBackgroundLocationEnabled: map['isBackgroundLocationEnabled'] ?? false,
      isBatteryOptimizationDisabled:
          map['isBatteryOptimizationDisabled'] as bool?,
      isGpsEnabled: map['isGpsEnabled'] ?? false,
      isWakeLockAcquired: map['isWakeLockAcquired'] as bool?,
      lastKnownAccuracy: (map['lastKnownAccuracy'] ?? -1.0).toDouble(),
      lastLocationUpdate: DateTime.fromMillisecondsSinceEpoch(
        (map['lastLocationUpdate'] as num?)?.toInt() ?? 0,
      ),
      platformVersion: map['platformVersion'] ?? 'Unknown',
      pluginVersion: map['pluginVersion'] ?? 'Unknown',
      osGeofenceRegistrationHealth: health is Map
          ? OsGeofenceRegistrationHealth.fromMap(
              Map<String, dynamic>.from(health),
            )
          : null,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PolyfenceSystemStatus &&
        other.isLocationPermissionGranted == isLocationPermissionGranted &&
        other.isBackgroundLocationEnabled == isBackgroundLocationEnabled &&
        other.isBatteryOptimizationDisabled == isBatteryOptimizationDisabled &&
        other.isGpsEnabled == isGpsEnabled &&
        other.isWakeLockAcquired == isWakeLockAcquired &&
        other.lastKnownAccuracy == lastKnownAccuracy &&
        other.lastLocationUpdate == lastLocationUpdate &&
        other.platformVersion == platformVersion &&
        other.pluginVersion == pluginVersion &&
        other.osGeofenceRegistrationHealth == osGeofenceRegistrationHealth;
  }

  @override
  int get hashCode => Object.hash(
        isLocationPermissionGranted,
        isBackgroundLocationEnabled,
        isBatteryOptimizationDisabled,
        isGpsEnabled,
        isWakeLockAcquired,
        lastKnownAccuracy,
        lastLocationUpdate,
        platformVersion,
        pluginVersion,
        osGeofenceRegistrationHealth,
      );

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
      'osGeofenceRegistrationHealth': osGeofenceRegistrationHealth?.toMap(),
    };
  }
}

/// State of the most recent attempt to register zone perimeters with the
/// operating system's geofence service.
///
/// Reached through [PolyfenceSystemStatus.osGeofenceRegistrationHealth], where
/// `null` means no attempt has been made yet.
class OsGeofenceRegistrationHealth {
  /// How many zones Polyfence asked the OS to monitor.
  final int requested;

  /// How many the OS accepted. Fewer than [requested] means the platform's
  /// per-app cap was reached and coverage is partial — expected on a large zone
  /// set, not a failure, and [lastError] stays `null`. Zero while the app is
  /// foregrounded is also deliberate: slots are released whenever the in-process
  /// engine is doing the detecting.
  final int registered;

  /// Why the last attempt could not register everything, or `null` when nothing
  /// went wrong. `"background_location_denied"` means the grant OS wake fences
  /// need is missing — `ACCESS_BACKGROUND_LOCATION` on Android, "Always"
  /// authorization on iOS.
  final String? lastError;

  /// Creates a registration health snapshot.
  const OsGeofenceRegistrationHealth({
    required this.requested,
    required this.registered,
    this.lastError,
  });

  /// Creates a snapshot from a platform channel map.
  factory OsGeofenceRegistrationHealth.fromMap(Map<String, dynamic> map) {
    return OsGeofenceRegistrationHealth(
      requested: (map['requested'] as num?)?.toInt() ?? 0,
      registered: (map['registered'] as num?)?.toInt() ?? 0,
      lastError: map['lastError'] as String?,
    );
  }

  /// Converts to a map for serialization.
  Map<String, dynamic> toMap() {
    return {
      'requested': requested,
      'registered': registered,
      'lastError': lastError,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OsGeofenceRegistrationHealth &&
        other.requested == requested &&
        other.registered == registered &&
        other.lastError == lastError;
  }

  @override
  int get hashCode => Object.hash(requested, registered, lastError);

  @override
  String toString() {
    return 'OsGeofenceRegistrationHealth('
        'requested: $requested, '
        'registered: $registered, '
        'lastError: $lastError'
        ')';
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

  /// How many of those crossings were timed, and so how many samples
  /// [averageDetectionLatency] covers.
  ///
  /// Lower than [totalZoneDetections] when the engine synthesised a crossing
  /// outside a timed evaluation — a degraded-GPS exit, for instance. Those are
  /// real crossings the consumer received, so they are counted, but they
  /// contribute no latency sample.
  final int timedZoneDetections;

  /// Average time in milliseconds to detect zone crossings.
  ///
  /// Null until at least one crossing has been timed. Zero is the best
  /// possible latency, so an unmeasured device is reported as unmeasured
  /// rather than as a perfect one.
  final double? averageDetectionLatency;

  /// Estimated memory usage in megabytes.
  ///
  /// Whole-process resident size on iOS, Java heap only on Android — the two
  /// are not comparable across platforms.
  final int memoryUsageMB;

  /// Number of times the background service was restarted.
  ///
  /// Null on iOS, which has no foreground service to restart.
  final int? restartCount;

  /// Creates performance metrics.
  PolyfencePerformanceMetrics({
    required this.uptime,
    required this.totalLocationUpdates,
    required this.totalZoneDetections,
    required this.timedZoneDetections,
    this.averageDetectionLatency,
    required this.memoryUsageMB,
    this.restartCount,
  });

  /// Creates performance metrics from a platform channel map.
  factory PolyfencePerformanceMetrics.fromMap(Map<String, dynamic> map) {
    final timedDetections = (map['timedZoneDetections'] as num?)?.toInt() ?? 0;
    return PolyfencePerformanceMetrics(
      uptime: Duration(milliseconds: (map['uptime'] as num?)?.toInt() ?? 0),
      totalLocationUpdates: (map['totalLocationUpdates'] as num?)?.toInt() ?? 0,
      totalZoneDetections: (map['totalZoneDetections'] as num?)?.toInt() ?? 0,
      timedZoneDetections: timedDetections,
      // A mean with no samples behind it is not a mean. A native build older
      // than this contract sends 0.0 for "nothing measured yet", and 0.0 is
      // the best possible latency — so it is dropped rather than passed on
      // to look like a perfect one.
      averageDetectionLatency: timedDetections > 0
          ? (map['averageDetectionLatency'] as num?)?.toDouble()
          : null,
      memoryUsageMB: (map['memoryUsageMB'] as num?)?.toInt() ?? 0,
      restartCount: (map['restartCount'] as num?)?.toInt(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PolyfencePerformanceMetrics &&
        other.uptime == uptime &&
        other.totalLocationUpdates == totalLocationUpdates &&
        other.totalZoneDetections == totalZoneDetections &&
        other.timedZoneDetections == timedZoneDetections &&
        other.averageDetectionLatency == averageDetectionLatency &&
        other.memoryUsageMB == memoryUsageMB &&
        other.restartCount == restartCount;
  }

  @override
  int get hashCode => Object.hash(
        uptime,
        totalLocationUpdates,
        totalZoneDetections,
        timedZoneDetections,
        averageDetectionLatency,
        memoryUsageMB,
        restartCount,
      );

  /// Converts to a map for serialization.
  Map<String, dynamic> toMap() {
    return {
      'uptime': uptime.inMilliseconds,
      'totalLocationUpdates': totalLocationUpdates,
      'totalZoneDetections': totalZoneDetections,
      'timedZoneDetections': timedZoneDetections,
      'averageDetectionLatency': averageDetectionLatency,
      'memoryUsageMB': memoryUsageMB,
      'restartCount': restartCount,
    };
  }
}

/// Reads a battery percentage, rejecting anything outside 0-100.
///
/// A negative value is how older native builds signalled a level the OS had
/// not populated; passing it through would show a consumer a charge the
/// device never had, and a `?? default` on their side would not catch it.
int? _batteryLevelOrNull(Object? raw) {
  final value = (raw as num?)?.toInt();
  if (value == null || value < 0 || value > 100) return null;
  return value;
}

/// Battery usage metrics for monitoring power consumption.
class PolyfenceBatteryMetrics {
  /// Whether the device is currently charging.
  final bool isCharging;

  /// Current battery level (0-100).
  ///
  /// Null on iOS before the operating system has populated the level, which
  /// is always the case in the Simulator. A value outside 0-100 is also
  /// reported as null: older native builds signalled "not populated" with a
  /// negative sentinel, and a charge no device ever had is not a
  /// measurement.
  final int? batteryLevel;

  /// Total time the plugin has been actively tracking.
  final Duration totalActiveTime;

  /// Creates battery metrics.
  PolyfenceBatteryMetrics({
    required this.isCharging,
    this.batteryLevel,
    required this.totalActiveTime,
  });

  /// Creates battery metrics from a platform channel map.
  factory PolyfenceBatteryMetrics.fromMap(Map<String, dynamic> map) {
    return PolyfenceBatteryMetrics(
      isCharging: map['isCharging'] ?? false,
      batteryLevel: _batteryLevelOrNull(map['batteryLevel']),
      totalActiveTime:
          Duration(milliseconds: (map['totalActiveTime'] as num?)?.toInt() ?? 0),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PolyfenceBatteryMetrics &&
        other.isCharging == isCharging &&
        other.batteryLevel == batteryLevel &&
        other.totalActiveTime == totalActiveTime;
  }

  @override
  int get hashCode => Object.hash(
        isCharging,
        batteryLevel,
        totalActiveTime,
      );

  /// Converts to a map for serialization.
  Map<String, dynamic> toMap() {
    return {
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

  /// Creates zone status.
  PolyfenceZoneStatus({
    required this.activeZones,
    required this.circleZones,
    required this.polygonZones,
  });

  /// Creates zone status from a platform channel map.
  factory PolyfenceZoneStatus.fromMap(Map<String, dynamic> map) {
    return PolyfenceZoneStatus(
      activeZones: (map['activeZones'] as num?)?.toInt() ?? 0,
      circleZones: (map['circleZones'] as num?)?.toInt() ?? 0,
      polygonZones: (map['polygonZones'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PolyfenceZoneStatus &&
        other.activeZones == activeZones &&
        other.circleZones == circleZones &&
        other.polygonZones == polygonZones;
  }

  @override
  int get hashCode => Object.hash(activeZones, circleZones, polygonZones);

  /// Converts to a map for serialization.
  Map<String, dynamic> toMap() {
    return {
      'activeZones': activeZones,
      'circleZones': circleZones,
      'polygonZones': polygonZones,
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
        (map['timestamp'] as num?)?.toInt() ?? 0,
      ),
      correlationId: map['correlationId'],
      context: Map<String, dynamic>.from(map['context'] ?? {}),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PolyfenceErrorSummary &&
        other.type == type &&
        other.message == message &&
        other.timestamp == timestamp &&
        other.correlationId == correlationId &&
        mapEquals(other.context, context);
  }

  @override
  int get hashCode {
    var contextHash = 0;
    final sortedKeys = context.keys.toList()..sort();
    for (final key in sortedKeys) {
      contextHash = Object.hash(contextHash, key, context[key]);
    }
    return Object.hash(type, message, timestamp, correlationId, contextHash);
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
