import 'package:flutter/foundation.dart';

/// Categories of errors that can occur in Polyfence.
///
/// Errors are emitted through [PolyfenceService.onError] and can be used
/// to handle specific failure conditions.
enum PolyfenceErrorType {
  // GPS Related

  /// GPS location request timed out.
  gpsTimeout,

  /// Location permission was denied by the user.
  gpsPermissionDenied,

  /// Device location services are disabled.
  gpsServiceDisabled,

  /// GPS accuracy is below the configured threshold.
  gpsAccuracyPoor,

  /// GPS signal is unreliable (frequent dropouts, large accuracy swings).
  /// This indicates Android FLP is feeding inconsistent location data.
  gpsUnreliable,

  // Service Related

  /// Background tracking service failed to start.
  serviceStartFailed,

  /// Background service was killed by the system.
  serviceKilled,

  /// Failed to restart the background service after it was killed.
  serviceRestartFailed,

  // Battery Related

  /// Battery optimization is preventing reliable background tracking.
  batteryOptimizationRequired,

  /// Device battery is critically low.
  lowBattery,

  // Zone Related

  /// Zone definition failed validation (e.g., invalid coordinates).
  zoneValidationFailed,

  /// Failed to save zone to persistent storage.
  zoneStorageFailed,

  /// Failed to load zones from persistent storage.
  zoneLoadFailed,

  // Network Related

  /// Network request timed out.
  networkTimeout,

  /// Failed to upload analytics data.
  analyticsUploadFailed,

  // System Related

  /// Location permission was revoked while tracking.
  permissionRevoked,

  /// Device is running low on memory.
  memoryLow,

  /// An unknown error occurred.
  unknown,
}

/// An error that occurred during Polyfence operation.
///
/// Errors are emitted through [PolyfenceService.onError]. Listen to this
/// stream to handle GPS failures, permission issues, and other problems.
///
/// **Example:**
/// ```dart
/// Polyfence.instance.onError.listen((error) {
///   switch (error.type) {
///     case PolyfenceErrorType.gpsPermissionDenied:
///       // Prompt user to grant permission
///       break;
///     case PolyfenceErrorType.gpsServiceDisabled:
///       // Prompt user to enable location services
///       break;
///     default:
///       print('Error: ${error.message}');
///   }
/// });
/// ```
class PolyfenceError {
  /// The category of error that occurred.
  final PolyfenceErrorType type;

  /// Human-readable error message.
  final String message;

  /// Additional context about the error (e.g., zone ID, coordinates).
  final Map<String, dynamic> context;

  /// When the error occurred.
  final DateTime timestamp;

  /// Optional correlation ID for tracking related errors.
  final String? correlationId;

  /// Creates a Polyfence error.
  PolyfenceError({
    required this.type,
    required this.message,
    required this.context,
    required this.timestamp,
    this.correlationId,
  });

  /// Creates an error from a map (used for platform channel deserialization).
  ///
  /// Handles both camelCase (Dart convention, e.g. `"permissionRevoked"`) and
  /// snake_case (native convention, e.g. `"permission_revoked"`) type strings.
  factory PolyfenceError.fromMap(Map<String, dynamic> map) {
    final rawType = map['type'] as String? ?? '';
    // Normalize: convert snake_case to camelCase for matching against enum names
    final normalizedType = _snakeToCamel(rawType);

    return PolyfenceError(
      type: PolyfenceErrorType.values.firstWhere(
        (e) => e.toString().split('.').last == normalizedType,
        orElse: () => PolyfenceErrorType.unknown,
      ),
      message: map['message'] ?? '',
      context: Map<String, dynamic>.from(map['context'] ?? {}),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] ?? 0),
      correlationId: map['correlationId'],
    );
  }

  /// Converts a snake_case string to camelCase.
  /// Returns the input unchanged if it's already camelCase or has no underscores.
  static String _snakeToCamel(String input) {
    if (!input.contains('_')) return input;
    final parts = input.split('_');
    final buffer = StringBuffer(parts.first);
    for (var i = 1; i < parts.length; i++) {
      if (parts[i].isNotEmpty) {
        buffer.write(parts[i][0].toUpperCase());
        buffer.write(parts[i].substring(1));
      }
    }
    return buffer.toString();
  }

  /// Converts this error to a map for serialization.
  Map<String, dynamic> toMap() {
    return {
      'type': type.toString().split('.').last,
      'message': message,
      'context': context,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'correlationId': correlationId,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PolyfenceError &&
        other.type == type &&
        other.message == message &&
        mapEquals(other.context, context) &&
        other.timestamp == timestamp &&
        other.correlationId == correlationId;
  }

  @override
  int get hashCode {
    var contextHash = 0;
    final sortedKeys = context.keys.toList()..sort();
    for (final key in sortedKeys) {
      contextHash = Object.hash(contextHash, key, context[key]);
    }
    return Object.hash(type, message, contextHash, timestamp, correlationId);
  }

  @override
  String toString() {
    return 'PolyfenceError(type: $type, message: $message, timestamp: $timestamp)';
  }
}
