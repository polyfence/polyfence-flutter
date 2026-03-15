import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polyfence/polyfence.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MethodChannelPolyfence platform;
  final List<MethodCall> log = [];

  setUp(() {
    platform = MethodChannelPolyfence();
    log.clear();

    // Set up mock method channel handler
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('polyfence'),
      (MethodCall call) async {
        log.add(call);
        switch (call.method) {
          case 'initialize':
            return null;
          case 'addZone':
            return null;
          case 'removeZone':
            return null;
          case 'clearAllZones':
            return null;
          case 'startTracking':
            return null;
          case 'stopTracking':
            return null;
          case 'requestPermissions':
            return true;
          case 'isLocationServiceEnabled':
            return true;
          case 'checkBatteryOptimization':
            return <String, dynamic>{'isOptimized': false};
          case 'requestBatteryOptimization':
            return true;
          case 'getConfiguration':
            return <String, dynamic>{'gps_interval_ms': 5000};
          case 'updateConfiguration':
            return null;
          case 'resetConfiguration':
            return null;
          case 'setAccuracyProfile':
            return null;
          case 'getDebugInfo':
            return <String, dynamic>{};
          case 'getErrorHistory':
            return <Map<String, dynamic>>[];
          default:
            return null;
        }
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('polyfence'), null);
  });

  group('MethodChannelPolyfence — method calls', () {
    test('initialize sends correct method and arguments', () async {
      await platform.initialize(
        licenseKey: 'test-key',
        config: {'debug': true},
      );

      expect(log, hasLength(1));
      expect(log[0].method, 'initialize');
      expect(log[0].arguments['licenseKey'], 'test-key');
      expect(log[0].arguments['config']['debug'], true);
    });

    test('initialize sends null licenseKey when not provided', () async {
      await platform.initialize();

      expect(log, hasLength(1));
      expect(log[0].arguments['licenseKey'], isNull);
      expect(log[0].arguments['config'], isNull);
    });

    test('startTracking sends correct method', () async {
      await platform.startTracking();

      expect(log, hasLength(1));
      expect(log[0].method, 'startTracking');
      expect(log[0].arguments, isNull);
    });

    test('stopTracking sends correct method', () async {
      await platform.stopTracking();

      expect(log, hasLength(1));
      expect(log[0].method, 'stopTracking');
      expect(log[0].arguments, isNull);
    });

    test('addZone serializes circle zone correctly', () async {
      final zone = Zone.circle(
        id: 'office',
        name: 'Office',
        center: PolyfenceLocation(latitude: 37.422, longitude: -122.084),
        radius: 150.0,
      );
      await platform.addZone(zone);

      expect(log, hasLength(1));
      expect(log[0].method, 'addZone');

      final args = log[0].arguments as Map;
      expect(args['id'], 'office');
      expect(args['name'], 'Office');
      expect(args['type'], 'circle');
      expect(args['radius'], 150.0);
    });

    test('addZone serializes polygon zone correctly', () async {
      final zone = Zone.polygon(
        id: 'campus',
        name: 'Campus',
        polygon: [
          PolyfenceLocation(latitude: 37.0, longitude: -122.0),
          PolyfenceLocation(latitude: 37.1, longitude: -122.0),
          PolyfenceLocation(latitude: 37.1, longitude: -122.1),
        ],
      );
      await platform.addZone(zone);

      expect(log, hasLength(1));
      expect(log[0].method, 'addZone');

      final args = log[0].arguments as Map;
      expect(args['id'], 'campus');
      expect(args['type'], 'polygon');
      expect(args['polygon'], isList);
      expect((args['polygon'] as List).length, 3);
    });

    test('removeZone sends zoneId', () async {
      await platform.removeZone('office');

      expect(log, hasLength(1));
      expect(log[0].method, 'removeZone');
      expect(log[0].arguments['zoneId'], 'office');
    });

    test('clearAllZones sends correct method', () async {
      await platform.clearAllZones();

      expect(log, hasLength(1));
      expect(log[0].method, 'clearAllZones');
    });

    test('requestPermissions sends always flag', () async {
      final result = await platform.requestPermissions(always: true);

      expect(log, hasLength(1));
      expect(log[0].method, 'requestPermissions');
      expect(log[0].arguments['always'], true);
      expect(result, true);
    });

    test('requestPermissions defaults always to false', () async {
      await platform.requestPermissions();

      expect(log, hasLength(1));
      expect(log[0].arguments['always'], false);
    });

    test('isLocationServiceEnabled returns bool', () async {
      final result = await platform.isLocationServiceEnabled();

      expect(log, hasLength(1));
      expect(log[0].method, 'isLocationServiceEnabled');
      expect(result, true);
    });

    test('checkBatteryOptimization returns map', () async {
      final result = await platform.checkBatteryOptimization();

      expect(log, hasLength(1));
      expect(log[0].method, 'checkBatteryOptimization');
      expect(result, isA<Map<String, dynamic>>());
    });

    test('requestBatteryOptimizationExemption returns bool', () async {
      final result = await platform.requestBatteryOptimizationExemption();

      expect(log, hasLength(1));
      expect(log[0].method, 'requestBatteryOptimization');
      expect(result, true);
    });

    test('getConfiguration returns map', () async {
      final result = await platform.getConfiguration();

      expect(log, hasLength(1));
      expect(log[0].method, 'getConfiguration');
      expect(result, isA<Map<String, dynamic>>());
      expect(result['gps_interval_ms'], 5000);
    });

    test('updateConfiguration sends config map', () async {
      await platform.updateConfiguration({'gps_interval_ms': 10000});

      expect(log, hasLength(1));
      expect(log[0].method, 'updateConfiguration');
      expect(log[0].arguments['gps_interval_ms'], 10000);
    });

    test('resetConfiguration sends correct method', () async {
      await platform.resetConfiguration();

      expect(log, hasLength(1));
      expect(log[0].method, 'resetConfiguration');
    });

    test('setAccuracyProfile sends profile string', () async {
      await platform.setAccuracyProfile('MAX_ACCURACY');

      expect(log, hasLength(1));
      expect(log[0].method, 'setAccuracyProfile');
      expect(log[0].arguments, 'MAX_ACCURACY');
    });

    test('getDebugInfo returns map', () async {
      final result = await platform.getDebugInfo();

      expect(log, hasLength(1));
      expect(log[0].method, 'getDebugInfo');
      expect(result, isA<Map<String, dynamic>>());
    });

    test('getErrorHistory sends params and returns list', () async {
      final result = await platform.getErrorHistory({
        'timeRangeMs': 3600000,
        'errorTypes': ['gpsTimeout'],
      });

      expect(log, hasLength(1));
      expect(log[0].method, 'getErrorHistory');
      expect(log[0].arguments['timeRangeMs'], 3600000);
      expect(result, isA<List<Map<String, dynamic>>>());
    });
  });

  group('MethodChannelPolyfence — platform error handling', () {
    test('initialize PlatformException propagates', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('polyfence'),
        (MethodCall call) async {
          throw PlatformException(
            code: 'INIT_FAILED',
            message: 'Native init failed',
          );
        },
      );

      expect(
        () => platform.initialize(),
        throwsA(isA<PlatformException>()),
      );
    });

    test('addZone PlatformException propagates', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('polyfence'),
        (MethodCall call) async {
          throw PlatformException(
            code: 'ZONE_ERROR',
            message: 'Zone add failed',
          );
        },
      );

      final zone = Zone.circle(
        id: 'z1',
        name: 'Z1',
        center: PolyfenceLocation(latitude: 37.0, longitude: -122.0),
        radius: 100.0,
      );

      expect(
        () => platform.addZone(zone),
        throwsA(isA<PlatformException>()),
      );
    });

    test('startTracking PlatformException propagates', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('polyfence'),
        (MethodCall call) async {
          throw PlatformException(
            code: 'TRACKING_ERROR',
            message: 'GPS unavailable',
          );
        },
      );

      expect(
        () => platform.startTracking(),
        throwsA(isA<PlatformException>()),
      );
    });

    test('requestPermissions returns false when platform returns null',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('polyfence'),
        (MethodCall call) async => null,
      );

      final result = await platform.requestPermissions();
      expect(result, false);
    });

    test('isLocationServiceEnabled returns false when platform returns null',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('polyfence'),
        (MethodCall call) async => null,
      );

      final result = await platform.isLocationServiceEnabled();
      expect(result, false);
    });

    test('checkBatteryOptimization returns empty map when null', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('polyfence'),
        (MethodCall call) async => null,
      );

      final result = await platform.checkBatteryOptimization();
      expect(result, isEmpty);
    });

    test('getConfiguration returns empty map when null', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('polyfence'),
        (MethodCall call) async => null,
      );

      final result = await platform.getConfiguration();
      expect(result, isEmpty);
    });

    test('getErrorHistory returns empty list when null', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('polyfence'),
        (MethodCall call) async => null,
      );

      final result = await platform.getErrorHistory({});
      expect(result, isEmpty);
    });
  });

  group('MethodChannelPolyfence — dispose', () {
    test('dispose nulls stream references', () async {
      await platform.dispose();
      // After dispose, accessing streams should create new ones
      // (the lazy ??= pattern re-creates if null)
      // Verify dispose doesn't throw
    });

    test('streams are lazily initialized (not null after first access)', () {
      // Access streams — they should be non-null and not throw
      expect(platform.onLocationUpdate, isA<Stream<PolyfenceLocation>>());
      expect(platform.onGeofenceEvent, isA<Stream<Map<String, dynamic>>>());
      expect(platform.onError, isA<Stream<Map<String, dynamic>>>());
      expect(platform.performanceStream, isA<Stream<Map<String, dynamic>>>());
    });
  });
}
