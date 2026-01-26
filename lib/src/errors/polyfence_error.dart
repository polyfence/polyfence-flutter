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
  factory PolyfenceError.fromMap(Map<String, dynamic> map) {
    return PolyfenceError(
      type: PolyfenceErrorType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'],
        orElse: () => PolyfenceErrorType.unknown,
      ),
      message: map['message'] ?? '',
      context: Map<String, dynamic>.from(map['context'] ?? {}),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] ?? 0),
      correlationId: map['correlationId'],
    );
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
  String toString() {
    return 'PolyfenceError(type: $type, message: $message, timestamp: $timestamp)';
  }
}
