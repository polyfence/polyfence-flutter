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


/// Does the sample published on the marketing homepage receive an event?
///
/// The snippet initialises, defines a zone, adds it, starts tracking — and
/// never subscribes. Events reach a consumer only through `onGeofenceEvent`,
/// a broadcast stream, so anything emitted with nothing listening is dropped
/// rather than buffered.
///
/// Both halves run against one platform instance and one initialise, because
/// the service is a singleton: re-initialising in a second test leaves it
/// subscribed to the previous mock and every case reads as zero.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the published sequence receives nothing until something subscribes',
      () async {
    final mockPlatform = MockPolyfencePlatform();
    PolyfencePlatform.instance = mockPlatform;
    SharedPreferences.setMockInitialValues({});
    await PolyfenceService.instance.initialize();

    final zone = Zone.circle(
      id: 'office',
      name: 'London Office',
      center: PolyfenceLocation(latitude: 51.5074, longitude: -0.1278),
      radius: 200,
    );

    Map<String, dynamic> crossing() => {
          'zoneId': 'office',
          'zoneName': 'London Office',
          'eventType': 'enter',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'latitude': 51.5074,
          'longitude': -0.1278,
        };

    // ── exactly what the homepage prints ──
    await PolyfenceService.instance.addZone(zone);
    await PolyfenceService.instance.startTracking();

    final asPublished = <GeofenceEvent>[];
    mockPlatform.geofenceController.add(crossing());
    await Future<void>.delayed(const Duration(milliseconds: 50));
    print('AS PUBLISHED (no listener) -> ${asPublished.length} event(s)');

    // ── the same run, with the one line the sample omits ──
    final withListener = <GeofenceEvent>[];
    final sub =
        PolyfenceService.instance.onGeofenceEvent.listen(withListener.add);
    mockPlatform.geofenceController.add(crossing());
    await Future<void>.delayed(const Duration(milliseconds: 50));
    print('WITH onGeofenceEvent.listen -> ${withListener.length} event(s)');

    await sub.cancel();

    expect(asPublished, isEmpty);
    expect(withListener, isNotEmpty);
  });
}
