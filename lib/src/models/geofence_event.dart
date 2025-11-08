import 'location.dart';
import 'zone.dart';

enum GeofenceEventType { enter, exit, dwell }

class GeofenceEvent {
  final String zoneId;
  final GeofenceEventType type;
  final PolyfenceLocation location;
  final DateTime timestamp;
  final Zone? zone;

  const GeofenceEvent({
    required this.zoneId,
    required this.type,
    required this.location,
    required this.timestamp,
    this.zone,
  });

  Map<String, dynamic> toJson() {
    return {
      'zoneId': zoneId,
      'type': type.name,
      'location': location.toJson(),
      'timestamp': timestamp.millisecondsSinceEpoch,
      'zone': zone?.toJson(),
    };
  }

  factory GeofenceEvent.fromJson(Map<String, dynamic> json) {
    return GeofenceEvent(
      zoneId: json['zoneId'],
      type: GeofenceEventType.values.firstWhere((e) => e.name == json['type']),
      location: PolyfenceLocation.fromJson(json['location']),
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
      zone: json['zone'] != null ? Zone.fromJson(json['zone']) : null,
    );
  }
}
