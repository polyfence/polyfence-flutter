# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Bridge platform telemetry** — Plugin sets `bridge_platform: "flutter"` on native core during initialization. Identifies Flutter sessions in analytics, distinguishing from future React Native sessions.
- **Health score stream** — `healthScoreStream` getter on `PolyfenceService` filters `performanceStream` for health score events. New `HealthScore` model.
- **Debug overlay widget** — `PolyfenceDebugOverlay` draggable widget showing real-time health metrics. Only renders in debug builds.

### Fixed
- **polyfence-core dependency bumped to 1.0.2** — Plugin calls `setBridgePlatform()` which was added in core 1.0.2. Previously declared 1.0.0, causing build failures for consumers.
- **Telemetry defaults, retry queue, and platform timeouts** — Audit findings resolved: telemetry field defaults corrected, retry queue backoff improved, platform-specific timeouts tuned.
- **Analytics config consolidation** — `AnalyticsConfig` unified with typed `initialize()` method. Migration guide added.
- **Haversine bounds and polygon test vectors** — Corrected edge-case calculations in `geofence_algorithms_test`.
- **Debug overlay nested accessors** — Updated to use `PolyfenceDebugInfo` nested objects (`info.zones.activeZones`, `info.performance.totalZoneDetections`).
- **Android build.gradle version alignment** — Was `1.0-SNAPSHOT`, now matches pubspec `0.13.0`.
- **Example app namespace** — Renamed from `io.polyfence` to `io.polyfence.example` to avoid collision with the plugin package.

### Changed
- **CI restructured** — Quality checks moved to local pre-push hook. CI slimmed to analyze + test only.
- **Contact emails consolidated** — All repo emails standardised to `hello@polyfence.io`.
- **Documentation updates** — Platform versions corrected (iOS 14.0+, Android API 24+), stale links fixed, TELEMETRY.md trimmed to pure field reference.

## [0.13.0] - 2026-03-19

### Breaking Changes
- **Android namespace changed** — Package namespace changed from `com.polyfence` to
  `io.polyfence`. Apps must update their dependency coordinates and any explicit
  references to the old namespace.

### Changed
- **Native core extracted to polyfence-core** — All native geofencing logic (25 files)
  extracted to a separate `polyfence-core` library, consumed as a CocoaPod (iOS) and
  Maven dependency (Android). The plugin is now a thin Flutter bridge over the core.
- **Telemetry aggregation moved to native (D016)** — Session telemetry is now aggregated
  on the native side. Dart `AnalyticsService` simplified from 592 to 231 lines and now
  handles HTTP POST only.
- **Telemetry remains opt-out** — Enabled by default; disable with
  `AnalyticsConfig(disableTelemetry: true)`. No change in behavior.

### Removed
- **`battery_plus` dependency** — Battery level tracking moved to native core. One fewer
  third-party dependency for consumers.
- **25 native source files** — Moved to `polyfence-core` repository. No longer shipped
  inside the plugin package.

### Repository
- Repo renamed from `polyfence-plugin` to `polyfence-flutter`.

## [0.12.4] - 2026-03-09

### Fixed
- **Samsung background survival** — Removed self-destructing `onTaskRemoved()`
  that killed the foreground service when Samsung swiped the app from recents.
  Service now continues tracking after task removal.
- **Notification importance** — Upgraded tracking notification from
  `IMPORTANCE_LOW` to `IMPORTANCE_DEFAULT` so Samsung treats the service as
  essential. Notification remains silent (no sound).
- **Boot/update tracking restart** — `ScheduleReceiver` now restarts continuous
  tracking after device reboot and app updates by checking persisted tracking
  state in SharedPreferences.

### Added
- `MY_PACKAGE_REPLACED` intent filter on `ScheduleReceiver` to restart tracking
  after app updates.
- `android:stopWithTask="false"` on `LocationTracker` service declaration for
  explicit OEM signaling.

## [0.12.3] - 2026-03-08

### Fixed
- **Native telemetry fields all null** — The Dart merge logic was looking for
  snake_case keys (`device_category`, `activity_distribution`, etc.) but native
  code returns camelCase (`deviceCategory`, `activityDistribution`). All 12
  native telemetry fields were silently dropped. Added proper camelCase →
  snake_case key mapping.

## [0.12.2] - 2026-03-08

### Fixed
- **iOS build failure** — Removed duplicate `getZoneCount()` declaration in
  `GeofenceEngine.swift` that caused Swift compile error. Same fix as v0.12.1
  for Android.

## [0.12.1] - 2026-03-08

### Fixed
- **Android build failure** — Removed duplicate `getZoneCount()` declaration in
  `GeofenceEngine.kt` that caused `compileReleaseKotlin` to fail. Kept the
  `@Synchronized` version for thread safety.

## [0.12.0] - 2026-03-07

### Added
- **Enhanced telemetry for ML training (21 new fields)** — Adds input context fields to the
  anonymous telemetry payload so ML models can correlate detection quality with conditions.
  - Config context: `accuracy_profile`, `update_strategy`
  - Per-event aggregates: `avg_speed_at_event_mps`, `boundary_events_count`
  - False event detection: `false_event_count` (enter/exit reversal within 30s)
  - Native session context: `activity_distribution`, `gps_interval_distribution`,
    `stationary_ratio`, `avg_gps_interval_ms`, `zone_count`, `zone_size_distribution`,
    `zone_transition_count`, `dwell_durations_minutes`
  - Dwell aggregates: `avg_dwell_duration_minutes`, `max_dwell_duration_minutes`
  - Device context: `device_category`, `os_version_major`, `charging_during_session`
  - Battery levels: `battery_level_start`, `battery_level_end`
- **`getSessionTelemetry` platform method** — New MethodChannel call aggregates telemetry
  from native ActivityRecognitionManager, LocationTracker, and GeofenceEngine.
- **Polygon boundary distance (iOS)** — Implements point-to-segment distance for polygon zones
  (Android already had this; iOS was missing it).
- **Enhanced telemetry tests** — Validates all 21 new fields, graceful degradation with legacy
  events, native telemetry merge, and dwell aggregate computation.

### Changed
- **iOS geofence callback** — Migrated from 7 positional parameters to a dictionary-based
  callback for extensibility (`[String: Any]`).

### Privacy
- No new fields contain GPS coordinates, zone definitions, or user identifiers.
- `disableTelemetry: true` still disables everything including new fields.
- See `doc/TELEMETRY.md` for complete field-by-field documentation.

## [0.11.3] - 2026-02-28

### Fixed
- **Android: use actual location provider check for isLocationServiceEnabled** — Uses
  `LocationManager.isProviderEnabled()` with try/catch instead of previous check.
- **Android: reapply SmartGpsConfig after GPS restart recovery** — After GPS recovery,
  `updateLocationRequest()` is now called so the correct config is reapplied.

### Added
- **Algorithm parity reference vectors** — Test vectors for Kotlin/Swift parity validation.
- **_handleGeofenceEvent unit tests** — Comprehensive tests for geofence event handling.
- **Lifecycle edge case tests** — Tests for start/stop/restart behavior.
- **Geofence algorithms test improvements** — Shared helper, stronger expectations, edge cases.

## [0.11.2] - 2026-02-25

### Fixed
- **iOS podspec: add CoreMotion framework dependency** — `ActivityRecognitionManager.swift` imports
  `CoreMotion` but the podspec only declared `CoreLocation, UserNotifications`. In release builds
  with link-time optimization, the framework could fail to link correctly. Now explicitly declared
  as `CoreLocation, CoreMotion, UserNotifications`.

## [0.11.1] - 2026-02-25

### Fixed
- **iOS compilation: `ZoneData.name` → `ZoneData.zoneName`** — Cluster zone activation log
  referenced non-existent `name` property on iOS `ZoneData` (property is `zoneName`).
  Android `ZoneData` uses `name`, causing the iOS parity mismatch.
- **iOS compilation: duplicate `currentTime` declaration** — `emitRuntimeStatus()` declared
  `let currentTime` twice in the same scope. Removed redundant re-declaration, reusing the
  existing variable from the function's outer scope (matching Android pattern).

## [0.11.0] - 2026-02-25

### Fixed
- **Stationary detection decoupled from movementSettings** — `isStationary` was permanently `false`
  when `movementSettings` was null (the default). Now always computed using sensible defaults
  (50m threshold, 5min timeout), independent of whether movementSettings is provided.
- **Self-referencing distance bug in updateMovementState()** — Distance was computed as
  `lastKnownLocation.distanceTo(lastKnownLocation)` (always 0) due to updating the reference
  before computing distance. Introduced `lastMovementLocation` for correct tracking.
- **Proximity hierarchy in INTELLIGENT strategy** — `calculateIntelligentInterval()` no longer
  returns fast 5s interval unconditionally when near a zone. Now respects stationary state:
  near zone + stationary → 2min interval, near zone + moving → fast proximity interval.

### Changed
- **Default `accuracyProfile` aligned with native platforms** — Dart default changed from
  `maxAccuracy` (5s interval, 0m filter) to `balanced` (10s interval, 10m+ filter), matching
  Android and iOS native SmartGpsConfig defaults. Prevents `toMap()` from silently overwriting
  native BALANCED with MAX_ACCURACY.

### Added
- **Diagnostic logging in example app** — LogBuffer ring buffer with disk persistence,
  battery/network tracking, and platform share export. Supports complete session export
  from disk file (not truncated at 5000-entry ring buffer limit).
- **SmartGPS INTELLIGENT strategy in example app** — Example now demonstrates recommended
  configuration: INTELLIGENT strategy with ProximitySettings, MovementSettings, BatterySettings,
  and ClusterSettings. iOS receives all config except activity settings (CoreMotion safety).

### Implementation Notes
- All engine fixes applied identically to Android (Kotlin) and iOS (Swift) for platform parity.
- Stationary detection changes are backward-compatible: apps providing movementSettings will
  use their custom values; apps without get sensible defaults.
- The default profile change is a **behavioral change** for apps creating `PolyfenceConfiguration()`
  without specifying `accuracyProfile` — they now get BALANCED instead of MAX_ACCURACY.

## [0.10.2] - 2026-02-18

### Added
- **GPS Health Monitoring in RuntimeStatus** — New metrics to detect GPS signal issues in real-time.
  - `currentGpsAccuracy` (double?) — Current GPS accuracy in meters, null if no fix available.
  - `secondsSinceLastGpsFix` (int) — Time elapsed since last valid GPS fix, increases when signal is lost.
  - `gpsAvailabilityDrops5Min` (int) — Count of GPS availability drops in the last 5 minutes, useful for detecting intermittent GPS issues.
  - Emitted via existing `onPerformanceEvent` stream with type `runtime_status`.
  - Enables apps to show "GPS signal lost" or "GPS unstable" banners to users.

- **`PolyfenceErrorType.gpsUnreliable` Error Event** — Automatically detects and reports unreliable GPS conditions.
  - Fires when GPS accuracy exceeds 150m (Android FLP feeding poor quality data during signal loss).
  - Fires when 3+ GPS availability drops occur within 5 minutes (frequent signal dropout).
  - Includes context: `drops5Min`, `accuracy`, `platform`, `timestamp`.
  - 60-second cooldown prevents error spam.
  - Available via existing `onError` stream — slots into existing error handlers without breaking changes.

- **Active Zone IDs in Cluster Logs** — Cluster refresh log messages now include zone names/IDs.
  - Android: `Cluster refreshed at (lat, lng): 11 of 29 zones active - [Signal Drive, Clifton, Hillmorton, ...]`
  - iOS: Same format for platform parity.
  - Invaluable for debugging which zones are included in active cluster.
  - Resolves blind spots where only counts were visible.

### Implementation Notes
- All changes are additive and non-breaking.
- GPS health metrics have sensible defaults in `fromMap()` (0 for counts, null for accuracy).
- Android and iOS implementations maintain platform parity for all features.
- Addresses GPS quality issues identified in live drive testing where Android FLP was feeding unreliable location data.

## [0.10.1] - 2026-02-17

### Added
- **`getZoneStates()` API** — Query the current INSIDE/OUTSIDE state for all monitored zones.
  - Returns `Map<String, bool>` where `true` = device is INSIDE, `false` = OUTSIDE.
  - Exposes the same persisted `GeofenceEngine` state used for `reconcileZoneStates` and `RECOVERY_ENTER`/`RECOVERY_EXIT` events.
  - Available via `Polyfence.instance.getZoneStates()`.
  - Useful for session management and state reconciliation in consumer apps.
  - Native implementations already existed on both platforms; this release adds the Dart bridge via MethodChannel.

## [0.10.0] - 2026-02-13

### Breaking Changes
- Renamed `updateGpsConfiguration()` to `updateConfiguration()`
- Renamed `gpsConfiguration()` to `getConfiguration()`
- Removed `getCurrentConfiguration()` from platform interface

### Added
- Coordinate validation on all Location and Zone constructors
- Configuration validation with descriptive error messages on all config classes
- Stream listener `onError` and `onDone` handlers on all internal streams
- Permission revocation detection and error reporting (Android + iOS)
- `kDebugMode` gating on all debug output (no debug strings in release builds)
- HTTPS validation on analytics endpoint
- Value equality (`==`, `hashCode`) on 21 model classes
- 324 unit tests (up from 16)
- `.pubignore` for clean pub.dev packaging (318KB)
- iOS 20-region limit note in README (Polyfence is not subject to this limit)

### Fixed
- Snake_case to camelCase normalization bug in `PolyfenceError.fromMap()` — all native error types were silently falling back to `unknown` since v0.1.0
- `PolygonSimplifier` Newton-Raphson sqrt precision error on small values — replaced with `dart:math`
- `debugPrint` not stripped in release builds — now gated behind `kDebugMode`
- 4 configuration validation bugs (negative radius, invalid coordinates, zero intervals, null nested maps)
- `AppLifecycleManager` incorrectly bundled inside analytics try-catch — now independent

### Changed
- Analytics service fully decoupled from core geofencing — analytics failures never block tracking
- `AppLifecycleManager` has its own availability flag and independent dispose
- `SessionMetrics` made private (`_SessionMetrics`)
- README restructured from 1384 to 749 lines — no content lost, all duplication removed
- Documentation sweep across all .md files for stale references

### Removed
- Dead `getCurrentConfiguration` platform channel handler (Kotlin + Swift)
- Unused stopwatch in `PolyfenceService`

## [0.9.0] - 2026-02-07

### Added
- **Activity Recognition** - Automatically detect user activity (still, walking, running, cycling, driving) and optimize GPS intervals accordingly
  - Android: Uses `ActivityRecognitionClient` from Google Play Services
  - iOS: Uses `CMMotionActivityManager` from CoreMotion
  - Configurable confidence threshold (default: 75%) and debounce time (default: 30s)
  - Custom GPS intervals per activity type (still: 120s, walking: 15s, driving: 5s, etc.)
  - Activity type included in location updates (`PolyfenceLocation.activity`)
  - Opt-in feature requiring additional permissions (`ACTIVITY_RECOGNITION` on Android, `NSMotionUsageDescription` on iOS)

- **Scheduled Tracking** - Automatically start/stop tracking based on time windows
  - Configure multiple time windows with start/end times
  - Filter by days of week (e.g., weekdays only)
  - Supports overnight windows (e.g., 22:00 - 06:00)
  - Schedule persists across app restarts and device reboots
  - Android uses AlarmManager for reliable wake-up at scheduled times

- **Dwell Detection** - Fire events when device remains in zone for configurable duration
  - Default threshold: 5 minutes
  - New `GeofenceEventType.dwell` event type
  - Useful for confirming presence rather than pass-through

- **Zone Clustering** - Performance optimization for large zone sets (100+ zones)
  - Only checks zones within configurable radius (default: 5km)
  - Refreshes active cluster after moving configurable distance (default: 1km)
  - Reduces CPU usage for apps with many geographically distributed zones

### Fixed
- **iOS Activity Recognition permission flow** - Permission prompt now correctly triggered by calling `startActivityUpdates()` when status is `.notDetermined`
- **Activity debounce timer bug** - Fixed issue where repeated detection of same activity was resetting the debounce timer instead of letting it complete
- **Android IntentReceiverLeaked error** - Fixed by stopping ActivityRecognitionManager in `onDestroy()`
- **Android background service start restriction** - Added pending activity settings storage for pre-tracking configuration on Android 12+

### Changed
- `PolyfenceLocation` model now includes optional `activity` field
- Location updates sent to Flutter now include current activity type

## [0.8.0] - 2026-01-25

### Added
- **Comprehensive battery drain optimizations** - Major improvements targeting Samsung and high-drain Android devices
  - **P1: Distance filter per profile** - GPS updates now filtered by movement distance (0m/10m/25m/10m for MAX_ACCURACY/BALANCED/BATTERY_OPTIMAL/ADAPTIVE)
  - **P4: Deferred GPS start** - GPS doesn't start until zones are registered, saving battery when no zones exist (Android & iOS)
  - **P5: Samsung/OEM device detection** - Detects Samsung, Xiaomi, Huawei, OPPO, Vivo, OnePlus devices with aggressive battery management
  - **P6: Consolidated health timers** - Reduced Android timers from 4 to 2 (combined 60s health check replaces separate GPS/permission checks)
  - **P7: Non-repeating fallback timer** - iOS fallback timer changed from 15s repeating to 30s non-repeating
  - **P9: Zone check throttling** - Skip geofence checks if device moved <5 meters (Android & iOS)
  - **P10: Profile-based wake lock duration** - Wake lock timeout tied to accuracy profile (4-12 hours based on profile)
  - **P11: Flutter callback throttling** - Throttle location callbacks to 30s when stationary (Android & iOS)

### Changed
- **P2: Default profile changed to BALANCED** - Both Android and iOS now default to BALANCED instead of MAX_ACCURACY for better battery life out of the box
- **P3: iOS pausesLocationUpdatesAutomatically** - Now respects profile configuration (enabled for BALANCED/BATTERY_OPTIMAL/ADAPTIVE)

### Performance
- Estimated 40-50% reduction in battery drain on Android devices
- Samsung Galaxy devices should see significant improvement due to distance filter + device detection
- iOS devices benefit from deferred GPS start, zone check throttling, and callback throttling

## [0.7.1] - 2026-01-23

### Fixed
- **Android config parsing bug** - `disableAlertNotifications` was not being read correctly
  - Android code was looking at top-level arguments instead of nested `config` map
  - iOS implementation was already correct
  - Thanks to Roadie team for the detailed bug report

## [0.7.0] - 2026-01-23

### Added
- **Configurable alert notifications** - New `disableAlertNotifications` config option
  - Apps can now suppress built-in "Entered Zone" / "Exited Zone" notifications
  - Enables custom notification implementations with app-specific context
  - Foreground service notification remains active for background GPS
  - Usage: `initialize(config: {'disableAlertNotifications': true})`

### Changed
- Alert notifications now respect `disableAlertNotifications` flag on both Android and iOS
- Defaults to `false` (notifications enabled) to maintain backward compatibility

## [0.6.0] - 2026-01-18

### Changed
- **Removed 50-point polygon limit**
  - Polygons can now have any number of points (previously limited to 50)
  - Enables support for complex Clean Air Zones (Birmingham: 2575 pts, Sheffield: 2216 pts, Tyneside: 169 pts, Portsmouth: 66 pts)
  - Server-side simplification using Douglas-Peucker algorithm handles large polygons automatically
  - No client-side performance impact for complex boundaries

### Added
- **PolygonSimplifier utility**
  - New `PolygonSimplifier` class with Douglas-Peucker algorithm for optional client-side polygon simplification
  - Useful for apps that want to reduce polygon complexity before sending to server
  - Tolerance-based simplification preserves polygon shape while reducing point count
  - Example: `PolygonSimplifier.simplify(points, tolerance: 0.0001)`

### Breaking Changes
- Apps that relied on the 50-point validation error will no longer receive errors for large polygons
- Update client code if you were catching `ArgumentError` for polygon point limits

## [0.5.0] - 2026-01-17

### Fixed
- **Android: Geofence events now include GPS coordinates**
  - Fixed bug where Android geofence events were missing `latitude` and `longitude` fields
  - iOS already included these fields, causing platform inconsistency
  - Apps syncing events to backend APIs can now access location data on both platforms
  - Resolves DEFECT-001 reported by Roadie mobile app team
  - Event payload now consistently includes GPS coordinates across both platforms

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
  - Comprehensive telemetry documentation added: `doc/TELEMETRY.md`

### Added
- **New `disableTelemetry` parameter** in `AnalyticsConfig` for simple opt-out
- **Smart disclosure message** that informs developers about telemetry:
  - Shows once per install
  - Shows again if telemetry state changes (enabled/disabled toggled)
  - Only in debug builds (production logs stay clean)
  - Uses SharedPreferences to track disclosure state
- **Complete telemetry reference**: `doc/TELEMETRY.md` with field-by-field payload breakdown
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
- **See full details**: Read `doc/TELEMETRY.md` to understand exactly what's sent

### Privacy Commitment
- **What's sent**: Plugin version, platform, app package name, performance metrics (detection times, GPS accuracy, battery usage), error counts, zone type usage (circle/polygon counts)
- **What's NEVER sent**: GPS coordinates, location data, zone definitions, user identifiers, personal information
- **Data retention**: 24 months (2 years) for trend analysis and product improvement
- **Full transparency**: See `doc/TELEMETRY.md` for complete payload reference

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
