import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:battery_plus/battery_plus.dart';

/// Configuration for Polyfence anonymous telemetry and analytics.
///
/// By default, anonymous plugin performance telemetry is enabled. No location
/// data or PII is ever sent. Developers can opt out with a single line:
///
/// ```dart
/// await Polyfence.instance.initialize(
///   analyticsConfig: AnalyticsConfig(disableTelemetry: true),
/// );
/// ```
///
/// The optional [apiKey] enables additional Polyfence.io dashboard features.
class AnalyticsConfig {
  /// Whether analytics data collection is enabled.
  final bool enabled;

  /// Set to `true` to disable all anonymous telemetry.
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

/// Aggregated metrics for a single analytics session.
///
/// Collects performance data including detection times, GPS accuracy,
/// battery usage, and error counts during a tracking session.
class _SessionMetrics {
  /// Total number of zone detections in this session.
  int detectionsTotal = 0;

  /// Detection time measurements in milliseconds.
  List<double> detectionTimes = [];

  /// GPS accuracy measurements in meters.
  List<double> gpsAccuracies = [];

  /// Battery level at session start.
  double? batteryStart;

  /// Battery level at session end.
  double? batteryEnd;

  /// When this session started.
  DateTime? sessionStart;

  /// When this session ended.
  DateTime? sessionEnd;

  /// Zone type usage counts (e.g., {'circle': 5, 'polygon': 2}).
  Map<String, int> zoneUsage = {};

  /// Error type counts.
  Map<String, int> errorCounts = {};

  /// Time to first detection in milliseconds.
  int? ttfdMs;

  /// Whether any detection occurred in this session.
  bool hadDetection = false;

  /// Detection latency measurements for percentile calculations.
  List<double> detectionLatencies = [];

  /// Number of background service interruptions.
  int serviceInterruptions = 0;

  /// Number of GPS readings with acceptable accuracy.
  int gpsOkCount = 0;

  /// Total number of GPS readings.
  int gpsTotalCount = 0;

  /// Total detection events in this session.
  int sampleEvents = 0;

  /// Whether battery optimization is disabled.
  bool? batteryOptimizationDisabled;

  /// Number of battery optimization status checks.
  int batteryOptimizationCheckCount = 0;

  /// Records a zone detection event.
  void recordDetection({
    required double detectionTimeMs,
    required double gpsAccuracy,
    required String zoneType,
  }) {
    detectionsTotal++;
    detectionTimes.add(detectionTimeMs);
    gpsAccuracies.add(gpsAccuracy);
    detectionLatencies.add(detectionTimeMs);
    sampleEvents++;

    zoneUsage[zoneType] = (zoneUsage[zoneType] ?? 0) + 1;

    if (!hadDetection) {
      hadDetection = true;
      if (sessionStart != null) {
        ttfdMs = DateTime.now().difference(sessionStart!).inMilliseconds;
      }
    }

    gpsTotalCount++;
    if (gpsAccuracy <= 30.0) {
      gpsOkCount++;
    }
  }

  /// Records an error event by type.
  void recordError(String errorType) {
    errorCounts[errorType] = (errorCounts[errorType] ?? 0) + 1;
  }

  /// Records a background service interruption.
  void recordServiceInterruption() {
    serviceInterruptions++;
  }

  /// Records a GPS reading for accuracy tracking.
  void recordGPSReading(double accuracy) {
    gpsTotalCount++;
    if (accuracy <= 30.0) {
      gpsOkCount++;
    }
  }

  /// Records battery optimization status.
  void recordBatteryOptimizationStatus(bool isDisabled) {
    batteryOptimizationDisabled = isDisabled;
    batteryOptimizationCheckCount++;
  }

  /// Sets the current battery level (used for drain calculation).
  void setBatteryLevel(double batteryLevel) {
    batteryStart ??= batteryLevel;
    batteryEnd = batteryLevel;
  }

  /// Marks the session as started.
  void startSession() {
    sessionStart = DateTime.now();
  }

  /// Marks the session as ended.
  void endSession() {
    sessionEnd = DateTime.now();
  }

  /// Generates a summary map of all session metrics.
  Map<String, dynamic> toSessionSummary() {
    final sessionDuration =
        sessionEnd?.difference(sessionStart ?? DateTime.now());
    final avgDetectionTime = detectionTimes.isEmpty
        ? null
        : detectionTimes.reduce((a, b) => a + b) / detectionTimes.length;

    double? p95DetectionTime;
    if (detectionLatencies.isNotEmpty) {
      final sorted = List<double>.from(detectionLatencies)..sort();
      final p95Index = (0.95 * sorted.length).ceil() - 1;
      p95DetectionTime = sorted[p95Index.clamp(0, sorted.length - 1)];
    }

    final avgGpsAccuracy = gpsAccuracies.isEmpty
        ? null
        : gpsAccuracies.reduce((a, b) => a + b) / gpsAccuracies.length;

    double? batteryDrainPerHour;
    if (batteryStart != null &&
        batteryEnd != null &&
        sessionDuration != null &&
        sessionDuration.inMinutes > 0) {
      final batteryDelta = batteryStart! - batteryEnd!;
      final hours = sessionDuration.inMinutes / 60.0;
      batteryDrainPerHour = batteryDelta / hours;
    }

    double? gpsOkRatio;
    if (gpsTotalCount > 0) {
      gpsOkRatio = gpsOkCount / gpsTotalCount;
    }

    return {
      'detections_total': detectionsTotal,
      'detection_time_avg_ms': avgDetectionTime,
      'detection_time_p95_ms': p95DetectionTime,
      'gps_accuracy_avg_m': avgGpsAccuracy,
      'battery_drain_avg_pct_per_hr': batteryDrainPerHour,
      'session_duration_minutes': sessionDuration?.inMinutes,
      'zone_usage': zoneUsage,
      'error_counts': errorCounts,
      'ttfd_ms': ttfdMs,
      'had_detection': hadDetection,
      'detection_latency_ms_p95': p95DetectionTime,
      'service_interruptions': serviceInterruptions,
      'gps_ok_ratio': gpsOkRatio,
      'sample_events': sampleEvents,
      'battery_optimization_disabled': batteryOptimizationDisabled,
      'battery_optimization_check_count': batteryOptimizationCheckCount,
    };
  }
}

/// Singleton analytics service for collecting and sending plugin telemetry.
///
/// Manages session-based metric aggregation and periodic upload to the
/// analytics endpoint. Data is only sent when [AnalyticsConfig.enabled] is true.
class PolyfenceAnalytics {
  static PolyfenceAnalytics? _instance;

  /// Gets the singleton instance.
  static PolyfenceAnalytics get instance =>
      _instance ??= PolyfenceAnalytics._();
  PolyfenceAnalytics._();

  AnalyticsConfig? _config;
  _SessionMetrics? _currentSession;
  String? _appIdentifier;
  String? _pluginVersion;
  final Battery _battery = Battery();

  static const String _defaultEndpoint =
      'https://polyfence.io/api/v1/analytics/session';

  /// Initializes the analytics service with the given configuration.
  Future<void> initialize({
    required AnalyticsConfig config,
    required String pluginVersion,
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
    _appIdentifier = await _getAppIdentifier();
    startSession();
  }

  /// Starts a new analytics session.
  void startSession() {
    _currentSession = _SessionMetrics();
    _currentSession?.startSession();

    _getBatteryLevel().then((level) {
      _currentSession?.setBatteryLevel(level);
    });
  }

  /// Ends the current session and sends data if enabled.
  Future<void> endSession() async {
    if (_currentSession == null) return;

    _currentSession?.endSession();

    final finalBattery = await _getBatteryLevel();
    _currentSession?.setBatteryLevel(finalBattery);

    await _sendSessionSummary();
    _currentSession = null;
  }

  /// Records a zone detection event.
  void recordDetection({
    required double detectionTimeMs,
    required double gpsAccuracy,
    required String zoneType,
  }) {
    if (_currentSession == null) {
      startSession();
    }

    _currentSession?.recordDetection(
      detectionTimeMs: detectionTimeMs,
      gpsAccuracy: gpsAccuracy,
      zoneType: zoneType,
    );
  }

  /// Records an error event by type.
  void recordError(String errorType) {
    if (!(_config?.enabled ?? false)) return;

    _currentSession?.recordError(errorType);
  }

  /// Records a background service interruption.
  void recordServiceInterruption() {
    if (!(_config?.enabled ?? false)) return;

    _currentSession?.recordServiceInterruption();
  }

  /// Records a GPS reading for accuracy tracking.
  void recordGPSReading(double accuracy) {
    if (!(_config?.enabled ?? false)) return;

    _currentSession?.recordGPSReading(accuracy);
  }

  /// Records battery optimization status.
  void recordBatteryOptimizationStatus(bool isDisabled) {
    if (!(_config?.enabled ?? false)) return;

    _currentSession?.recordBatteryOptimizationStatus(isDisabled);
  }

  Future<void> _sendSessionSummary() async {
    if (_currentSession == null ||
        _appIdentifier == null ||
        _pluginVersion == null ||
        !(_config?.enabled ?? false)) {
      return;
    }

    try {
      final sessionData = _currentSession!.toSessionSummary();
      final payload = {
        'app_identifier': _appIdentifier,
        'platform': Platform.isAndroid ? 'android' : 'ios',
        'plugin_version': _pluginVersion,
        'industry_category': _config?.industryCategory,
        'use_case': _config?.useCase,
        ...sessionData,
      };

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
      await _storeForRetry();
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

  Future<double> _getBatteryLevel() async {
    try {
      final batteryLevel = await _battery.batteryLevel;
      return batteryLevel.toDouble();
    } catch (e) {
      return 100.0;
    }
  }

  Future<void> _storeForRetry() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionData = _currentSession?.toSessionSummary();
      if (sessionData != null) {
        final key =
            'polyfence_analytics_retry_${DateTime.now().millisecondsSinceEpoch}';
        await prefs.setString(key, json.encode(sessionData));
      }
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
          final sessionData = json.decode(sessionDataJson);
          final payload = {
            'app_identifier': _appIdentifier,
            'platform': Platform.isAndroid ? 'android' : 'ios',
            'plugin_version': _pluginVersion,
            'industry_category': _config?.industryCategory,
            'use_case': _config?.useCase,
            ...sessionData,
          };

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
            body: json.encode(payload),
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
