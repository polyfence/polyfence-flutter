# Platform Channel Contract — v0.12.4

> **Purpose:** Definitive specification of the platform channel contract between Dart and native (Android/iOS). Any changes to this contract require updating both native implementations and this document.

---

## Channel Overview

| Channel | Type | Name | Purpose |
|---------|------|------|---------|
| Primary | MethodChannel | `polyfence` | All request/response operations |
| Location | EventChannel | `polyfence/location` | GPS location updates |
| Geofence | EventChannel | `polyfence/geofence` | Zone entry/exit/dwell events |
| Error | EventChannel | `polyfence/error` | Structured error events |
| Performance | EventChannel | `polyfence/performance` | Runtime status and performance metrics |

---

## MethodChannel: `polyfence`

### Lifecycle Methods

#### `initialize`

| | |
|---|---|
| **Direction** | Dart → Native |
| **Arguments** | `{ licenseKey: String?, config: { pluginVersion: String?, disableAlertNotifications: bool?, ...custom } }` |
| **Returns** | `null` (void) |
| **Errors** | PlatformException on initialization failure |

#### `dispose`

| | |
|---|---|
| **Direction** | Dart → Native |
| **Arguments** | none |
| **Returns** | `null` (void) |
| **Notes** | Dart-side only — resets stream references. No native method call. |

### Tracking Methods

#### `startTracking`

| | |
|---|---|
| **Direction** | Dart → Native |
| **Arguments** | none |
| **Returns** | `null` (void) |
| **Errors** | PlatformException if service fails to start |

#### `stopTracking`

| | |
|---|---|
| **Direction** | Dart → Native |
| **Arguments** | none |
| **Returns** | `null` (void) |
| **Errors** | PlatformException on failure |

### Zone Management Methods

#### `addZone`

| | |
|---|---|
| **Direction** | Dart → Native |
| **Arguments** | Zone JSON map: `{ id: String, name: String, type: String("circle"\|"polygon"), center: { latitude: double, longitude: double }?, radius: double?, polygon: [{ latitude: double, longitude: double }, ...]?, metadata: Map? }` |
| **Returns** | `null` (void) |
| **Errors** | PlatformException on validation or storage failure |

#### `removeZone`

| | |
|---|---|
| **Direction** | Dart → Native |
| **Arguments** | `{ zoneId: String }` |
| **Returns** | `null` (void) |
| **Errors** | PlatformException if zone not found or storage failure |

#### `clearAllZones`

| | |
|---|---|
| **Direction** | Dart → Native |
| **Arguments** | none |
| **Returns** | `null` (void) |

#### `getCurrentZoneStates`

| | |
|---|---|
| **Direction** | Dart → Native |
| **Arguments** | none |
| **Returns** | `Map<String, bool>` — zone ID → `true` (inside) / `false` (outside) |
| **Notes** | Returns persisted engine state, not a fresh GPS check |

### Permission Methods

#### `requestPermissions`

| | |
|---|---|
| **Direction** | Dart → Native |
| **Arguments** | `{ always: bool }` (Android only; iOS ignores) |
| **Returns** | `bool` — `true` if granted |
| **Platform diff** | Android: respects `always` param. iOS: always requests "Always" permission |

#### `isLocationServiceEnabled`

| | |
|---|---|
| **Direction** | Dart → Native |
| **Arguments** | none |
| **Returns** | `bool` — `true` if device location services are on |

### Configuration Methods

#### `getConfiguration`

| | |
|---|---|
| **Direction** | Dart → Native |
| **Arguments** | none |
| **Returns** | `Map<String, dynamic>` — SmartGpsConfig serialized |
| **Schema** | `{ accuracyProfile: String, updateStrategy: String, gpsAccuracyThreshold: double, enableDebugLogging: bool, proximitySettings: Map?, movementSettings: Map?, batterySettings: Map?, dwellSettings: Map?, clusterSettings: Map?, scheduleSettings: Map?, activitySettings: Map? }` |

#### `updateConfiguration`

| | |
|---|---|
| **Direction** | Dart → Native |
| **Arguments** | Configuration map (same schema as `getConfiguration` return) |
| **Returns** | `null` (void) |

#### `resetConfiguration`

| | |
|---|---|
| **Direction** | Dart → Native |
| **Arguments** | none |
| **Returns** | `null` (void) |
| **Notes** | Restores platform defaults |

#### `setAccuracyProfile`

| | |
|---|---|
| **Direction** | Dart → Native |
| **Arguments** | `String` — profile name in snake_case (`max_accuracy`, `balanced`, `battery_optimal`, `adaptive`) |
| **Returns** | `null` (void) |

### Battery Methods (Android-specific)

#### `checkBatteryOptimization`

| | |
|---|---|
| **Direction** | Dart → Native |
| **Arguments** | none |
| **Returns** | `{ isOptimized: bool, canRequest: bool }` |
| **Platform diff** | iOS: no equivalent; returns fixed values in debug info |

#### `requestBatteryOptimization`

| | |
|---|---|
| **Direction** | Dart → Native |
| **Arguments** | none |
| **Returns** | `bool` — `true` if user granted exemption |
| **Platform diff** | iOS: no-op, always returns `true` |
| **Note** | Method name is `requestBatteryOptimization` on channel, but Dart exposes as `requestBatteryOptimizationExemption()` |

### Debug Methods

#### `getDebugInfo`

| | |
|---|---|
| **Direction** | Dart → Native |
| **Arguments** | none |
| **Returns** | Nested map with structure: |

```
{
  systemStatus: {
    isLocationPermissionGranted: bool,
    isBackgroundLocationEnabled: bool,
    isBatteryOptimizationDisabled: bool,
    isGpsEnabled: bool,
    isWakeLockAcquired: bool,
    lastKnownAccuracy: double,
    lastLocationUpdate: int (ms epoch),
    platformVersion: String,
    pluginVersion: String
  },
  performance: {
    uptime: int (ms),
    totalLocationUpdates: int,
    totalZoneDetections: int,
    averageDetectionLatency: double,
    memoryUsageMB: int,
    cpuUsagePercent: double,
    restartCount: int
  },
  battery: {
    estimatedHourlyDrain: double,
    gpsActiveTimePercent: int,
    wakeUpCount: int,
    isCharging: bool,
    batteryLevel: int,
    totalActiveTime: int (ms)
  },
  zones: {
    activeZones: int,
    circleZones: int,
    polygonZones: int,
    lastZoneUpdate: int (ms epoch),
    zoneEventCounts: Map<String, int>
  },
  recentErrors: [
    {
      type: String,
      message: String,
      timestamp: int (ms epoch),
      correlationId: String?,
      context: Map
    }
  ]
}
```

#### `getErrorHistory`

| | |
|---|---|
| **Direction** | Dart → Native |
| **Arguments** | `{ timeRangeMs: int?, errorTypes: List<String>? }` |
| **Returns** | `List<Map>` — error summaries |
| **Platform diff** | Android: full implementation. iOS: returns empty array (stub) |

### Telemetry Methods

#### `getSessionTelemetry`

| | |
|---|---|
| **Direction** | Dart → Native |
| **Arguments** | none |
| **Returns** | Native session telemetry map (camelCase keys): |

```
{
  activityDistribution: Map<String, double>,
  gpsIntervalDistribution: Map<String, double>,
  stationaryRatio: double,
  avgGpsIntervalMs: int,
  zoneCount: int,
  zoneSizeDistribution: Map<String, int>,
  zoneTransitionCount: int,
  dwellDurationsMinutes: List<double>,
  deviceCategory: String,
  osVersionMajor: int,
  chargingDuringSession: bool,
  falseEventCount: int
}
```

| **Notes** | Keys are camelCase from native; Dart maps to snake_case for API payload |

---

## EventChannel: `polyfence/location`

| | |
|---|---|
| **Listen argument** | `"location"` |
| **Event format** | `Map<String, dynamic>` |

### Event Schema

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `latitude` | `double` | Yes | -90 to 90 |
| `longitude` | `double` | Yes | -180 to 180 |
| `altitude` | `double?` | No | Meters above sea level |
| `accuracy` | `double?` | No | Horizontal accuracy in meters |
| `timestamp` | `int?` | No | Milliseconds since epoch |
| `speed` | `double?` | No | Meters per second |
| `interval` | `int?` | No | GPS update interval in ms |
| `isFallback` | `bool?` | No | True if coords defaulted to 0.0 |
| `activity` | `String?` | No | Activity type string |

---

## EventChannel: `polyfence/geofence`

| | |
|---|---|
| **Listen argument** | `"geofence"` |
| **Event format** | `Map<String, dynamic>` |

### Event Schema

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `zoneId` | `String` | Yes | Zone identifier |
| `zoneName` | `String` | Yes | Zone display name |
| `eventType` | `String` | Yes | `ENTER`, `EXIT`, `DWELL`, `RECOVERY_ENTER`, `RECOVERY_EXIT` |
| `timestamp` | `int64` | Yes | Milliseconds since epoch |
| `latitude` | `double` | Yes | Event location latitude |
| `longitude` | `double` | Yes | Event location longitude |
| `detectionTimeMs` | `double` | No | Time to detect zone crossing |
| `gpsAccuracy` | `double` | No | GPS accuracy at event time |
| `speedMps` | `double` | No | Speed in meters/second |
| `activityAtEvent` | `String` | No | Activity type at event |
| `distanceToBoundaryM` | `double` | No | Distance to zone boundary |

**Event type values are UPPER_SNAKE_CASE from native, mapped to camelCase enums in Dart.**

---

## EventChannel: `polyfence/error`

| | |
|---|---|
| **Listen argument** | `"error"` |
| **Event format** | `Map<String, dynamic>` |

### Event Schema

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `type` | `String` | Yes | Error type in snake_case (e.g., `gps_timeout`, `permission_revoked`) |
| `message` | `String` | Yes | Human-readable error message |
| `context` | `Map<String, dynamic>` | No | Additional error context |
| `timestamp` | `int` | Yes | Milliseconds since epoch |
| `correlationId` | `String?` | No | For tracking related errors |

**Error type strings are snake_case from native, converted to camelCase enum values in Dart via `_snakeToCamel()`.**

---

## EventChannel: `polyfence/performance`

| | |
|---|---|
| **Listen argument** | `"performance"` |
| **Event format** | `Map<String, dynamic>` |

### Event Schema — Status Updates

| Field | Type | Notes |
|-------|------|-------|
| `type` | `String` | `"status"` or `"runtime_status"` |
| `trackingEnabled` | `bool` | Whether tracking is active |
| `zonesCount` | `int` | Number of monitored zones |
| `timestamp` | `int` | Milliseconds since epoch |

### Event Schema — Runtime Status (nested in `data` key)

| Field | Type | Notes |
|-------|------|-------|
| `intervalMs` | `int` | Current GPS update interval |
| `nearestZoneDistanceM` | `double` | Distance to nearest zone |
| `currentGpsAccuracy` | `double?` | Current GPS accuracy |
| `secondsSinceLastGpsFix` | `int` | Time since last GPS fix |
| `gpsAvailabilityDrops5Min` | `int` | GPS dropout count (5 min window) |
| `timestamp` | `int` | Milliseconds since epoch |

---

## Platform Differences Summary

| Aspect | Android | iOS |
|--------|---------|-----|
| `requestPermissions` args | `{ always: bool }` used | `{ always: bool }` parameter ignored; always requests "Always" |
| `checkBatteryOptimization` | Full implementation | Not implemented (battery optimization is an Android concept) |
| `requestBatteryOptimization` | Opens system dialog | No-op, returns `true` |
| `getErrorHistory` | Full implementation with time/type filters | Stub — returns empty array |
| `getDebugInfo` | Delegates to `PolyfenceDebugCollector` | Built inline with some fields hardcoded |
| Event channel init | Automatic on listener attach | Uses string arguments (`"location"`, `"geofence"`, etc.) |
| Device category | From `Build.MANUFACTURER`/`Build.MODEL` | From `utsname()` machine identifier |
| Session telemetry | Includes `chargingDuringSession` | Includes `chargingDuringSession` |

---

## Configuration Map Schema (over MethodChannel)

### Accuracy Profiles (snake_case on wire)

| Dart Enum | Wire Value | Description |
|-----------|-----------|-------------|
| `maxAccuracy` | `max_accuracy` | Highest precision, highest battery |
| `balanced` | `balanced` | Default; balanced accuracy/battery |
| `batteryOptimal` | `battery_optimal` | Prioritizes battery life |
| `adaptive` | `adaptive` | Context-aware auto-adjustment |

### Update Strategies (snake_case on wire)

| Dart Enum | Wire Value | Description |
|-----------|-----------|-------------|
| `continuous` | `continuous` | Regular intervals |
| `proximityBased` | `proximity_based` | Distance-to-zone adaptive |
| `movementBased` | `movement_based` | Movement-state adaptive |
| `intelligent` | `intelligent` | Combined optimization |

### Nested Settings Maps

#### ProximitySettings

```
{
  nearZoneThresholdMeters: double,    // default: 500.0
  farZoneThresholdMeters: double,     // default: 2000.0
  nearZoneUpdateIntervalMs: int,      // default: 5000
  farZoneUpdateIntervalMs: int        // default: 60000
}
```

#### MovementSettings

```
{
  stationaryThresholdMs: int,         // default: 300000 (5 min)
  movementThresholdMeters: double,    // default: 50.0
  stationaryUpdateIntervalMs: int,    // default: 120000 (2 min)
  movingUpdateIntervalMs: int         // default: 10000 (10s)
}
```

#### BatterySettings

```
{
  lowBatteryThreshold: int,           // default: 20 (percent)
  criticalBatteryThreshold: int,      // default: 10 (percent)
  lowBatteryUpdateIntervalMs: int,    // default: 30000
  pauseOnCriticalBattery: bool        // default: true
}
```

#### DwellSettings

```
{
  enabled: bool,                      // default: true
  dwellThresholdMs: int               // default: 300000 (5 min)
}
```

#### ClusterSettings

```
{
  enabled: bool,                      // default: false
  activeRadiusMeters: double,         // default: 5000.0
  refreshDistanceMeters: double       // default: 1000.0
}
```

#### ScheduleSettings

```
{
  enabled: bool,                      // default: false
  timeWindows: [
    {
      startTime: { hour: int, minute: int },
      endTime: { hour: int, minute: int },
      daysOfWeek: [int]               // 1=Monday..7=Sunday, empty=all
    }
  ],
  startImmediatelyIfInWindow: bool    // default: true
}
```

#### ActivitySettings

```
{
  enabled: bool,                      // default: false
  confidenceThreshold: int,           // default: 75 (0-100)
  debounceSeconds: int,               // default: 30
  stillIntervalMs: int?,              // default: 120000
  walkingIntervalMs: int?,            // default: 15000
  runningIntervalMs: int?,            // default: 10000
  cyclingIntervalMs: int?,            // default: 8000
  drivingIntervalMs: int?             // default: 5000
}
```
