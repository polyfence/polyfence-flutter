import 'package:polyfence/polyfence.dart';

/// Demo zone data for offline testing
class DemoZones {
  /// Get hardcoded demo zones for testing without API
  static List<Zone> getDemoZones() {
    return [
      // Demo Circle Zone 1 - London area
      Zone.circle(
        id: 'demo_circle_1',
        name: '🎯 Demo Zone 1',
        center: const PolyfenceLocation(
          latitude: 51.5074,
          longitude: -0.1278,
        ),
        radius: 500,
      ),

      // Demo Circle Zone 2 - Different location
      Zone.circle(
        id: 'demo_circle_2',
        name: '🎯 Demo Zone 2',
        center: const PolyfenceLocation(
          latitude: 51.5155,
          longitude: -0.0922,
        ),
        radius: 300,
      ),

      // Demo Polygon Zone 3 - Area with multiple points
      Zone.polygon(
        id: 'demo_polygon_3',
        name: '🎯 Demo Zone 3',
        polygon: const [
          PolyfenceLocation(latitude: 51.5000, longitude: -0.1300),
          PolyfenceLocation(latitude: 51.5020, longitude: -0.1250),
          PolyfenceLocation(latitude: 51.5010, longitude: -0.1200),
          PolyfenceLocation(latitude: 51.4990, longitude: -0.1220),
        ],
      ),
    ];
  }
}
