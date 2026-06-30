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
///     print('Entered ${event.zone?.name ?? event.zoneName}');
///   }
/// });
/// ```
class GeofenceEvent {
  /// The unique identifier of the zone that triggered this event.
  final String zoneId;

  /// Human-readable name of the zone that triggered this event.
  ///
  /// Empty string if the zone has no name configured. Populated by
  /// polyfence-core from the zone's persisted name; see also [zone] for
  /// the full client-side Zone object (looked up from the zone cache).
  final String zoneName;

  /// Whether this was an entry or exit event.
  final GeofenceEventType type;

  /// The device location when the event was detected.
  final PolyfenceLocation location;

  /// When the event was detected.
  final DateTime timestamp;

  /// Milliseconds the polyfence-core engine took to detect the
  /// transition (from receiving the GPS fix to firing this event).
  /// Useful for performance diagnostics.
  final double? detectionTimeMs;

  /// Distance in metres from the event location to the zone boundary
  /// at the moment of detection. Useful for filtering edge-of-boundary
  /// jitter.
  final double? distanceToBoundaryM;

  /// Milliseconds the device has been inside the zone at the moment of
  /// the event. Populated only on [GeofenceEventType.dwell] events —
  /// `null` for enter / exit / recovery* events (those don't carry a
  /// meaningful dwell duration). BUG-009 (pre-fix this was never
  /// populated because polyfence-core didn't emit the field and the
  /// bridge didn't read it).
  final double? dwellDurationMs;

  /// The full zone object, looked up from the local zone cache by
  /// [zoneId]. May be `null` if the zone was removed (or never
  /// registered) before the event was processed. NOT sent over the
  /// platform channel — populated client-side from
  /// [PolyfenceService]'s zone cache.
  final Zone? zone;

  /// Creates a geofence event.
  const GeofenceEvent({
    required this.zoneId,
    required this.type,
    required this.location,
    required this.timestamp,
    this.zoneName = '',
    this.detectionTimeMs,
    this.distanceToBoundaryM,
    this.dwellDurationMs,
    this.zone,
  });

  Map<String, dynamic> toJson() {
    return {
      'zoneId': zoneId,
      'zoneName': zoneName,
      'type': type.name,
      'location': location.toJson(),
      'timestamp': timestamp.millisecondsSinceEpoch,
      'detectionTimeMs': detectionTimeMs,
      'distanceToBoundaryM': distanceToBoundaryM,
      'dwellDurationMs': dwellDurationMs,
      'zone': zone?.toJson(),
    };
  }

  factory GeofenceEvent.fromJson(Map<String, dynamic> json) {
    return GeofenceEvent(
      zoneId: json['zoneId'],
      zoneName: json['zoneName'] as String? ?? '',
      type: GeofenceEventType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => GeofenceEventType.enter,
      ),
      location: PolyfenceLocation.fromJson(json['location']),
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
      detectionTimeMs: (json['detectionTimeMs'] as num?)?.toDouble(),
      distanceToBoundaryM: (json['distanceToBoundaryM'] as num?)?.toDouble(),
      dwellDurationMs: (json['dwellDurationMs'] as num?)?.toDouble(),
      zone: json['zone'] != null ? Zone.fromJson(json['zone']) : null,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GeofenceEvent &&
        other.zoneId == zoneId &&
        other.zoneName == zoneName &&
        other.type == type &&
        other.location == location &&
        other.timestamp == timestamp &&
        other.detectionTimeMs == detectionTimeMs &&
        other.distanceToBoundaryM == distanceToBoundaryM &&
        other.dwellDurationMs == dwellDurationMs &&
        other.zone == zone;
  }

  @override
  int get hashCode => Object.hash(
        zoneId,
        zoneName,
        type,
        location,
        timestamp,
        detectionTimeMs,
        distanceToBoundaryM,
        dwellDurationMs,
        zone,
      );
}
