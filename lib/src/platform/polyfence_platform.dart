import 'dart:async';
import 'package:flutter/services.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import '../models/zone.dart';
import '../models/location.dart';
import '../configuration/polyfence_configuration.dart';

abstract class PolyfencePlatform extends PlatformInterface {
  PolyfencePlatform() : super(token: _token);

  static final Object _token = Object();
  static PolyfencePlatform _instance = MethodChannelPolyfence();
  static PolyfencePlatform get instance => _instance;

  static set instance(PolyfencePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Stream<PolyfenceLocation> get onLocationUpdate;
  Stream<Map<String, dynamic>> get onError;
  Stream<Map<String, dynamic>> get onGeofenceEvent;

  /// Initializes the Polyfence plugin.
  ///
  /// The [config] parameter accepts a [PolyfenceConfiguration] object for typed
  /// configuration. This is internally converted to a Map for native platform
  /// communication.
  Future<void> initialize({String? licenseKey, PolyfenceConfiguration? config});
  Future<void> addZone(Zone zone);
  Future<void> removeZone(String zoneId);
  Future<void> clearAllZones();

  /// The zone as it was passed to [addZone], or `null` when no zone is stored
  /// under that id. See `PolyfenceService.getZone`.
  ///
  /// Carries a default rather than being abstract. This is a
  /// [PlatformInterface], so anything outside this package can implement it,
  /// and a new abstract member would stop every existing implementation
  /// compiling. A default that throws keeps adding a method to a minor
  /// release, and an implementation that has not caught up fails loudly at the
  /// call rather than silently answering null.
  Future<Zone?> getZone(String zoneId) {
    throw UnimplementedError('getZone() has not been implemented.');
  }
  Future<void> startTracking();
  Future<void> stopTracking();
  Future<bool> requestPermissions({bool always = false});
  Future<void> dispose();

  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled();

  /// Check battery optimization status (Android only)
  Future<Map<String, dynamic>> checkBatteryOptimization();

  /// Launch the Android system battery-optimization-exemption dialog
  /// (fire-and-forget — the user's response cannot be observed
  /// synchronously). Re-poll [checkBatteryOptimization] after your app
  /// resumes to detect the outcome.
  Future<void> requestBatteryOptimizationExemption();

  /// Returns the current GPS configuration as a raw map from the platform.
  Future<Map<String, dynamic>> getConfiguration();

  /// Sends a configuration map to the native platform.
  Future<void> updateConfiguration(Map<String, dynamic> config);

  /// Resets native GPS configuration to platform defaults.
  Future<void> resetConfiguration();

  /// Sets the GPS accuracy profile by name on the native platform.
  Future<void> setAccuracyProfile(String profile);

  // Debug API methods
  Future<Map<String, dynamic>> getDebugInfo();
  Stream<Map<String, dynamic>> get performanceStream;
  Future<List<Map<String, dynamic>>> getErrorHistory(
      Map<String, dynamic> params);

  /// Returns accumulated session telemetry from native engines.
  ///
  /// Includes activity distribution, GPS interval distribution, zone metrics,
  /// device category, and other ML training context collected during the session.
  Future<Map<String, dynamic>> getSessionTelemetry();

  /// Returns the current persisted zone states from the native engine.
  ///
  /// The returned map uses:
  /// - keys: zone IDs
  /// - values: `true` if the engine's persisted state says the device is
  ///   currently INSIDE the zone, `false` if it says OUTSIDE.
  ///
  /// This reflects the same internal `GeofenceEngine` state that powers
  /// `reconcileZoneStates` and `RECOVERY_ENTER`/`RECOVERY_EXIT` events. It is
  /// **not** a fresh GPS point-in-polygon calculation, and only zones currently
  /// tracked by the engine are included.
  Future<Map<String, bool>> getZoneStates();

  /// Drain every geofence event the native engine persisted while the bridge
  /// was not attached. Returns raw event maps in oldest-first order and removes
  /// them from disk in the same serialised block. Returns an empty list when
  /// no events are queued or the queue is disabled
  /// (`pendingEventsQueueSize == 0`).
  Future<List<Map<String, dynamic>>> drainPendingEvents() async {
    throw UnimplementedError('drainPendingEvents() has not been implemented.');
  }

  /// Cumulative count of events the native durable queue has evicted since
  /// first construction of a store on this device (oldest-first eviction fires
  /// when the queue cap is reached). Persists across process restarts. Returns
  /// `0` when the queue has never evicted and when it is disabled.
  Future<int> pendingEventsDroppedCount() async {
    throw UnimplementedError(
        'pendingEventsDroppedCount() has not been implemented.');
  }

  /// Tell the native engine whether a consumer's geofence-event listener is
  /// live. Distinct from the plugin's own platform-channel subscription, which
  /// is attached during `initialize()` and therefore says nothing about a
  /// subscriber existing. The native side replays the durable queue on the
  /// false→true edge.
  ///
  /// Advisory, and fired on every subscribe / unsubscribe rather than by
  /// consumer request — so the default is a no-op rather than the
  /// `UnimplementedError` the request-driven methods above throw. An
  /// implementation that ignores it leaves the queue pull-only, which is the
  /// same behaviour as opting out.
  Future<void> setEventListenerActive(bool active) async {}
}

class MethodChannelPolyfence extends PolyfencePlatform {
  static const MethodChannel _channel = MethodChannel('polyfence');
  static const EventChannel _locationChannel =
      EventChannel('polyfence/location');
  static const EventChannel _geofenceChannel =
      EventChannel('polyfence/geofence');
  static const EventChannel _errorChannel = EventChannel('polyfence/error');
  static const EventChannel _performanceChannel =
      EventChannel('polyfence/performance');

  Stream<PolyfenceLocation>? _locationStream;
  Stream<Map<String, dynamic>>? _geofenceStream;
  Stream<Map<String, dynamic>>? _errorStream;
  Stream<Map<String, dynamic>>? _performanceStream;

  @override
  Stream<PolyfenceLocation> get onLocationUpdate {
    // Use lazy initialization: create stream only once
    // In Dart's single-threaded model, ??= is atomic and safe
    return _locationStream ??= _locationChannel
        .receiveBroadcastStream('location')
        .map((data) =>
            PolyfenceLocation.fromJson(Map<String, dynamic>.from(data)));
  }

  // Separate geofence event stream
  @override
  Stream<Map<String, dynamic>> get onGeofenceEvent {
    // Use lazy initialization: create stream only once
    return _geofenceStream ??= _geofenceChannel
        .receiveBroadcastStream('geofence')
        .map((data) => Map<String, dynamic>.from(data));
  }

  @override
  Stream<Map<String, dynamic>> get onError {
    // Use lazy initialization: create stream only once
    return _errorStream ??= _errorChannel
        .receiveBroadcastStream('error')
        .map((data) => Map<String, dynamic>.from(data));
  }

  @override
  Stream<Map<String, dynamic>> get performanceStream {
    // Use lazy initialization: create stream only once
    return _performanceStream ??= _performanceChannel
        .receiveBroadcastStream('performance')
        .map((data) => Map<String, dynamic>.from(data));
  }

  /// Timeout for critical platform operations that interact with native
  /// services (GPS, permissions). Prevents Dart from hanging indefinitely
  /// if the native side becomes unresponsive.
  static const _platformTimeout = Duration(seconds: 30);

  @override
  Future<void> initialize(
      {String? licenseKey, PolyfenceConfiguration? config}) async {
    await _channel.invokeMethod('initialize', {
      'licenseKey': licenseKey,
      'config': config?.toMap(),
    }).timeout(_platformTimeout);
  }

  @override
  Future<void> addZone(Zone zone) async {
    await _channel.invokeMethod('addZone', zone.toJson());
  }

  @override
  Future<void> removeZone(String zoneId) async {
    await _channel.invokeMethod('removeZone', {'zoneId': zoneId});
  }

  @override
  Future<void> clearAllZones() async {
    await _channel.invokeMethod('clearAllZones');
  }

  @override
  Future<Zone?> getZone(String zoneId) async {
    final result = await _channel
        .invokeMethod<Map<Object?, Object?>>('getZone', {'zoneId': zoneId});

    if (result == null) {
      return null;
    }
    // Deep cast, not Map<String, dynamic>.from: a method channel hands back
    // nested maps as Map<Object?, Object?>, and Zone.fromJson passes `center`
    // straight to PolyfenceLocation.fromJson and assigns `metadata` to a
    // Map<String, dynamic>. A shallow cast converts the outer map only, so both
    // would fail at runtime on any zone that has a centre or metadata, which is
    // every zone worth reading back.
    //
    // Zone.fromJson takes a non-nullable id and name and rejects an empty one,
    // so a record missing either throws rather than returning. Left alone those
    // escape as a TypeError or an ArgumentError, which this method's signature
    // does not admit and its caller does not catch. A stored record this method
    // cannot decode is a real failure, not an absent zone, so it must not come
    // back as null either: that would report a corrupted store as "no such
    // zone". Raised as a PlatformException so PolyfenceService.getZone wraps it
    // into the PlatformOperationException it already documents.
    try {
      return Zone.fromJson(_deepCastMap(result));
    } catch (e) {
      throw PlatformException(
        code: 'ZONE_DECODE_FAILED',
        message: 'Stored zone $zoneId could not be read as a Zone: $e',
      );
    }
  }

  @override
  Future<void> startTracking() async {
    await _channel.invokeMethod('startTracking').timeout(_platformTimeout);
  }

  @override
  Future<void> stopTracking() async {
    await _channel.invokeMethod('stopTracking');
  }

  @override
  Future<bool> requestPermissions({bool always = false}) async {
    final result = await _channel.invokeMethod<bool>('requestPermissions', {
      'always': always,
    }).timeout(_platformTimeout);
    return result ?? false;
  }

  @override
  Future<bool> isLocationServiceEnabled() async {
    final result =
        await _channel.invokeMethod<bool>('isLocationServiceEnabled');
    return result ?? false;
  }

  @override
  Future<Map<String, dynamic>> checkBatteryOptimization() async {
    final result = await _channel
        .invokeMethod<Map<Object?, Object?>>('checkBatteryOptimization');
    if (result == null) return {};
    return _deepCastMap(result);
  }

  @override
  Future<void> requestBatteryOptimizationExemption() async {
    await _channel.invokeMethod<void>('requestBatteryOptimization');
  }

  @override
  Future<Map<String, dynamic>> getConfiguration() async {
    final result =
        await _channel.invokeMethod<Map<Object?, Object?>>('getConfiguration');
    return _deepCastMap(result ?? {});
  }

  /// Recursively casts platform channel maps from Map<Object?, Object?> to
  /// Map<String, dynamic>. Platform channels return untyped maps; a shallow
  /// Map.from only fixes the top level, leaving nested maps as Object?.
  /// Companion to [_deepCastMap] for the list case.
  ///
  /// Recurses into nested lists as well as maps. Handling only maps one level
  /// down leaves a map inside a list inside a list with its channel type, which
  /// then sits inside a value declared `Map<String, dynamic>`: the outer cast
  /// passes and the inner type is a lie, so the caller's first typed read of it
  /// throws. Caller-supplied zone metadata is arbitrary, so that nesting is
  /// ordinary rather than exotic.
  static List<dynamic> _deepCastList(List<Object?> list) {
    return list.map((e) {
      if (e is Map) return _deepCastMap(Map<Object?, Object?>.from(e));
      if (e is List) return _deepCastList(e);
      return e;
    }).toList();
  }

  static Map<String, dynamic> _deepCastMap(Map<Object?, Object?> map) {
    return map.map((key, value) {
      if (value is Map) {
        return MapEntry(key.toString(), _deepCastMap(Map<Object?, Object?>.from(value)));
      } else if (value is List) {
        return MapEntry(key.toString(), _deepCastList(value));
      }
      return MapEntry(key.toString(), value);
    });
  }

  @override
  Future<void> updateConfiguration(Map<String, dynamic> config) async {
    await _channel.invokeMethod('updateConfiguration', config);
  }

  @override
  Future<void> resetConfiguration() async {
    await _channel.invokeMethod('resetConfiguration');
  }

  @override
  Future<void> setAccuracyProfile(String profile) async {
    await _channel.invokeMethod('setAccuracyProfile', profile);
  }

  @override
  Future<Map<String, dynamic>> getDebugInfo() async {
    final result =
        await _channel.invokeMethod<Map<Object?, Object?>>('getDebugInfo');
    return _deepCastMap(result ?? {});
  }

  @override
  Future<List<Map<String, dynamic>>> getErrorHistory(
      Map<String, dynamic> params) async {
    final result =
        await _channel.invokeMethod<List<Object?>>('getErrorHistory', params);
    return (result ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  @override
  Future<Map<String, bool>> getZoneStates() async {
    final result = await _channel
        .invokeMethod<Map<Object?, Object?>>('getCurrentZoneStates');

    if (result == null) {
      return <String, bool>{};
    }

    // Channel returns Map<String, bool> on both platforms; we defensively
    // coerce keys to String and values to bool with a false default.
    return result.map(
      (key, value) => MapEntry(
        key as String,
        (value as bool?) ?? false,
      ),
    );
  }

  @override
  Future<Map<String, dynamic>> getSessionTelemetry() async {
    final result = await _channel
        .invokeMethod<Map<Object?, Object?>>('getSessionTelemetry');
    if (result == null) return {};
    return _deepCastMap(result);
  }

  @override
  Future<List<Map<String, dynamic>>> drainPendingEvents() async {
    final result =
        await _channel.invokeMethod<List<Object?>>('drainPendingEvents');
    if (result == null) return const <Map<String, dynamic>>[];
    return result
        .map((e) => _deepCastMap(Map<Object?, Object?>.from(e as Map)))
        .toList();
  }

  @override
  Future<int> pendingEventsDroppedCount() async {
    final result =
        await _channel.invokeMethod<Object?>('pendingEventsDroppedCount');
    if (result == null) return 0;
    return (result as num).toInt();
  }

  @override
  Future<void> setEventListenerActive(bool active) async {
    await _channel.invokeMethod('setEventListenerActive', {'active': active});
  }

  @override
  Future<void> dispose() async {
    // Cancel any active stream subscriptions before nulling references.
    // This ensures native event channel handlers are properly torn down
    // rather than just dropping the Dart-side stream references.
    try {
      await _channel.invokeMethod('dispose');
    } catch (_) {
      // Best-effort — native side may already be torn down
    }

    _locationStream = null;
    _geofenceStream = null;
    _errorStream = null;
    _performanceStream = null;
  }
}
