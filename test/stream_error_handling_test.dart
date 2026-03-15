import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:polyfence/polyfence.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mock platform with controllable stream controllers for error injection.
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
      {String? licenseKey, Map<String, dynamic>? config}) async {
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
  Future<Map<String, dynamic>> checkBatteryOptimization() async =>
      {'isOptimized': false};
  @override
  Future<bool> requestBatteryOptimizationExemption() async => true;
  @override
  Future<Map<String, dynamic>> getConfiguration() async => {};
  @override
  Future<void> updateConfiguration(Map<String, dynamic> config) async =>
      calls.add('updateConfiguration');
  @override
  Future<void> resetConfiguration() async => calls.add('resetConfiguration');
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

  setUpAll(() {
    mockPlatform = MockPolyfencePlatform();
    PolyfencePlatform.instance = mockPlatform;
    SharedPreferences.setMockInitialValues({});
  });

  group('Platform stream error handling', () {
    test('initialize succeeds (setup for subsequent tests)', () async {
      await PolyfenceService.instance.initialize(
        analyticsConfig: const AnalyticsConfig(disableTelemetry: true),
      );

      expect(mockPlatform.calls, contains('initialize'));
    });

    test('location stream error is routed to onError', () async {
      final errors = <PolyfenceError>[];
      final sub = PolyfenceService.instance.onError.listen(errors.add);

      // Simulate a PlatformException from the native location EventChannel
      mockPlatform.locationController.addError(
        PlatformException(
            code: 'GPS_UNAVAILABLE', message: 'GPS hardware failed'),
        StackTrace.current,
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(errors, hasLength(1));
      expect(errors[0].type, PolyfenceErrorType.unknown);
      expect(errors[0].message, contains('location'));
      expect(errors[0].message, contains('GPS hardware failed'));
      expect(errors[0].context['stream'], 'location');
      expect(errors[0].context['platformCode'], 'GPS_UNAVAILABLE');

      await sub.cancel();
    });

    test('geofence stream error is routed to onError', () async {
      final errors = <PolyfenceError>[];
      final sub = PolyfenceService.instance.onError.listen(errors.add);

      mockPlatform.geofenceController.addError(
        PlatformException(
            code: 'DECODE_ERROR', message: 'Malformed geofence data'),
        StackTrace.current,
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(errors, hasLength(1));
      expect(errors[0].message, contains('geofence'));
      expect(errors[0].message, contains('Malformed geofence data'));
      expect(errors[0].context['stream'], 'geofence');

      await sub.cancel();
    });

    test('error stream error is routed to onError (no infinite loop)',
        () async {
      final errors = <PolyfenceError>[];
      final sub = PolyfenceService.instance.onError.listen(errors.add);

      // The error channel itself emits an error — should be caught and
      // routed to the developer error stream without recursion.
      mockPlatform.errorController.addError(
        PlatformException(
            code: 'CHANNEL_ERROR', message: 'Error channel disrupted'),
        StackTrace.current,
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(errors, hasLength(1));
      expect(errors[0].message, contains('error'));
      expect(errors[0].message, contains('Error channel disrupted'));
      expect(errors[0].context['stream'], 'error');

      await sub.cancel();
    });

    test('performance stream error is routed to onError', () async {
      final errors = <PolyfenceError>[];
      final sub = PolyfenceService.instance.onError.listen(errors.add);

      mockPlatform.performanceController.addError(
        StateError('Performance stream corrupted'),
        StackTrace.current,
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(errors, hasLength(1));
      expect(errors[0].message, contains('performance'));
      expect(errors[0].message, contains('Performance stream corrupted'));
      expect(errors[0].context['stream'], 'performance');
      // Non-PlatformException should NOT have platformCode
      expect(errors[0].context.containsKey('platformCode'), false);

      await sub.cancel();
    });

    test('service continues functioning after location stream error', () async {
      final errors = <PolyfenceError>[];
      final locations = <PolyfenceLocation>[];
      final errorSub = PolyfenceService.instance.onError.listen(errors.add);
      final locationSub =
          PolyfenceService.instance.onLocationUpdate.listen(locations.add);

      // Emit an error
      mockPlatform.locationController.addError(
        PlatformException(code: 'TRANSIENT', message: 'Temporary failure'),
        StackTrace.current,
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(errors, hasLength(1));

      // Now emit a valid location — stream should still work
      mockPlatform.locationController.add(PolyfenceLocation(
        latitude: 37.422,
        longitude: -122.084,
        accuracy: 10.0,
      ));

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(locations, hasLength(1));
      expect(locations[0].latitude, 37.422);

      await errorSub.cancel();
      await locationSub.cancel();
    });

    test('service continues functioning after geofence stream error', () async {
      final errors = <PolyfenceError>[];
      final events = <GeofenceEvent>[];
      final errorSub = PolyfenceService.instance.onError.listen(errors.add);
      final eventSub =
          PolyfenceService.instance.onGeofenceEvent.listen(events.add);

      // Add a zone so event handler can look it up
      await PolyfenceService.instance.addZone(Zone.circle(
        id: 'recovery-zone',
        name: 'Recovery Zone',
        center: PolyfenceLocation(latitude: 37.0, longitude: -122.0),
        radius: 100.0,
      ));

      // Emit an error
      mockPlatform.geofenceController.addError(
        PlatformException(code: 'TRANSIENT', message: 'Temporary failure'),
        StackTrace.current,
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(errors, hasLength(1));

      // Now emit a valid geofence event — stream should still work
      mockPlatform.geofenceController.add({
        'zoneId': 'recovery-zone',
        'eventType': 'ENTER',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'detectionTimeMs': 12.0,
        'gpsAccuracy': 8.0,
        'latitude': 37.0,
        'longitude': -122.0,
        'accuracy': 8.0,
      });

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(events, hasLength(1));
      expect(events[0].zoneId, 'recovery-zone');

      await errorSub.cancel();
      await eventSub.cancel();
    });

    test('multiple stream errors are all routed independently', () async {
      final errors = <PolyfenceError>[];
      final sub = PolyfenceService.instance.onError.listen(errors.add);

      // Fire errors on multiple streams
      mockPlatform.locationController.addError(
        PlatformException(code: 'LOC_ERR', message: 'Location error'),
        StackTrace.current,
      );
      mockPlatform.geofenceController.addError(
        PlatformException(code: 'GEO_ERR', message: 'Geofence error'),
        StackTrace.current,
      );
      mockPlatform.performanceController.addError(
        PlatformException(code: 'PERF_ERR', message: 'Performance error'),
        StackTrace.current,
      );

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(errors, hasLength(3));

      final streams = errors.map((e) => e.context['stream'] as String).toSet();
      expect(streams, containsAll(['location', 'geofence', 'performance']));

      await sub.cancel();
    });

    // dispose() tests MUST run last
    test('dispose succeeds after stream errors', () async {
      mockPlatform.calls.clear();

      await PolyfenceService.instance.dispose();

      expect(mockPlatform.calls, contains('dispose'));
    });
  });
}
