import 'location.dart';

enum ZoneType { circle, polygon }

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
  }

  /// Create a circular zone
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

  /// Create a polygon zone
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
