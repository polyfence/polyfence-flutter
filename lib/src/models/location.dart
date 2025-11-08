class PolyfenceLocation {
  final double latitude;
  final double longitude;
  final double? altitude;
  final double? accuracy;
  final DateTime? timestamp;
  final double? speed;
  final int? interval;

  const PolyfenceLocation({
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.accuracy,
    this.timestamp,
    this.speed,
    this.interval,
  });

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'accuracy': accuracy,
      'timestamp': timestamp?.millisecondsSinceEpoch,
      'speed': speed,
      'interval': interval,
    };
  }

  factory PolyfenceLocation.fromJson(Map<String, dynamic> json) {
    final num? tsNum = json['timestamp'] as num?;
    final DateTime? ts = tsNum != null
        ? DateTime.fromMillisecondsSinceEpoch(tsNum.round())
        : null;

    return PolyfenceLocation(
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      altitude: (json['altitude'] as num?)?.toDouble(),
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      timestamp: ts,
      speed: (json['speed'] as num?)?.toDouble(),
      interval: (json['interval'] as num?)?.toInt(),
    );
  }

  @override
  String toString() {
    return 'PolyfenceLocation(lat: $latitude, lng: $longitude)';
  }
}
