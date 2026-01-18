import '../models/location.dart';

/// Douglas-Peucker polygon simplification algorithm
/// Reduces polygon complexity while preserving shape accuracy
///
/// Used as a fallback when polygons exceed the plugin limit
class PolygonSimplifier {
  /// Default maximum points for simplified polygons
  static const int defaultTargetPoints = 500;

  /// Calculate perpendicular distance from point to line segment
  static double _perpendicularDistance(
    PolyfenceLocation point,
    PolyfenceLocation lineStart,
    PolyfenceLocation lineEnd,
  ) {
    final dx = lineEnd.longitude - lineStart.longitude;
    final dy = lineEnd.latitude - lineStart.latitude;

    // Normalize
    final mag = _sqrt(dx * dx + dy * dy);
    if (mag == 0) {
      // Line start and end are the same point
      return _sqrt(
        _pow(point.longitude - lineStart.longitude, 2) +
            _pow(point.latitude - lineStart.latitude, 2),
      );
    }

    final u = ((point.longitude - lineStart.longitude) * dx +
            (point.latitude - lineStart.latitude) * dy) /
        (mag * mag);

    PolyfenceLocation closestPoint;
    if (u < 0) {
      closestPoint = lineStart;
    } else if (u > 1) {
      closestPoint = lineEnd;
    } else {
      closestPoint = PolyfenceLocation(
        longitude: lineStart.longitude + u * dx,
        latitude: lineStart.latitude + u * dy,
      );
    }

    return _sqrt(
      _pow(point.longitude - closestPoint.longitude, 2) +
          _pow(point.latitude - closestPoint.latitude, 2),
    );
  }

  static double _sqrt(double x) => x >= 0 ? _fastSqrt(x) : 0;
  static double _pow(double x, int n) => n == 2 ? x * x : x;
  static double _fastSqrt(double x) {
    // Newton-Raphson approximation - good enough for distance comparisons
    if (x == 0) return 0;
    double guess = x / 2;
    for (int i = 0; i < 10; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }

  /// Douglas-Peucker algorithm for polygon simplification
  static List<PolyfenceLocation> _douglasPeucker(
    List<PolyfenceLocation> points,
    double tolerance,
  ) {
    if (points.length <= 2) {
      return points;
    }

    // Find point with maximum distance from line
    double maxDistance = 0;
    int maxIndex = 0;
    final end = points.length - 1;

    for (int i = 1; i < end; i++) {
      final distance = _perpendicularDistance(points[i], points[0], points[end]);
      if (distance > maxDistance) {
        maxDistance = distance;
        maxIndex = i;
      }
    }

    // If max distance is greater than tolerance, recursively simplify
    if (maxDistance > tolerance) {
      final left = _douglasPeucker(points.sublist(0, maxIndex + 1), tolerance);
      final right = _douglasPeucker(points.sublist(maxIndex), tolerance);

      // Combine results (remove duplicate point at junction)
      return [...left.sublist(0, left.length - 1), ...right];
    } else {
      // All points between start and end can be removed
      return [points[0], points[end]];
    }
  }

  /// Calculate optimal tolerance to reach target point count
  /// Uses binary search to find tolerance that gets close to target
  static double _findOptimalTolerance(
    List<PolyfenceLocation> points,
    int targetPoints, {
    double minTolerance = 0.00001,
    double maxTolerance = 0.01,
  }) {
    if (points.length <= targetPoints) {
      return 0; // No simplification needed
    }

    double low = minTolerance;
    double high = maxTolerance;
    double bestTolerance = minTolerance;
    int iterations = 0;
    const maxIterations = 20;

    while (iterations < maxIterations && high - low > 0.000001) {
      final mid = (low + high) / 2;
      final simplified = _douglasPeucker(points, mid);

      if (simplified.length > targetPoints) {
        // Need more simplification
        low = mid;
      } else if (simplified.length < targetPoints * 0.8) {
        // Simplified too much
        high = mid;
      } else {
        // Close enough
        bestTolerance = mid;
        break;
      }

      bestTolerance = mid;
      iterations++;
    }

    return bestTolerance;
  }

  /// Simplify polygon to target point count
  ///
  /// [polygon] Array of PolyfenceLocation points
  /// [targetPoints] Desired number of points (default: 500)
  /// [preserveEndpoints] If true, ensures first/last point preserved (for closed polygons)
  ///
  /// Returns simplified polygon
  ///
  /// Example:
  /// ```dart
  /// // Birmingham CAZ: 2575 points → 500 points
  /// final simplified = PolygonSimplifier.simplify(birminghamCAZ, targetPoints: 500);
  /// ```
  static List<PolyfenceLocation> simplify(
    List<PolyfenceLocation> polygon, {
    int targetPoints = defaultTargetPoints,
    bool preserveEndpoints = true,
  }) {
    if (polygon.isEmpty) {
      return [];
    }

    if (polygon.length <= targetPoints) {
      // Already under target, return as-is
      return polygon;
    }

    // Check if polygon is closed (first point === last point)
    final isClosed = polygon.length > 1 &&
        polygon[0].latitude == polygon[polygon.length - 1].latitude &&
        polygon[0].longitude == polygon[polygon.length - 1].longitude;

    // If closed and we want to preserve endpoints, temporarily remove last point
    final pointsToSimplify = isClosed && preserveEndpoints
        ? polygon.sublist(0, polygon.length - 1)
        : polygon;

    // Find optimal tolerance
    final tolerance = _findOptimalTolerance(
      pointsToSimplify,
      targetPoints - (isClosed ? 1 : 0), // Reserve 1 point for closing if needed
    );

    // Simplify
    var simplified = _douglasPeucker(pointsToSimplify, tolerance);

    // If we over-simplified, use fixed tolerance instead
    if (simplified.length < targetPoints * 0.5) {
      simplified = _douglasPeucker(pointsToSimplify, 0.0001); // ~10m accuracy
    }

    // Re-close polygon if it was originally closed
    if (isClosed && preserveEndpoints) {
      if (simplified[0].latitude != simplified[simplified.length - 1].latitude ||
          simplified[0].longitude != simplified[simplified.length - 1].longitude) {
        simplified.add(simplified[0]);
      }
    }

    return simplified;
  }
}
