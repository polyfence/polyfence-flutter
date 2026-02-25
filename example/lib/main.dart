import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:polyfence/polyfence.dart' as polyfence hide GeofenceEvent;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math' as math;
// Import new design system and components
import 'theme/app_theme.dart';
import 'models/app_models.dart';
import 'widgets/status_section.dart';
import 'widgets/gps_profile_card.dart';
import 'widgets/zones_card.dart';
import 'widgets/events_card.dart';
import 'widgets/tracking_button.dart';
import 'widgets/error_banner.dart';
import 'zone_api_service.dart';
import 'config.dart';
import 'demo_data.dart';
import 'utils/logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LogBuffer.initialize();
  logDebug('App started', level: LogLevel.info);
  runApp(const PolyfenceApp());
}

Future<bool> ensureAndroidTrackingPermissions() async {
  if (!Platform.isAndroid) return true;

  // 33+: notifications
  if (await Permission.notification.isDenied ||
      await Permission.notification.isPermanentlyDenied) {
    final notif = await Permission.notification.request();
    if (!notif.isGranted) return false;
  }

  // Fine location first
  final fine = await Permission.location.request();
  if (!fine.isGranted) return false;

  // Background location (API 29+)
  final always = await Permission.locationAlways.request();
  if (!always.isGranted) {
    // Some OEMs require going to settings; guide user
    await openAppSettings();
    return false;
  }

  // Activity recognition (API 29+) - needed for activity-based GPS optimization
  if (await Permission.activityRecognition.isDenied) {
    final activity = await Permission.activityRecognition.request();
    if (!activity.isGranted) {
      // Activity recognition is optional - continue without it
      logDebug('Activity recognition permission not granted - continuing without it');
    }
  }

  return true;
}

class PolyfenceApp extends StatelessWidget {
  const PolyfenceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Polyfence',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      home: const HomeScreen(),
      builder: (context, child) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            systemNavigationBarColor: Colors.white,
            systemNavigationBarIconBrightness: Brightness.dark,
          ),
          child: child!,
        );
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  // Preserve all existing state variables
  final List<Map<String, dynamic>> _events = [];
  bool _isTracking = false; // Default to OFF until we read saved state
  String _locationStatus = 'Waiting for GPS...';
  bool _isLoadingZones = true;
  List<polyfence.Zone> _loadedZones = [];

  // Simple status tracking
  double? _gpsAccuracy;
  double _currentSpeed = 0.0;
  String _currentActivity = 'unknown';
  polyfence.PolyfenceAccuracyProfile _currentProfile =
      polyfence.PolyfenceAccuracyProfile.balanced;

  // Error tracking
  final List<GeofenceEvent> _errors = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadStoredEvents();
    _initializePolyfence();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    LogBuffer.dispose();
    super.dispose();
  }

  // App lifecycle handling (analytics lifecycle managed by plugin when enabled)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Flush logs to disk on app pause/background
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      LogBuffer.flush();
      logDebug('App lifecycle: ${state.name}', level: LogLevel.info);
    }
  }

  Future<void> _initializePolyfence() async {
    try {
      // Check permissions first (Android only)
      if (Platform.isAndroid) {
        final hasPermissions = await ensureAndroidTrackingPermissions();
        if (!hasPermissions) {
          _addErrorEvent('Location permissions required for tracking');
          return;
        }
      }

      // Initialize Polyfence plugin
      // Anonymous plugin telemetry enabled by default (no location data or PII sent)
      // See what's sent: https://github.com/blackabass/polyfence-plugin/blob/main/doc/TELEMETRY.md
      await polyfence.Polyfence.instance.initialize();

      // Enable SmartGPS: INTELLIGENT strategy with proximity, movement, and battery
      // awareness. This dramatically reduces battery drain when stationary.
      // On iOS, activity settings are excluded to avoid CMMotionActivityManager crash
      // (confirmed in Roadie v0.10.0 upgrade) — all other optimizations are sent.
      {
        final current = await polyfence.Polyfence.instance.getConfiguration();
        final clusterSettings = polyfence.ClusterSettings(
          enabled: true,
          activeRadiusMeters: 5000, // 5km radius - only monitor nearby zones
        );

        if (Platform.isIOS) {
          await polyfence.Polyfence.instance.updateConfiguration(
            current.copyWith(
              updateStrategy: polyfence.PolyfenceUpdateStrategy.intelligent,
              proximitySettings: polyfence.ProximitySettings(),
              movementSettings: polyfence.MovementSettings(),
              batterySettings: polyfence.BatterySettings(),
              clusterSettings: clusterSettings,
            ),
          );
        } else {
          await polyfence.Polyfence.instance.updateConfiguration(
            current.copyWith(
              updateStrategy: polyfence.PolyfenceUpdateStrategy.intelligent,
              proximitySettings: polyfence.ProximitySettings(),
              movementSettings: polyfence.MovementSettings(),
              batterySettings: polyfence.BatterySettings(),
              activitySettings: polyfence.ActivitySettings(
                enabled: true,
                confidenceThreshold: 75,
                debounceSeconds: 10, // Reduced for demo (default is 30)
              ),
              clusterSettings: clusterSettings,
            ),
          );
        }
      }

      // Configuration examples:

      // To disable telemetry (opt-out):
      // await polyfence.Polyfence.instance.initialize(
      //   analyticsConfig: polyfence.AnalyticsConfig(
      //     disableTelemetry: true,
      //   ),
      // );

      // To disable built-in alert notifications (for custom notifications):
      // await polyfence.Polyfence.instance.initialize(
      //   config: {
      //     'disableAlertNotifications': true,
      //   },
      // );

      // Load zones from API (may still be down; no fallback)
      await _loadZonesFromAPI();

      // Listen to geofence events
      polyfence.Polyfence.instance.onGeofenceEvent.listen((event) {
        final timestamp = DateTime.now().toIso8601String(); // Full ISO8601 for date grouping
        final eventType = event.type.name.toUpperCase();
        final zoneName = _getZoneName(event.zoneId);

        // Note: Analytics are automatically recorded by the plugin when geofence events occur
        // No need to manually call recordDetection here

        _addEvent({
          'timestamp': timestamp,
          'type': eventType,
          'zone': zoneName,
          'zoneId': event.zoneId,
        });
      });

      // Listen to location updates
      polyfence.Polyfence.instance.onLocationUpdate.listen((location) {
        if (mounted) {
          setState(() {
            _locationStatus =
                '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}';
            _gpsAccuracy = location.accuracy;
            _currentSpeed = location.speed ??
                0.0; // Already converted to km/h by native code
            _currentActivity = location.activity ?? 'unknown';
          });
        }
      });
    } catch (e) {
      _addErrorEvent('Failed to initialize Polyfence: $e');
    }
  }

  Future<void> _loadZonesFromAPI() async {
    setState(() => _isLoadingZones = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      // Get previously registered zone IDs from persistent storage (truth source)
      // This survives app kills, crashes, and restarts
      final storedZoneIdsJson = prefs.getString('registered_zone_ids') ?? '[]';
      final previousZoneIds = (jsonDecode(storedZoneIdsJson) as List<dynamic>)
          .cast<String>()
          .toSet();

      List<polyfence.Zone> zones;

      // Use demo zones if demo mode is enabled
      if (AppConfig.demoMode) {
        zones = DemoZones.getDemoZones();
      } else {
        // Try to fetch from API
        try {
          zones = await ZoneApiService.fetchActiveZones();
        } catch (e) {
          // Fallback to demo zones if API fails
          zones = DemoZones.getDemoZones();
        }
      }

      if (mounted) {
        final currentZoneIds = zones.map((z) => z.id).toSet();

        // Calculate delta: what to remove, what to add
        final zonesToRemove = previousZoneIds.difference(currentZoneIds);
        final zonesToAdd = currentZoneIds.difference(previousZoneIds);

        // Remove deleted zones (efficient: only removed zones)
        for (final zoneId in zonesToRemove) {
          try {
            await polyfence.Polyfence.instance.removeZone(zoneId);
          } catch (e) {
            _addErrorEvent('Failed to remove zone $zoneId: $e');
          }
        }

        // Add all zones (ensure they're registered with plugin)
        // Note: Plugin handles deduplication internally, so it's safe to add all zones
        for (final zone in zones) {
          try {
            await polyfence.Polyfence.instance.addZone(zone);
          } catch (e) {
            // Only log error if it's actually a new zone (not a duplicate)
            if (zonesToAdd.contains(zone.id)) {
              _addErrorEvent('Failed to add zone ${zone.id}: $e');
            }
            // Silently ignore duplicate zone errors from plugin
          }
        }

        // Update persistent record of registered zones
        await prefs.setString(
          'registered_zone_ids',
          jsonEncode(currentZoneIds.toList()),
        );

        setState(() {
          _loadedZones = zones;
          _isLoadingZones = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingZones = false);
      }
      _addErrorEvent('Failed to load zones: $e');
    }
  }

  Future<void> _loadStoredEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final eventsJson = prefs.getString('events');
      if (eventsJson != null) {
        final List<dynamic> eventsList = jsonDecode(eventsJson);
        final List<Map<String, dynamic>> events = eventsList.cast<Map<String, dynamic>>();

        // Migrate legacy events (time-only) to full ISO8601 timestamps
        bool needsMigration = false;
        final now = DateTime.now();
        int eventIndex = 0;

        for (var event in events) {
          final timestamp = event['timestamp'] as String? ?? '';
          // Check if it's legacy format (no date, just time like "22:57:34")
          if (!timestamp.contains('T') && !timestamp.contains('-') && timestamp.contains(':')) {
            needsMigration = true;
            // Spread events across last 5 days based on position in list
            // Newer events (lower index) get more recent dates
            final daysAgo = (eventIndex * 5) ~/ events.length; // 0-4 days ago
            final eventDate = now.subtract(Duration(days: daysAgo));
            final timeParts = timestamp.split(':');
            if (timeParts.length >= 3) {
              final fullTimestamp = DateTime(
                eventDate.year,
                eventDate.month,
                eventDate.day,
                int.tryParse(timeParts[0]) ?? 0,
                int.tryParse(timeParts[1]) ?? 0,
                int.tryParse(timeParts[2]) ?? 0,
              ).toIso8601String();
              event['timestamp'] = fullTimestamp;
            }
          }
          eventIndex++;
        }

        setState(() {
          _events.clear();
          _events.addAll(events);
        });

        // Save migrated events
        if (needsMigration) {
          _saveEvents();
        }
      }
    } catch (e) {
      // Failed to load stored events
      debugPrint('Failed to load stored events: $e');
    }
  }

  Future<void> _saveEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('events', jsonEncode(_events));
    } catch (e) {
      // Failed to save events - log but don't show error banner
      logDebug('Failed to save events: $e');
    }
  }

  void _addEvent(Map<String, dynamic> event) {
    setState(() {
      _events.insert(0, event);
      // Keep only last 100 events
      if (_events.length > 100) {
        _events.removeRange(100, _events.length);
      }
    });
    _saveEvents();
  }

  void _addErrorEvent(String message) {
    setState(() {
      _errors.add(GeofenceEvent(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp: DateTime.now(),
        type: EventType.error,
        zoneName: 'System',
        zoneId: 'system',
        message: message,
      ));
    });
  }

  String _getZoneName(String zoneId) {
    try {
      final zone = _loadedZones.firstWhere((z) => z.id == zoneId);
      return zone.name;
    } catch (e) {
      // No crash - just return the ID as fallback
      return zoneId;
    }
  }

  Future<void> _refreshZones() async {
    await _loadZonesFromAPI();
  }

  Future<void> _toggleTracking() async {
    if (_isTracking) {
      await _stopTracking();
    } else {
      await _startTracking();
    }
  }

  Future<void> _startTracking() async {
    try {
      await polyfence.Polyfence.instance.startTracking();
      setState(() {
        _isTracking = true;
      });

      // Save state
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isTracking', true);
    } catch (e) {
      _addErrorEvent('Failed to start tracking: $e');
    }
  }

  Future<void> _stopTracking() async {
    try {
      await polyfence.Polyfence.instance.stopTracking();
      setState(() {
        _isTracking = false;
        _currentSpeed = 0.0;
      });

      // Save state
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isTracking', false);
    } catch (e) {
      _addErrorEvent('Failed to stop tracking: $e');
    }
  }

  Future<void> _setAccuracyProfile(
      polyfence.PolyfenceAccuracyProfile profile) async {
    try {
      await polyfence.Polyfence.instance.setAccuracyProfile(profile);
      setState(() {
        _currentProfile = profile;
      });
    } catch (e) {
      _addErrorEvent('Failed to set accuracy profile: $e');
    }
  }

  void _clearEvents() {
    setState(() {
      _events.clear();
    });
    _saveEvents();
  }

  void _dismissError(String id) {
    setState(() {
      _errors.removeWhere((e) => e.id == id);
    });
  }

  // Convert Polyfence enums to new model enums
  GpsProfile _convertToGpsProfile(polyfence.PolyfenceAccuracyProfile profile) {
    switch (profile) {
      case polyfence.PolyfenceAccuracyProfile.maxAccuracy:
        return GpsProfile.max;
      case polyfence.PolyfenceAccuracyProfile.balanced:
        return GpsProfile.balanced;
      case polyfence.PolyfenceAccuracyProfile.batteryOptimal:
        return GpsProfile.battery;
      case polyfence.PolyfenceAccuracyProfile.adaptive:
        return GpsProfile.smart;
    }
  }

  polyfence.PolyfenceAccuracyProfile _convertFromGpsProfile(
      GpsProfile profile) {
    switch (profile) {
      case GpsProfile.max:
        return polyfence.PolyfenceAccuracyProfile.maxAccuracy;
      case GpsProfile.balanced:
        return polyfence.PolyfenceAccuracyProfile.balanced;
      case GpsProfile.battery:
        return polyfence.PolyfenceAccuracyProfile.batteryOptimal;
      case GpsProfile.smart:
        return polyfence.PolyfenceAccuracyProfile.adaptive;
    }
  }

  // Convert Polyfence Zone to new Zone model
  List<Zone> _convertZones(List<polyfence.Zone> polyfenceZones) {
    return polyfenceZones.map((zone) {
      double? distance;
      final currentLocation = _getCurrentLocation();

      if (currentLocation != null) {
        try {
          switch (zone.type) {
            case polyfence.ZoneType.circle:
              if (zone.center != null && zone.radius != null) {
                final center = _toLatLng(zone.center!);
                final centerDistance =
                    _distanceBetweenLatLng(currentLocation, center);
                distance = centerDistance <= zone.radius!
                    ? 0.0
                    : centerDistance - zone.radius!;
              }
              break;
            case polyfence.ZoneType.polygon:
              final polygonPoints =
                  zone.polygon?.map((p) => _toLatLng(p)).toList();

              if (polygonPoints != null && polygonPoints.length >= 3) {
                final inside =
                    _isPointInPolygon(currentLocation, polygonPoints);
                if (inside) {
                  distance = 0.0;
                } else {
                  distance = _distanceToPolygon(currentLocation, polygonPoints);
                }
              } else if (zone.center != null) {
                final center = _toLatLng(zone.center!);
                distance = _distanceBetweenLatLng(currentLocation, center);
              }
              break;
          }
        } catch (e) {
          logDebug('Zone distance calculation failed for ${zone.name}: $e');
        }
      }

      return Zone(
        id: zone.id,
        name: zone.name,
        type: zone.type == polyfence.ZoneType.circle
            ? ZoneType.circle
            : ZoneType.polygon,
        distance: distance,
      );
    }).toList();
  }

  LatLng _toLatLng(polyfence.PolyfenceLocation location) {
    return LatLng(location.latitude, location.longitude);
  }

  double _distanceBetweenLatLng(LatLng a, LatLng b) {
    const double earthRadius = 6371000;
    final lat1 = a.latitude * (math.pi / 180);
    final lat2 = b.latitude * (math.pi / 180);
    final dLat = (b.latitude - a.latitude) * (math.pi / 180);
    final dLon = (b.longitude - a.longitude) * (math.pi / 180);

    final sinLat = math.sin(dLat / 2);
    final sinLon = math.sin(dLon / 2);
    final aCalc =
        sinLat * sinLat + math.cos(lat1) * math.cos(lat2) * sinLon * sinLon;
    final c = 2 * math.atan2(math.sqrt(aCalc), math.sqrt(1 - aCalc));
    return earthRadius * c;
  }

  bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
    bool inside = false;
    for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final xi = polygon[i].longitude;
      final yi = polygon[i].latitude;
      final xj = polygon[j].longitude;
      final yj = polygon[j].latitude;

      final intersect = ((yi > point.latitude) != (yj > point.latitude)) &&
          (point.longitude <
              (xj - xi) *
                      (point.latitude - yi) /
                      (yj - yi == 0 ? 1e-12 : (yj - yi)) +
                  xi);
      if (intersect) inside = !inside;
    }
    return inside;
  }

  double _distanceToPolygon(LatLng point, List<LatLng> polygon) {
    double minDistance = double.infinity;
    for (var i = 0; i < polygon.length; i++) {
      final start = polygon[i];
      final end = polygon[(i + 1) % polygon.length];
      final distance = _distanceFromPointToLineSegment(point, start, end);
      if (distance < minDistance) minDistance = distance;
    }
    return minDistance;
  }

  double _distanceFromPointToLineSegment(
    LatLng point,
    LatLng start,
    LatLng end,
  ) {
    final latDiff = end.latitude - start.latitude;
    final lonDiff = end.longitude - start.longitude;

    if (latDiff == 0 && lonDiff == 0) {
      return _distanceBetweenLatLng(point, start);
    }

    final t = ((point.longitude - start.longitude) * lonDiff +
            (point.latitude - start.latitude) * latDiff) /
        (lonDiff * lonDiff + latDiff * latDiff);

    final clampedT = t.clamp(0.0, 1.0);
    final projection = LatLng(
      start.latitude + clampedT * latDiff,
      start.longitude + clampedT * lonDiff,
    );

    return _distanceBetweenLatLng(point, projection);
  }

  // Convert events to new GeofenceEvent model
  List<GeofenceEvent> _convertEvents() {
    return _events.map((event) {
      DateTime timestamp;
      try {
        final timeStr = event['timestamp'] as String? ?? '';
        // Try parsing as full ISO8601 first (new format)
        if (timeStr.contains('T') || timeStr.contains('-')) {
          timestamp = DateTime.parse(timeStr);
        } else {
          // Legacy format: time-only string like "22:57:34" - assume today
          final now = DateTime.now();
          final timeParts = timeStr.split(':');
          timestamp = DateTime(
            now.year,
            now.month,
            now.day,
            int.parse(timeParts[0]),
            int.parse(timeParts[1]),
            int.parse(timeParts[2]),
          );
        }
      } catch (e) {
        timestamp = DateTime.now();
      }

      return GeofenceEvent(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp: timestamp,
        type: event['type'] == 'ENTER' ? EventType.enter : EventType.exit,
        zoneName: event['zone'] ?? 'Unknown',
        zoneId: event['zoneId'] ?? 'unknown',
      );
    }).toList();
  }

  TrackingStatus _getTrackingStatus() {
    if (_isTracking) return TrackingStatus.active;
    return TrackingStatus.inactive;
  }

  LatLng? _getCurrentLocation() {
    // Fallback to parsed location status
    try {
      final parts = _locationStatus.split(',');
      if (parts.length == 2) {
        final lat = double.parse(parts[0].trim());
        final lng = double.parse(parts[1].trim());
        return LatLng(lat, lng);
      }
    } catch (e) {
      // Fallback to default location
    }
    return null; // Return null when GPS is not available
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.foreground,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Polyfence',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppTheme.foreground,
              ),
            ),
            Text(
              'Flutter Example App',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.mutedForeground,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: AppTheme.border,
          ),
        ),
        actions: [
          Builder(
            builder: (btnContext) => IconButton(
              icon: Badge(
                label: Text('${LogBuffer.length}'),
                isLabelVisible: LogBuffer.length > 0,
                child: const Icon(Icons.share, color: AppTheme.foreground),
              ),
              tooltip: 'Export Logs (${LogBuffer.length})',
              onPressed: () async {
                if (LogBuffer.length == 0) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No logs to export')),
                    );
                  }
                  return;
                }
                try {
                  final box = btnContext.findRenderObject() as RenderBox?;
                  final origin = box != null
                      ? box.localToGlobal(Offset.zero) & box.size
                      : null;
                  await LogBuffer.exportLogs(shareOrigin: origin);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Export failed: $e')),
                    );
                  }
                }
              },
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main scrollable content
          Column(
            children: [
              // Error Banner
              if (_errors.isNotEmpty)
                ErrorBanner(
                  errors: _errors,
                  onDismiss: _dismissError,
                ),

              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(
                    left: AppTheme.spacingLg,
                    right: AppTheme.spacingLg,
                    top: AppTheme.spacingLg,
                    bottom: 220,
                  ),
                  child: Column(
                    children: [
                      StatusSection(
                        isTracking: _isTracking,
                        location: _getCurrentLocation(),
                        accuracy: _gpsAccuracy,
                        speed: _currentSpeed,
                        activity: _currentActivity,
                        gpsProfile: _convertToGpsProfile(_currentProfile),
                        locationStatus: _locationStatus,
                      ),
                      const SizedBox(height: AppTheme.spacingLg),
                      GpsProfileCard(
                        currentProfile: _convertToGpsProfile(_currentProfile),
                        onProfileChange: (profile) => _setAccuracyProfile(
                            _convertFromGpsProfile(profile)),
                      ),
                      const SizedBox(height: AppTheme.spacingLg),
                      ZonesCard(
                        zones: _convertZones(_loadedZones),
                        isLoading: _isLoadingZones,
                        onRefresh: _refreshZones,
                      ),
                      const SizedBox(height: AppTheme.spacingLg),
                      EventsCard(
                        events: _convertEvents(),
                        onClear: _clearEvents,
                        trackingStatus: _getTrackingStatus(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Fixed tracking button at bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: TrackingButton(
              isTracking: _isTracking,
              onPressed: _toggleTracking,
            ),
          ),
        ],
      ),
    );
  }
}
