import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:polyfence/polyfence.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mock platform that tracks calls for verification.
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

  group('Analytics isolation — analytics failure does not block geofencing',
      () {
    test('initialize succeeds when analytics throws (non-HTTPS endpoint)',
        () async {
      // Provide a non-HTTPS analytics endpoint — this triggers ArgumentError
      // inside PolyfenceAnalytics.initialize(). Before the fix, this would
      // crash initialize() and prevent geofencing from starting.
      await PolyfenceService.instance.initialize(
        analyticsConfig: const AnalyticsConfig(
          apiEndpoint: 'http://insecure.example.com/analytics',
        ),
      );

      // Core geofencing should be fully operational
      expect(mockPlatform.calls, contains('initialize'));

      // Verify we can use post-initialization APIs
      final zone = Zone.circle(
        id: 'test-zone',
        name: 'Test',
        center: PolyfenceLocation(latitude: 37.0, longitude: -122.0),
        radius: 100.0,
      );
      await PolyfenceService.instance.addZone(zone);
      expect(mockPlatform.calls, contains('addZone'));
    });

    test('startTracking works when analytics is unavailable', () async {
      // initialize() already ran with broken analytics in the previous test.
      // Verify that startTracking does not crash from analytics recordError.
      mockPlatform.calls.clear();

      await PolyfenceService.instance.startTracking();

      expect(mockPlatform.calls, contains('isLocationServiceEnabled'));
      expect(mockPlatform.calls, contains('requestPermissions'));
      expect(mockPlatform.calls, contains('startTracking'));
    });

    test('startTracking with permission denied does not crash on analytics',
        () async {
      mockPlatform.permissionsGranted = false;

      // Should throw PlatformOperationException, NOT crash from analytics
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

    test('geofence events are still emitted when analytics is unavailable',
        () async {
      // Add a zone so the event handler has something to look up
      await PolyfenceService.instance.addZone(Zone.circle(
        id: 'event-zone',
        name: 'Event Zone',
        center: PolyfenceLocation(latitude: 37.0, longitude: -122.0),
        radius: 100.0,
      ));

      // Listen for events
      final events = <GeofenceEvent>[];
      final sub = PolyfenceService.instance.onGeofenceEvent.listen(events.add);

      // Simulate a geofence event from the platform
      mockPlatform.geofenceController.add({
        'zoneId': 'event-zone',
        'eventType': 'ENTER',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'detectionTimeMs': 15.0,
        'gpsAccuracy': 10.0,
        'latitude': 37.0,
        'longitude': -122.0,
        'accuracy': 10.0,
      });

      // Give the stream time to process
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(events, hasLength(1));
      expect(events[0].zoneId, 'event-zone');
      expect(events[0].type, GeofenceEventType.enter);

      await sub.cancel();
    });

    test('error handling works when analytics is unavailable', () async {
      // Listen for errors
      final errors = <PolyfenceError>[];
      final sub = PolyfenceService.instance.onError.listen(errors.add);

      // Simulate an error from the platform
      mockPlatform.errorController.add({
        'type': 'gpsError',
        'message': 'GPS signal lost',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      // Give the stream time to process
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Error should still be emitted to the developer stream
      expect(errors, hasLength(1));
      expect(errors[0].message, 'GPS signal lost');

      await sub.cancel();
    });

    test('dispose succeeds when analytics is unavailable', () async {
      mockPlatform.calls.clear();

      // Should not throw — analytics cleanup is skipped when unavailable
      await PolyfenceService.instance.dispose();

      expect(mockPlatform.calls, contains('dispose'));
    });
  });
}
