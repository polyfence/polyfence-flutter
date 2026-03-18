# Polyfence Example App

A complete example demonstrating all Polyfence features.

## Quick Start

```bash
cd example
flutter run
```

The app works immediately with **no setup required** using hardcoded demo zones.

## Features Demonstrated

This example shows:

- ✅ **Standalone zone management** (hardcoded zones)
- ✅ **API zone fetching** (from polyfence.io)
- ✅ **Delta-based zone sync** (efficient updates)
- ✅ **Real-time geofence events** (entry/exit)
- ✅ **Background tracking** (app minimized/killed)
- ✅ **GPS profile switching** (Android)
- ✅ **Permission handling** (iOS/Android)
- ✅ **Error stream handling**
- ✅ **Battery optimization** (Android)

## Running in Demo Mode (Default)

The app starts with 3 hardcoded demo zones around London landmarks:

```dart
// example/lib/demo_data.dart
class DemoZones {
  static List<Zone> getDemoZones() {
    return [
      Zone.circle(
        id: 'demo-1',
        name: 'Trafalgar Square',
        center: PolyfenceLocation(latitude: 51.5074, longitude: -0.1278),
        radius: 500,
      ),
      // ... more zones
    ];
  }
}
```

**No API key needed. No internet required.**

## Running with Live Zones

To fetch zones from polyfence.io:

1. Get a free API key from [polyfence.io](https://polyfence.io)
2. Edit `example/lib/config.dart`:
   ```dart
   static const bool demoMode = false;
   static const String? apiKey = 'your-api-key-here';
   ```
3. Restart the app

## Code Structure

```
example/
├── lib/
│   ├── main.dart              # Entry point
│   ├── config.dart            # Demo mode / API key config
│   ├── demo_data.dart         # Hardcoded demo zones
│   ├── zone_api_service.dart  # Optional: Fetch zones from polyfence.io
│   └── widgets/               # UI components
└── android/ios/               # Platform-specific config
```

## Key Patterns Demonstrated

### 1. Standalone Mode (No Backend)

```dart
// Hardcode zones directly
final zones = [
  Zone.circle(id: 'office', name: 'Office', ...),
  Zone.circle(id: 'home', name: 'Home', ...),
];

for (var zone in zones) {
  await Polyfence.instance.addZone(zone);
}
```

### 2. API Integration (Polyfence SaaS)

```dart
// Fetch from polyfence.io
final zones = await ZoneApiService.fetchActiveZones();

for (var zone in zones) {
  await Polyfence.instance.addZone(zone);
}
```

### 3. Delta-Based Sync

```dart
// Only update changed zones (efficient)
final existingZoneIds = Polyfence.instance.zones
    .map((z) => z.id)
    .toSet();

final currentZoneIds = zones.map((z) => z.id).toSet();

// Remove deleted zones
final zonesToRemove = existingZoneIds.difference(currentZoneIds);
for (var id in zonesToRemove) {
  await Polyfence.instance.removeZone(id);
}

// Add new zones
final zonesToAdd = currentZoneIds.difference(existingZoneIds);
for (var zone in zones.where((z) => zonesToAdd.contains(z.id))) {
  await Polyfence.instance.addZone(zone);
}
```

### 4. Event Handling

```dart
// Listen for geofence events
Polyfence.instance.onGeofenceEvent.listen((event) {
  switch (event.type) {
    case GeofenceEventType.enter:
      print('Entered ${event.zone?.name ?? event.zoneId}');
      break;
    case GeofenceEventType.exit:
      print('Exited ${event.zone?.name ?? event.zoneId}');
      break;
    case GeofenceEventType.dwell:
      print('Dwelling in ${event.zone?.name ?? event.zoneId}');
      break;
  }
});
```

## Platform Setup

See the main [README Platform Setup](../README.md#platform-setup) section for required permissions and configuration.

## Testing

The app includes visual feedback for:
- Current GPS location
- Active zones (colored by proximity)
- Recent geofence events
- Tracking status
- Battery optimization status

## Troubleshooting

### "No geofence events"
- Ensure "Always" location permission is granted (iOS)
- Check battery optimization is disabled (Android)
- Verify GPS accuracy is good (<100m)
- Make sure you're actually moving in/out of zones

### "Zones not persisting"
- Zones automatically save to local storage
- They persist across app restarts
- Check you're not calling `clearAllZones()` accidentally

### "Background tracking stops"
- iOS: Needs "Always" permission (Settings → Privacy → Location)
- Android: Needs battery optimization exemption

## Learn More

- [Main README](../README.md) - Full documentation
- [API Reference](https://pub.dev/documentation/polyfence/latest/)
- [GitHub Issues](https://github.com/blackabass/polyfence-flutter/issues)
