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
  });

  group('PolyfencePerformanceMetrics', () {
    test('fromMap/toMap round-trip', () {
      final metrics = PolyfencePerformanceMetrics(
        uptime: const Duration(hours: 2, minutes: 30),
        totalLocationUpdates: 500,
        totalZoneDetections: 12,
        averageDetectionLatency: 45.5,
        memoryUsageMB: 25,
        cpuUsagePercent: 3.2,
        restartCount: 1,
      );

      final map = metrics.toMap();
      final restored = PolyfencePerformanceMetrics.fromMap(map);

      expect(restored.uptime, const Duration(hours: 2, minutes: 30));
      expect(restored.totalLocationUpdates, 500);
      expect(restored.totalZoneDetections, 12);
      expect(restored.averageDetectionLatency, 45.5);
      expect(restored.memoryUsageMB, 25);
      expect(restored.cpuUsagePercent, 3.2);
      expect(restored.restartCount, 1);
    });

    test('fromMap uses defaults for missing fields', () {
      final metrics = PolyfencePerformanceMetrics.fromMap({});

      expect(metrics.uptime, Duration.zero);
      expect(metrics.totalLocationUpdates, 0);
      expect(metrics.totalZoneDetections, 0);
      expect(metrics.averageDetectionLatency, 0.0);
    });
  });

  group('PolyfenceBatteryMetrics', () {
    test('fromMap/toMap round-trip', () {
      final metrics = PolyfenceBatteryMetrics(
        estimatedHourlyDrain: 2.5,
        gpsActiveTimePercent: 40,
        wakeUpCount: 15,
        isCharging: true,
        batteryLevel: 85,
        totalActiveTime: const Duration(hours: 3),
      );

      final map = metrics.toMap();
      final restored = PolyfenceBatteryMetrics.fromMap(map);

      expect(restored.estimatedHourlyDrain, 2.5);
      expect(restored.gpsActiveTimePercent, 40);
      expect(restored.wakeUpCount, 15);
      expect(restored.isCharging, true);
      expect(restored.batteryLevel, 85);
      expect(restored.totalActiveTime, const Duration(hours: 3));
    });

    test('fromMap uses defaults for missing fields', () {
      final metrics = PolyfenceBatteryMetrics.fromMap({});

      expect(metrics.estimatedHourlyDrain, 0.0);
      expect(metrics.isCharging, false);
      expect(metrics.batteryLevel, 0);
    });
  });

  group('PolyfenceZoneStatus', () {
    test('fromMap/toMap round-trip', () {
      final ts = DateTime(2024, 6, 15, 12, 0, 0);
      final status = PolyfenceZoneStatus(
        activeZones: 5,
        circleZones: 3,
        polygonZones: 2,
        lastZoneUpdate: ts,
        zoneEventCounts: {'zone-1': 10, 'zone-2': 5},
      );

      final map = status.toMap();
      final restored = PolyfenceZoneStatus.fromMap(map);

      expect(restored.activeZones, 5);
      expect(restored.circleZones, 3);
      expect(restored.polygonZones, 2);
      expect(restored.lastZoneUpdate, ts);
      expect(restored.zoneEventCounts['zone-1'], 10);
      expect(restored.zoneEventCounts['zone-2'], 5);
    });

    test('fromMap uses defaults for missing fields', () {
      final status = PolyfenceZoneStatus.fromMap({});

      expect(status.activeZones, 0);
      expect(status.circleZones, 0);
      expect(status.polygonZones, 0);
      expect(status.zoneEventCounts, isEmpty);
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
          averageDetectionLatency: 30.0,
          memoryUsageMB: 10,
          cpuUsagePercent: 1.5,
          restartCount: 0,
        ),
        battery: PolyfenceBatteryMetrics(
          estimatedHourlyDrain: 1.5,
          gpsActiveTimePercent: 30,
          wakeUpCount: 5,
          isCharging: false,
          batteryLevel: 72,
          totalActiveTime: const Duration(hours: 1),
        ),
        zones: PolyfenceZoneStatus(
          activeZones: 3,
          circleZones: 2,
          polygonZones: 1,
          lastZoneUpdate: ts,
          zoneEventCounts: {'z1': 3},
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
  });
}
