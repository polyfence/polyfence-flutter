/// Centralized error logging for Polyfence
class PolyfenceLogger {
  static const String _tag = 'PF';
  
  /// Log error with structured format
  static void logError(String component, String message, [Object? error]) {
    final errorMsg = error != null ? ' - $error' : '';
    print('$_tag[ERR]: $component: $message$errorMsg');
  }
  
  /// Log geofence events in terse format
  static void logGeofenceEvent(String eventType, String zoneId, String zoneName) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    print('$_tag: EVENT $eventType zone=${zoneName.isEmpty ? zoneId : zoneName} ts=$timestamp');
  }
}