import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import '../version.dart';
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

  // Analytics availability flag — false if analytics initialization failed.
  // When false, all analytics calls are silently skipped so analytics
  // can never take down core geofencing functionality.
  bool _analyticsAvailable = false;

  // Lifecycle manager availability flag — false if initialization failed.
  // When false, lifecycle cleanup is skipped during dispose.
  bool _lifecycleManagerAvailable = false;

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
  StreamSubscription<dynamic>? _locationSubscription;
  StreamSubscription<dynamic>? _geofenceSubscription;
  StreamSubscription<dynamic>? _errorSubscription;
  StreamSubscription<Map<String, dynamic>>? _performanceSubscription;

  // Zone cache for event creation (read-only)
  final Map<String, Zone> _zones = {};

  // Current GPS configuration
  PolyfenceConfiguration _currentConfiguration = PolyfenceConfiguration();

  /// Initialize Polyfence plugin.
  ///
  /// Must be called before using any other methods. Sets up platform channels
  /// and event streams for geofence detection and location updates.
  ///
  /// **Example:**
  /// ```dart
  /// await Polyfence.instance.initialize();
  ///
  /// // With custom notification behavior:
  /// await Polyfence.instance.initialize(
  ///   config: {
  ///     'disableAlertNotifications': true, // Suppress built-in zone alerts
  ///   },
  /// );
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
      // Get plugin version from version constant (plugin's own version, not app's)
      // This ensures we always use the plugin's version, not the app's version
      const pluginVersion = polyfencePluginVersion;

      // Pass plugin version to native platforms for debug collectors
      await _platform.initialize(
        licenseKey: licenseKey,
        config: {
          ...?config,
          'pluginVersion': pluginVersion, // Pass version to native
        },
      );

      // Initialize analytics — isolated so failures never block geofencing.
      // Anonymous plugin telemetry enabled by default. No location data or PII
      // ever sent — only plugin performance metrics.
      try {
        // Check if developer opted out
        final bool telemetryDisabled =
            analyticsConfig?.disableTelemetry ?? false;

        // Environment variables can still override for production builds
        const String analyticsEnabledEnv = String.fromEnvironment(
          'POLYFENCE_ANALYTICS_ENABLED',
          defaultValue: '',
        );
        final bool envOverride = analyticsEnabledEnv.isNotEmpty;
        final bool envEnabled = analyticsEnabledEnv.toLowerCase() == 'true';

        const String apiKeyEnv =
            String.fromEnvironment('POLYFENCE_API_KEY', defaultValue: '');
        const String apiEndpointEnv =
            String.fromEnvironment('POLYFENCE_API_ENDPOINT', defaultValue: '');

        // Determine final telemetry state:
        // 1. If env var set → use it (production override)
        // 2. If developer set disableTelemetry: true → respect it
        // 3. Otherwise → enabled by default
        final bool telemetryEnabled =
            envOverride ? envEnabled : !telemetryDisabled;

        final analyticsConfigToUse = AnalyticsConfig(
          enabled: telemetryEnabled,
          disableTelemetry: telemetryDisabled,
          apiKey:
              analyticsConfig?.apiKey ?? (apiKeyEnv.isEmpty ? null : apiKeyEnv),
          apiEndpoint: analyticsConfig?.apiEndpoint ??
              (apiEndpointEnv.isEmpty ? null : apiEndpointEnv),
          industryCategory: analyticsConfig?.industryCategory,
          useCase: analyticsConfig?.useCase,
        );

        await PolyfenceAnalytics.instance.initialize(
          config: analyticsConfigToUse,
          pluginVersion: pluginVersion,
          sessionTelemetryFetcher: () => _platform.getSessionTelemetry(),
        );

        _analyticsAvailable = true;

        // Set config context for telemetry (accuracy profile, update strategy)
        PolyfenceAnalytics.instance.setConfigContext(
          accuracyProfile: _currentConfiguration.accuracyProfile.name,
          updateStrategy: _currentConfiguration.updateStrategy.name,
        );

        // Telemetry disclosure: show once per install or when state changes
        // Only in debug builds to avoid production log spam
        await _showTelemetryDisclosureIfNeeded(telemetryEnabled);
      } catch (e) {
        // Analytics failed — log and continue. Core geofencing must not
        // be blocked by telemetry failures.
        _analyticsAvailable = false;
        if (kDebugMode) {
          debugPrint('Polyfence: Analytics initialization failed: $e');
        }
      }

      // Initialize app lifecycle manager — separate concern from analytics.
      // Manages foreground/background session transitions. Failures must not
      // block geofencing.
      try {
        AppLifecycleManager.instance.initialize();
        _lifecycleManagerAvailable = true;
      } catch (e) {
        _lifecycleManagerAvailable = false;
        if (kDebugMode) {
          debugPrint(
              'Polyfence: App lifecycle manager initialization failed: $e');
        }
      }

      // Listen to SEPARATE streams — each with onError to prevent uncaught
      // async exceptions and onDone to detect unexpected stream closures.
      _locationSubscription = _platform.onLocationUpdate.listen(
        _handleLocationUpdate,
        onError: (Object error, StackTrace stackTrace) {
          _emitStreamError('location', error, stackTrace);
        },
        onDone: () {
          _emitStreamDone('location');
        },
      );
      _geofenceSubscription = _platform.onGeofenceEvent.listen(
        _handleGeofenceEvent,
        onError: (Object error, StackTrace stackTrace) {
          _emitStreamError('geofence', error, stackTrace);
        },
        onDone: () {
          _emitStreamDone('geofence');
        },
      );
      _errorSubscription = _platform.onError.listen(
        _handleError,
        onError: (Object error, StackTrace stackTrace) {
          // Error stream itself failed — emit directly without recursion.
          // Use debugPrint as fallback since _errorController is the
          // destination and the source stream is the one that errored.
          _emitStreamError('error', error, stackTrace);
        },
        onDone: () {
          _emitStreamDone('error');
        },
      );
      _performanceSubscription = _platform.performanceStream.listen(
        (event) {
          _handlePerformanceEvent(event);
          if (event['type'] == 'status') {
            _statusController.add(event);
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          _emitStreamError('performance', error, stackTrace);
        },
        onDone: () {
          _emitStreamDone('performance');
        },
      );

      _isInitialized = true;
    } on PlatformException catch (e, stackTrace) {
      throw PlatformOperationException(
        'initialize',
        e.message ?? 'Unknown error',
        details: {'code': e.code, 'details': e.details},
        innerException: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Adds a zone for monitoring.
  ///
  /// The zone will be persisted and start generating entry/exit events once
  /// tracking is started. Both circle and polygon zones are supported.
  ///
  /// **Example:**
  /// ```dart
  /// final zone = Zone.circle(
  ///   id: 'office',
  ///   name: 'Office',
  ///   center: PolyfenceLocation(latitude: 37.422, longitude: -122.084),
  ///   radius: 150,
  /// );
  /// await Polyfence.instance.addZone(zone);
  /// ```
  ///
  /// Throws [PolyfenceNotInitializedException] if not initialized.
  /// Throws [PlatformOperationException] if platform error occurs.
  Future<void> addZone(Zone zone) async {
    if (_isDisposed) {
      throw StateError(
          'PolyfenceService has been disposed and cannot be reused');
    }
    if (!_isInitialized) throw PolyfenceNotInitializedException();

    try {
      // Cache zone for event creation
      _zones[zone.id] = zone;

      // Send to native platform (Android handles all detection)
      await _platform.addZone(zone);
    } on PlatformException catch (e, stackTrace) {
      throw PlatformOperationException(
        'addZone',
        e.message ?? 'Unknown error',
        details: {'code': e.code, 'details': e.details, 'zoneId': zone.id},
        innerException: e,
        stackTrace: stackTrace,
      );
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
    } on PlatformException catch (e, stackTrace) {
      throw PlatformOperationException(
        'removeZone',
        e.message ?? 'Unknown error',
        details: {'code': e.code, 'details': e.details, 'zoneId': zoneId},
        innerException: e,
        stackTrace: stackTrace,
      );
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
    } on PlatformException catch (e, stackTrace) {
      throw PlatformOperationException(
        'clearAllZones',
        e.message ?? 'Unknown error',
        details: {'code': e.code, 'details': e.details},
        innerException: e,
        stackTrace: stackTrace,
      );
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

  /// Gets the current INSIDE/OUTSIDE state for all monitored zones.
  ///
  /// Returns a map where:
  /// - Keys are zone IDs.
  /// - Values are `true` if the native engine's persisted state says the
  ///   device is currently INSIDE the zone, `false` if it says OUTSIDE.
  ///
  /// This is the same internal state used by the native `GeofenceEngine`
  /// for `reconcileZoneStates` and `RECOVERY_ENTER`/`RECOVERY_EXIT` events.
  /// It does **not** perform a fresh GPS point-in-polygon check.
  ///
  /// Only zones currently tracked by the engine are included in the map.
  ///
  /// **Example:**
  /// ```dart
  /// final states = await Polyfence.instance.getZoneStates();
  /// if (states['office'] == true) {
  ///   print('Device is currently inside the office zone');
  /// }
  /// ```
  ///
  /// Throws [PolyfenceNotInitializedException] if not initialized.
  /// Throws [PlatformOperationException] if platform error occurs.
  Future<Map<String, bool>> getZoneStates() async {
    if (!_isInitialized) throw PolyfenceNotInitializedException();

    try {
      return await _platform.getZoneStates();
    } on PlatformException catch (e, stackTrace) {
      throw PlatformOperationException(
        'getZoneStates',
        e.message ?? 'Unknown error',
        details: {'code': e.code, 'details': e.details},
        innerException: e,
        stackTrace: stackTrace,
      );
    }
  }

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
      _tryRecordAnalyticsError('permission_denied');
      throw PlatformOperationException(
          'startTracking', 'Location permissions not granted');
    }

    // Start tracking on native platform
    try {
      await _platform.startTracking();
    } on PlatformException catch (e, stackTrace) {
      _tryRecordAnalyticsError('tracking_start_failed');
      throw PlatformOperationException(
        'startTracking',
        e.message ?? 'Unknown error',
        details: {'code': e.code, 'details': e.details},
        innerException: e,
        stackTrace: stackTrace,
      );
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
    } on PlatformException catch (e, stackTrace) {
      throw PlatformOperationException(
        'stopTracking',
        e.message ?? 'Unknown error',
        details: {'code': e.code, 'details': e.details},
        innerException: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Handle geofence events from dedicated geofence channel
  void _handleGeofenceEvent(Map<String, dynamic> eventData) {
    try {
      final zoneId = eventData['zoneId'] as String?;
      final eventTypeRaw = (eventData['eventType'] as String?)?.toUpperCase();
      final detectionTimeMs =
          (eventData['detectionTimeMs'] as num?)?.toDouble() ?? 0.0;
      final gpsAccuracy = (eventData['gpsAccuracy'] as num?)?.toDouble() ?? 0.0;

      // Validate required fields
      if (zoneId == null || eventTypeRaw == null) {
        _errorController.add(PolyfenceError(
          type: PolyfenceErrorType.unknown,
          message: 'Missing required fields in geofence event',
          context: {'rawEvent': eventData},
          timestamp: DateTime.now(),
        ));
        return;
      }

      // Explicit eventType mapping with validation
      final GeofenceEventType? geofenceEventType = switch (eventTypeRaw) {
        'ENTER' => GeofenceEventType.enter,
        'EXIT' => GeofenceEventType.exit,
        'DWELL' => GeofenceEventType.dwell,
        'RECOVERY_ENTER' => GeofenceEventType.recoveryEnter,
        'RECOVERY_EXIT' => GeofenceEventType.recoveryExit,
        _ => null,
      };

      if (geofenceEventType == null) {
        _errorController.add(PolyfenceError(
          type: PolyfenceErrorType.unknown,
          message: 'Unknown geofence eventType: $eventTypeRaw',
          context: {'zoneId': zoneId, 'eventType': eventTypeRaw},
          timestamp: DateTime.now(),
        ));
        return;
      }

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
        // Don't throw in stream callback - emit error and use fallback
        _errorController.add(PolyfenceError(
          type: PolyfenceErrorType.unknown,
          message: 'Invalid timestamp type: ${timestampRaw.runtimeType}',
          context: {
            'zoneId': zoneId,
            'expected': 'int or double',
            'received': timestampRaw.runtimeType.toString(),
          },
          timestamp: DateTime.now(),
        ));
        timestamp = DateTime.now().millisecondsSinceEpoch;
      }

      // Get zone from cache
      final zone = _zones[zoneId];

      // Record analytics for detection (fire-and-forget)
      if (zone != null && _analyticsAvailable) {
        try {
          final speedMps =
              (eventData['speedMps'] as num?)?.toDouble();
          final distanceToBoundaryM =
              (eventData['distanceToBoundaryM'] as num?)?.toDouble();

          PolyfenceAnalytics.instance.recordDetection(
            detectionTimeMs: detectionTimeMs,
            gpsAccuracy: gpsAccuracy,
            zoneType: zone.type.name.toLowerCase(), // 'circle' or 'polygon'
            speedMps: speedMps,
            boundaryDistanceM: distanceToBoundaryM,
          );
        } catch (_) {
          // Analytics must never crash geofence event handling
        }
      }

      // Extract optional coordinates if provided by platform
      final lat = (eventData['latitude'] as num?)?.toDouble();
      final lng = (eventData['longitude'] as num?)?.toDouble();
      final acc = (eventData['accuracy'] as num?)?.toDouble();

      // Warn if coordinates are missing (0.0/0.0 is Null Island - unlikely to be intentional)
      if (lat == null || lng == null) {
        _errorController.add(PolyfenceError(
          type: PolyfenceErrorType.unknown,
          message:
              'Missing GPS coordinates in geofence event - using 0.0 fallback',
          context: {
            'zoneId': zoneId,
            'eventType': eventTypeRaw,
            'hasLatitude': lat != null,
            'hasLongitude': lng != null,
          },
          timestamp: DateTime.now(),
        ));
      }

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
    } catch (e, stackTrace) {
      // Catch any unexpected errors to prevent stream callback crashes
      _errorController.add(PolyfenceError(
        type: PolyfenceErrorType.unknown,
        message: 'Failed to parse geofence event: $e',
        context: {
          'rawEvent': eventData,
          'error': e.toString(),
          // Only include stack traces in debug builds to avoid leaking
          // internal file paths and implementation details in production.
          if (kDebugMode) 'stackTrace': stackTrace.toString(),
        },
        timestamp: DateTime.now(),
      ));
    }
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

      // Still record in analytics for plugin owner metrics (fire-and-forget)
      _tryRecordAnalyticsError(error.type.toString().split('.').last);
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

  /// Gets the current GPS configuration from the native platform.
  ///
  /// Queries the native platform for the active configuration, parses it
  /// into a [PolyfenceConfiguration], and caches it locally. Use
  /// [currentConfiguration] to read the cached value without a platform call.
  ///
  /// **Example:**
  /// ```dart
  /// final config = await Polyfence.instance.getConfiguration();
  /// print('Accuracy profile: ${config.accuracyProfile}');
  /// print('GPS threshold: ${config.gpsAccuracyThreshold}m');
  /// ```
  ///
  /// Throws [PolyfenceNotInitializedException] if not initialized.
  /// Throws [PlatformOperationException] if platform error occurs.
  Future<PolyfenceConfiguration> getConfiguration() async {
    if (!_isInitialized) throw PolyfenceNotInitializedException();

    try {
      final result = await _platform.getConfiguration();
      _currentConfiguration = PolyfenceConfiguration.fromMap(result);
      return _currentConfiguration;
    } on PlatformException catch (e, stackTrace) {
      throw PlatformOperationException(
        'getConfiguration',
        e.message ?? 'Unknown error',
        details: {'code': e.code, 'details': e.details},
        innerException: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Updates GPS configuration.
  ///
  /// Serializes the [PolyfenceConfiguration] and sends it to the native
  /// platform. Configuration changes take effect immediately. The provided
  /// configuration is also cached locally (see [currentConfiguration]).
  ///
  /// **Example:**
  /// ```dart
  /// await Polyfence.instance.updateConfiguration(
  ///   PolyfenceConfiguration(
  ///     accuracyProfile: PolyfenceAccuracyProfile.balanced,
  ///     updateStrategy: PolyfenceUpdateStrategy.proximityBased,
  ///     gpsAccuracyThreshold: 50.0,
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
  Future<void> updateConfiguration(PolyfenceConfiguration config) async {
    if (!_isInitialized) throw PolyfenceNotInitializedException();

    try {
      final configMap = config.toMap();
      await _platform.updateConfiguration(configMap);

      // Update local configuration cache
      _currentConfiguration = config;
    } on PlatformException catch (e, stackTrace) {
      throw PlatformOperationException(
        'updateConfiguration',
        e.message ?? 'Unknown error',
        details: {'code': e.code, 'details': e.details},
        innerException: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Resets GPS configuration to platform defaults.
  ///
  /// Tells the native platform to restore its factory defaults for GPS
  /// intervals, accuracy thresholds, and optimization settings. Also resets
  /// the local configuration cache.
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

      // Reset local cache to Dart defaults
      _currentConfiguration = PolyfenceConfiguration();
    } on PlatformException catch (e, stackTrace) {
      throw PlatformOperationException(
        'resetConfiguration',
        e.message ?? 'Unknown error',
        details: {'code': e.code, 'details': e.details},
        innerException: e,
        stackTrace: stackTrace,
      );
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
    } on PlatformException catch (e, stackTrace) {
      throw PlatformOperationException(
        'requestPermissions',
        e.message ?? 'Unknown error',
        details: {'code': e.code, 'details': e.details, 'always': always},
        innerException: e,
        stackTrace: stackTrace,
      );
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
    } on PlatformException catch (e, stackTrace) {
      throw PlatformOperationException(
        'isLocationServiceEnabled',
        e.message ?? 'Unknown error',
        details: {'code': e.code, 'details': e.details},
        innerException: e,
        stackTrace: stackTrace,
      );
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
    } on PlatformException catch (e, stackTrace) {
      throw PlatformOperationException(
        'batteryOptimizationStatus',
        e.message ?? 'Unknown error',
        details: {'code': e.code, 'details': e.details},
        innerException: e,
        stackTrace: stackTrace,
      );
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
    } on PlatformException catch (e, stackTrace) {
      throw PlatformOperationException(
        'requestBatteryOptimizationExemption',
        e.message ?? 'Unknown error',
        details: {'code': e.code, 'details': e.details},
        innerException: e,
        stackTrace: stackTrace,
      );
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
    } on PlatformException catch (e, stackTrace) {
      throw PlatformOperationException(
        'debugInfo',
        e.message ?? 'Unknown error',
        details: {'code': e.code, 'details': e.details},
        innerException: e,
        stackTrace: stackTrace,
      );
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
    return _platform.performanceStream
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
  /// // Get only GPS timeout errors from last 24 hours
  /// final gpsErrors = await Polyfence.instance.errorHistory(
  ///   timeRange: Duration(hours: 24),
  ///   errorTypes: [PolyfenceErrorType.gpsTimeout],
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
    } on PlatformException catch (e, stackTrace) {
      throw PlatformOperationException(
        'errorHistory',
        e.message ?? 'Unknown error',
        details: {'code': e.code, 'details': e.details},
        innerException: e,
        stackTrace: stackTrace,
      );
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
    await updateConfiguration(config);
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
    await updateConfiguration(config);
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
    final config = PolyfenceConfiguration(
      accuracyProfile: PolyfenceAccuracyProfile.adaptive,
      updateStrategy: PolyfenceUpdateStrategy.intelligent,
      proximitySettings: ProximitySettings(),
      movementSettings: MovementSettings(),
      batterySettings: BatterySettings(),
    );
    await updateConfiguration(config);
  }

  /// Gets the current GPS configuration (cached).
  ///
  /// Returns the last known [PolyfenceConfiguration] without querying the platform.
  /// For the latest configuration from the platform, use [getConfiguration].
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
      await _locationSubscription?.cancel();
      await _geofenceSubscription?.cancel();
      await _errorSubscription?.cancel();
      await _performanceSubscription?.cancel();

      // 3. Close all stream controllers
      await _runtimeStatusController.close();
      await _eventController.close();
      await _locationController.close();
      await _errorController.close();
      await _statusController.close();

      // 4. Cleanup analytics session (only if analytics initialized)
      if (_analyticsAvailable) {
        try {
          await PolyfenceAnalytics.instance.endSession();
        } catch (_) {
          // Analytics cleanup is best-effort
        }
      }

      // 5. Dispose app lifecycle manager (independent of analytics)
      if (_lifecycleManagerAvailable) {
        try {
          AppLifecycleManager.instance.dispose();
        } catch (_) {
          // Lifecycle cleanup is best-effort
        }
      }

      // 6. Clear zone cache
      _zones.clear();

      // 7. Reset initialization, analytics, and lifecycle flags
      _isInitialized = false;
      _analyticsAvailable = false;
      _lifecycleManagerAvailable = false;

      // 8. Notify platform of disposal
      try {
        await _platform.dispose();
      } catch (_) {
        // Platform disposal is best-effort
      }
    } catch (e) {
      // Log disposal error but don't throw (disposal should never fail)
      if (kDebugMode) {
        debugPrint('Polyfence: Error during disposal: $e');
      }
    }
  }

  /// Record an analytics error if analytics is available.
  /// Fire-and-forget — analytics must never interfere with core operations.
  void _tryRecordAnalyticsError(String errorType) {
    if (!_analyticsAvailable) return;
    try {
      PolyfenceAnalytics.instance.recordError(errorType);
    } catch (_) {
      // Silently ignore — analytics must never crash core operations
    }
  }

  /// Routes a platform stream error to the developer-facing error stream.
  /// Called from onError callbacks on all platform stream subscriptions.
  void _emitStreamError(
      String streamName, Object error, StackTrace stackTrace) {
    if (_errorController.isClosed) return;

    final message = error is PlatformException
        ? 'Platform stream "$streamName" error: ${error.message}'
        : 'Platform stream "$streamName" error: $error';

    _errorController.add(PolyfenceError(
      type: PolyfenceErrorType.unknown,
      message: message,
      context: {
        'stream': streamName,
        'error': error.toString(),
        // Only include stack traces in debug builds to avoid leaking
        // internal file paths and implementation details in production.
        if (kDebugMode) 'stackTrace': stackTrace.toString(),
        if (error is PlatformException) 'platformCode': error.code,
      },
      timestamp: DateTime.now(),
    ));
  }

  /// Emits a warning when a platform stream closes unexpectedly.
  void _emitStreamDone(String streamName) {
    if (_errorController.isClosed) return;

    _errorController.add(PolyfenceError(
      type: PolyfenceErrorType.unknown,
      message: 'Platform stream "$streamName" closed unexpectedly',
      context: {'stream': streamName},
      timestamp: DateTime.now(),
    ));
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

  /// Show telemetry disclosure intelligently
  /// - Once per install
  /// - Again if telemetry state changes
  /// - Only in debug builds (production logs stay clean)
  Future<void> _showTelemetryDisclosureIfNeeded(bool telemetryEnabled) async {
    // Only show in debug builds
    if (!kDebugMode) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      const String shownKey = 'polyfence_telemetry_disclosure_shown';
      const String stateKey = 'polyfence_telemetry_last_state';

      final bool hasShown = prefs.getBool(shownKey) ?? false;
      final bool? lastState = prefs.getBool(stateKey);

      // Show disclosure if:
      // 1. Never shown before (first install)
      // 2. Telemetry state changed (user toggled it)
      final bool shouldShow =
          !hasShown || (lastState != null && lastState != telemetryEnabled);

      if (shouldShow) {
        _logTelemetryDisclosure(telemetryEnabled);
        await prefs.setBool(shownKey, true);
        await prefs.setBool(stateKey, telemetryEnabled);
      }
    } catch (e) {
      // If SharedPreferences fails, show disclosure anyway (fail-safe)
      _logTelemetryDisclosure(telemetryEnabled);
    }
  }

  /// Log telemetry disclosure message
  void _logTelemetryDisclosure(bool enabled) {
    if (enabled) {
      debugPrint('''
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[Polyfence] Anonymous plugin telemetry enabled.

What's sent:
  • Plugin version, platform (Android/iOS), app package name
  • Performance metrics (detection times, GPS accuracy, battery usage)
  • Error counts, zone type usage (circle/polygon counts)

What's NEVER sent:
  • GPS coordinates or location data
  • Zone definitions or boundaries
  • User identifiers or personal information

See full details: https://polyfence.io/privacy/telemetry

Disable telemetry (one line):
  Polyfence.instance.initialize(
    analyticsConfig: AnalyticsConfig(disableTelemetry: true)
  );
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
''');
    } else {
      debugPrint('''
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[Polyfence] Telemetry disabled.

No analytics data will be sent.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
''');
    }
  }
}
