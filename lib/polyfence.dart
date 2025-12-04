library polyfence;

export 'src/models/zone.dart';
export 'src/models/geofence_event.dart';
export 'src/models/location.dart';
export 'src/models/industry_category.dart';
export 'src/services/polyfence_service.dart';
export 'src/services/analytics_service.dart';
export 'src/services/app_lifecycle_manager.dart';
export 'src/platform/polyfence_platform.dart';
export 'src/errors/polyfence_error.dart';
export 'src/errors/polyfence_exceptions.dart';
export 'src/debug/polyfence_debug_info.dart';
export 'src/configuration/polyfence_configuration.dart';

import 'src/services/polyfence_service.dart';

/// Polyfence provides accurate geofencing without external dependencies.
/// All processing happens on-device for maximum privacy.
class Polyfence {
  static PolyfenceService get instance => PolyfenceService.instance;
}
