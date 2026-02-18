/// Runtime status snapshot from the Polyfence plugin.
///
/// Contains the current GPS update interval, distance to the nearest zone,
/// GPS health metrics, and a timestamp. Emitted through [PolyfenceService.runtimeStatus].
class PolyfenceRuntimeStatus {
  /// Current GPS update interval in milliseconds.
  final int intervalMs;

  /// Distance to the nearest monitored zone in meters.
  final double nearestZoneDistanceM;

  /// When this status was captured.
  final DateTime timestamp;

  /// Current GPS accuracy in meters.
  /// Lower values indicate more accurate GPS fixes.
  /// Null if no GPS fix available.
  final double? currentGpsAccuracy;

  /// Seconds since the last valid GPS fix was received.
  /// Increases when GPS signal is lost.
  final int secondsSinceLastGpsFix;

  /// Number of times GPS became unavailable in the last 5 minutes.
  /// Useful for detecting intermittent GPS issues.
  final int gpsAvailabilityDrops5Min;

  /// Creates a runtime status snapshot.
  PolyfenceRuntimeStatus({
    required this.intervalMs,
    required this.nearestZoneDistanceM,
    required this.timestamp,
    this.currentGpsAccuracy,
    required this.secondsSinceLastGpsFix,
    required this.gpsAvailabilityDrops5Min,
  });

  factory PolyfenceRuntimeStatus.fromMap(Map<String, dynamic> map) {
    return PolyfenceRuntimeStatus(
      intervalMs: map['intervalMs'] as int? ?? 5000,
      nearestZoneDistanceM:
          (map['nearestZoneDistanceM'] as num?)?.toDouble() ?? double.infinity,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
          map['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch),
      currentGpsAccuracy: (map['currentGpsAccuracy'] as num?)?.toDouble(),
      secondsSinceLastGpsFix: map['secondsSinceLastGpsFix'] as int? ?? 0,
      gpsAvailabilityDrops5Min: map['gpsAvailabilityDrops5Min'] as int? ?? 0,
    );
  }

  String get intervalDescription => '${intervalMs ~/ 1000}s';

  String get proximityDescription {
    if (nearestZoneDistanceM == double.infinity) {
      return 'No zones';
    } else if (nearestZoneDistanceM < 500) {
      return 'Inside zone (${nearestZoneDistanceM.toStringAsFixed(0)}m)';
    } else if (nearestZoneDistanceM < 5000) {
      return 'Near zone (${nearestZoneDistanceM.toStringAsFixed(0)}m)';
    } else {
      return 'Far from zones (${nearestZoneDistanceM.toStringAsFixed(0)}m)';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PolyfenceRuntimeStatus &&
        other.intervalMs == intervalMs &&
        other.nearestZoneDistanceM == nearestZoneDistanceM &&
        other.timestamp == timestamp &&
        other.currentGpsAccuracy == currentGpsAccuracy &&
        other.secondsSinceLastGpsFix == secondsSinceLastGpsFix &&
        other.gpsAvailabilityDrops5Min == gpsAvailabilityDrops5Min;
  }

  @override
  int get hashCode => Object.hash(
        intervalMs,
        nearestZoneDistanceM,
        timestamp,
        currentGpsAccuracy,
        secondsSinceLastGpsFix,
        gpsAvailabilityDrops5Min,
      );
}
