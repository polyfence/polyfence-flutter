import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:polyfence/polyfence.dart' as polyfence hide GeofenceEvent;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'api_key_store.dart';
import 'theme/app_theme.dart';
import 'models/app_models.dart';
import 'widgets/status_section.dart';
import 'widgets/gps_profile_card.dart';
import 'widgets/zones_card.dart';
import 'widgets/events_card.dart';
import 'widgets/error_banner.dart';
import 'widgets/common/poly_card.dart';
import 'screens/map_screen.dart';
import 'zone_api_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PolyfenceApp());
}

Future<bool> ensureAndroidTrackingPermissions() async {
  if (!Platform.isAndroid) return true;

  // Notifications (API 33+). If the user has permanently denied, the
  // standard `.request()` call returns immediately without showing the
  // system prompt — guide them to the app settings instead so they
  // aren't stuck in a "denied + no path forward" state.
  if (await Permission.notification.isPermanentlyDenied) {
    await openAppSettings();
    return false;
  }
  if (await Permission.notification.isDenied) {
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

  // Activity recognition (API 29+) — powers the SmartGPS intelligent
  // strategy. Optional: the example keeps working if the user declines.
  await Permission.activityRecognition.request();

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

class _HomeScreenState extends State<HomeScreen> {
  // Event log (entry/exit/dwell events from the plugin)
  final List<Map<String, dynamic>> _events = [];

  bool _isTracking = false;
  String _locationStatus = 'Waiting for GPS...';
  bool _isLoadingZones = false;
  List<polyfence.Zone> _loadedZones = [];

  // GPS telemetry surfaced in StatusSection
  double? _gpsAccuracy;
  double _currentSpeed = 0.0;
  String _currentActivity = 'unknown';
  polyfence.PolyfenceAccuracyProfile _currentProfile =
      polyfence.PolyfenceAccuracyProfile.balanced;

  // Error tracking
  final List<GeofenceEvent> _errors = [];
  bool _errorsVisible = true;

  // Tab navigation: 0 = Dashboard, 1 = Map
  int _currentTab = 0;

  // API key state — null until we've read from ApiKeyStore.
  // `_apiKeyLoaded` distinguishes "still loading" from "loaded, no key
  // configured" so we don't flash the empty-state gate during startup.
  String? _apiKey;
  bool _apiKeyLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadStoredEvents();
    _bootstrap();
  }

  /// Order of operations on cold start:
  ///   1. Read the API key from [ApiKeyStore] (build-time dart-define).
  ///      Flipping `_apiKeyLoaded` synchronously means the Dashboard
  ///      renders the empty-state CTA immediately when no key was
  ///      supplied, instead of showing a blank scroll view during init.
  ///   2. Initialise the plugin (no key required — only zone fetch is
  ///      gated).
  ///   3. If a key is present, fetch zones.
  Future<void> _bootstrap() async {
    _loadApiKey();
    await _initializePolyfence();
    if (_apiKey != null && _apiKey!.isNotEmpty) {
      await _loadZonesFromAPI();
    }
  }

  /// Snapshot the resolved API key into state.
  void _loadApiKey() {
    setState(() {
      _apiKey = ApiKeyStore.get();
      _apiKeyLoaded = true;
    });
  }

  Future<void> _initializePolyfence() async {
    try {
      // Plugin error stream — subscribe FIRST. onError is the SDK's
      // central error channel; initialize(), addZone(),
      // requestPermissions(), and requestBatteryOptimizationExemption()
      // all emit errors here as a side effect rather than rejecting
      // their own Future. If we subscribed after initialize() (the
      // pre-fix ordering) any early-init error would be silently
      // dropped. BUG-011 parity with polyfence-react-native#73.
      polyfence.Polyfence.instance.onError.listen((error) {
        if (!mounted) return;
        _addErrorEvent(error.message);
      });

      // Check permissions first (Android only)
      if (Platform.isAndroid) {
        final hasPermissions = await ensureAndroidTrackingPermissions();
        if (!hasPermissions) {
          _addErrorEvent('Location permissions required for tracking');
          return;
        }
      }

      // Initialise the plugin. Anonymous SDK telemetry is opt-out by
      // default — see https://github.com/polyfence/polyfence-flutter for
      // disabling via AnalyticsConfig.
      await polyfence.Polyfence.instance.initialize();

      // SmartGPS — intelligent strategy with proximity, movement, and
      // battery awareness. Dramatically reduces battery drain when
      // stationary.
      final current = await polyfence.Polyfence.instance.getConfiguration();
      await polyfence.Polyfence.instance.updateConfiguration(
        current.copyWith(
          updateStrategy: polyfence.PolyfenceUpdateStrategy.intelligent,
          proximitySettings: polyfence.ProximitySettings(),
          movementSettings: polyfence.MovementSettings(),
          batterySettings: polyfence.BatterySettings(),
          activitySettings: polyfence.ActivitySettings(
            enabled: true,
            confidenceThreshold: 75,
            debounceSeconds: 10,
          ),
          clusterSettings: polyfence.ClusterSettings(
            enabled: true,
            activeRadiusMeters: 5000,
          ),
        ),
      );

      // Geofence events: entry/exit/dwell. We deliberately do NOT pre-resolve
      // the zone name here — if a zone-entry event fires before the zone
      // fetch completes (cold-start race), the lookup would fall back to
      // the zoneId and get baked into persistent storage. Instead we store
      // the zoneId only and resolve the name at render time, so names
      // surface as soon as the zone fetch lands.
      polyfence.Polyfence.instance.onGeofenceEvent.listen((event) {
        _addEvent({
          'timestamp': DateTime.now().toIso8601String(),
          'type': event.type.name.toUpperCase(),
          'zoneId': event.zoneId,
        });
      });

      // Location stream
      polyfence.Polyfence.instance.onLocationUpdate.listen((location) {
        if (!mounted) return;
        setState(() {
          _locationStatus =
              '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}';
          _gpsAccuracy = location.accuracy;
          _currentSpeed = location.speed ?? 0.0;
          _currentActivity = location.activity ?? 'unknown';
        });
      });

      // onError is already wired at the top of init — see the BUG-011
      // comment there for the reasoning.
    } catch (e) {
      _addErrorEvent('Failed to initialize Polyfence: $e');
    }
  }

  Future<void> _loadZonesFromAPI() async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      // Silent no-op when the user hasn't configured a key yet — the
      // empty-state gate in the Dashboard already surfaces this.
      return;
    }
    setState(() => _isLoadingZones = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      // Persistent record of zones we've registered with the plugin —
      // survives app kill / crash / restart. Treated as the truth source
      // for "what's currently registered" so we can compute a delta.
      final storedZoneIdsJson = prefs.getString('registered_zone_ids') ?? '[]';
      final previousZoneIds = (jsonDecode(storedZoneIdsJson) as List<dynamic>)
          .cast<String>()
          .toSet();

      final zones = await ZoneApiService.fetchActiveZones();
      if (!mounted) return;
      final currentZoneIds = zones.map((z) => z.id).toSet();

      // Delta: remove what's no longer in the API
      final zonesToRemove = previousZoneIds.difference(currentZoneIds);

      for (final zoneId in zonesToRemove) {
        try {
          await polyfence.Polyfence.instance.removeZone(zoneId);
        } catch (e) {
          _addErrorEvent('Failed to remove zone $zoneId: $e');
        }
      }

      // Re-add every current zone — the plugin overwrites its own zone
      // map on `addZone`, so this self-heals if local state drifts from
      // plugin state without producing duplicate-id failures.
      for (final zone in zones) {
        try {
          await polyfence.Polyfence.instance.addZone(zone);
        } catch (e) {
          _addErrorEvent('Failed to add zone ${zone.id}: $e');
        }
      }

      await prefs.setString(
        'registered_zone_ids',
        jsonEncode(currentZoneIds.toList()),
      );

      setState(() {
        _loadedZones = zones;
        _isLoadingZones = false;
      });
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
      if (eventsJson == null) return;

      final List<dynamic> eventsList = jsonDecode(eventsJson);
      final List<Map<String, dynamic>> events =
          eventsList.cast<Map<String, dynamic>>();

      // Migrate legacy events (time-only) to full ISO8601 timestamps so
      // EventsCard's date-grouping logic doesn't fall over on entries
      // written before the timestamp format change.
      bool needsMigration = false;
      final now = DateTime.now();
      int eventIndex = 0;

      for (var event in events) {
        final timestamp = event['timestamp'] as String? ?? '';
        if (!timestamp.contains('T') &&
            !timestamp.contains('-') &&
            timestamp.contains(':')) {
          needsMigration = true;
          final daysAgo = (eventIndex * 5) ~/ events.length;
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

      if (needsMigration) {
        _saveEvents();
      }
    } catch (_) {
      // Persisted events are best-effort — a corrupt blob shouldn't
      // block the rest of the app from loading.
    }
  }

  Future<void> _saveEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('events', jsonEncode(_events));
    } catch (_) {
      // Best-effort persistence; ignore write failures.
    }
  }

  void _addEvent(Map<String, dynamic> event) {
    setState(() {
      _events.insert(0, event);
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
    } catch (_) {
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
      setState(() => _isTracking = true);
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
      setState(() => _currentProfile = profile);
    } catch (e) {
      _addErrorEvent('Failed to set accuracy profile: $e');
    }
  }

  void _clearEvents() {
    setState(() => _events.clear());
    _saveEvents();
  }

  void _dismissError(String id) {
    setState(() {
      _errors.removeWhere((e) => e.id == id);
    });
  }

  // Convert Polyfence enums to local model enums
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

  // Convert Polyfence Zone to local Zone model (carries distance info)
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
        } catch (_) {
          // Distance is best-effort; leave it null on failure.
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

  List<GeofenceEvent> _convertEvents() {
    return _events.map((event) {
      DateTime timestamp;
      try {
        final timeStr = event['timestamp'] as String? ?? '';
        if (timeStr.contains('T') || timeStr.contains('-')) {
          timestamp = DateTime.parse(timeStr);
        } else {
          // Legacy time-only format — assume today
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
      } catch (_) {
        timestamp = DateTime.now();
      }

      EventType eventType;
      switch (event['type']) {
        case 'ENTER':
          eventType = EventType.enter;
          break;
        case 'DWELL':
          eventType = EventType.dwell;
          break;
        default:
          eventType = EventType.exit;
          break;
      }

      // Resolve zone name fresh against the current zone list so events
      // that fired before zones loaded (or pre-rename) display the right
      // name as soon as the data catches up. Falls back to:
      //   1. Any previously-stored 'zone' field (legacy events written
      //      under the old pre-resolve scheme)
      //   2. The zoneId itself (zone deleted upstream or never loaded)
      final zoneId = event['zoneId'] as String? ?? 'unknown';
      final resolved = _getZoneName(zoneId);
      final zoneName = resolved != zoneId
          ? resolved
          : (event['zone'] as String? ?? zoneId);

      return GeofenceEvent(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp: timestamp,
        type: eventType,
        zoneName: zoneName,
        zoneId: zoneId,
      );
    }).toList();
  }

  TrackingStatus _getTrackingStatus() {
    if (_isTracking) return TrackingStatus.active;
    return TrackingStatus.inactive;
  }

  LatLng? _getCurrentLocation() {
    try {
      final parts = _locationStatus.split(',');
      if (parts.length == 2) {
        final lat = double.parse(parts[0].trim());
        final lng = double.parse(parts[1].trim());
        return LatLng(lat, lng);
      }
    } catch (_) {
      // Fall through to null
    }
    return null;
  }

  /// Dashboard contents — either the empty-state CTA (no API key
  /// configured) or the full card stack (key present). The error banner
  /// renders above either, gated by visibility.
  Widget _buildDashboardTab() {
    final hasKey = _apiKey != null && _apiKey!.isNotEmpty;

    return Column(
      children: [
        if (_errorsVisible && _errors.isNotEmpty)
          ErrorBanner(
            errors: _errors,
            onDismiss: _dismissError,
            onClearAll: () => setState(() {
              _errors.clear();
              _errorsVisible = false;
            }),
            onClose: () => setState(() => _errorsVisible = false),
          ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(
              left: AppTheme.spacingLg,
              right: AppTheme.spacingLg,
              top: AppTheme.spacingLg,
              bottom: AppTheme.spacingXl3,
            ),
            child: _apiKeyLoaded && !hasKey
                ? const ApiKeyEmptyState()
                : Column(
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
    );
  }

  Widget _buildMapTab() {
    return MapScreen(
      isTracking: _isTracking,
      location: _getCurrentLocation(),
      accuracy: _gpsAccuracy,
      zoneCount: _loadedZones.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.card,
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
          child: Container(height: 1, color: AppTheme.border),
        ),
        actions: [
          // Notification bell — tap always toggles the error banner;
          // the red badge appears only when there are errors to surface.
          IconButton(
            icon: Badge(
              label: Text(
                _errors.length > 99 ? '99+' : '${_errors.length}',
              ),
              isLabelVisible: _errors.isNotEmpty,
              backgroundColor: AppTheme.destructive,
              textColor: AppTheme.destructiveForeground,
              child: const Icon(
                LucideIcons.bell,
                color: AppTheme.mutedForeground,
              ),
            ),
            tooltip: _errors.isEmpty
                ? 'No errors'
                : '${_errors.length} error${_errors.length != 1 ? "s" : ""}',
            onPressed: () =>
                setState(() => _errorsVisible = !_errorsVisible),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentTab,
        children: [
          _buildDashboardTab(),
          _buildMapTab(),
        ],
      ),
      floatingActionButton: _buildTrackingFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildTrackingFab() {
    return GestureDetector(
      onTap: _toggleTracking,
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          color: _isTracking ? AppTheme.destructive : AppTheme.primary,
          shape: BoxShape.circle,
          boxShadow: AppTheme.fabShadow,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _TrackingDot(isTracking: _isTracking),
            const SizedBox(height: 6),
            Text(
              _isTracking ? 'Stop' : 'Start',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.card,
        border: Border(
          top: BorderSide(color: AppTheme.border),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              Expanded(
                child: _NavBarItem(
                  icon: LucideIcons.layoutDashboard,
                  label: 'Dashboard',
                  isActive: _currentTab == 0,
                  onTap: () => setState(() => _currentTab = 0),
                ),
              ),
              // Spacer for the centerDocked FAB
              const SizedBox(width: 96),
              Expanded(
                child: _NavBarItem(
                  icon: LucideIcons.map,
                  label: 'Map',
                  isActive: _currentTab == 1,
                  onTap: () => setState(() => _currentTab = 1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dashboard CTA shown when no Polyfence API key was supplied at build
/// time. Pure documentation — surfaces the dart-define command the
/// developer needs to rerun with. There is no in-app paste flow by
/// design (this example is run from an IDE/shell; the key belongs in
/// the build invocation, not in app state).
///
/// Public so widget tests can mount it directly without bootstrapping
/// the full app (which would require a MethodChannel for the Polyfence
/// plugin's `initialize` call).
class ApiKeyEmptyState extends StatelessWidget {
  const ApiKeyEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return PolyCard(
      padding: const EdgeInsets.all(AppTheme.spacingXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                LucideIcons.key,
                size: 22,
                color: AppTheme.primary,
              ),
              SizedBox(width: AppTheme.spacingSm),
              Text(
                'Connect Polyfence',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingMd),
          const Text(
            'This example needs a Polyfence API key to load your zones. '
            'Sign up for a free key at polyfence.io, then re-run the '
            'app with the key passed as a build-time define:',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: AppTheme.mutedForeground,
            ),
          ),
          const SizedBox(height: AppTheme.spacingMd),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            decoration: BoxDecoration(
              color: AppTheme.secondary,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: SelectableText(
              'flutter run --dart-define=POLYFENCE_API_KEY=pf_...',
              style: AppTheme.brandTextStyle(
                fontSize: 13,
                color: AppTheme.foreground,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 20,
            color: isActive ? AppTheme.primary : AppTheme.mutedForeground,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isActive ? AppTheme.primary : AppTheme.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackingDot extends StatefulWidget {
  final bool isTracking;

  const _TrackingDot({required this.isTracking});

  @override
  State<_TrackingDot> createState() => _TrackingDotState();
}

class _TrackingDotState extends State<_TrackingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _animation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.isTracking) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_TrackingDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isTracking && !oldWidget.isTracking) {
      _controller.repeat(reverse: true);
    } else if (!widget.isTracking && oldWidget.isTracking) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.isTracking
        ? FadeTransition(
            opacity: _animation,
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          )
        : Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          );
  }
}
