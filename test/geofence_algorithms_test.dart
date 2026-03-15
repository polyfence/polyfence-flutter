import 'package:flutter_test/flutter_test.dart';
import 'helpers/geofence_algorithms.dart';

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

      final distance1 =
          GeofenceAlgorithms.haversineDistance(lat1, lon1, lat2, lon2);
      final distance2 =
          GeofenceAlgorithms.haversineDistance(lat2, lon2, lat1, lon1);

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

    test('Antipodal points yield half-circumference (~20015 km)', () {
      // North pole to south pole = half Earth circumference
      final distance = GeofenceAlgorithms.haversineDistance(
        90.0,
        0.0,
        -90.0,
        0.0,
      );
      // Half circumference ≈ 20015 km
      expect(distance, closeTo(20015086.8, 100.0));
    });

    test('Points on equator crossing date line', () {
      // (0, 179) to (0, -179) = 2 degrees at equator ≈ 222.4 km
      final distance = GeofenceAlgorithms.haversineDistance(
        0.0,
        179.0,
        0.0,
        -179.0,
      );
      // 2 degrees longitude at equator ≈ 222,389 meters
      expect(distance, closeTo(222389.9, 50.0));
    });

    test('Equator distance matches 1 degree ≈ 111.19 km', () {
      final distance = GeofenceAlgorithms.haversineDistance(
        0.0,
        0.0,
        0.0,
        1.0,
      );
      // 1 degree at equator ≈ 111,195 meters
      expect(distance, closeTo(111195.0, 10.0));
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

    test('Point on bottom edge returns true (half-open interval)', () {
      // Ray-casting uses half-open intervals: a point on the bottom edge
      // (where y == vertex lat) counts as inside because the upward-going
      // adjacent segment satisfies (p1Lat > y) != (p2Lat > y).
      // The horizontal edge itself is skipped (false != false = false).
      final polygon = [
        {'latitude': 37.0, 'longitude': -122.0},
        {'latitude': 37.0, 'longitude': -121.0},
        {'latitude': 38.0, 'longitude': -121.0},
        {'latitude': 38.0, 'longitude': -122.0},
      ];

      final isInside = GeofenceAlgorithms.isPointInPolygon(
        37.0, // On bottom edge
        -121.5,
        polygon,
      );

      expect(isInside, isTrue);
    });

    test('Point on top edge returns false (half-open interval)', () {
      // Counterpart to bottom edge: a point on the top edge is outside
      // because no segment crosses y when all adjacent vertices have y == pointLat.
      final polygon = [
        {'latitude': 37.0, 'longitude': -122.0},
        {'latitude': 37.0, 'longitude': -121.0},
        {'latitude': 38.0, 'longitude': -121.0},
        {'latitude': 38.0, 'longitude': -122.0},
      ];

      final isInside = GeofenceAlgorithms.isPointInPolygon(
        38.0, // On top edge
        -121.5,
        polygon,
      );

      expect(isInside, isFalse);
    });

    test('Point on vertex returns implementation-defined result', () {
      // Point exactly on a vertex is a degenerate case in ray-casting.
      // The result depends on floating-point comparison and edge adjacency.
      // We document the behavior without asserting a specific value.
      final polygon = [
        {'latitude': 37.0, 'longitude': -122.0},
        {'latitude': 37.0, 'longitude': -121.0},
        {'latitude': 38.0, 'longitude': -121.0},
        {'latitude': 38.0, 'longitude': -122.0},
      ];

      // On vertex (37.0, -122.0) — degenerate, just verify no crash
      final result = GeofenceAlgorithms.isPointInPolygon(
        37.0,
        -122.0,
        polygon,
      );
      expect(result, isA<bool>());
    });

    test('Point inside complex zigzag polygon', () {
      // Zigzag polygon going NE. Point (37.15, -121.95) has exactly 1
      // ray intersection (segment 5→0), placing it inside.
      final polygon = [
        {'latitude': 37.0, 'longitude': -122.0},
        {'latitude': 37.1, 'longitude': -121.9},
        {'latitude': 37.2, 'longitude': -122.1},
        {'latitude': 37.3, 'longitude': -121.8},
        {'latitude': 37.4, 'longitude': -122.2},
        {'latitude': 37.5, 'longitude': -121.7},
      ];

      final isInside = GeofenceAlgorithms.isPointInPolygon(
        37.15,
        -121.95,
        polygon,
      );

      expect(isInside, isTrue);
    });

    test('Point outside complex zigzag polygon', () {
      // Point clearly to the east of all polygon vertices
      final polygon = [
        {'latitude': 37.0, 'longitude': -122.0},
        {'latitude': 37.1, 'longitude': -121.9},
        {'latitude': 37.2, 'longitude': -122.1},
        {'latitude': 37.3, 'longitude': -121.8},
        {'latitude': 37.4, 'longitude': -122.2},
        {'latitude': 37.5, 'longitude': -121.7},
      ];

      final isInside = GeofenceAlgorithms.isPointInPolygon(
        37.25,
        -121.5, // East of all vertices
        polygon,
      );

      expect(isInside, isFalse);
    });

    test('Point below complex zigzag polygon', () {
      final polygon = [
        {'latitude': 37.0, 'longitude': -122.0},
        {'latitude': 37.1, 'longitude': -121.9},
        {'latitude': 37.2, 'longitude': -122.1},
        {'latitude': 37.3, 'longitude': -121.8},
        {'latitude': 37.4, 'longitude': -122.2},
        {'latitude': 37.5, 'longitude': -121.7},
      ];

      final isInside = GeofenceAlgorithms.isPointInPolygon(
        36.5, // South of polygon
        -121.95,
        polygon,
      );

      expect(isInside, isFalse);
    });
  });
}
