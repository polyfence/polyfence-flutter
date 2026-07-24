import 'package:flutter_test/flutter_test.dart';
import 'package:polyfence/polyfence.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'polyfence_service_test.dart' show MockPolyfencePlatform;

/// Runs in its own test file so it gets a fresh singleton — the
/// PolyfenceService singleton in polyfence_service_test.dart accumulates
/// state across its ordered groups (dispose is one-way) which prevents
/// end-to-end stream assertions there.
void main() {
  late MockPolyfencePlatform mockPlatform;

  setUpAll(() {
    mockPlatform = MockPolyfencePlatform();
    PolyfencePlatform.instance = mockPlatform;
    SharedPreferences.setMockInitialValues({});
  });

  test(
      'runtimeStatus decodes the real {type:"runtime_status", data:{...}} '
      'envelope and ignores other types', () async {
    try {
      await PolyfenceService.instance.initialize(
        config: PolyfenceConfiguration(enableDebugLogging: false),
        analyticsConfig: const AnalyticsConfig(disableTelemetry: true),
      );
    } catch (_) {
      // Analytics can throw in the test env (PackageInfo unavailable);
      // the platform stream subscription is set up unconditionally
      // downstream of that, so we ignore.
    }

    final received = <PolyfenceRuntimeStatus>[];
    final sub = PolyfenceService.instance.runtimeStatus.listen(received.add);
    // Give listen() a chance to attach to the broadcast controller.
    await Future<void>.delayed(Duration.zero);

    // Bridges no longer emit type:"status" — asserting no emission on
    // this variant guards against a future regression that re-adds it.
    mockPlatform.performanceController.add({
      'type': 'status',
      'trackingEnabled': true,
      'zonesCount': 3,
      'timestamp': 1234567890,
    });
    // Health-score events travel on healthScoreStream, not runtimeStatus.
    mockPlatform.performanceController.add({
      'type': 'health_score',
      'score': 87,
      'topIssue': null,
    });
    // Production envelope: metric fields live nested under `data`.
    // Fabricating a top-level shape (which would map to an all-zeros
    // PolyfenceRuntimeStatus) would defeat this test's purpose.
    mockPlatform.performanceController.add({
      'type': 'runtime_status',
      'data': {
        'strategy': 'CONTINUOUS',
        'intervalMs': 5000,
        'accuracyProfile': 'BALANCED',
        'nearestZoneDistanceM': 42.5,
        'isStationary': false,
        'batteryMode': 'NORMAL',
        'gpsAccuracy': 15.2,
        'timestamp': 1700000000000,
        'secondsSinceLastGpsFix': 3,
        'gpsAvailabilityDrops5Min': 0,
        'currentGpsAccuracy': 15.2,
      },
    });

    // Broadcast chain (platform stream → internal handler →
    // _runtimeStatusController → listener) needs a few microtask
    // flushes to drain; 50 ms is generous but bounded so a real hang
    // still fails fast.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();

    expect(received, hasLength(1));
    final status = received.single;
    expect(status.intervalMs, 5000);
    expect(status.nearestZoneDistanceM, 42.5);
    expect(status.currentGpsAccuracy, 15.2);
    expect(status.secondsSinceLastGpsFix, 3);
    expect(status.gpsAvailabilityDrops5Min, 0);
  });
}
