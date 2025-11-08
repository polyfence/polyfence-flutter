enum PolyfenceErrorType {
  // GPS Related
  gpsTimeout,
  gpsPermissionDenied,
  gpsServiceDisabled,
  gpsAccuracyPoor,

  // Service Related
  serviceStartFailed,
  serviceKilled,
  serviceRestartFailed,

  // Battery Related
  batteryOptimizationRequired,
  lowBattery,

  // Zone Related
  zoneValidationFailed,
  zoneStorageFailed,
  zoneLoadFailed,

  // Network Related
  networkTimeout,
  analyticsUploadFailed,

  // System Related
  permissionRevoked,
  memoryLow,
  unknown
}

class PolyfenceError {
  final PolyfenceErrorType type;
  final String message;
  final Map<String, dynamic> context;
  final DateTime timestamp;
  final String? correlationId;

  PolyfenceError({
    required this.type,
    required this.message,
    required this.context,
    required this.timestamp,
    this.correlationId,
  });

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
