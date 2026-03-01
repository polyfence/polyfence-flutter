import 'package:flutter_test/flutter_test.dart';
import 'helpers/geofence_algorithms.dart';

/// Reference test vectors for cross-platform parity.
///
/// Each entry defines exact inputs and expected outputs. When implementing
/// Kotlin (JUnit) or Swift (XCTest) tests, copy these test vectors and
/// verify that native implementations produce the same results.
///
/// Tolerance: Haversine distances must agree within ±1 meter across platforms.
/// Ray-casting: boolean results must be identical.
void main() {
  // =========================================================================
  // HAVERSINE REFERENCE VECTORS
  //
  // Format: (lat1, lon1, lat2, lon2) → expected distance in meters
  // Tolerance: ±1 meter
  //
  // Copy these to:
  //   - android/src/test/.../GeofenceEngineTest.kt
  //   - ios/Tests/.../GeofenceEngineTests.swift
  // =========================================================================

  group('Haversine parity vectors', () {
    final haversineVectors = <String, Map<String, dynamic>>{
      'Same point': {
        'lat1': 37.422, 'lon1': -122.084,
        'lat2': 37.422, 'lon2': -122.084,
        'expected': 0.0, 'tolerance': 1.0,
      },
      'SF to LA (~559 km)': {
        'lat1': 37.7749, 'lon1': -122.4194,
        'lat2': 34.0522, 'lon2': -118.2437,
        'expected': 559120.6, 'tolerance': 1.0,
      },
      'NYC to London (~5570 km)': {
        'lat1': 40.7128, 'lon1': -74.0060,
        'lat2': 51.5074, 'lon2': -0.1278,
        'expected': 5570222.5, 'tolerance': 1.0,
      },
      'Tokyo to Sydney (~7826 km)': {
        'lat1': 35.6762, 'lon1': 139.6503,
        'lat2': -33.8688, 'lon2': 151.2093,
        'expected': 7825818.6, 'tolerance': 1.0,
      },
      'North Pole to South Pole': {
        'lat1': 90.0, 'lon1': 0.0,
        'lat2': -90.0, 'lon2': 0.0,
        'expected': 20015086.8, 'tolerance': 1.0,
      },
      'Equator 1 degree longitude': {
        'lat1': 0.0, 'lon1': 0.0,
        'lat2': 0.0, 'lon2': 1.0,
        'expected': 111195.1, 'tolerance': 1.0,
      },
      'Short distance (~141 m)': {
        'lat1': 37.422, 'lon1': -122.084,
        'lat2': 37.423, 'lon2': -122.085,
        'expected': 141.8, 'tolerance': 1.0,
      },
      'Cross date line': {
        'lat1': 0.0, 'lon1': 179.0,
        'lat2': 0.0, 'lon2': -179.0,
        'expected': 222389.9, 'tolerance': 1.0,
      },
      'High latitude (60°N)': {
        'lat1': 60.0, 'lon1': 0.0,
        'lat2': 60.0, 'lon2': 1.0,
        // At 60°N, 1° longitude ≈ 55.8 km (half of equator distance)
        'expected': 55597.5, 'tolerance': 1.0,
      },
      'Very short (~11 m)': {
        'lat1': 37.422, 'lon1': -122.084,
        'lat2': 37.4221, 'lon2': -122.084,
        'expected': 11.1, 'tolerance': 1.0,
      },
    };

    for (final entry in haversineVectors.entries) {
      test(entry.key, () {
        final v = entry.value;
        final distance = GeofenceAlgorithms.haversineDistance(
          v['lat1'] as double,
          v['lon1'] as double,
          v['lat2'] as double,
          v['lon2'] as double,
        );
        expect(
          distance,
          closeTo(v['expected'] as double, v['tolerance'] as double),
          reason: '${entry.key}: expected ${v['expected']}m, got ${distance}m',
        );
      });
    }

    test('Symmetry: distance(A,B) == distance(B,A) for all vectors', () {
      for (final entry in haversineVectors.entries) {
        final v = entry.value;
        final forward = GeofenceAlgorithms.haversineDistance(
          v['lat1'] as double, v['lon1'] as double,
          v['lat2'] as double, v['lon2'] as double,
        );
        final reverse = GeofenceAlgorithms.haversineDistance(
          v['lat2'] as double, v['lon2'] as double,
          v['lat1'] as double, v['lon1'] as double,
        );
        expect(
          forward,
          closeTo(reverse, 0.001),
          reason: '${entry.key}: asymmetric by ${(forward - reverse).abs()}m',
        );
      }
    });
  });

  // =========================================================================
  // RAY-CASTING REFERENCE VECTORS
  //
  // Format: polygon vertices + test point → expected boolean
  //
  // Copy these to native test suites for parity verification.
  // =========================================================================

  group('Ray-casting parity vectors', () {
    // --- Polygon 1: Simple square ---
    final square = [
      {'latitude': 37.0, 'longitude': -122.0},
      {'latitude': 37.0, 'longitude': -121.0},
      {'latitude': 38.0, 'longitude': -121.0},
      {'latitude': 38.0, 'longitude': -122.0},
    ];

    final squareVectors = <String, Map<String, dynamic>>{
      'Center of square → inside': {
        'lat': 37.5, 'lon': -121.5, 'expected': true,
      },
      'South of square → outside': {
        'lat': 36.5, 'lon': -121.5, 'expected': false,
      },
      'North of square → outside': {
        'lat': 38.5, 'lon': -121.5, 'expected': false,
      },
      'East of square → outside': {
        'lat': 37.5, 'lon': -120.5, 'expected': false,
      },
      'West of square → outside': {
        'lat': 37.5, 'lon': -122.5, 'expected': false,
      },
      'Bottom edge (y == min lat) → inside (half-open)': {
        'lat': 37.0, 'lon': -121.5, 'expected': true,
      },
      'Top edge (y == max lat) → outside (half-open)': {
        'lat': 38.0, 'lon': -121.5, 'expected': false,
      },
      'Near bottom-left corner → inside': {
        'lat': 37.001, 'lon': -121.999, 'expected': true,
      },
      'Near top-right corner → inside': {
        'lat': 37.999, 'lon': -121.001, 'expected': true,
      },
    };

    for (final entry in squareVectors.entries) {
      test('Square: ${entry.key}', () {
        final v = entry.value;
        final result = GeofenceAlgorithms.isPointInPolygon(
          v['lat'] as double,
          v['lon'] as double,
          square,
        );
        expect(result, v['expected'] as bool, reason: entry.key);
      });
    }

    // --- Polygon 2: Triangle ---
    final triangle = [
      {'latitude': 37.0, 'longitude': -122.0},
      {'latitude': 38.0, 'longitude': -121.5},
      {'latitude': 37.0, 'longitude': -121.0},
    ];

    final triangleVectors = <String, Map<String, dynamic>>{
      'Centroid → inside': {
        // Centroid of triangle: average of vertices
        'lat': 37.333, 'lon': -121.5, 'expected': true,
      },
      'Above apex → outside': {
        'lat': 38.5, 'lon': -121.5, 'expected': false,
      },
      'Below base → outside': {
        'lat': 36.5, 'lon': -121.5, 'expected': false,
      },
      'Left of triangle → outside': {
        'lat': 37.5, 'lon': -122.5, 'expected': false,
      },
    };

    for (final entry in triangleVectors.entries) {
      test('Triangle: ${entry.key}', () {
        final v = entry.value;
        final result = GeofenceAlgorithms.isPointInPolygon(
          v['lat'] as double,
          v['lon'] as double,
          triangle,
        );
        expect(result, v['expected'] as bool, reason: entry.key);
      });
    }

    // --- Polygon 3: L-shape (concave) ---
    final lShape = [
      {'latitude': 37.0, 'longitude': -122.0},
      {'latitude': 37.0, 'longitude': -121.5},
      {'latitude': 37.5, 'longitude': -121.5},
      {'latitude': 37.5, 'longitude': -121.75},
      {'latitude': 37.25, 'longitude': -121.75},
      {'latitude': 37.25, 'longitude': -122.0},
    ];

    final lShapeVectors = <String, Map<String, dynamic>>{
      'In bottom-left arm → inside': {
        'lat': 37.1, 'lon': -121.9, 'expected': true,
      },
      'In top-right arm → inside': {
        'lat': 37.4, 'lon': -121.6, 'expected': true,
      },
      'In concavity (top-left) → outside': {
        'lat': 37.4, 'lon': -121.9, 'expected': false,
      },
      'Far outside → outside': {
        'lat': 38.0, 'lon': -121.0, 'expected': false,
      },
    };

    for (final entry in lShapeVectors.entries) {
      test('L-shape: ${entry.key}', () {
        final v = entry.value;
        final result = GeofenceAlgorithms.isPointInPolygon(
          v['lat'] as double,
          v['lon'] as double,
          lShape,
        );
        expect(result, v['expected'] as bool, reason: entry.key);
      });
    }

    // --- Polygon 4: Single-vertex degenerate ---
    test('Degenerate: single vertex polygon → always false', () {
      final singlePoint = [
        {'latitude': 37.0, 'longitude': -122.0},
      ];
      expect(
        GeofenceAlgorithms.isPointInPolygon(37.0, -122.0, singlePoint),
        isFalse,
      );
    });

    // --- Polygon 5: Two-vertex degenerate (line) ---
    test('Degenerate: two vertex polygon (line) → always false', () {
      final line = [
        {'latitude': 37.0, 'longitude': -122.0},
        {'latitude': 38.0, 'longitude': -121.0},
      ];
      // Point on the line
      expect(
        GeofenceAlgorithms.isPointInPolygon(37.5, -121.5, line),
        isFalse,
      );
    });
  });
}
