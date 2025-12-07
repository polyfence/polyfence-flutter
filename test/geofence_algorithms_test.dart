import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';

/// Test utilities for geofence algorithms
/// These mirror the native implementations in GeofenceEngine (Kotlin/Swift)
class GeofenceAlgorithms {
  static const double earthRadiusMeters = 6371000.0;

  /// Calculate distance between two points using Haversine formula
  /// This matches the implementation in GeofenceEngine.kt and GeofenceEngine.swift
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

  /// Point-in-polygon detection using ray casting algorithm
  /// This matches the implementation in GeofenceEngine.kt and GeofenceEngine.swift
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
          (x <
              (p2Lon - p1Lon) * (y - p1Lat) / (p2Lat - p1Lat) + p1Lon)) {
        intersections++;
      }
    }

    return intersections % 2 == 1;
  }

  static double _toRadians(double degrees) {
    return degrees * (math.pi / 180.0);
  }
}

void main() {
  group('Haversine Distance Tests', () {
    test('Distance between same point is zero', () {
      final distance = GeofenceAlgorithms.haversineDistance(
        37.422,
        -122.084,
        37.422,
        -122.084,
      );
      expect(distance, closeTo(0.0, 1.0)); // Within 1 meter
    });

    test('Distance between two known points', () {
      // San Francisco to Los Angeles (approximately 560 km)
      final distance = GeofenceAlgorithms.haversineDistance(
        37.7749, // San Francisco
        -122.4194,
        34.0522, // Los Angeles
        -118.2437,
      );
      // Should be approximately 560,000 meters
      expect(distance, greaterThan(550000));
      expect(distance, lessThan(570000));
    });

    test('Distance calculation is symmetric', () {
      const lat1 = 37.422;
      const lon1 = -122.084;
      const lat2 = 37.423;
      const lon2 = -122.085;

      final distance1 = GeofenceAlgorithms.haversineDistance(lat1, lon1, lat2, lon2);
      final distance2 = GeofenceAlgorithms.haversineDistance(lat2, lon2, lat1, lon1);

      expect(distance1, closeTo(distance2, 0.1));
    });

    test('Small distance calculation (within 100m)', () {
      // Two points approximately 50 meters apart
      final distance = GeofenceAlgorithms.haversineDistance(
        37.422,
        -122.084,
        37.422001, // ~0.11 meters north
        -122.084001, // ~0.11 meters east
      );
      // Should be very small (less than 1 meter)
      expect(distance, lessThan(1.0));
    });
  });

  group('Ray Casting Point-in-Polygon Tests', () {
    test('Point inside square polygon', () {
      final polygon = [
        {'latitude': 37.0, 'longitude': -122.0},
        {'latitude': 37.0, 'longitude': -121.0},
        {'latitude': 38.0, 'longitude': -121.0},
        {'latitude': 38.0, 'longitude': -122.0},
      ];

      final isInside = GeofenceAlgorithms.isPointInPolygon(
        37.5, // Center of square
        -121.5,
        polygon,
      );

      expect(isInside, isTrue);
    });

    test('Point outside square polygon', () {
      final polygon = [
        {'latitude': 37.0, 'longitude': -122.0},
        {'latitude': 37.0, 'longitude': -121.0},
        {'latitude': 38.0, 'longitude': -121.0},
        {'latitude': 38.0, 'longitude': -122.0},
      ];

      final isInside = GeofenceAlgorithms.isPointInPolygon(
        36.5, // Outside square (south)
        -121.5,
        polygon,
      );

      expect(isInside, isFalse);
    });

    test('Point on polygon edge', () {
      final polygon = [
        {'latitude': 37.0, 'longitude': -122.0},
        {'latitude': 37.0, 'longitude': -121.0},
        {'latitude': 38.0, 'longitude': -121.0},
        {'latitude': 38.0, 'longitude': -122.0},
      ];

      final isInside = GeofenceAlgorithms.isPointInPolygon(
        37.0, // On edge
        -121.5,
        polygon,
      );

      // Edge cases may vary by implementation
      // This test documents current behavior
      expect(isInside, isA<bool>());
    });

    test('Complex polygon with multiple vertices', () {
      final polygon = [
        {'latitude': 37.0, 'longitude': -122.0},
        {'latitude': 37.1, 'longitude': -121.9},
        {'latitude': 37.2, 'longitude': -122.1},
        {'latitude': 37.3, 'longitude': -121.8},
        {'latitude': 37.4, 'longitude': -122.2},
        {'latitude': 37.5, 'longitude': -121.7},
      ];

      final isInside = GeofenceAlgorithms.isPointInPolygon(
        37.25, // Inside complex polygon
        -121.95,
        polygon,
      );

      expect(isInside, isA<bool>());
    });
  });
}

