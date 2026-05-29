import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:polyfence/polyfence.dart';

import 'api_key_store.dart';

/// Service that fetches zones from the Polyfence Zone Admin API.
///
/// The API key is resolved via [ApiKeyStore], which reads the
/// build-time `--dart-define=POLYFENCE_API_KEY=...`. Callers should
/// gate invocation on key presence themselves; this service throws a
/// [StateError] when called without a configured key so that misuse
/// fails loudly in tests rather than silently swallowing an empty fetch.
class ZoneApiService {
  /// Configurable via `--dart-define=POLYFENCE_API_URL=...` for self-hosted
  /// or staging deployments. Defaults to the public Polyfence SaaS.
  static const String baseUrl = String.fromEnvironment(
    'POLYFENCE_API_URL',
    defaultValue: 'https://polyfence.io/api/zones',
  );

  /// Fetch all active zones for the account behind the resolved API key.
  ///
  /// Throws [StateError] when no key is configured (caller bug — gate on
  /// [ApiKeyStore.get] first). Wraps network / parse failures in
  /// [Exception] with a user-facing message.
  static Future<List<Zone>> fetchActiveZones() async {
    final apiKey = ApiKeyStore.get();
    if (apiKey == null || apiKey.isEmpty) {
      throw StateError(
        'No Polyfence API key configured. Sign up for a free key at '
        'https://polyfence.io and pass it at build time via '
        '--dart-define=POLYFENCE_API_KEY=your_key.',
      );
    }

    try {
      // The Polyfence list endpoint paginates with a default page size of
      // 50. Without `limit=`, accounts with > 50 zones silently lose
      // everything past page 1 — including zones that are active and
      // visible in the dashboard. `limit=200` covers the example app's
      // foreseeable zone count; users with larger accounts should add
      // proper pagination.
      final url = baseUrl.contains('?')
          ? '$baseUrl&limit=200'
          : '$baseUrl?limit=200';
      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'x-api-key': apiKey,
            },
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw TimeoutException(
                'Request timed out after 30 seconds. The server may be '
                'slow or unreachable.',
                const Duration(seconds: 30),
              );
            },
          );

      if (response.statusCode == 200) {
        final dynamic responseBody = json.decode(response.body);

        // Handle both response shapes:
        //   1. Direct array: [...]
        //   2. Wrapped object: {success: true, data: [...]}
        final List<dynamic> zonesJson;
        if (responseBody is List) {
          zonesJson = responseBody;
        } else if (responseBody is Map && responseBody.containsKey('data')) {
          zonesJson = responseBody['data'] as List<dynamic>;
        } else {
          throw Exception('Unexpected API response format');
        }

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
              debugPrint(
                'ZoneApiService: skipping inactive zone '
                "${zoneData['name']}",
              );
            }
          } catch (e) {
            debugPrint(
              'ZoneApiService: failed to process zone '
              "${zoneData['name']}: $e",
            );
          }
        }

        return zones;
      } else {
        final errorBody = response.body;
        debugPrint(
          'ZoneApiService: API error — status ${response.statusCode}, '
          'body $errorBody',
        );
        throw Exception(
          'Failed to load zones. Status: ${response.statusCode}. $errorBody',
        );
      }
    } on TimeoutException catch (e) {
      debugPrint('ZoneApiService: request timeout — $e');
      throw Exception(
        'Request timed out. The server may be slow or unreachable. '
        'Please try again.',
      );
    } on SocketException {
      throw Exception('No internet connection');
    } on http.ClientException {
      throw Exception('Network error occurred');
    } catch (e) {
      debugPrint('ZoneApiService: unexpected error — $e');
      throw Exception('Error fetching zones: $e');
    }
  }

  /// Convert an API zone payload to a Polyfence [Zone].
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
            center: PolyfenceLocation(
              latitude: centerLat,
              longitude: centerLng,
            ),
            radius: radiusMeters,
          );
        } else {
          debugPrint('ZoneApiService: invalid circle zone data for $name');
          return null;
        }
      } else if (type == 'polygon') {
        final List<PolyfenceLocation> points = _parsePolygonPoints(
          zoneData['polygon'],
        );

        if (points.isNotEmpty) {
          return Zone.polygon(id: id, name: name, polygon: points);
        } else {
          debugPrint('ZoneApiService: invalid polygon zone data for $name');
          return null;
        }
      } else {
        debugPrint('ZoneApiService: unknown zone type $type for $name');
        return null;
      }
    } catch (e) {
      debugPrint('ZoneApiService: failed to convert zone — $e');
      return null;
    }
  }

  /// Parse polygon points from an API response. Tolerates both an
  /// already-decoded `List` and a JSON-encoded string (older payloads).
  static List<PolyfenceLocation> _parsePolygonPoints(dynamic polygonData) {
    final List<PolyfenceLocation> points = [];

    try {
      List<dynamic> polygonJson;

      if (polygonData is String) {
        polygonJson = json.decode(polygonData);
      } else if (polygonData is List) {
        polygonJson = polygonData;
      } else {
        debugPrint(
          'ZoneApiService: invalid polygon data type '
          '${polygonData.runtimeType}',
        );
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
      debugPrint('ZoneApiService: failed to parse polygon points — $e');
    }

    return points;
  }

  /// Safely parse a double from int / double / String inputs.
  static double? _parseDouble(dynamic value) {
    if (value == null) return null;

    try {
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.parse(value);
    } catch (e) {
      debugPrint('ZoneApiService: failed to parse double from $value — $e');
    }

    return null;
  }
}
