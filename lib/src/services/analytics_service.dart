// MVP Flutter Analytics - Session-based aggregation
// File: lib/src/services/analytics_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:battery_plus/battery_plus.dart';

class AnalyticsConfig {
  final bool enabled;
  final String? industryCategory;
  final String? useCase;
  final String? apiEndpoint;
  final String? apiKey; // Required if enabled

  const AnalyticsConfig({
    this.enabled = false, // Opt-in by default
    this.industryCategory,
    this.useCase,
    this.apiEndpoint,
    this.apiKey,
  });
}

class SessionMetrics {
  int detectionsTotal = 0;
  List<double> detectionTimes = [];
  List<double> gpsAccuracies = [];
  double? batteryStart;
  double? batteryEnd;
  DateTime? sessionStart;
  DateTime? sessionEnd;
  Map<String, int> zoneUsage = {};
  Map<String, int> errorCounts = {};

  // NEW Phase 2A fields
  int? ttfdMs; // Time to first detection
  bool hadDetection = false; // Did any detection occur?
  List<double> detectionLatencies = []; // For P95 calculation
  int serviceInterruptions = 0; // Background service restarts
  int gpsOkCount = 0; // GPS accuracy successes
  int gpsTotalCount = 0; // Total GPS readings
  int sampleEvents = 0; // Event count for this session

  // Battery optimization tracking
  bool? batteryOptimizationDisabled; // Is battery optimization disabled?
  int batteryOptimizationCheckCount = 0; // How many times checked

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

    // Count zone type usage
    zoneUsage[zoneType] = (zoneUsage[zoneType] ?? 0) + 1;

    // Track first detection
    if (!hadDetection) {
      hadDetection = true;
      if (sessionStart != null) {
        ttfdMs = DateTime.now().difference(sessionStart!).inMilliseconds;
      }
    }

    // Track GPS accuracy
    gpsTotalCount++;
    if (gpsAccuracy <= 30.0) {
      // 30m threshold
      gpsOkCount++;
    }
  }

  void recordError(String errorType) {
    errorCounts[errorType] = (errorCounts[errorType] ?? 0) + 1;
  }

  // NEW Phase 2A methods
  void recordServiceInterruption() {
    serviceInterruptions++;
  }

  void recordGPSReading(double accuracy) {
    gpsTotalCount++;
    if (accuracy <= 30.0) {
      // 30m threshold
      gpsOkCount++;
    }
  }

  void recordBatteryOptimizationStatus(bool isDisabled) {
    batteryOptimizationDisabled = isDisabled;
    batteryOptimizationCheckCount++;
  }

  void setBatteryLevel(double batteryLevel) {
    batteryStart ??= batteryLevel;
    batteryEnd = batteryLevel;
  }

  void startSession() {
    sessionStart = DateTime.now();
  }

  void endSession() {
    sessionEnd = DateTime.now();
  }

  // Calculate session summary
  Map<String, dynamic> toSessionSummary() {
    final sessionDuration =
        sessionEnd?.difference(sessionStart ?? DateTime.now());
    final avgDetectionTime = detectionTimes.isEmpty
        ? null
        : detectionTimes.reduce((a, b) => a + b) / detectionTimes.length;

    // Calculate 95th percentile
    double? p95DetectionTime;
    if (detectionLatencies.isNotEmpty) {
      final sorted = List<double>.from(detectionLatencies)..sort();
      final p95Index = (0.95 * sorted.length).ceil() - 1;
      p95DetectionTime = sorted[p95Index.clamp(0, sorted.length - 1)];
    }

    final avgGpsAccuracy = gpsAccuracies.isEmpty
        ? null
        : gpsAccuracies.reduce((a, b) => a + b) / gpsAccuracies.length;

    // Calculate battery drain per hour
    double? batteryDrainPerHour;
    if (batteryStart != null &&
        batteryEnd != null &&
        sessionDuration != null &&
        sessionDuration.inMinutes > 0) {
      final batteryDelta = batteryStart! - batteryEnd!;
      final hours = sessionDuration.inMinutes / 60.0;
      batteryDrainPerHour = batteryDelta / hours;
    }

    // Calculate GPS OK ratio
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
      // NEW Phase 2A fields
      'ttfd_ms': ttfdMs,
      'had_detection': hadDetection,
      'detection_latency_ms_p95': p95DetectionTime,
      'service_interruptions': serviceInterruptions,
      'gps_ok_ratio': gpsOkRatio,
      'sample_events': sampleEvents,
      // Battery optimization tracking
      'battery_optimization_disabled': batteryOptimizationDisabled,
      'battery_optimization_check_count': batteryOptimizationCheckCount,
    };
  }
}

class PolyfenceAnalytics {
  static PolyfenceAnalytics? _instance;
  static PolyfenceAnalytics get instance =>
      _instance ??= PolyfenceAnalytics._();
  PolyfenceAnalytics._();

  AnalyticsConfig? _config;
  SessionMetrics? _currentSession;
  String? _appIdentifier;
  String? _pluginVersion;
  final Battery _battery = Battery();

  static const String _defaultEndpoint =
      'https://polyfence.io/api/v1/analytics/session';

  // Initialize analytics with configuration
  Future<void> initialize({
    required AnalyticsConfig config,
    required String pluginVersion,
  }) async {
    // Validate HTTPS endpoint if custom endpoint is provided
    if (config.apiEndpoint != null) {
      final uri = Uri.tryParse(config.apiEndpoint!);
      if (uri == null || uri.scheme != 'https') {
        throw ArgumentError(
          'Analytics endpoint must use HTTPS for security. Got: ${config.apiEndpoint}',
        );
      }
    }

    _config = config;
    _pluginVersion = pluginVersion;

    // Get app identifier from package info
    _appIdentifier = await _getAppIdentifier();

    // Start session if analytics is enabled (apiKey is optional)
    if (config.enabled) {
      startSession();
    }
  }

  // Start a new analytics session
  void startSession() {
    if (!(_config?.enabled ?? false)) return;

    _currentSession = SessionMetrics();
    _currentSession?.startSession();

    // Get initial battery level
    _getBatteryLevel().then((level) {
      _currentSession?.setBatteryLevel(level);
    });
  }

  // End current session and send data
  Future<void> endSession() async {
    if (!(_config?.enabled ?? false) || _currentSession == null) return;

    _currentSession?.endSession();

    // Get final battery level
    final finalBattery = await _getBatteryLevel();
    _currentSession?.setBatteryLevel(finalBattery);

    // Send session summary
    await _sendSessionSummary();
    _currentSession = null;
  }

  // Record a zone detection event
  void recordDetection({
    required double detectionTimeMs,
    required double gpsAccuracy,
    required String zoneType, // 'circle' or 'polygon'
  }) {
    if (!(_config?.enabled ?? false)) return;

    _currentSession?.recordDetection(
      detectionTimeMs: detectionTimeMs,
      gpsAccuracy: gpsAccuracy,
      zoneType: zoneType,
    );
  }

  // Record an error event
  void recordError(String errorType) {
    if (!(_config?.enabled ?? false)) return;

    _currentSession?.recordError(errorType);
  }

  // NEW Phase 2A methods
  // Record a service interruption
  void recordServiceInterruption() {
    if (!(_config?.enabled ?? false)) return;

    _currentSession?.recordServiceInterruption();
  }

  // Record a GPS reading for accuracy tracking
  void recordGPSReading(double accuracy) {
    if (!(_config?.enabled ?? false)) return;

    _currentSession?.recordGPSReading(accuracy);
  }

  void recordBatteryOptimizationStatus(bool isDisabled) {
    if (!(_config?.enabled ?? false)) return;

    _currentSession?.recordBatteryOptimizationStatus(isDisabled);
  }

  // Send session summary to API
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

      // Build headers - only include x-api-key if provided
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Idempotency-Key': idempotencyKey,
      };
      
      // Only add x-api-key header if apiKey is provided
      if (_config?.apiKey != null && _config!.apiKey!.isNotEmpty) {
        headers['x-api-key'] = _config!.apiKey!;
      }

      final response = await http.post(
        Uri.parse(endpoint),
        headers: headers,
        body: json.encode(payload),
      );

      if (response.statusCode == 201) {
        // Analytics session sent successfully
      } else if (response.statusCode == 200) {
        // Analytics session already processed (deduped)
      } else {
        // Failed to send analytics
      }
    } catch (e) {
      // Error sending analytics
      // Store locally for retry (optional)
      await _storeForRetry();
    }
  }

  // Get app package identifier
  Future<String> _getAppIdentifier() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.packageName;
    } catch (e) {
      // Error getting app identifier
      return 'unknown.app';
    }
  }

  // Get device battery level
  Future<double> _getBatteryLevel() async {
    try {
      final batteryLevel = await _battery.batteryLevel;
      return batteryLevel.toDouble();
    } catch (e) {
      // Error getting battery level
      return 100.0; // Default to full battery
    }
  }

  // Store failed requests for retry
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
      // Error storing analytics for retry
    }
  }

  // Retry failed analytics requests
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

          // Build headers - only include x-api-key if provided
          final headers = <String, String>{
            'Content-Type': 'application/json',
            'Idempotency-Key': idempotencyKey,
          };
          
          // Only add x-api-key header if apiKey is provided
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
            // Retried analytics request successfully
          }
        }
      }
    } catch (e) {
      // Error retrying analytics requests
    }
  }
}

// Extension for easy integration
extension PolyfenceAnalyticsExtension on Object {
  void recordDetection({
    required double detectionTimeMs,
    required double gpsAccuracy,
    required String zoneType,
  }) {
    PolyfenceAnalytics.instance.recordDetection(
      detectionTimeMs: detectionTimeMs,
      gpsAccuracy: gpsAccuracy,
      zoneType: zoneType,
    );
  }

  void recordError(String errorType) {
    PolyfenceAnalytics.instance.recordError(errorType);
  }
}
