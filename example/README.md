# Polyfence Flutter Example

A complete example app demonstrating the Polyfence Flutter SDK end-to-end:
zone sync, real-time geofence events, background tracking, GPS accuracy
profiles, and live position on a map.

## What you'll see

- **Dashboard** — tracking status, current position, accuracy/speed/activity,
  GPS profile selector, the zones you've defined in your Polyfence account,
  and a live event feed (enter/exit/dwell).
- **Map** — your position over OpenStreetMap tiles, with a zone counter
  and tracking indicator overlay.

## Prerequisites

- Flutter ≥ 3.10
- iOS 14+ or Android API 24+
- A **free Polyfence API key** — sign up at
  [polyfence.io](https://polyfence.io). You'll define zones in the Polyfence
  dashboard; this example renders whichever ones are active on your account.

## Run it

The API key is supplied at build/run time via `--dart-define`:

```bash
cd example
flutter pub get
flutter run --dart-define=POLYFENCE_API_KEY=pf_live_xxx
```

Without the define, the Dashboard renders an empty-state card that surfaces
the exact command to re-run. The Map tab still works (shows your position
with zero zones) so you can sanity-check location permissions without a key.

## Permissions

The example asks for:

- **Location (always)** — required for background tracking. On iOS this
  is "Always" in Settings → Privacy → Location.
- **Notifications** (Android 13+) — used by the plugin's foreground
  service while tracking.
- **Activity recognition** (Android) — optional. Powers the SmartGPS
  intelligent strategy. The example continues to work without it.

## Where to look in the code

| File | What it does |
|---|---|
| `lib/main.dart` | App shell, plugin init, tracking control, zone delta sync, navigation |
| `lib/api_key_store.dart` | Single read point for the `POLYFENCE_API_KEY` dart-define |
| `lib/zone_api_service.dart` | HTTP client for the Polyfence Zone API |
| `lib/screens/map_screen.dart` | OSM map with current position |
| `lib/widgets/` | Dashboard cards (status, GPS profile, zones, events) |

## Plugin docs

For the plugin's full API, telemetry behaviour, and platform setup, see
the main [README](../README.md) at the repository root.
