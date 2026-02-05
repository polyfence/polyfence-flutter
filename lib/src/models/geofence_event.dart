import 'location.dart';
import 'zone.dart';

/// The type of geofence event that occurred.
enum GeofenceEventType {
  /// Device entered a zone boundary.
  enter,

  /// Device exited a zone boundary.
  exit,

  /// Device has remained inside a zone for the configured dwell threshold.
  /// Fired once after device stays inside a zone for the duration specified
  /// in DwellSettings.dwellThreshold (default: 5 minutes).
  dwell,

  /// State recovery: device was outside according to persisted state,
  /// but is now inside according to current location.
  /// Fired after service restart when reconciling state.
  recoveryEnter,

  /// State recovery: device was inside according to persisted state,
  /// but is now outside according to current location.
  /// Fired after service restart when reconciling state.
  recoveryExit,
}

/// A geofence event triggered when a device enters or exits a zone.
///
/// Events are emitted through [PolyfenceService.onGeofenceEvent] when the
/// device crosses a zone boundary.
///
/// **Example:**
/// ```dart
/// Polyfence.instance.onGeofenceEvent.listen((event) {
///   if (event.type == GeofenceEventType.enter) {
///     print('Entered ${event.zone?.name ?? event.zoneId}');
///   }
/// });
/// ```
class GeofenceEvent {
  /// The unique identifier of the zone that triggered this event.
  final String zoneId;

  /// Whether this was an entry or exit event.
  final GeofenceEventType type;

  /// The device location when the event was detected.
  final PolyfenceLocation location;

  /// When the event was detected.
  final DateTime timestamp;

  /// The full zone object, if available.
  ///
  /// May be `null` if the zone was removed before the event was processed.
  final Zone? zone;

  /// Creates a geofence event.
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
      type: GeofenceEventType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => GeofenceEventType.enter,
      ),
      location: PolyfenceLocation.fromJson(json['location']),
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
      zone: json['zone'] != null ? Zone.fromJson(json['zone']) : null,
    );
  }
}
