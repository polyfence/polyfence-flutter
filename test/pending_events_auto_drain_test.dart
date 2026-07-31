import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:polyfence/polyfence.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records the listener-live signals the service sends to native, which is the
/// only observable this layer has: the drain itself happens in polyfence-core.
class RecordingPlatform extends PolyfencePlatform with MockPlatformInterfaceMixin {
  final List<bool> listenerSignals = [];
  final List<String> calls = [];

  final StreamController<PolyfenceLocation> locationController =
      StreamController<PolyfenceLocation>.broadcast();
  final StreamController<Map<String, dynamic>> geofenceController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> errorController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> performanceController =
      StreamController<Map<String, dynamic>>.broadcast();

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
  Future<void> setEventListenerActive(bool active) async {
    calls.add('setEventListenerActive');
    listenerSignals.add(active);
  }

  @override
  Future<void> initialize(
      {String? licenseKey, PolyfenceConfiguration? config}) async {
    calls.add('initialize');
  }

  @override
  Future<void> addZone(Zone zone) async {}

  @override
  Future<void> removeZone(String zoneId) async {}

  @override
  Future<void> clearAllZones() async {}

  @override
  Future<void> startTracking() async {}

  @override
  Future<void> stopTracking() async {}

  @override
  Future<bool> requestPermissions({bool always = false}) async => true;

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
  Future<List<Map<String, dynamic>>> drainPendingEvents() async =>
      const <Map<String, dynamic>>[];

  @override
  Future<int> pendingEventsDroppedCount() async => 0;

  @override
  Future<void> dispose() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RecordingPlatform platform;
  late List<bool> signalsAfterInitialize;

  setUpAll(() async {
    platform = RecordingPlatform();
    PolyfencePlatform.instance = platform;
    SharedPreferences.setMockInitialValues({});
    await PolyfenceService.instance.initialize();
    // Snapshot taken before any test can subscribe, so the assertion below
    // cannot be polluted by a later test's subscription.
    signalsAfterInitialize = List<bool>.from(platform.listenerSignals);
  });

  group('listener-live signal', () {
    // The load-bearing test. initialize() opens the plugin's own
    // platform-channel subscription, which is what setBridgeAttached reports.
    // If that were treated as "a listener exists", the native engine would
    // replay the durable queue into onGeofenceEvent while it still has zero
    // subscribers — a broadcast stream drops what it is given then, so the
    // events would be lost at exactly the moment the feature exists to save
    // them.
    test('initialize() never reports an active listener', () {
      expect(
        signalsAfterInitialize,
        isNot(contains(true)),
        reason: 'No consumer has subscribed during initialize() — reporting an '
            'active listener there replays the queue into a stream nobody reads',
      );
    });

    test('initialize() reports the inactive state so native holds the queue',
        () {
      expect(signalsAfterInitialize, equals([false]));
    });

    test('subscribing to onGeofenceEvent reports an active listener', () async {
      platform.listenerSignals.clear();

      final sub = PolyfenceService.instance.onGeofenceEvent.listen((_) {});
      await Future<void>.delayed(Duration.zero);

      expect(platform.listenerSignals, equals([true]));

      await sub.cancel();
      await Future<void>.delayed(Duration.zero);
    });

    test('a second concurrent subscriber does not re-report', () async {
      final first = PolyfenceService.instance.onGeofenceEvent.listen((_) {});
      await Future<void>.delayed(Duration.zero);
      platform.listenerSignals.clear();

      final second = PolyfenceService.instance.onGeofenceEvent.listen((_) {});
      await Future<void>.delayed(Duration.zero);

      expect(
        platform.listenerSignals,
        isEmpty,
        reason: 'The controller already had a subscriber — nothing changed for '
            'native, and a repeat signal would be a wasted disk read',
      );

      await first.cancel();
      await second.cancel();
      await Future<void>.delayed(Duration.zero);
    });

    test('cancelling the last subscriber reports the listener as gone',
        () async {
      final sub = PolyfenceService.instance.onGeofenceEvent.listen((_) {});
      await Future<void>.delayed(Duration.zero);
      platform.listenerSignals.clear();

      await sub.cancel();
      await Future<void>.delayed(Duration.zero);

      expect(platform.listenerSignals, equals([false]));
    });

    test('the filtered enter/exit streams count as geofence listeners',
        () async {
      platform.listenerSignals.clear();

      final sub = PolyfenceService.instance.onZoneEnter.listen((_) {});
      await Future<void>.delayed(Duration.zero);

      expect(platform.listenerSignals, equals([true]));

      await sub.cancel();
      await Future<void>.delayed(Duration.zero);
    });

    test('resubscribing after a cancel reports active again', () async {
      final first = PolyfenceService.instance.onGeofenceEvent.listen((_) {});
      await Future<void>.delayed(Duration.zero);
      await first.cancel();
      await Future<void>.delayed(Duration.zero);
      platform.listenerSignals.clear();

      final second = PolyfenceService.instance.onGeofenceEvent.listen((_) {});
      await Future<void>.delayed(Duration.zero);

      expect(platform.listenerSignals, equals([true]));

      await second.cancel();
      await Future<void>.delayed(Duration.zero);
    });
  });

  group('PolyfenceConfiguration.pendingEventsAutoDrainEnabled', () {
    test('defaults to true — queued crossings arrive without being asked for',
        () {
      expect(PolyfenceConfiguration().pendingEventsAutoDrainEnabled, isTrue);
    });

    test('serialises through toMap for platform passthrough', () {
      final map = PolyfenceConfiguration(pendingEventsAutoDrainEnabled: false)
          .toMap();
      expect(map['pendingEventsAutoDrainEnabled'], isFalse);
    });

    test('round-trips through toMap / fromMap unchanged', () {
      final original =
          PolyfenceConfiguration(pendingEventsAutoDrainEnabled: false);
      final restored = PolyfenceConfiguration.fromMap(original.toMap());
      expect(restored.pendingEventsAutoDrainEnabled, isFalse);
      expect(restored, equals(original));
    });

    test('fromMap defaults to true when the key is absent', () {
      final restored = PolyfenceConfiguration.fromMap(const {});
      expect(restored.pendingEventsAutoDrainEnabled, isTrue);
    });

    test('copyWith preserves and overrides the flag', () {
      final base = PolyfenceConfiguration(pendingEventsAutoDrainEnabled: false);
      expect(base.copyWith().pendingEventsAutoDrainEnabled, isFalse);
      expect(
        base.copyWith(pendingEventsAutoDrainEnabled: true)
            .pendingEventsAutoDrainEnabled,
        isTrue,
      );
    });

    test('equality distinguishes the two settings', () {
      final on = PolyfenceConfiguration();
      final off = PolyfenceConfiguration(pendingEventsAutoDrainEnabled: false);
      expect(on, isNot(equals(off)));
      expect(on.hashCode, isNot(equals(off.hashCode)));
    });
  });
}
