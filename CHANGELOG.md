# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.4.0] - 2026-01-02

### Added
- **Enhanced exception diagnostics**
  - `PlatformOperationException` now exposes `details`, `innerException`, and `stackTrace` fields
  - Developers can access full `PlatformException.code` and `details` for debugging
  - Complete stack traces preserved and accessible in exception objects
  - Enhanced `toString()` output with formatted details, inner exception, and stack trace

- **Improved error visibility**
  - Missing GPS coordinates in geofence events now emit warning errors to error stream
  - Unknown event types emit structured errors instead of silently defaulting
  - Invalid timestamps emit errors with diagnostic context instead of throwing
  - All parsing failures emit `PolyfenceError` events for developer visibility

### Fixed
- **Platform interface architecture improvements**
  - Added missing `onGeofenceEvent` stream to abstract `PolyfencePlatform` interface
  - Removed unnecessary type casts to `MethodChannelPolyfence` throughout service layer
  - Fixes analyzer warnings and enables proper platform interface mocking for tests
  - Improves testability and maintainability of platform boundary code

- **Defensive event parsing to prevent crashes**
  - Wrapped `_handleGeofenceEvent` in comprehensive try-catch to prevent stream callback crashes
  - Added explicit `eventType` validation with switch expression (handles unknown event types gracefully)
  - Timestamp parsing no longer throws exceptions - emits error and uses fallback instead
  - All parsing failures emit structured `PolyfenceError` events for developer visibility

- **Code quality improvements**
  - Fixed dead code warning in `example/lib/zone_api_service.dart` (unreachable catch block)
  - Reordered exception handlers (`ClientException` before `SocketException` to prevent subtype shadowing)

### Changed
- **Error stream behavior**
  - Error stream now receives more events for edge cases (missing coords, unknown event types, invalid timestamps)
  - Coordinate fallback (0.0/0.0) is still used but now transparent via error emission
  - Helps developers identify platform data issues instead of silent failures

## [0.3.1] - 2025-12-29

### Fixed
- **Plugin version now correctly reported in analytics**
  - Fixed bug where plugin was sending app's version (e.g., `1.0.0`) instead of plugin's own version (e.g., `0.3.0`)
  - Plugin now uses version constant from `lib/src/version.dart` instead of `PackageInfo.fromPlatform()`
  - Version constant automatically synced from `pubspec.yaml` via pre-commit hook
  - Ensures accurate plugin version tracking in analytics and debug info

## [0.3.0] - 2025-12-29

### Changed
- **Anonymous plugin telemetry enabled by default**
  - Telemetry is now enabled by default to monitor plugin performance and improve reliability
  - Simple one-line opt-out: `AnalyticsConfig(disableTelemetry: true)`
  - Smart disclosure informs developers (once per install, only debug builds, state-aware)
  - API key no longer required for telemetry (optional - only needed for additional Polyfence.io services)
  - Environment variables (`POLYFENCE_ANALYTICS_ENABLED`) can still override runtime config
  - Comprehensive telemetry documentation added: `docs/TELEMETRY.md`

### Added
- **New `disableTelemetry` parameter** in `AnalyticsConfig` for simple opt-out
- **Smart disclosure message** that informs developers about telemetry:
  - Shows once per install
  - Shows again if telemetry state changes (enabled/disabled toggled)
  - Only in debug builds (production logs stay clean)
  - Uses SharedPreferences to track disclosure state
- **Complete telemetry reference**: `docs/TELEMETRY.md` with field-by-field payload breakdown
- **Stakeholder review document**: `SIMPLE_TERMS_TELEMETRY.md` for non-technical review

### Breaking Changes
- **Telemetry is now enabled by default** (previously opt-in only)
  - Anonymous plugin performance metrics are sent automatically
  - No location data or PII is ever transmitted
  - To disable: pass `analyticsConfig: AnalyticsConfig(disableTelemetry: true)` to `initialize()`
- Old approach: `AnalyticsConfig(enabled: false)` (opt-in, required API key)
- New approach: Enabled by default, opt-out with `disableTelemetry: true`, no API key required

### Migration Guide
- **No action needed** if you're okay with anonymous telemetry (recommended)
- **To opt-out**: Add `analyticsConfig: AnalyticsConfig(disableTelemetry: true)` to your `initialize()` call
- **See full details**: Read `docs/TELEMETRY.md` to understand exactly what's sent

### Privacy Commitment
- **What's sent**: Plugin version, platform, app package name, performance metrics (detection times, GPS accuracy, battery usage), error counts, zone type usage (circle/polygon counts)
- **What's NEVER sent**: GPS coordinates, location data, zone definitions, user identifiers, personal information
- **Data retention**: 24 months (2 years) for trend analysis and product improvement
- **Full transparency**: See `docs/TELEMETRY.md` for complete payload reference

## [0.2.5] - 2025-12-26

### Fixed
- **Automatic version syncing from single source of truth**
  - Plugin version now automatically synced from `pubspec.yaml` (single source of truth)
  - Version passed from Flutter to native platforms during `initialize()`
  - Removed all hardcoded versions from Android and iOS debug collectors
  - Native code now uses version received from Flutter (no hardcoding)
  - Example app version automatically synced with plugin version via `scripts/sync_version.sh`
  - All version references now come from `pubspec.yaml` or Flutter
  - Fixes issue where native code had outdated hardcoded versions (1.0.0, 0.1.0, 0.2.4)

### Added
- `scripts/sync_version.sh` - Script to sync plugin version across all files
- `scripts/README.md` - Documentation for version synchronization system

## [0.2.4] - 2025-12-26

### Changed
- **Plugin-level analytics decision making**
  - Plugin is now the sole master decider for analytics sending
  - Plugin checks environment variables (`POLYFENCE_ANALYTICS_ENABLED`, `POLYFENCE_API_KEY`, `POLYFENCE_API_ENDPOINT`) at build time
  - Apps no longer control analytics sending - plugin's decision cannot be overridden
  - Apps can still provide metadata (`industryCategory`, `useCase`) but cannot control `enabled`/`apiKey`/`apiEndpoint`
  - Enables plugin-level configuration without requiring app code changes
  - Build with: `--dart-define=POLYFENCE_ANALYTICS_ENABLED=true --dart-define=POLYFENCE_API_KEY=your_key`

### Breaking Changes
- Apps passing `analyticsConfig(enabled: true)` will have their `enabled` setting ignored
- Plugin now uses environment variables for analytics configuration instead of app-provided config
- Apps should remove `analyticsConfig` parameter from `initialize()` calls

## [0.2.3] - 2025-12-26

### Changed
- **Centralized error reporting**
  - Replaced direct `PolyfencePlugin.sendError()` calls with `PolyfenceErrorManager.reportError()`
  - Cleaner API: error manager handles timestamp and correlationId automatically
  - Applied to permission_revoked and wake_lock_timeout error reporting
  - Improves code organization and maintainability

## [0.2.2] - 2025-12-26

### Changed
- **Analytics data collection now automatic**
  - Analytics always initializes and collects data automatically (no app configuration needed)
  - Apps no longer need to pass `analyticsConfig` for data collection
  - Plugin automatically records analytics when geofence events occur
  - Plugin controls sending: only sends to API if `enabled: true` in config (opt-in)
  - Apps can still opt-in to sending by passing `analyticsConfig(enabled: true)`
  - Privacy-first: data collected but not sent unless explicitly opted-in

### Fixed
- Fixed analytics initialization to always occur (even without config)
- Fixed analytics data collection to work automatically without app-level gates
- Apps now automatically collect and pass analytics data to plugin

## [0.2.1] - 2025-12-26

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
- **Security: Wake lock timeout (Finding 2.2 - HIGH severity)**
  - Added 12-hour timeout to wake lock with auto-renewal for continued tracking
  - Added `onTaskRemoved()` handler for defensive cleanup when app is removed
  - Added health check monitor to detect and handle zombie wake locks
  - Prevents battery drain from indefinite wake lock holds
- **Security: Memory leak fixes (Finding 2.1 - HIGH severity)**
  - Added comprehensive resource cleanup in `dispose()` method
  - Added `_statusController.close()` to prevent stream controller leaks
  - Added analytics session cleanup and app lifecycle manager disposal
  - Added platform disposal method for complete resource cleanup
  - Prevents memory leaks when apps repeatedly initialize/dispose the plugin
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

