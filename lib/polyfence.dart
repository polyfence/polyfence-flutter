/// Privacy-first, on-device geofencing for Flutter.
///
/// Polyfence provides accurate circle and polygon zone detection with true
/// background operation. By default, no data leaves the device. Optional
/// analytics is opt-in and requires an API key.
///
/// ## Features
///
/// - **Circle & Polygon Zones**: Support for both circular and complex polygon zones
/// - **True Background Operation**: Works reliably in background on iOS and Android
/// - **Privacy-First**: All processing happens on-device by default
/// - **Cross-Platform Consistency**: Identical behavior on Android and iOS
/// - **Structured Error Handling**: Comprehensive error streams for debugging
/// - **Battery Optimization**: Built-in battery optimization management
/// - **GPS Configuration**: Flexible GPS accuracy and update frequency settings
///
/// ## Quick Start
///
/// ```dart
/// import 'package:polyfence/polyfence.dart';
///
/// // Initialize
/// await Polyfence.instance.initialize();
///
/// // Add a zone
/// final zone = Zone.circle(
///   id: 'office',
///   name: 'Office',
///   center: PolyfenceLocation(latitude: 37.422, longitude: -122.084),
///   radius: 150,
/// );
/// await Polyfence.instance.addZone(zone);
///
/// // Listen for events
/// Polyfence.instance.onGeofenceEvent.listen((event) {
///   print('${event.type.name.toUpperCase()}: ${event.zoneId}');
/// });
///
/// // Start tracking
/// await Polyfence.instance.startTracking();
/// ```
///
/// See the [README](https://github.com/polyfence/polyfence-flutter) for more examples.
library polyfence;

export 'src/models/zone.dart';
export 'src/models/geofence_event.dart';
export 'src/models/location.dart';
export 'src/models/industry_category.dart';
export 'src/models/polyfence_runtime_status.dart';
export 'src/models/health_score.dart';
export 'src/services/polyfence_service.dart';
export 'src/services/analytics_service.dart';
export 'src/services/app_lifecycle_manager.dart';
export 'src/platform/polyfence_platform.dart';
export 'src/errors/polyfence_error.dart';
export 'src/errors/polyfence_exceptions.dart';
export 'src/debug/polyfence_debug_info.dart';
export 'src/configuration/polyfence_configuration.dart';
export 'src/utils/polygon_simplifier.dart';
export 'src/widgets/polyfence_debug_overlay.dart';

import 'src/services/polyfence_service.dart';

/// Main entry point for Polyfence geofencing plugin.
///
/// Provides access to the singleton [PolyfenceService] instance through
/// [instance]. All geofencing operations are performed through this instance.
///
/// **Example:**
/// ```dart
/// await Polyfence.instance.initialize();
/// await Polyfence.instance.addZone(myZone);
/// await Polyfence.instance.startTracking();
/// ```
class Polyfence {
  /// Gets the singleton Polyfence service instance.
  ///
  /// Use this to access all geofencing functionality:
  /// - Zone management (add, remove, clear)
  /// - Location tracking (start, stop)
  /// - Event streams (geofence events, location updates, errors)
  /// - GPS configuration
  /// - Debug information
  static PolyfenceService get instance => PolyfenceService.instance;
}
