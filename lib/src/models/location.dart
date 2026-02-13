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
  /// [latitude] must be between -90 and 90 (inclusive).
  /// [longitude] must be between -180 and 180 (inclusive).
  ///
  /// Throws [ArgumentError] if coordinates are out of bounds, unless
  /// [isFallback] is `true` (used internally for platform data recovery
  /// when coordinates are unavailable).
  ///
  /// **Note:** This constructor is intentionally non-const to enforce
  /// coordinate validation at runtime in all build modes. Debug-only
  /// assertions would silently pass invalid coordinates in release builds,
  /// causing corrupt geofence math (haversine, ray-casting) with no error.
  PolyfenceLocation({
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.accuracy,
    this.timestamp,
    this.speed,
    this.interval,
    this.isFallback = false,
    this.activity,
  }) {
    if (!isFallback) {
      if (latitude < -90 || latitude > 90) {
        throw ArgumentError.value(
          latitude,
          'latitude',
          'Must be between -90 and 90, got $latitude',
        );
      }
      if (longitude < -180 || longitude > 180) {
        throw ArgumentError.value(
          longitude,
          'longitude',
          'Must be between -180 and 180, got $longitude',
        );
      }
    }
  }

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
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PolyfenceLocation &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.altitude == altitude &&
        other.accuracy == accuracy &&
        other.timestamp == timestamp &&
        other.speed == speed &&
        other.interval == interval &&
        other.isFallback == isFallback &&
        other.activity == activity;
  }

  @override
  int get hashCode => Object.hash(
        latitude,
        longitude,
        altitude,
        accuracy,
        timestamp,
        speed,
        interval,
        isFallback,
        activity,
      );

  @override
  String toString() {
    return 'PolyfenceLocation(lat: $latitude, lng: $longitude)';
  }
}
