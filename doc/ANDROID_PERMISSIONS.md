# Android Permissions

Which Android permissions Polyfence declares for you, which ones your app must
declare itself, and the exact XML to paste for each feature.

The iOS equivalent is `Info.plist` usage strings — see the **Platform Setup**
section of the [README](../README.md).

---

## The split

Manifest merging happens at build time. Anything the plugin declares ends up in
**your** merged manifest whether or not you use the feature behind it — including
on the Play Console listing that reviewers read. So the plugin declares only the
permissions its own service and receiver cannot run without, and leaves the rest
to you.

### Declared by the plugin — you paste nothing

These arrive in your merged manifest automatically. They are listed so you can
account for every permission your app ends up requesting.

| Permission | Why the plugin needs it |
|------------|-------------------------|
| `ACCESS_FINE_LOCATION` | The fixes zone membership is evaluated against |
| `ACCESS_COARSE_LOCATION` | Degraded-accuracy fallback for the same |
| `FOREGROUND_SERVICE` | `LocationTracker` runs as a foreground service |
| `FOREGROUND_SERVICE_LOCATION` | Its service type; `startForeground()` throws without it from API 34 |
| `WAKE_LOCK` | Partial wake lock held for the life of a tracking session |
| `POST_NOTIFICATIONS` | The foreground-service notification (API 33+) |
| `VIBRATE` | Zone alert notifications |
| `RECEIVE_BOOT_COMPLETED` | Re-arms scheduled tracking after a reboot |

### Declared by you — one block per feature

| Permission | Feature | Cost of declaring it |
|------------|---------|----------------------|
| `ACCESS_BACKGROUND_LOCATION` | Tracking while your app is backgrounded or closed | Triggers Google Play's manual background-location review |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | `requestBatteryOptimizationExemption()` | Play restricts it to app categories that can justify it |
| `SCHEDULE_EXACT_ALARM` | Minute-accurate scheduled tracking windows | Play policy review on API 33+ |
| `ACTIVITY_RECOGNITION` (both) | Activity-based GPS interval tuning | Adds a physical-activity runtime prompt |

---

## The trap: an undeclared permission cannot be granted

Android will not grant a permission that is absent from the merged manifest. A
runtime request against one returns **denied immediately, with no system dialog
shown to the user**. There is no error, no exception, and nothing in logcat that
points at the manifest.

Concretely, if your app does this:

```dart
final always = await Permission.locationAlways.request();
```

without `ACCESS_BACKGROUND_LOCATION` in `android/app/src/main/AndroidManifest.xml`,
`always` is `PermissionStatus.denied` on every call, the user is never asked, and
background tracking simply never starts. Earlier versions of the example app in
this repository taught exactly that call pattern, so an app that copied it and
changes nothing else will hit this.

The fix is always the same: declare the permission, then request it.

---

## Base integration

**Nothing to paste.** Foreground tracking, zone detection, the foreground-service
notification and zone alerts all run on the permissions the plugin declares.

You still request the location and notification grants at runtime:

```dart
import 'package:permission_handler/permission_handler.dart';

await Permission.notification.request();
await Permission.location.request();
```

Then confirm the plugin sees them:

```dart
final granted = await Polyfence.instance.requestPermissions();
```

## Background tracking

Needed when zones must keep firing while your app is backgrounded or closed.

```xml
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
```

Android requires background location to be requested **after** foreground location
has already been granted — a combined request is rejected by the OS:

```dart
final fine = await Permission.location.request();
if (fine.isGranted) {
  final always = await Permission.locationAlways.request();
  if (!always.isGranted) {
    // From API 30 the OS shows no dialog for this one; the user must pick
    // "Allow all the time" in app settings.
    await openAppSettings();
  }
}
```

From API 30 the runtime dialog no longer offers "Allow all the time" at all — the
user has to pick it in app settings, so treat `openAppSettings()` as the real path
rather than a fallback.

## Background service survival

Needed only if you call `requestBatteryOptimizationExemption()`. Without the
permission the exemption dialog cannot be shown and the call is a no-op; tracking
still works, but aggressive OEM power management may kill the service.

```xml
<uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" />
```

```dart
final status = await Polyfence.instance.batteryOptimizationStatus();
if (status['isOptimized'] == true && status['canRequest'] == true) {
  await Polyfence.instance.requestBatteryOptimizationExemption();
}
```

## Activity recognition

Needed only when `ActivitySettings.enabled` is `true`. Declare both — the platform
permission and the Play Services one:

```xml
<uses-permission android:name="android.permission.ACTIVITY_RECOGNITION" />
<uses-permission android:name="com.google.android.gms.permission.ACTIVITY_RECOGNITION" />
```

```dart
await Permission.activityRecognition.request();
```

Declining it is safe: GPS intervals fall back to the profile defaults and zone
detection is unaffected.

## Exact alarms for scheduled tracking

Needed only when `ScheduleSettings.enabled` is `true` **and** your schedule windows
must start and stop on the minute.

```xml
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
```

Without it, scheduling still works: on API 31+ the plugin detects that exact alarms
are unavailable and falls back to inexact alarms, so a window may open or close a
few minutes late while the device is dozing. Declare it only if that drift matters
to you — it is subject to Play policy review.

Grant behaviour varies by API level: pre-granted but user-revocable on API 31–33,
and denied by default for apps targeting API 34+, where the user must enable it
under Settings → Apps → Special app access → Alarms & reminders. The plugin checks
`AlarmManager.canScheduleExactAlarms()` before every alarm and picks the fallback
itself, so exact timing is best-effort at every level.

---

## Everything

The full consumer-declared set, for an app that uses every optional feature:

```xml
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
<uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" />
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
<uses-permission android:name="android.permission.ACTIVITY_RECOGNITION" />
<uses-permission android:name="com.google.android.gms.permission.ACTIVITY_RECOGNITION" />
```

A working reference is [`example/android/app/src/main/AndroidManifest.xml`](../example/android/app/src/main/AndroidManifest.xml).

---

## The foreground service declaration

The plugin declares the tracking service, so **you do not need to add it**:

```xml
<service
    android:name="io.polyfence.core.LocationTracker"
    android:foregroundServiceType="location"
    android:stopWithTask="false"
    android:exported="false" />
```

Two properties of that block are worth knowing, because a hand-written copy of it
in your own manifest merges attribute-by-attribute and can override the plugin's:

- `android:foregroundServiceType="location"` is required from API 29. From API 34
  it is hard-enforced — `startForeground()` throws `MissingForegroundServiceTypeException`
  without it, and the app crashes the moment tracking starts.
- The class name must be fully qualified. `LocationTracker` ships in polyfence-core
  under `io.polyfence.core`; a relative name such as `.LocationTracker` resolves
  against your own application id and fails at runtime with `ClassNotFoundException`.

## Verifying the merged result

The merged manifest — not the one you edited — is what Android and the Play Console
actually see. Build once, then read it back:

```bash
flutter build apk --debug
```

```bash
find build -path '*merged_manifests*' -name AndroidManifest.xml -exec grep -h uses-permission {} \; | sort -u
```

Reading it out of the built APK is the stronger check, since that is what actually
ships (`aapt2` lives under `$ANDROID_HOME/build-tools/<version>/`):

```bash
aapt2 dump permissions build/app/outputs/flutter-apk/app-debug.apk
```

If a permission you expect is absent from that list, no runtime request for it will
ever succeed.
