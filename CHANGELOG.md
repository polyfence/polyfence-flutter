# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- Renamed methods to follow Dart style guide:
  - `getConfiguration()` → `configuration()`
  - `getDebugInfo()` → `debugInfo()`
  - `getErrorHistory()` → `errorHistory()`
  - `getCurrentConfiguration()` → `gpsConfiguration()`
  - `checkBatteryOptimization()` → `batteryOptimizationStatus()`

### Fixed
- Fixed inconsistent error handling - standardized exception types
- Fixed error messages to use public API method names
- Removed duplicate enum conversion utilities
- Fixed linter warnings (unnecessary null checks, type checks, casts)

### Added
- `PolyfenceException` base class for all plugin exceptions
- `PolyfenceNotInitializedException` for initialization errors
- `PlatformOperationException` for platform operation failures
- `EnumUtils` utility class for enum conversion

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
- On-device zone persistence (SQLite on Android, UserDefaults on iOS)
- Demo mode in example app with 3 hardcoded zones
- Optional analytics (opt-in with API key)

### Platform Support
- Android: API 21+ (Android 5.0+)
- iOS: 12.0+

### Known Limitations
- iOS notification delivery requires Critical Alert entitlement for optimal performance
- Large polygons (>50 vertices) may impact performance
- Maximum recommended zones: 50 active simultaneously

