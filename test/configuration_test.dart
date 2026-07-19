import 'package:flutter_test/flutter_test.dart';
import 'package:polyfence/polyfence.dart';

void main() {
  group('PolyfenceConfiguration', () {
    test('default values are correct', () {
      final config = PolyfenceConfiguration();

      expect(config.accuracyProfile, PolyfenceAccuracyProfile.balanced);
      expect(config.updateStrategy, PolyfenceUpdateStrategy.continuous);
      expect(config.proximitySettings, isNull);
      expect(config.movementSettings, isNull);
      expect(config.batterySettings, isNull);
      expect(config.dwellSettings, isNull);
      expect(config.clusterSettings, isNull);
      expect(config.scheduleSettings, isNull);
      expect(config.activitySettings, isNull);
      expect(config.disableAlertNotifications, false);
      expect(config.gpsAccuracyThreshold, 100.0);
      expect(config.gpsStalenessTimeoutMs, 0);
      expect(config.enableDebugLogging, false);
    });

    test('toMap/fromMap round-trip preserves all fields', () {
      final config = PolyfenceConfiguration(
        accuracyProfile: PolyfenceAccuracyProfile.balanced,
        updateStrategy: PolyfenceUpdateStrategy.intelligent,
        proximitySettings: ProximitySettings(
          nearZoneThresholdMeters: 300.0,
          farZoneThresholdMeters: 3000.0,
        ),
        movementSettings: MovementSettings(
          stationaryThreshold: const Duration(minutes: 10),
          movementThresholdMeters: 25.0,
        ),
        batterySettings: BatterySettings(
          lowBatteryThreshold: 15,
          criticalBatteryThreshold: 5,
        ),
        dwellSettings: DwellSettings(
          enabled: true,
          dwellThreshold: const Duration(minutes: 10),
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
              daysOfWeek: const [1, 2, 3, 4, 5],
            ),
          ],
        ),
        activitySettings: ActivitySettings(
          enabled: true,
          confidenceThreshold: 80,
          debounceSeconds: 45,
          stillInterval: const Duration(seconds: 120),
          drivingInterval: const Duration(seconds: 3),
        ),
        disableAlertNotifications: true,
        gpsAccuracyThreshold: 50.0,
        gpsStalenessTimeoutMs: 30000,
        enableDebugLogging: true,
      );

      final map = config.toMap();
      final restored = PolyfenceConfiguration.fromMap(map);

      expect(restored.accuracyProfile, PolyfenceAccuracyProfile.balanced);
      expect(restored.updateStrategy, PolyfenceUpdateStrategy.intelligent);
      expect(restored.disableAlertNotifications, true);
      expect(restored.gpsAccuracyThreshold, 50.0);
      expect(restored.gpsStalenessTimeoutMs, 30000);
      expect(restored.enableDebugLogging, true);
      expect(restored.proximitySettings, isNotNull);
      expect(restored.movementSettings, isNotNull);
      expect(restored.batterySettings, isNotNull);
      expect(restored.dwellSettings, isNotNull);
      expect(restored.clusterSettings, isNotNull);
      expect(restored.scheduleSettings, isNotNull);
      expect(restored.activitySettings, isNotNull);
    });

    test('fromMap with empty map uses defaults', () {
      final config = PolyfenceConfiguration.fromMap({});

      expect(config.accuracyProfile, PolyfenceAccuracyProfile.balanced);
      expect(config.updateStrategy, PolyfenceUpdateStrategy.continuous);
      expect(config.disableAlertNotifications, false);
      expect(config.gpsAccuracyThreshold, 100.0);
      expect(config.gpsStalenessTimeoutMs, 0);
      expect(config.enableDebugLogging, false);
      expect(config.proximitySettings, isNull);
      expect(config.movementSettings, isNull);
      expect(config.batterySettings, isNull);
    });

    test('gpsStalenessTimeoutMs rejects negative values', () {
      expect(
        () => PolyfenceConfiguration(gpsStalenessTimeoutMs: -1),
        throwsArgumentError,
      );
    });

    test('copyWith updates specified fields and preserves others', () {
      final original = PolyfenceConfiguration(
        accuracyProfile: PolyfenceAccuracyProfile.maxAccuracy,
        gpsAccuracyThreshold: 100.0,
        enableDebugLogging: false,
        disableAlertNotifications: false,
      );

      final modified = original.copyWith(
        accuracyProfile: PolyfenceAccuracyProfile.batteryOptimal,
        enableDebugLogging: true,
        disableAlertNotifications: true,
      );

      expect(modified.accuracyProfile, PolyfenceAccuracyProfile.batteryOptimal);
      expect(modified.enableDebugLogging, true);
      expect(modified.disableAlertNotifications, true);
      // Preserved from original:
      expect(modified.gpsAccuracyThreshold, 100.0);
      expect(modified.updateStrategy, PolyfenceUpdateStrategy.continuous);
    });

    test('toMap serializes disableAlertNotifications with correct key', () {
      final config = PolyfenceConfiguration(disableAlertNotifications: true);
      final map = config.toMap();

      expect(map.containsKey('disableAlertNotifications'), true);
      expect(map['disableAlertNotifications'], true);

      final defaultConfig = PolyfenceConfiguration();
      final defaultMap = defaultConfig.toMap();
      expect(defaultMap['disableAlertNotifications'], false);
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
      final config = PolyfenceConfiguration();
      final str = config.toString();
      expect(str, contains('accuracyProfile'));
      expect(str, contains('updateStrategy'));
      expect(str, contains('disableAlertNotifications'));
      expect(str, contains('gpsAccuracyThreshold'));
    });
  });

  group('ProximitySettings', () {
    test('default values are correct', () {
      final settings = ProximitySettings();
      expect(settings.nearZoneThresholdMeters, 500.0);
      expect(settings.farZoneThresholdMeters, 2000.0);
      expect(settings.nearZoneUpdateInterval, const Duration(seconds: 5));
      expect(settings.farZoneUpdateInterval, const Duration(seconds: 60));
    });

    test('toMap/fromMap round-trip preserves values', () {
      final settings = ProximitySettings(
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
      final settings = ProximitySettings(
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
      final settings = MovementSettings();
      expect(settings.stationaryThreshold, const Duration(minutes: 5));
      expect(settings.movementThresholdMeters, 50.0);
      expect(settings.stationaryUpdateInterval, const Duration(minutes: 2));
      expect(settings.movingUpdateInterval, const Duration(seconds: 10));
    });

    test('toMap/fromMap round-trip preserves values', () {
      final settings = MovementSettings(
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
      final settings = BatterySettings();
      expect(settings.lowBatteryThreshold, 20);
      expect(settings.criticalBatteryThreshold, 10);
      expect(settings.lowBatteryUpdateInterval, const Duration(seconds: 30));
      expect(settings.pauseOnCriticalBattery, true);
    });

    test('toMap/fromMap round-trip preserves values', () {
      final settings = BatterySettings(
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
      final settings = DwellSettings();
      expect(settings.enabled, true);
      expect(settings.dwellThreshold, const Duration(minutes: 5));
    });

    test('toMap/fromMap round-trip preserves values', () {
      final settings = DwellSettings(
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
      final settings = ClusterSettings();
      expect(settings.enabled, false);
      expect(settings.activeRadiusMeters, 5000.0);
      expect(settings.refreshDistanceMeters, 1000.0);
    });

    test('toMap/fromMap round-trip preserves values', () {
      final settings = ClusterSettings(
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
      final tod = TimeOfDay(hour: 14, minute: 30);
      final map = tod.toMap();
      final restored = TimeOfDay.fromMap(map);

      expect(restored.hour, 14);
      expect(restored.minute, 30);
    });

    test('toString formats with leading zeros', () {
      final tod = TimeOfDay(hour: 9, minute: 5);
      expect(tod.toString(), '09:05');
    });

    test('toString formats midnight correctly', () {
      final tod = TimeOfDay(hour: 0, minute: 0);
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
      final window = TimeWindow(
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
      final window = TimeWindow(
        startTime: TimeOfDay(hour: 0, minute: 0),
        endTime: TimeOfDay(hour: 23, minute: 59),
      );
      expect(window.daysOfWeek, isEmpty);
    });

    test('toString includes time range and days', () {
      final window = TimeWindow(
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
      final settings = ScheduleSettings();
      expect(settings.enabled, false);
      expect(settings.timeWindows, isEmpty);
      expect(settings.startImmediatelyIfInWindow, true);
    });

    test('toMap/fromMap round-trip with time windows', () {
      final settings = ScheduleSettings(
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
      final settings = ActivitySettings();
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
      final settings = ActivitySettings(
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
      final settings = ActivitySettings(
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

  group('Configuration validation', () {
    group('PolyfenceConfiguration', () {
      test('rejects zero gpsAccuracyThreshold', () {
        expect(
          () => PolyfenceConfiguration(gpsAccuracyThreshold: 0),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('rejects negative gpsAccuracyThreshold', () {
        expect(
          () => PolyfenceConfiguration(gpsAccuracyThreshold: -10.0),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('accepts positive gpsAccuracyThreshold', () {
        expect(
          () => PolyfenceConfiguration(gpsAccuracyThreshold: 0.1),
          returnsNormally,
        );
      });
    });

    group('ProximitySettings', () {
      test('rejects zero nearZoneThresholdMeters', () {
        expect(
          () => ProximitySettings(nearZoneThresholdMeters: 0),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('rejects negative farZoneThresholdMeters', () {
        expect(
          () => ProximitySettings(farZoneThresholdMeters: -100),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('rejects near >= far threshold', () {
        expect(
          () => ProximitySettings(
            nearZoneThresholdMeters: 2000.0,
            farZoneThresholdMeters: 2000.0,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('rejects near > far threshold', () {
        expect(
          () => ProximitySettings(
            nearZoneThresholdMeters: 3000.0,
            farZoneThresholdMeters: 1000.0,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('accepts valid near < far thresholds', () {
        expect(
          () => ProximitySettings(
            nearZoneThresholdMeters: 100.0,
            farZoneThresholdMeters: 500.0,
          ),
          returnsNormally,
        );
      });
    });

    group('MovementSettings', () {
      test('rejects zero movementThresholdMeters', () {
        expect(
          () => MovementSettings(movementThresholdMeters: 0),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('rejects negative movementThresholdMeters', () {
        expect(
          () => MovementSettings(movementThresholdMeters: -1),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('DwellSettings', () {
      test('rejects zero dwellThreshold', () {
        expect(
          () => DwellSettings(dwellThreshold: Duration.zero),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('rejects negative dwellThreshold', () {
        expect(
          () => DwellSettings(
            dwellThreshold: const Duration(milliseconds: -1),
          ),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('ClusterSettings', () {
      test('rejects zero activeRadiusMeters', () {
        expect(
          () => ClusterSettings(activeRadiusMeters: 0),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('rejects negative refreshDistanceMeters', () {
        expect(
          () => ClusterSettings(refreshDistanceMeters: -500),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('TimeOfDay', () {
      test('rejects hour < 0', () {
        expect(
          () => TimeOfDay(hour: -1, minute: 0),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('rejects hour > 23', () {
        expect(
          () => TimeOfDay(hour: 24, minute: 0),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('rejects minute < 0', () {
        expect(
          () => TimeOfDay(hour: 0, minute: -1),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('rejects minute > 59', () {
        expect(
          () => TimeOfDay(hour: 0, minute: 60),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('accepts boundary values (0:00 and 23:59)', () {
        expect(() => TimeOfDay(hour: 0, minute: 0), returnsNormally);
        expect(() => TimeOfDay(hour: 23, minute: 59), returnsNormally);
      });
    });

    group('TimeWindow', () {
      test('rejects daysOfWeek value < 1', () {
        expect(
          () => TimeWindow(
            startTime: TimeOfDay(hour: 9, minute: 0),
            endTime: TimeOfDay(hour: 17, minute: 0),
            daysOfWeek: const [0],
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('rejects daysOfWeek value > 7', () {
        expect(
          () => TimeWindow(
            startTime: TimeOfDay(hour: 9, minute: 0),
            endTime: TimeOfDay(hour: 17, minute: 0),
            daysOfWeek: const [8],
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('accepts valid daysOfWeek 1-7', () {
        expect(
          () => TimeWindow(
            startTime: TimeOfDay(hour: 9, minute: 0),
            endTime: TimeOfDay(hour: 17, minute: 0),
            daysOfWeek: const [1, 2, 3, 4, 5, 6, 7],
          ),
          returnsNormally,
        );
      });
    });

    group('BatterySettings', () {
      test('rejects lowBatteryThreshold < 0', () {
        expect(
          () => BatterySettings(
            lowBatteryThreshold: -1,
            criticalBatteryThreshold: -2,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('rejects lowBatteryThreshold > 100', () {
        expect(
          () => BatterySettings(lowBatteryThreshold: 101),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('rejects criticalBatteryThreshold > 100', () {
        expect(
          () => BatterySettings(
            lowBatteryThreshold: 100,
            criticalBatteryThreshold: 101,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('rejects critical >= low', () {
        expect(
          () => BatterySettings(
            lowBatteryThreshold: 20,
            criticalBatteryThreshold: 20,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('rejects critical > low', () {
        expect(
          () => BatterySettings(
            lowBatteryThreshold: 10,
            criticalBatteryThreshold: 20,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('accepts valid thresholds', () {
        expect(
          () => BatterySettings(
            lowBatteryThreshold: 20,
            criticalBatteryThreshold: 5,
          ),
          returnsNormally,
        );
      });
    });

    group('ActivitySettings', () {
      test('rejects confidenceThreshold < 0', () {
        expect(
          () => ActivitySettings(confidenceThreshold: -1),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('rejects confidenceThreshold > 100', () {
        expect(
          () => ActivitySettings(confidenceThreshold: 101),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('rejects negative debounceSeconds', () {
        expect(
          () => ActivitySettings(debounceSeconds: -1),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('accepts boundary values (0 and 100 confidence)', () {
        expect(() => ActivitySettings(confidenceThreshold: 0), returnsNormally);
        expect(
          () => ActivitySettings(confidenceThreshold: 100),
          returnsNormally,
        );
      });

      test('accepts zero debounceSeconds', () {
        expect(() => ActivitySettings(debounceSeconds: 0), returnsNormally);
      });
    });
  });
}
