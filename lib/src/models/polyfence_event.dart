/// Consistent event structure for notifications
/// Single responsibility: Standardized event format
class PolyfenceEvent {
  final String type; // 'enter', 'exit', 'error'
  final String zoneId;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;
  
  const PolyfenceEvent({
    required this.type,
    required this.zoneId,
    required this.timestamp,
    required this.metadata,
  });
  
  // Standard format for event processing
  Map<String, dynamic> toEvent() {
    return {
      'event_type': type,
      'zone_id': zoneId,
      'timestamp': timestamp.toIso8601String(),
      'metadata': metadata,
    };
  }
}