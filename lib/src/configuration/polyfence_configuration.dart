/// Polyfence GPS Configuration System
/// Provides flexible GPS accuracy/battery profiles for different use cases
library polyfence_configuration;

import '../utils/enum_utils.dart';

/// GPS accuracy profiles that balance precision vs battery consumption
enum PolyfenceAccuracyProfile {
  /// Maximum accuracy - highest precision, highest battery usage
  /// Matches current default behavior
  maxAccuracy,

  /// Balanced accuracy/battery for most use cases
  /// Good compromise between precision and battery life
  balanced,

  /// Prioritizes battery life over precision
  /// Best for background monitoring applications
  batteryOptimal,

  /// Automatically adjusts based on context
  /// Uses proximity, movement, and battery awareness
  adaptive
}

/// GPS update strategies that control when and how often GPS is used
enum PolyfenceUpdateStrategy {
  /// Continuous updates - current behavior
  /// Regular intervals regardless of context
  continuous,

  /// Adjust frequency based on distance to zones
  /// More frequent when near zones, less frequent when far
  proximityBased,

  /// Adjust based on device movement
  /// Less frequent when stationary, more frequent when moving
  movementBased,

  /// Intelligent combination of proximity + movement + battery awareness
  /// Automatically optimizes for best battery life while maintaining accuracy
  intelligent
}

/// Main configuration class for Polyfence GPS behavior
class PolyfenceConfiguration {
  /// GPS accuracy profile
  final PolyfenceAccuracyProfile accuracyProfile;

  /// GPS update strategy
  final PolyfenceUpdateStrategy updateStrategy;

  /// Proximity-based optimization settings
  final ProximitySettings? proximitySettings;

  /// Movement-based optimization settings
  final MovementSettings? movementSettings;

  /// Battery-aware optimization settings
  final BatterySettings? batterySettings;

  /// Dwell detection settings
  final DwellSettings? dwellSettings;

  /// Zone clustering settings for large zone sets
  final ClusterSettings? clusterSettings;

  /// Scheduled tracking settings
  final ScheduleSettings? scheduleSettings;

  /// Activity recognition settings
  final ActivitySettings? activitySettings;

  /// GPS accuracy threshold in meters
  /// Locations with accuracy worse than this are rejected
  /// Default: 100m (ensures platform parity between iOS and Android)
  final double gpsAccuracyThreshold;

  /// Enable debug logging for GPS configuration changes
  final bool enableDebugLogging;

  const PolyfenceConfiguration({
    this.accuracyProfile = PolyfenceAccuracyProfile.maxAccuracy,
    this.updateStrategy = PolyfenceUpdateStrategy.continuous,
    this.proximitySettings,
    this.movementSettings,
    this.batterySettings,
    this.dwellSettings,
    this.clusterSettings,
    this.scheduleSettings,
    this.activitySettings,
    this.gpsAccuracyThreshold = 100.0,
    this.enableDebugLogging = false,
  });

  /// Create a copy with updated values
  PolyfenceConfiguration copyWith({
    PolyfenceAccuracyProfile? accuracyProfile,
    PolyfenceUpdateStrategy? updateStrategy,
    ProximitySettings? proximitySettings,
    MovementSettings? movementSettings,
    BatterySettings? batterySettings,
    DwellSettings? dwellSettings,
    ClusterSettings? clusterSettings,
    ScheduleSettings? scheduleSettings,
    ActivitySettings? activitySettings,
    double? gpsAccuracyThreshold,
    bool? enableDebugLogging,
  }) {
    return PolyfenceConfiguration(
      accuracyProfile: accuracyProfile ?? this.accuracyProfile,
      updateStrategy: updateStrategy ?? this.updateStrategy,
      proximitySettings: proximitySettings ?? this.proximitySettings,
      movementSettings: movementSettings ?? this.movementSettings,
      batterySettings: batterySettings ?? this.batterySettings,
      dwellSettings: dwellSettings ?? this.dwellSettings,
      clusterSettings: clusterSettings ?? this.clusterSettings,
      scheduleSettings: scheduleSettings ?? this.scheduleSettings,
      activitySettings: activitySettings ?? this.activitySettings,
      gpsAccuracyThreshold: gpsAccuracyThreshold ?? this.gpsAccuracyThreshold,
      enableDebugLogging: enableDebugLogging ?? this.enableDebugLogging,
    );
  }

  /// Convert to map for platform communication
  Map<String, dynamic> toMap() {
    final accuracyProfileValue =
        EnumUtils.toChannelFormat(accuracyProfile.name);
    final updateStrategyValue = EnumUtils.toChannelFormat(updateStrategy.name);

    return {
      'accuracyProfile': accuracyProfileValue,
      'updateStrategy': updateStrategyValue,
      'proximitySettings': proximitySettings?.toMap(),
      'movementSettings': movementSettings?.toMap(),
      'batterySettings': batterySettings?.toMap(),
      'dwellSettings': dwellSettings?.toMap(),
      'clusterSettings': clusterSettings?.toMap(),
      'scheduleSettings': scheduleSettings?.toMap(),
      'activitySettings': activitySettings?.toMap(),
      'gpsAccuracyThreshold': gpsAccuracyThreshold,
      'enableDebugLogging': enableDebugLogging,
    };
  }

  /// Create from map (for platform communication)
  factory PolyfenceConfiguration.fromMap(Map<String, dynamic> map) {
    return PolyfenceConfiguration(
      accuracyProfile: EnumUtils.fromChannelFormat(
        map['accuracyProfile'],
        PolyfenceAccuracyProfile.values,
        PolyfenceAccuracyProfile.maxAccuracy,
      ),
      updateStrategy: EnumUtils.fromChannelFormat(
        map['updateStrategy'],
        PolyfenceUpdateStrategy.values,
        PolyfenceUpdateStrategy.continuous,
      ),
      proximitySettings: map['proximitySettings'] != null
          ? ProximitySettings.fromMap(map['proximitySettings'])
          : null,
      movementSettings: map['movementSettings'] != null
          ? MovementSettings.fromMap(map['movementSettings'])
          : null,
      batterySettings: map['batterySettings'] != null
          ? BatterySettings.fromMap(map['batterySettings'])
          : null,
      dwellSettings: map['dwellSettings'] != null
          ? DwellSettings.fromMap(map['dwellSettings'])
          : null,
      clusterSettings: map['clusterSettings'] != null
          ? ClusterSettings.fromMap(map['clusterSettings'])
          : null,
      scheduleSettings: map['scheduleSettings'] != null
          ? ScheduleSettings.fromMap(map['scheduleSettings'])
          : null,
      activitySettings: map['activitySettings'] != null
          ? ActivitySettings.fromMap(map['activitySettings'])
          : null,
      gpsAccuracyThreshold:
          (map['gpsAccuracyThreshold'] as num?)?.toDouble() ?? 100.0,
      enableDebugLogging: map['enableDebugLogging'] ?? false,
    );
  }

  @override
  String toString() {
    return 'PolyfenceConfiguration('
        'accuracyProfile: $accuracyProfile, '
        'updateStrategy: $updateStrategy, '
        'proximitySettings: $proximitySettings, '
        'movementSettings: $movementSettings, '
        'batterySettings: $batterySettings, '
        'dwellSettings: $dwellSettings, '
        'clusterSettings: $clusterSettings, '
        'scheduleSettings: $scheduleSettings, '
        'activitySettings: $activitySettings, '
        'gpsAccuracyThreshold: $gpsAccuracyThreshold, '
        'enableDebugLogging: $enableDebugLogging'
        ')';
  }
}

/// Settings for proximity-based GPS optimization
class ProximitySettings {
  /// Distance in meters considered "near" a zone
  final double nearZoneThresholdMeters;

  /// Distance in meters considered "far" from zones
  final double farZoneThresholdMeters;

  /// GPS update interval when near zones
  final Duration nearZoneUpdateInterval;

  /// GPS update interval when far from zones
  final Duration farZoneUpdateInterval;

  const ProximitySettings({
    this.nearZoneThresholdMeters = 500.0,
    this.farZoneThresholdMeters = 2000.0,
    this.nearZoneUpdateInterval = const Duration(seconds: 5),
    this.farZoneUpdateInterval = const Duration(seconds: 60),
  });

  Map<String, dynamic> toMap() {
    return {
      'nearZoneThresholdMeters': nearZoneThresholdMeters,
      'farZoneThresholdMeters': farZoneThresholdMeters,
      'nearZoneUpdateIntervalMs': nearZoneUpdateInterval.inMilliseconds,
      'farZoneUpdateIntervalMs': farZoneUpdateInterval.inMilliseconds,
    };
  }

  factory ProximitySettings.fromMap(Map<String, dynamic> map) {
    return ProximitySettings(
      nearZoneThresholdMeters:
          map['nearZoneThresholdMeters']?.toDouble() ?? 500.0,
      farZoneThresholdMeters:
          map['farZoneThresholdMeters']?.toDouble() ?? 2000.0,
      nearZoneUpdateInterval: Duration(
        milliseconds: map['nearZoneUpdateIntervalMs']?.toInt() ?? 5000,
      ),
      farZoneUpdateInterval: Duration(
        milliseconds: map['farZoneUpdateIntervalMs']?.toInt() ?? 60000,
      ),
    );
  }

  @override
  String toString() {
    return 'ProximitySettings('
        'nearZoneThresholdMeters: $nearZoneThresholdMeters, '
        'farZoneThresholdMeters: $farZoneThresholdMeters, '
        'nearZoneUpdateInterval: $nearZoneUpdateInterval, '
        'farZoneUpdateInterval: $farZoneUpdateInterval'
        ')';
  }
}

/// Settings for movement-based GPS optimization
class MovementSettings {
  /// Time threshold before device is considered stationary
  final Duration stationaryThreshold;

  /// Distance threshold in meters to be considered moving
  final double movementThresholdMeters;

  /// GPS update interval when device is stationary
  final Duration stationaryUpdateInterval;

  /// GPS update interval when device is moving
  final Duration movingUpdateInterval;

  const MovementSettings({
    this.stationaryThreshold = const Duration(minutes: 5),
    this.movementThresholdMeters = 50.0,
    this.stationaryUpdateInterval = const Duration(minutes: 2),
    this.movingUpdateInterval = const Duration(seconds: 10),
  });

  Map<String, dynamic> toMap() {
    return {
      'stationaryThresholdMs': stationaryThreshold.inMilliseconds,
      'movementThresholdMeters': movementThresholdMeters,
      'stationaryUpdateIntervalMs': stationaryUpdateInterval.inMilliseconds,
      'movingUpdateIntervalMs': movingUpdateInterval.inMilliseconds,
    };
  }

  factory MovementSettings.fromMap(Map<String, dynamic> map) {
    return MovementSettings(
      stationaryThreshold: Duration(
        milliseconds: map['stationaryThresholdMs']?.toInt() ?? 300000,
      ),
      movementThresholdMeters:
          map['movementThresholdMeters']?.toDouble() ?? 50.0,
      stationaryUpdateInterval: Duration(
        milliseconds: map['stationaryUpdateIntervalMs']?.toInt() ?? 120000,
      ),
      movingUpdateInterval: Duration(
        milliseconds: map['movingUpdateIntervalMs']?.toInt() ?? 10000,
      ),
    );
  }

  @override
  String toString() {
    return 'MovementSettings('
        'stationaryThreshold: $stationaryThreshold, '
        'movementThresholdMeters: $movementThresholdMeters, '
        'stationaryUpdateInterval: $stationaryUpdateInterval, '
        'movingUpdateInterval: $movingUpdateInterval'
        ')';
  }
}

/// Settings for dwell time detection
/// Fires DWELL event when device stays inside zone for specified duration
class DwellSettings {
  /// Whether dwell detection is enabled
  final bool enabled;

  /// Duration device must stay inside zone before DWELL event fires
  final Duration dwellThreshold;

  const DwellSettings({
    this.enabled = true,
    this.dwellThreshold = const Duration(minutes: 5),
  });

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'dwellThresholdMs': dwellThreshold.inMilliseconds,
    };
  }

  factory DwellSettings.fromMap(Map<String, dynamic> map) {
    return DwellSettings(
      enabled: map['enabled'] ?? true,
      dwellThreshold: Duration(
        milliseconds: map['dwellThresholdMs']?.toInt() ?? 300000,
      ),
    );
  }

  @override
  String toString() {
    return 'DwellSettings('
        'enabled: $enabled, '
        'dwellThreshold: $dwellThreshold'
        ')';
  }
}

/// Settings for zone clustering optimization
/// Only checks zones within a radius of user's location for better performance
/// with large zone sets (100+ zones)
class ClusterSettings {
  /// Whether zone clustering is enabled
  /// Default: false (all zones checked on every update)
  final bool enabled;

  /// Radius in meters to load/check zones around user's location
  /// Zones outside this radius are stored but not checked
  /// Default: 5000m (5km)
  final double activeRadiusMeters;

  /// Distance in meters user must move before re-evaluating which zones are active
  /// Prevents constant cluster recalculation
  /// Default: 1000m (1km)
  final double refreshDistanceMeters;

  const ClusterSettings({
    this.enabled = false,
    this.activeRadiusMeters = 5000.0,
    this.refreshDistanceMeters = 1000.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'activeRadiusMeters': activeRadiusMeters,
      'refreshDistanceMeters': refreshDistanceMeters,
    };
  }

  factory ClusterSettings.fromMap(Map<String, dynamic> map) {
    return ClusterSettings(
      enabled: map['enabled'] ?? false,
      activeRadiusMeters: map['activeRadiusMeters']?.toDouble() ?? 5000.0,
      refreshDistanceMeters: map['refreshDistanceMeters']?.toDouble() ?? 1000.0,
    );
  }

  @override
  String toString() {
    return 'ClusterSettings('
        'enabled: $enabled, '
        'activeRadiusMeters: $activeRadiusMeters, '
        'refreshDistanceMeters: $refreshDistanceMeters'
        ')';
  }
}

/// Represents a time of day (hour and minute)
/// Used for scheduling tracking windows
class TimeOfDay {
  /// Hour in 24-hour format (0-23)
  final int hour;

  /// Minute (0-59)
  final int minute;

  const TimeOfDay({
    required this.hour,
    required this.minute,
  });

  Map<String, dynamic> toMap() {
    return {
      'hour': hour,
      'minute': minute,
    };
  }

  factory TimeOfDay.fromMap(Map<String, dynamic> map) {
    return TimeOfDay(
      hour: map['hour']?.toInt() ?? 0,
      minute: map['minute']?.toInt() ?? 0,
    );
  }

  @override
  String toString() {
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }
}

/// Represents a time window when tracking should be active
class TimeWindow {
  /// When tracking should start
  final TimeOfDay startTime;

  /// When tracking should stop
  final TimeOfDay endTime;

  /// Days of week when this window applies (1=Monday, 7=Sunday)
  /// Empty list means all days
  final List<int> daysOfWeek;

  const TimeWindow({
    required this.startTime,
    required this.endTime,
    this.daysOfWeek = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'startTime': startTime.toMap(),
      'endTime': endTime.toMap(),
      'daysOfWeek': daysOfWeek,
    };
  }

  factory TimeWindow.fromMap(Map<String, dynamic> map) {
    return TimeWindow(
      startTime: TimeOfDay.fromMap(map['startTime'] ?? {}),
      endTime: TimeOfDay.fromMap(map['endTime'] ?? {}),
      daysOfWeek: (map['daysOfWeek'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
    );
  }

  @override
  String toString() {
    final days = daysOfWeek.isEmpty ? 'all days' : daysOfWeek.join(',');
    return 'TimeWindow($startTime - $endTime on $days)';
  }
}

/// Settings for scheduled tracking
/// Automatically starts/stops tracking based on time windows
class ScheduleSettings {
  /// Whether scheduled tracking is enabled
  /// Default: false (tracking runs continuously when started)
  final bool enabled;

  /// Time windows when tracking should be active
  /// If multiple windows overlap, tracking will be active during any of them
  final List<TimeWindow> timeWindows;

  /// Whether to start tracking immediately if currently within a scheduled window
  /// Default: true
  final bool startImmediatelyIfInWindow;

  const ScheduleSettings({
    this.enabled = false,
    this.timeWindows = const [],
    this.startImmediatelyIfInWindow = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'timeWindows': timeWindows.map((w) => w.toMap()).toList(),
      'startImmediatelyIfInWindow': startImmediatelyIfInWindow,
    };
  }

  factory ScheduleSettings.fromMap(Map<String, dynamic> map) {
    return ScheduleSettings(
      enabled: map['enabled'] ?? false,
      timeWindows: (map['timeWindows'] as List<dynamic>?)
              ?.map((e) => TimeWindow.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      startImmediatelyIfInWindow: map['startImmediatelyIfInWindow'] ?? true,
    );
  }

  @override
  String toString() {
    return 'ScheduleSettings('
        'enabled: $enabled, '
        'timeWindows: $timeWindows, '
        'startImmediatelyIfInWindow: $startImmediatelyIfInWindow'
        ')';
  }
}

/// Activity types detected by the device
enum ActivityType {
  /// Device is stationary
  still,

  /// User is walking
  walking,

  /// User is running
  running,

  /// User is cycling
  cycling,

  /// User is in a vehicle (driving)
  driving,

  /// Activity could not be determined
  unknown,
}

/// Settings for activity-based GPS optimization
/// Uses device motion sensors to detect user activity and adjust GPS intervals
class ActivitySettings {
  /// Whether activity recognition is enabled
  /// Default: false (opt-in, no new permissions requested until enabled)
  final bool enabled;

  /// Minimum confidence (0-100) before acting on detected activity
  /// Higher values reduce false positives but may be less responsive
  /// Default: 75
  final int confidenceThreshold;

  /// Seconds activity must persist before switching GPS mode
  /// Prevents rapid switching at activity transitions
  /// Default: 30
  final int debounceSeconds;

  /// GPS interval when device is still (optional override)
  /// Default: 120 seconds
  final Duration? stillInterval;

  /// GPS interval when walking (optional override)
  /// Default: 15 seconds
  final Duration? walkingInterval;

  /// GPS interval when running (optional override)
  /// Default: 10 seconds
  final Duration? runningInterval;

  /// GPS interval when cycling (optional override)
  /// Default: 8 seconds
  final Duration? cyclingInterval;

  /// GPS interval when driving (optional override)
  /// Default: 5 seconds
  final Duration? drivingInterval;

  const ActivitySettings({
    this.enabled = false,
    this.confidenceThreshold = 75,
    this.debounceSeconds = 30,
    this.stillInterval,
    this.walkingInterval,
    this.runningInterval,
    this.cyclingInterval,
    this.drivingInterval,
  });

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'confidenceThreshold': confidenceThreshold,
      'debounceSeconds': debounceSeconds,
      if (stillInterval != null) 'stillIntervalMs': stillInterval!.inMilliseconds,
      if (walkingInterval != null) 'walkingIntervalMs': walkingInterval!.inMilliseconds,
      if (runningInterval != null) 'runningIntervalMs': runningInterval!.inMilliseconds,
      if (cyclingInterval != null) 'cyclingIntervalMs': cyclingInterval!.inMilliseconds,
      if (drivingInterval != null) 'drivingIntervalMs': drivingInterval!.inMilliseconds,
    };
  }

  factory ActivitySettings.fromMap(Map<String, dynamic> map) {
    return ActivitySettings(
      enabled: map['enabled'] ?? false,
      confidenceThreshold: map['confidenceThreshold']?.toInt() ?? 75,
      debounceSeconds: map['debounceSeconds']?.toInt() ?? 30,
      stillInterval: map['stillIntervalMs'] != null
          ? Duration(milliseconds: map['stillIntervalMs'].toInt())
          : null,
      walkingInterval: map['walkingIntervalMs'] != null
          ? Duration(milliseconds: map['walkingIntervalMs'].toInt())
          : null,
      runningInterval: map['runningIntervalMs'] != null
          ? Duration(milliseconds: map['runningIntervalMs'].toInt())
          : null,
      cyclingInterval: map['cyclingIntervalMs'] != null
          ? Duration(milliseconds: map['cyclingIntervalMs'].toInt())
          : null,
      drivingInterval: map['drivingIntervalMs'] != null
          ? Duration(milliseconds: map['drivingIntervalMs'].toInt())
          : null,
    );
  }

  @override
  String toString() {
    return 'ActivitySettings('
        'enabled: $enabled, '
        'confidenceThreshold: $confidenceThreshold, '
        'debounceSeconds: $debounceSeconds, '
        'stillInterval: $stillInterval, '
        'walkingInterval: $walkingInterval, '
        'runningInterval: $runningInterval, '
        'cyclingInterval: $cyclingInterval, '
        'drivingInterval: $drivingInterval'
        ')';
  }
}

/// Settings for battery-aware GPS optimization
class BatterySettings {
  /// Battery percentage considered "low"
  final int lowBatteryThreshold;

  /// Battery percentage considered "critical"
  final int criticalBatteryThreshold;

  /// GPS update interval when battery is low
  final Duration lowBatteryUpdateInterval;

  /// Whether to pause GPS when battery is critical
  final bool pauseOnCriticalBattery;

  const BatterySettings({
    this.lowBatteryThreshold = 20,
    this.criticalBatteryThreshold = 10,
    this.lowBatteryUpdateInterval = const Duration(seconds: 30),
    this.pauseOnCriticalBattery = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'lowBatteryThreshold': lowBatteryThreshold,
      'criticalBatteryThreshold': criticalBatteryThreshold,
      'lowBatteryUpdateIntervalMs': lowBatteryUpdateInterval.inMilliseconds,
      'pauseOnCriticalBattery': pauseOnCriticalBattery,
    };
  }

  factory BatterySettings.fromMap(Map<String, dynamic> map) {
    return BatterySettings(
      lowBatteryThreshold: map['lowBatteryThreshold']?.toInt() ?? 20,
      criticalBatteryThreshold: map['criticalBatteryThreshold']?.toInt() ?? 10,
      lowBatteryUpdateInterval: Duration(
        milliseconds: map['lowBatteryUpdateIntervalMs']?.toInt() ?? 30000,
      ),
      pauseOnCriticalBattery: map['pauseOnCriticalBattery'] ?? true,
    );
  }

  @override
  String toString() {
    return 'BatterySettings('
        'lowBatteryThreshold: $lowBatteryThreshold, '
        'criticalBatteryThreshold: $criticalBatteryThreshold, '
        'lowBatteryUpdateInterval: $lowBatteryUpdateInterval, '
        'pauseOnCriticalBattery: $pauseOnCriticalBattery'
        ')';
  }
}
