import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:polyfence/polyfence.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockPolyfencePlatform extends PolyfencePlatform
    with MockPlatformInterfaceMixin {
  final List<String> calls = [];
  final Map<String, dynamic> callArgs = {};

  final StreamController<PolyfenceLocation> locationController =
      StreamController<PolyfenceLocation>.broadcast();
  final StreamController<Map<String, dynamic>> geofenceController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> errorController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> performanceController =
      StreamController<Map<String, dynamic>>.broadcast();

  List<Map<String, dynamic>> drainPendingEventsResponse =
      const <Map<String, dynamic>>[];
  int pendingEventsDroppedCountResponse = 0;
  PlatformException? drainErrorToThrow;
  PlatformException? droppedCountErrorToThrow;

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
    callArgs['initialize'] = {
      'licenseKey': licenseKey,
      'config': config?.toMap(),
    };
  }

  @override
  Future<void> addZone(Zone zone) async {
    calls.add('addZone');
    callArgs['addZone'] = zone.toJson();
  }

  @override
  Future<void> removeZone(String zoneId) async {
    calls.add('removeZone');
  }

  @override
  Future<void> clearAllZones() async {
    calls.add('clearAllZones');
  }

  @override
  Future<void> startTracking() async {
    calls.add('startTracking');
  }

  @override
  Future<void> stopTracking() async {
    calls.add('stopTracking');
  }

  @override
  Future<bool> requestPermissions({bool always = false}) async {
    calls.add('requestPermissions');
    return true;
  }

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<Map<String, dynamic>> checkBatteryOptimization() async => {};

  @override
  Future<void> requestBatteryOptimizationExemption() async {}

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
      Map<String, dynamic> params) async => [];

  @override
  Future<Map<String, bool>> getZoneStates() async => {};

  @override
  Future<Map<String, dynamic>> getSessionTelemetry() async => {};

  @override
  Future<List<Map<String, dynamic>>> drainPendingEvents() async {
    calls.add('drainPendingEvents');
    if (drainErrorToThrow != null) throw drainErrorToThrow!;
    return drainPendingEventsResponse;
  }

  @override
  Future<int> pendingEventsDroppedCount() async {
    calls.add('pendingEventsDroppedCount');
    if (droppedCountErrorToThrow != null) throw droppedCountErrorToThrow!;
    return pendingEventsDroppedCountResponse;
  }

  @override
  Future<void> dispose() async {
    calls.add('dispose');
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
    await PolyfenceService.instance.initialize();
    mockPlatform.calls.clear();
  });

  group('PolyfenceConfiguration.pendingEventsQueueSize', () {
    test('defaults to 0 — feature is off out of the box', () {
      final config = PolyfenceConfiguration();
      expect(config.pendingEventsQueueSize, 0);
    });

    test('serialises through toMap for platform passthrough', () {
      final config = PolyfenceConfiguration(pendingEventsQueueSize: 500);
      final map = config.toMap();
      expect(map['pendingEventsQueueSize'], 500);
    });

    test('round-trips through toMap / fromMap unchanged', () {
      final original = PolyfenceConfiguration(pendingEventsQueueSize: 250);
      final restored = PolyfenceConfiguration.fromMap(original.toMap());
      expect(restored.pendingEventsQueueSize, 250);
      expect(restored, equals(original));
    });

    test('copyWith preserves and overrides pendingEventsQueueSize', () {
      final base = PolyfenceConfiguration(pendingEventsQueueSize: 100);
      final unchanged = base.copyWith();
      expect(unchanged.pendingEventsQueueSize, 100);
      final bumped = base.copyWith(pendingEventsQueueSize: 800);
      expect(bumped.pendingEventsQueueSize, 800);
    });

    test('rejects negative queue sizes', () {
      expect(
        () => PolyfenceConfiguration(pendingEventsQueueSize: -1),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('equality distinguishes different queue sizes', () {
      final a = PolyfenceConfiguration(pendingEventsQueueSize: 100);
      final b = PolyfenceConfiguration(pendingEventsQueueSize: 200);
      expect(a, isNot(equals(b)));
      expect(a.hashCode, isNot(equals(b.hashCode)));
    });
  });

  group('PolyfenceService.drainPendingEvents', () {
    setUp(() {
      mockPlatform.calls.clear();
      mockPlatform.drainPendingEventsResponse = const <Map<String, dynamic>>[];
      mockPlatform.drainErrorToThrow = null;
    });

    test('returns an empty list when core has nothing to drain', () async {
      final events = await PolyfenceService.instance.drainPendingEvents();
      expect(events, isEmpty);
      expect(mockPlatform.calls, contains('drainPendingEvents'));
    });

    test(
        'marks drained events with deliveredLate=true, capturedTs, and queuedDurationMs',
        () async {
      final capturedTs =
          DateTime.now().subtract(const Duration(seconds: 30)).millisecondsSinceEpoch;
      mockPlatform.drainPendingEventsResponse = [
        {
          'zoneId': 'zone-1',
          'zoneName': 'Home',
          'eventType': 'ENTER',
          'timestamp': capturedTs,
          'latitude': 37.7749,
          'longitude': -122.4194,
          'detectionTimeMs': 12.0,
          'deliveredLate': true,
          'capturedTs': capturedTs,
          'queuedDurationMs': 30000,
        },
      ];

      final events = await PolyfenceService.instance.drainPendingEvents();

      expect(events, hasLength(1));
      final event = events.single;
      expect(event.zoneId, 'zone-1');
      expect(event.type, GeofenceEventType.enter);
      expect(event.deliveredLate, isTrue);
      expect(event.capturedTs, capturedTs);
      expect(event.queuedDurationMs, 30000);
    });

    test('preserves drain order (oldest-first)', () async {
      mockPlatform.drainPendingEventsResponse = [
        {
          'zoneId': 'zone-1',
          'eventType': 'ENTER',
          'timestamp': 1000,
          'latitude': 0.0,
          'longitude': 0.0,
        },
        {
          'zoneId': 'zone-1',
          'eventType': 'EXIT',
          'timestamp': 2000,
          'latitude': 0.0,
          'longitude': 0.0,
        },
      ];

      final events = await PolyfenceService.instance.drainPendingEvents();

      expect(events, hasLength(2));
      expect(events[0].type, GeofenceEventType.enter);
      expect(events[1].type, GeofenceEventType.exit);
    });

    test('computes queuedDurationMs from timestamp when native omits it',
        () async {
      final past =
          DateTime.now().subtract(const Duration(seconds: 5)).millisecondsSinceEpoch;
      mockPlatform.drainPendingEventsResponse = [
        {
          'zoneId': 'z',
          'eventType': 'ENTER',
          'timestamp': past,
          'latitude': 0.0,
          'longitude': 0.0,
        },
      ];

      final events = await PolyfenceService.instance.drainPendingEvents();

      expect(events.single.deliveredLate, isTrue);
      expect(events.single.capturedTs, past);
      expect(events.single.queuedDurationMs, greaterThanOrEqualTo(0));
    });

    test('skips events with missing required fields but emits warning onError',
        () async {
      mockPlatform.drainPendingEventsResponse = [
        {'eventType': 'ENTER'}, // no zoneId
        {'zoneId': 'z'}, // no eventType
        {
          'zoneId': 'z',
          'eventType': 'ENTER',
          'timestamp': 1000,
          'latitude': 0.0,
          'longitude': 0.0,
        },
      ];

      final warnings = <PolyfenceError>[];
      final sub = PolyfenceService.instance.onError
          .where((e) => e.context['severity'] == 'warning')
          .listen(warnings.add);

      final events = await PolyfenceService.instance.drainPendingEvents();
      // Give the broadcast stream a chance to deliver.
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(events, hasLength(1));
      // Native side has already deleted the two unparseable entries from
      // the on-disk store; the bridge must at minimum surface an
      // observable warning so the consumer knows two crossings were lost.
      expect(warnings, hasLength(2));
      for (final warning in warnings) {
        expect(warning.context['severity'], 'warning');
        expect(warning.context['rawEvent'], isA<Map>());
      }
    });

    test('unparseable drained payload surfaces a single warning onError',
        () async {
      final past = DateTime.now()
          .subtract(const Duration(seconds: 30))
          .millisecondsSinceEpoch;
      final malformed = <String, dynamic>{
        // eventType present but unknown, and zoneId absent → not parseable.
        'eventType': 'SUPERPOSITION',
        'timestamp': past,
        'latitude': 0.0,
        'longitude': 0.0,
      };
      mockPlatform.drainPendingEventsResponse = [malformed];

      final warnings = <PolyfenceError>[];
      final sub = PolyfenceService.instance.onError.listen(warnings.add);

      final events = await PolyfenceService.instance.drainPendingEvents();
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(events, isEmpty);
      expect(warnings, hasLength(1));
      expect(warnings.single.context['severity'], 'warning');
      expect(warnings.single.context['rawEvent'], malformed);
      expect(warnings.single.message, contains('Drained pending event dropped'));
    });

    test('platform errors surface as PlatformOperationException', () async {
      mockPlatform.drainErrorToThrow = PlatformException(
        code: 'DRAIN_PENDING_EVENTS_FAILED',
        message: 'disk read error',
      );

      expect(
        () => PolyfenceService.instance.drainPendingEvents(),
        throwsA(isA<PlatformOperationException>()),
      );
    });
  });

  group('PolyfenceService.pendingEventsDroppedCount', () {
    setUp(() {
      mockPlatform.calls.clear();
      mockPlatform.pendingEventsDroppedCountResponse = 0;
      mockPlatform.droppedCountErrorToThrow = null;
    });

    test('returns 0 when the queue has never evicted', () async {
      final count = await PolyfenceService.instance.pendingEventsDroppedCount();
      expect(count, 0);
      expect(mockPlatform.calls, contains('pendingEventsDroppedCount'));
    });

    test('returns the native counter value when non-zero', () async {
      mockPlatform.pendingEventsDroppedCountResponse = 17;
      final count = await PolyfenceService.instance.pendingEventsDroppedCount();
      expect(count, 17);
    });

    test('platform errors surface as PlatformOperationException', () async {
      mockPlatform.droppedCountErrorToThrow = PlatformException(
        code: 'PENDING_EVENTS_DROPPED_COUNT_FAILED',
        message: 'unavailable',
      );

      expect(
        () => PolyfenceService.instance.pendingEventsDroppedCount(),
        throwsA(isA<PlatformOperationException>()),
      );
    });
  });

  group('PolyfenceErrorType.pendingEventsEvicted', () {
    test('is present on the enum surface for consumer switches', () {
      expect(PolyfenceErrorType.values,
          contains(PolyfenceErrorType.pendingEventsEvicted));
    });

    test('deserialises from native snake_case pending_events_evicted', () {
      final err = PolyfenceError.fromMap({
        'type': 'pending_events_evicted',
        'message': 'queue at capacity',
        'context': {'severity': 'warning', 'droppedCount': 5},
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      expect(err.type, PolyfenceErrorType.pendingEventsEvicted);
      expect(err.context['severity'], 'warning');
      expect(err.context['droppedCount'], 5);
    });
  });
}
