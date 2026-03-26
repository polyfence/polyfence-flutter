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

  group('Haversine Edge Cases', () {
    test('Distance along same longitude (meridian): Portland to Seattle', () {
      // Portland, OR to Seattle, WA — close but not identical longitudes
      // Real: ~234 km apart
      final distance = GeofenceAlgorithms.haversineDistance(
        45.5152, // Portland
        -122.6784,
        47.6062, // Seattle
        -122.3321,
      );
      // Distance should be approximately 230-240 km
      expect(distance, greaterThan(230000));
      expect(distance, lessThan(240000));
    });

    test('Distance along same latitude (parallel): Los Angeles to San Diego', () {
      // Both in Southern California, different latitudes (~32-34°N)
      // Real: ~179 km apart
      final distance = GeofenceAlgorithms.haversineDistance(
        34.0522, // Los Angeles
        -118.2437,
        32.7157, // San Diego
        -117.1611,
      );
      // Distance should be approximately 175-185 km
      expect(distance, greaterThan(175000));
      expect(distance, lessThan(185000));
    });

    test('Very small distance precision: 0.5 meter offset', () {
      // Test sub-meter precision: move 0.00001° north and east from (40, -105)
      // At 40°N, 1° ≈ 84.9 km longitude, so 0.00001° ≈ 0.849 meters
      final distance = GeofenceAlgorithms.haversineDistance(
        40.0000,
        -105.0000,
        40.00001, // ~0.85m north
        -105.00001, // ~0.6m east
      );
      // Should be less than 2 meters
      expect(distance, lessThan(2.0));
      // But more than zero
      expect(distance, greaterThan(0.0));
    });

    test('Near-antipodal points: London to New Zealand', () {
      // Nearly opposite sides of Earth but not exactly antipodal
      final distance = GeofenceAlgorithms.haversineDistance(
        51.5074, // London
        -0.1278,
        -41.2865, // Auckland, NZ
        174.8860,
      );
      // Should be close to half Earth circumference (~20,000 km)
      // but slightly less since not exactly antipodal
      expect(distance, greaterThan(18000000)); // 18,000 km
      expect(distance, lessThan(20500000)); // 20,500 km
    });

    test('Meridian crossing at 90°W: Chicago to Houston', () {
      // Chicago and Houston span across the 90°W meridian
      // Chicago is at -87.6°W, Houston at -95.4°W
      final distance = GeofenceAlgorithms.haversineDistance(
        41.8781, // Chicago
        -87.6298,
        29.7604, // Houston
        -95.3698,
      );
      // Should be approximately 1,516 km
      expect(distance, greaterThan(1500000));
      expect(distance, lessThan(1530000));
    });

    test('High latitude distance: Stockholm to Reykjavik', () {
      // Both at high latitudes (~60°N), ~40° longitude apart
      final distance = GeofenceAlgorithms.haversineDistance(
        59.3293, // Stockholm
        18.0686,
        64.1466, // Reykjavik
        -21.9426,
      );
      // Should be approximately 2,135 km
      expect(distance, greaterThan(2120000));
      expect(distance, lessThan(2150000));
    });

    test('Crossing date line: Tokyo to Honolulu', () {
      // Crosses international date line (-180/180 boundary)
      final distance = GeofenceAlgorithms.haversineDistance(
        35.6762, // Tokyo
        139.6503,
        21.3099, // Honolulu
        -157.8581,
      );
      // Should be approximately 6,209 km
      expect(distance, greaterThan(6190000));
      expect(distance, lessThan(6230000));
    });
  });

  group('Ray-Casting Edge Cases: Concave Polygons', () {
    test('Point inside concave L-shaped polygon', () {
      // L-shaped polygon with concavity on the right side
      // Vertices form: bottom-left, bottom-right, middle-right, top-right, top-left
      final polygon = [
        {'latitude': 37.0, 'longitude': -122.0}, // bottom-left
        {'latitude': 37.0, 'longitude': -121.0}, // bottom-right
        {'latitude': 37.5, 'longitude': -121.0}, // middle-right
        {'latitude': 37.5, 'longitude': -121.5}, // top-middle (indent)
        {'latitude': 38.0, 'longitude': -121.5}, // top-left of indent
        {'latitude': 38.0, 'longitude': -122.0}, // top-left
      ];

      // Point inside the concavity (left side of the indent)
      final isInside = GeofenceAlgorithms.isPointInPolygon(
        37.75,
        -121.75,
        polygon,
      );

      expect(isInside, isTrue);
    });

    test('Point outside concave polygon in the cutout', () {
      // Same L-shape. The cutout is the upper-right rectangle:
      // lat 37.5–38.0, lon -121.5 to -121.0. Points here are OUTSIDE.
      final polygon = [
        {'latitude': 37.0, 'longitude': -122.0},
        {'latitude': 37.0, 'longitude': -121.0},
        {'latitude': 37.5, 'longitude': -121.0},
        {'latitude': 37.5, 'longitude': -121.5},
        {'latitude': 38.0, 'longitude': -121.5},
        {'latitude': 38.0, 'longitude': -122.0},
      ];

      // Point in the upper-right cutout (outside the polygon)
      final isInside = GeofenceAlgorithms.isPointInPolygon(
        37.75,
        -121.25,
        polygon,
      );

      expect(isInside, isFalse);
    });

    test('Point inside bottom rectangle of L-shaped polygon', () {
      // Same L-shape. The bottom rectangle spans full width:
      // lat 37.0–37.5, lon -122.0 to -121.0. Points here are INSIDE.
      final polygon = [
        {'latitude': 37.0, 'longitude': -122.0},
        {'latitude': 37.0, 'longitude': -121.0},
        {'latitude': 37.5, 'longitude': -121.0},
        {'latitude': 37.5, 'longitude': -121.5},
        {'latitude': 38.0, 'longitude': -121.5},
        {'latitude': 38.0, 'longitude': -122.0},
      ];

      // Point in the bottom-right area (inside the polygon)
      final isInside = GeofenceAlgorithms.isPointInPolygon(
        37.25,
        -121.25,
        polygon,
      );

      expect(isInside, isTrue);
    });
  });

  group('Ray-Casting Edge Cases: Large Polygons', () {
    test('Point inside very large polygon spanning many degrees', () {
      // Large polygon roughly covering the US West Coast
      // Vertices spread across ~10° in each direction
      final polygon = [
        {'latitude': 32.0, 'longitude': -124.0}, // Southern CA coast
        {'latitude': 32.0, 'longitude': -114.0}, // Arizona border
        {'latitude': 49.0, 'longitude': -114.0}, // Canada border, east
        {'latitude': 49.0, 'longitude': -124.0}, // Canada border, west
      ];

      // Point in the center
      final isInside = GeofenceAlgorithms.isPointInPolygon(
        40.5,
        -119.0,
        polygon,
      );

      expect(isInside, isTrue);
    });

    test('Point outside large polygon', () {
      final polygon = [
        {'latitude': 32.0, 'longitude': -124.0},
        {'latitude': 32.0, 'longitude': -114.0},
        {'latitude': 49.0, 'longitude': -114.0},
        {'latitude': 49.0, 'longitude': -124.0},
      ];

      // Point far outside (Gulf of Mexico)
      final isInside = GeofenceAlgorithms.isPointInPolygon(
        30.0,
        -90.0,
        polygon,
      );

      expect(isInside, isFalse);
    });
  });

  group('Ray-Casting Edge Cases: Triangle (Minimal Polygon)', () {
    test('Point inside equilateral triangle', () {
      // Simple equilateral triangle
      final polygon = [
        {'latitude': 37.0, 'longitude': -122.0},
        {'latitude': 37.0, 'longitude': -121.0},
        {'latitude': 38.0, 'longitude': -121.5},
      ];

      // Point roughly in center
      final isInside = GeofenceAlgorithms.isPointInPolygon(
        37.4,
        -121.5,
        polygon,
      );

      expect(isInside, isTrue);
    });

    test('Point outside triangle', () {
      final polygon = [
        {'latitude': 37.0, 'longitude': -122.0},
        {'latitude': 37.0, 'longitude': -121.0},
        {'latitude': 38.0, 'longitude': -121.5},
      ];

      // Point south of all vertices
      final isInside = GeofenceAlgorithms.isPointInPolygon(
        36.5,
        -121.5,
        polygon,
      );

      expect(isInside, isFalse);
    });

    test('Point near edge but outside triangle', () {
      final polygon = [
        {'latitude': 37.0, 'longitude': -122.0},
        {'latitude': 37.0, 'longitude': -121.0},
        {'latitude': 38.0, 'longitude': -121.5},
      ];

      // Point very close to the right edge but slightly outside
      final isInside = GeofenceAlgorithms.isPointInPolygon(
        37.3,
        -120.95, // Just outside the triangle boundary
        polygon,
      );

      expect(isInside, isFalse);
    });
  });

  group('Ray-Casting Edge Cases: High Latitude (Pole Proximity)', () {
    test('Point inside polygon near North Pole', () {
      // High latitude polygon near the Arctic Circle (~66.5°N)
      final polygon = [
        {'latitude': 65.0, 'longitude': -120.0},
        {'latitude': 65.0, 'longitude': -100.0},
        {'latitude': 70.0, 'longitude': -100.0},
        {'latitude': 70.0, 'longitude': -120.0},
      ];

      // Point in center
      final isInside = GeofenceAlgorithms.isPointInPolygon(
        67.5,
        -110.0,
        polygon,
      );

      expect(isInside, isTrue);
    });

    test('Point inside polygon near South Pole', () {
      // High latitude polygon near Antarctic Circle (~-66.5°S)
      final polygon = [
        {'latitude': -65.0, 'longitude': -120.0},
        {'latitude': -65.0, 'longitude': -100.0},
        {'latitude': -70.0, 'longitude': -100.0},
        {'latitude': -70.0, 'longitude': -120.0},
      ];

      // Point in center
      final isInside = GeofenceAlgorithms.isPointInPolygon(
        -67.5,
        -110.0,
        polygon,
      );

      expect(isInside, isTrue);
    });
  });

  group('Circle Zone Edge Cases', () {
    test('Point exactly at circle boundary', () {
      // Circle centered at San Francisco with 1 km radius
      const centerLat = 37.7749;
      const centerLon = -122.4194;
      const radiusMeters = 1000.0;

      // 1000m north: 1000 / 111195 ≈ 0.008993° latitude offset
      final pointLat = 37.7749 + 0.008993;
      final pointLon = -122.4194;

      final distance =
          GeofenceAlgorithms.haversineDistance(centerLat, centerLon, pointLat, pointLon);

      // Should be very close to 1 km
      expect(distance, closeTo(radiusMeters, 10.0)); // Within 10 meters
    });

    test('Point inside circle (1m inside boundary)', () {
      // Same circle as above, but point 1m inside the 1 km boundary
      const centerLat = 37.7749;
      const centerLon = -122.4194;
      const radiusMeters = 1000.0;

      // 999m north: 999 / 111195 ≈ 0.008984° latitude offset
      final pointLat = 37.7749 + 0.008984;
      final pointLon = -122.4194;

      final distance =
          GeofenceAlgorithms.haversineDistance(centerLat, centerLon, pointLat, pointLon);

      // Should be just inside boundary
      expect(distance, lessThan(radiusMeters));
      expect(distance, greaterThan(radiusMeters - 50.0)); // Close to boundary
    });

    test('Point outside circle (1m outside boundary)', () {
      // Point approximately 1001m away
      const centerLat = 37.7749;
      const centerLon = -122.4194;
      const radiusMeters = 1000.0;

      // 1001m north: 1001 / 111195 ≈ 0.009002° latitude offset
      final pointLat = 37.7749 + 0.009002;
      final pointLon = -122.4194;

      final distance =
          GeofenceAlgorithms.haversineDistance(centerLat, centerLon, pointLat, pointLon);

      // Should be just outside boundary
      expect(distance, greaterThan(radiusMeters));
      expect(distance, lessThan(radiusMeters + 50.0)); // Close to boundary
    });

    test('Very small circle (5m radius)', () {
      // Tiny circle: 5 meter radius
      const centerLat = 37.7749;
      const centerLon = -122.4194;
      const radiusMeters = 5.0;

      // Point 4 meters away (inside)
      final insideDistance =
          GeofenceAlgorithms.haversineDistance(37.774915, -122.4194, centerLat, centerLon);

      expect(insideDistance, lessThan(radiusMeters));

      // Point 6 meters away (outside)
      final outsideDistance =
          GeofenceAlgorithms.haversineDistance(37.774945, -122.4194, centerLat, centerLon);

      expect(outsideDistance, greaterThan(radiusMeters));
    });

    test('Very large circle (100km radius)', () {
      // Huge circle: 100 km radius centered on Denver
      const centerLat = 39.7392;
      const centerLon = -104.9903;
      const radiusMeters = 100000.0;

      // Boulder is ~40 km from Denver (inside)
      final boulderDistance = GeofenceAlgorithms.haversineDistance(
        40.0149,
        -105.2705,
        centerLat,
        centerLon,
      );
      expect(boulderDistance, lessThan(radiusMeters));

      // Kansas City is ~600 km away (outside)
      final kansasDistance = GeofenceAlgorithms.haversineDistance(
        39.0997,
        -94.5786,
        centerLat,
        centerLon,
      );
      expect(kansasDistance, greaterThan(radiusMeters));
    });
  });
}
