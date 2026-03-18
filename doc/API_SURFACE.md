# Polyfence API Surface — v0.12.4

> **Purpose:** Catalog every public symbol exported from `lib/polyfence.dart` and evaluate cross-platform naming for Flutter, React Native, and future SDKs.

---

## Public Classes

| Class | Purpose | Multi-platform notes |
|-------|---------|---------------------|
| `Polyfence` | Static entry point; exposes `instance` getter for `PolyfenceService` | RN equivalent: `NativeModules.Polyfence` — works as-is |
| `PolyfenceService` | Singleton service — all geofencing operations | RN: methods become async native module methods. Stream properties become event subscriptions |
| `PolyfenceAnalytics` | Singleton analytics/telemetry service. Session aggregation handled by native polyfence-core; Dart fetches and POSTs. | Internal to plugin; not directly exposed in RN public API |
| `AnalyticsConfig` | Configuration for telemetry opt-in/out. **Telemetry is opt-in** (`enabled` defaults to `false`). | RN: plain object `{ enabled, disableTelemetry, apiKey, ... }` |
| `AppLifecycleManager` | Manages app lifecycle for telemetry upload on background transition. Session lifecycle managed by native polyfence-core. | Internal; no RN equivalent needed (RN has its own lifecycle handling) |
| `PolyfencePlatform` | Abstract platform interface | Internal; not exported to RN |
| `MethodChannelPolyfence` | Platform channel implementation | Internal; not exported to RN |
| `Zone` | Zone model (circle or polygon) | RN: TypeScript interface. Name is clean and platform-neutral |
| `GeofenceEvent` | Zone entry/exit/dwell event | RN: TypeScript interface. Clean name |
| `PolyfenceLocation` | GPS coordinate model | RN: TypeScript interface. See rename recommendations |
| `PolyfenceRuntimeStatus` | Runtime status snapshot | RN: TypeScript interface |
| `PolyfenceDebugInfo` | Comprehensive debug information | RN: TypeScript interface |
| `PolyfenceSystemStatus` | System/permission status | Nested in debug info |
| `PolyfencePerformanceMetrics` | Performance metrics | Nested in debug info |
| `PolyfenceBatteryMetrics` | Battery usage metrics | Nested in debug info |
| `PolyfenceZoneStatus` | Zone statistics | Nested in debug info |
| `PolyfenceErrorSummary` | Error summary for debug info | Nested in debug info |
| `PolyfenceError` | Structured error from native platform | RN: TypeScript interface |
| `PolyfenceException` | Abstract base exception | RN: errors are plain objects, not exception classes |
| `PolyfenceNotInitializedException` | Thrown before `initialize()` | RN: reject Promise with `{ code: 'NOT_INITIALIZED', message }` |
| `PlatformOperationException` | Thrown on platform errors | RN: reject Promise with `{ code: 'PLATFORM_ERROR', message, operation }` |
| `PolyfenceConfiguration` | GPS configuration model | RN: plain object. Clean name |
| `ProximitySettings` | Proximity-based GPS settings | RN: plain object |
| `MovementSettings` | Movement-based GPS settings | RN: plain object |
| `BatterySettings` | Battery-aware GPS settings | RN: plain object |
| `DwellSettings` | Dwell detection settings | RN: plain object |
| `ClusterSettings` | Zone clustering settings | RN: plain object |
| `ScheduleSettings` | Scheduled tracking settings | RN: plain object |
| `ActivitySettings` | Activity recognition settings | RN: plain object |
| `TimeOfDay` | Time representation for schedules | **Naming conflict**: Flutter has `material.TimeOfDay`. See rename recommendations |
| `TimeWindow` | Tracking time window | RN: plain object |
| `PolygonSimplifier` | Douglas-Peucker simplification | Utility; may not need RN export (server-side simplification) |

## Public Enums

| Enum | Values | Notes |
|------|--------|-------|
| `ZoneType` | `circle`, `polygon` | RN: string union `'circle' \| 'polygon'`. Clean |
| `GeofenceEventType` | `enter`, `exit`, `dwell`, `recoveryEnter`, `recoveryExit` | **Issue**: `recoveryEnter`/`recoveryExit` are camelCase in Dart but native sends `RECOVERY_ENTER`/`RECOVERY_EXIT`. RN doc proposes `recovery_enter`/`recovery_exit` (snake_case). See recommendations |
| `PolyfenceAccuracyProfile` | `maxAccuracy`, `balanced`, `batteryOptimal`, `adaptive` | RN: string union. Platform channel uses snake_case (`max_accuracy`, `battery_optimal`). Clean |
| `PolyfenceUpdateStrategy` | `continuous`, `proximityBased`, `movementBased`, `intelligent` | RN: string union. Platform channel uses snake_case. Clean |
| `PolyfenceErrorType` | `gpsTimeout`, `gpsPermissionDenied`, `gpsServiceDisabled`, `gpsAccuracyPoor`, `gpsUnreliable`, `serviceStartFailed`, `serviceKilled`, `serviceRestartFailed`, `batteryOptimizationRequired`, `lowBattery`, `zoneValidationFailed`, `zoneStorageFailed`, `zoneLoadFailed`, `networkTimeout`, `analyticsUploadFailed`, `permissionRevoked`, `memoryLow`, `unknown` | RN: string constants. Native uses snake_case; Dart uses camelCase. Conversion handled by `_snakeToCamel()` in `PolyfenceError.fromMap()` |
| `IndustryCategory` | `delivery`, `rideshare`, `retail`, `logistics`, `healthcare`, `fitness`, `social`, `gaming`, `travel`, `fieldService`, `security`, `education`, `realestate`, `agriculture`, `construction`, `events`, `financial`, `utilities`, `government`, `other` | RN: string values (`field_service`, `real_estate`, etc.). Each has `value`, `displayName`, `description` |
| `ActivityType` | `still`, `walking`, `running`, `cycling`, `driving`, `unknown` | RN: string union. Clean |

## PolyfenceService Methods

| Method | Signature | RN Equivalent | Notes |
|--------|-----------|---------------|-------|
| `initialize` | `Future<void> initialize({String? licenseKey, Map<String, dynamic>? config, AnalyticsConfig? analyticsConfig})` | `initialize(config?: object): Promise<void>` | `Future` → `Promise` is automatic. `AnalyticsConfig` flattened into config object for RN |
| `addZone` | `Future<void> addZone(Zone zone)` | `addZone(zone: Zone): Promise<void>` | Direct mapping |
| `removeZone` | `Future<void> removeZone(String zoneId)` | `removeZone(zoneId: string): Promise<void>` | Direct mapping |
| `clearAllZones` | `Future<void> clearAllZones()` | `clearAllZones(): Promise<void>` | Direct mapping |
| `startTracking` | `Future<void> startTracking()` | `startTracking(): Promise<void>` | Direct mapping |
| `stopTracking` | `Future<void> stopTracking()` | `stopTracking(): Promise<void>` | Direct mapping |
| `requestPermissions` | `Future<bool> requestPermissions({bool always = false})` | `requestPermissions(options?: { always?: boolean }): Promise<boolean>` | Named param → options object |
| `isLocationServiceEnabled` | `Future<bool> isLocationServiceEnabled()` | `isLocationServiceEnabled(): Promise<boolean>` | Direct mapping |
| `batteryOptimizationStatus` | `Future<Map<String, dynamic>> batteryOptimizationStatus()` | `batteryOptimizationStatus(): Promise<{ isOptimized: boolean, canRequest: boolean }>` | **Issue**: returns untyped `Map`. See recommendations |
| `requestBatteryOptimizationExemption` | `Future<bool> requestBatteryOptimizationExemption()` | `requestBatteryOptimizationExemption(): Promise<boolean>` | Direct mapping |
| `getConfiguration` | `Future<PolyfenceConfiguration> getConfiguration()` | `getConfiguration(): Promise<PolyfenceConfiguration>` | Direct mapping |
| `updateConfiguration` | `Future<void> updateConfiguration(PolyfenceConfiguration config)` | `updateConfiguration(config: PolyfenceConfiguration): Promise<void>` | Direct mapping |
| `resetConfiguration` | `Future<void> resetConfiguration()` | `resetConfiguration(): Promise<void>` | Direct mapping |
| `setAccuracyProfile` | `Future<void> setAccuracyProfile(PolyfenceAccuracyProfile profile)` | `setAccuracyProfile(profile: AccuracyProfile): Promise<void>` | Enum → string |
| `enableProximityOptimization` | `Future<void> enableProximityOptimization({double nearThreshold, double farThreshold})` | `enableProximityOptimization(options?: { nearThreshold?, farThreshold? }): Promise<void>` | Convenience wrapper |
| `enableMovementOptimization` | `Future<void> enableMovementOptimization({Duration stationaryThreshold, Duration stationaryUpdateInterval})` | `enableMovementOptimization(options?: { stationaryThresholdMs?, stationaryUpdateIntervalMs? }): Promise<void>` | **Issue**: `Duration` → milliseconds in RN |
| `enableIntelligentOptimization` | `Future<void> enableIntelligentOptimization()` | `enableIntelligentOptimization(): Promise<void>` | Direct mapping |
| `debugInfo` | `Future<PolyfenceDebugInfo> debugInfo()` | `getDebugInfo(): Promise<PolyfenceDebugInfo>` | **Issue**: `debugInfo()` vs `getDebugInfo()` — inconsistent with `getConfiguration()` pattern |
| `errorHistory` | `Future<List<PolyfenceErrorSummary>> errorHistory({Duration? timeRange, List<PolyfenceErrorType>? errorTypes})` | `getErrorHistory(options?: { timeRangeMs?, errorTypes? }): Promise<ErrorSummary[]>` | **Issue**: `errorHistory()` vs `getErrorHistory()` — missing `get` prefix |
| `getZoneStates` | `Future<Map<String, bool>> getZoneStates()` | `getZoneStates(): Promise<Record<string, boolean>>` | Direct mapping |
| `dispose` | `Future<void> dispose()` | `dispose(): Promise<void>` | Direct mapping |

### PolyfenceService Properties (Getters)

| Property | Type | RN Equivalent | Notes |
|----------|------|---------------|-------|
| `onGeofenceEvent` | `Stream<GeofenceEvent>` | `addListener('onGeofenceEvent', callback)` | Stream → event listener |
| `onZoneEnter` | `Stream<GeofenceEvent>` | `addListener('onZoneEnter', callback)` | Filtered stream; RN filters client-side |
| `onZoneExit` | `Stream<GeofenceEvent>` | `addListener('onZoneExit', callback)` | Filtered stream; RN filters client-side |
| `onLocationUpdate` | `Stream<PolyfenceLocation>` | `addListener('onLocation', callback)` | **Issue**: `onLocationUpdate` vs RN doc's `onLocation` — inconsistency |
| `onError` | `Stream<PolyfenceError>` | `addListener('onError', callback)` | Direct mapping |
| `runtimeStatus` | `Stream<PolyfenceRuntimeStatus>` | `addListener('onRuntimeStatus', callback)` | **Issue**: no `on` prefix unlike other streams |
| `statusStream` | `Stream<Map<String, dynamic>>` | N/A | Raw status; likely internal-only for RN |
| `performanceStream` | `Stream<PolyfencePerformanceMetrics>` | `addListener('onPerformance', callback)` | **Issue**: no `on` prefix; inconsistent with other stream properties |
| `zones` | `List<Zone>` | `getZones(): Promise<Zone[]>` | Sync getter → async in RN (must cross bridge) |
| `currentConfiguration` | `PolyfenceConfiguration` | `getCurrentConfiguration(): Promise<PolyfenceConfiguration>` | Sync getter → async in RN |

## Configuration Model — PolyfenceConfiguration

| Property | Type | Default | Notes |
|----------|------|---------|-------|
| `accuracyProfile` | `PolyfenceAccuracyProfile` | `balanced` | Serialized as snake_case string |
| `updateStrategy` | `PolyfenceUpdateStrategy` | `continuous` | Serialized as snake_case string |
| `proximitySettings` | `ProximitySettings?` | `null` | Nested config object |
| `movementSettings` | `MovementSettings?` | `null` | Nested config object |
| `batterySettings` | `BatterySettings?` | `null` | Nested config object |
| `dwellSettings` | `DwellSettings?` | `null` | Nested config object |
| `clusterSettings` | `ClusterSettings?` | `null` | Nested config object |
| `scheduleSettings` | `ScheduleSettings?` | `null` | Nested config object |
| `activitySettings` | `ActivitySettings?` | `null` | Nested config object |
| `gpsAccuracyThreshold` | `double` | `100.0` | Meters |
| `enableDebugLogging` | `bool` | `false` | |

## Event Model — GeofenceEvent

| Field | Type | JSON Key | Notes |
|-------|------|----------|-------|
| `zoneId` | `String` | `zoneId` | Required |
| `type` | `GeofenceEventType` | `type` | Serialized as enum name string |
| `location` | `PolyfenceLocation` | `location` | Nested object |
| `timestamp` | `DateTime` | `timestamp` | Milliseconds since epoch |
| `zone` | `Zone?` | `zone` | Optional; may be null if zone removed |

**Native geofence channel event format** (different from GeofenceEvent.toJson):

| Field | Type | Notes |
|-------|------|-------|
| `zoneId` | String | Required |
| `zoneName` | String | Zone display name |
| `eventType` | String | `ENTER`, `EXIT`, `DWELL`, `RECOVERY_ENTER`, `RECOVERY_EXIT` |
| `timestamp` | int64 | Milliseconds since epoch |
| `latitude` | double | Event location |
| `longitude` | double | Event location |
| `detectionTimeMs` | double | Time to detect zone crossing |
| `gpsAccuracy` | double | GPS accuracy at event |
| `speedMps` | double | Speed at event (m/s) |
| `activityAtEvent` | String | Activity type at event |
| `distanceToBoundaryM` | double | Distance to zone boundary |

## Zone Model

| Field | Type | JSON Key | Notes |
|-------|------|----------|-------|
| `id` | `String` | `id` | Required, non-empty |
| `name` | `String` | `name` | Required, non-empty |
| `type` | `ZoneType` | `type` | `circle` or `polygon` |
| `center` | `PolyfenceLocation?` | `center` | Required for circle zones |
| `radius` | `double?` | `radius` | Required for circle zones; must be > 0 |
| `polygon` | `List<PolyfenceLocation>?` | `polygon` | Required for polygon zones; min 3 points |
| `metadata` | `Map<String, dynamic>?` | `metadata` | Optional key-value pairs |

## Location Model — PolyfenceLocation

| Field | Type | JSON Key | Notes |
|-------|------|----------|-------|
| `latitude` | `double` | `latitude` | -90 to 90, required |
| `longitude` | `double` | `longitude` | -180 to 180, required |
| `altitude` | `double?` | `altitude` | Meters above sea level |
| `accuracy` | `double?` | `accuracy` | Horizontal accuracy in meters |
| `timestamp` | `DateTime?` | `timestamp` | Milliseconds since epoch |
| `speed` | `double?` | `speed` | Meters per second |
| `interval` | `int?` | `interval` | GPS update interval in ms |
| `isFallback` | `bool` | `isFallback` | True if coords defaulted to 0.0 |
| `activity` | `String?` | `activity` | Activity type string |

## Error Hierarchy

| Error Class | Code | Message Pattern | Notes |
|------------|------|-----------------|-------|
| `PolyfenceException` | (abstract) | `PolyfenceException: {message}` | Base class |
| `PolyfenceNotInitializedException` | `NOT_INITIALIZED` | `Polyfence not initialized. Call Polyfence.instance.initialize() first.` | |
| `PlatformOperationException` | `PLATFORM_ERROR` | `Platform operation "{operation}" failed: {message}` | Includes `operation`, `details`, `innerException`, `stackTrace` |

## Error Types (PolyfenceErrorType)

| Error Type | Category | Description |
|-----------|----------|-------------|
| `gpsTimeout` | GPS | Location request timed out |
| `gpsPermissionDenied` | GPS | Permission denied by user |
| `gpsServiceDisabled` | GPS | Device location services disabled |
| `gpsAccuracyPoor` | GPS | Accuracy below threshold |
| `gpsUnreliable` | GPS | Frequent dropouts/accuracy swings |
| `serviceStartFailed` | Service | Background service failed to start |
| `serviceKilled` | Service | Background service killed by system |
| `serviceRestartFailed` | Service | Service restart failed |
| `batteryOptimizationRequired` | Battery | Battery optimization preventing tracking |
| `lowBattery` | Battery | Critically low battery |
| `zoneValidationFailed` | Zone | Invalid zone definition |
| `zoneStorageFailed` | Zone | Failed to save zone |
| `zoneLoadFailed` | Zone | Failed to load zones |
| `networkTimeout` | Network | Network request timed out |
| `analyticsUploadFailed` | Network | Analytics upload failed |
| `permissionRevoked` | System | Permission revoked while tracking |
| `memoryLow` | System | Device low on memory |
| `unknown` | System | Unclassified error |

## Analytics Model — AnalyticsConfig

| Property | Type | Default | Notes |
|----------|------|---------|-------|
| `enabled` | `bool` | `false` | Whether analytics is enabled (opt-in) |
| `disableTelemetry` | `bool` | `true` | Explicit opt-out flag (redundant with `enabled`, see R7) |
| `industryCategory` | `String?` | `null` | From IndustryCategory enum values |
| `useCase` | `String?` | `null` | Custom use-case string |
| `apiEndpoint` | `String?` | `null` | Must be HTTPS |
| `apiKey` | `String?` | `null` | For Polyfence.io dashboard |

## Telemetry Session Payload (snake_case JSON)

> **Note:** Session telemetry aggregation is handled entirely by native polyfence-core
> (TelemetryAggregator). The Dart layer fetches the aggregated payload via
> `getSessionTelemetry` platform channel and POSTs it to the analytics endpoint.

| Field | Type | Notes |
|-------|------|-------|
| `app_identifier` | string | Package name |
| `platform` | string | `android` or `ios` |
| `plugin_version` | string | e.g., `0.12.4` |
| `industry_category` | string? | Optional |
| `use_case` | string? | Optional |
| `detections_total` | int | Total zone detections |
| `detection_time_avg_ms` | float? | Mean detection time |
| `detection_time_p95_ms` | float? | 95th percentile |
| `gps_accuracy_avg_m` | float? | Mean GPS accuracy |
| `battery_drain_avg_pct_per_hr` | float? | Estimated drain rate |
| `session_duration_minutes` | int? | Session length |
| `zone_usage` | object | `{ "circle": N, "polygon": N }` |
| `error_counts` | object | `{ "error_type": N, ... }` |
| `ttfd_ms` | int? | Time to first detection |
| `had_detection` | bool | Any detection occurred |
| `service_interruptions` | int | Background service restarts |
| `gps_ok_ratio` | float? | Good GPS readings ratio |
| `sample_events` | int | Total events sampled |
| `accuracy_profile` | string? | Config profile name |
| `update_strategy` | string? | Config strategy name |
| `avg_speed_at_event_mps` | float? | Mean speed at events |
| `boundary_events_count` | int | Events within 50m of boundary |
| `false_event_count` | int | Enter→exit reversals within 30s |
| `battery_level_start` | float? | Battery at session start |
| `battery_level_end` | float? | Battery at session end |
| `avg_dwell_duration_minutes` | float? | From native telemetry |
| `max_dwell_duration_minutes` | float? | From native telemetry |
| `activity_distribution` | object? | From native telemetry |
| `gps_interval_distribution` | object? | From native telemetry |
| `stationary_ratio` | float? | From native telemetry |
| `avg_gps_interval_ms` | int? | From native telemetry |
| `zone_count` | int? | From native telemetry |
| `zone_size_distribution` | object? | From native telemetry |
| `zone_transition_count` | int? | From native telemetry |
| `dwell_durations_minutes` | array? | From native telemetry |
| `device_category` | string? | From native telemetry |
| `os_version_major` | int? | From native telemetry |
| `charging_during_session` | bool? | From native telemetry |
