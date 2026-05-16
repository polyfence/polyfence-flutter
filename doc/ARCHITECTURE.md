# Polyfence Architecture

This document describes the internal architecture of the Polyfence Flutter plugin and its relationship to polyfence-core.

## Repository Structure

Polyfence is split across two repositories:

```
polyfence-core                        ← Standalone native geofencing engine
  ├── android/                        ← Kotlin implementation
  │   └── core/
  │       ├── GeofenceEngine.kt       ← Zone detection (ray-casting, haversine)
  │       ├── LocationTracker.kt      ← SmartGPS, activity-based intervals
  │       ├── TrackingScheduler.kt    ← Time-window scheduling
  │       ├── ActivityRecognitionManager.kt
  │       ├── TelemetryAggregator.kt  ← Session metrics collection
  │       ├── ZonePersistence.kt      ← Zone state recovery
  │       └── SmartGpsConfig.kt       ← Configuration model
  └── ios/
      └── Classes/Core/               ← Swift implementation (mirrors Kotlin)

polyfence (this repo)                 ← Flutter plugin bridge
  ├── lib/
  │   ├── polyfence.dart              ← Public API exports
  │   └── src/
  │       ├── services/               ← PolyfenceService, AnalyticsService
  │       ├── models/                 ← Zone, GeofenceEvent, Location
  │       ├── configuration/          ← PolyfenceConfiguration
  │       ├── platform/               ← MethodChannel bridge
  │       ├── errors/                 ← Exception hierarchy
  │       └── debug/                  ← PolyfenceDebugInfo
  ├── android/                        ← Kotlin plugin (bridges to polyfence-core)
  └── ios/                            ← Swift plugin (bridges to polyfence-core)
```

## Why Two Repos?

The native engines (Kotlin + Swift) are framework-agnostic. By separating them into polyfence-core:

- **polyfence-flutter** depends on polyfence-core via CocoaPods (iOS) and Maven (Android)
- **polyfence-react-native** (planned) will depend on the same polyfence-core
- **polyfence-swift** and **polyfence-kotlin** (future) will expose polyfence-core directly

One set of algorithms, multiple framework bridges.

## Platform Channel Contract

The Flutter plugin communicates with native code through platform channels:

| Channel | Type | Purpose |
|---------|------|---------|
| `polyfence` | MethodChannel | Request/response operations (initialize, addZone, startTracking, etc.) |
| `polyfence/location` | EventChannel | GPS location update stream |
| `polyfence/geofence` | EventChannel | Zone entry/exit/dwell event stream |
| `polyfence/error` | EventChannel | Structured error event stream |
| `polyfence/performance` | EventChannel | Runtime status and performance metrics stream |

For the full channel specification, see [PLATFORM_CHANNEL_SPEC.md](PLATFORM_CHANNEL_SPEC.md).

## Data Flow

### Zone Configuration

```
Developer code
  │  Polyfence.instance.addZone(Zone.circle(...))
  ▼
PolyfenceService (Dart)
  │  zone.toJson() → MethodChannel.invokeMethod('addZone', map)
  ▼
PolyfencePlugin (Kotlin/Swift)
  │  Deserialize map → ZoneData
  ▼
GeofenceEngine (polyfence-core)
  │  Store in memory + persist to SharedPreferences/UserDefaults
  ▼
Zone active — checked on every GPS update
```

### Geofence Detection

```
GPS hardware
  │  Location update
  ▼
LocationTracker (polyfence-core)
  │  SmartGPS: filter by accuracy threshold, apply distance filter
  │  Activity recognition: adjust interval (still=120s, driving=5s)
  ▼
GeofenceEngine (polyfence-core)
  │  For each active zone:
  │    Circle → haversine distance < radius?
  │    Polygon → ray-casting point-in-polygon test
  │  Compare with previous state → detect ENTER/EXIT
  │  Track dwell time → fire DWELL after threshold
  ▼
EventChannel: polyfence/geofence
  │  Native map → Dart GeofenceEvent.fromMap()
  ▼
PolyfenceService.onGeofenceEvent stream
  │  Developer's stream listener fires
  ▼
Developer code handles event
```

### Telemetry Flow

Telemetry is opt-out — enabled by default with one-line disable (`AnalyticsConfig(disableTelemetry: true)`). When enabled:

```
GeofenceEngine + LocationTracker (polyfence-core)
  │  TelemetryAggregator collects session metrics natively:
  │    detection counts, latency, GPS accuracy, battery,
  │    activity distribution, zone transitions, false events
  ▼
MethodChannel: getSessionTelemetry
  │  Dart fetches aggregated payload from native
  ▼
PolyfenceAnalytics (Dart)
  │  Merges native metrics with Dart-side metrics
  │  Converts camelCase keys → snake_case for API
  ▼
HTTPS POST → polyfence.io/api/v1/telemetry/session
  │  Anonymous aggregate metrics only
  │  No GPS coordinates, no PII, no zone definitions
```

## Critical Algorithms

These algorithms are implemented identically in both Kotlin and Swift (polyfence-core). Changes to one must be mirrored in the other.

### Haversine Formula

Calculates the great-circle distance between two GPS coordinates. Used for circle zone detection.

```
a = sin²(dlat/2) + cos(lat1) * cos(lat2) * sin²(dlon/2)
c = 2 * atan2(sqrt(a), sqrt(1-a))
d = R * c    (R = 6371000 meters)
```

### Ray-Casting Algorithm

Determines if a point is inside a polygon by counting how many times a ray from the point crosses polygon edges. Odd count = inside, even = outside.

### Douglas-Peucker Algorithm

Simplifies polygons by recursively removing points that are within a tolerance distance of the simplified line. Used for large polygons (1000+ points) to reduce computation.

## SmartGPS Strategies

| Strategy | Behavior |
|----------|----------|
| `continuous` | Fixed interval based on accuracy profile |
| `proximityBased` | Near zones: fast updates. Far from zones: slow updates |
| `movementBased` | Moving: fast updates. Stationary: slow updates |
| `intelligent` | Combines proximity + movement + battery + activity |

The `intelligent` strategy hierarchy:
1. Near a zone + moving → fast proximity interval (5s)
2. Near a zone + stationary → reduced interval (120s)
3. Far from all zones → slow interval (60s)
4. Low battery → further reduced regardless of above

## Building from Source

```bash
# Clone the plugin
git clone https://github.com/polyfence/polyfence-flutter.git
cd polyfence-flutter

# Install Dart dependencies
flutter pub get

# Run tests
flutter test

# Run static analysis
flutter analyze

# Generate API docs
dart doc

# Run the example app
cd example && flutter run
```

polyfence-core is pulled automatically as a dependency when building the plugin. To build polyfence-core separately:

```bash
# Clone polyfence-core
git clone https://github.com/polyfence/polyfence-core.git

# Android
cd polyfence-core/android && ./gradlew build

# iOS
cd polyfence-core/ios && pod lib lint
```

## Related Repositories

| Repository | Purpose |
|---|---|
| [polyfence-flutter](https://github.com/polyfence/polyfence-flutter) | Flutter plugin (this repo) |
| [polyfence-core](https://github.com/polyfence/polyfence-core) | Shared native engine (Kotlin + Swift) |
| polyfence-react-native | React Native bridge (planned) |
