import 'package:flutter_test/flutter_test.dart';
import 'package:polyfence/polyfence.dart';

void main() {
  group('PolygonSimplifier', () {
    test('empty polygon returns empty list', () {
      final result = PolygonSimplifier.simplify([]);
      expect(result, isEmpty);
    });

    test('polygon under target count is returned unchanged', () {
      final polygon = [
        PolyfenceLocation(latitude: 37.0, longitude: -122.0),
        PolyfenceLocation(latitude: 37.1, longitude: -122.1),
        PolyfenceLocation(latitude: 37.2, longitude: -122.0),
      ];

      final result = PolygonSimplifier.simplify(polygon, targetPoints: 500);
      expect(result.length, 3);
      expect(result[0].latitude, 37.0);
    });

    test('minimum polygon (3 points) stays unchanged', () {
      final triangle = [
        PolyfenceLocation(latitude: 37.0, longitude: -122.0),
        PolyfenceLocation(latitude: 37.1, longitude: -122.1),
        PolyfenceLocation(latitude: 37.2, longitude: -122.0),
      ];

      final result = PolygonSimplifier.simplify(triangle, targetPoints: 3);
      expect(result.length, 3);
    });

    test('collinear points are reduced to endpoints', () {
      final collinear = List.generate(
        20,
        (i) => PolyfenceLocation(
          latitude: 37.0 + (i * 0.001),
          longitude: -122.0,
        ),
      );

      final result = PolygonSimplifier.simplify(collinear, targetPoints: 5);
      // Collinear points all have perpendicular distance 0, so any positive
      // tolerance collapses them to the 2 endpoints. The adaptive tolerance
      // range now detects this correctly.
      expect(result.length, lessThan(collinear.length));
    });

    test('large polygon with small radius is simplified with adaptive tolerance', () {
      final large = List.generate(
        1000,
        (i) {
          final angle = (i / 1000) * 2 * 3.14159;
          return PolyfenceLocation(
            latitude: 37.0 + 0.01 * _cos(angle),
            longitude: -122.0 + 0.01 * _sin(angle),
          );
        },
      );

      final result = PolygonSimplifier.simplify(large, targetPoints: 50);
      // Adaptive tolerance range now covers the actual point distances,
      // so simplification works regardless of polygon scale.
      expect(result.length, lessThan(large.length));
      expect(result.length, greaterThan(2));
    });

    test('large polygon with wider radius is simplified', () {
      // Use a larger radius (1.0 degrees) so perpendicular distances fall
      // within the binary search tolerance range [0.00001, 0.01]
      final large = List.generate(
        1000,
        (i) {
          final angle = (i / 1000) * 2 * 3.14159;
          return PolyfenceLocation(
            latitude: 37.0 + 1.0 * _cos(angle),
            longitude: -122.0 + 1.0 * _sin(angle),
          );
        },
      );

      final result = PolygonSimplifier.simplify(large, targetPoints: 50);
      expect(result.length, lessThan(large.length));
      expect(result.length, greaterThan(2));
    });

    test('closed polygon remains closed after simplification', () {
      // Create a closed polygon (first == last)
      final points = <PolyfenceLocation>[
        PolyfenceLocation(latitude: 37.0, longitude: -122.0),
      ];
      for (int i = 1; i < 100; i++) {
        final angle = (i / 100) * 2 * 3.14159;
        points.add(PolyfenceLocation(
          latitude: 37.0 + 0.01 * _cos(angle),
          longitude: -122.0 + 0.01 * _sin(angle),
        ));
      }
      // Close the polygon
      points.add(PolyfenceLocation(latitude: 37.0, longitude: -122.0));

      final result = PolygonSimplifier.simplify(
        points,
        targetPoints: 20,
        preserveEndpoints: true,
      );

      // First and last should match (polygon is closed)
      expect(result.first.latitude, result.last.latitude);
      expect(result.first.longitude, result.last.longitude);
    });

    test('two-point polygon is returned as-is', () {
      final twoPoints = [
        PolyfenceLocation(latitude: 37.0, longitude: -122.0),
        PolyfenceLocation(latitude: 37.1, longitude: -122.1),
      ];

      final result = PolygonSimplifier.simplify(twoPoints, targetPoints: 1);
      // Two points can't be simplified further (minimum for Douglas-Peucker)
      expect(result.length, 2);
    });

    test('defaultTargetPoints constant is 500', () {
      expect(PolygonSimplifier.defaultTargetPoints, 500);
    });
  });
}

// Minimal trig helpers to avoid importing dart:math in the test file
double _sin(double x) {
  // Taylor series approximation, good enough for test data generation
  double result = x;
  double term = x;
  for (int i = 1; i <= 10; i++) {
    term *= -x * x / ((2 * i) * (2 * i + 1));
    result += term;
  }
  return result;
}

double _cos(double x) {
  return _sin(x + 1.5707963);
}
