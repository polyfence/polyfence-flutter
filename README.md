# Polyfence Flutter

Polyfence is the geofence layer — same zones run on your mobile app, your IoT device, and your server. This package is the Flutter SDK; see [polyfence-core](https://github.com/polyfence/polyfence-core) (native engines) and [polyfence-embedded](https://github.com/polyfence/polyfence-embedded) (C library for IoT) for the other surfaces.

**Privacy-first, on-device geofencing for Flutter.** Accurate circle & polygon zone detection with true background operation on both platforms. No location data or PII ever transmitted. Minimal dependencies.

[![pub package](https://img.shields.io/pub/v/polyfence.svg)](https://pub.dev/packages/polyfence)
[![CI](https://github.com/polyfence/polyfence-flutter/actions/workflows/ci.yml/badge.svg)](https://github.com/polyfence/polyfence-flutter/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
![Platform: Android & iOS](https://img.shields.io/badge/platform-Android%20%7C%20iOS-blue)
[![pub points](https://img.shields.io/pub/points/polyfence)](https://pub.dev/packages/polyfence/score)

<p>
  <img alt="Map view" src="assets/screenshots/map-view.jpg" width="280" />
  <img alt="Zones with live state" src="assets/screenshots/zones.jpg" width="280" />
</p>

The screenshots above are from the [example app](example/) in this repo — a working Flutter app that loads zones from the Polyfence SaaS (or local demo zones), tracks location, and renders enter / exit / dwell events. Sign up at [polyfence.io](https://polyfence.io) for a free API key, then follow [`example/README.md`](example/README.md) to run it locally.

## Why Polyfence?

- **Polygon geofencing** — Not just circles. Define zones with arbitrary polygon boundaries (complex city zones, campus outlines, delivery areas).
- **Unlimited zones** — No artificial limits. Monitor hundreds of zones simultaneously with zone clustering for performance.
- **Privacy-first** — All geofencing runs on-device. Zero location data ever leaves the device by default. No cloud dependency.
- **SmartGPS** — Intelligent GPS scheduling based on proximity, movement, activity, and battery state. 40-50% less battery drain than naive polling.

## Zone sources — three ways

Once you're using the Flutter SDK, you can source zones from three places. (For where the SDK fits in the wider Polyfence platform — the three integration surfaces across mobile, IoT, and server — see the header at the top of this README.)

| Approach | Backend | API Key | Best For |
|----------|---------|---------|----------|
| **Hardcode zones in your app** | None | Not needed | Static zones, full control, privacy-first apps |
| **Fetch from your own API** | Your backend | Not needed | Existing infrastructure, custom zone logic |
| **Use Polyfence SaaS** _(optional)_ | polyfence.io | Required | Visual zone editor, analytics dashboard |

All three zone-sourcing approaches use the **same plugin API** — switch anytime without code changes.

---

## Requirements

| Requirement | Version |
|-------------|---------|
| **Flutter** | 3.10.0+ |
| **Dart SDK** | 3.0.0+ |
| **Android** | API 24+ (Android 7.0), tested up to API 35 (Android 15) |
| **iOS** | 14.0+ |

## Platform Support

| Feature | Android | iOS |
|---------|---------|-----|
| Circle geofences | Yes | Yes |
| Polygon geofences | Yes | Yes |
| Dwell detection | Yes | Yes |
| Zone clustering | Yes | Yes |
| Scheduled tracking | Yes | Yes |
| Activity recognition | Yes | Yes |
| Background tracking | Yes (foreground service) | Yes ("Always" permission) |
| Battery optimization bypass | Yes | N/A |
| GPS accuracy profiles | Yes | Partial (iOS manages GPS) |

## Installation

```yaml
# pubspec.yaml
dependencies:
  polyfence: <!-- pf:version -->^1.0.1<!-- /pf:version -->
```

**Current version:** <!-- pf:version-plain -->1.0.1<!-- /pf:version-plain -->

> **Native dependency:** Polyfence uses [polyfence-core](https://github.com/polyfence/polyfence-core) for native geofencing engines. It's included automatically — Maven for Android, CocoaPods for iOS. On iOS, run `cd ios && pod install` after adding the dependency.

```bash
flutter pub get
```

> **New to Polyfence?** Try the example app first: `cd example && flutter run --dart-define=POLYFENCE_API_KEY=pf_live_xxx` (the Map tab also works without a key)

## Platform Setup

### Android — `android/app/src/main/AndroidManifest.xml`

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" />
```

- **minSdk**: 24+ (Android 7.0)
- **tested**: up to API 35 (Android 15)
- **dependency**: [polyfence-core](https://github.com/polyfence/polyfence-core) (native engine, pulled transitively via Maven — see CHANGELOG.md for the current pinned version)

Ensure your `android/app/build.gradle` has the correct minimum SDK version:
```groovy
android {
    defaultConfig {
        minSdkVersion 24 // Required for Polyfence
    }
}
```

#### Foreground Service Notification

Polyfence requires a foreground service notification on Android. **The plugin automatically creates the notification channel** — no additional setup required. The notification uses low priority and is silent.

### iOS — `ios/Runner/Info.plist`

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs location access to detect when you enter or exit defined zones.</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Background location access is required for continuous zone monitoring.</string>

<key>NSLocationAlwaysUsageDescription</key>
<string>Background location access is required for continuous zone monitoring.</string>

<key>UIBackgroundModes</key>
<array>
  <string>location</string>
</array>
```

- **iOS**: 14.0+
- **Requires** "Always" location for background geofencing

#### iOS Background Mode in Xcode

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select the Runner target → **Signing & Capabilities**
3. Click **+ Capability** → add **Background Modes**
4. Check **Location updates**

#### iOS Permission Flow

**Important:** iOS requires "Always" location permission for background geofencing, but the flow is different from Android:

1. **First Request:** When you call `requestPermissions(always: true)`, iOS shows a "While in use" permission dialog
2. **Manual Step Required:** The user must manually enable "Always" permission in Settings → Privacy & Security → Location Services → Your App → "Always"
3. **Check Permission Status:**

```dart
final isEnabled = await Polyfence.instance.isLocationServiceEnabled();
if (!isEnabled) {
  // Guide user to enable location services
}

final granted = await Polyfence.instance.requestPermissions(always: true);
if (granted) {
  // User granted "While in use" — they still need to enable "Always" in Settings
  // You may want to show a dialog guiding them to Settings
}
```

**Note:** iOS doesn't provide a direct API to check if "Always" permission is granted. The plugin will work with "While in use" but background geofencing requires "Always" permission.

## Getting Started

### Step 1: Initialize the Plugin

> **Subscribe to `onError` BEFORE calling `initialize()` — see Step 6 for why.** Several methods (including `initialize` itself, `addZone`, `requestPermissions`, and `requestBatteryOptimizationExemption`) emit errors through `onError` as a side effect. Without a listener attached at the time, those errors are silently dropped.

```dart
import 'package:polyfence/polyfence.dart';

// Subscribe FIRST so the listener catches any side-effect errors
// from initialize() itself.
Polyfence.instance.onError.listen((error) {
  print('Polyfence error: ${error.type} - ${error.message}');
});

await Polyfence.instance.initialize();
```

### Step 2: Request Permissions

**iOS:** `requestPermissions(always: true)` triggers the system permission dialog.

**Android:** `requestPermissions()` **does not show a dialog** — it only reads the current permission state and returns a boolean. To trigger the OS dialog on Android, use a package like [`permission_handler`](https://pub.dev/packages/permission_handler) first, then call `requestPermissions()` to verify the result.

```dart
import 'dart:io' show Platform;
// Android only — trigger the OS permission dialog.
// import 'package:permission_handler/permission_handler.dart';
// if (Platform.isAndroid) {
//   await Permission.location.request();
//   await Permission.locationAlways.request();
// }

// Both platforms — verify the result. On iOS this ALSO shows the
// system dialog on first call.
final hasPermission = await Polyfence.instance.requestPermissions(always: true);
if (!hasPermission) {
  // Handle permission denied — e.g. guide the user to Settings.
  return;
}
```

### Step 3: Add Zones

```dart
// Circle zone
await Polyfence.instance.addZone(Zone.circle(
  id: 'office',
  name: 'Office',
  center: PolyfenceLocation(latitude: 37.422, longitude: -122.084),
  radius: 150,
));

// Polygon zone
await Polyfence.instance.addZone(Zone.polygon(
  id: 'campus',
  name: 'Campus',
  polygon: [
    PolyfenceLocation(latitude: 37.422, longitude: -122.084),
    PolyfenceLocation(latitude: 37.423, longitude: -122.085),
    PolyfenceLocation(latitude: 37.424, longitude: -122.083),
  ],
));
```

Zones are automatically persisted across app restarts — no database setup needed. There is no hard limit on zone count (tested with 100+ zones on both platforms). Large polygons (1000+ points) are supported; the plugin uses Douglas-Peucker simplification to optimize complex polygons. Unlike plugins that rely on the OS native region monitoring APIs, Polyfence performs its own on-device calculations — so the iOS 20-region limit does not apply.

### Step 4: Listen for Events

```dart
Polyfence.instance.onGeofenceEvent.listen((event) {
  switch (event.type) {
    case GeofenceEventType.enter:
      print('Entered: ${event.zoneId}');
      break;
    case GeofenceEventType.exit:
      print('Exited: ${event.zoneId}');
      break;
    case GeofenceEventType.dwell:
      print('Stayed in ${event.zoneId} for 5+ minutes');
      break;
    // Recovery events fire ONLY when the tracking service was killed
    // and restarted (Doze kill / OOM / force-stop / phone reboot). On
    // the first GPS fix after restart, the SDK reconciles persisted
    // zone state against the actual location and emits recoveryEnter /
    // recoveryExit for any mismatch. They do NOT fire on GPS signal
    // loss (airplane mode, tunnel) during active tracking — a regular
    // enter/exit fires for those. Treat recovery events like enter/exit
    // unless you specifically want to distinguish "user just crossed
    // the boundary" from "user was already inside/outside when the
    // tracking process resumed after being killed."
    case GeofenceEventType.recoveryEnter:
      print('Confirmed inside (post-restart): ${event.zoneId}');
      break;
    case GeofenceEventType.recoveryExit:
      print('Confirmed outside (post-restart): ${event.zoneId}');
      break;
  }
});
```

<p align="center">
  <img alt="ENTER, EXIT, DWELL and RECOVERY events as your device moves" src="assets/screenshots/events.png" width="280" />
</p>

### Step 5: Start Tracking

```dart
await Polyfence.instance.startTracking();
```

### Step 6: Handle Errors

`onError` is the SDK's **central error channel** — and the only place several methods report failure. `initialize`, `addZone`, `requestPermissions`, and `requestBatteryOptimizationExemption` emit errors here rather than rejecting their own Future, so if you don't have a listener attached when one of those calls runs, the error vanishes silently. Subscribe before any other SDK call (Step 1 shows the recommended ordering).

```dart
Polyfence.instance.onError.listen((error) {
  switch (error.type) {
    case PolyfenceErrorType.gpsPermissionDenied:
      // Guide user to settings
      break;
    case PolyfenceErrorType.gpsServiceDisabled:
      // Prompt to enable GPS
      break;
    default:
      print('Error: ${error.message}');
  }
});
```

## Configuration

Polyfence provides flexible configuration to balance accuracy, battery life, and notification behavior.

### Alert Notifications

By default, Polyfence shows built-in "Entered Zone" / "Exited Zone" notifications. If your app implements custom notifications, you can disable these:

```dart
await Polyfence.instance.initialize(
  config: PolyfenceConfiguration(
    disableAlertNotifications: true,  // Suppress built-in zone alerts
  ),
);
```

**Use cases:** custom notifications with app-specific context, apps that handle zone events silently, or different notification styles. The foreground service notification remains active (required for background GPS).

### GPS Accuracy Profiles

```dart
// Maximum accuracy (highest battery usage)
await Polyfence.instance.setAccuracyProfile(PolyfenceAccuracyProfile.maxAccuracy);

// Balanced accuracy/battery (DEFAULT - recommended for most apps)
await Polyfence.instance.setAccuracyProfile(PolyfenceAccuracyProfile.balanced);

// Battery-optimized for background monitoring
await Polyfence.instance.setAccuracyProfile(PolyfenceAccuracyProfile.batteryOptimal);

// Intelligent auto-adjustment based on context
await Polyfence.instance.setAccuracyProfile(PolyfenceAccuracyProfile.adaptive);
```

| Profile | GPS Accuracy | Update Interval | Battery Impact | Use Case |
|---------|-------------|-----------------|----------------|----------|
| **Max Accuracy** | High | 5 seconds (Android) | High | Delivery, navigation, fleet tracking |
| **Balanced** | Balanced | 10 seconds (Android) | Medium | Most location-aware apps |
| **Battery Optimal** | Low Power | 30 seconds (Android) | Low | Background monitoring, casual use |
| **Adaptive** | Dynamic | Dynamic (Android) | Variable | Apps with varying accuracy needs |

> **Platform Note:** Both platforms respect accuracy profiles. Android uses explicit update intervals; iOS uses `desiredAccuracy` and `distanceFilter` settings which CoreLocation optimizes automatically.

<p align="center">
  <img alt="GPS profile selector — Max, Balanced, Battery, Smart" src="assets/screenshots/dashboard.png" width="280" />
</p>

### Advanced Configuration

```dart
// Proximity-aware GPS optimization
await Polyfence.instance.updateConfiguration(
  PolyfenceConfiguration(
    accuracyProfile: PolyfenceAccuracyProfile.balanced,
    updateStrategy: PolyfenceUpdateStrategy.proximityBased,
    proximitySettings: ProximitySettings(
      nearZoneThresholdMeters: 500.0,
      farZoneThresholdMeters: 2000.0,
      nearZoneUpdateInterval: Duration(seconds: 5),
      farZoneUpdateInterval: Duration(seconds: 60),
    ),
  ),
);

// Movement-based optimization
await Polyfence.instance.updateConfiguration(
  PolyfenceConfiguration(
    updateStrategy: PolyfenceUpdateStrategy.movementBased,
    movementSettings: MovementSettings(
      stationaryThreshold: Duration(minutes: 5),
      stationaryUpdateInterval: Duration(minutes: 2),
      movingUpdateInterval: Duration(seconds: 10),
    ),
  ),
);

// Intelligent optimization (proximity + movement + battery)
await Polyfence.instance.enableIntelligentOptimization();

// Or use the convenience method for proximity only
await Polyfence.instance.enableProximityOptimization(
  nearThreshold: 500.0,  // High accuracy within 500m of zones
  farThreshold: 2000.0,  // Low frequency when >2km from zones
);
```

**Proximity behavior:** Inside zones: continuous monitoring for exit detection. Near zones (<500m): high frequency for accurate entry detection. Medium distance (500m-2km): graduated frequency. Far from zones (>2km): low frequency to preserve battery. Can reduce GPS usage by 60-80% for users who spend time away from monitored zones.

### GPS Accuracy Threshold

By default, Polyfence rejects GPS readings with accuracy worse than **100 meters** to ensure consistent behavior across iOS and Android. This threshold is configurable:

```dart
await Polyfence.instance.updateConfiguration(
  PolyfenceConfiguration(
    gpsAccuracyThreshold: 50.0, // 50 meters - stricter
    // Or
    gpsAccuracyThreshold: 200.0, // 200 meters - more lenient
  ),
);
```

### Dwell Detection

Dwell events fire when a device remains inside a zone for a configurable duration (default: 5 minutes). Useful for confirming presence rather than pass-through.

```dart
// Listen for dwell events
Polyfence.instance.onGeofenceEvent.listen((event) {
  if (event.type == GeofenceEventType.dwell) {
    final mins = (event.dwellDurationMs ?? 0) ~/ 60000;
    print('User confirmed in ${event.zoneId} after $mins min');
  }
});

// Configure threshold (default: 5 minutes)
await Polyfence.instance.updateConfiguration(
  PolyfenceConfiguration(
    dwellSettings: DwellSettings(
      enabled: true,
      dwellThreshold: Duration(minutes: 10),
    ),
  ),
);
```

| Setting | Default | Description |
|---------|---------|-------------|
| `enabled` | `true` | Whether dwell detection is active |
| `dwellThreshold` | 5 minutes | Time inside zone before DWELL fires |

### Zone Clustering

For apps with large zone sets (100+ zones), clustering improves performance by only checking zones near the user's location.

```dart
await Polyfence.instance.updateConfiguration(
  PolyfenceConfiguration(
    clusterSettings: ClusterSettings(
      enabled: true,
      activeRadiusMeters: 5000,    // Check zones within 5km
      refreshDistanceMeters: 1000, // Re-evaluate cluster after moving 1km
    ),
  ),
);
```

| Setting | Default | Description |
|---------|---------|-------------|
| `enabled` | `false` | Whether clustering is active |
| `activeRadiusMeters` | 5000 | Radius to check zones within |
| `refreshDistanceMeters` | 1000 | Distance to move before refreshing active cluster |

**When to use:** Apps with 100+ geographically distributed zones (retail chains, delivery networks). For apps with fewer zones, clustering adds overhead without benefit.

### Scheduled Tracking

Automatically start and stop tracking based on time windows. Useful for work-hours-only tracking, shift-based applications, or battery conservation.

```dart
// Track only during work hours (9am-5pm, weekdays)
await Polyfence.instance.updateConfiguration(
  PolyfenceConfiguration(
    scheduleSettings: ScheduleSettings(
      enabled: true,
      timeWindows: [
        TimeWindow(
          startTime: TimeOfDay(hour: 9, minute: 0),
          endTime: TimeOfDay(hour: 17, minute: 0),
          daysOfWeek: [1, 2, 3, 4, 5], // Monday-Friday
        ),
      ],
    ),
  ),
);
```

| Setting | Default | Description |
|---------|---------|-------------|
| `enabled` | `false` | Whether scheduled tracking is active |
| `timeWindows` | `[]` | List of time windows when tracking is active |
| `startImmediatelyIfInWindow` | `true` | Start tracking immediately if currently in a scheduled window |

**TimeWindow properties:**

| Property | Description |
|----------|-------------|
| `startTime` | When tracking should start (TimeOfDay with hour/minute) |
| `endTime` | When tracking should stop (TimeOfDay with hour/minute) |
| `daysOfWeek` | Days when window applies (1=Monday, 7=Sunday). Empty = all days |

**Notes:** Schedule persists across app restarts and device reboots. Time windows that span midnight are supported (e.g., 22:00 - 06:00). Multiple overlapping windows are supported — tracking is active during any of them. On Android, uses AlarmManager for reliable wake-up at scheduled times.

### Activity Recognition

Automatically detect user activity (still, walking, running, cycling, driving) and optimize GPS intervals accordingly. This feature is **opt-in** and requires additional permissions.

```dart
// Enable activity recognition
await Polyfence.instance.updateConfiguration(
  PolyfenceConfiguration(
    activitySettings: ActivitySettings(
      enabled: true,
      confidenceThreshold: 75,   // Only act on 75%+ confidence
      debounceSeconds: 30,       // Wait 30s before switching modes
    ),
  ),
);

// Custom intervals per activity (optional)
await Polyfence.instance.updateConfiguration(
  PolyfenceConfiguration(
    activitySettings: ActivitySettings(
      enabled: true,
      stillInterval: Duration(seconds: 120),    // 2 min when stationary
      walkingInterval: Duration(seconds: 15),   // 15s when walking
      drivingInterval: Duration(seconds: 5),    // 5s when driving
    ),
  ),
);
```

| Setting | Default | Description |
|---------|---------|-------------|
| `enabled` | `false` | Whether activity recognition is active (opt-in) |
| `confidenceThreshold` | `75` | Minimum confidence (0-100) before acting on detected activity |
| `debounceSeconds` | `30` | Seconds activity must persist before switching GPS mode |
| `stillInterval` | 120s | GPS interval when device is stationary |
| `walkingInterval` | 15s | GPS interval when walking |
| `runningInterval` | 10s | GPS interval when running |
| `cyclingInterval` | 8s | GPS interval when cycling |
| `drivingInterval` | 5s | GPS interval when driving |

**Platform APIs:** Android uses `ActivityRecognitionClient` from Google Play Services. iOS uses `CMMotionActivityManager` from CoreMotion.

**Additional Permissions Required:**

**Android** — Add to `AndroidManifest.xml` (only if using activity recognition):
```xml
<uses-permission android:name="android.permission.ACTIVITY_RECOGNITION" />
```

**iOS** — Add to `Info.plist` (only if using activity recognition):
```xml
<key>NSMotionUsageDescription</key>
<string>This app uses motion data to optimize GPS updates based on your activity.</string>
```

**Important:** Activity recognition only affects GPS update intervals. It does NOT affect zone detection accuracy, validation logic, or confidence thresholds. When near a zone, proximity-based fast updates take precedence over activity-based optimizations.

## Background Reliability & Battery Optimization

Polyfence includes battery optimizations that reduce drain by an estimated 40-50%. The default profile is BALANCED.

Events fire whether the app is foregrounded, backgrounded, or the screen is locked. Here's what users see on each platform when zones fire in the background:

<p align="center">
  <img alt="Background events on iOS lock screen" src="assets/screenshots/notifications-ios.jpg" width="280" />
  <img alt="Background events on Android notification shade" src="assets/screenshots/notifications-android.jpg" width="280" />
</p>

| Feature | Description | Platforms |
|---------|-------------|-----------|
| **Deferred GPS Start** | GPS doesn't start until zones are registered | Android & iOS |
| **Distance Filter** | Only receive updates when device moves (10m for BALANCED) | Android & iOS |
| **Zone Check Throttling** | Skip geofence checks if moved <5 meters | Android & iOS |
| **Callback Throttling** | Reduce Flutter callbacks to 30s when stationary | Android & iOS |
| **Stationary Detection** | 2-minute intervals when stationary near zones | Android & iOS |
| **Profile-based Wake Lock** | Wake lock timeout tied to accuracy profile (4-12 hours) | Android |
| **Auto-restart** | Service restarts if killed (up to 3 attempts with cooldown) | Android |
| **GPS Recovery** | Automatic recovery from GPS failures (up to 5 attempts) | Android |
| **Foreground Service** | Uses `FOREGROUND_SERVICE_LOCATION` for background updates | Android |
| **Pauses When Stationary** | Automatically pauses location updates for BALANCED/BATTERY_OPTIMAL | iOS |
| **Significant Location Fallback** | Falls back to significant location changes when appropriate | iOS |

### Battery Optimization Bypass (Android)

Android may kill background services if battery optimization is enabled. Use the built-in API to request exemption:

```dart
final status = await Polyfence.instance.batteryOptimizationStatus();
if (status['isOptimized'] == true && status['canRequest'] == true) {
  await Polyfence.instance.requestBatteryOptimizationExemption();
}
```

## Error Handling & Recovery

### Error Stream

```dart
Polyfence.instance.onError.listen((error) {
  switch (error.type) {
    case PolyfenceErrorType.batteryOptimizationRequired:
      _showBatteryOptimizationDialog();
      break;
    case PolyfenceErrorType.gpsPermissionDenied:
      _showPermissionDialog();
      break;
    case PolyfenceErrorType.serviceKilled:
      _showServiceKilledNotification();
      break;
    default:
      print('Polyfence error: ${error.message}');
  }
});
```

### Exception Types

Polyfence throws structured exceptions for better error handling:

- **`PolyfenceNotInitializedException`**: Thrown when plugin methods are called before `initialize()`
- **`PlatformOperationException`**: Thrown when platform operations fail. Includes `details` (code/details from platform), `innerException`, and full `stackTrace`.

```dart
try {
  await Polyfence.instance.startTracking();
} on PolyfenceNotInitializedException {
  await Polyfence.instance.initialize();
  await Polyfence.instance.startTracking();
} on PlatformOperationException catch (e, stackTrace) {
  print('Platform error in ${e.operation}: ${e.message}');
  print('Platform code: ${e.details?['code']}');
  print('Full details: ${e.details}');
}
```

### Error Types

| Error Type | Description | Recommended Action |
|------------|-------------|-------------------|
| `batteryOptimizationRequired` | Android battery optimization enabled | Request exemption |
| `gpsPermissionDenied` | Location permission denied | Guide to settings |
| `gpsServiceDisabled` | GPS service disabled | Enable location services |
| `serviceKilled` | Background service terminated | Show restart notification |
| `serviceStartFailed` | Failed to start location service | Check permissions |
| `gpsTimeout` | GPS signal timeout | Retry or show status |
| `gpsUnreliable` | GPS accuracy poor or signal dropping | Show GPS quality banner |

## Debug Information API

```dart
final debugInfo = await Polyfence.instance.debugInfo();

// System status
print('Location Permission: ${debugInfo.systemStatus.isLocationPermissionGranted}');
print('GPS Enabled: ${debugInfo.systemStatus.isGpsEnabled}');
print('Wake Lock Active: ${debugInfo.systemStatus.isWakeLockAcquired}');

// Performance metrics
print('Uptime: ${debugInfo.performance.uptime}');
print('Location Updates: ${debugInfo.performance.totalLocationUpdates}');
print('Memory Usage: ${debugInfo.performance.memoryUsageMB}MB');

// Battery information
print('Battery Level: ${debugInfo.battery.batteryLevel}%');
print('Is Charging: ${debugInfo.battery.isCharging}');

// Zone status
print('Active Zones: ${debugInfo.zones.activeZones}');
```

### Error History

```dart
final recentErrors = await Polyfence.instance.errorHistory(
  timeRange: Duration(hours: 24),
);
```

### Zone State Query

```dart
// Get current INSIDE/OUTSIDE state for all monitored zones
final states = await Polyfence.instance.getZoneStates();
states.forEach((zoneId, isInside) {
  print('$zoneId: ${isInside ? "INSIDE" : "OUTSIDE"}');
});
```

Useful for session management and state reconciliation after app restarts.

## Common Gotchas

### Stream Subscription Management
Always cancel stream subscriptions in `dispose()` to prevent memory leaks. The plugin automatically handles all resource cleanup including stream controllers, analytics sessions, and platform resources. Example: `_geofenceSubscription?.cancel();`

### Zone Persistence
Zones are automatically persisted across app restarts — no manual persistence needed. Zone state persists through app kills, crashes, and restarts. When loading zones from an external source, consider implementing delta-based sync to avoid re-registering all zones on each load.

### OEM Battery Restrictions (Android)

Some Android manufacturers (Samsung, Xiaomi, Huawei, OnePlus, Oppo) aggressively kill background services. If tracking stops on specific devices, the user likely needs to whitelist your app from battery optimization. See [dontkillmyapp.com](https://dontkillmyapp.com) for device-specific instructions.

### Debugging

**Android** — Filter logcat for Polyfence messages:
```bash
adb logcat | grep -E "LocationTracker|GeofenceEngine|Polyfence"
```

**iOS** — Filter Xcode console:
```
LocationTracker GeofenceEngine Polyfence
```

**Programmatic debugging** — Use the debug API:
```dart
final debug = await Polyfence.instance.debugInfo();
print('GPS accuracy: ${debug.systemStatus.lastKnownAccuracy}m');
print('Zones monitored: ${debug.zones.activeZones}');
print('Detections: ${debug.performance.totalZoneDetections}');
print('Recent errors: ${debug.recentErrors.length}');
```

### Reporting Issues

When opening a GitHub issue, include: output of `Polyfence.instance.debugInfo()`, device manufacturer and OS version, whether battery optimization is disabled, and relevant logcat/Xcode console output.

## Example App

A complete example app is included in the `example/` directory, demonstrating
the SDK end-to-end: zone sync, real-time geofence events, background tracking,
GPS accuracy profiles, and live position on a map.

The API key is supplied at build/run time via `--dart-define` — there is no
in-app paste field, and the app ships with **zero zones**:

```bash
cd example
flutter pub get
flutter run --dart-define=POLYFENCE_API_KEY=pf_live_xxx
```

The example renders whichever zones are active on your Polyfence account; define
them in the [Polyfence dashboard](https://polyfence.io) first. Without the
`--dart-define`, the **Dashboard** tab shows an empty-state card surfacing the
exact command to re-run. The **Map** tab still works without a key (shows your
position with zero zones), so you can sanity-check location permissions.

**What the example demonstrates:** zone delta sync, zone entry/exit/dwell event
handling, background tracking across app states, GPS profile switching,
permission request flow, and error stream handling.

See [`example/README.md`](example/README.md) for the full walkthrough.

---

## Privacy & Security

Polyfence is built with privacy as the foundation.

### What We NEVER Send

- **GPS coordinates** or location data
- **Zone definitions** or boundaries
- **User identifiers** (name, email, phone, device ID)
- **Personal information** of any kind

**Your users' location data stays on their device. Always.**

### Zero PII about your end users

Polyfence collects **zero PII and zero identifiable data about your end users.** The only personal information our analytics endpoint sees is anonymous platform aggregates — never coordinates, never identifiers.

Different defaults for different data classes — control on every axis, no privacy theatre:

| Data class | Default | Why |
|---|---|---|
| **Raw positions** | **Opt-IN** | We don't have your customers' location data unless you explicitly turn retention on. |
| **Anonymous platform aggregates** | **Opt-OUT** with one-line disable | Collected by default to fuel product improvements everyone benefits from. Never coordinates, never identifiers, never PII. Industry-standard pattern (Stripe, Vercel, Cloudflare, Sentry). |
| **Zone events** | **Always** | They're the value we deliver — collecting them isn't surveillance, it's the product. |

### Anonymous Plugin Telemetry (Opt-Out)

Polyfence collects anonymous performance telemetry to help improve plugin reliability. Telemetry is **enabled by default** — disable it with one line:

```dart
await Polyfence.instance.initialize(
  analyticsConfig: AnalyticsConfig(
    disableTelemetry: true,
  ),
);
```

Only anonymous aggregate metrics are sent: plugin version, platform, performance metrics (detection times, GPS accuracy averages), battery impact statistics, error counts, and zone type counts. **No GPS coordinates, zone definitions, or PII are ever transmitted.**

**See exactly what's sent:** [Full Telemetry Reference](doc/TELEMETRY.md)

### Architecture Guarantees

- **On-device geofencing**: All zone detection runs locally using native GPS APIs
- **Local persistence**: Zones stored in SharedPreferences (Android) / UserDefaults (iOS)
- **No tracking**: No user behavior tracking, no cross-app tracking
- **GDPR/CCPA-friendly**: Anonymous telemetry only, easy opt-out

---

## Comparison

| Capability | Polyfence | Google Geofencing API | Apple CLRegion | Radar.io |
|---|---|---|---|---|
| **Polygon zones** | Yes | No (circles only) | No (circles only) | Yes |
| **Zone limit** | Unlimited | 100 | 20 | Unlimited (paid) |
| **On-device processing** | Yes | No (cloud) | Yes | No (cloud) |
| **Cross-platform** | iOS + Android | Android only | iOS only | iOS + Android |
| **Privacy-first** | Yes | No | Partial | No |
| **Open source** | Yes (MIT) | No | N/A | No |
| **Activity recognition** | Yes | No | No | Yes |
| **Dwell detection** | Yes | Yes | No | Yes |
| **Zone clustering** | Yes | No | No | No |
| **Scheduled tracking** | Yes | No | No | No |
| **Battery optimization** | SmartGPS | Platform-managed | Platform-managed | Cloud-managed |
| **Cost** | Free | Free | Free | Free tier, then $500/mo+ |

## Architecture

Polyfence uses a layered architecture:

```
polyfence-core (native engines)          ← Kotlin + Swift
  ├── GeofenceEngine                     ← Ray-casting, haversine, dwell detection
  ├── LocationTracker                    ← SmartGPS, activity-based intervals
  ├── TrackingScheduler                  ← Time windows, day-of-week
  └── TelemetryAggregator               ← Session metrics (native-side)

polyfence (Flutter plugin)               ← You are here
  ├── PolyfenceService                   ← Dart API (singleton)
  ├── MethodChannel bridge               ← Dart ↔ Native communication
  └── PolyfenceAnalytics                 ← Telemetry POST (Dart-side)
```

**Data flow:** Zone definitions → native GeofenceEngine → GPS location updates trigger zone checks → geofence events stream back to Dart.

For the full architecture guide, see [doc/ARCHITECTURE.md](doc/ARCHITECTURE.md).

## Contributing

Contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup, code style, and PR guidelines.

## Support

- **Plugin Issues**: [GitHub Issues](https://github.com/polyfence/polyfence-flutter/issues)
- **Questions & Discussions**: Open an issue with the `question` label
- **Security Issues**: See [SECURITY.md](SECURITY.md)
- **Commercial Support**: [polyfence.io](https://polyfence.io)

## License

MIT — see [LICENSE](LICENSE)

Copyright (c) 2025-2026 Polyfence
