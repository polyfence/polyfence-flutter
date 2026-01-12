# DEFECT-001: Missing GPS Coordinates in Geofence Events

## Summary
Geofence events (ENTER/EXIT) are sent to Flutter without GPS coordinates (latitude/longitude), causing downstream sync failures in apps that require location data.

## Severity
**High** - Affects apps that need to sync geofence events with backend APIs requiring location data.

## Affected Version
v0.4.0 and earlier

## Symptoms
1. Flutter side receives geofence events with `latitude: null` and `longitude: null`
2. Plugin emits warning: `Missing GPS coordinates in geofence event - using 0.0 fallback`
3. Apps that sync events to APIs fail with "missing required fields: latitude, longitude"

## Root Cause
In `PolyfencePlugin.kt`, the `sendGeofenceEvent` function does not include latitude/longitude:

```kotlin
// Current implementation (missing coordinates)
fun sendGeofenceEvent(zoneId: String, zoneName: String, eventType: String,
                      detectionTimeMs: Double = 0.0, gpsAccuracy: Double = 0.0) {
    val event = mapOf(
        "zoneId" to zoneId,
        "zoneName" to zoneName,
        "eventType" to eventType,
        "timestamp" to System.currentTimeMillis(),
        "detectionTimeMs" to detectionTimeMs,
        "gpsAccuracy" to gpsAccuracy
        // ← latitude and longitude NOT included
    )
    geofenceSink?.success(event)
}
```

However, the `GeofenceEngine` callback DOES provide the location:
```kotlin
geofenceEngine.setEventCallback { zoneId, eventType, location, detectionTimeMs ->
    // location is available here but not passed to sendGeofenceEvent
}
```

## Why Test App Was Not Affected
The test app does not USE `event.location` for any critical functionality:
- It only displays zone name and event type in the events list
- Distance calculations use `onLocationUpdate` stream, not geofence event data

## Fix Required
Update `sendGeofenceEvent` to accept and include latitude/longitude:

```kotlin
fun sendGeofenceEvent(zoneId: String, zoneName: String, eventType: String,
                      latitude: Double, longitude: Double,
                      detectionTimeMs: Double = 0.0, gpsAccuracy: Double = 0.0) {
    val event = mapOf(
        "zoneId" to zoneId,
        "zoneName" to zoneName,
        "eventType" to eventType,
        "timestamp" to System.currentTimeMillis(),
        "latitude" to latitude,
        "longitude" to longitude,
        "detectionTimeMs" to detectionTimeMs,
        "gpsAccuracy" to gpsAccuracy
    )
    geofenceSink?.success(event)
}
```

And update the caller in `LocationTracker.kt` to pass the location coordinates.

## Files to Modify
1. `android/src/main/kotlin/com/polyfence/polyfence/flutter/PolyfencePlugin.kt`
2. `android/src/main/kotlin/com/polyfence/polyfence/core/LocationTracker.kt`

## Testing
1. Build test app with fix
2. Enter a zone
3. Verify geofence event includes valid latitude/longitude
4. Verify no "Missing GPS coordinates" warning in error stream

## Reported By
Roadie mobile app team

## Date Reported
2026-01-12
