# Security Policy

## Supported Versions

We actively support the following versions with security updates:

| Version | Supported          |
| ------- | ------------------ |
| 3.0.x   | :white_check_mark: |
| < 3.0   | :x:                |

## Reporting a Vulnerability

**Please do NOT report security vulnerabilities through public GitHub issues.**

Instead, please report them responsibly by emailing:

**hello@polyfence.io**

You should receive a response within 48 hours. If for some reason you do not, please follow up via email to ensure we received your original message.

### What to Include

When reporting a vulnerability, please include:

- **Type of vulnerability** (e.g., unauthorized location access, data leak, etc.)
- **Full paths of affected files**
- **Step-by-step instructions** to reproduce the issue
- **Proof of concept** or exploit code (if possible)
- **Impact assessment** - how severe is this vulnerability?
- **Your contact information** for follow-up questions

### What to Expect

1. **Acknowledgment** within 48 hours
2. **Initial assessment** within 5 business days
3. **Regular updates** as we investigate and develop a fix
4. **Credit** in the security advisory (if you want)

### Our Commitment

- We will keep you informed throughout the process
- We will not take legal action against security researchers who follow this policy
- We will credit you in security advisories (unless you prefer anonymity)
- We aim to patch critical vulnerabilities within 7 days

## Security Best Practices

### For Developers Using Polyfence

1. **API Keys**
   - Never commit API keys to version control
   - Use environment variables or secure storage
   - Rotate keys regularly

   **Example: Secure API Key Storage**

   API keys are only required for the Polyfence.io REST API. The anonymous
   telemetry pipeline does NOT require an API key and is enabled by default —
   see [PRIVACY.md](PRIVACY.md) and [doc/TELEMETRY.md](doc/TELEMETRY.md) for the
   canonical one-line opt-out.

   **Option 1: Environment Variables (Recommended for CI/CD)**

   ```dart
   // Load from environment at build time
   const String? apiKey = String.fromEnvironment('POLYFENCE_API_KEY');
   ```

   Build command:
   ```bash
   flutter build apk --dart-define=POLYFENCE_API_KEY=your_key_here
   ```

   **Option 2: flutter_secure_storage (Recommended for Runtime)**

   ```dart
   import 'package:flutter_secure_storage/flutter_secure_storage.dart';

   class ApiKeyManager {
     static const _storage = FlutterSecureStorage();

     static Future<String?> getApiKey() async {
       return await _storage.read(key: 'polyfence_api_key');
     }

     static Future<void> saveApiKey(String key) async {
       await _storage.write(key: 'polyfence_api_key', value: key);
     }
   }
   ```

2. **Location Data**
   - Polyfence stores zones locally (SharedPreferences/UserDefaults)
   - Zone data is NOT encrypted by default
   - For sensitive use cases, encrypt zone data before passing to Polyfence

   **Example: Encrypting Sensitive Zones**

   If your zones contain private locations (home addresses, sensitive facilities), encrypt the coordinates using `flutter_secure_storage`:

   ```dart
   import 'package:flutter_secure_storage/flutter_secure_storage.dart';
   import 'package:polyfence/polyfence.dart';

   class SecureZoneManager {
     static const _storage = FlutterSecureStorage();

     // Store coordinates securely
     static Future<void> storeSecureZone({
       required String zoneId,
       required double latitude,
       required double longitude,
     }) async {
       await _storage.write(
         key: 'zone_coords_$zoneId',
         value: '$latitude,$longitude',
       );
     }

     // Retrieve coordinates when needed
     static Future<PolyfenceLocation?> getSecureCoordinates(String zoneId) async {
       final coords = await _storage.read(key: 'zone_coords_$zoneId');
       if (coords == null) return null;

       final parts = coords.split(',');
       return PolyfenceLocation(
         latitude: double.parse(parts[0]),
         longitude: double.parse(parts[1]),
       );
     }
   }
   ```

   **Note:** For most use cases (public venues, offices, stores), zone encryption is unnecessary. The default unencrypted storage is acceptable.

3. **Analytics**
   - Anonymous telemetry is opt-out: enabled by default. It never contains coordinates or end-user identifiers, but it does carry aggregates derived from location
   - Disable with: `AnalyticsConfig(disableTelemetry: true)`
   - Review `AnalyticsConfig` settings and see `doc/TELEMETRY.md` for full details

4. **Permissions**
   - Request minimum necessary permissions
   - Explain to users why "Always" location is needed
   - Provide opt-out mechanisms

### Known Security Considerations

**Zone Data Storage**
- Zones are stored unencrypted in local storage
- Any app with file system access could theoretically read zone data
- **Mitigation**: Don't store sensitive information in zone metadata

**Location Privacy**
- Polyfence processes positions on the device
- Positions never leave the device. Telemetry, on by default, carries aggregates derived from them (see `doc/TELEMETRY.md`)
- **Mitigation**: Review the telemetry fields, or turn telemetry off with `AnalyticsConfig(disableTelemetry: true)`

**Background Tracking**
- iOS/Android require "Always" location permission for background geofencing
- Users should be informed about background tracking
- **Mitigation**: Clear privacy policy, obvious UI indicators

---

## iOS Deployment Notes

### Time-Critical Alerts (Optional, Downstream)

If your app needs zone events to break through Do Not Disturb / Silent mode / Focus — for example perimeter security, anti-theft, child safety, fall detection, or medication adherence — you'll want Apple's [Critical Alerts entitlement](https://developer.apple.com/contact/request/notifications-critical-alerts-entitlement/). Polyfence fires events to your code; surfacing them with `.criticalAlert` is your app's responsibility and requires this entitlement, applied for via the form linked above.

This is **not** required for normal use cases — standard "you arrived at the office" notifications work fine without it. The entitlement is specifically for time-critical safety / security scenarios where breaking through DND is essential.

### App Store Submission — Background Location Review

Apple reviewers scrutinize apps that declare `UIBackgroundModes: location` and request Always permission. To smooth review:

- **Justify Always permission in plain language.** Reviewers want to understand the user-visible benefit, not just the technical capability ("we need Always to fire reminders when you arrive at a saved location, even when the app is closed").
- **Include a brief screen recording** in your TestFlight build showing the location-driven feature working. Helps avoid a reject + resubmit cycle.
- **Link your privacy policy from the app's settings screen**, not just from the App Store listing — reviewers check both.

---

## Privacy Policy Guidance

Telemetry fields, legal basis, retention, and opt-out are documented in **[PRIVACY.md](./PRIVACY.md)** and the technical payload reference **[doc/TELEMETRY.md](./doc/TELEMETRY.md)**. Use those sources as the source of truth so your public policy stays aligned with what the plugin actually sends.

When submitting apps using Polyfence to the App Store, include the following in your privacy policy:

### Location Data Usage Template

```
[Your App Name] uses background location services to provide geofence-based
features. Your position is processed on your device by the Polyfence SDK,
which does not send it to external servers.

We use the Polyfence open-source SDK for geofencing. By default, Polyfence:
- Processes your position locally on your device
- Does not send your position to any external server
- Stores geofence zone definitions locally in device storage

Polyfence also sends usage statistics to polyfence.io by default, each time
the app goes to the background or shuts Polyfence down, with totals since
tracking started. They include GPS accuracy averages, battery level and usage,
detection latency, average speed at zone events, time spent in zones, the mix
of activities such as walking or driving, the hour tracking started, the
device maker and class (for example, Samsung flagship) and OS version, and
this app's package name. They do NOT include your GPS coordinates, your
location history or anything that names you.
Polyfence's servers see your device's IP address when the statistics arrive,
as with any internet request; Polyfence does not keep it with them. [Delete
this paragraph if your app turns Polyfence telemetry off.]

You can disable location services at any time in your device Settings.
```

### Data Retention Template

```
Geofence zone definitions are stored locally on your device and persist until:
- You delete the app
- You clear app data via device Settings
- You explicitly remove zones within the app

Your GPS coordinates are not sent to or retained on external servers by the
Polyfence SDK.
```

## Security Updates

Security updates will be released as patch versions (e.g., 3.0.1) and announced via:

- GitHub Security Advisories
- CHANGELOG.md
- pub.dev package notes

Subscribe to repository releases to get notifications.

## Third-Party Dependencies

We regularly audit our dependencies for security vulnerabilities:

- `http` - HTTP client (official Dart package)
- `shared_preferences` - Local storage (official Flutter package)
- `package_info_plus` - Package metadata (community package)
- `uuid` - UUID generation (community package)

All dependencies are from trusted sources and actively maintained.

## Contact

- **Security vulnerabilities, privacy practices, or general inquiries**: hello@polyfence.io
- **Technical questions**: Open a GitHub issue with `question` label
- **Commercial support**: https://polyfence.io

Thank you for helping keep Polyfence and our users safe!
