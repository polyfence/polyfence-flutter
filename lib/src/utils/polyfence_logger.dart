import 'package:flutter/foundation.dart';

/// Centralized logging for Polyfence.
///
/// All output is gated behind [kDebugMode] so no log messages are emitted
/// in release builds. This prevents leaking internal implementation details
/// (zone IDs, coordinates, error messages) in production.
class PolyfenceLogger {
  static const String _tag = 'PF';

  /// Log error with structured format.
  ///
  /// Only prints in debug builds. Safe to call with any error object —
  /// the error's `toString()` is never evaluated in release mode.
  static void logError(String component, String message, [Object? error]) {
    if (!kDebugMode) return;
    final errorMsg = error != null ? ' - $error' : '';
    debugPrint('$_tag[ERR]: $component: $message$errorMsg');
  }

  /// Log geofence events in terse format.
  ///
  /// Only prints in debug builds.
  static void logGeofenceEvent(
      String eventType, String zoneId, String zoneName) {
    if (!kDebugMode) return;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    debugPrint(
        '$_tag: EVENT $eventType zone=${zoneName.isEmpty ? zoneId : zoneName} ts=$timestamp');
  }

  /// Log a debug message. Only prints in debug builds.
  static void logDebug(String component, String message) {
    if (!kDebugMode) return;
    debugPrint('$_tag: $component: $message');
  }
}
