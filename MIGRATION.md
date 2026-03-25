# Polyfence 0.13.0 Migration Guide

## Overview

Polyfence 0.13.0 is a significant internal refactoring that extracts the native geofencing core to a separate library. **The Dart API is unchanged** — most apps upgrade with zero code changes.

The key changes:
- Android package namespace: `com.polyfence` → `io.polyfence`
- Native core split into standalone `polyfence-core` library
- Telemetry aggregation moved to native side (transparent)
- `battery_plus` dependency removed

## For Most Apps: Nothing to Change

If you:
- Call `Polyfence.initialize()` with zones
- Listen to geofence events and errors
- Use the public API from `package:polyfence/polyfence.dart`

...then **upgrade to 0.13.0 and test**. Your code needs no changes.

## If You Reference Android Packages: Update Imports

If your Android code imports `com.polyfence` classes directly (unusual, but possible):

**Before (0.12.x):**
```kotlin
import com.polyfence.polyfence.core.GeofenceEngine
import com.polyfence.polyfence.core.LocationTracker
```

**After (0.13.0):**
```kotlin
import io.polyfence.core.GeofenceEngine
import io.polyfence.core.LocationTracker
```

### Gradle Dependency (if manual)

If you manually declare a polyfence-core dependency, update to the new namespace:

**Before:**
```groovy
implementation 'com.polyfence:polyfence-core:0.1.0'
```

**After:**
```groovy
implementation 'io.polyfence:polyfence-core:1.0.0'
```

The plugin now depends on `polyfence-core` automatically — you don't need to add it manually unless you use native APIs directly.

## If You Use Native Telemetry

The Dart `AnalyticsService` API is unchanged. Telemetry still works the same way:

```dart
final config = AnalyticsConfig(
  disableTelemetry: false, // Default — enabled
);
await Polyfence.instance.initialize(
  zones: zones,
  analyticsConfig: config,
);
```

- Telemetry is **enabled by default** (same as 0.12.x)
- Disable with `disableTelemetry: true`
- The payload structure hasn't changed

## iOS CocoaPods Update

On iOS, the plugin now depends on `PolyfenceCore` (a separate pod). After upgrading:

```bash
cd ios
pod install --repo-update
```

This fetches the new `PolyfenceCore` pod. No code changes needed.

## Android: No Manifest Changes

The Android namespace changed, but:
- You **do not** need to update `AndroidManifest.xml`
- You **do not** need to change `build.gradle` references to `polyfence`
- The plugin dependency in `pubspec.yaml` is `polyfence` (unchanged)

## What Changed on the Native Side (No Action Needed)

- 25 native source files moved to `polyfence-core` repository
- `battery_plus` dependency removed — battery tracking is now in the native core
- Telemetry aggregation moved to native (`TelemetryAggregator.kt`/`.swift`)
- `AnalyticsService` simplified from 592 to 231 lines of Dart code

These are internal changes. The Dart API and behavior are unchanged.

## Verification Checklist

After upgrading to 0.13.0:

- [ ] Run `flutter pub get`
- [ ] (iOS only) Run `cd ios && pod install --repo-update`
- [ ] Run `flutter analyze` — no new warnings
- [ ] Run your tests — they should pass without changes
- [ ] Test geofence events in your app — zones should trigger as before
- [ ] (Optional) Check example app: `cd example && flutter run`

If you use the Polyfence SaaS dashboard to fetch zones:

- [ ] Verify zones still load from the API
- [ ] Verify geofence events still fire

## If Anything Breaks

- **iOS build fails** — Run `cd ios && pod deintegrate && pod install --repo-update` to reset CocoaPods
- **Android build fails** — Run `flutter clean && flutter pub get && flutter build apk` to rebuild
- **Zone events don't fire** — Check that you're calling `Polyfence.initialize()` before using zones (unchanged behavior)
- **Telemetry not working** — Verify you didn't accidentally set `disableTelemetry: true` (it's `false` by default)

## Questions?

See the [README](README.md) for API reference, or check the [example app](example/) for a working implementation.
