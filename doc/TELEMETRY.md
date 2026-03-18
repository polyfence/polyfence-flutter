# Polyfence Telemetry Reference

**Last updated:** 2026-03-18
**Plugin version:** 0.12.4

---

## Overview

Polyfence supports **anonymous plugin performance telemetry** to help monitor reliability, detect issues early, and improve the plugin across different devices and platforms. **Telemetry is opt-in** — it is disabled by default and must be explicitly enabled by the developer.

**This document provides complete transparency about what data is collected and how it's used.**

---

## Quick Summary

✅ **What's sent (when enabled):** Anonymous plugin performance metrics
❌ **What's NEVER sent:** GPS coordinates, location data, zone definitions, user PII
🔧 **Default:** Off. Enable with `AnalyticsConfig(enabled: true)`
📊 **Purpose:** Monitor plugin performance, detect issues, improve reliability

---

## Complete Telemetry Payload

Here's **exactly** what gets sent to our analytics endpoint when a session ends:

### Session Payload Structure

```json
{
  // App/Platform Identifiers (NOT user identifiers)
  "app_identifier": "com.example.logistics",
  "platform": "android",
  "plugin_version": "0.12.0",

  // Optional Developer Metadata
  "industry_category": null,
  "use_case": null,

  // Performance Metrics
  "detections_total": 5,
  "detection_time_avg_ms": 125.5,
  "detection_time_p95_ms": 200.0,
  "gps_accuracy_avg_m": 15.2,
  "battery_drain_avg_pct_per_hr": 2.5,
  "session_duration_minutes": 30,

  // Zone Usage (types only, no coordinates)
  "zone_usage": {
    "circle": 3,
    "polygon": 2
  },

  // Error Tracking
  "error_counts": {
    "gps_timeout": 1
  },

  // Plugin Performance
  "ttfd_ms": 500,
  "had_detection": true,
  "detection_latency_ms_p95": 200.0,
  "service_interruptions": 0,
  "gps_ok_ratio": 0.95,
  "sample_events": 10,

  // Battery Optimization Tracking
  "battery_optimization_disabled": true,
  "battery_optimization_check_count": 1,

  // --- Enhanced Telemetry (v0.12.0) ---

  // Config Context
  "accuracy_profile": "balanced",
  "update_strategy": "continuous",

  // Per-Event Aggregates
  "avg_speed_at_event_mps": 3.2,
  "boundary_events_count": 2,

  // False Event Detection
  "false_event_count": 0,

  // Battery Levels
  "battery_level_start": 85.0,
  "battery_level_end": 72.0,

  // Native Session Context (from platform engines)
  "activity_distribution": {
    "still": 0.6,
    "walking": 0.3,
    "driving": 0.1
  },
  "gps_interval_distribution": {
    "5000": 0.8,
    "10000": 0.2
  },
  "stationary_ratio": 0.45,
  "avg_gps_interval_ms": 6200.0,
  "zone_count": 3,
  "zone_size_distribution": {
    "small": 1,
    "medium": 1,
    "large": 1
  },
  "zone_transition_count": 7,
  "dwell_durations_minutes": [5.0, 12.5, 3.2],
  "avg_dwell_duration_minutes": 6.9,
  "max_dwell_duration_minutes": 12.5,

  // Device Context
  "device_category": "google_pixel",
  "os_version_major": 14,
  "charging_during_session": false
}
```

---

## Field-by-Field Explanation

### Identifiers

| Field | Type | Example | Description | Why We Need It |
|-------|------|---------|-------------|----------------|
| `app_identifier` | string | `"com.example.logistics"` | App package name | Identify which apps use the plugin |
| `platform` | string | `"android"` or `"ios"` | Operating system | Platform-specific issue detection |
| `plugin_version` | string | `"0.2.5"` | Plugin version | Track version-specific bugs |

**Important:** `app_identifier` is the app **package name**, not a user identifier. It tells us "Company X's logistics app" but nothing about individual users.

### Performance Metrics

| Field | Type | Example | Description | Why We Need It |
|-------|------|---------|-------------|----------------|
| `detections_total` | integer | `5` | Total zone detections | Measure plugin usage |
| `detection_time_avg_ms` | float | `125.5` | Average detection time (ms) | Monitor performance |
| `detection_time_p95_ms` | float | `200.0` | 95th percentile latency | Identify slow detections |
| `gps_accuracy_avg_m` | float | `15.2` | Average GPS accuracy (meters) | Track GPS quality |
| `battery_drain_avg_pct_per_hr` | float | `2.5` | Battery usage (% per hour) | Optimize battery impact |
| `session_duration_minutes` | integer | `30` | Session length (minutes) | Context for metrics |

### Zone Usage

| Field | Type | Example | Description | Why We Need It |
|-------|------|---------|-------------|----------------|
| `zone_usage` | object | `{"circle": 3, "polygon": 2}` | Zone type counts | Optimize zone type performance |

**Important:** Only zone **types** (circle/polygon) and **counts** are sent. **No zone coordinates, addresses, or names** are transmitted.

### Error Tracking

| Field | Type | Example | Description | Why We Need It |
|-------|------|---------|-------------|----------------|
| `error_counts` | object | `{"gps_timeout": 1}` | Error type counts | Identify common failure modes |

**Example error types:**
- `gps_timeout` - GPS signal lost
- `gps_permission_denied` - Permission issues
- `service_killed` - Background service terminated

### Plugin Performance

| Field | Type | Example | Description | Why We Need It |
|-------|------|---------|-------------|----------------|
| `ttfd_ms` | integer | `500` | Time to first detection (ms) | Monitor startup performance |
| `had_detection` | boolean | `true` | Did any detection occur? | Track successful sessions |
| `detection_latency_ms_p95` | float | `200.0` | P95 detection latency | Identify slow edge cases |
| `service_interruptions` | integer | `0` | Service restart count | Detect reliability issues |
| `gps_ok_ratio` | float | `0.95` | GPS accuracy success rate | Monitor GPS quality |
| `sample_events` | integer | `10` | Event count | Context for metrics |

### Battery Optimization

| Field | Type | Example | Description | Why We Need It |
|-------|------|---------|-------------|----------------|
| `battery_optimization_disabled` | boolean | `true` | Is optimization disabled? | Track user configuration |
| `battery_optimization_check_count` | integer | `1` | Check count | Monitor API usage |

### Enhanced Telemetry (v0.12.0)

These fields provide ML training context for improving geofence detection algorithms.

#### Config Context

| Field | Type | Example | Description | Why We Need It |
|-------|------|---------|-------------|----------------|
| `accuracy_profile` | string | `"balanced"` | GPS accuracy profile name | Correlate performance with config |
| `update_strategy` | string | `"continuous"` | Update strategy name | Correlate performance with config |

#### Per-Event Aggregates

| Field | Type | Example | Description | Why We Need It |
|-------|------|---------|-------------|----------------|
| `avg_speed_at_event_mps` | float | `3.2` | Average speed at detection (m/s) | Correlate speed with detection accuracy |
| `boundary_events_count` | integer | `2` | Events within 50m of zone boundary | Measure boundary precision |

#### False Event Detection

| Field | Type | Example | Description | Why We Need It |
|-------|------|---------|-------------|----------------|
| `false_event_count` | integer | `0` | Enter/exit reversals within 30s | Measure detection reliability |

#### Battery Levels

| Field | Type | Example | Description | Why We Need It |
|-------|------|---------|-------------|----------------|
| `battery_level_start` | float | `85.0` | Battery % at session start | Precise battery impact tracking |
| `battery_level_end` | float | `72.0` | Battery % at session end | Precise battery impact tracking |

#### Native Session Context

| Field | Type | Example | Description | Why We Need It |
|-------|------|---------|-------------|----------------|
| `activity_distribution` | object | `{"still": 0.6, "walking": 0.3}` | Time proportion per activity | Correlate activity with GPS strategy |
| `gps_interval_distribution` | object | `{"5000": 0.8}` | Time proportion per GPS interval | Understand adaptive GPS behavior |
| `stationary_ratio` | float | `0.45` | Proportion of time stationary | Optimize stationary detection |
| `avg_gps_interval_ms` | float | `6200.0` | Average GPS poll interval (ms) | Monitor GPS polling behavior |
| `zone_count` | integer | `3` | Number of active zones | Context for performance metrics |
| `zone_size_distribution` | object | `{"small": 1, "medium": 1}` | Zone count by size bucket | Optimize for common zone sizes |
| `zone_transition_count` | integer | `7` | Total zone state changes | Measure detection activity |
| `dwell_durations_minutes` | array | `[5.0, 12.5]` | Individual dwell durations | Analyze dwell patterns |
| `avg_dwell_duration_minutes` | float | `6.9` | Average dwell time (minutes) | Summarize dwell behavior |
| `max_dwell_duration_minutes` | float | `12.5` | Maximum dwell time (minutes) | Identify long-dwell sessions |

#### Device Context

| Field | Type | Example | Description | Why We Need It |
|-------|------|---------|-------------|----------------|
| `device_category` | string | `"google_pixel"` | Device manufacturer/tier bucket | Correlate performance with hardware |
| `os_version_major` | integer | `14` | OS major version | Track platform-specific behavior |
| `charging_during_session` | boolean | `false` | Was device charging? | Correlate battery with charging state |

**Privacy note:** `device_category` is a broad bucket (e.g., "samsung_mid", "google_pixel", "iphone_flagship"), not a specific model identifier. `zone_size_distribution` uses abstract buckets (small/medium/large), not actual dimensions.

---

## What is NEVER Sent

The following data is **never transmitted** under any circumstances:

### Location Data
- ❌ GPS coordinates (latitude/longitude)
- ❌ Zone definitions or boundaries
- ❌ Zone addresses or names
- ❌ User location history
- ❌ Movement patterns

### Personal Information
- ❌ User names, emails, phone numbers
- ❌ Device identifiers (IMEI, serial number, advertising ID)
- ❌ User account information
- ❌ Cross-app tracking identifiers

### Sensitive Data
- ❌ Zone configuration details
- ❌ App-specific business logic
- ❌ User behavior patterns
- ❌ Any data that could identify an individual user

---

## When is Telemetry Sent?

### Session Lifecycle

1. **Session Start:** When `Polyfence.instance.initialize()` is called
2. **Data Collection:** Metrics collected automatically during tracking
3. **Session End:** When app lifecycle changes (background/terminated)
4. **Transmission:** Session summary sent to analytics endpoint

### Automatic Session Management

The plugin automatically manages sessions based on app lifecycle:

```
App Launch → Session Start → Data Collection → App Background → Session End → Send Telemetry
```

**You don't need to manually manage sessions** - the plugin handles this via `AppLifecycleManager`.

---

## How to Enable Telemetry

Telemetry is disabled by default. To opt in:

```dart
import 'package:polyfence/polyfence.dart';

await Polyfence.instance.initialize(
  analyticsConfig: AnalyticsConfig(
    enabled: true, // ← Enable anonymous telemetry
  ),
);
```

To explicitly disable (or re-disable after enabling):

```dart
await Polyfence.instance.initialize(
  analyticsConfig: AnalyticsConfig(
    disableTelemetry: true, // ← Ensure telemetry is off
  ),
);
```

### Disclosure Messages

In debug builds, the plugin shows a one-time disclosure message about telemetry state:

**Disclosure behavior:**
- Shows **once per install** (not every time you run the app)
- Shows **again if telemetry state changes** (when you enable/disable it)
- Only shows in **debug builds** (production logs stay clean)
- Uses SharedPreferences to track disclosure state

This means:
- ✅ First run (debug): See disclosure
- ✅ Second run (debug): No message (already shown)
- ✅ Toggle telemetry: See updated disclosure
- ✅ Production builds: Zero disclosure messages

---

## How the Data is Used

### Primary Uses

1. **Performance Monitoring**
   - Detect slow zone detections across devices
   - Identify platform-specific issues
   - Track battery impact trends

2. **Error Detection**
   - Identify common failure patterns
   - Prioritize bug fixes
   - Improve error handling

3. **Platform Distribution**
   - Understand Android vs iOS usage
   - Prioritize platform-specific work
   - Optimize for common configurations

4. **Product Decisions**
   - Measure feature adoption (e.g., polygon vs circle zones)
   - Identify performance bottlenecks
   - Guide optimization efforts

### What We Don't Do

- ❌ **No user tracking** - We can't identify individual users
- ❌ **No selling data** - Telemetry data is never sold or shared with third parties
- ❌ **No cross-app tracking** - We don't link data across different apps
- ❌ **No marketing** - Telemetry is not used for advertising or marketing

---

## Data Retention

**Retention Period:** 24 months (2 years)

Telemetry data is automatically deleted after 24 months. We retain data to:
- Identify long-term trends and patterns
- Debug issues reported by developers
- Measure performance improvements over time
- Track year-over-year trends
- Compare performance across plugin versions
- Analyze multi-year adoption patterns

After 24 months, all telemetry data is permanently deleted from our systems.

**Why 24 months?** This duration allows us to:
- Maintain sufficient history for meaningful trend analysis
- Compare performance year-over-year with historical context
- Identify seasonal patterns and long-term trends
- Support strategic product decisions with deeper insights
- Correlate performance across major plugin version releases

**You can request earlier deletion:** Contact hello@polyfence.io to request deletion of your app's telemetry data at any time.

---

## Security & Privacy

### Transmission Security

- **HTTPS Only:** All telemetry is sent over encrypted HTTPS
- **Idempotency:** Duplicate sessions are automatically deduplicated
- **Retry Mechanism:** Failed requests are retried automatically (with local storage)

### Privacy Safeguards

- **No PII:** Telemetry contains no personally identifiable information
- **Anonymous:** Session data cannot be linked to individual users
- **Aggregated Analysis:** Data is analyzed in aggregate, not per-user
- **Open Source:** Plugin code is open source—verify what's sent

### API Key (Optional)

Telemetry does **not** require an API key. API keys are only needed for additional Polyfence.io services (zone management, advanced analytics dashboard).

---

## GDPR & CCPA Compliance

### GDPR (Europe)

**Is this compliant?** Yes.

- ✅ **No personal data:** App package name is not personal data
- ✅ **Legitimate interest:** Improving plugin performance is a valid legal basis
- ✅ **Easy opt-out:** One-line opt-out mechanism provided
- ✅ **Transparent:** Full disclosure of data collected
- ✅ **No location data:** GPS coordinates are never transmitted

**Legal Basis:** Legitimate interest (Article 6(1)(f) GDPR) - improving our plugin's performance and reliability.

### CCPA (California)

**Is this compliant?** Yes.

- ✅ **No personal information:** Telemetry contains no personal information as defined by CCPA
- ✅ **No selling:** Data is never sold to third parties
- ✅ **Legitimate use:** Product improvement only
- ✅ **Easy opt-out:** One-line opt-out mechanism provided

---

## Verification & Transparency

### Verify What's Sent

The plugin is **open source**. You can verify exactly what's sent by reading the code:

**Telemetry code:** [`lib/src/services/analytics_service.dart`](../lib/src/services/analytics_service.dart)

**Key methods:**
- `_sendSessionSummary()` - Sends telemetry payload
- `toSessionSummary()` - Builds session payload

### Test Telemetry Locally

To see what telemetry would be sent:

```dart
// Enable telemetry in a test app
await Polyfence.instance.initialize();

// Trigger some detections
await Polyfence.instance.addZone(Zone.circle(...));
await Polyfence.instance.startTracking();

// Use network inspection tools (Charles Proxy, Wireshark) to verify the payload
```

**Network inspection:** Use Charles Proxy or Wireshark to inspect network calls and verify the payload.

---

## Frequently Asked Questions

### Can I use Polyfence without sending telemetry?

**Yes.** Telemetry is disabled by default. You don't need to do anything — just don't enable it.

### Will disabling telemetry affect plugin functionality?

**No.** All plugin features work identically with telemetry enabled or disabled. Telemetry is purely for our monitoring and does not affect zone detection, background tracking, or any other feature.

### Can you identify individual users from telemetry?

**No.** The telemetry contains no user identifiers, device identifiers, or location data. We can only see aggregated metrics per app package name (e.g., "this logistics app had 10 detections with 150ms average latency").

### What if I don't want to share my app package name?

**Opt-out of telemetry.** The app package name is the only app-specific identifier we collect. If you don't want to share it, disable telemetry entirely.

### Do you share telemetry data with third parties?

**No.** Telemetry data is used exclusively for improving the Polyfence plugin. We never sell, share, or provide this data to third parties.

### Can I see what data you've collected from my app?

**Contact us.** While we store telemetry in aggregated form, you can contact us at [hello@polyfence.io](mailto:hello@polyfence.io) to inquire about data collected from your specific app package.

### How do I know you're not sending location data?

**Verify the code.** The plugin is open source. Read [`analytics_service.dart`](../lib/src/services/analytics_service.dart) and confirm that GPS coordinates are never included in the telemetry payload. You can also use network inspection tools to verify the actual HTTP requests.

---

## Contact & Feedback

### Questions About Telemetry?

- **Email:** [hello@polyfence.io](mailto:hello@polyfence.io)
- **GitHub Issues:** [Report a concern](https://github.com/blackabass/polyfence-flutter/issues)

### Privacy Policy

For the full privacy policy, see: [https://polyfence.io/privacy](https://polyfence.io/privacy)

---

## Changelog

### 2026-03-07 (Version 0.12.0)
- **Added:** 21 enhanced telemetry fields for ML training context
- **Added:** Config context (accuracy_profile, update_strategy)
- **Added:** Per-event aggregates (avg_speed_at_event_mps, boundary_events_count)
- **Added:** False event detection (false_event_count)
- **Added:** Native session context (activity_distribution, gps_interval_distribution, stationary_ratio, zone metrics, dwell durations)
- **Added:** Device context (device_category, os_version_major, charging_during_session)
- **Added:** Battery level snapshots (battery_level_start, battery_level_end)
- **Privacy:** No new fields contain GPS coordinates, zone definitions, or user identifiers

### 2026-03-18 (Version 0.12.4)
- **Changed:** Telemetry is now opt-in (disabled by default). Developers must explicitly enable it.
- **Updated:** Documentation to reflect opt-in approach

### 2025-12-29 (Version 0.3.0)
- **Added:** `disableTelemetry` parameter
- **Added:** Smart disclosure message (once per install, debug-only, state-aware)
- **Removed:** API key requirement for telemetry
- **Updated:** Data retention to 24 months (2 years)

---

**Summary:** Polyfence telemetry is anonymous, transparent, and opt-in. When enabled, we collect plugin performance metrics to improve reliability, but we never transmit location data, zone definitions, or personal information.
