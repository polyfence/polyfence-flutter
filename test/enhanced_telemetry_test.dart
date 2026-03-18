import 'package:flutter_test/flutter_test.dart';
import 'package:polyfence/src/services/analytics_service.dart';

/// Tests for the simplified telemetry service (D016).
///
/// With D016, all telemetry aggregation moved to native polyfence-core.
/// The Dart PolyfenceAnalytics is now a thin client that fetches aggregated
/// data via platform channel and POSTs it.
void main() {
  group('AnalyticsConfig defaults — opt-in telemetry', () {
    test('default config has telemetry disabled (opt-in)', () {
      const config = AnalyticsConfig();
      expect(config.enabled, isFalse);
      expect(config.disableTelemetry, isTrue);
    });

    test('explicitly enabling telemetry works', () {
      const config = AnalyticsConfig(enabled: true, disableTelemetry: false);
      expect(config.enabled, isTrue);
      expect(config.disableTelemetry, isFalse);
    });

    test('optional fields default to null', () {
      const config = AnalyticsConfig();
      expect(config.industryCategory, isNull);
      expect(config.useCase, isNull);
      expect(config.apiEndpoint, isNull);
      expect(config.apiKey, isNull);
    });

    test('custom endpoint and apiKey are preserved', () {
      const config = AnalyticsConfig(
        enabled: true,
        apiEndpoint: 'https://custom.example.com/analytics',
        apiKey: 'test-key-123',
        industryCategory: 'logistics',
        useCase: 'fleet_tracking',
      );
      expect(config.apiEndpoint, 'https://custom.example.com/analytics');
      expect(config.apiKey, 'test-key-123');
      expect(config.industryCategory, 'logistics');
      expect(config.useCase, 'fleet_tracking');
    });
  });

  group('PolyfenceAnalytics — endpoint validation', () {
    test('rejects non-HTTPS endpoint', () async {
      expect(
        () => PolyfenceAnalytics.instance.initialize(
          config: const AnalyticsConfig(
            enabled: true,
            disableTelemetry: false,
            apiEndpoint: 'http://insecure.example.com/analytics',
          ),
          pluginVersion: '0.12.4',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects endpoint without valid hostname', () async {
      expect(
        () => PolyfenceAnalytics.instance.initialize(
          config: const AnalyticsConfig(
            enabled: true,
            disableTelemetry: false,
            apiEndpoint: 'https://localhost/analytics',
          ),
          pluginVersion: '0.12.4',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('PolyfenceAnalytics — endSession behavior', () {
    test('endSession does nothing when telemetry is disabled', () async {
      // Initialize with telemetry disabled (default)
      await PolyfenceAnalytics.instance.initialize(
        config: const AnalyticsConfig(),
        pluginVersion: '0.12.4',
        sessionTelemetryFetcher: () async =>
            throw Exception('should not be called'),
      );

      // Should not call the fetcher since telemetry is disabled
      await PolyfenceAnalytics.instance.endSession();
    });

    test('endSession does nothing when no fetcher provided', () async {
      await PolyfenceAnalytics.instance.initialize(
        config: const AnalyticsConfig(enabled: true, disableTelemetry: false),
        pluginVersion: '0.12.4',
        // No sessionTelemetryFetcher
      );

      // Should not throw
      await PolyfenceAnalytics.instance.endSession();
    });
  });
}
