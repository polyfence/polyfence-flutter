import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:polyfence/polyfence.dart';

/// Centralized error logging for example app
class _Logger {
  static void logError(String message, [Object? error]) {
    final errorMsg = error != null ? ' - $error' : '';
    print('ZoneAPI error: $message$errorMsg');
  }
}

/// Service to fetch zones from the Polyfence Zone Admin API
class ZoneApiService {
  static const String baseUrl = 'https://polyfence.io/api/zones';

  /// Fetch all active zones from the admin database
  static Future<List<Zone>> fetchActiveZones() async {
    try {
      final response = await http.get(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          // ⚠️ TEST/DEMO KEY ONLY - Example app demonstration purposes
          // This is a test API key with limited permissions.
          // Do NOT use this key in production applications.
          // For production: Get your own key from https://polyfence.io/signup
          'x-api-key': 'cu-5lmLLJE7lQLPBkd7JPR3SPgDI9D3PfR3j2StsdX8',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> zonesJson = json.decode(response.body);

        final List<Zone> zones = [];

        for (final zoneData in zonesJson) {
          try {
            // Only process active zones
            if (zoneData['is_active'] == true) {
              final zone = _convertApiZoneToPolyfenceZone(zoneData);
              if (zone != null) {
                zones.add(zone);
              }
            } else {
              _Logger.logError('Skipping inactive zone: ${zoneData['name']}');
            }
          } catch (e) {
            _Logger.logError('Processing zone ${zoneData['name']}', e);
          }
        }

        return zones;
      } else {
        throw Exception('Failed to load zones. Status: ${response.statusCode}');
      }
    } on SocketException {
      throw Exception('No internet connection');
    } on http.ClientException {
      throw Exception('Network error occurred');
    } catch (e) {
      throw Exception('Error fetching zones: $e');
    }
  }

  /// Convert API zone data to Polyfence Zone object
  static Zone? _convertApiZoneToPolyfenceZone(Map<String, dynamic> zoneData) {
    try {
      final String id = zoneData['id'].toString();
      final String name = zoneData['name'] ?? 'Unknown Zone';
      final String type = zoneData['type'] ?? 'circle';

      if (type == 'circle') {
        final double? centerLat = _parseDouble(zoneData['center_lat']);
        final double? centerLng = _parseDouble(zoneData['center_lng']);
        final double? radiusMeters = _parseDouble(zoneData['radius_meters']);

        if (centerLat != null && centerLng != null && radiusMeters != null) {
          return Zone.circle(
            id: id,
            name: name,
            center:
                PolyfenceLocation(latitude: centerLat, longitude: centerLng),
            radius: radiusMeters,
          );
        } else {
          _Logger.logError('Invalid circle zone data for $name');
          return null;
        }
      } else if (type == 'polygon') {
        final List<PolyfenceLocation> points =
            _parsePolygonPoints(zoneData['polygon']);

        if (points.isNotEmpty) {
          return Zone.polygon(
            id: id,
            name: name,
            polygon: points,
          );
        } else {
          _Logger.logError('Invalid polygon zone data for $name');
          return null;
        }
      } else {
        _Logger.logError('Unknown zone type: $type for $name');
        return null;
      }
    } catch (e) {
      _Logger.logError('Converting zone', e);
      return null;
    }
  }

  /// Parse polygon points from API response
  static List<PolyfenceLocation> _parsePolygonPoints(dynamic polygonData) {
    final List<PolyfenceLocation> points = [];

    try {
      List<dynamic> polygonJson;

      // Handle both string and already parsed JSON
      if (polygonData is String) {
        polygonJson = json.decode(polygonData);
      } else if (polygonData is List) {
        polygonJson = polygonData;
      } else {
        _Logger.logError(
            'Invalid polygon data type: ${polygonData.runtimeType}');
        return points;
      }

      for (final pointData in polygonJson) {
        if (pointData is Map<String, dynamic>) {
          final double? lat = _parseDouble(pointData['lat']);
          final double? lng = _parseDouble(pointData['lng']);

          if (lat != null && lng != null) {
            points.add(PolyfenceLocation(latitude: lat, longitude: lng));
          }
        }
      }
    } catch (e) {
      _Logger.logError('Parsing polygon points', e);
    }

    return points;
  }

  /// Safely parse double from various input types
  static double? _parseDouble(dynamic value) {
    if (value == null) return null;

    try {
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.parse(value);
    } catch (e) {
      _Logger.logError('Parsing double from $value', e);
    }

    return null;
  }
}

/// Extension to add zone info for debugging
extension ZoneInfo on Zone {
  String get debugInfo {
    if (type == ZoneType.circle && center != null && radius != null) {
      return 'Circle: ${center!.latitude}, ${center!.longitude} (${radius}m)';
    } else if (type == ZoneType.polygon && polygon != null) {
      return 'Polygon: ${polygon!.length} points';
    }
    return 'Unknown zone type';
  }
}
