import 'package:flutter_test/flutter_test.dart';
import 'package:polyfence/polyfence.dart';

void main() {
  group('PolyfenceRuntimeStatus', () {
    test('fromMap parses all fields', () {
      final ts = DateTime(2024, 6, 15, 12, 0, 0);
      final status = PolyfenceRuntimeStatus.fromMap({
        'intervalMs': 10000,
        'nearestZoneDistanceM': 250.5,
        'timestamp': ts.millisecondsSinceEpoch,
      });

      expect(status.intervalMs, 10000);
      expect(status.nearestZoneDistanceM, 250.5);
      expect(status.timestamp, ts);
    });

    test('fromMap uses defaults for missing fields', () {
      final status = PolyfenceRuntimeStatus.fromMap({});

      expect(status.intervalMs, 5000);
      expect(status.nearestZoneDistanceM, double.infinity);
    });

    test('intervalDescription formats seconds correctly', () {
      final status = PolyfenceRuntimeStatus.fromMap({'intervalMs': 10000});
      expect(status.intervalDescription, '10s');
    });

    test('intervalDescription formats sub-second correctly', () {
      final status = PolyfenceRuntimeStatus.fromMap({'intervalMs': 500});
      expect(status.intervalDescription, '0s');
    });

    test('proximityDescription for no zones', () {
      final status = PolyfenceRuntimeStatus.fromMap({
        'nearestZoneDistanceM': double.infinity,
      });
      expect(status.proximityDescription, 'No zones');
    });

    test('proximityDescription for inside zone (< 500m)', () {
      final status = PolyfenceRuntimeStatus.fromMap({
        'nearestZoneDistanceM': 100.0,
      });
      expect(status.proximityDescription, contains('Inside zone'));
      expect(status.proximityDescription, contains('100'));
    });

    test('proximityDescription for near zone (500-5000m)', () {
      final status = PolyfenceRuntimeStatus.fromMap({
        'nearestZoneDistanceM': 2000.0,
      });
      expect(status.proximityDescription, contains('Near zone'));
      expect(status.proximityDescription, contains('2000'));
    });

    test('proximityDescription for far from zones (> 5000m)', () {
      final status = PolyfenceRuntimeStatus.fromMap({
        'nearestZoneDistanceM': 10000.0,
      });
      expect(status.proximityDescription, contains('Far from zones'));
    });
  });

  group('PolyfenceSystemStatus', () {
    test('fromMap/toMap round-trip', () {
      final ts = DateTime(2024, 6, 15, 12, 0, 0);
      final status = PolyfenceSystemStatus(
        isLocationPermissionGranted: true,
        isBackgroundLocationEnabled: true,
        isBatteryOptimizationDisabled: false,
        isGpsEnabled: true,
        isWakeLockAcquired: true,
        lastKnownAccuracy: 15.5,
        lastLocationUpdate: ts,
        platformVersion: 'Android 14',
        pluginVersion: '1.0.0',
      );

      final map = status.toMap();
      final restored = PolyfenceSystemStatus.fromMap(map);

      expect(restored.isLocationPermissionGranted, true);
      expect(restored.isBackgroundLocationEnabled, true);
      expect(restored.isBatteryOptimizationDisabled, false);
      expect(restored.isGpsEnabled, true);
      expect(restored.isWakeLockAcquired, true);
      expect(restored.lastKnownAccuracy, 15.5);
      expect(restored.lastLocationUpdate, ts);
      expect(restored.platformVersion, 'Android 14');
      expect(restored.pluginVersion, '1.0.0');
    });

    test('fromMap uses defaults for missing fields', () {
      final status = PolyfenceSystemStatus.fromMap({});

      expect(status.isLocationPermissionGranted, false);
      expect(status.isGpsEnabled, false);
      expect(status.lastKnownAccuracy, -1.0);
      expect(status.platformVersion, 'Unknown');
      expect(status.pluginVersion, 'Unknown');
    });

    group('osGeofenceRegistrationHealth', () {
      test('is null when the native map omits it or sends null', () {
        // Null is the "no registration attempted" contract, which is what a
        // consumer with wake fences off always sees — it has to stay
        // distinguishable from a cap hit or a permission failure.
        expect(PolyfenceSystemStatus.fromMap({}).osGeofenceRegistrationHealth,
            isNull);
        expect(
          PolyfenceSystemStatus.fromMap({'osGeofenceRegistrationHealth': null})
              .osGeofenceRegistrationHealth,
          isNull,
        );
      });

      test('parses a cap hit without treating it as an error', () {
        final status = PolyfenceSystemStatus.fromMap({
          'osGeofenceRegistrationHealth': {
            'requested': 40,
            'registered': 20,
            'lastError': null,
          },
        });

        final health = status.osGeofenceRegistrationHealth;
        expect(health, isNotNull);
        expect(health!.requested, 40);
        expect(health.registered, 20);
        expect(health.lastError, isNull);
      });

      test('parses a denied background grant', () {
        final health = PolyfenceSystemStatus.fromMap({
          'osGeofenceRegistrationHealth': {
            'requested': 12,
            'registered': 0,
            'lastError': 'background_location_denied',
          },
        }).osGeofenceRegistrationHealth;

        expect(health!.lastError, 'background_location_denied');
        expect(health.registered, 0);
      });

      test('round-trips through toMap and participates in equality', () {
        final status = PolyfenceSystemStatus(
          isLocationPermissionGranted: true,
          isBackgroundLocationEnabled: false,
          isBatteryOptimizationDisabled: false,
          isGpsEnabled: true,
          isWakeLockAcquired: false,
          lastKnownAccuracy: 10.0,
          lastLocationUpdate: DateTime.fromMillisecondsSinceEpoch(0),
          platformVersion: 'Android 12',
          pluginVersion: '2.2.0',
          osGeofenceRegistrationHealth: const OsGeofenceRegistrationHealth(
            requested: 8,
            registered: 8,
          ),
        );

        final restored = PolyfenceSystemStatus.fromMap(status.toMap());

        expect(restored, status);
        expect(restored.hashCode, status.hashCode);
        expect(restored.osGeofenceRegistrationHealth!.registered, 8);
      });
    });
  });

  group('PolyfencePerformanceMetrics', () {
    test('fromMap/toMap round-trip', () {
      final metrics = PolyfencePerformanceMetrics(
        uptime: const Duration(hours: 2, minutes: 30),
        totalLocationUpdates: 500,
        totalZoneDetections: 12,
timedZoneDetections: 12,
        averageDetectionLatency: 45.5,
        memoryUsageMB: 25,
        restartCount: 1,
      );

      final map = metrics.toMap();
      final restored = PolyfencePerformanceMetrics.fromMap(map);

      expect(restored.uptime, const Duration(hours: 2, minutes: 30));
      expect(restored.totalLocationUpdates, 500);
      expect(restored.totalZoneDetections, 12);
      expect(restored.averageDetectionLatency, 45.5);
      expect(restored.memoryUsageMB, 25);
      expect(restored.restartCount, 1);
    });

    test('fromMap uses defaults for missing fields', () {
      final metrics = PolyfencePerformanceMetrics.fromMap({});

      expect(metrics.uptime, Duration.zero);
      expect(metrics.totalLocationUpdates, 0);
      expect(metrics.totalZoneDetections, 0);
      expect(metrics.timedZoneDetections, 0);
      // Absent, not zero: zero is the best possible latency, so defaulting
      // would make a device that has measured nothing look perfect.
      expect(metrics.averageDetectionLatency, isNull);
    });
  });

  group('PolyfenceBatteryMetrics', () {
    test('fromMap/toMap round-trip', () {
      final metrics = PolyfenceBatteryMetrics(
        isCharging: true,
        batteryLevel: 85,
        totalActiveTime: const Duration(hours: 3),
      );

      final map = metrics.toMap();
      final restored = PolyfenceBatteryMetrics.fromMap(map);
      expect(restored.isCharging, true);
      expect(restored.batteryLevel, 85);
      expect(restored.totalActiveTime, const Duration(hours: 3));
    });

    test('fromMap uses defaults for missing fields', () {
      final metrics = PolyfenceBatteryMetrics.fromMap({});
      expect(metrics.isCharging, false);
      // Absent, not zero — the platform has not reported a level.
      expect(metrics.batteryLevel, isNull);
    });
  });

  group('PolyfenceZoneStatus', () {
    test('fromMap/toMap round-trip', () {
      final ts = DateTime(2024, 6, 15, 12, 0, 0);
      final status = PolyfenceZoneStatus(
        activeZones: 5,
        circleZones: 3,
        polygonZones: 2,
      );

      final map = status.toMap();
      final restored = PolyfenceZoneStatus.fromMap(map);

      expect(restored.activeZones, 5);
      expect(restored.circleZones, 3);
      expect(restored.polygonZones, 2);
    });

    test('fromMap uses defaults for missing fields', () {
      final status = PolyfenceZoneStatus.fromMap({});

      expect(status.activeZones, 0);
      expect(status.circleZones, 0);
      expect(status.polygonZones, 0);
    });
  });

  group('PolyfenceErrorSummary', () {
    test('fromMap/toMap round-trip', () {
      final ts = DateTime(2024, 6, 15, 12, 0, 0);
      final summary = PolyfenceErrorSummary(
        type: 'gpsTimeout',
        message: 'GPS timed out after 30s',
        timestamp: ts,
        correlationId: 'req-123',
        context: {'timeoutMs': 30000},
      );

      final map = summary.toMap();
      final restored = PolyfenceErrorSummary.fromMap(map);

      expect(restored.type, 'gpsTimeout');
      expect(restored.message, 'GPS timed out after 30s');
      expect(restored.timestamp, ts);
      expect(restored.correlationId, 'req-123');
      expect(restored.context['timeoutMs'], 30000);
    });

    test('fromMap uses defaults for missing fields', () {
      final summary = PolyfenceErrorSummary.fromMap({});

      expect(summary.type, 'unknown');
      expect(summary.message, '');
      expect(summary.correlationId, isNull);
      expect(summary.context, isEmpty);
    });
  });

  group('PolyfenceDebugInfo', () {
    test('fromMap/toMap round-trip', () {
      final ts = DateTime(2024, 6, 15, 12, 0, 0);
      final debugInfo = PolyfenceDebugInfo(
        systemStatus: PolyfenceSystemStatus(
          isLocationPermissionGranted: true,
          isBackgroundLocationEnabled: true,
          isBatteryOptimizationDisabled: false,
          isGpsEnabled: true,
          isWakeLockAcquired: false,
          lastKnownAccuracy: 10.0,
          lastLocationUpdate: ts,
          platformVersion: 'iOS 17',
          pluginVersion: '2.0.0',
        ),
        performance: PolyfencePerformanceMetrics(
          uptime: const Duration(hours: 1),
          totalLocationUpdates: 100,
          totalZoneDetections: 5,
timedZoneDetections: 5,
          averageDetectionLatency: 30.0,
          memoryUsageMB: 10,
          restartCount: 0,
        ),
        battery: PolyfenceBatteryMetrics(
          isCharging: false,
          batteryLevel: 72,
          totalActiveTime: const Duration(hours: 1),
        ),
        zones: PolyfenceZoneStatus(
          activeZones: 3,
          circleZones: 2,
          polygonZones: 1,
        ),
        recentErrors: [
          PolyfenceErrorSummary(
            type: 'gpsTimeout',
            message: 'Timeout',
            timestamp: ts,
            context: {},
          ),
        ],
      );

      final map = debugInfo.toMap();
      final restored = PolyfenceDebugInfo.fromMap(map);

      expect(restored.systemStatus.pluginVersion, '2.0.0');
      expect(restored.performance.totalZoneDetections, 5);
      expect(restored.battery.batteryLevel, 72);
      expect(restored.zones.activeZones, 3);
      expect(restored.recentErrors.length, 1);
      expect(restored.recentErrors[0].type, 'gpsTimeout');
    });

    test('fromMap parses the polyfence-core collector debugInfo shape', () {
      // Golden fixture: this is the exact shape
      // `PolyfenceDebugCollector.collectDebugInfo()` returns on both
      // Android and iOS (see polyfence-core/ios/Classes/
      // PolyfenceDebugCollector.swift:30 and the Android counterpart).
      // The Flutter iOS and Android bridges delegate to that collector
      // on getDebugInfo. Locking the shape here prevents a silent
      // regression if a future collector change drops a key.
      final map = <String, dynamic>{
        'systemStatus': {
          'isLocationPermissionGranted': true,
          'isBackgroundLocationEnabled': true,
          'isBatteryOptimizationDisabled': true,
          'isGpsEnabled': true,
          'isWakeLockAcquired': false,
          'lastKnownAccuracy': 12.5,
          'lastLocationUpdate': 1700000000000,
          'platformVersion': '17.4',
          'pluginVersion': '2.1.0',
        },
        'performance': {
          'uptime': 300000, // real value from sessionStartTime
          'totalLocationUpdates': 0,
          'totalZoneDetections': 0,
          'averageDetectionLatency': 0.0,
          'memoryUsageMB': 42, // real value from mach_task_basic_info
          'restartCount': 0,
        },
        'battery': {
          'isCharging': false,
          'batteryLevel': 85,
          'totalActiveTime': 300000, // real session-elapsed ms
        },
        'zones': {
          'activeZones': 0,
          'circleZones': 0,
          'polygonZones': 0,
        },
        'recentErrors': <Map<String, dynamic>>[
          {
            'type': 'gpsTimeout',
            'message': 'GPS timeout',
            'timestamp': 1700000000000,
            'context': <String, dynamic>{},
          },
        ],
      };

      final debugInfo = PolyfenceDebugInfo.fromMap(map);

      expect(debugInfo.systemStatus.platformVersion, '17.4');
      expect(debugInfo.systemStatus.pluginVersion, '2.1.0');
      expect(debugInfo.performance.uptime,
          const Duration(milliseconds: 300000));
      expect(debugInfo.performance.memoryUsageMB, 42);
      expect(debugInfo.battery.totalActiveTime,
          const Duration(milliseconds: 300000));
      expect(debugInfo.battery.batteryLevel, 85);
      expect(debugInfo.recentErrors, hasLength(1));
      expect(debugInfo.recentErrors.single.type, 'gpsTimeout');
    });
  });
}
