import 'package:flutter_test/flutter_test.dart';
import 'package:polyfence/polyfence.dart';

void main() {
  group('Zone Model Tests', () {
    test('Zone.circle creates valid circle zone', () {
      final zone = Zone.circle(
        id: 'test-circle',
        name: 'Test Circle',
        center: const PolyfenceLocation(latitude: 37.422, longitude: -122.084),
        radius: 100.0,
      );

      expect(zone.id, 'test-circle');
      expect(zone.name, 'Test Circle');
      expect(zone.type, ZoneType.circle);
      expect(zone.center?.latitude, 37.422);
      expect(zone.center?.longitude, -122.084);
      expect(zone.radius, 100.0);
      expect(zone.polygon, isNull);
    });

    test('Zone.polygon creates valid polygon zone', () {
      final polygon = [
        const PolyfenceLocation(latitude: 37.422, longitude: -122.084),
        const PolyfenceLocation(latitude: 37.423, longitude: -122.085),
        const PolyfenceLocation(latitude: 37.424, longitude: -122.086),
      ];

      final zone = Zone.polygon(
        id: 'test-polygon',
        name: 'Test Polygon',
        polygon: polygon,
      );

      expect(zone.id, 'test-polygon');
      expect(zone.name, 'Test Polygon');
      expect(zone.type, ZoneType.polygon);
      expect(zone.polygon, polygon);
      expect(zone.center, isNull);
      expect(zone.radius, isNull);
    });

    test('Zone.polygon rejects polygon with less than 3 points', () {
      final polygon = [
        const PolyfenceLocation(latitude: 37.422, longitude: -122.084),
        const PolyfenceLocation(latitude: 37.423, longitude: -122.085),
      ];

      expect(
        () => Zone.polygon(
          id: 'test-polygon',
          name: 'Test Polygon',
          polygon: polygon,
        ),
        throwsArgumentError,
      );
    });

    test('Zone.polygon rejects polygon with more than 50 points', () {
      final polygon = List.generate(
        51,
        (i) => PolyfenceLocation(
          latitude: 37.422 + (i * 0.001),
          longitude: -122.084 + (i * 0.001),
        ),
      );

      expect(
        () => Zone.polygon(
          id: 'test-polygon',
          name: 'Test Polygon',
          polygon: polygon,
        ),
        throwsArgumentError,
      );
    });

    test('Zone.polygon accepts polygon with exactly 50 points', () {
      final polygon = List.generate(
        50,
        (i) => PolyfenceLocation(
          latitude: 37.422 + (i * 0.001),
          longitude: -122.084 + (i * 0.001),
        ),
      );

      final zone = Zone.polygon(
        id: 'test-polygon',
        name: 'Test Polygon',
        polygon: polygon,
      );

      expect(zone.polygon?.length, 50);
    });

    test('Zone rejects empty ID', () {
      expect(
        () => Zone.circle(
          id: '',
          name: 'Test',
          center: const PolyfenceLocation(latitude: 37.422, longitude: -122.084),
          radius: 100.0,
        ),
        throwsArgumentError,
      );
    });

    test('Zone rejects empty name', () {
      expect(
        () => Zone.circle(
          id: 'test',
          name: '',
          center: const PolyfenceLocation(latitude: 37.422, longitude: -122.084),
          radius: 100.0,
        ),
        throwsArgumentError,
      );
    });

    test('Zone.toJson serializes correctly', () {
      final zone = Zone.circle(
        id: 'test-circle',
        name: 'Test Circle',
        center: const PolyfenceLocation(latitude: 37.422, longitude: -122.084),
        radius: 100.0,
      );

      final json = zone.toJson();

      expect(json['id'], 'test-circle');
      expect(json['name'], 'Test Circle');
      expect(json['type'], 'circle');
      expect(json['radius'], 100.0);
      expect(json['center'], isNotNull);
    });

    test('Zone.fromJson deserializes correctly', () {
      final json = {
        'id': 'test-circle',
        'name': 'Test Circle',
        'type': 'circle',
        'center': {
          'latitude': 37.422,
          'longitude': -122.084,
        },
        'radius': 100.0,
      };

      final zone = Zone.fromJson(json);

      expect(zone.id, 'test-circle');
      expect(zone.name, 'Test Circle');
      expect(zone.type, ZoneType.circle);
      expect(zone.radius, 100.0);
    });
  });
}

