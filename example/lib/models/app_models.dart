import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

enum TrackingStatus { active, inactive, error }

enum GpsProfile { max, balanced, battery, smart }

enum ZoneType { circle, polygon }

enum EventType { enter, exit, error }

class LatLng {
  final double latitude;
  final double longitude;

  const LatLng(this.latitude, this.longitude);

  String toFormattedString() {
    return '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
  }
}

class Zone {
  final String id;
  final String name;
  final ZoneType type;
  final double? distance;

  const Zone({
    required this.id,
    required this.name,
    required this.type,
    this.distance,
  });
}

class GeofenceEvent {
  final String id;
  final DateTime timestamp;
  final EventType type;
  final String zoneName;
  final String zoneId;
  final String? message;

  const GeofenceEvent({
    required this.id,
    required this.timestamp,
    required this.type,
    required this.zoneName,
    required this.zoneId,
    this.message,
  });
}

// Helper extensions
extension GpsProfileExtension on GpsProfile {
  String get displayName {
    switch (this) {
      case GpsProfile.max:
        return 'Max';
      case GpsProfile.balanced:
        return 'Balance';
      case GpsProfile.battery:
        return 'Battery';
      case GpsProfile.smart:
        return 'Smart';
    }
  }

  String get description {
    switch (this) {
      case GpsProfile.max:
        return 'Highest accuracy, most battery use';
      case GpsProfile.balanced:
        return 'Good accuracy, moderate battery';
      case GpsProfile.battery:
        return 'Lower accuracy, best battery life';
      case GpsProfile.smart:
        return 'Adapts based on movement & proximity';
    }
  }

  String get intervalText {
    switch (this) {
      case GpsProfile.max:
        return '5s';
      case GpsProfile.balanced:
        return '10s';
      case GpsProfile.battery:
        return '30s';
      case GpsProfile.smart:
        return '10s';
    }
  }

  IconData get icon {
    switch (this) {
      case GpsProfile.max:
        return LucideIcons.zap;
      case GpsProfile.balanced:
        return LucideIcons.trendingUp;
      case GpsProfile.battery:
        return LucideIcons.battery;
      case GpsProfile.smart:
        return LucideIcons.target;
    }
  }
}
