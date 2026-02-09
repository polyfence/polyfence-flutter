import 'package:flutter/foundation.dart';

/// Centralized error logging for Polyfence.
///
/// Provides structured logging for errors and geofence events.
/// All output uses [debugPrint] so messages are suppressed in release builds.
class PolyfenceLogger {
  static const String _tag = 'PF';

  /// Log error with structured format.
  static void logError(String component, String message, [Object? error]) {
    final errorMsg = error != null ? ' - $error' : '';
    debugPrint('$_tag[ERR]: $component: $message$errorMsg');
  }

  /// Log geofence events in terse format.
  static void logGeofenceEvent(
      String eventType, String zoneId, String zoneName) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    debugPrint(
        '$_tag: EVENT $eventType zone=${zoneName.isEmpty ? zoneId : zoneName} ts=$timestamp');
  }
}
