import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:polyfence/polyfence.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mock platform that exposes stream controllers for injecting events.
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
      {String? licenseKey, PolyfenceConfiguration? config}) async {
    calls.add('initialize');
  }

  @override
  Future<void> addZone(Zone zone) async => calls.add('addZone');
  @override
  Future<void> removeZone(String zoneId) async => calls.add('removeZone');
  @override
  Future<void> clearAllZones() async => calls.add('clearAllZones');
  @override
  Future<void> startTracking() async => calls.add('startTracking');
  @override
  Future<void> stopTracking() async => calls.add('stopTracking');
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
  Future<void> updateConfiguration(Map<String, dynamic> config) async {}
  @override
  Future<void> resetConfiguration() async {}
  @override
  Future<void> setAccuracyProfile(String profile) async {}
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
    await locationController.close();
    await geofenceController.close();
    await errorController.close();
    await performanceController.close();
  }
}

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

  // Helper: fixed timestamp for deterministic tests
  final fixedTimestamp = DateTime(2025, 6, 15, 12, 0, 0).millisecondsSinceEpoch;

  /// Builds a valid geofence event map with all required fields.
  Map<String, dynamic> validEvent({
    String zoneId = 'zone-1',
    String eventType = 'ENTER',
    int? timestamp,
    double latitude = 37.422,
    double longitude = -122.084,
    double accuracy = 10.0,
    double detectionTimeMs = 45.0,
    double gpsAccuracy = 10.0,
  }) {
    return {
      'zoneId': zoneId,
      'eventType': eventType,
      'timestamp': timestamp ?? fixedTimestamp,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'detectionTimeMs': detectionTimeMs,
      'gpsAccuracy': gpsAccuracy,
    };
  }

  group('_handleGeofenceEvent — valid events', () {
    test('ENTER event emits GeofenceEvent with correct type', () async {
      final events = <GeofenceEvent>[];
      final sub = PolyfenceService.instance.onGeofenceEvent.listen(events.add);

      mockPlatform.geofenceController.add(validEvent(eventType: 'ENTER'));
      await Future.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events.first.type, GeofenceEventType.enter);
      expect(events.first.zoneId, 'zone-1');
      expect(events.first.location.latitude, 37.422);
      expect(events.first.location.longitude, -122.084);
      expect(events.first.location.accuracy, 10.0);

      await sub.cancel();
    });

    test('EXIT event emits correct type', () async {
      final events = <GeofenceEvent>[];
      final sub = PolyfenceService.instance.onGeofenceEvent.listen(events.add);

      mockPlatform.geofenceController.add(validEvent(eventType: 'EXIT'));
      await Future.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events.first.type, GeofenceEventType.exit);

      await sub.cancel();
    });

    test('DWELL event emits correct type', () async {
      final events = <GeofenceEvent>[];
      final sub = PolyfenceService.instance.onGeofenceEvent.listen(events.add);

      mockPlatform.geofenceController.add(validEvent(eventType: 'DWELL'));
      await Future.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events.first.type, GeofenceEventType.dwell);

      await sub.cancel();
    });

    test('RECOVERY_ENTER event emits correct type', () async {
      final events = <GeofenceEvent>[];
      final sub = PolyfenceService.instance.onGeofenceEvent.listen(events.add);

      mockPlatform.geofenceController
          .add(validEvent(eventType: 'RECOVERY_ENTER'));
      await Future.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events.first.type, GeofenceEventType.recoveryEnter);

      await sub.cancel();
    });

    test('RECOVERY_EXIT event emits correct type', () async {
      final events = <GeofenceEvent>[];
      final sub = PolyfenceService.instance.onGeofenceEvent.listen(events.add);

      mockPlatform.geofenceController
          .add(validEvent(eventType: 'RECOVERY_EXIT'));
      await Future.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events.first.type, GeofenceEventType.recoveryExit);

      await sub.cancel();
    });

    test('lowercase eventType is handled (uppercased internally)', () async {
      final events = <GeofenceEvent>[];
      final sub = PolyfenceService.instance.onGeofenceEvent.listen(events.add);

      mockPlatform.geofenceController.add(validEvent(eventType: 'enter'));
      await Future.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events.first.type, GeofenceEventType.enter);

      await sub.cancel();
    });

    test('mixed case eventType is handled', () async {
      final events = <GeofenceEvent>[];
      final sub = PolyfenceService.instance.onGeofenceEvent.listen(events.add);

      mockPlatform.geofenceController.add(validEvent(eventType: 'Exit'));
      await Future.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events.first.type, GeofenceEventType.exit);

      await sub.cancel();
    });

    test('int timestamp is used directly', () async {
      final events = <GeofenceEvent>[];
      final sub = PolyfenceService.instance.onGeofenceEvent.listen(events.add);

      mockPlatform.geofenceController
          .add(validEvent(timestamp: fixedTimestamp));
      await Future.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(
        events.first.timestamp,
        DateTime.fromMillisecondsSinceEpoch(fixedTimestamp),
      );

      await sub.cancel();
    });

    test('double timestamp (iOS) is converted to int', () async {
      final events = <GeofenceEvent>[];
      final errors = <PolyfenceError>[];
      final eventSub =
          PolyfenceService.instance.onGeofenceEvent.listen(events.add);
      final errorSub = PolyfenceService.instance.onError.listen(errors.add);

      // iOS sends TimeInterval as double
      final event = validEvent();
      event['timestamp'] = fixedTimestamp.toDouble();

      mockPlatform.geofenceController.add(event);
      await Future.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(
        events.first.timestamp,
        DateTime.fromMillisecondsSinceEpoch(fixedTimestamp),
      );
      // No error should be emitted for a valid double timestamp
      final timestampErrors =
          errors.where((e) => e.message.contains('timestamp')).toList();
      expect(timestampErrors, isEmpty);

      await eventSub.cancel();
      await errorSub.cancel();
    });
  });

  group('_handleGeofenceEvent — zone cache lookup', () {
    test('event.zone is populated when zone is in cache', () async {
      // Add a zone so it's in the cache
      final zone = Zone.circle(
        id: 'cached-zone',
        name: 'Cached Zone',
        center: PolyfenceLocation(latitude: 37.0, longitude: -122.0),
        radius: 100.0,
      );
      await PolyfenceService.instance.addZone(zone);

      final events = <GeofenceEvent>[];
      final sub = PolyfenceService.instance.onGeofenceEvent.listen(events.add);

      mockPlatform.geofenceController.add(validEvent(zoneId: 'cached-zone'));
      await Future.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events.first.zone, isNotNull);
      expect(events.first.zone!.id, 'cached-zone');
      expect(events.first.zone!.name, 'Cached Zone');

      await sub.cancel();
      await PolyfenceService.instance.removeZone('cached-zone');
    });

    test('event.zone is null when zone is not in cache', () async {
      final events = <GeofenceEvent>[];
      final sub = PolyfenceService.instance.onGeofenceEvent.listen(events.add);

      mockPlatform.geofenceController.add(validEvent(zoneId: 'unknown-zone'));
      await Future.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events.first.zone, isNull);
      expect(events.first.zoneId, 'unknown-zone');

      await sub.cancel();
    });
  });

  group('_handleGeofenceEvent — missing required fields', () {
    test('missing zoneId emits error, no event', () async {
      final events = <GeofenceEvent>[];
      final errors = <PolyfenceError>[];
      final eventSub =
          PolyfenceService.instance.onGeofenceEvent.listen(events.add);
      final errorSub = PolyfenceService.instance.onError.listen(errors.add);

      mockPlatform.geofenceController.add({
        'eventType': 'ENTER',
        'timestamp': fixedTimestamp,
        'latitude': 37.0,
        'longitude': -122.0,
      });
      await Future.delayed(Duration.zero);

      expect(events, isEmpty);
      expect(errors, hasLength(1));
      expect(errors.first.message, contains('Missing required fields'));

      await eventSub.cancel();
      await errorSub.cancel();
    });

    test('missing eventType emits error, no event', () async {
      final events = <GeofenceEvent>[];
      final errors = <PolyfenceError>[];
      final eventSub =
          PolyfenceService.instance.onGeofenceEvent.listen(events.add);
      final errorSub = PolyfenceService.instance.onError.listen(errors.add);

      mockPlatform.geofenceController.add({
        'zoneId': 'zone-1',
        'timestamp': fixedTimestamp,
        'latitude': 37.0,
        'longitude': -122.0,
      });
      await Future.delayed(Duration.zero);

      expect(events, isEmpty);
      expect(errors, hasLength(1));
      expect(errors.first.message, contains('Missing required fields'));

      await eventSub.cancel();
      await errorSub.cancel();
    });

    test('null zoneId and null eventType emits single error', () async {
      final events = <GeofenceEvent>[];
      final errors = <PolyfenceError>[];
      final eventSub =
          PolyfenceService.instance.onGeofenceEvent.listen(events.add);
      final errorSub = PolyfenceService.instance.onError.listen(errors.add);

      mockPlatform.geofenceController.add({
        'zoneId': null,
        'eventType': null,
        'timestamp': fixedTimestamp,
      });
      await Future.delayed(Duration.zero);

      expect(events, isEmpty);
      expect(errors, hasLength(1));
      expect(errors.first.message, contains('Missing required fields'));

      await eventSub.cancel();
      await errorSub.cancel();
    });
  });

  group('_handleGeofenceEvent — unknown eventType', () {
    test('unknown eventType emits error, no event', () async {
      final events = <GeofenceEvent>[];
      final errors = <PolyfenceError>[];
      final eventSub =
          PolyfenceService.instance.onGeofenceEvent.listen(events.add);
      final errorSub = PolyfenceService.instance.onError.listen(errors.add);

      mockPlatform.geofenceController.add(validEvent(eventType: 'HOVER'));
      await Future.delayed(Duration.zero);

      expect(events, isEmpty);
      expect(errors, hasLength(1));
      expect(errors.first.message, contains('Unknown geofence eventType'));
      expect(errors.first.message, contains('HOVER'));

      await eventSub.cancel();
      await errorSub.cancel();
    });

    test('empty string eventType emits error', () async {
      final events = <GeofenceEvent>[];
      final errors = <PolyfenceError>[];
      final eventSub =
          PolyfenceService.instance.onGeofenceEvent.listen(events.add);
      final errorSub = PolyfenceService.instance.onError.listen(errors.add);

      mockPlatform.geofenceController.add(validEvent(eventType: ''));
      await Future.delayed(Duration.zero);

      expect(events, isEmpty);
      // Empty string uppercased is still empty → unknown type
      expect(errors, hasLength(1));
      expect(errors.first.message, contains('Unknown geofence eventType'));

      await eventSub.cancel();
      await errorSub.cancel();
    });
  });

  group('_handleGeofenceEvent — invalid timestamp', () {
    test('string timestamp emits error and uses fallback', () async {
      final events = <GeofenceEvent>[];
      final errors = <PolyfenceError>[];
      final eventSub =
          PolyfenceService.instance.onGeofenceEvent.listen(events.add);
      final errorSub = PolyfenceService.instance.onError.listen(errors.add);

      final event = validEvent();
      event['timestamp'] = '2025-06-15'; // Invalid type

      mockPlatform.geofenceController.add(event);
      await Future.delayed(Duration.zero);

      // Event should still be emitted (with fallback timestamp)
      expect(events, hasLength(1));
      // Error about invalid timestamp should be emitted
      final timestampErrors =
          errors.where((e) => e.message.contains('Invalid timestamp')).toList();
      expect(timestampErrors, hasLength(1));
      expect(timestampErrors.first.message, contains('String'));

      await eventSub.cancel();
      await errorSub.cancel();
    });

    test('null timestamp emits error and uses fallback', () async {
      final events = <GeofenceEvent>[];
      final errors = <PolyfenceError>[];
      final eventSub =
          PolyfenceService.instance.onGeofenceEvent.listen(events.add);
      final errorSub = PolyfenceService.instance.onError.listen(errors.add);

      final event = validEvent();
      event['timestamp'] = null;

      mockPlatform.geofenceController.add(event);
      await Future.delayed(Duration.zero);

      expect(events, hasLength(1));
      final timestampErrors =
          errors.where((e) => e.message.contains('Invalid timestamp')).toList();
      expect(timestampErrors, hasLength(1));

      await eventSub.cancel();
      await errorSub.cancel();
    });
  });

  group('_handleGeofenceEvent — missing coordinates', () {
    test('missing latitude and longitude uses 0.0 fallback and warns',
        () async {
      final events = <GeofenceEvent>[];
      final errors = <PolyfenceError>[];
      final eventSub =
          PolyfenceService.instance.onGeofenceEvent.listen(events.add);
      final errorSub = PolyfenceService.instance.onError.listen(errors.add);

      final event = validEvent();
      event.remove('latitude');
      event.remove('longitude');

      mockPlatform.geofenceController.add(event);
      await Future.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events.first.location.latitude, 0.0);
      expect(events.first.location.longitude, 0.0);

      final coordErrors = errors
          .where((e) => e.message.contains('Missing GPS coordinates'))
          .toList();
      expect(coordErrors, hasLength(1));

      await eventSub.cancel();
      await errorSub.cancel();
    });

    test('missing only latitude warns and uses 0.0', () async {
      final events = <GeofenceEvent>[];
      final errors = <PolyfenceError>[];
      final eventSub =
          PolyfenceService.instance.onGeofenceEvent.listen(events.add);
      final errorSub = PolyfenceService.instance.onError.listen(errors.add);

      final event = validEvent();
      event.remove('latitude');
      // longitude still present

      mockPlatform.geofenceController.add(event);
      await Future.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events.first.location.latitude, 0.0);
      expect(events.first.location.longitude, -122.084);

      final coordErrors = errors
          .where((e) => e.message.contains('Missing GPS coordinates'))
          .toList();
      expect(coordErrors, hasLength(1));

      await eventSub.cancel();
      await errorSub.cancel();
    });

    test('missing accuracy does not emit error', () async {
      final events = <GeofenceEvent>[];
      final errors = <PolyfenceError>[];
      final eventSub =
          PolyfenceService.instance.onGeofenceEvent.listen(events.add);
      final errorSub = PolyfenceService.instance.onError.listen(errors.add);

      final event = validEvent();
      // Native sends accuracy under the canonical `gpsAccuracy` key
      // (iOS also sends a duplicate `accuracy` key — Android does not).
      // To exercise the "neither present" case, drop both.
      event.remove('accuracy');
      event.remove('gpsAccuracy');

      mockPlatform.geofenceController.add(event);
      await Future.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events.first.location.accuracy, isNull);
      // No error for missing accuracy — it's optional
      final coordErrors =
          errors.where((e) => e.message.contains('coordinates')).toList();
      expect(coordErrors, isEmpty);

      await eventSub.cancel();
      await errorSub.cancel();
    });

    test('forwards all polyfence-core enrichment fields (BUG-009)', () async {
      final events = <GeofenceEvent>[];
      final sub = PolyfenceService.instance.onGeofenceEvent.listen(events.add);

      mockPlatform.geofenceController.add({
        'zoneId': 'zone-9',
        'zoneName': 'Office',
        'eventType': 'DWELL',
        'timestamp': fixedTimestamp,
        'latitude': 37.422,
        'longitude': -122.084,
        'gpsAccuracy': 8.5,
        'speedMps': 1.2,
        'activityAtEvent': 'walking',
        'detectionTimeMs': 45.0,
        'distanceToBoundaryM': 12.3,
        'dwellDurationMs': 60000.0,
      });
      await Future.delayed(Duration.zero);

      expect(events, hasLength(1));
      final e = events.first;
      expect(e.zoneId, 'zone-9');
      expect(e.zoneName, 'Office');
      expect(e.type, GeofenceEventType.dwell);
      expect(e.location.accuracy, 8.5);
      expect(e.location.speed, 1.2);
      expect(e.location.activity, 'walking');
      expect(e.detectionTimeMs, 45.0);
      expect(e.distanceToBoundaryM, 12.3);
      expect(e.dwellDurationMs, 60000.0);

      await sub.cancel();
    });

    test('ENTER event without dwellDurationMs has null dwellDurationMs',
        () async {
      // Regression for BUG-009: polyfence-core only includes
      // dwellDurationMs in the event map for DWELL events. The bridge
      // must normalise its absence to null on every other event type.
      final events = <GeofenceEvent>[];
      final sub = PolyfenceService.instance.onGeofenceEvent.listen(events.add);

      mockPlatform.geofenceController.add(validEvent(eventType: 'ENTER'));
      await Future.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events.first.type, GeofenceEventType.enter);
      expect(events.first.dwellDurationMs, isNull);

      await sub.cancel();
    });

    test('gpsAccuracy wins when both keys present with different values',
        () async {
      // iOS sends both gpsAccuracy and accuracy (as a duplicate). If
      // the values ever diverge, gpsAccuracy is the canonical key on
      // both platforms and must take precedence over the iOS-only
      // fallback.
      final events = <GeofenceEvent>[];
      final sub = PolyfenceService.instance.onGeofenceEvent.listen(events.add);

      final event = validEvent();
      event['gpsAccuracy'] = 7.5;
      event['accuracy'] = 99.0;
      mockPlatform.geofenceController.add(event);
      await Future.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events.first.location.accuracy, 7.5);

      await sub.cancel();
    });

    test('reads gpsAccuracy when accuracy is absent (Android shape)',
        () async {
      final events = <GeofenceEvent>[];
      final sub = PolyfenceService.instance.onGeofenceEvent.listen(events.add);

      final event = validEvent();
      event.remove('accuracy');
      // Android only sends gpsAccuracy — verify it lands in
      // location.accuracy.
      mockPlatform.geofenceController.add(event);
      await Future.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events.first.location.accuracy, 10.0);

      await sub.cancel();
    });
  });

  group('_handleGeofenceEvent — malformed data', () {
    test('empty map emits error, no event', () async {
      final events = <GeofenceEvent>[];
      final errors = <PolyfenceError>[];
      final eventSub =
          PolyfenceService.instance.onGeofenceEvent.listen(events.add);
      final errorSub = PolyfenceService.instance.onError.listen(errors.add);

      mockPlatform.geofenceController.add({});
      await Future.delayed(Duration.zero);

      expect(events, isEmpty);
      expect(errors, hasLength(1));
      expect(errors.first.message, contains('Missing required fields'));

      await eventSub.cancel();
      await errorSub.cancel();
    });

    test('wrong types for fields emits error via outer catch', () async {
      final events = <GeofenceEvent>[];
      final errors = <PolyfenceError>[];
      final eventSub =
          PolyfenceService.instance.onGeofenceEvent.listen(events.add);
      final errorSub = PolyfenceService.instance.onError.listen(errors.add);

      // zoneId as int instead of String — will fail the `as String?` cast
      mockPlatform.geofenceController.add({
        'zoneId': 12345,
        'eventType': 'ENTER',
        'timestamp': fixedTimestamp,
      });
      await Future.delayed(Duration.zero);

      expect(events, isEmpty);
      expect(errors, hasLength(1));
      expect(errors.first.message, contains('Failed to parse geofence event'));

      await eventSub.cancel();
      await errorSub.cancel();
    });
  });

  group('_handleGeofenceEvent — multiple events', () {
    test('sequential events are all emitted in order', () async {
      final events = <GeofenceEvent>[];
      final sub = PolyfenceService.instance.onGeofenceEvent.listen(events.add);

      mockPlatform.geofenceController
          .add(validEvent(zoneId: 'z1', eventType: 'ENTER'));
      mockPlatform.geofenceController
          .add(validEvent(zoneId: 'z2', eventType: 'EXIT'));
      mockPlatform.geofenceController
          .add(validEvent(zoneId: 'z1', eventType: 'EXIT'));

      await Future.delayed(Duration.zero);

      expect(events, hasLength(3));
      expect(events[0].zoneId, 'z1');
      expect(events[0].type, GeofenceEventType.enter);
      expect(events[1].zoneId, 'z2');
      expect(events[1].type, GeofenceEventType.exit);
      expect(events[2].zoneId, 'z1');
      expect(events[2].type, GeofenceEventType.exit);

      await sub.cancel();
    });

    test('invalid event between valid events does not block stream', () async {
      final events = <GeofenceEvent>[];
      final errors = <PolyfenceError>[];
      final eventSub =
          PolyfenceService.instance.onGeofenceEvent.listen(events.add);
      final errorSub = PolyfenceService.instance.onError.listen(errors.add);

      // Valid → Invalid → Valid
      mockPlatform.geofenceController
          .add(validEvent(zoneId: 'z1', eventType: 'ENTER'));
      mockPlatform.geofenceController.add({'garbage': true}); // Invalid
      mockPlatform.geofenceController
          .add(validEvent(zoneId: 'z2', eventType: 'EXIT'));

      await Future.delayed(Duration.zero);

      expect(events, hasLength(2));
      expect(events[0].zoneId, 'z1');
      expect(events[1].zoneId, 'z2');
      expect(errors, hasLength(1)); // One error for the invalid event

      await eventSub.cancel();
      await errorSub.cancel();
    });
  });

  group('_handleGeofenceEvent — filtered streams', () {
    test('onZoneEnter only receives enter events', () async {
      final enterEvents = <GeofenceEvent>[];
      final sub = PolyfenceService.instance.onZoneEnter.listen(enterEvents.add);

      mockPlatform.geofenceController
          .add(validEvent(zoneId: 'z1', eventType: 'ENTER'));
      mockPlatform.geofenceController
          .add(validEvent(zoneId: 'z2', eventType: 'EXIT'));
      mockPlatform.geofenceController
          .add(validEvent(zoneId: 'z3', eventType: 'ENTER'));

      await Future.delayed(Duration.zero);

      expect(enterEvents, hasLength(2));
      expect(enterEvents[0].zoneId, 'z1');
      expect(enterEvents[1].zoneId, 'z3');

      await sub.cancel();
    });

    test('onZoneExit only receives exit events', () async {
      final exitEvents = <GeofenceEvent>[];
      final sub = PolyfenceService.instance.onZoneExit.listen(exitEvents.add);

      mockPlatform.geofenceController
          .add(validEvent(zoneId: 'z1', eventType: 'ENTER'));
      mockPlatform.geofenceController
          .add(validEvent(zoneId: 'z2', eventType: 'EXIT'));
      mockPlatform.geofenceController
          .add(validEvent(zoneId: 'z3', eventType: 'DWELL'));

      await Future.delayed(Duration.zero);

      expect(exitEvents, hasLength(1));
      expect(exitEvents.first.zoneId, 'z2');

      await sub.cancel();
    });
  });
}
