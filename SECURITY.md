# Security Policy

## Supported Versions

We actively support the following versions with security updates:

| Version | Supported          |
| ------- | ------------------ |
| 0.13.x  | :white_check_mark: |
| 0.12.x  | :white_check_mark: |
| 0.11.x  | :white_check_mark: |
| 0.10.x  | :white_check_mark: |
| < 0.10  | :x:                |

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

   **Option 1: Environment Variables (Recommended for CI/CD)**

   ```dart
   // Load from environment at build time
   const String? apiKey = String.fromEnvironment('POLYFENCE_API_KEY');

   await Polyfence.instance.initialize(
     analyticsConfig: AnalyticsConfig(
       enabled: apiKey != null,
       apiKey: apiKey,
     ),
   );
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

   // Usage
   final apiKey = await ApiKeyManager.getApiKey();
   await Polyfence.instance.initialize(
     analyticsConfig: AnalyticsConfig(
       enabled: apiKey != null,
       apiKey: apiKey,
     ),
   );
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
   - Anonymous telemetry is opt-out — enabled by default (no location data or PII)
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
- Polyfence processes location data on-device
- No location data leaves the device by default
- **Mitigation**: Audit analytics configuration before enabling

**Background Tracking**
- iOS/Android require "Always" location permission for background geofencing
- Users should be informed about background tracking
- **Mitigation**: Clear privacy policy, obvious UI indicators

---

## Privacy Policy Guidance

Telemetry fields, legal basis, retention, and opt-out are documented in **[PRIVACY.md](./PRIVACY.md)** and the technical payload reference **[doc/TELEMETRY.md](./doc/TELEMETRY.md)**. Use those sources as the source of truth so your public policy stays aligned with what the plugin actually sends.

When submitting apps using Polyfence to the App Store, include the following in your privacy policy:

### Location Data Usage Template

```
[Your App Name] uses background location services to provide geofence-based
features. Location data is processed entirely on your device and is never
transmitted to external servers without your explicit consent.

We use the Polyfence open-source SDK for geofencing. By default, Polyfence:
- Processes all location data locally on your device
- Does not transmit location data to any external servers
- Stores geofence zone definitions locally in device storage

Optional Analytics (if enabled):
If you enable analytics, aggregated performance metrics (GPS accuracy, battery
usage, detection latency) are transmitted to [polyfence.io / your backend].
These metrics do NOT include your actual GPS coordinates or personal location
history.

You can disable location services at any time in your device Settings.
```

### Data Retention Template

```
Geofence zone definitions are stored locally on your device and persist until:
- You delete the app
- You clear app data via device Settings
- You explicitly remove zones within the app

No location data is retained on external servers (unless you've enabled analytics).
```

## Security Updates

Security updates will be released as patch versions (e.g., 0.2.1) and announced via:

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
