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

  /// Whether coordinates were missing and defaulted to 0.0.
  ///
  /// When `true`, the latitude/longitude values are synthetic (0.0, 0.0)
  /// because the platform failed to provide valid coordinates. Check this
  /// flag to detect and handle invalid location data appropriately.
  final bool isFallback;

  /// Current detected activity type (walking, running, driving, etc).
  ///
  /// Only populated when activity recognition is enabled. Possible values:
  /// - 'still' - Device is stationary
  /// - 'walking' - User is walking
  /// - 'running' - User is running
  /// - 'cycling' - User is cycling
  /// - 'driving' - User is in a vehicle
  /// - 'unknown' - Activity could not be determined
  final String? activity;

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
    this.isFallback = false,
    this.activity,
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
      'isFallback': isFallback,
      'activity': activity,
    };
  }

  factory PolyfenceLocation.fromJson(Map<String, dynamic> json) {
    final num? tsNum = json['timestamp'] as num?;
    final DateTime? ts = tsNum != null
        ? DateTime.fromMillisecondsSinceEpoch(tsNum.round())
        : null;

    final latMissing = json['latitude'] == null;
    final lngMissing = json['longitude'] == null;

    return PolyfenceLocation(
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      altitude: (json['altitude'] as num?)?.toDouble(),
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      timestamp: ts,
      speed: (json['speed'] as num?)?.toDouble(),
      interval: (json['interval'] as num?)?.toInt(),
      isFallback: latMissing || lngMissing || (json['isFallback'] == true),
      activity: json['activity'] as String?,
    );
  }

  @override
  String toString() {
    return 'PolyfenceLocation(lat: $latitude, lng: $longitude)';
  }
}
