/// A geographic location with optional metadata.
///
/// Used throughout Polyfence to represent GPS coordinates for zone centers,
/// polygon vertices, and device positions.
///
/// **Example:**
/// ```dart
/// final location = PolyfenceLocation(
///   latitude: 51.5074,
///   longitude: -0.1278,
///   accuracy: 10.0,
/// );
/// ```
class PolyfenceLocation {
  /// Latitude in degrees (-90 to 90).
  final double latitude;

  /// Longitude in degrees (-180 to 180).
  final double longitude;

  /// Altitude in meters above sea level, if available.
  final double? altitude;

  /// Horizontal accuracy in meters. Lower is better.
  ///
  /// Typical values:
  /// - GPS: 3-15m
  /// - Wi-Fi: 15-40m
  /// - Cell: 100-3000m
  final double? accuracy;

  /// When this location was recorded.
  final DateTime? timestamp;

  /// Speed in meters per second, if available.
  final double? speed;

  /// GPS update interval in milliseconds, if applicable.
  final int? interval;

  /// Creates a location with the given coordinates.
  ///
  /// [latitude] and [longitude] are required. All other fields are optional
  /// and typically populated by GPS readings.
  const PolyfenceLocation({
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.accuracy,
    this.timestamp,
    this.speed,
    this.interval,
  });

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'accuracy': accuracy,
      'timestamp': timestamp?.millisecondsSinceEpoch,
      'speed': speed,
      'interval': interval,
    };
  }

  factory PolyfenceLocation.fromJson(Map<String, dynamic> json) {
    final num? tsNum = json['timestamp'] as num?;
    final DateTime? ts = tsNum != null
        ? DateTime.fromMillisecondsSinceEpoch(tsNum.round())
        : null;

    return PolyfenceLocation(
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      altitude: (json['altitude'] as num?)?.toDouble(),
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      timestamp: ts,
      speed: (json['speed'] as num?)?.toDouble(),
      interval: (json['interval'] as num?)?.toInt(),
    );
  }

  @override
  String toString() {
    return 'PolyfenceLocation(lat: $latitude, lng: $longitude)';
  }
}
