class PolyfenceRuntimeStatus {
  final int intervalMs;
  final double nearestZoneDistanceM;
  final DateTime timestamp;

  PolyfenceRuntimeStatus({
    required this.intervalMs,
    required this.nearestZoneDistanceM,
    required this.timestamp,
  });

  factory PolyfenceRuntimeStatus.fromMap(Map<String, dynamic> map) {
    return PolyfenceRuntimeStatus(
      intervalMs: map['intervalMs'] as int? ?? 5000,
      nearestZoneDistanceM:
          (map['nearestZoneDistanceM'] as num?)?.toDouble() ?? double.infinity,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
          map['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch),
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
}




