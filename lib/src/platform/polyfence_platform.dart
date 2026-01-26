import 'dart:async';
import 'package:flutter/services.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import '../models/zone.dart';
import '../models/location.dart';

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

  Future<void> initialize({String? licenseKey, Map<String, dynamic>? config});
  Future<void> addZone(Zone zone);
  Future<void> removeZone(String zoneId);
  Future<void> clearAllZones();
  Future<void> startTracking();
  Future<void> stopTracking();
  Future<bool> requestPermissions({bool always = false});
  Future<void> dispose();

  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled();

  /// Check battery optimization status (Android only)
  Future<Map<String, dynamic>> checkBatteryOptimization();

  /// Request battery optimization exemption (Android only)
  Future<bool> requestBatteryOptimizationExemption();

  Future<Map<String, dynamic>> getConfiguration();
  Future<void> updateConfiguration(Map<String, dynamic> config);
  Future<void> resetConfiguration();
  Future<void> setAccuracyProfile(String profile);

  // GPS Configuration API
  Future<Map<String, dynamic>> getCurrentConfiguration();

  // Debug API methods
  Future<Map<String, dynamic>> getDebugInfo();
  Stream<Map<String, dynamic>> get performanceStream;
  Future<List<Map<String, dynamic>>> getErrorHistory(
      Map<String, dynamic> params);
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

  @override
  Future<void> initialize(
      {String? licenseKey, Map<String, dynamic>? config}) async {
    await _channel.invokeMethod('initialize', {
      'licenseKey': licenseKey,
      'config': config,
    });
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
  Future<void> startTracking() async {
    await _channel.invokeMethod('startTracking');
  }

  @override
  Future<void> stopTracking() async {
    await _channel.invokeMethod('stopTracking');
  }

  @override
  Future<bool> requestPermissions({bool always = false}) async {
    final result = await _channel.invokeMethod<bool>('requestPermissions', {
      'always': always,
    });
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
    return Map<String, dynamic>.from(result ?? {});
  }

  @override
  Future<bool> requestBatteryOptimizationExemption() async {
    final result =
        await _channel.invokeMethod<bool>('requestBatteryOptimization');
    return result ?? false;
  }

  @override
  Future<Map<String, dynamic>> getConfiguration() async {
    final result =
        await _channel.invokeMethod<Map<Object?, Object?>>('getConfiguration');
    return Map<String, dynamic>.from(result ?? {});
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
    return Map<String, dynamic>.from(result ?? {});
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
  Future<Map<String, dynamic>> getCurrentConfiguration() async {
    final result = await _channel
        .invokeMethod<Map<Object?, Object?>>('getCurrentConfiguration');
    return Map<String, dynamic>.from(result ?? {});
  }

  @override
  Future<void> dispose() async {
    // Cleanup platform resources
    // Reset stream references to allow garbage collection
    _locationStream = null;
    _geofenceStream = null;
    _errorStream = null;
    _performanceStream = null;

    // Note: MethodChannel and EventChannels are managed by Flutter framework
    // They will be cleaned up automatically when plugin is detached
  }
}
