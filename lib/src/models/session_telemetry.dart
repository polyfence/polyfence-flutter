/// Aggregated per-session performance snapshot returned by
/// [PolyfenceService.getSessionTelemetry].
///
/// This is the same payload the plugin sends to the anonymous telemetry
/// endpoint at session end. Field names match the
/// polyfence-react-native `SessionTelemetry` interface so consumers using
/// both bridges see the same public surface.
///
/// The underlying native map uses **snake_case** keys (the wire format).
/// Bridge-added device-context fields (`deviceCategory`, `osVersionMajor`)
/// are camelCase. [raw] preserves the complete map for consumers that
/// need fields not yet exposed as typed getters or future core additions.
///
/// Field-by-field wire reference: [`doc/TELEMETRY.md`](https://github.com/polyfence/polyfence-flutter/blob/main/doc/TELEMETRY.md).
class SessionTelemetry {
  /// Length of the session in minutes.
  final double sessionDurationMinutes;

  /// Average interval between GPS updates during the session, in
  /// milliseconds. `0` when no GPS updates were recorded.
  final int avgGpsIntervalMs;

  /// Number of geofence zones active during the session.
  final int zoneCount;

  /// Count of geofence events that were emitted but did not correspond
  /// to a true zone crossing (e.g. transient GPS jitter).
  final int falseEventCount;

  /// Count of zone entered/exited transitions during the session.
  final int zoneTransitionCount;

  /// Accuracy profile in effect for the session (e.g. `balanced`,
  /// `maxAccuracy`). `null` if no configuration was applied.
  final String? accuracyProfile;

  /// Update strategy in effect for the session (e.g. `continuous`,
  /// `adaptive`). `null` if no configuration was applied.
  final String? updateStrategy;

  /// Device form-factor category assigned by the bridge based on OS
  /// version, chipset class, and battery capacity (e.g. `phone`,
  /// `wearable`, `unknown`).
  final String? deviceCategory;

  /// Which SDK bridge produced this session — `flutter` for
  /// this plugin, `react-native` for the RN wrapper.
  final String? bridgePlatform;

  /// Version of the underlying polyfence-core engine that produced
  /// the metrics.
  final String? coreVersion;

  /// Hour of the day (0-23) when the session started, in the device
  /// local timezone.
  final int sessionStartHour;

  /// Complete unparsed telemetry map from the native layer. Use this
  /// to read fields not exposed as typed getters — for example
  /// `raw['activity_distribution']` or bridge-added
  /// `raw['osVersionMajor']`. Keys are the wire-format snake_case
  /// except where noted.
  final Map<String, dynamic> raw;

  /// Creates a session-telemetry snapshot.
  SessionTelemetry({
    required this.sessionDurationMinutes,
    required this.avgGpsIntervalMs,
    required this.zoneCount,
    required this.falseEventCount,
    required this.zoneTransitionCount,
    required this.accuracyProfile,
    required this.updateStrategy,
    required this.deviceCategory,
    required this.bridgePlatform,
    required this.coreVersion,
    required this.sessionStartHour,
    required this.raw,
  });

  /// Builds a [SessionTelemetry] from a platform-channel map. Reads the
  /// snake_case runtime keys and tolerates missing fields — any typed
  /// field absent from the map defaults to a zero/null value. The
  /// original map is preserved verbatim in [raw].
  factory SessionTelemetry.fromMap(Map<String, dynamic> map) {
    return SessionTelemetry(
      sessionDurationMinutes:
          (map['session_duration_minutes'] as num?)?.toDouble() ?? 0.0,
      avgGpsIntervalMs: (map['avg_gps_interval_ms'] as num?)?.toInt() ?? 0,
      zoneCount: (map['zone_count'] as num?)?.toInt() ?? 0,
      falseEventCount: (map['false_event_count'] as num?)?.toInt() ?? 0,
      zoneTransitionCount:
          (map['zone_transition_count'] as num?)?.toInt() ?? 0,
      accuracyProfile: map['accuracy_profile'] as String?,
      updateStrategy: map['update_strategy'] as String?,
      deviceCategory: (map['device_category'] ?? map['deviceCategory'])
          as String?,
      bridgePlatform: map['bridge_platform'] as String?,
      coreVersion: map['core_version'] as String?,
      sessionStartHour: (map['session_start_hour'] as num?)?.toInt() ?? 0,
      raw: Map<String, dynamic>.from(map),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SessionTelemetry) return false;
    return other.sessionDurationMinutes == sessionDurationMinutes &&
        other.avgGpsIntervalMs == avgGpsIntervalMs &&
        other.zoneCount == zoneCount &&
        other.falseEventCount == falseEventCount &&
        other.zoneTransitionCount == zoneTransitionCount &&
        other.accuracyProfile == accuracyProfile &&
        other.updateStrategy == updateStrategy &&
        other.deviceCategory == deviceCategory &&
        other.bridgePlatform == bridgePlatform &&
        other.coreVersion == coreVersion &&
        other.sessionStartHour == sessionStartHour;
  }

  @override
  int get hashCode => Object.hash(
        sessionDurationMinutes,
        avgGpsIntervalMs,
        zoneCount,
        falseEventCount,
        zoneTransitionCount,
        accuracyProfile,
        updateStrategy,
        deviceCategory,
        bridgePlatform,
        coreVersion,
        sessionStartHour,
      );
}
