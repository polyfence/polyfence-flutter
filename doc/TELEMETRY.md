# Polyfence Telemetry Reference

**Last updated:** 2026-05-14
**Plugin version:** 0.14.2

This is the field-by-field technical reference for Polyfence's anonymous telemetry. For the privacy policy (opt-out instructions, legal basis, data retention, your rights), see [PRIVACY.md](../PRIVACY.md).

---

## Complete Telemetry Payload

Here's exactly what gets sent to our analytics endpoint when a session ends:

```json
{
  "app_identifier": "com.example.logistics",
  "platform": "android",
  "plugin_version": "0.14.2",
  "core_version": "1.0.4",

  "industry_category": null,
  "use_case": null,

  "detections_total": 5,
  "detection_time_avg_ms": 125.5,
  "detection_time_p95_ms": 200.0,
  "gps_accuracy_avg_m": 15.2,
  "battery_drain_avg_pct_per_hr": 2.5,
  "session_duration_minutes": 30,

  "zone_usage": { "circle": 3, "polygon": 2 },

  "error_counts": { "gps_timeout": 1 },

  "ttfd_ms": 500,
  "had_detection": true,
  "detection_latency_ms_p95": 200.0,
  "service_interruptions": 0,
  "gps_ok_ratio": 0.95,
  "sample_events": 10,

  "battery_optimization_disabled": true,
  "battery_optimization_check_count": 1,

  "accuracy_profile": "balanced",
  "update_strategy": "continuous",

  "avg_speed_at_event_mps": 3.2,
  "boundary_events_count": 2,

  "false_event_count": 0,

  "battery_level_start": 85.0,
  "battery_level_end": 72.0,

  "activity_distribution": { "still": 0.6, "walking": 0.3, "driving": 0.1 },
  "gps_interval_distribution": { "5000": 0.8, "10000": 0.2 },
  "stationary_ratio": 0.45,
  "avg_gps_interval_ms": 6200.0,
  "zone_count": 3,
  "zone_size_distribution": { "small": 1, "medium": 1, "large": 1 },
  "zone_transition_count": 7,
  "dwell_durations_minutes": [5.0, 12.5, 3.2],
  "avg_dwell_duration_minutes": 6.9,
  "max_dwell_duration_minutes": 12.5,

  "device_category": "google_pixel",
  "os_version_major": 14,
  "charging_during_session": false,

  "bridge_platform": "flutter"
}
```

---

## Field Reference

### Identifiers

| Field | Type | Example | Description |
|-------|------|---------|-------------|
| `app_identifier` | string | `"com.example.logistics"` | App package name (not a user identifier) |
| `platform` | string | `"android"` | Operating system |
| `plugin_version` | string | `"0.14.2"` | Plugin version |
| `bridge_platform` | string | `"flutter"` | Bridge layer (e.g. `flutter`, `react-native`). Set automatically. |
| `core_version` | string | `"1.0.4"` | Native engine version from polyfence-core. Stamped automatically by TelemetryAggregator. |

### Performance Metrics

| Field | Type | Example | Description |
|-------|------|---------|-------------|
| `detections_total` | integer | `5` | Total zone detections in session |
| `detection_time_avg_ms` | float | `125.5` | Average detection time (ms) |
| `detection_time_p95_ms` | float | `200.0` | 95th percentile detection latency |
| `gps_accuracy_avg_m` | float | `15.2` | Average GPS accuracy (meters) |
| `battery_drain_avg_pct_per_hr` | float | `2.5` | Battery drain (% per hour) |
| `session_duration_minutes` | integer | `30` | Session length (minutes) |

### Zone Usage

| Field | Type | Example | Description |
|-------|------|---------|-------------|
| `zone_usage` | object | `{"circle": 3, "polygon": 2}` | Zone type counts only — no coordinates or names |

### Error Tracking

| Field | Type | Example | Description |
|-------|------|---------|-------------|
| `error_counts` | object | `{"gps_timeout": 1}` | Error type counts (`gps_timeout`, `gps_permission_denied`, `service_killed`) |

### Plugin Health

| Field | Type | Example | Description |
|-------|------|---------|-------------|
| `ttfd_ms` | integer | `500` | Time to first detection (ms) |
| `had_detection` | boolean | `true` | Did any detection occur? |
| `detection_latency_ms_p95` | float | `200.0` | P95 detection latency |
| `service_interruptions` | integer | `0` | Service restart count |
| `gps_ok_ratio` | float | `0.95` | GPS accuracy success rate |
| `sample_events` | integer | `10` | Event count |
| `battery_optimization_disabled` | boolean | `true` | Is battery optimization disabled? |
| `battery_optimization_check_count` | integer | `1` | Battery optimization API check count |

### Enhanced Telemetry (v0.12.0+)

#### Config Context

| Field | Type | Example | Description |
|-------|------|---------|-------------|
| `accuracy_profile` | string | `"balanced"` | GPS accuracy profile name |
| `update_strategy` | string | `"continuous"` | Location update strategy |

#### Event Aggregates

| Field | Type | Example | Description |
|-------|------|---------|-------------|
| `avg_speed_at_event_mps` | float | `3.2` | Average speed at detection (m/s) |
| `boundary_events_count` | integer | `2` | Events within 50m of zone boundary |
| `false_event_count` | integer | `0` | Enter/exit reversals within 30s |

#### Battery

| Field | Type | Example | Description |
|-------|------|---------|-------------|
| `battery_level_start` | float | `85.0` | Battery % at session start |
| `battery_level_end` | float | `72.0` | Battery % at session end |

#### Native Session Context

| Field | Type | Example | Description |
|-------|------|---------|-------------|
| `activity_distribution` | object | `{"still": 0.6, "walking": 0.3}` | Time proportion per activity type |
| `gps_interval_distribution` | object | `{"5000": 0.8}` | Time proportion per GPS interval (ms) |
| `stationary_ratio` | float | `0.45` | Proportion of session spent stationary |
| `avg_gps_interval_ms` | float | `6200.0` | Average GPS poll interval (ms) |
| `zone_count` | integer | `3` | Number of active zones |
| `zone_size_distribution` | object | `{"small": 1, "medium": 1}` | Zone count by size bucket (abstract, not dimensions) |
| `zone_transition_count` | integer | `7` | Total zone state changes |
| `dwell_durations_minutes` | array | `[5.0, 12.5]` | Individual dwell durations |
| `avg_dwell_duration_minutes` | float | `6.9` | Average dwell time (minutes) |
| `max_dwell_duration_minutes` | float | `12.5` | Maximum dwell time (minutes) |

#### Device Context

| Field | Type | Example | Description |
|-------|------|---------|-------------|
| `device_category` | string | `"google_pixel"` | Device manufacturer/tier bucket (not specific model) |
| `os_version_major` | integer | `14` | OS major version |
| `charging_during_session` | boolean | `false` | Was device charging during session? |

---

## Session Lifecycle

```
App Launch → initialize() → Session Start → Data Collection → App Background → Session End → Send Telemetry
```

Sessions are managed automatically via `AppLifecycleManager`. No manual session management needed.

---

## Debug Disclosure

In debug builds, the plugin shows a one-time disclosure message about telemetry state:

- Shows once per install (not every run)
- Shows again if telemetry state changes (enable/disable toggle)
- Only in debug builds — production logs stay clean
- Uses SharedPreferences to track disclosure state

---

## Verify What's Sent

The plugin is open source. Verify the telemetry implementation directly:

- **Telemetry code:** [`lib/src/services/analytics_service.dart`](../lib/src/services/analytics_service.dart)
- **Key methods:** `_sendSessionSummary()` builds and sends the payload
- **Network inspection:** Use Charles Proxy or Wireshark to inspect actual HTTP requests

---

## Changelog

### 2026-04-03
- Added `core_version` field — native engine version from polyfence-core, stamped automatically by TelemetryAggregator (D043). Not a user identifier.

### 2026-03-27 (added in v0.13)
- Added `bridge_platform` field — identifies which bridge layer produced the session (e.g. `flutter`, `react-native`). Set automatically by the plugin during initialization. Not a user identifier.

### 2026-03-07 (v0.12.0)
- Added 21 enhanced telemetry fields (config context, event aggregates, native session context, device context, battery levels)
- No new fields contain GPS coordinates, zone definitions, or user identifiers

### 2026-03-18 (v0.12.4)
- Reverted telemetry to opt-out (enabled by default) per D008

### 2025-12-29 (v0.3.0)
- Added `disableTelemetry` parameter
- Added smart disclosure message (once per install, debug-only)
- Removed API key requirement for telemetry
- Updated data retention to 24 months
