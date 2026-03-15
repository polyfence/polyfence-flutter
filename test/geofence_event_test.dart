import 'package:flutter_test/flutter_test.dart';
import 'package:polyfence/polyfence.dart';

void main() {
  group('GeofenceEvent', () {
    final testTimestamp = DateTime(2024, 6, 15, 12, 0, 0);
    final testLocation = PolyfenceLocation(
      latitude: 37.422,
      longitude: -122.084,
      accuracy: 10.0,
    );

    test('creates event with all fields', () {
      final event = GeofenceEvent(
        zoneId: 'zone-1',
        type: GeofenceEventType.enter,
        location: testLocation,
        timestamp: testTimestamp,
      );

      expect(event.zoneId, 'zone-1');
      expect(event.type, GeofenceEventType.enter);
      expect(event.location.latitude, 37.422);
      expect(event.timestamp, testTimestamp);
      expect(event.zone, isNull);
    });

    test('creates event with optional zone', () {
      final zone = Zone.circle(
        id: 'zone-1',
        name: 'Test Zone',
        center: PolyfenceLocation(latitude: 37.422, longitude: -122.084),
        radius: 100.0,
      );

      final event = GeofenceEvent(
        zoneId: 'zone-1',
        type: GeofenceEventType.enter,
        location: testLocation,
        timestamp: testTimestamp,
        zone: zone,
      );

      expect(event.zone, isNotNull);
      expect(event.zone?.name, 'Test Zone');
    });

    test('toJson/fromJson round-trip for enter event', () {
      final event = GeofenceEvent(
        zoneId: 'office',
        type: GeofenceEventType.enter,
        location: testLocation,
        timestamp: testTimestamp,
      );

      final json = event.toJson();
      final restored = GeofenceEvent.fromJson(json);

      expect(restored.zoneId, 'office');
      expect(restored.type, GeofenceEventType.enter);
      expect(restored.location.latitude, 37.422);
      expect(restored.timestamp, testTimestamp);
    });

    test('toJson/fromJson round-trip for exit event', () {
      final event = GeofenceEvent(
        zoneId: 'office',
        type: GeofenceEventType.exit,
        location: testLocation,
        timestamp: testTimestamp,
      );

      final json = event.toJson();
      final restored = GeofenceEvent.fromJson(json);

      expect(restored.type, GeofenceEventType.exit);
    });

    test('toJson/fromJson round-trip for dwell event', () {
      final event = GeofenceEvent(
        zoneId: 'office',
        type: GeofenceEventType.dwell,
        location: testLocation,
        timestamp: testTimestamp,
      );

      final json = event.toJson();
      final restored = GeofenceEvent.fromJson(json);

      expect(restored.type, GeofenceEventType.dwell);
    });

    test('toJson/fromJson round-trip for recoveryEnter event', () {
      final event = GeofenceEvent(
        zoneId: 'office',
        type: GeofenceEventType.recoveryEnter,
        location: testLocation,
        timestamp: testTimestamp,
      );

      final json = event.toJson();
      final restored = GeofenceEvent.fromJson(json);

      expect(restored.type, GeofenceEventType.recoveryEnter);
    });

    test('toJson/fromJson round-trip for recoveryExit event', () {
      final event = GeofenceEvent(
        zoneId: 'office',
        type: GeofenceEventType.recoveryExit,
        location: testLocation,
        timestamp: testTimestamp,
      );

      final json = event.toJson();
      final restored = GeofenceEvent.fromJson(json);

      expect(restored.type, GeofenceEventType.recoveryExit);
    });

    test('fromJson with unknown type defaults to enter', () {
      final json = {
        'zoneId': 'office',
        'type': 'nonexistent_type',
        'location': {'latitude': 37.422, 'longitude': -122.084},
        'timestamp': testTimestamp.millisecondsSinceEpoch,
      };

      final event = GeofenceEvent.fromJson(json);
      expect(event.type, GeofenceEventType.enter);
    });

    test('fromJson with zone included', () {
      final json = {
        'zoneId': 'office',
        'type': 'enter',
        'location': {'latitude': 37.422, 'longitude': -122.084},
        'timestamp': testTimestamp.millisecondsSinceEpoch,
        'zone': {
          'id': 'office',
          'name': 'Office',
          'type': 'circle',
          'center': {'latitude': 37.422, 'longitude': -122.084},
          'radius': 100.0,
        },
      };

      final event = GeofenceEvent.fromJson(json);
      expect(event.zone, isNotNull);
      expect(event.zone?.id, 'office');
      expect(event.zone?.radius, 100.0);
    });

    test('fromJson without zone sets zone to null', () {
      final json = {
        'zoneId': 'office',
        'type': 'exit',
        'location': {'latitude': 37.422, 'longitude': -122.084},
        'timestamp': testTimestamp.millisecondsSinceEpoch,
      };

      final event = GeofenceEvent.fromJson(json);
      expect(event.zone, isNull);
    });

    test('toJson serializes type as name string', () {
      final event = GeofenceEvent(
        zoneId: 'z',
        type: GeofenceEventType.dwell,
        location: testLocation,
        timestamp: testTimestamp,
      );

      final json = event.toJson();
      expect(json['type'], 'dwell');
    });

    test('all GeofenceEventType values exist', () {
      expect(
          GeofenceEventType.values,
          containsAll([
            GeofenceEventType.enter,
            GeofenceEventType.exit,
            GeofenceEventType.dwell,
            GeofenceEventType.recoveryEnter,
            GeofenceEventType.recoveryExit,
          ]));
    });
  });
}
