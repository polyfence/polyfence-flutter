class PolyfenceDebugInfo {
  final PolyfenceSystemStatus systemStatus;
  final PolyfencePerformanceMetrics performance;
  final PolyfenceBatteryMetrics battery;
  final PolyfenceZoneStatus zones;
  final List<PolyfenceErrorSummary> recentErrors;

  PolyfenceDebugInfo({
    required this.systemStatus,
    required this.performance,
    required this.battery,
    required this.zones,
    required this.recentErrors,
  });

  factory PolyfenceDebugInfo.fromMap(Map<String, dynamic> map) {
    return PolyfenceDebugInfo(
      systemStatus: PolyfenceSystemStatus.fromMap(map['systemStatus']),
      performance: PolyfencePerformanceMetrics.fromMap(map['performance']),
      battery: PolyfenceBatteryMetrics.fromMap(map['battery']),
      zones: PolyfenceZoneStatus.fromMap(map['zones']),
      recentErrors: (map['recentErrors'] as List)
          .map((e) => PolyfenceErrorSummary.fromMap(e))
          .toList(),
    );
  }

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

class PolyfenceSystemStatus {
  final bool isLocationPermissionGranted;
  final bool isBackgroundLocationEnabled;
  final bool isBatteryOptimizationDisabled;
  final bool isGpsEnabled;
  final bool isWakeLockAcquired;
  final double lastKnownAccuracy;
  final DateTime lastLocationUpdate;
  final String platformVersion;
  final String pluginVersion;

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

class PolyfencePerformanceMetrics {
  final Duration uptime;
  final int totalLocationUpdates;
  final int totalZoneDetections;
  final double averageDetectionLatency;
  final int memoryUsageMB;
  final double cpuUsagePercent;
  final int restartCount;

  PolyfencePerformanceMetrics({
    required this.uptime,
    required this.totalLocationUpdates,
    required this.totalZoneDetections,
    required this.averageDetectionLatency,
    required this.memoryUsageMB,
    required this.cpuUsagePercent,
    required this.restartCount,
  });

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

class PolyfenceBatteryMetrics {
  final double estimatedHourlyDrain;
  final int gpsActiveTimePercent;
  final int wakeUpCount;
  final bool isCharging;
  final int batteryLevel;
  final Duration totalActiveTime;

  PolyfenceBatteryMetrics({
    required this.estimatedHourlyDrain,
    required this.gpsActiveTimePercent,
    required this.wakeUpCount,
    required this.isCharging,
    required this.batteryLevel,
    required this.totalActiveTime,
  });

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

class PolyfenceZoneStatus {
  final int activeZones;
  final int circleZones;
  final int polygonZones;
  final DateTime lastZoneUpdate;
  final Map<String, int> zoneEventCounts;

  PolyfenceZoneStatus({
    required this.activeZones,
    required this.circleZones,
    required this.polygonZones,
    required this.lastZoneUpdate,
    required this.zoneEventCounts,
  });

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

class PolyfenceErrorSummary {
  final String type;
  final String message;
  final DateTime timestamp;
  final String? correlationId;
  final Map<String, dynamic> context;

  PolyfenceErrorSummary({
    required this.type,
    required this.message,
    required this.timestamp,
    this.correlationId,
    required this.context,
  });

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
