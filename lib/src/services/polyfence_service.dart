import 'dart:async';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../models/zone.dart';
import '../models/location.dart';
import '../models/geofence_event.dart';
import '../models/polyfence_runtime_status.dart';
import '../platform/polyfence_platform.dart';
import '../errors/polyfence_error.dart';
import '../errors/polyfence_exceptions.dart';
import '../debug/polyfence_debug_info.dart';
import '../configuration/polyfence_configuration.dart';
import '../utils/enum_utils.dart';
import 'analytics_service.dart';
import 'app_lifecycle_manager.dart';

/// Simplified Polyfence service
/// Single responsibility: Flutter API ↔ Native bridge
/// NO duplicate detection logic - Android handles everything
class PolyfenceService {
  static final PolyfenceService _instance = PolyfenceService._internal();
  static PolyfenceService get instance => _instance;

  PolyfenceService._internal();

  final PolyfencePlatform _platform = PolyfencePlatform.instance;

  // Disposal guard to prevent use-after-disposal
  bool _isDisposed = false;

  // Event streams for the app
  final StreamController<GeofenceEvent> _eventController =
      StreamController<GeofenceEvent>.broadcast();
  final StreamController<PolyfenceLocation> _locationController =
      StreamController<PolyfenceLocation>.broadcast();
  final StreamController<PolyfenceError> _errorController =
      StreamController<PolyfenceError>.broadcast();
  final StreamController<PolyfenceRuntimeStatus> _runtimeStatusController =
      StreamController<PolyfenceRuntimeStatus>.broadcast();
  final StreamController<Map<String, dynamic>> _statusController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Stream of all geofence events (enter/exit).
  ///
  /// Emits [GeofenceEvent] whenever a zone entry or exit is detected.
  ///
  /// **Example:**
  /// ```dart
  /// Polyfence.instance.onGeofenceEvent.listen((event) {
  ///   print('${event.type.name.toUpperCase()}: ${event.zoneId}');
  ///   print('Location: ${event.location.latitude}, ${event.location.longitude}');
  /// });
  /// ```
  Stream<GeofenceEvent> get onGeofenceEvent => _eventController.stream;

  /// Stream of zone entry events only.
  ///
  /// Filters [onGeofenceEvent] to only emit entry events.
  ///
  /// **Example:**
  /// ```dart
  /// Polyfence.instance.onZoneEnter.listen((event) {
  ///   print('Entered zone: ${event.zoneId}');
  /// });
  /// ```
  Stream<GeofenceEvent> get onZoneEnter =>
      _eventController.stream.where((e) => e.type == GeofenceEventType.enter);

  /// Stream of zone exit events only.
  ///
  /// Filters [onGeofenceEvent] to only emit exit events.
  ///
  /// **Example:**
  /// ```dart
  /// Polyfence.instance.onZoneExit.listen((event) {
  ///   print('Exited zone: ${event.zoneId}');
  /// });
  /// ```
  Stream<GeofenceEvent> get onZoneExit =>
      _eventController.stream.where((e) => e.type == GeofenceEventType.exit);

  /// Stream of location updates from GPS.
  ///
  /// Emits [PolyfenceLocation] whenever a new GPS reading is received.
  /// Update frequency depends on GPS configuration.
  ///
  /// **Example:**
  /// ```dart
  /// Polyfence.instance.onLocationUpdate.listen((location) {
  ///   print('Location: ${location.latitude}, ${location.longitude}');
  ///   print('Accuracy: ${location.accuracy}m');
  /// });
  /// ```
  Stream<PolyfenceLocation> get onLocationUpdate => _locationController.stream;

  /// Stream of errors from the plugin.
  ///
  /// Emits [PolyfenceError] whenever an error occurs (GPS failures, permission
  /// issues, platform errors, etc.).
  ///
  /// **Example:**
  /// ```dart
  /// Polyfence.instance.onError.listen((error) {
  ///   print('Error: ${error.type} - ${error.message}');
  /// });
  /// ```
  Stream<PolyfenceError> get onError => _errorController.stream;

  /// Stream of runtime status updates.
  ///
  /// Emits [PolyfenceRuntimeStatus] with current plugin state including
  /// nearest zone distance, GPS accuracy, and tracking status.
  ///
  /// **Example:**
  /// ```dart
  /// Polyfence.instance.runtimeStatus.listen((status) {
  ///   print('Nearest zone: ${status.nearestZoneDistanceM}m away');
  /// });
  /// ```
  Stream<PolyfenceRuntimeStatus> get runtimeStatus =>
      _runtimeStatusController.stream;

  /// Stream of raw status updates from platform.
  ///
  /// Lower-level stream that emits raw status maps from the native platform.
  /// Use [runtimeStatus] for typed status updates.
  Stream<Map<String, dynamic>> get statusStream => _statusController.stream;

  bool _isInitialized = false;
  StreamSubscription<dynamic>? _platformSubscription;
  StreamSubscription<dynamic>? _locationSubscription;
  StreamSubscription<dynamic>? _geofenceSubscription;
  StreamSubscription<dynamic>? _errorSubscription;
  StreamSubscription<Map<String, dynamic>>? _performanceSubscription;

  // Zone cache for event creation (read-only)
  final Map<String, Zone> _zones = {};

  // Current GPS configuration
  PolyfenceConfiguration _currentConfiguration = const PolyfenceConfiguration();

  /// Initialize Polyfence plugin.
  ///
  /// Must be called before using any other methods. Sets up platform channels
  /// and event streams for geofence detection and location updates.
  ///
  /// **Example:**
  /// ```dart
  /// await Polyfence.instance.initialize();
  ///
  /// // With analytics (opt-in):
  /// await Polyfence.instance.initialize(
  ///   analyticsConfig: AnalyticsConfig(
  ///     enabled: true,
  ///     apiKey: 'your-api-key',
  ///   ),
  /// );
  /// ```
  ///
  /// Throws [PlatformOperationException] if platform initialization fails.
  Future<void> initialize({
    String? licenseKey,
    Map<String, dynamic>? config,
    AnalyticsConfig? analyticsConfig,
  }) async {
    if (_isDisposed) {
      throw StateError(
          'PolyfenceService has been disposed and cannot be reused');
    }

    if (_isInitialized) {
      return;
    }

    try {
      // Get plugin version from package info (single source of truth)
      final packageInfo = await PackageInfo.fromPlatform();
      final pluginVersion = packageInfo.version;

      // Pass plugin version to native platforms for debug collectors
      await _platform.initialize(
        licenseKey: licenseKey,
        config: {
          ...?config,
          'pluginVersion': pluginVersion, // Pass version to native
        },
      );

      // Initialize analytics - data collection happens automatically
      // Plugin is the master decider for sending: checks environment variables
      // Apps don't need to pass config - plugin decides independently
      // If app passes analyticsConfig, it is ignored - plugin's decision is final
      final String analyticsEnabledEnv = const String.fromEnvironment(
        'POLYFENCE_ANALYTICS_ENABLED',
        defaultValue: 'false',
      );
      final bool pluginLevelEnabled =
          analyticsEnabledEnv.toLowerCase() == 'true';

      final String apiKeyEnv =
          const String.fromEnvironment('POLYFENCE_API_KEY', defaultValue: '');
      final String apiEndpointEnv = const String.fromEnvironment(
          'POLYFENCE_API_ENDPOINT',
          defaultValue: '');

      // Plugin is the sole master decider - always uses environment variables
      // App config is ignored - plugin's decision cannot be overridden
      final analyticsConfigToUse = AnalyticsConfig(
        enabled: pluginLevelEnabled,
        apiKey: apiKeyEnv.isEmpty ? null : apiKeyEnv,
        apiEndpoint: apiEndpointEnv.isEmpty ? null : apiEndpointEnv,
        // Preserve app-provided metadata if provided (industryCategory, useCase)
        // but plugin controls enabled/API settings
        industryCategory: analyticsConfig?.industryCategory,
        useCase: analyticsConfig?.useCase,
      );

      await PolyfenceAnalytics.instance.initialize(
        config: analyticsConfigToUse,
        pluginVersion: pluginVersion,
      );

      // Initialize app lifecycle management for analytics
      AppLifecycleManager.instance.initialize();

      // Listen to SEPARATE streams
      _locationSubscription =
          _platform.onLocationUpdate.listen(_handleLocationUpdate);
      _geofenceSubscription = (_platform as MethodChannelPolyfence)
          .onGeofenceEvent
          .listen(_handleGeofenceEvent);
      _errorSubscription =
          (_platform as MethodChannelPolyfence).onError.listen(_handleError);
      _performanceSubscription = (_platform as MethodChannelPolyfence)
          .performanceStream
          .listen((event) {
        _handlePerformanceEvent(event);
        if (event['type'] == 'status') {
          _statusController.add(event);
        }
      });

      _isInitialized = true;
    } on PlatformException catch (e) {
      throw PlatformOperationException(
          'initialize', e.message ?? 'Unknown error');
    }
  }

  /// Add a zone for monitoring
  Future<void> addZone(Zone zone) async {
    if (_isDisposed) {
      throw StateError(
          'PolyfenceService has been disposed and cannot be reused');
    }
    if (!_isInitialized) throw PolyfenceNotInitializedException();
    final stopwatch = Stopwatch()..start();

    try {
      // Cache zone for event creation
      _zones[zone.id] = zone;

      // Send to native platform (Android handles all detection)
      await _platform.addZone(zone);

      stopwatch.stop();
    } on PlatformException catch (e) {
      throw PlatformOperationException('addZone', e.message ?? 'Unknown error');
    }
  }

  /// Removes a zone from monitoring.
  ///
  /// The zone will no longer trigger entry/exit events. The zone is also
  /// removed from persistent storage.
  ///
  /// **Example:**
  /// ```dart
  /// await Polyfence.instance.removeZone('office');
  /// ```
  ///
  /// Throws [PolyfenceNotInitializedException] if not initialized.
  /// Throws [PlatformOperationException] if platform error occurs.
  Future<void> removeZone(String zoneId) async {
    if (_isDisposed) {
      throw StateError(
          'PolyfenceService has been disposed and cannot be reused');
    }
    if (!_isInitialized) throw PolyfenceNotInitializedException();

    // Remove from cache
    _zones.remove(zoneId);

    // Remove from native platform
    try {
      await _platform.removeZone(zoneId);
    } on PlatformException catch (e) {
      throw PlatformOperationException(
          'removeZone', e.message ?? 'Unknown error');
    }
  }

  /// Removes all zones from monitoring.
  ///
  /// All zones are cleared from memory and persistent storage. No more
  /// geofence events will be triggered until new zones are added.
  ///
  /// **Example:**
  /// ```dart
  /// await Polyfence.instance.clearAllZones();
  /// ```
  ///
  /// Throws [PolyfenceNotInitializedException] if not initialized.
  /// Throws [PlatformOperationException] if platform error occurs.
  Future<void> clearAllZones() async {
    if (!_isInitialized) throw PolyfenceNotInitializedException();

    // Clear cache
    _zones.clear();

    // Clear from native platform
    try {
      await _platform.clearAllZones();
    } on PlatformException catch (e) {
      throw PlatformOperationException(
          'clearAllZones', e.message ?? 'Unknown error');
    }
  }

  /// Gets all currently monitored zones.
  ///
  /// Returns a read-only list of all zones that have been added. Zones are
  /// returned in the order they were added.
  ///
  /// **Example:**
  /// ```dart
  /// final allZones = Polyfence.instance.zones;
  /// print('Monitoring ${allZones.length} zones');
  /// for (final zone in allZones) {
  ///   print('  - ${zone.name} (${zone.type.name})');
  /// }
  /// ```
  List<Zone> get zones => _zones.values.toList();

  /// Starts background location tracking and geofence monitoring.
  ///
  /// This method will:
  /// 1. Check if location services are enabled
  /// 2. Request location permissions if needed
  /// 3. Start background GPS tracking
  /// 4. Begin monitoring all added zones for entry/exit events
  ///
  /// **Permissions:**
  /// - Android: Requires `ACCESS_FINE_LOCATION` and `ACCESS_BACKGROUND_LOCATION`
  /// - iOS: Requires "Always" location permission for background tracking
  ///
  /// **Example:**
  /// ```dart
  /// // Add zones first
  /// await Polyfence.instance.addZone(officeZone);
  ///
  /// // Listen for events
  /// Polyfence.instance.onGeofenceEvent.listen((event) {
  ///   print('${event.type.name.toUpperCase()}: ${event.zoneId}');
  /// });
  ///
  /// // Start tracking
  /// await Polyfence.instance.startTracking();
  /// ```
  ///
  /// Throws [PolyfenceNotInitializedException] if not initialized.
  /// Throws [PlatformOperationException] if location services disabled or permissions denied.
  Future<void> startTracking() async {
    if (_isDisposed) {
      throw StateError(
          'PolyfenceService has been disposed and cannot be reused');
    }
    if (!_isInitialized) throw PolyfenceNotInitializedException();

    // Check if location services are enabled
    final isEnabled = await _platform.isLocationServiceEnabled();
    if (!isEnabled) {
      throw PlatformOperationException(
          'startTracking', 'Location services not enabled');
    }

    // Request permissions if needed
    final hasPermissions = await _platform.requestPermissions();
    if (!hasPermissions) {
      PolyfenceAnalytics.instance.recordError('permission_denied');
      throw PlatformOperationException(
          'startTracking', 'Location permissions not granted');
    }

    // Start tracking on native platform
    try {
      await _platform.startTracking();
    } on PlatformException catch (e) {
      PolyfenceAnalytics.instance.recordError('tracking_start_failed');
      throw PlatformOperationException(
          'startTracking', e.message ?? 'Unknown error');
    }
  }

  /// Stops location tracking and geofence monitoring.
  ///
  /// GPS tracking stops immediately. Zones remain in memory but won't trigger
  /// events until tracking is started again.
  ///
  /// **Example:**
  /// ```dart
  /// await Polyfence.instance.stopTracking();
  /// ```
  ///
  /// Throws [PolyfenceNotInitializedException] if not initialized.
  /// Throws [PlatformOperationException] if platform error occurs.
  Future<void> stopTracking() async {
    if (_isDisposed) {
      throw StateError(
          'PolyfenceService has been disposed and cannot be reused');
    }
    if (!_isInitialized) throw PolyfenceNotInitializedException();

    try {
      await _platform.stopTracking();
    } on PlatformException catch (e) {
      throw PlatformOperationException(
          'stopTracking', e.message ?? 'Unknown error');
    }
  }

  /// Handle geofence events from dedicated geofence channel
  void _handleGeofenceEvent(Map<String, dynamic> eventData) {
    final zoneId = eventData['zoneId'] as String?;
    final eventType = eventData['eventType'] as String?;
    final detectionTimeMs =
        (eventData['detectionTimeMs'] as num?)?.toDouble() ?? 0.0;
    final gpsAccuracy = (eventData['gpsAccuracy'] as num?)?.toDouble() ?? 0.0;

    // Platform channel type safety: timestamp must be int64 milliseconds
    // Both iOS and Android send int64, but we validate to catch platform bugs
    final timestampRaw = eventData['timestamp'];
    final int timestamp;
    if (timestampRaw is int) {
      timestamp = timestampRaw;
    } else if (timestampRaw is double) {
      // iOS might send double (TimeInterval), convert to int
      timestamp = timestampRaw.toInt();
    } else {
      throw PlatformOperationException(
        '_handleGeofenceEvent',
        'Invalid timestamp type: ${timestampRaw.runtimeType}. Expected int (milliseconds since epoch). Platform may have a bug.',
      );
    }

    if (zoneId == null || eventType == null) {
      return;
    }

    // Get zone from cache
    final zone = _zones[zoneId];

    // Record analytics for detection
    if (zone != null) {
      PolyfenceAnalytics.instance.recordDetection(
        detectionTimeMs: detectionTimeMs,
        gpsAccuracy: gpsAccuracy,
        zoneType: zone.type.name.toLowerCase(), // 'circle' or 'polygon'
      );
    }

    // Extract optional coordinates if provided by platform
    final lat = (eventData['latitude'] as num?)?.toDouble();
    final lng = (eventData['longitude'] as num?)?.toDouble();
    final acc = (eventData['accuracy'] as num?)?.toDouble();

    // Create geofence event
    final geofenceEventType =
        eventType == 'ENTER' ? GeofenceEventType.enter : GeofenceEventType.exit;

    final event = GeofenceEvent(
      zoneId: zoneId,
      type: geofenceEventType,
      location: PolyfenceLocation(
        latitude: lat ?? 0.0,
        longitude: lng ?? 0.0,
        accuracy: acc,
        timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp),
      ),
      timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp),
      zone: zone,
    );

    _eventController.add(event);
  }

  /// Handle location updates from dedicated location channel
  void _handleLocationUpdate(PolyfenceLocation location) {
    // Emit location update to listeners
    _locationController.add(location);
  }

  /// Handle errors from native platforms
  void _handleError(Map<String, dynamic> errorData) {
    try {
      final error = PolyfenceError.fromMap(errorData);

      // Emit error to developer stream
      _errorController.add(error);

      // Still record in analytics for plugin owner metrics
      PolyfenceAnalytics.instance.recordError(
        error.type.toString().split('.').last,
      );
    } catch (e) {
      // If error parsing fails, create a generic error
      final genericError = PolyfenceError(
        type: PolyfenceErrorType.unknown,
        message: 'Failed to parse error: $e',
        context: {'rawError': errorData},
        timestamp: DateTime.now(),
      );
      _errorController.add(genericError);
    }
  }

  /// Gets the current GPS configuration.
  ///
  /// Returns a map containing current GPS settings including update intervals,
  /// accuracy thresholds, and optimization settings.
  ///
  /// **Example:**
  /// ```dart
  /// final config = await Polyfence.instance.configuration();
  /// print('GPS interval: ${config['gps_interval_ms']}ms');
  /// ```
  ///
  /// Throws [PolyfenceNotInitializedException] if not initialized.
  /// Throws [PlatformOperationException] if platform error occurs.
  Future<Map<String, dynamic>> configuration() async {
    if (!_isInitialized) throw PolyfenceNotInitializedException();

    try {
      final config = await _platform.getConfiguration();
      return config;
    } on PlatformException catch (e) {
      throw PlatformOperationException(
          'configuration', e.message ?? 'Unknown error');
    }
  }

  /// Updates GPS configuration.
  ///
  /// Allows fine-tuning GPS behavior for battery vs accuracy tradeoffs.
  /// Configuration changes take effect immediately.
  ///
  /// **Example:**
  /// ```dart
  /// await Polyfence.instance.updateConfiguration({
  ///   'gps_interval_ms': 10000, // 10 seconds
  ///   'gps_accuracy_threshold': 50.0, // 50 meters
  /// });
  /// ```
  ///
  /// Throws [PolyfenceNotInitializedException] if not initialized.
  /// Throws [PlatformOperationException] if platform error occurs.
  Future<void> updateConfiguration(Map<String, dynamic> config) async {
    if (!_isInitialized) throw PolyfenceNotInitializedException();

    try {
      await _platform.updateConfiguration(config);
    } on PlatformException catch (e) {
      throw PlatformOperationException(
          'updateConfiguration', e.message ?? 'Unknown error');
    }
  }

  /// Resets GPS configuration to default values.
  ///
  /// Restores factory defaults for GPS intervals, accuracy thresholds, and
  /// optimization settings.
  ///
  /// **Example:**
  /// ```dart
  /// await Polyfence.instance.resetConfiguration();
  /// ```
  ///
  /// Throws [PolyfenceNotInitializedException] if not initialized.
  /// Throws [PlatformOperationException] if platform error occurs.
  Future<void> resetConfiguration() async {
    if (!_isInitialized) throw PolyfenceNotInitializedException();

    try {
      await _platform.resetConfiguration();
    } on PlatformException catch (e) {
      throw PlatformOperationException(
          'resetConfiguration', e.message ?? 'Unknown error');
    }
  }

  /// Requests location permissions from the user.
  ///
  /// **Android:**
  /// - `always: false` - Requests "While in use" permission
  /// - `always: true` - Requests "Always allow" permission (required for background)
  ///
  /// **iOS:**
  /// - Always requests "Always" permission (required for background geofencing)
  ///
  /// **Example:**
  /// ```dart
  /// final granted = await Polyfence.instance.requestPermissions(always: true);
  /// if (!granted) {
  ///   print('Location permission denied');
  /// }
  /// ```
  ///
  /// Returns `true` if permissions were granted, `false` otherwise.
  ///
  /// Throws [PolyfenceNotInitializedException] if not initialized.
  /// Throws [PlatformOperationException] if platform error occurs.
  Future<bool> requestPermissions({bool always = false}) async {
    if (!_isInitialized) throw PolyfenceNotInitializedException();

    try {
      final result = await _platform.requestPermissions(always: always);
      return result;
    } on PlatformException catch (e) {
      throw PlatformOperationException(
          'requestPermissions', e.message ?? 'Unknown error');
    }
  }

  /// Checks if location services are enabled on the device.
  ///
  /// Returns `true` if GPS/location services are enabled, `false` otherwise.
  /// This checks the system-level location setting, not app permissions.
  ///
  /// **Example:**
  /// ```dart
  /// final enabled = await Polyfence.instance.isLocationServiceEnabled();
  /// if (!enabled) {
  ///   // Guide user to enable location services in settings
  /// }
  /// ```
  ///
  /// Throws [PolyfenceNotInitializedException] if not initialized.
  /// Throws [PlatformOperationException] if platform error occurs.
  Future<bool> isLocationServiceEnabled() async {
    if (!_isInitialized) throw PolyfenceNotInitializedException();

    try {
      final result = await _platform.isLocationServiceEnabled();
      return result;
    } on PlatformException catch (e) {
      throw PlatformOperationException(
          'isLocationServiceEnabled', e.message ?? 'Unknown error');
    }
  }

  /// Checks battery optimization status (Android only).
  ///
  /// Battery optimization can prevent background location tracking. This method
  /// checks if the app is exempt from battery optimization.
  ///
  /// **Returns:**
  /// - `isOptimized`: `true` if battery optimization is enabled (may affect tracking)
  /// - `canRequest`: `true` if user can be prompted to disable optimization
  ///
  /// **Example:**
  /// ```dart
  /// final status = await Polyfence.instance.batteryOptimizationStatus();
  /// if (status['isOptimized'] == true) {
  ///   // Request exemption for reliable background tracking
  ///   await Polyfence.instance.requestBatteryOptimizationExemption();
  /// }
  /// ```
  ///
  /// **Note:** iOS doesn't have battery optimization, so this always returns
  /// `isOptimized: false` on iOS.
  ///
  /// Throws [PolyfenceNotInitializedException] if not initialized.
  /// Throws [PlatformOperationException] if platform error occurs.
  Future<Map<String, dynamic>> batteryOptimizationStatus() async {
    if (!_isInitialized) throw PolyfenceNotInitializedException();

    try {
      final result = await _platform.checkBatteryOptimization();
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw PlatformOperationException(
          'batteryOptimizationStatus', e.message ?? 'Unknown error');
    }
  }

  /// Requests exemption from battery optimization (Android only).
  ///
  /// Opens a system dialog asking the user to disable battery optimization
  /// for your app. This is recommended for reliable background geofencing.
  ///
  /// **Example:**
  /// ```dart
  /// final status = await Polyfence.instance.batteryOptimizationStatus();
  /// if (status['isOptimized'] == true && status['canRequest'] == true) {
  ///   final exempted = await Polyfence.instance.requestBatteryOptimizationExemption();
  ///   if (exempted) {
  ///     print('Battery optimization disabled - background tracking will be reliable');
  ///   }
  /// }
  /// ```
  ///
  /// Returns `true` if user granted exemption, `false` if denied.
  ///
  /// **Note:** iOS doesn't have battery optimization, so this always returns
  /// `true` on iOS (no-op).
  ///
  /// Throws [PolyfenceNotInitializedException] if not initialized.
  /// Throws [PlatformOperationException] if platform error occurs.
  Future<bool> requestBatteryOptimizationExemption() async {
    if (!_isInitialized) throw PolyfenceNotInitializedException();

    try {
      final result = await _platform.requestBatteryOptimizationExemption();
      return result;
    } on PlatformException catch (e) {
      throw PlatformOperationException(
          'requestBatteryOptimizationExemption', e.message ?? 'Unknown error');
    }
  }

  /// Gets comprehensive debug information about the plugin state.
  ///
  /// Returns detailed information including:
  /// - Zone count and status
  /// - GPS accuracy and health
  /// - Battery usage estimates
  /// - Detection statistics
  /// - Error counts
  ///
  /// **Example:**
  /// ```dart
  /// final debugInfo = await Polyfence.instance.debugInfo();
  /// print('Zones monitored: ${debugInfo.zonesCount}');
  /// print('GPS accuracy: ${debugInfo.lastKnownAccuracy}m');
  /// print('Detections: ${debugInfo.totalDetections}');
  /// ```
  ///
  /// Throws [PolyfenceNotInitializedException] if not initialized.
  /// Throws [PlatformOperationException] if platform error occurs.
  Future<PolyfenceDebugInfo> debugInfo() async {
    if (!_isInitialized) throw PolyfenceNotInitializedException();

    try {
      final result = await _platform.getDebugInfo();
      return PolyfenceDebugInfo.fromMap(Map<String, dynamic>.from(result));
    } on PlatformException catch (e) {
      throw PlatformOperationException(
          'debugInfo', e.message ?? 'Unknown error');
    }
  }

  /// Stream of performance metrics from the plugin.
  ///
  /// Emits [PolyfencePerformanceMetrics] with performance data including
  /// detection latencies, GPS accuracy statistics, and battery usage.
  ///
  /// **Example:**
  /// ```dart
  /// Polyfence.instance.performanceStream.listen((metrics) {
  ///   print('Average detection latency: ${metrics.averageDetectionLatency}ms');
  ///   print('GPS accuracy ratio: ${metrics.gpsOkRatio}');
  /// });
  /// ```
  Stream<PolyfencePerformanceMetrics> get performanceStream {
    return (_platform as MethodChannelPolyfence)
        .performanceStream
        .map((event) => PolyfencePerformanceMetrics.fromMap(event));
  }

  /// Gets error history for debugging and monitoring.
  ///
  /// Returns a list of errors that occurred within the specified time range
  /// and/or error types. Useful for troubleshooting and understanding plugin
  /// behavior in production.
  ///
  /// **Example:**
  /// ```dart
  /// // Get all errors from last hour
  /// final errors = await Polyfence.instance.errorHistory(
  ///   timeRange: Duration(hours: 1),
  /// );
  ///
  /// // Get only GPS errors from last 24 hours
  /// final gpsErrors = await Polyfence.instance.errorHistory(
  ///   timeRange: Duration(hours: 24),
  ///   errorTypes: [PolyfenceErrorType.gpsError],
  /// );
  /// ```
  ///
  /// Throws [PolyfenceNotInitializedException] if not initialized.
  /// Throws [PlatformOperationException] if platform error occurs.
  Future<List<PolyfenceErrorSummary>> errorHistory({
    Duration? timeRange,
    List<PolyfenceErrorType>? errorTypes,
  }) async {
    if (!_isInitialized) throw PolyfenceNotInitializedException();

    final params = {
      'timeRangeMs': timeRange?.inMilliseconds,
      'errorTypes':
          errorTypes?.map((e) => e.toString().split('.').last).toList(),
    };

    try {
      final result = await _platform.getErrorHistory(params);
      return (result as List)
          .map((e) => PolyfenceErrorSummary.fromMap(e))
          .toList();
    } on PlatformException catch (e) {
      throw PlatformOperationException(
          'errorHistory', e.message ?? 'Unknown error');
    }
  }

  // ============================================================================
  // GPS CONFIGURATION API
  // ============================================================================

  /// Updates GPS configuration with advanced settings.
  ///
  /// Allows fine-grained control over GPS behavior including accuracy profiles,
  /// update strategies, and optimization settings. Configuration changes take
  /// effect immediately.
  ///
  /// **Example:**
  /// ```dart
  /// await Polyfence.instance.updateGpsConfiguration(
  ///   PolyfenceConfiguration(
  ///     accuracyProfile: PolyfenceAccuracyProfile.balanced,
  ///     updateStrategy: PolyfenceUpdateStrategy.proximityBased,
  ///     gpsAccuracyThreshold: 50.0, // 50 meters
  ///     proximitySettings: ProximitySettings(
  ///       nearZoneThresholdMeters: 500.0,
  ///       farZoneThresholdMeters: 2000.0,
  ///     ),
  ///   ),
  /// );
  /// ```
  ///
  /// Throws [PolyfenceNotInitializedException] if not initialized.
  /// Throws [PlatformOperationException] if platform error occurs.
  Future<void> updateGpsConfiguration(PolyfenceConfiguration config) async {
    if (!_isInitialized) throw PolyfenceNotInitializedException();

    try {
      final configMap = config.toMap();
      await _platform.updateConfiguration(configMap);

      // Update local configuration
      _currentConfiguration = config;
    } on PlatformException catch (e) {
      throw PlatformOperationException(
          'updateConfiguration', e.message ?? 'Unknown error');
    }
  }

  /// Gets the current GPS configuration.
  ///
  /// Returns the active [PolyfenceConfiguration] with all current GPS settings
  /// including accuracy profile, update strategy, and optimization parameters.
  ///
  /// **Example:**
  /// ```dart
  /// final config = await Polyfence.instance.gpsConfiguration();
  /// print('Accuracy profile: ${config.accuracyProfile}');
  /// print('GPS threshold: ${config.gpsAccuracyThreshold}m');
  /// ```
  ///
  /// Throws [PolyfenceNotInitializedException] if not initialized.
  /// Throws [PlatformOperationException] if platform error occurs.
  Future<PolyfenceConfiguration> gpsConfiguration() async {
    if (!_isInitialized) throw PolyfenceNotInitializedException();

    try {
      final result = await _platform.getCurrentConfiguration();
      _currentConfiguration = PolyfenceConfiguration.fromMap(result);
      return _currentConfiguration;
    } on PlatformException catch (e) {
      throw PlatformOperationException(
          'gpsConfiguration', e.message ?? 'Unknown error');
    }
  }

  /// Sets GPS accuracy profile for common use cases.
  ///
  /// Quick way to configure GPS behavior using predefined profiles:
  /// - [PolyfenceAccuracyProfile.maxAccuracy] - High accuracy, high battery usage
  /// - [PolyfenceAccuracyProfile.balanced] - Balanced accuracy and battery
  /// - [PolyfenceAccuracyProfile.batteryOptimal] - Low battery usage, lower accuracy
  /// - [PolyfenceAccuracyProfile.adaptive] - Automatically adjusts based on context
  ///
  /// **Example:**
  /// ```dart
  /// // For delivery tracking - need high accuracy
  /// await Polyfence.instance.setAccuracyProfile(
  ///   PolyfenceAccuracyProfile.maxAccuracy,
  /// );
  ///
  /// // For background monitoring - save battery
  /// await Polyfence.instance.setAccuracyProfile(
  ///   PolyfenceAccuracyProfile.batteryOptimal,
  /// );
  /// ```
  ///
  /// Throws [PolyfenceNotInitializedException] if not initialized.
  /// Throws [PlatformOperationException] if platform error occurs.
  Future<void> setAccuracyProfile(PolyfenceAccuracyProfile profile) async {
    if (!_isInitialized) throw PolyfenceNotInitializedException();

    final profileKey = EnumUtils.toChannelFormat(profile.name);
    await _platform.setAccuracyProfile(profileKey);

    final existing = _currentConfiguration;
    _currentConfiguration = existing.copyWith(accuracyProfile: profile);
  }

  /// Enables proximity-based GPS optimization.
  ///
  /// Adjusts GPS update frequency based on distance to zones:
  /// - **Near zones** (< `nearThreshold`): High frequency for accurate entry detection
  /// - **Far from zones** (> `farThreshold`): Low frequency to save battery
  ///
  /// This can reduce GPS usage by 60-80% for users who spend time away from zones.
  ///
  /// **Example:**
  /// ```dart
  /// await Polyfence.instance.enableProximityOptimization(
  ///   nearThreshold: 500.0,  // High accuracy within 500m of zones
  ///   farThreshold: 2000.0,  // Low frequency when >2km from zones
  /// );
  /// ```
  ///
  /// Throws [PolyfenceNotInitializedException] if not initialized.
  /// Throws [PlatformOperationException] if platform error occurs.
  Future<void> enableProximityOptimization({
    double nearThreshold = 500.0,
    double farThreshold = 2000.0,
  }) async {
    final config = PolyfenceConfiguration(
      updateStrategy: PolyfenceUpdateStrategy.proximityBased,
      proximitySettings: ProximitySettings(
        nearZoneThresholdMeters: nearThreshold,
        farZoneThresholdMeters: farThreshold,
      ),
    );
    await updateGpsConfiguration(config);
  }

  /// Enables movement-based GPS optimization.
  ///
  /// Adjusts GPS update frequency based on device movement:
  /// - **Stationary** (no movement for `stationaryThreshold`): Low frequency
  /// - **Moving**: Higher frequency (`stationaryUpdateInterval`)
  ///
  /// Reduces battery drain when device is stationary (e.g., user at desk).
  ///
  /// **Example:**
  /// ```dart
  /// await Polyfence.instance.enableMovementOptimization(
  ///   stationaryThreshold: Duration(minutes: 5), // Consider stationary after 5 min
  ///   stationaryUpdateInterval: Duration(minutes: 2), // Update every 2 min when stationary
  /// );
  /// ```
  ///
  /// Throws [PolyfenceNotInitializedException] if not initialized.
  /// Throws [PlatformOperationException] if platform error occurs.
  Future<void> enableMovementOptimization({
    Duration stationaryThreshold = const Duration(minutes: 5),
    Duration stationaryUpdateInterval = const Duration(minutes: 2),
  }) async {
    final config = PolyfenceConfiguration(
      updateStrategy: PolyfenceUpdateStrategy.movementBased,
      movementSettings: MovementSettings(
        stationaryThreshold: stationaryThreshold,
        stationaryUpdateInterval: stationaryUpdateInterval,
      ),
    );
    await updateGpsConfiguration(config);
  }

  /// Enables intelligent GPS optimization.
  ///
  /// Combines proximity-based, movement-based, and battery-aware optimizations
  /// for optimal balance between accuracy and battery life. Automatically adjusts
  /// GPS behavior based on:
  /// - Distance to nearest zone
  /// - Device movement state
  /// - Battery level
  ///
  /// **Example:**
  /// ```dart
  /// await Polyfence.instance.enableIntelligentOptimization();
  /// ```
  ///
  /// Throws [PolyfenceNotInitializedException] if not initialized.
  /// Throws [PlatformOperationException] if platform error occurs.
  Future<void> enableIntelligentOptimization() async {
    const config = PolyfenceConfiguration(
      accuracyProfile: PolyfenceAccuracyProfile.adaptive,
      updateStrategy: PolyfenceUpdateStrategy.intelligent,
      proximitySettings: ProximitySettings(),
      movementSettings: MovementSettings(),
      batterySettings: BatterySettings(),
    );
    await updateGpsConfiguration(config);
  }

  /// Resets GPS configuration to default (max accuracy).
  ///
  /// Restores factory defaults: maximum accuracy profile with continuous
  /// update strategy. Useful for resetting after testing different configurations.
  ///
  /// **Example:**
  /// ```dart
  /// await Polyfence.instance.resetToDefaultConfiguration();
  /// ```
  ///
  /// Throws [PolyfenceNotInitializedException] if not initialized.
  /// Throws [PlatformOperationException] if platform error occurs.
  Future<void> resetToDefaultConfiguration() async {
    const config = PolyfenceConfiguration();
    await updateGpsConfiguration(config);
  }

  /// Gets the current GPS configuration (cached).
  ///
  /// Returns the last known [PolyfenceConfiguration] without querying the platform.
  /// For the latest configuration from the platform, use [gpsConfiguration].
  ///
  /// **Example:**
  /// ```dart
  /// final config = Polyfence.instance.currentConfiguration;
  /// print('Current accuracy profile: ${config.accuracyProfile}');
  /// ```
  PolyfenceConfiguration get currentConfiguration => _currentConfiguration;

  /// Dispose resources
  ///
  /// Performs comprehensive cleanup of all SDK resources including:
  /// - Stream subscriptions and controllers
  /// - Analytics session
  /// - App lifecycle manager
  /// - Zone cache
  ///
  /// After disposal, the service cannot be reused. Any calls to public methods
  /// will throw [StateError].
  Future<void> dispose() async {
    if (_isDisposed) return; // Prevent double-disposal
    _isDisposed = true;

    try {
      // 1. Stop tracking if active (graceful shutdown)
      if (_isInitialized) {
        try {
          await stopTracking();
        } catch (_) {
          // Ignore errors during disposal
        }
      }

      // 2. Cancel all stream subscriptions
      await _platformSubscription?.cancel();
      await _locationSubscription?.cancel();
      await _geofenceSubscription?.cancel();
      await _errorSubscription?.cancel();
      await _performanceSubscription?.cancel();

      // 3. Close all stream controllers
      await _runtimeStatusController.close();
      await _eventController.close();
      await _locationController.close();
      await _errorController.close();
      await _statusController.close(); // ← FIX: Was missing

      // 4. Cleanup analytics session
      try {
        await PolyfenceAnalytics.instance.endSession();
      } catch (_) {
        // Analytics cleanup is best-effort
      }

      // 5. Dispose app lifecycle manager
      try {
        AppLifecycleManager.instance.dispose();
      } catch (_) {
        // Lifecycle cleanup is best-effort
      }

      // 6. Clear zone cache
      _zones.clear();

      // 7. Reset initialization flag
      _isInitialized = false;

      // 8. Notify platform of disposal
      try {
        await _platform.dispose();
      } catch (_) {
        // Platform disposal is best-effort
      }
    } catch (e) {
      // Log disposal error but don't throw (disposal should never fail)
      // ignore: avoid_print
      print('Error during Polyfence disposal: $e');
    }
  }

  void _handlePerformanceEvent(Map<String, dynamic> event) {
    final type = event['type'];
    if (type != 'runtime_status') return;

    final rawData = event['data'];
    if (rawData is! Map) return;

    try {
      final data = Map<String, dynamic>.from(rawData);
      final status = PolyfenceRuntimeStatus.fromMap(data);
      if (!_runtimeStatusController.isClosed) {
        _runtimeStatusController.add(status);
      }
    } catch (e) {
      // Failed to parse runtime status
    }
  }
}
