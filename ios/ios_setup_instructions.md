# iOS Setup Instructions for Polyfence

## Required Info.plist Configuration

Add the following keys to your iOS app's `Info.plist` file:

### Background Modes
```xml
<key>UIBackgroundModes</key>
<array>
    <string>location</string>
    <string>background-processing</string>
    <string>background-fetch</string>
</array>
```

### Location Permissions
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Polyfence needs location access to monitor geofence zones when the app is in use.</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Polyfence needs location access to monitor geofence zones in the background for accurate zone detection.</string>

<key>NSLocationAlwaysUsageDescription</key>
<string>Polyfence needs location access to monitor geofence zones in the background for accurate zone detection.</string>
```

### Notification Permissions
```xml
<key>NSUserNotificationUsageDescription</key>
<string>Polyfence sends notifications when you enter or exit geofence zones.</string>
```

## Background App Refresh

Enable Background App Refresh in your iOS app settings to ensure continuous location monitoring.

## Testing Requirements

1. **Real Device Testing**: iOS geofencing requires a real device for testing
2. **Location Services**: Ensure Location Services are enabled
3. **Background App Refresh**: Enable in iOS Settings > General > Background App Refresh
4. **Notification Permissions**: Grant notification permissions when prompted

## Performance Notes

- iOS geofencing engine matches Android performance with sub-10ms detection times
- Background location updates every 5 seconds (configurable)
- Zone persistence survives app restarts
- Error recovery handles GPS failures automatically