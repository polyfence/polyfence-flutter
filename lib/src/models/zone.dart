import 'location.dart';

enum ZoneType { circle, polygon }

/// Zone model for geofencing
///
/// **Zone Limits:**
/// - Maximum zones: 50 (iOS), unlimited (Android)
/// - Maximum polygon points: 50 per polygon
/// - Minimum polygon points: 3
///
/// These limits are enforced to ensure optimal performance and memory usage.
class Zone {
  final String id;
  final String name;
  final ZoneType type;
  final PolyfenceLocation? center;
  final double? radius;
  final List<PolyfenceLocation>? polygon;
  final Map<String, dynamic>? metadata;

  Zone({
    required this.id,
    required this.name,
    required this.type,
    this.center,
    this.radius,
    this.polygon,
    this.metadata,
  }) {
    if (id.isEmpty) throw ArgumentError('Zone ID required');
    if (name.isEmpty) throw ArgumentError('Zone name required');
    
    // Validate polygon points
    if (type == ZoneType.polygon && polygon != null) {
      if (polygon!.length < 3) {
        throw ArgumentError('Polygon must have at least 3 points');
      }
      if (polygon!.length > 50) {
        throw ArgumentError('Polygon cannot have more than 50 points');
      }
    }
  }

  /// Creates a circular zone.
  ///
  /// A circular zone is defined by a center point and radius. Entry/exit events
  /// are triggered when the device crosses the circle boundary.
  ///
  /// **Example:**
  /// ```dart
  /// final officeZone = Zone.circle(
  ///   id: 'office',
  ///   name: 'Office Building',
  ///   center: PolyfenceLocation(latitude: 37.422, longitude: -122.084),
  ///   radius: 150, // 150 meters
  /// );
  /// ```
  ///
  /// Throws [ArgumentError] if `id` or `name` is empty.
  factory Zone.circle({
    required String id,
    required String name,
    required PolyfenceLocation center,
    required double radius,
    Map<String, dynamic>? metadata,
  }) {
    return Zone(
      id: id,
      name: name,
      type: ZoneType.circle,
      center: center,
      radius: radius,
      metadata: metadata,
    );
  }

  /// Creates a polygon zone.
  ///
  /// A polygon zone is defined by a list of points forming a closed shape.
  /// Entry/exit events are triggered when the device crosses the polygon boundary.
  /// Uses ray-casting algorithm for point-in-polygon detection.
  ///
  /// **Requirements:**
  /// - Minimum 3 points (forms a triangle)
  /// - Maximum 50 points per polygon
  ///
  /// **Example:**
  /// ```dart
  /// final campusZone = Zone.polygon(
  ///   id: 'campus',
  ///   name: 'University Campus',
  ///   polygon: [
  ///     PolyfenceLocation(latitude: 37.422, longitude: -122.084),
  ///     PolyfenceLocation(latitude: 37.423, longitude: -122.085),
  ///     PolyfenceLocation(latitude: 37.424, longitude: -122.086),
  ///     PolyfenceLocation(latitude: 37.425, longitude: -122.087),
  ///   ],
  /// );
  /// ```
  ///
  /// Throws [ArgumentError] if `id` or `name` is empty, or if polygon has
  /// less than 3 or more than 50 points.
  factory Zone.polygon({
    required String id,
    required String name,
    required List<PolyfenceLocation> polygon,
    Map<String, dynamic>? metadata,
  }) {
    return Zone(
      id: id,
      name: name,
      type: ZoneType.polygon,
      polygon: polygon,
      metadata: metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'center': center?.toJson(),
      'radius': radius,
      'polygon': polygon?.map((p) => p.toJson()).toList(),
      'metadata': metadata,
    };
  }

  factory Zone.fromJson(Map<String, dynamic> json) {
    return Zone(
      id: json['id'],
      name: json['name'],
      type: ZoneType.values.firstWhere((e) => e.name == json['type']),
      center: json['center'] != null 
          ? PolyfenceLocation.fromJson(json['center']) 
          : null,
      radius: json['radius']?.toDouble(),
      polygon: json['polygon'] != null
          ? (json['polygon'] as List)
              .map((p) => PolyfenceLocation.fromJson(p))
              .toList()
          : null,
      metadata: json['metadata'],
    );
  }
}
