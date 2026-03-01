import 'dart:math' as math;

/// Dart reference implementations of geofence algorithms.
///
/// These mirror the native implementations in:
///   - `GeofenceEngine.kt` (Android/Kotlin)
///   - `GeofenceEngine.swift` (iOS/Swift)
///
/// Shared across test files to avoid duplication.
/// When modifying, ensure all three platform implementations stay in sync.
class GeofenceAlgorithms {
  static const double earthRadiusMeters = 6371000.0;

  /// Calculate distance between two points using Haversine formula.
  static double haversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  /// Point-in-polygon detection using ray casting algorithm.
  ///
  /// Uses half-open intervals: points on the "bottom" edge (min-lat)
  /// are considered inside; points on the "top" edge (max-lat) are outside.
  /// Points exactly on a vertex are implementation-defined.
  static bool isPointInPolygon(
    double pointLat,
    double pointLon,
    List<Map<String, double>> polygon,
  ) {
    var intersections = 0;
    final x = pointLon;
    final y = pointLat;

    for (int i = 0; i < polygon.length; i++) {
      final p1 = polygon[i];
      final p2 = polygon[(i + 1) % polygon.length];

      final p1Lat = p1['latitude']!;
      final p1Lon = p1['longitude']!;
      final p2Lat = p2['latitude']!;
      final p2Lon = p2['longitude']!;

      if (((p1Lat > y) != (p2Lat > y)) &&
          (x < (p2Lon - p1Lon) * (y - p1Lat) / (p2Lat - p1Lat) + p1Lon)) {
        intersections++;
      }
    }

    return intersections % 2 == 1;
  }

  static double _toRadians(double degrees) {
    return degrees * (math.pi / 180.0);
  }
}
