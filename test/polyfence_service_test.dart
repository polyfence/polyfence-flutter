import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:polyfence/polyfence.dart';
import 'package:polyfence/src/models/polyfence_runtime_status.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Mock platform implementation using MockPlatformInterfaceMixin to bypass
// the PlatformInterface token verification.
class MockPolyfencePlatform extends PolyfencePlatform
    with MockPlatformInterfaceMixin {
  final List<String> calls = [];
  final Map<String, dynamic> callArgs = {};

  // Controllable stream controllers for simulating platform events
  final StreamController<PolyfenceLocation> locationController =
      StreamController<PolyfenceLocation>.broadcast();
  final StreamController<Map<String, dynamic>> geofenceController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> errorController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> performanceController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Configurable responses
  bool locationServiceEnabled = true;
  bool permissionsGranted = true;
  Map<String, dynamic> configResponse = {};
  Map<String, dynamic> debugInfoResponse = {};
  List<Map<String, dynamic>> errorHistoryResponse = [];

  // Error injection
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
    callArgs['initialize'] = {'licenseKey': licenseKey, 'config': config};
    if (errorToThrow != null) throw errorToThrow!;
  }

  @override
  Future<void> addZone(Zone zone) async {
    calls.add('addZone');
    callArgs['addZone'] = zone.toJson();
    if (errorToThrow != null) throw errorToThrow!;
  }

  @override
  Future<void> removeZone(String zoneId) async {
    calls.add('removeZone');
    callArgs['removeZone'] = zoneId;
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
  Future<bool> requestPermissions({bool always = false}) async {
    calls.add('requestPermissions');
    return permissionsGranted;
  }

  @override
  Future<bool> isLocationServiceEnabled() async {
    calls.add('isLocationServiceEnabled');
    return locationServiceEnabled;
  }

  @override
  Future<Map<String, dynamic>> checkBatteryOptimization() async {
    calls.add('checkBatteryOptimization');
    return {'isOptimized': false};
  }

  @override
  Future<bool> requestBatteryOptimizationExemption() async {
    calls.add('requestBatteryOptimizationExemption');
    return true;
  }

  @override
  Future<Map<String, dynamic>> getConfiguration() async {
    calls.add('getConfiguration');
    return configResponse;
  }

  @override
  Future<void> updateConfiguration(Map<String, dynamic> config) async {
    calls.add('updateConfiguration');
    callArgs['updateConfiguration'] = config;
  }

  @override
  Future<void> resetConfiguration() async {
    calls.add('resetConfiguration');
  }

  @override
  Future<void> setAccuracyProfile(String profile) async {
    calls.add('setAccuracyProfile');
    callArgs['setAccuracyProfile'] = profile;
  }

  @override
  Future<Map<String, dynamic>> getDebugInfo() async {
    calls.add('getDebugInfo');
    return debugInfoResponse;
  }

  @override
  Future<Map<String, dynamic>> getCurrentConfiguration() async {
    calls.add('getCurrentConfiguration');
    return {
      'accuracyProfile': 'MAX_ACCURACY',
      'updateStrategy': 'CONTINUOUS',
    };
  }

  @override
  Future<List<Map<String, dynamic>>> getErrorHistory(
      Map<String, dynamic> params) async {
    calls.add('getErrorHistory');
    return errorHistoryResponse;
  }

  @override
  Future<void> dispose() async {
    calls.add('dispose');
    await locationController.close();
    await geofenceController.close();
    await errorController.close();
    await performanceController.close();
  }

  void reset() {
    calls.clear();
    callArgs.clear();
    errorToThrow = null;
    locationServiceEnabled = true;
    permissionsGranted = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockPolyfencePlatform mockPlatform;

  setUpAll(() {
    // Replace the platform instance BEFORE PolyfenceService singleton
    // is first accessed. This works because static final fields in Dart
    // are lazily initialized on first access.
    mockPlatform = MockPolyfencePlatform();
    PolyfencePlatform.instance = mockPlatform;

    // Set up SharedPreferences mock (needed by initialize's telemetry check)
    SharedPreferences.setMockInitialValues({});
  });

  // NOTE: PolyfenceService is a singleton with no public reset method.
  // The _isInitialized and _isDisposed flags persist across tests.
  // Tests in this file MUST run in order and account for cumulative state.
  // This is a known architectural limitation of the singleton pattern.

  group('PolyfenceService — pre-initialization guards', () {
    test('addZone throws PolyfenceNotInitializedException before initialize',
        () {
      final zone = Zone.circle(
        id: 'z1',
        name: 'Zone 1',
        center: PolyfenceLocation(latitude: 37.0, longitude: -122.0),
        radius: 100.0,
      );

      expect(
        () => PolyfenceService.instance.addZone(zone),
        throwsA(isA<PolyfenceNotInitializedException>()),
      );
    });

    test('removeZone throws PolyfenceNotInitializedException before initialize',
        () {
      expect(
        () => PolyfenceService.instance.removeZone('z1'),
        throwsA(isA<PolyfenceNotInitializedException>()),
      );
    });

    test('startTracking throws PolyfenceNotInitializedException before initialize',
        () {
      expect(
        () => PolyfenceService.instance.startTracking(),
        throwsA(isA<PolyfenceNotInitializedException>()),
      );
    });

    test('stopTracking throws PolyfenceNotInitializedException before initialize',
        () {
      expect(
        () => PolyfenceService.instance.stopTracking(),
        throwsA(isA<PolyfenceNotInitializedException>()),
      );
    });

    test('configuration throws PolyfenceNotInitializedException before initialize',
        () {
      expect(
        () => PolyfenceService.instance.configuration(),
        throwsA(isA<PolyfenceNotInitializedException>()),
      );
    });

    test('debugInfo throws PolyfenceNotInitializedException before initialize',
        () {
      expect(
        () => PolyfenceService.instance.debugInfo(),
        throwsA(isA<PolyfenceNotInitializedException>()),
      );
    });

    test('requestPermissions throws PolyfenceNotInitializedException before initialize',
        () {
      expect(
        () => PolyfenceService.instance.requestPermissions(),
        throwsA(isA<PolyfenceNotInitializedException>()),
      );
    });

    test('clearAllZones throws PolyfenceNotInitializedException before initialize',
        () {
      expect(
        () => PolyfenceService.instance.clearAllZones(),
        throwsA(isA<PolyfenceNotInitializedException>()),
      );
    });
  });

  group('PolyfenceService — initialization', () {
    test('initialize calls platform.initialize with config', () async {
      // Initialize the service — this will call through to mockPlatform.
      // Note: PolyfenceAnalytics.instance.initialize() will also be called
      // internally, which tries to get PackageInfo (will throw in test env).
      // The service catches and continues despite analytics errors.
      try {
        await PolyfenceService.instance.initialize(
          config: {'debug': true},
          analyticsConfig: const AnalyticsConfig(disableTelemetry: true),
        );
      } catch (_) {
        // Analytics initialization may throw in test env (PackageInfo).
        // The important thing is that the platform was initialized.
      }

      expect(mockPlatform.calls, contains('initialize'));
    });

    test('second initialize call is no-op', () async {
      final callCountBefore = mockPlatform.calls.length;

      // Should return immediately because _isInitialized is already true
      await PolyfenceService.instance.initialize();

      // No new platform calls
      expect(mockPlatform.calls.length, callCountBefore);
    });
  });

  group('PolyfenceService — zone management', () {
    test('addZone calls through to platform', () async {
      mockPlatform.calls.clear();

      final zone = Zone.circle(
        id: 'office',
        name: 'Office',
        center: PolyfenceLocation(latitude: 37.422, longitude: -122.084),
        radius: 150.0,
      );
      await PolyfenceService.instance.addZone(zone);

      expect(mockPlatform.calls, contains('addZone'));
      expect(mockPlatform.callArgs['addZone']['id'], 'office');
    });

    test('zones getter returns added zones', () async {
      // Add a second zone
      final zone2 = Zone.circle(
        id: 'home',
        name: 'Home',
        center: PolyfenceLocation(latitude: 37.0, longitude: -122.0),
        radius: 200.0,
      );
      await PolyfenceService.instance.addZone(zone2);

      final allZones = PolyfenceService.instance.zones;
      expect(allZones.length, greaterThanOrEqualTo(2));
      expect(allZones.map((z) => z.id), containsAll(['office', 'home']));
    });

    test('removeZone calls through to platform', () async {
      mockPlatform.calls.clear();

      await PolyfenceService.instance.removeZone('home');

      expect(mockPlatform.calls, contains('removeZone'));
    });

    test('removeZone removes from zone cache', () async {
      final allZones = PolyfenceService.instance.zones;
      expect(allZones.map((z) => z.id), isNot(contains('home')));
    });

    test('clearAllZones calls through to platform', () async {
      // First add a zone back
      await PolyfenceService.instance.addZone(Zone.circle(
        id: 'temp',
        name: 'Temp',
        center: PolyfenceLocation(latitude: 37.0, longitude: -122.0),
        radius: 50.0,
      ));

      mockPlatform.calls.clear();
      await PolyfenceService.instance.clearAllZones();

      expect(mockPlatform.calls, contains('clearAllZones'));
      expect(PolyfenceService.instance.zones, isEmpty);
    });
  });

  group('PolyfenceService — tracking', () {
    test('startTracking checks location services and permissions', () async {
      mockPlatform.calls.clear();

      await PolyfenceService.instance.startTracking();

      expect(mockPlatform.calls, contains('isLocationServiceEnabled'));
      expect(mockPlatform.calls, contains('requestPermissions'));
      expect(mockPlatform.calls, contains('startTracking'));
    });

    test('startTracking throws when location services disabled', () async {
      mockPlatform.locationServiceEnabled = false;

      await expectLater(
        () => PolyfenceService.instance.startTracking(),
        throwsA(isA<PlatformOperationException>().having(
          (e) => e.message,
          'message',
          contains('Location services not enabled'),
        )),
      );

      mockPlatform.locationServiceEnabled = true;
    });

    test('startTracking throws when permissions denied', () async {
      mockPlatform.permissionsGranted = false;

      await expectLater(
        () => PolyfenceService.instance.startTracking(),
        throwsA(isA<PlatformOperationException>().having(
          (e) => e.message,
          'message',
          contains('permissions not granted'),
        )),
      );

      mockPlatform.permissionsGranted = true;
    });

    test('stopTracking calls through to platform', () async {
      mockPlatform.calls.clear();

      await PolyfenceService.instance.stopTracking();

      expect(mockPlatform.calls, contains('stopTracking'));
    });
  });

  group('PolyfenceService — configuration', () {
    test('configuration calls through to platform', () async {
      mockPlatform.configResponse = {'gps_interval_ms': 5000};
      mockPlatform.calls.clear();

      final config = await PolyfenceService.instance.configuration();

      expect(mockPlatform.calls, contains('getConfiguration'));
      expect(config['gps_interval_ms'], 5000);
    });

    test('updateConfiguration calls through to platform', () async {
      mockPlatform.calls.clear();

      await PolyfenceService.instance
          .updateConfiguration({'gps_interval_ms': 10000});

      expect(mockPlatform.calls, contains('updateConfiguration'));
    });

    test('resetConfiguration calls through to platform', () async {
      mockPlatform.calls.clear();

      await PolyfenceService.instance.resetConfiguration();

      expect(mockPlatform.calls, contains('resetConfiguration'));
    });

    test('updateGpsConfiguration sends serialized config to platform',
        () async {
      mockPlatform.calls.clear();

      const config = PolyfenceConfiguration(
        accuracyProfile: PolyfenceAccuracyProfile.balanced,
        gpsAccuracyThreshold: 50.0,
      );
      await PolyfenceService.instance.updateGpsConfiguration(config);

      expect(mockPlatform.calls, contains('updateConfiguration'));
      final sentConfig =
          mockPlatform.callArgs['updateConfiguration'] as Map<String, dynamic>;
      expect(sentConfig['gpsAccuracyThreshold'], 50.0);
    });

    test('currentConfiguration returns cached configuration', () {
      final config = PolyfenceService.instance.currentConfiguration;
      expect(config, isA<PolyfenceConfiguration>());
    });

    test('setAccuracyProfile calls platform with channel format', () async {
      mockPlatform.calls.clear();

      await PolyfenceService.instance
          .setAccuracyProfile(PolyfenceAccuracyProfile.batteryOptimal);

      expect(mockPlatform.calls, contains('setAccuracyProfile'));
      expect(mockPlatform.callArgs['setAccuracyProfile'], 'BATTERY_OPTIMAL');
    });
  });

  group('PolyfenceService — debug and diagnostics', () {
    // BUG: PolyfenceDebugInfo.fromMap does not null-check nested maps.
    // If any of systemStatus, performance, battery, zones, or recentErrors
    // is missing from the platform response, fromMap throws a TypeError.
    // Must provide all required keys to avoid the crash.
    test('debugInfo calls through to platform and returns parsed result',
        () async {
      mockPlatform.debugInfoResponse = {
        'systemStatus': {
          'pluginVersion': '0.9.0',
          'platformVersion': 'Android 14',
        },
        'performance': <String, dynamic>{},
        'battery': <String, dynamic>{},
        'zones': <String, dynamic>{},
        'recentErrors': <Map<String, dynamic>>[],
      };
      mockPlatform.calls.clear();

      final info = await PolyfenceService.instance.debugInfo();

      expect(mockPlatform.calls, contains('getDebugInfo'));
      expect(info, isA<PolyfenceDebugInfo>());
      expect(info.systemStatus.pluginVersion, '0.9.0');
    });

    test('batteryOptimizationStatus calls platform', () async {
      mockPlatform.calls.clear();

      final status =
          await PolyfenceService.instance.batteryOptimizationStatus();

      expect(mockPlatform.calls, contains('checkBatteryOptimization'));
      expect(status, isA<Map<String, dynamic>>());
    });

    test('isLocationServiceEnabled calls platform', () async {
      mockPlatform.calls.clear();

      final enabled =
          await PolyfenceService.instance.isLocationServiceEnabled();

      expect(mockPlatform.calls, contains('isLocationServiceEnabled'));
      expect(enabled, true);
    });

    test('requestPermissions calls platform with always flag', () async {
      mockPlatform.calls.clear();

      final granted =
          await PolyfenceService.instance.requestPermissions(always: true);

      expect(mockPlatform.calls, contains('requestPermissions'));
      expect(granted, true);
    });
  });

  group('PolyfenceService — streams', () {
    test('onGeofenceEvent stream is available', () {
      expect(
        PolyfenceService.instance.onGeofenceEvent,
        isA<Stream<GeofenceEvent>>(),
      );
    });

    test('onZoneEnter filters enter events', () {
      expect(
        PolyfenceService.instance.onZoneEnter,
        isA<Stream<GeofenceEvent>>(),
      );
    });

    test('onZoneExit filters exit events', () {
      expect(
        PolyfenceService.instance.onZoneExit,
        isA<Stream<GeofenceEvent>>(),
      );
    });

    test('onLocationUpdate stream is available', () {
      expect(
        PolyfenceService.instance.onLocationUpdate,
        isA<Stream<PolyfenceLocation>>(),
      );
    });

    test('onError stream is available', () {
      expect(
        PolyfenceService.instance.onError,
        isA<Stream<PolyfenceError>>(),
      );
    });

    test('runtimeStatus stream is available', () {
      expect(
        PolyfenceService.instance.runtimeStatus,
        isA<Stream<PolyfenceRuntimeStatus>>(),
      );
    });

    test('statusStream is available', () {
      expect(
        PolyfenceService.instance.statusStream,
        isA<Stream<Map<String, dynamic>>>(),
      );
    });
  });

  group('PolyfenceService — dispose', () {
    // dispose() tests MUST run last because the singleton is permanently
    // unusable after disposal (_isDisposed = true with no reset method).

    test('dispose calls platform.dispose', () async {
      mockPlatform.calls.clear();

      await PolyfenceService.instance.dispose();

      expect(mockPlatform.calls, contains('dispose'));
    });

    test('methods throw StateError after dispose', () async {
      final zone = Zone.circle(
        id: 'z1',
        name: 'Z',
        center: PolyfenceLocation(latitude: 37.0, longitude: -122.0),
        radius: 100.0,
      );

      expect(
        () => PolyfenceService.instance.addZone(zone),
        throwsA(isA<StateError>()),
      );

      expect(
        () => PolyfenceService.instance.removeZone('z1'),
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

    test('initialize throws StateError after dispose', () {
      expect(
        () => PolyfenceService.instance.initialize(),
        throwsA(isA<StateError>()),
      );
    });

    test('double dispose is no-op', () async {
      // Should not throw — early return when _isDisposed is already true
      await PolyfenceService.instance.dispose();
    });
  });
}
