import 'package:flutter_test/flutter_test.dart';
import 'package:polyfence/polyfence.dart';

void main() {
  group('Zone Model Tests', () {
    test('Zone.circle creates valid circle zone', () {
      final zone = Zone.circle(
        id: 'test-circle',
        name: 'Test Circle',
        center: PolyfenceLocation(latitude: 37.422, longitude: -122.084),
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
        PolyfenceLocation(latitude: 37.422, longitude: -122.084),
        PolyfenceLocation(latitude: 37.423, longitude: -122.085),
        PolyfenceLocation(latitude: 37.424, longitude: -122.086),
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
        PolyfenceLocation(latitude: 37.422, longitude: -122.084),
        PolyfenceLocation(latitude: 37.423, longitude: -122.085),
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

    test('Zone.polygon accepts large polygons (no upper limit)', () {
      // Large polygons are simplified server-side, so no client-side limit
      final polygon = List.generate(
        1000,
        (i) => PolyfenceLocation(
          latitude: 37.422 + (i * 0.0001),
          longitude: -122.084 + (i * 0.0001),
        ),
      );

      final zone = Zone.polygon(
        id: 'test-polygon',
        name: 'Test Polygon',
        polygon: polygon,
      );

      expect(zone.polygon?.length, 1000);
    });

    test('Zone rejects empty ID', () {
      expect(
        () => Zone.circle(
          id: '',
          name: 'Test',
          center: PolyfenceLocation(latitude: 37.422, longitude: -122.084),
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
          center: PolyfenceLocation(latitude: 37.422, longitude: -122.084),
          radius: 100.0,
        ),
        throwsArgumentError,
      );
    });

    test('Zone.toJson serializes correctly', () {
      final zone = Zone.circle(
        id: 'test-circle',
        name: 'Test Circle',
        center: PolyfenceLocation(latitude: 37.422, longitude: -122.084),
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

  group('PolyfenceLocation Coordinate Validation', () {
    test('accepts valid coordinates', () {
      final loc = PolyfenceLocation(latitude: 37.422, longitude: -122.084);
      expect(loc.latitude, 37.422);
      expect(loc.longitude, -122.084);
    });

    test('accepts boundary latitude values', () {
      final north = PolyfenceLocation(latitude: 90.0, longitude: 0.0);
      expect(north.latitude, 90.0);

      final south = PolyfenceLocation(latitude: -90.0, longitude: 0.0);
      expect(south.latitude, -90.0);
    });

    test('accepts boundary longitude values', () {
      final east = PolyfenceLocation(latitude: 0.0, longitude: 180.0);
      expect(east.longitude, 180.0);

      final west = PolyfenceLocation(latitude: 0.0, longitude: -180.0);
      expect(west.longitude, -180.0);
    });

    test('accepts origin (0, 0)', () {
      final loc = PolyfenceLocation(latitude: 0.0, longitude: 0.0);
      expect(loc.latitude, 0.0);
      expect(loc.longitude, 0.0);
    });

    test('rejects latitude > 90', () {
      expect(
        () => PolyfenceLocation(latitude: 90.001, longitude: 0.0),
        throwsArgumentError,
      );
    });

    test('rejects latitude < -90', () {
      expect(
        () => PolyfenceLocation(latitude: -90.001, longitude: 0.0),
        throwsArgumentError,
      );
    });

    test('rejects latitude far out of range', () {
      expect(
        () => PolyfenceLocation(latitude: 999.0, longitude: 0.0),
        throwsArgumentError,
      );
    });

    test('rejects longitude > 180', () {
      expect(
        () => PolyfenceLocation(latitude: 0.0, longitude: 180.001),
        throwsArgumentError,
      );
    });

    test('rejects longitude < -180', () {
      expect(
        () => PolyfenceLocation(latitude: 0.0, longitude: -180.001),
        throwsArgumentError,
      );
    });

    test('rejects longitude far out of range', () {
      expect(
        () => PolyfenceLocation(latitude: 0.0, longitude: -500.0),
        throwsArgumentError,
      );
    });

    test('rejects both coordinates out of range', () {
      expect(
        () => PolyfenceLocation(latitude: 999.0, longitude: -500.0),
        throwsArgumentError,
      );
    });

    test('skips validation when isFallback is true', () {
      // Platform data recovery path — 0.0/0.0 fallback with isFallback flag
      final loc = PolyfenceLocation(
        latitude: 0.0,
        longitude: 0.0,
        isFallback: true,
      );
      expect(loc.isFallback, isTrue);
    });

    test(
        'fromJson with missing coordinates sets isFallback and skips validation',
        () {
      final loc = PolyfenceLocation.fromJson({});
      expect(loc.latitude, 0.0);
      expect(loc.longitude, 0.0);
      expect(loc.isFallback, isTrue);
    });

    test('fromJson with valid coordinates passes validation', () {
      final loc = PolyfenceLocation.fromJson({
        'latitude': 51.5074,
        'longitude': -0.1278,
      });
      expect(loc.latitude, 51.5074);
      expect(loc.longitude, -0.1278);
      expect(loc.isFallback, isFalse);
    });
  });

  group('Zone Circle Radius Validation', () {
    test('accepts positive radius', () {
      final zone = Zone.circle(
        id: 'test',
        name: 'Test',
        center: PolyfenceLocation(latitude: 37.422, longitude: -122.084),
        radius: 150.0,
      );
      expect(zone.radius, 150.0);
    });

    test('accepts small positive radius', () {
      final zone = Zone.circle(
        id: 'test',
        name: 'Test',
        center: PolyfenceLocation(latitude: 37.422, longitude: -122.084),
        radius: 0.001,
      );
      expect(zone.radius, 0.001);
    });

    test('rejects zero radius', () {
      expect(
        () => Zone.circle(
          id: 'test',
          name: 'Test',
          center: PolyfenceLocation(latitude: 37.422, longitude: -122.084),
          radius: 0.0,
        ),
        throwsArgumentError,
      );
    });

    test('rejects negative radius', () {
      expect(
        () => Zone.circle(
          id: 'test',
          name: 'Test',
          center: PolyfenceLocation(latitude: 37.422, longitude: -122.084),
          radius: -50.0,
        ),
        throwsArgumentError,
      );
    });

    test('rejects invalid center coordinates', () {
      expect(
        () => Zone.circle(
          id: 'test',
          name: 'Test',
          center: PolyfenceLocation(latitude: 999.0, longitude: -122.084),
          radius: 100.0,
        ),
        throwsArgumentError,
      );
    });
  });

  group('Zone Polygon Coordinate Validation', () {
    test('rejects polygon with invalid coordinates', () {
      expect(
        () => Zone.polygon(
          id: 'test',
          name: 'Test',
          polygon: [
            PolyfenceLocation(latitude: 37.422, longitude: -122.084),
            PolyfenceLocation(latitude: 37.423, longitude: -122.085),
            PolyfenceLocation(latitude: 999.0, longitude: -122.086), // invalid
          ],
        ),
        throwsArgumentError,
      );
    });

    test('accepts polygon with valid boundary coordinates', () {
      final zone = Zone.polygon(
        id: 'test',
        name: 'Test',
        polygon: [
          PolyfenceLocation(latitude: 90.0, longitude: -180.0),
          PolyfenceLocation(latitude: -90.0, longitude: 180.0),
          PolyfenceLocation(latitude: 0.0, longitude: 0.0),
        ],
      );
      expect(zone.polygon?.length, 3);
    });
  });
}
