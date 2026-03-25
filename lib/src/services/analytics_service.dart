import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Configuration for Polyfence anonymous telemetry and analytics.
///
/// By default, telemetry is **enabled** (opt-out). To disable, set
/// `disableTelemetry: true`:
///
/// ```dart
/// await Polyfence.instance.initialize(
///   analyticsConfig: AnalyticsConfig(disableTelemetry: true),
/// );
/// ```
///
/// No location data or PII is ever sent. The optional [apiKey] enables
/// additional Polyfence.io dashboard features.
class AnalyticsConfig {
  /// Whether analytics data collection is enabled.
  ///
  /// Defaults to `true` — telemetry is opt-out (D008).
  final bool enabled;

  /// Set to `true` to explicitly disable all anonymous telemetry.
  ///
  /// Defaults to `false` — telemetry is on by default.
  final bool disableTelemetry;

  /// Optional industry category for benchmarking.
  final String? industryCategory;

  /// Optional use-case description.
  final String? useCase;

  /// Custom analytics endpoint URL (must use HTTPS).
  final String? apiEndpoint;

  /// Optional API key for Polyfence.io dashboard features.
  final String? apiKey;

  /// Creates an analytics configuration.
  const AnalyticsConfig({
    this.enabled = true,
    this.disableTelemetry = false,
    this.industryCategory,
    this.useCase,
    this.apiEndpoint,
    this.apiKey,
  });
}

/// Singleton analytics service for collecting and sending plugin telemetry.
///
/// Session telemetry aggregation is handled entirely by native polyfence-core
/// (D016). This service fetches the aggregated payload via platform channel
/// and POSTs it to the analytics endpoint.
class PolyfenceAnalytics {
  static PolyfenceAnalytics? _instance;

  /// Gets the singleton instance.
  static PolyfenceAnalytics get instance =>
      _instance ??= PolyfenceAnalytics._();
  PolyfenceAnalytics._();

  AnalyticsConfig? _config;
  String? _appIdentifier;
  String? _pluginVersion;

  /// Injected function to fetch native session telemetry via platform channel.
  Future<Map<String, dynamic>> Function()? _sessionTelemetryFetcher;

  static const String _defaultEndpoint =
      'https://polyfence.io/api/v1/analytics/session';

  /// Initializes the analytics service with the given configuration.
  ///
  /// The [sessionTelemetryFetcher] provides the complete session telemetry
  /// payload from native polyfence-core's TelemetryAggregator.
  Future<void> initialize({
    required AnalyticsConfig config,
    required String pluginVersion,
    Future<Map<String, dynamic>> Function()? sessionTelemetryFetcher,
  }) async {
    if (config.apiEndpoint != null) {
      final uri = Uri.tryParse(config.apiEndpoint!);
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host.isEmpty ||
          !uri.host.contains('.')) {
        throw ArgumentError(
          'Analytics endpoint must be a valid HTTPS URL with a hostname. '
          'Got: ${config.apiEndpoint}',
        );
      }
    }

    _config = config;
    _pluginVersion = pluginVersion;
    _sessionTelemetryFetcher = sessionTelemetryFetcher;
    _appIdentifier = await _getAppIdentifier();
  }

  /// Ends the current session and sends telemetry if enabled.
  ///
  /// Fetches the complete session telemetry from native polyfence-core
  /// and POSTs it to the analytics endpoint.
  Future<void> endSession() async {
    if (!(_config?.enabled ?? false) || _sessionTelemetryFetcher == null) {
      return;
    }

    Map<String, dynamic>? telemetry;
    try {
      telemetry = await _sessionTelemetryFetcher!();
    } catch (_) {
      // Native telemetry fetch failed — nothing to send
      return;
    }

    await _sendTelemetry(telemetry);
  }

  Future<void> _sendTelemetry(Map<String, dynamic> sessionData) async {
    if (_appIdentifier == null || _pluginVersion == null) return;

    final payload = {
      'app_identifier': _appIdentifier,
      'platform': Platform.isAndroid ? 'android' : 'ios',
      'plugin_version': _pluginVersion,
      'industry_category': _config?.industryCategory,
      'use_case': _config?.useCase,
      ...sessionData,
    };

    try {
      final endpoint = _config?.apiEndpoint ?? _defaultEndpoint;
      final idempotencyKey = const Uuid().v4();

      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Idempotency-Key': idempotencyKey,
      };

      if (_config?.apiKey != null && _config!.apiKey!.isNotEmpty) {
        headers['x-api-key'] = _config!.apiKey!;
      }

      await http.post(
        Uri.parse(endpoint),
        headers: headers,
        body: json.encode(payload),
      );
    } catch (e) {
      // Store the full payload so retries send it directly without
      // re-wrapping app_identifier/platform fields.
      await _storeForRetry(payload);
    }
  }

  Future<String> _getAppIdentifier() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.packageName;
    } catch (e) {
      return 'unknown.app';
    }
  }

  static const int _maxRetryEntries = 50;

  Future<void> _storeForRetry(Map<String, dynamic> sessionData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingKeys = prefs
          .getKeys()
          .where((key) => key.startsWith('polyfence_analytics_retry_'))
          .toList()
        ..sort();

      // Cap retry queue — drop oldest entries beyond limit
      if (existingKeys.length >= _maxRetryEntries) {
        final toRemove =
            existingKeys.sublist(0, existingKeys.length - _maxRetryEntries + 1);
        for (final oldKey in toRemove) {
          await prefs.remove(oldKey);
        }
      }

      final key =
          'polyfence_analytics_retry_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString(key, json.encode(sessionData));
    } catch (e) {
      // Best-effort storage for retry
    }
  }

  /// Retries sending previously failed analytics requests.
  Future<void> retryFailedRequests() async {
    if (!(_config?.enabled ?? false)) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs
          .getKeys()
          .where((key) => key.startsWith('polyfence_analytics_retry_'));

      for (final key in keys) {
        final sessionDataJson = prefs.getString(key);
        if (sessionDataJson != null) {
          // Stored data already contains app_identifier, platform, etc.
          // from the original _sendTelemetry() call — send as-is to avoid
          // double-wrapping those fields.
          final sessionData =
              json.decode(sessionDataJson) as Map<String, dynamic>;

          final endpoint = _config?.apiEndpoint ?? _defaultEndpoint;
          final idempotencyKey = const Uuid().v4();

          final headers = <String, String>{
            'Content-Type': 'application/json',
            'Idempotency-Key': idempotencyKey,
          };

          if (_config?.apiKey != null && _config!.apiKey!.isNotEmpty) {
            headers['x-api-key'] = _config!.apiKey!;
          }

          final response = await http.post(
            Uri.parse(endpoint),
            headers: headers,
            body: json.encode(sessionData),
          );

          if (response.statusCode == 201 || response.statusCode == 200) {
            await prefs.remove(key);
          }
        }
      }
    } catch (e) {
      // Best-effort retry
    }
  }
}
