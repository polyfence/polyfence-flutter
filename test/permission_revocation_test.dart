import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:polyfence/polyfence.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mock platform that simulates native permission revocation error events.
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

  group('Permission revocation during tracking', () {
    test('initialize succeeds (setup for subsequent tests)', () async {
      await PolyfenceService.instance.initialize(
        analyticsConfig: const AnalyticsConfig(disableTelemetry: true),
      );

      expect(mockPlatform.calls, contains('initialize'));
    });

    test('permission_revoked error from Android is deserialized with correct type',
        () async {
      final errors = <PolyfenceError>[];
      final sub = PolyfenceService.instance.onError.listen(errors.add);

      // Simulate native Android platform sending a permission_revoked error
      // (as Android's combined health monitor sends via PolyfenceErrorManager)
      // Native sends snake_case type strings
      mockPlatform.errorController.add({
        'type': 'permission_revoked',
        'message': 'Location permission was revoked while tracking',
        'context': {
          'platform': 'android',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(errors, hasLength(1));
      expect(errors[0].type, PolyfenceErrorType.permissionRevoked);
      expect(errors[0].message, contains('permission was revoked'));
      expect(errors[0].context['platform'], 'android');

      await sub.cancel();
    });

    test('permission_revoked error from iOS is deserialized correctly',
        () async {
      final errors = <PolyfenceError>[];
      final sub = PolyfenceService.instance.onError.listen(errors.add);

      // Simulate iOS sending a permission revocation error
      // Native sends snake_case type strings
      mockPlatform.errorController.add({
        'type': 'permission_revoked',
        'message':
            'Location permission was revoked while tracking was active (status: denied)',
        'context': {
          'platform': 'ios',
          'authorizationStatus': 'denied',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(errors, hasLength(1));
      expect(errors[0].type, PolyfenceErrorType.permissionRevoked);
      expect(errors[0].context['platform'], 'ios');
      expect(errors[0].context['authorizationStatus'], 'denied');

      await sub.cancel();
    });

    test('service continues to receive events after permission error',
        () async {
      final errors = <PolyfenceError>[];
      final locations = <PolyfenceLocation>[];
      final errorSub = PolyfenceService.instance.onError.listen(errors.add);
      final locationSub =
          PolyfenceService.instance.onLocationUpdate.listen(locations.add);

      // Emit a permission revocation error (snake_case from native)
      mockPlatform.errorController.add({
        'type': 'permission_revoked',
        'message': 'Location permission was revoked',
        'context': {'platform': 'android'},
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(errors, hasLength(1));
      expect(errors[0].type, PolyfenceErrorType.permissionRevoked);

      // Service should still be able to process events (e.g., if permissions
      // are re-granted and tracking is restarted on native side)
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

    test('multiple permission errors are each delivered independently',
        () async {
      final errors = <PolyfenceError>[];
      final sub = PolyfenceService.instance.onError.listen(errors.add);

      // Simulate two sequential permission revocations (e.g., Android periodic
      // check fires, then SecurityException also fires)
      mockPlatform.errorController.add({
        'type': 'permission_revoked',
        'message': 'Location permission was revoked by user during tracking',
        'context': {'platform': 'android', 'source': 'health_check'},
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      mockPlatform.errorController.add({
        'type': 'permission_revoked',
        'message':
            'Location permission was revoked - SecurityException during GPS update',
        'context': {'platform': 'android', 'source': 'security_exception'},
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(errors, hasLength(2));
      expect(errors[0].type, PolyfenceErrorType.permissionRevoked);
      expect(errors[1].type, PolyfenceErrorType.permissionRevoked);
      expect(errors[0].context['source'], 'health_check');
      expect(errors[1].context['source'], 'security_exception');

      await sub.cancel();
    });

    test('PolyfenceError.fromMap maps camelCase permissionRevoked type', () {
      final error = PolyfenceError.fromMap({
        'type': 'permissionRevoked',
        'message': 'Test permission revoked',
        'context': {'platform': 'android'},
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      expect(error.type, PolyfenceErrorType.permissionRevoked);
      expect(error.message, 'Test permission revoked');
    });

    test('PolyfenceError.fromMap maps snake_case permission_revoked type', () {
      // Native platforms (Android/iOS) send snake_case error type strings.
      // The fromMap factory normalizes to camelCase before matching.
      final error = PolyfenceError.fromMap({
        'type': 'permission_revoked',
        'message': 'Native permission revoked',
        'context': {'platform': 'android'},
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      expect(error.type, PolyfenceErrorType.permissionRevoked);
      expect(error.message, 'Native permission revoked');
    });

    test('PolyfenceError.fromMap maps other snake_case native error types', () {
      // Verify that other native error types also map correctly via
      // the snake_case → camelCase normalization
      final gpsError = PolyfenceError.fromMap({
        'type': 'gps_timeout',
        'message': 'GPS timeout',
        'context': {},
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      expect(gpsError.type, PolyfenceErrorType.gpsTimeout);

      final batteryError = PolyfenceError.fromMap({
        'type': 'battery_optimization_required',
        'message': 'Battery opt required',
        'context': {},
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      expect(
          batteryError.type, PolyfenceErrorType.batteryOptimizationRequired);

      final serviceError = PolyfenceError.fromMap({
        'type': 'service_start_failed',
        'message': 'Service failed',
        'context': {},
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      expect(serviceError.type, PolyfenceErrorType.serviceStartFailed);
    });

    test('unknown error type falls back to PolyfenceErrorType.unknown', () {
      final error = PolyfenceError.fromMap({
        'type': 'some_future_error_type',
        'message': 'Unrecognized error',
        'context': {},
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      expect(error.type, PolyfenceErrorType.unknown);
    });

    // dispose() tests MUST run last
    test('dispose succeeds after permission revocation errors', () async {
      mockPlatform.calls.clear();

      await PolyfenceService.instance.dispose();

      expect(mockPlatform.calls, contains('dispose'));
    });
  });
}
