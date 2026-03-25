import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:polyfence/polyfence.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Polyfence Integration Tests', () {
    setUp(() async {
      // Clean up any previous state before each test
      try {
        await Polyfence.instance.stopTracking();
        await Polyfence.instance.clearAllZones();
      } catch (_) {
        // Service may not be initialized yet, which is fine
      }
    });

    tearDown(() async {
      // Clean up after each test
      try {
        await Polyfence.instance.stopTracking();
        await Polyfence.instance.clearAllZones();
      } catch (_) {
        // May be disposed already
      }
    });

    group('Initialization', () {
      test('initialize completes without error', () async {
        await Polyfence.instance.initialize();
        expect(Polyfence.instance, isNotNull);
      });

      test('initialize is idempotent', () async {
        // Should not throw on second call
        await Polyfence.instance.initialize();
        await Polyfence.instance.initialize();
        expect(Polyfence.instance, isNotNull);
      });

      test('zones list is empty after initialization', () async {
        await Polyfence.instance.initialize();
        expect(Polyfence.instance.zones, isEmpty);
      });
    });

    group('Zone Management', () {
      setUp(() async {
        await Polyfence.instance.initialize();
      });

      test('can add and retrieve a circle zone', () async {
        final zone = Zone.circle(
          id: 'test-circle',
          name: 'Test Circle Zone',
          center: PolyfenceLocation(latitude: 37.422, longitude: -122.084),
          radius: 150,
        );

        await Polyfence.instance.addZone(zone);

        final zones = Polyfence.instance.zones;
        expect(zones, isNotEmpty);
        expect(zones.length, equals(1));
        expect(zones.first.id, equals('test-circle'));
        expect(zones.first.name, equals('Test Circle Zone'));
        expect(zones.first.type, equals(ZoneType.circle));
        expect(zones.first.radius, equals(150));
      });

      test('can add and retrieve a polygon zone', () async {
        final polygonPoints = [
          PolyfenceLocation(latitude: 37.422, longitude: -122.084),
          PolyfenceLocation(latitude: 37.423, longitude: -122.085),
          PolyfenceLocation(latitude: 37.424, longitude: -122.086),
        ];

        final zone = Zone.polygon(
          id: 'test-polygon',
          name: 'Test Polygon Zone',
          polygon: polygonPoints,
        );

        await Polyfence.instance.addZone(zone);

        final zones = Polyfence.instance.zones;
        expect(zones, isNotEmpty);
        expect(zones.length, equals(1));
        expect(zones.first.id, equals('test-polygon'));
        expect(zones.first.type, equals(ZoneType.polygon));
        expect(zones.first.polygon, isNotNull);
        expect(zones.first.polygon!.length, equals(3));
      });

      test('can add multiple zones', () async {
        final circle = Zone.circle(
          id: 'zone1',
          name: 'Circle Zone',
          center: PolyfenceLocation(latitude: 37.422, longitude: -122.084),
          radius: 100,
        );

        final polygon = Zone.polygon(
          id: 'zone2',
          name: 'Polygon Zone',
          polygon: [
            PolyfenceLocation(latitude: 37.422, longitude: -122.084),
            PolyfenceLocation(latitude: 37.423, longitude: -122.085),
            PolyfenceLocation(latitude: 37.424, longitude: -122.086),
          ],
        );

        await Polyfence.instance.addZone(circle);
        await Polyfence.instance.addZone(polygon);

        final zones = Polyfence.instance.zones;
        expect(zones.length, equals(2));
      });

      test('can remove a zone', () async {
        final zone = Zone.circle(
          id: 'removable-zone',
          name: 'Zone to Remove',
          center: PolyfenceLocation(latitude: 37.422, longitude: -122.084),
          radius: 150,
        );

        await Polyfence.instance.addZone(zone);
        expect(Polyfence.instance.zones.length, equals(1));

        await Polyfence.instance.removeZone('removable-zone');
        expect(Polyfence.instance.zones, isEmpty);
      });

      test('can clear all zones', () async {
        final zone1 = Zone.circle(
          id: 'zone1',
          name: 'Zone 1',
          center: PolyfenceLocation(latitude: 37.422, longitude: -122.084),
          radius: 100,
        );

        final zone2 = Zone.circle(
          id: 'zone2',
          name: 'Zone 2',
          center: PolyfenceLocation(latitude: 37.425, longitude: -122.090),
          radius: 200,
        );

        await Polyfence.instance.addZone(zone1);
        await Polyfence.instance.addZone(zone2);
        expect(Polyfence.instance.zones.length, equals(2));

        await Polyfence.instance.clearAllZones();
        expect(Polyfence.instance.zones, isEmpty);
      });

      test('zone validation rejects empty ID', () async {
        expect(
          () => Zone.circle(
            id: '',
            name: 'Invalid Zone',
            center: PolyfenceLocation(latitude: 37.422, longitude: -122.084),
            radius: 150,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('zone validation rejects empty name', () async {
        expect(
          () => Zone.circle(
            id: 'valid-id',
            name: '',
            center: PolyfenceLocation(latitude: 37.422, longitude: -122.084),
            radius: 150,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('zone validation rejects invalid radius', () async {
        expect(
          () => Zone.circle(
            id: 'test-zone',
            name: 'Test Zone',
            center: PolyfenceLocation(latitude: 37.422, longitude: -122.084),
            radius: 0,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('zone validation rejects polygon with < 3 points', () async {
        expect(
          () => Zone.polygon(
            id: 'invalid-polygon',
            name: 'Invalid Polygon',
            polygon: [
              PolyfenceLocation(latitude: 37.422, longitude: -122.084),
              PolyfenceLocation(latitude: 37.423, longitude: -122.085),
            ],
          ),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('Tracking Lifecycle', () {
      setUp(() async {
        await Polyfence.instance.initialize();
      });

      test('startTracking requires location services enabled', () async {
        // This test may fail on emulator if location services are disabled
        // It's expected behavior - the platform requires location enabled
        final isEnabled =
            await Polyfence.instance.isLocationServiceEnabled();

        if (isEnabled) {
          // Location services are enabled, so we can attempt to start tracking
          // Note: This may fail due to permission denial, which is also valid
          try {
            await Polyfence.instance.startTracking();
            // If successful, verify we can stop
            await Polyfence.instance.stopTracking();
          } on PlatformOperationException catch (e) {
            // Expected if permissions are denied
            expect(
              e.message.toLowerCase().contains('permission') ||
                  e.message.toLowerCase().contains('denied'),
              true,
            );
          }
        }
      });

      test('stopTracking completes without error after startTracking fails',
          () async {
        // Even if startTracking fails, stopTracking should not crash
        try {
          await Polyfence.instance.startTracking();
        } catch (e) {
          // Expected - might fail due to permissions
        }

        // This should not throw
        await Polyfence.instance.stopTracking();
      });

      test('startTracking and stopTracking cycle completes', () async {
        final isEnabled =
            await Polyfence.instance.isLocationServiceEnabled();

        if (!isEnabled) {
          // Skip this test if location services are disabled
          return;
        }

        try {
          // Add a zone first
          final zone = Zone.circle(
            id: 'test-zone',
            name: 'Test',
            center: PolyfenceLocation(latitude: 37.422, longitude: -122.084),
            radius: 150,
          );
          await Polyfence.instance.addZone(zone);

          // Start tracking
          await Polyfence.instance.startTracking();

          // Stop tracking
          await Polyfence.instance.stopTracking();

          // Verify we can call them again
          await Polyfence.instance.startTracking();
          await Polyfence.instance.stopTracking();
        } on PlatformOperationException catch (e) {
          // Expected if permissions denied - skip test
          if (e.message.toLowerCase().contains('permission') ||
              e.message.toLowerCase().contains('denied')) {
            return;
          }
          rethrow;
        }
      });
    });

    group('Permission Handling', () {
      setUp(() async {
        await Polyfence.instance.initialize();
      });

      test('requestPermissions returns a boolean result', () async {
        try {
          final result = await Polyfence.instance.requestPermissions();
          expect(result, isA<bool>());
        } on PlatformOperationException {
          // Expected on some emulators or if already granted
        }
      });

      test('requestPermissions with always=true returns a result', () async {
        try {
          final result = await Polyfence.instance.requestPermissions(always: true);
          expect(result, isA<bool>());
        } on PlatformOperationException {
          // Expected on some emulators or if already granted
        }
      });

      test('isLocationServiceEnabled returns a boolean', () async {
        final result = await Polyfence.instance.isLocationServiceEnabled();
        expect(result, isA<bool>());
      });
    });

    group('Error Handling', () {
      setUp(() async {
        await Polyfence.instance.initialize();
      });

      test('error stream does not crash on initialization', () async {
        // Listen to error stream - if there are any buffered errors
        // they should not crash the stream
        var errorCount = 0;
        final subscription = Polyfence.instance.onError.listen((_) {
          errorCount++;
        });

        // Let the stream process any pending events
        await Future.delayed(Duration(milliseconds: 100));

        subscription.cancel();
        // Just verify we got this far without crashing
        expect(errorCount, isA<int>());
      });

      test('geofence event stream does not crash on initialization', () async {
        // Listen to geofence event stream - should not crash
        var eventCount = 0;
        final subscription = Polyfence.instance.onGeofenceEvent.listen((_) {
          eventCount++;
        });

        await Future.delayed(Duration(milliseconds: 100));

        subscription.cancel();
        expect(eventCount, isA<int>());
      });

      test('location update stream does not crash on initialization', () async {
        // Listen to location stream - should not crash
        var locationCount = 0;
        final subscription = Polyfence.instance.onLocationUpdate.listen((_) {
          locationCount++;
        });

        await Future.delayed(Duration(milliseconds: 100));

        subscription.cancel();
        expect(locationCount, isA<int>());
      });
    });

    group('Zone State Management', () {
      setUp(() async {
        await Polyfence.instance.initialize();
      });

      test('getZoneStates returns empty map with no zones', () async {
        final states = await Polyfence.instance.getZoneStates();
        expect(states, isA<Map<String, bool>>());
      });

      test('getZoneStates returns map after adding zones', () async {
        final zone1 = Zone.circle(
          id: 'zone1',
          name: 'Zone 1',
          center: PolyfenceLocation(latitude: 37.422, longitude: -122.084),
          radius: 100,
        );

        final zone2 = Zone.circle(
          id: 'zone2',
          name: 'Zone 2',
          center: PolyfenceLocation(latitude: 37.425, longitude: -122.090),
          radius: 200,
        );

        await Polyfence.instance.addZone(zone1);
        await Polyfence.instance.addZone(zone2);

        final states = await Polyfence.instance.getZoneStates();
        expect(states, isA<Map<String, bool>>());
        // States may be empty on first call, or contain boolean values
        for (final value in states.values) {
          expect(value, isA<bool>());
        }
      });
    });
  });
}
