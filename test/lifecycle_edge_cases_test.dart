import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:polyfence/polyfence.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mock platform that tracks call order for lifecycle verification.
class MockPolyfencePlatform extends PolyfencePlatform
    with MockPlatformInterfaceMixin {
  final List<String> calls = [];

  final StreamController<PolyfenceLocation> locationController =
      StreamController<PolyfenceLocation>.broadcast();
  final StreamController<Map<String, dynamic>> geofenceController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> errorController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> performanceController =
      StreamController<Map<String, dynamic>>.broadcast();

  bool locationServiceEnabled = true;
  bool permissionsGranted = true;
  PlatformException? errorToThrow;

  @override
  Stream<PolyfenceLocation> get onLocationUpdate => locationController.stream;
  @override
  Stream<Map<String, dynamic>> get onGeofenceEvent => geofenceController.stream;
  @override
  Stream<Map<String, dynamic>> get onError => errorController.stream;
  @override
  Stream<Map<String, dynamic>> get performanceStream =>
      performanceController.stream;

  @override
  Future<void> initialize(
      {String? licenseKey, Map<String, dynamic>? config}) async {
    calls.add('initialize');
    if (errorToThrow != null) throw errorToThrow!;
  }

  @override
  Future<void> addZone(Zone zone) async {
    calls.add('addZone:${zone.id}');
    if (errorToThrow != null) throw errorToThrow!;
  }

  @override
  Future<void> removeZone(String zoneId) async {
    calls.add('removeZone:$zoneId');
    if (errorToThrow != null) throw errorToThrow!;
  }

  @override
  Future<void> clearAllZones() async {
    calls.add('clearAllZones');
    if (errorToThrow != null) throw errorToThrow!;
  }

  @override
  Future<void> startTracking() async {
    calls.add('startTracking');
    if (errorToThrow != null) throw errorToThrow!;
  }

  @override
  Future<void> stopTracking() async {
    calls.add('stopTracking');
    if (errorToThrow != null) throw errorToThrow!;
  }

  @override
  Future<bool> requestPermissions({bool always = false}) async =>
      permissionsGranted;
  @override
  Future<bool> isLocationServiceEnabled() async => locationServiceEnabled;
  @override
  Future<Map<String, dynamic>> checkBatteryOptimization() async =>
      {'isOptimized': false};
  @override
  Future<bool> requestBatteryOptimizationExemption() async => true;
  @override
  Future<Map<String, dynamic>> getConfiguration() async => {};
  @override
  Future<void> updateConfiguration(Map<String, dynamic> config) async {
    calls.add('updateConfiguration');
  }

  @override
  Future<void> resetConfiguration() async {
    calls.add('resetConfiguration');
  }

  @override
  Future<void> setAccuracyProfile(String profile) async {
    calls.add('setAccuracyProfile:$profile');
  }

  @override
  Future<Map<String, dynamic>> getDebugInfo() async => {};
  @override
  Future<List<Map<String, dynamic>>> getErrorHistory(
          Map<String, dynamic> params) async =>
      [];
  @override
  Future<Map<String, bool>> getZoneStates() async => {};
  @override
  Future<Map<String, dynamic>> getSessionTelemetry() async => {};
  @override
  Future<void> dispose() async {
    calls.add('dispose');
    await locationController.close();
    await geofenceController.close();
    await errorController.close();
    await performanceController.close();
  }
}

Zone _makeZone(String id) => Zone.circle(
      id: id,
      name: 'Zone $id',
      center: PolyfenceLocation(latitude: 37.0, longitude: -122.0),
      radius: 100.0,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockPolyfencePlatform mockPlatform;

  setUpAll(() async {
    mockPlatform = MockPolyfencePlatform();
    PolyfencePlatform.instance = mockPlatform;
    SharedPreferences.setMockInitialValues({});

    await PolyfenceService.instance.initialize(
      analyticsConfig: const AnalyticsConfig(disableTelemetry: true),
    );
  });

  // --- Tracking lifecycle ---

  group('Tracking lifecycle — start/stop/restart', () {
    test('start → stop → start again succeeds', () async {
      mockPlatform.calls.clear();

      await PolyfenceService.instance.startTracking();
      expect(mockPlatform.calls, contains('startTracking'));

      mockPlatform.calls.clear();
      await PolyfenceService.instance.stopTracking();
      expect(mockPlatform.calls, contains('stopTracking'));

      mockPlatform.calls.clear();
      await PolyfenceService.instance.startTracking();
      expect(mockPlatform.calls, contains('startTracking'));

      // Clean up
      await PolyfenceService.instance.stopTracking();
    });

    test('stop without start does not throw', () async {
      // Service is initialized but not tracking — stopTracking should
      // call through to platform without error
      mockPlatform.calls.clear();

      await PolyfenceService.instance.stopTracking();
      expect(mockPlatform.calls, contains('stopTracking'));
    });

    test('start when platform throws PlatformException', () async {
      mockPlatform.errorToThrow =
          PlatformException(code: 'GPS_ERROR', message: 'GPS unavailable');

      await expectLater(
        () => PolyfenceService.instance.startTracking(),
        throwsA(isA<PlatformOperationException>()),
      );

      mockPlatform.errorToThrow = null;
    });

    test('streams still emit after stop/restart cycle', () async {
      await PolyfenceService.instance.startTracking();
      await PolyfenceService.instance.stopTracking();
      await PolyfenceService.instance.startTracking();

      // Inject a geofence event — should still flow through
      final events = <GeofenceEvent>[];
      final sub = PolyfenceService.instance.onGeofenceEvent.listen(events.add);

      mockPlatform.geofenceController.add({
        'zoneId': 'test-zone',
        'eventType': 'ENTER',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'latitude': 37.0,
        'longitude': -122.0,
        'accuracy': 10.0,
      });
      await Future.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events.first.zoneId, 'test-zone');

      await sub.cancel();
      await PolyfenceService.instance.stopTracking();
    });
  });

  // --- Zone management lifecycle ---

  group('Zone management — add/remove/clear cycles', () {
    test('add multiple zones then clear then add again', () async {
      mockPlatform.calls.clear();

      await PolyfenceService.instance.addZone(_makeZone('a'));
      await PolyfenceService.instance.addZone(_makeZone('b'));
      await PolyfenceService.instance.addZone(_makeZone('c'));

      expect(PolyfenceService.instance.zones, hasLength(3));

      await PolyfenceService.instance.clearAllZones();
      expect(PolyfenceService.instance.zones, isEmpty);

      // Re-add zones after clear
      await PolyfenceService.instance.addZone(_makeZone('d'));
      expect(PolyfenceService.instance.zones, hasLength(1));
      expect(PolyfenceService.instance.zones.first.id, 'd');

      // Clean up
      await PolyfenceService.instance.clearAllZones();
    });

    test('adding zone with duplicate id replaces cache entry', () async {
      await PolyfenceService.instance.addZone(Zone.circle(
        id: 'dup',
        name: 'Original',
        center: PolyfenceLocation(latitude: 37.0, longitude: -122.0),
        radius: 100.0,
      ));

      await PolyfenceService.instance.addZone(Zone.circle(
        id: 'dup',
        name: 'Replacement',
        center: PolyfenceLocation(latitude: 38.0, longitude: -121.0),
        radius: 200.0,
      ));

      final zones = PolyfenceService.instance.zones;
      final dupZones = zones.where((z) => z.id == 'dup').toList();
      expect(dupZones, hasLength(1));
      expect(dupZones.first.name, 'Replacement');
      expect(dupZones.first.radius, 200.0);

      await PolyfenceService.instance.removeZone('dup');
    });

    test('remove non-existent zone does not throw', () async {
      // Should call through to platform (which is mocked) without error
      mockPlatform.calls.clear();

      await PolyfenceService.instance.removeZone('does-not-exist');
      expect(mockPlatform.calls, contains('removeZone:does-not-exist'));
    });

    test('add zones while tracking', () async {
      await PolyfenceService.instance.startTracking();

      await PolyfenceService.instance.addZone(_makeZone('live-1'));
      await PolyfenceService.instance.addZone(_makeZone('live-2'));

      expect(PolyfenceService.instance.zones.map((z) => z.id),
          containsAll(['live-1', 'live-2']));

      // Events for the live-added zone should still work
      final events = <GeofenceEvent>[];
      final sub = PolyfenceService.instance.onGeofenceEvent.listen(events.add);

      mockPlatform.geofenceController.add({
        'zoneId': 'live-1',
        'eventType': 'ENTER',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'latitude': 37.0,
        'longitude': -122.0,
        'accuracy': 10.0,
      });
      await Future.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events.first.zone, isNotNull);
      expect(events.first.zone!.id, 'live-1');

      await sub.cancel();
      await PolyfenceService.instance.stopTracking();
      await PolyfenceService.instance.clearAllZones();
    });
  });

  // --- Configuration lifecycle ---

  group('Configuration — update/reset cycles', () {
    test('update then reset returns to defaults', () async {
      final custom = PolyfenceConfiguration(
        accuracyProfile: PolyfenceAccuracyProfile.maxAccuracy,
        gpsAccuracyThreshold: 25.0,
      );
      await PolyfenceService.instance.updateConfiguration(custom);

      expect(
        PolyfenceService.instance.currentConfiguration.accuracyProfile,
        PolyfenceAccuracyProfile.maxAccuracy,
      );

      await PolyfenceService.instance.resetConfiguration();

      expect(
        PolyfenceService.instance.currentConfiguration.accuracyProfile,
        PolyfenceAccuracyProfile.balanced,
      );
    });

    test('setAccuracyProfile updates cached configuration', () async {
      await PolyfenceService.instance
          .setAccuracyProfile(PolyfenceAccuracyProfile.batteryOptimal);

      expect(
        PolyfenceService.instance.currentConfiguration.accuracyProfile,
        PolyfenceAccuracyProfile.batteryOptimal,
      );

      // Reset for other tests
      await PolyfenceService.instance.resetConfiguration();
    });
  });

  // --- Second initialize is no-op ---

  group('Initialization — idempotency', () {
    test('second initialize call is no-op', () async {
      final callsBefore = mockPlatform.calls.length;

      await PolyfenceService.instance.initialize();

      // No new platform calls — already initialized
      expect(mockPlatform.calls.length, callsBefore);
    });
  });

  // --- Dispose tests MUST be last ---

  group('Dispose — finality', () {
    test('dispose calls platform dispose', () async {
      mockPlatform.calls.clear();

      await PolyfenceService.instance.dispose();

      expect(mockPlatform.calls, contains('dispose'));
    });

    test('all methods throw StateError after dispose', () {
      expect(
        () => PolyfenceService.instance.initialize(),
        throwsA(isA<StateError>()),
      );
      expect(
        () => PolyfenceService.instance.addZone(_makeZone('z')),
        throwsA(isA<StateError>()),
      );
      expect(
        () => PolyfenceService.instance.removeZone('z'),
        throwsA(isA<StateError>()),
      );
      expect(
        () => PolyfenceService.instance.startTracking(),
        throwsA(isA<StateError>()),
      );
      expect(
        () => PolyfenceService.instance.stopTracking(),
        throwsA(isA<StateError>()),
      );
    });

    test('double dispose is no-op', () async {
      // Should not throw
      await PolyfenceService.instance.dispose();
    });
  });
}
