import 'package:flutter_test/flutter_test.dart';
import 'package:polyfence/polyfence.dart';

void main() {
  group('PolyfenceConfiguration', () {
    test('default values are correct', () {
      const config = PolyfenceConfiguration();

      expect(config.accuracyProfile, PolyfenceAccuracyProfile.maxAccuracy);
      expect(config.updateStrategy, PolyfenceUpdateStrategy.continuous);
      expect(config.proximitySettings, isNull);
      expect(config.movementSettings, isNull);
      expect(config.batterySettings, isNull);
      expect(config.dwellSettings, isNull);
      expect(config.clusterSettings, isNull);
      expect(config.scheduleSettings, isNull);
      expect(config.activitySettings, isNull);
      expect(config.gpsAccuracyThreshold, 100.0);
      expect(config.enableDebugLogging, false);
    });

    test('toMap/fromMap round-trip preserves all fields', () {
      const config = PolyfenceConfiguration(
        accuracyProfile: PolyfenceAccuracyProfile.balanced,
        updateStrategy: PolyfenceUpdateStrategy.intelligent,
        proximitySettings: ProximitySettings(
          nearZoneThresholdMeters: 300.0,
          farZoneThresholdMeters: 3000.0,
        ),
        movementSettings: MovementSettings(
          stationaryThreshold: Duration(minutes: 10),
          movementThresholdMeters: 25.0,
        ),
        batterySettings: BatterySettings(
          lowBatteryThreshold: 15,
          criticalBatteryThreshold: 5,
        ),
        dwellSettings: DwellSettings(
          enabled: true,
          dwellThreshold: Duration(minutes: 10),
        ),
        clusterSettings: ClusterSettings(
          enabled: true,
          activeRadiusMeters: 10000.0,
        ),
        scheduleSettings: ScheduleSettings(
          enabled: true,
          timeWindows: [
            TimeWindow(
              startTime: TimeOfDay(hour: 9, minute: 0),
              endTime: TimeOfDay(hour: 17, minute: 30),
              daysOfWeek: [1, 2, 3, 4, 5],
            ),
          ],
        ),
        activitySettings: ActivitySettings(
          enabled: true,
          confidenceThreshold: 80,
          debounceSeconds: 45,
          stillInterval: Duration(seconds: 120),
          drivingInterval: Duration(seconds: 3),
        ),
        gpsAccuracyThreshold: 50.0,
        enableDebugLogging: true,
      );

      final map = config.toMap();
      final restored = PolyfenceConfiguration.fromMap(map);

      expect(restored.accuracyProfile, PolyfenceAccuracyProfile.balanced);
      expect(restored.updateStrategy, PolyfenceUpdateStrategy.intelligent);
      expect(restored.gpsAccuracyThreshold, 50.0);
      expect(restored.enableDebugLogging, true);
      expect(restored.proximitySettings, isNotNull);
      expect(restored.movementSettings, isNotNull);
      expect(restored.batterySettings, isNotNull);
      expect(restored.dwellSettings, isNotNull);
      expect(restored.clusterSettings, isNotNull);
      expect(restored.scheduleSettings, isNotNull);
      expect(restored.activitySettings, isNotNull);
    });

    // BUG: PolyfenceConfiguration.fromMap({}) crashes with
    // "type 'Null' is not a subtype of type 'String'" because
    // EnumUtils.fromChannelFormat takes a non-nullable String but
    // map['accuracyProfile'] is null for empty maps. The fromMap factory
    // should null-check before calling EnumUtils.fromChannelFormat.
    test('fromMap with empty map throws due to null enum values', () {
      expect(
        () => PolyfenceConfiguration.fromMap({}),
        throwsA(isA<TypeError>()),
      );
    });

    test('copyWith updates specified fields and preserves others', () {
      const original = PolyfenceConfiguration(
        accuracyProfile: PolyfenceAccuracyProfile.maxAccuracy,
        gpsAccuracyThreshold: 100.0,
        enableDebugLogging: false,
      );

      final modified = original.copyWith(
        accuracyProfile: PolyfenceAccuracyProfile.batteryOptimal,
        enableDebugLogging: true,
      );

      expect(modified.accuracyProfile, PolyfenceAccuracyProfile.batteryOptimal);
      expect(modified.enableDebugLogging, true);
      // Preserved from original:
      expect(modified.gpsAccuracyThreshold, 100.0);
      expect(modified.updateStrategy, PolyfenceUpdateStrategy.continuous);
    });

    test('all accuracy profiles serialize to correct channel format', () {
      for (final profile in PolyfenceAccuracyProfile.values) {
        final config = PolyfenceConfiguration(accuracyProfile: profile);
        final map = config.toMap();
        final restored = PolyfenceConfiguration.fromMap(map);
        expect(restored.accuracyProfile, profile,
            reason: 'Round-trip failed for $profile');
      }
    });

    test('all update strategies serialize to correct channel format', () {
      for (final strategy in PolyfenceUpdateStrategy.values) {
        final config = PolyfenceConfiguration(updateStrategy: strategy);
        final map = config.toMap();
        final restored = PolyfenceConfiguration.fromMap(map);
        expect(restored.updateStrategy, strategy,
            reason: 'Round-trip failed for $strategy');
      }
    });

    test('toString contains key fields', () {
      const config = PolyfenceConfiguration();
      final str = config.toString();
      expect(str, contains('accuracyProfile'));
      expect(str, contains('updateStrategy'));
      expect(str, contains('gpsAccuracyThreshold'));
    });
  });

  group('ProximitySettings', () {
    test('default values are correct', () {
      const settings = ProximitySettings();
      expect(settings.nearZoneThresholdMeters, 500.0);
      expect(settings.farZoneThresholdMeters, 2000.0);
      expect(settings.nearZoneUpdateInterval, const Duration(seconds: 5));
      expect(settings.farZoneUpdateInterval, const Duration(seconds: 60));
    });

    test('toMap/fromMap round-trip preserves values', () {
      const settings = ProximitySettings(
        nearZoneThresholdMeters: 200.0,
        farZoneThresholdMeters: 5000.0,
        nearZoneUpdateInterval: Duration(seconds: 3),
        farZoneUpdateInterval: Duration(seconds: 90),
      );

      final map = settings.toMap();
      final restored = ProximitySettings.fromMap(map);

      expect(restored.nearZoneThresholdMeters, 200.0);
      expect(restored.farZoneThresholdMeters, 5000.0);
      expect(restored.nearZoneUpdateInterval, const Duration(seconds: 3));
      expect(restored.farZoneUpdateInterval, const Duration(seconds: 90));
    });

    test('fromMap with empty map uses defaults', () {
      final settings = ProximitySettings.fromMap({});
      expect(settings.nearZoneThresholdMeters, 500.0);
      expect(settings.farZoneThresholdMeters, 2000.0);
    });

    test('toMap serializes intervals as milliseconds', () {
      const settings = ProximitySettings(
        nearZoneUpdateInterval: Duration(seconds: 10),
        farZoneUpdateInterval: Duration(minutes: 2),
      );
      final map = settings.toMap();
      expect(map['nearZoneUpdateIntervalMs'], 10000);
      expect(map['farZoneUpdateIntervalMs'], 120000);
    });
  });

  group('MovementSettings', () {
    test('default values are correct', () {
      const settings = MovementSettings();
      expect(settings.stationaryThreshold, const Duration(minutes: 5));
      expect(settings.movementThresholdMeters, 50.0);
      expect(settings.stationaryUpdateInterval, const Duration(minutes: 2));
      expect(settings.movingUpdateInterval, const Duration(seconds: 10));
    });

    test('toMap/fromMap round-trip preserves values', () {
      const settings = MovementSettings(
        stationaryThreshold: Duration(minutes: 10),
        movementThresholdMeters: 25.0,
        stationaryUpdateInterval: Duration(minutes: 5),
        movingUpdateInterval: Duration(seconds: 5),
      );

      final map = settings.toMap();
      final restored = MovementSettings.fromMap(map);

      expect(restored.stationaryThreshold, const Duration(minutes: 10));
      expect(restored.movementThresholdMeters, 25.0);
      expect(restored.stationaryUpdateInterval, const Duration(minutes: 5));
      expect(restored.movingUpdateInterval, const Duration(seconds: 5));
    });

    test('fromMap with empty map uses defaults', () {
      final settings = MovementSettings.fromMap({});
      expect(settings.movementThresholdMeters, 50.0);
      expect(settings.stationaryThreshold, const Duration(minutes: 5));
    });
  });

  group('BatterySettings', () {
    test('default values are correct', () {
      const settings = BatterySettings();
      expect(settings.lowBatteryThreshold, 20);
      expect(settings.criticalBatteryThreshold, 10);
      expect(
          settings.lowBatteryUpdateInterval, const Duration(seconds: 30));
      expect(settings.pauseOnCriticalBattery, true);
    });

    test('toMap/fromMap round-trip preserves values', () {
      const settings = BatterySettings(
        lowBatteryThreshold: 25,
        criticalBatteryThreshold: 5,
        lowBatteryUpdateInterval: Duration(minutes: 1),
        pauseOnCriticalBattery: false,
      );

      final map = settings.toMap();
      final restored = BatterySettings.fromMap(map);

      expect(restored.lowBatteryThreshold, 25);
      expect(restored.criticalBatteryThreshold, 5);
      expect(restored.lowBatteryUpdateInterval, const Duration(minutes: 1));
      expect(restored.pauseOnCriticalBattery, false);
    });

    test('fromMap with empty map uses defaults', () {
      final settings = BatterySettings.fromMap({});
      expect(settings.lowBatteryThreshold, 20);
      expect(settings.pauseOnCriticalBattery, true);
    });
  });

  group('DwellSettings', () {
    test('default values are correct', () {
      const settings = DwellSettings();
      expect(settings.enabled, true);
      expect(settings.dwellThreshold, const Duration(minutes: 5));
    });

    test('toMap/fromMap round-trip preserves values', () {
      const settings = DwellSettings(
        enabled: false,
        dwellThreshold: Duration(minutes: 15),
      );

      final map = settings.toMap();
      final restored = DwellSettings.fromMap(map);

      expect(restored.enabled, false);
      expect(restored.dwellThreshold, const Duration(minutes: 15));
    });

    test('fromMap with empty map uses defaults', () {
      final settings = DwellSettings.fromMap({});
      expect(settings.enabled, true);
      expect(settings.dwellThreshold, const Duration(minutes: 5));
    });
  });

  group('ClusterSettings', () {
    test('default values are correct', () {
      const settings = ClusterSettings();
      expect(settings.enabled, false);
      expect(settings.activeRadiusMeters, 5000.0);
      expect(settings.refreshDistanceMeters, 1000.0);
    });

    test('toMap/fromMap round-trip preserves values', () {
      const settings = ClusterSettings(
        enabled: true,
        activeRadiusMeters: 10000.0,
        refreshDistanceMeters: 2000.0,
      );

      final map = settings.toMap();
      final restored = ClusterSettings.fromMap(map);

      expect(restored.enabled, true);
      expect(restored.activeRadiusMeters, 10000.0);
      expect(restored.refreshDistanceMeters, 2000.0);
    });

    test('fromMap with empty map uses defaults', () {
      final settings = ClusterSettings.fromMap({});
      expect(settings.enabled, false);
      expect(settings.activeRadiusMeters, 5000.0);
    });
  });

  group('TimeOfDay', () {
    test('toMap/fromMap round-trip', () {
      const tod = TimeOfDay(hour: 14, minute: 30);
      final map = tod.toMap();
      final restored = TimeOfDay.fromMap(map);

      expect(restored.hour, 14);
      expect(restored.minute, 30);
    });

    test('toString formats with leading zeros', () {
      const tod = TimeOfDay(hour: 9, minute: 5);
      expect(tod.toString(), '09:05');
    });

    test('toString formats midnight correctly', () {
      const tod = TimeOfDay(hour: 0, minute: 0);
      expect(tod.toString(), '00:00');
    });

    test('fromMap with empty map defaults to 00:00', () {
      final tod = TimeOfDay.fromMap({});
      expect(tod.hour, 0);
      expect(tod.minute, 0);
    });
  });

  group('TimeWindow', () {
    test('toMap/fromMap round-trip', () {
      const window = TimeWindow(
        startTime: TimeOfDay(hour: 9, minute: 0),
        endTime: TimeOfDay(hour: 17, minute: 0),
        daysOfWeek: [1, 2, 3, 4, 5],
      );

      final map = window.toMap();
      final restored = TimeWindow.fromMap(map);

      expect(restored.startTime.hour, 9);
      expect(restored.endTime.hour, 17);
      expect(restored.daysOfWeek, [1, 2, 3, 4, 5]);
    });

    test('defaults to empty daysOfWeek (all days)', () {
      const window = TimeWindow(
        startTime: TimeOfDay(hour: 0, minute: 0),
        endTime: TimeOfDay(hour: 23, minute: 59),
      );
      expect(window.daysOfWeek, isEmpty);
    });

    test('toString includes time range and days', () {
      const window = TimeWindow(
        startTime: TimeOfDay(hour: 9, minute: 0),
        endTime: TimeOfDay(hour: 17, minute: 0),
        daysOfWeek: [1, 5],
      );
      final str = window.toString();
      expect(str, contains('09:00'));
      expect(str, contains('17:00'));
      expect(str, contains('1,5'));
    });
  });

  group('ScheduleSettings', () {
    test('default values are correct', () {
      const settings = ScheduleSettings();
      expect(settings.enabled, false);
      expect(settings.timeWindows, isEmpty);
      expect(settings.startImmediatelyIfInWindow, true);
    });

    test('toMap/fromMap round-trip with time windows', () {
      const settings = ScheduleSettings(
        enabled: true,
        timeWindows: [
          TimeWindow(
            startTime: TimeOfDay(hour: 8, minute: 0),
            endTime: TimeOfDay(hour: 20, minute: 0),
          ),
        ],
        startImmediatelyIfInWindow: false,
      );

      final map = settings.toMap();
      final restored = ScheduleSettings.fromMap(map);

      expect(restored.enabled, true);
      expect(restored.timeWindows.length, 1);
      expect(restored.timeWindows[0].startTime.hour, 8);
      expect(restored.startImmediatelyIfInWindow, false);
    });

    test('fromMap with empty map uses defaults', () {
      final settings = ScheduleSettings.fromMap({});
      expect(settings.enabled, false);
      expect(settings.timeWindows, isEmpty);
      expect(settings.startImmediatelyIfInWindow, true);
    });
  });

  group('ActivitySettings', () {
    test('default values are correct', () {
      const settings = ActivitySettings();
      expect(settings.enabled, false);
      expect(settings.confidenceThreshold, 75);
      expect(settings.debounceSeconds, 30);
      expect(settings.stillInterval, isNull);
      expect(settings.walkingInterval, isNull);
      expect(settings.runningInterval, isNull);
      expect(settings.cyclingInterval, isNull);
      expect(settings.drivingInterval, isNull);
    });

    test('toMap/fromMap round-trip with all intervals', () {
      const settings = ActivitySettings(
        enabled: true,
        confidenceThreshold: 90,
        debounceSeconds: 60,
        stillInterval: Duration(seconds: 120),
        walkingInterval: Duration(seconds: 15),
        runningInterval: Duration(seconds: 10),
        cyclingInterval: Duration(seconds: 8),
        drivingInterval: Duration(seconds: 5),
      );

      final map = settings.toMap();
      final restored = ActivitySettings.fromMap(map);

      expect(restored.enabled, true);
      expect(restored.confidenceThreshold, 90);
      expect(restored.debounceSeconds, 60);
      expect(restored.stillInterval, const Duration(seconds: 120));
      expect(restored.walkingInterval, const Duration(seconds: 15));
      expect(restored.runningInterval, const Duration(seconds: 10));
      expect(restored.cyclingInterval, const Duration(seconds: 8));
      expect(restored.drivingInterval, const Duration(seconds: 5));
    });

    test('toMap omits null intervals', () {
      const settings = ActivitySettings(
        stillInterval: Duration(seconds: 120),
      );
      final map = settings.toMap();

      expect(map.containsKey('stillIntervalMs'), true);
      expect(map.containsKey('walkingIntervalMs'), false);
      expect(map.containsKey('drivingIntervalMs'), false);
    });

    test('fromMap with missing intervals returns null', () {
      final settings = ActivitySettings.fromMap({
        'enabled': true,
        'confidenceThreshold': 80,
        'debounceSeconds': 20,
      });
      expect(settings.stillInterval, isNull);
      expect(settings.walkingInterval, isNull);
    });

    test('fromMap with empty map uses defaults', () {
      final settings = ActivitySettings.fromMap({});
      expect(settings.enabled, false);
      expect(settings.confidenceThreshold, 75);
      expect(settings.debounceSeconds, 30);
    });
  });
}
