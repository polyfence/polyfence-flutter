import 'dart:async';
import 'package:flutter/services.dart';
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

  // Public streams
  Stream<GeofenceEvent> get onGeofenceEvent => _eventController.stream;
  Stream<GeofenceEvent> get onZoneEnter =>
      _eventController.stream.where((e) => e.type == GeofenceEventType.enter);
  Stream<GeofenceEvent> get onZoneExit =>
      _eventController.stream.where((e) => e.type == GeofenceEventType.exit);
  Stream<PolyfenceLocation> get onLocationUpdate => _locationController.stream;
  Stream<PolyfenceError> get onError => _errorController.stream;
  Stream<PolyfenceRuntimeStatus> get runtimeStatus =>
      _runtimeStatusController.stream;
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

  /// Initialize Polyfence
  Future<void> initialize({
    String? licenseKey,
    Map<String, dynamic>? config,
    AnalyticsConfig? analyticsConfig,
  }) async {
    if (_isInitialized) {
      return;
    }

    try {
      await _platform.initialize(licenseKey: licenseKey, config: config);

      // Initialize analytics if configured
      if (analyticsConfig != null) {
        await PolyfenceAnalytics.instance.initialize(
          config: analyticsConfig,
          pluginVersion: '0.1.0', // This should come from package info
        );

        // Initialize app lifecycle management for analytics
        AppLifecycleManager.instance.initialize();
      }

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
      throw PlatformOperationException('initialize', e.message ?? 'Unknown error');
    }
  }

  /// Add a zone for monitoring
  Future<void> addZone(Zone zone) async {
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

  /// Remove a zone
  Future<void> removeZone(String zoneId) async {
    if (!_isInitialized) throw PolyfenceNotInitializedException();

    // Remove from cache
    _zones.remove(zoneId);

    // Remove from native platform
    try {
      await _platform.removeZone(zoneId);
    } on PlatformException catch (e) {
      throw PlatformOperationException('removeZone', e.message ?? 'Unknown error');
    }
  }

  /// Clear all zones
  Future<void> clearAllZones() async {
    if (!_isInitialized) throw PolyfenceNotInitializedException();

    // Clear cache
    _zones.clear();

    // Clear from native platform
    try {
      await _platform.clearAllZones();
    } on PlatformException catch (e) {
      throw PlatformOperationException('clearAllZones', e.message ?? 'Unknown error');
    }
  }

  /// Get all zones (read-only)
  List<Zone> get zones => _zones.values.toList();

  /// Start location tracking
  Future<void> startTracking() async {
    if (!_isInitialized) throw PolyfenceNotInitializedException();

    // Check if location services are enabled
    final isEnabled = await _platform.isLocationServiceEnabled();
    if (!isEnabled) {
      throw PlatformOperationException('startTracking', 'Location services not enabled');
    }

    // Request permissions if needed
    final hasPermissions = await _platform.requestPermissions();
    if (!hasPermissions) {
      PolyfenceAnalytics.instance.recordError('permission_denied');
      throw PlatformOperationException('startTracking', 'Location permissions not granted');
    }

    // Start tracking on native platform
    try {
      await _platform.startTracking();
    } on PlatformException catch (e) {
      PolyfenceAnalytics.instance.recordError('tracking_start_failed');
      throw PlatformOperationException('startTracking', e.message ?? 'Unknown error');
    }
  }

  /// Stop location tracking
  Future<void> stopTracking() async {
    if (!_isInitialized) throw PolyfenceNotInitializedException();

    try {
      await _platform.stopTracking();
    } on PlatformException catch (e) {
      throw PlatformOperationException('stopTracking', e.message ?? 'Unknown error');
    }
  }

  /// Handle geofence events from dedicated geofence channel
  void _handleGeofenceEvent(Map<String, dynamic> eventData) {
    final zoneId = eventData['zoneId'] as String?;
    final eventType = eventData['eventType'] as String?;
    final detectionTimeMs =
        (eventData['detectionTimeMs'] as num?)?.toDouble() ?? 0.0;
    final gpsAccuracy = (eventData['gpsAccuracy'] as num?)?.toDouble() ?? 0.0;

    // Fix: Handle both int and double timestamp from iOS/Android
    final timestampRaw = eventData['timestamp'];
    final timestamp = timestampRaw is int
        ? timestampRaw
        : timestampRaw is double
            ? timestampRaw.toInt()
            : DateTime.now().millisecondsSinceEpoch;

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

  /// Get current configuration from Android
  Future<Map<String, dynamic>> configuration() async {
    if (!_isInitialized) throw PolyfenceNotInitializedException();

    try {
      final config = await _platform.getConfiguration();
      return config;
    } on PlatformException catch (e) {
      throw PlatformOperationException('configuration', e.message ?? 'Unknown error');
    }
  }

  /// Update configuration on Android
  Future<void> updateConfiguration(Map<String, dynamic> config) async {
    if (!_isInitialized) throw PolyfenceNotInitializedException();

    try {
      await _platform.updateConfiguration(config);
    } on PlatformException catch (e) {
      throw PlatformOperationException('updateConfiguration', e.message ?? 'Unknown error');
    }
  }

  /// Reset configuration to defaults
  Future<void> resetConfiguration() async {
    if (!_isInitialized) throw PolyfenceNotInitializedException();

    try {
      await _platform.resetConfiguration();
    } on PlatformException catch (e) {
      throw PlatformOperationException('resetConfiguration', e.message ?? 'Unknown error');
    }
  }

  /// Request location permissions
  Future<bool> requestPermissions({bool always = false}) async {
    if (!_isInitialized) throw PolyfenceNotInitializedException();

    try {
      final result = await _platform.requestPermissions(always: always);
      return result;
    } on PlatformException catch (e) {
      throw PlatformOperationException('requestPermissions', e.message ?? 'Unknown error');
    }
  }

  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    if (!_isInitialized) throw PolyfenceNotInitializedException();

    try {
      final result = await _platform.isLocationServiceEnabled();
      return result;
    } on PlatformException catch (e) {
      throw PlatformOperationException('isLocationServiceEnabled', e.message ?? 'Unknown error');
    }
  }

  /// Check battery optimization status (Android only)
  Future<Map<String, dynamic>> batteryOptimizationStatus() async {
    if (!_isInitialized) throw PolyfenceNotInitializedException();

    try {
      final result = await _platform.checkBatteryOptimization();
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw PlatformOperationException('batteryOptimizationStatus', e.message ?? 'Unknown error');
    }
  }

  /// Request battery optimization exemption (Android only)
  Future<bool> requestBatteryOptimizationExemption() async {
    if (!_isInitialized) throw PolyfenceNotInitializedException();

    try {
      final result = await _platform.requestBatteryOptimizationExemption();
      return result;
    } on PlatformException catch (e) {
      throw PlatformOperationException('requestBatteryOptimizationExemption', e.message ?? 'Unknown error');
    }
  }

  /// Get comprehensive debug information
  Future<PolyfenceDebugInfo> debugInfo() async {
    if (!_isInitialized) throw PolyfenceNotInitializedException();

    try {
      final result = await _platform.getDebugInfo();
      return PolyfenceDebugInfo.fromMap(Map<String, dynamic>.from(result));
    } on PlatformException catch (e) {
      throw PlatformOperationException('debugInfo', e.message ?? 'Unknown error');
    }
  }

  /// Get performance metrics stream
  Stream<PolyfencePerformanceMetrics> get performanceStream {
    return (_platform as MethodChannelPolyfence)
        .performanceStream
        .map((event) => PolyfencePerformanceMetrics.fromMap(event));
  }

  /// Get error history
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
      throw PlatformOperationException('errorHistory', e.message ?? 'Unknown error');
    }
  }

  // ============================================================================
  // GPS CONFIGURATION API
  // ============================================================================

  /// Update GPS configuration
  Future<void> updateGpsConfiguration(PolyfenceConfiguration config) async {
    if (!_isInitialized) throw PolyfenceNotInitializedException();

    try {
      final configMap = config.toMap();
      await _platform.updateConfiguration(configMap);

      // Update local configuration
      _currentConfiguration = config;
    } on PlatformException catch (e) {
      throw PlatformOperationException('updateConfiguration', e.message ?? 'Unknown error');
    }
  }

  /// Get current GPS configuration
  Future<PolyfenceConfiguration> gpsConfiguration() async {
    if (!_isInitialized) throw PolyfenceNotInitializedException();

    try {
      final result = await _platform.getCurrentConfiguration();
      _currentConfiguration = PolyfenceConfiguration.fromMap(result);
      return _currentConfiguration;
    } on PlatformException catch (e) {
      throw PlatformOperationException('gpsConfiguration', e.message ?? 'Unknown error');
    }
  }

  /// Quick profile setter for common use cases
  Future<void> setAccuracyProfile(PolyfenceAccuracyProfile profile) async {
    if (!_isInitialized) throw PolyfenceNotInitializedException();

    final profileKey = EnumUtils.toChannelFormat(profile.name);
    await _platform.setAccuracyProfile(profileKey);

    final existing = _currentConfiguration;
    _currentConfiguration = existing.copyWith(accuracyProfile: profile);
  }

  /// Enable proximity-based optimization
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

  /// Enable movement-based optimization
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

  /// Enable intelligent optimization (proximity + movement + battery)
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

  /// Reset to default configuration (max accuracy)
  Future<void> resetToDefaultConfiguration() async {
    const config = PolyfenceConfiguration();
    await updateGpsConfiguration(config);
  }

  /// Get current configuration (cached)
  PolyfenceConfiguration get currentConfiguration => _currentConfiguration;

  /// Dispose resources
  void dispose() {
    _platformSubscription?.cancel();
    _locationSubscription?.cancel();
    _geofenceSubscription?.cancel();
    _errorSubscription?.cancel();
    _performanceSubscription?.cancel();
    _runtimeStatusController.close();
    _eventController.close();
    _locationController.close();
    _errorController.close();
    _zones.clear();
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
