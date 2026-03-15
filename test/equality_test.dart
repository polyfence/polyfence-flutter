import 'package:flutter_test/flutter_test.dart';
import 'package:polyfence/polyfence.dart';

void main() {
  group('PolyfenceLocation equality', () {
    test('equal instances with same values', () {
      final ts = DateTime(2024, 1, 1);
      final a = PolyfenceLocation(
        latitude: 51.5074,
        longitude: -0.1278,
        accuracy: 10.0,
        timestamp: ts,
      );
      final b = PolyfenceLocation(
        latitude: 51.5074,
        longitude: -0.1278,
        accuracy: 10.0,
        timestamp: ts,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('not equal when latitude differs', () {
      final a = PolyfenceLocation(latitude: 51.5074, longitude: -0.1278);
      final b = PolyfenceLocation(latitude: 51.5075, longitude: -0.1278);

      expect(a, isNot(equals(b)));
    });

    test('not equal when optional field differs', () {
      final a = PolyfenceLocation(
          latitude: 51.5074, longitude: -0.1278, accuracy: 10.0);
      final b = PolyfenceLocation(
          latitude: 51.5074, longitude: -0.1278, accuracy: 20.0);

      expect(a, isNot(equals(b)));
    });

    test('equal with all fields populated', () {
      final ts = DateTime(2024, 1, 1);
      final a = PolyfenceLocation(
        latitude: 51.5074,
        longitude: -0.1278,
        altitude: 100.0,
        accuracy: 10.0,
        timestamp: ts,
        speed: 5.0,
        interval: 1000,
        isFallback: false,
        activity: 'walking',
      );
      final b = PolyfenceLocation(
        latitude: 51.5074,
        longitude: -0.1278,
        altitude: 100.0,
        accuracy: 10.0,
        timestamp: ts,
        speed: 5.0,
        interval: 1000,
        isFallback: false,
        activity: 'walking',
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('identical instance is equal', () {
      final a = PolyfenceLocation(latitude: 51.5074, longitude: -0.1278);
      expect(a, equals(a));
    });

    test('not equal to different type', () {
      final a = PolyfenceLocation(latitude: 51.5074, longitude: -0.1278);
      expect(a, isNot(equals('not a location')));
    });
  });

  group('Zone equality', () {
    test('equal circle zones with same values', () {
      final a = Zone.circle(
        id: 'office',
        name: 'Office',
        center: PolyfenceLocation(latitude: 37.422, longitude: -122.084),
        radius: 150.0,
      );
      final b = Zone.circle(
        id: 'office',
        name: 'Office',
        center: PolyfenceLocation(latitude: 37.422, longitude: -122.084),
        radius: 150.0,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('not equal when id differs', () {
      final a = Zone.circle(
        id: 'office-1',
        name: 'Office',
        center: PolyfenceLocation(latitude: 37.422, longitude: -122.084),
        radius: 150.0,
      );
      final b = Zone.circle(
        id: 'office-2',
        name: 'Office',
        center: PolyfenceLocation(latitude: 37.422, longitude: -122.084),
        radius: 150.0,
      );

      expect(a, isNot(equals(b)));
    });

    test('equal polygon zones with same coordinates', () {
      final points = [
        PolyfenceLocation(latitude: 37.422, longitude: -122.084),
        PolyfenceLocation(latitude: 37.423, longitude: -122.085),
        PolyfenceLocation(latitude: 37.424, longitude: -122.086),
      ];
      final pointsCopy = [
        PolyfenceLocation(latitude: 37.422, longitude: -122.084),
        PolyfenceLocation(latitude: 37.423, longitude: -122.085),
        PolyfenceLocation(latitude: 37.424, longitude: -122.086),
      ];

      final a = Zone.polygon(id: 'campus', name: 'Campus', polygon: points);
      final b = Zone.polygon(id: 'campus', name: 'Campus', polygon: pointsCopy);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('not equal polygon zones with different coordinates', () {
      final a = Zone.polygon(
        id: 'campus',
        name: 'Campus',
        polygon: [
          PolyfenceLocation(latitude: 37.422, longitude: -122.084),
          PolyfenceLocation(latitude: 37.423, longitude: -122.085),
          PolyfenceLocation(latitude: 37.424, longitude: -122.086),
        ],
      );
      final b = Zone.polygon(
        id: 'campus',
        name: 'Campus',
        polygon: [
          PolyfenceLocation(latitude: 37.422, longitude: -122.084),
          PolyfenceLocation(latitude: 37.423, longitude: -122.085),
          PolyfenceLocation(latitude: 37.999, longitude: -122.999),
        ],
      );

      expect(a, isNot(equals(b)));
    });

    test('equal zones with same metadata', () {
      final a = Zone.circle(
        id: 'z1',
        name: 'Z1',
        center: PolyfenceLocation(latitude: 0, longitude: 0),
        radius: 100,
        metadata: {'color': 'red', 'priority': 1},
      );
      final b = Zone.circle(
        id: 'z1',
        name: 'Z1',
        center: PolyfenceLocation(latitude: 0, longitude: 0),
        radius: 100,
        metadata: {'color': 'red', 'priority': 1},
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('not equal zones with different metadata', () {
      final a = Zone.circle(
        id: 'z1',
        name: 'Z1',
        center: PolyfenceLocation(latitude: 0, longitude: 0),
        radius: 100,
        metadata: {'color': 'red'},
      );
      final b = Zone.circle(
        id: 'z1',
        name: 'Z1',
        center: PolyfenceLocation(latitude: 0, longitude: 0),
        radius: 100,
        metadata: {'color': 'blue'},
      );

      expect(a, isNot(equals(b)));
    });

    test('zone can be used in Set for deduplication', () {
      final a = Zone.circle(
        id: 'z1',
        name: 'Z1',
        center: PolyfenceLocation(latitude: 0, longitude: 0),
        radius: 100,
      );
      final b = Zone.circle(
        id: 'z1',
        name: 'Z1',
        center: PolyfenceLocation(latitude: 0, longitude: 0),
        radius: 100,
      );

      final set = {a, b};
      expect(set.length, equals(1));
    });
  });

  group('GeofenceEvent equality', () {
    test('equal events with same values', () {
      final ts = DateTime(2024, 1, 1);
      final loc = PolyfenceLocation(latitude: 37.422, longitude: -122.084);

      final a = GeofenceEvent(
        zoneId: 'z1',
        type: GeofenceEventType.enter,
        location: loc,
        timestamp: ts,
      );
      final b = GeofenceEvent(
        zoneId: 'z1',
        type: GeofenceEventType.enter,
        location: PolyfenceLocation(latitude: 37.422, longitude: -122.084),
        timestamp: ts,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('not equal when event type differs', () {
      final ts = DateTime(2024, 1, 1);
      final loc = PolyfenceLocation(latitude: 37.422, longitude: -122.084);

      final a = GeofenceEvent(
        zoneId: 'z1',
        type: GeofenceEventType.enter,
        location: loc,
        timestamp: ts,
      );
      final b = GeofenceEvent(
        zoneId: 'z1',
        type: GeofenceEventType.exit,
        location: loc,
        timestamp: ts,
      );

      expect(a, isNot(equals(b)));
    });
  });

  group('PolyfenceError equality', () {
    test('equal errors with same values', () {
      final ts = DateTime(2024, 1, 1);

      final a = PolyfenceError(
        type: PolyfenceErrorType.gpsTimeout,
        message: 'GPS timed out',
        context: {'zoneId': 'z1'},
        timestamp: ts,
      );
      final b = PolyfenceError(
        type: PolyfenceErrorType.gpsTimeout,
        message: 'GPS timed out',
        context: {'zoneId': 'z1'},
        timestamp: ts,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('not equal when type differs', () {
      final ts = DateTime(2024, 1, 1);

      final a = PolyfenceError(
        type: PolyfenceErrorType.gpsTimeout,
        message: 'Error',
        context: {},
        timestamp: ts,
      );
      final b = PolyfenceError(
        type: PolyfenceErrorType.gpsPermissionDenied,
        message: 'Error',
        context: {},
        timestamp: ts,
      );

      expect(a, isNot(equals(b)));
    });

    test('not equal when context differs', () {
      final ts = DateTime(2024, 1, 1);

      final a = PolyfenceError(
        type: PolyfenceErrorType.unknown,
        message: 'Error',
        context: {'key': 'value1'},
        timestamp: ts,
      );
      final b = PolyfenceError(
        type: PolyfenceErrorType.unknown,
        message: 'Error',
        context: {'key': 'value2'},
        timestamp: ts,
      );

      expect(a, isNot(equals(b)));
    });

    test('equal with correlationId', () {
      final ts = DateTime(2024, 1, 1);

      final a = PolyfenceError(
        type: PolyfenceErrorType.unknown,
        message: 'Error',
        context: {},
        timestamp: ts,
        correlationId: 'abc-123',
      );
      final b = PolyfenceError(
        type: PolyfenceErrorType.unknown,
        message: 'Error',
        context: {},
        timestamp: ts,
        correlationId: 'abc-123',
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('PolyfenceRuntimeStatus equality', () {
    test('equal instances', () {
      final ts = DateTime(2024, 1, 1);
      final a = PolyfenceRuntimeStatus(
        intervalMs: 5000,
        nearestZoneDistanceM: 150.0,
        timestamp: ts,
        currentGpsAccuracy: 10.0,
        secondsSinceLastGpsFix: 0,
        gpsAvailabilityDrops5Min: 0,
      );
      final b = PolyfenceRuntimeStatus(
        intervalMs: 5000,
        nearestZoneDistanceM: 150.0,
        timestamp: ts,
        currentGpsAccuracy: 10.0,
        secondsSinceLastGpsFix: 0,
        gpsAvailabilityDrops5Min: 0,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('not equal when interval differs', () {
      final ts = DateTime(2024, 1, 1);
      final a = PolyfenceRuntimeStatus(
        intervalMs: 5000,
        nearestZoneDistanceM: 150.0,
        timestamp: ts,
        currentGpsAccuracy: 10.0,
        secondsSinceLastGpsFix: 0,
        gpsAvailabilityDrops5Min: 0,
      );
      final b = PolyfenceRuntimeStatus(
        intervalMs: 10000,
        nearestZoneDistanceM: 150.0,
        timestamp: ts,
        currentGpsAccuracy: 10.0,
        secondsSinceLastGpsFix: 0,
        gpsAvailabilityDrops5Min: 0,
      );

      expect(a, isNot(equals(b)));
    });
  });

  group('PolyfenceConfiguration equality', () {
    test('equal default configurations', () {
      final a = PolyfenceConfiguration();
      final b = PolyfenceConfiguration();

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('equal with same sub-settings', () {
      final a = PolyfenceConfiguration(
        accuracyProfile: PolyfenceAccuracyProfile.balanced,
        updateStrategy: PolyfenceUpdateStrategy.proximityBased,
        proximitySettings: ProximitySettings(
          nearZoneThresholdMeters: 500,
          farZoneThresholdMeters: 2000,
        ),
        dwellSettings:
            DwellSettings(dwellThreshold: const Duration(minutes: 3)),
      );
      final b = PolyfenceConfiguration(
        accuracyProfile: PolyfenceAccuracyProfile.balanced,
        updateStrategy: PolyfenceUpdateStrategy.proximityBased,
        proximitySettings: ProximitySettings(
          nearZoneThresholdMeters: 500,
          farZoneThresholdMeters: 2000,
        ),
        dwellSettings:
            DwellSettings(dwellThreshold: const Duration(minutes: 3)),
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('not equal when accuracy profile differs', () {
      final a = PolyfenceConfiguration(
          accuracyProfile: PolyfenceAccuracyProfile.maxAccuracy);
      final b = PolyfenceConfiguration(
          accuracyProfile: PolyfenceAccuracyProfile.balanced);

      expect(a, isNot(equals(b)));
    });

    test('not equal when sub-settings differ', () {
      final a = PolyfenceConfiguration(
        dwellSettings:
            DwellSettings(dwellThreshold: const Duration(minutes: 3)),
      );
      final b = PolyfenceConfiguration(
        dwellSettings:
            DwellSettings(dwellThreshold: const Duration(minutes: 5)),
      );

      expect(a, isNot(equals(b)));
    });

    test('not equal when one has sub-settings and other does not', () {
      final a = PolyfenceConfiguration(
        proximitySettings: ProximitySettings(),
      );
      final b = PolyfenceConfiguration();

      expect(a, isNot(equals(b)));
    });
  });

  group('ProximitySettings equality', () {
    test('equal with same values', () {
      final a = ProximitySettings(
        nearZoneThresholdMeters: 500,
        farZoneThresholdMeters: 2000,
      );
      final b = ProximitySettings(
        nearZoneThresholdMeters: 500,
        farZoneThresholdMeters: 2000,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('MovementSettings equality', () {
    test('equal with same values', () {
      final a = MovementSettings(movementThresholdMeters: 50.0);
      final b = MovementSettings(movementThresholdMeters: 50.0);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('BatterySettings equality', () {
    test('equal with same values', () {
      final a = BatterySettings(
          lowBatteryThreshold: 20, criticalBatteryThreshold: 10);
      final b = BatterySettings(
          lowBatteryThreshold: 20, criticalBatteryThreshold: 10);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('not equal when threshold differs', () {
      final a = BatterySettings(
          lowBatteryThreshold: 20, criticalBatteryThreshold: 10);
      final b = BatterySettings(
          lowBatteryThreshold: 30, criticalBatteryThreshold: 10);

      expect(a, isNot(equals(b)));
    });
  });

  group('DwellSettings equality', () {
    test('equal with same values', () {
      final a = DwellSettings(dwellThreshold: const Duration(minutes: 5));
      final b = DwellSettings(dwellThreshold: const Duration(minutes: 5));

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('ClusterSettings equality', () {
    test('equal with same values', () {
      final a = ClusterSettings(activeRadiusMeters: 5000);
      final b = ClusterSettings(activeRadiusMeters: 5000);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('TimeOfDay equality', () {
    test('equal with same hour and minute', () {
      final a = TimeOfDay(hour: 9, minute: 30);
      final b = TimeOfDay(hour: 9, minute: 30);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('not equal when hour differs', () {
      final a = TimeOfDay(hour: 9, minute: 30);
      final b = TimeOfDay(hour: 10, minute: 30);

      expect(a, isNot(equals(b)));
    });
  });

  group('TimeWindow equality', () {
    test('equal with same values and daysOfWeek', () {
      final a = TimeWindow(
        startTime: TimeOfDay(hour: 9, minute: 0),
        endTime: TimeOfDay(hour: 17, minute: 0),
        daysOfWeek: [1, 2, 3, 4, 5],
      );
      final b = TimeWindow(
        startTime: TimeOfDay(hour: 9, minute: 0),
        endTime: TimeOfDay(hour: 17, minute: 0),
        daysOfWeek: [1, 2, 3, 4, 5],
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('not equal when daysOfWeek differs', () {
      final a = TimeWindow(
        startTime: TimeOfDay(hour: 9, minute: 0),
        endTime: TimeOfDay(hour: 17, minute: 0),
        daysOfWeek: [1, 2, 3],
      );
      final b = TimeWindow(
        startTime: TimeOfDay(hour: 9, minute: 0),
        endTime: TimeOfDay(hour: 17, minute: 0),
        daysOfWeek: [4, 5, 6],
      );

      expect(a, isNot(equals(b)));
    });
  });

  group('ScheduleSettings equality', () {
    test('equal with same timeWindows', () {
      final window = TimeWindow(
        startTime: TimeOfDay(hour: 9, minute: 0),
        endTime: TimeOfDay(hour: 17, minute: 0),
      );
      final a = ScheduleSettings(enabled: true, timeWindows: [window]);
      final b = ScheduleSettings(
        enabled: true,
        timeWindows: [
          TimeWindow(
            startTime: TimeOfDay(hour: 9, minute: 0),
            endTime: TimeOfDay(hour: 17, minute: 0),
          )
        ],
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('ActivitySettings equality', () {
    test('equal with same values', () {
      final a = ActivitySettings(
        enabled: true,
        confidenceThreshold: 80,
        stillInterval: const Duration(seconds: 120),
      );
      final b = ActivitySettings(
        enabled: true,
        confidenceThreshold: 80,
        stillInterval: const Duration(seconds: 120),
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('not equal when interval differs', () {
      final a = ActivitySettings(
        enabled: true,
        stillInterval: const Duration(seconds: 120),
      );
      final b = ActivitySettings(
        enabled: true,
        stillInterval: const Duration(seconds: 60),
      );

      expect(a, isNot(equals(b)));
    });
  });

  group('PolyfenceDebugInfo equality', () {
    PolyfenceDebugInfo makeDebugInfo({
      int activeZones = 5,
      String errorType = 'gps_timeout',
    }) {
      final ts = DateTime(2024, 1, 1);
      return PolyfenceDebugInfo(
        systemStatus: PolyfenceSystemStatus(
          isLocationPermissionGranted: true,
          isBackgroundLocationEnabled: true,
          isBatteryOptimizationDisabled: false,
          isGpsEnabled: true,
          isWakeLockAcquired: false,
          lastKnownAccuracy: 10.0,
          lastLocationUpdate: ts,
          platformVersion: 'Android 14',
          pluginVersion: '0.2.1',
        ),
        performance: PolyfencePerformanceMetrics(
          uptime: const Duration(hours: 1),
          totalLocationUpdates: 100,
          totalZoneDetections: 10,
          averageDetectionLatency: 15.0,
          memoryUsageMB: 50,
          cpuUsagePercent: 2.5,
          restartCount: 0,
        ),
        battery: PolyfenceBatteryMetrics(
          estimatedHourlyDrain: 3.5,
          gpsActiveTimePercent: 80,
          wakeUpCount: 5,
          isCharging: false,
          batteryLevel: 75,
          totalActiveTime: const Duration(hours: 1),
        ),
        zones: PolyfenceZoneStatus(
          activeZones: activeZones,
          circleZones: 3,
          polygonZones: 2,
          lastZoneUpdate: ts,
          zoneEventCounts: {'z1': 5, 'z2': 3},
        ),
        recentErrors: [
          PolyfenceErrorSummary(
            type: errorType,
            message: 'Test error',
            timestamp: ts,
            context: {'key': 'value'},
          ),
        ],
      );
    }

    test('equal debug info instances', () {
      final a = makeDebugInfo();
      final b = makeDebugInfo();

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('not equal when nested field differs', () {
      final a = makeDebugInfo(activeZones: 5);
      final b = makeDebugInfo(activeZones: 10);

      expect(a, isNot(equals(b)));
    });

    test('not equal when error list differs', () {
      final a = makeDebugInfo(errorType: 'gps_timeout');
      final b = makeDebugInfo(errorType: 'permission_revoked');

      expect(a, isNot(equals(b)));
    });
  });

  group('PolyfenceSystemStatus equality', () {
    test('equal instances', () {
      final ts = DateTime(2024, 1, 1);
      final a = PolyfenceSystemStatus(
        isLocationPermissionGranted: true,
        isBackgroundLocationEnabled: true,
        isBatteryOptimizationDisabled: false,
        isGpsEnabled: true,
        isWakeLockAcquired: false,
        lastKnownAccuracy: 10.0,
        lastLocationUpdate: ts,
        platformVersion: 'Android 14',
        pluginVersion: '0.2.1',
      );
      final b = PolyfenceSystemStatus(
        isLocationPermissionGranted: true,
        isBackgroundLocationEnabled: true,
        isBatteryOptimizationDisabled: false,
        isGpsEnabled: true,
        isWakeLockAcquired: false,
        lastKnownAccuracy: 10.0,
        lastLocationUpdate: ts,
        platformVersion: 'Android 14',
        pluginVersion: '0.2.1',
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('PolyfencePerformanceMetrics equality', () {
    test('equal instances', () {
      final a = PolyfencePerformanceMetrics(
        uptime: const Duration(hours: 1),
        totalLocationUpdates: 100,
        totalZoneDetections: 10,
        averageDetectionLatency: 15.0,
        memoryUsageMB: 50,
        cpuUsagePercent: 2.5,
        restartCount: 0,
      );
      final b = PolyfencePerformanceMetrics(
        uptime: const Duration(hours: 1),
        totalLocationUpdates: 100,
        totalZoneDetections: 10,
        averageDetectionLatency: 15.0,
        memoryUsageMB: 50,
        cpuUsagePercent: 2.5,
        restartCount: 0,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('PolyfenceBatteryMetrics equality', () {
    test('equal instances', () {
      final a = PolyfenceBatteryMetrics(
        estimatedHourlyDrain: 3.5,
        gpsActiveTimePercent: 80,
        wakeUpCount: 5,
        isCharging: false,
        batteryLevel: 75,
        totalActiveTime: const Duration(hours: 1),
      );
      final b = PolyfenceBatteryMetrics(
        estimatedHourlyDrain: 3.5,
        gpsActiveTimePercent: 80,
        wakeUpCount: 5,
        isCharging: false,
        batteryLevel: 75,
        totalActiveTime: const Duration(hours: 1),
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('PolyfenceZoneStatus equality', () {
    test('equal instances with same map', () {
      final ts = DateTime(2024, 1, 1);
      final a = PolyfenceZoneStatus(
        activeZones: 5,
        circleZones: 3,
        polygonZones: 2,
        lastZoneUpdate: ts,
        zoneEventCounts: {'z1': 5, 'z2': 3},
      );
      final b = PolyfenceZoneStatus(
        activeZones: 5,
        circleZones: 3,
        polygonZones: 2,
        lastZoneUpdate: ts,
        zoneEventCounts: {'z1': 5, 'z2': 3},
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('not equal when map differs', () {
      final ts = DateTime(2024, 1, 1);
      final a = PolyfenceZoneStatus(
        activeZones: 5,
        circleZones: 3,
        polygonZones: 2,
        lastZoneUpdate: ts,
        zoneEventCounts: {'z1': 5},
      );
      final b = PolyfenceZoneStatus(
        activeZones: 5,
        circleZones: 3,
        polygonZones: 2,
        lastZoneUpdate: ts,
        zoneEventCounts: {'z1': 10},
      );

      expect(a, isNot(equals(b)));
    });
  });

  group('PolyfenceErrorSummary equality', () {
    test('equal instances', () {
      final ts = DateTime(2024, 1, 1);
      final a = PolyfenceErrorSummary(
        type: 'gps_timeout',
        message: 'GPS timed out',
        timestamp: ts,
        correlationId: 'abc',
        context: {'zone': 'z1'},
      );
      final b = PolyfenceErrorSummary(
        type: 'gps_timeout',
        message: 'GPS timed out',
        timestamp: ts,
        correlationId: 'abc',
        context: {'zone': 'z1'},
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('hashCode consistency', () {
    test('PolyfenceLocation hashCode consistent across calls', () {
      final loc = PolyfenceLocation(latitude: 51.5074, longitude: -0.1278);
      final h1 = loc.hashCode;
      final h2 = loc.hashCode;
      expect(h1, equals(h2));
    });

    test('Zone hashCode consistent across calls', () {
      final zone = Zone.circle(
        id: 'z1',
        name: 'Z1',
        center: PolyfenceLocation(latitude: 0, longitude: 0),
        radius: 100,
      );
      final h1 = zone.hashCode;
      final h2 = zone.hashCode;
      expect(h1, equals(h2));
    });

    test('PolyfenceConfiguration hashCode consistent', () {
      final config = PolyfenceConfiguration(
        accuracyProfile: PolyfenceAccuracyProfile.adaptive,
        dwellSettings: DwellSettings(),
      );
      final h1 = config.hashCode;
      final h2 = config.hashCode;
      expect(h1, equals(h2));
    });
  });

  group('Map/Set usage', () {
    test('PolyfenceLocation works as Map key', () {
      final loc1 = PolyfenceLocation(latitude: 37.422, longitude: -122.084);
      final loc2 = PolyfenceLocation(latitude: 37.422, longitude: -122.084);

      final map = <PolyfenceLocation, String>{loc1: 'office'};
      expect(map[loc2], equals('office'));
    });

    test('Zone works in Set for deduplication', () {
      final zones = <Zone>{};
      for (var i = 0; i < 3; i++) {
        zones.add(Zone.circle(
          id: 'office',
          name: 'Office',
          center: PolyfenceLocation(latitude: 37.422, longitude: -122.084),
          radius: 150,
        ));
      }
      expect(zones.length, equals(1));
    });

    test('GeofenceEvent works in Set', () {
      final ts = DateTime(2024, 1, 1);
      final events = <GeofenceEvent>{};
      for (var i = 0; i < 2; i++) {
        events.add(GeofenceEvent(
          zoneId: 'z1',
          type: GeofenceEventType.enter,
          location: PolyfenceLocation(latitude: 37.422, longitude: -122.084),
          timestamp: ts,
        ));
      }
      expect(events.length, equals(1));
    });
  });
}
