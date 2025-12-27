# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- **Improved detection time accuracy** (Android & iOS)
  - Detection time now measures actual algorithm execution time (zone check start to event detection)
  - Previously used GPS timestamp age, which was inaccurate
  - Uses `System.nanoTime()` (Android) and `CFAbsoluteTimeGetCurrent()` (iOS) for precise timing
  - More accurate analytics metrics for performance monitoring
- **Analytics lifecycle management improvements**
  - Plugin now automatically manages analytics session lifecycle via `AppLifecycleManager`
  - Removed need for manual `startSession()`/`endSession()` calls in apps
  - Analytics events are automatically recorded when geofence events occur
  - Example apps updated to demonstrate automatic analytics handling

### Fixed
- Fixed detection time calculation to use actual algorithm execution time instead of GPS timestamp age
- Removed redundant manual analytics lifecycle management from example apps

## [0.2.0] - 2025-12-23

### Added
- **Delta-based zone synchronization** in example app
  - Prevents "zombie zones" when switching between demo and API modes
  - Uses SharedPreferences to track registered zone IDs persistently
  - Only adds new zones and removes deleted zones (efficient delta sync)
  - Survives app kills, crashes, and restarts
  - Ensures zones in app always match zones in backend (architectural principle)

### Fixed
- **BREAKING FIX:** Fixed Android zone removal bug - `removeZone()` and `clearAllZones()` now work regardless of tracking state
  - **Root cause:** Two-layer guard system prevented zone removal when tracking was disabled
    - Layer 1: PolyfencePlugin checked `isTrackingEnabled()` (SharedPreferences)
    - Layer 2: LocationTracker service checked `isRunning` (foreground service state)
  - **What changed:**
    - Removed tracking state check from `PolyfencePlugin.removeZone()` and `clearAllZones()`
    - Reordered logic in `LocationTracker` to process removal before checking service state
    - Zones are now removed from persistent storage even when tracking is stopped
  - **Impact:** Fixes issue where deleted zones continued triggering geofence events on Android
  - **Edge case resolved:** Zones deleted while tracking is disabled no longer reappear when tracking restarts
  - **No breaking changes:** Background tracking behavior and app closure handling remain unchanged

### Changed
- Renamed methods to follow Dart style guide:
  - `getConfiguration()` → `configuration()`
  - `getDebugInfo()` → `debugInfo()`
  - `getErrorHistory()` → `errorHistory()`
  - `getCurrentConfiguration()` → `gpsConfiguration()`
  - `checkBatteryOptimization()` → `batteryOptimizationStatus()`
- **API key configuration improvements**:
  - Made API key nullable/optional (was required before)
  - Set default to `null` in example app config (forces explicit user configuration)
  - Added validation check before making API requests
  - Improved error messages when API key is missing
  - Added security documentation for protecting API keys in production
  - Removed placeholder API keys from repository for security

### Fixed
- Fixed inconsistent error handling - standardized exception types
- Fixed error messages to use public API method names
- Removed duplicate enum conversion utilities
- Fixed linter warnings (unnecessary null checks, type checks, casts)
- Fixed broken documentation links in README (API Reference and Platform Setup anchors)
- Fixed platform channel type safety - standardized timestamps to Int64 across all platforms
- Fixed Android wake lock timeout issue (now uses indefinite wake lock with proper cleanup)
- Fixed hardcoded package name in Android notification intents (now dynamically resolves)
- Fixed Android SDK constant check for FOREGROUND_SERVICE_LOCATION permission (API 34+)
- Fixed GPS recovery logic to handle up to 5 consecutive failures consistently
- Enhanced thread safety in ZonePersistence (Android & iOS) to prevent data corruption
- Fixed code style issues (const constructors, doc comments, unnecessary operations) - all lint issues resolved

### Added
- `PolyfenceException` base class for all plugin exceptions
- `PolyfenceNotInitializedException` for initialization errors
- `PlatformOperationException` for platform operation failures
- `EnumUtils` utility class for enum conversion
- Comprehensive dartdoc comments for all public APIs
- Dynamic plugin version extraction from pubspec.yaml

## [0.1.0] - 2025-11-08

### Added
- Initial release of Polyfence Flutter plugin
- Circle and polygon geofencing support
- Background location tracking (Android & iOS)
- Real-time zone entry/exit detection
- Cross-platform consistency (identical behavior on Android/iOS)
- Structured error handling with error streams
- Comprehensive debug information API
- Battery optimization management (Android)
- Wake lock support for reliable background operation
- GPS configuration profiles (maxAccuracy, balanced, batteryOptimal, adaptive)
- Proximity-based GPS optimization
- Movement-based GPS optimization
- On-device zone persistence (SharedPreferences on Android, UserDefaults on iOS)
- Demo mode in example app with 3 hardcoded zones
- Optional analytics (opt-in with API key)

### Platform Support
- Android: API 21+ (Android 5.0+)
- iOS: 12.0+

### Known Limitations
- iOS notification delivery requires Critical Alert entitlement for optimal performance
- Large polygons (>50 vertices) may impact performance
- Maximum recommended zones: 50 active simultaneously

