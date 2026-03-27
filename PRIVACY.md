# Polyfence Plugin — Privacy Policy

**Effective Date:** March 26, 2026
**Last Updated:** March 27, 2026
**Applies to:** The Polyfence Flutter plugin (`package:polyfence`)

---

## Overview

This privacy policy explains how the Polyfence Flutter plugin handles data. It applies to the open-source plugin only. If you use the Polyfence platform at polyfence.io, the [platform privacy policy](https://polyfence.io/privacy) applies to your account and zone data.

**Our Core Principle:** Your users' location data stays on their devices. Always.

---

## What the Plugin Collects

### Anonymous Performance Telemetry (Enabled by Default)

The plugin sends anonymous performance metrics to help us monitor reliability and improve the plugin. Telemetry is **enabled by default** with a simple opt-out.

**What's collected:**

- **App/platform identifiers** (not user identifiers): app package name, platform (Android/iOS), plugin version, bridge layer (e.g. Flutter, React Native)
- **Performance metrics**: detection counts, detection timing, GPS accuracy averages (in meters, not coordinates), battery usage, session duration
- **Zone usage** (types only, no locations): circle vs polygon counts — no coordinates, addresses, or names
- **Error tracking**: error type counts (e.g., "gps_timeout"), service interruption counts
- **System health**: GPS accuracy success rate, battery optimization status, service restart counts
- **Enhanced metrics** (v0.12.0+): activity type distribution, GPS update interval distribution, false event detection counts, device category, OS major version, charging status

For a complete field-by-field breakdown with examples, see the [Telemetry Reference](doc/TELEMETRY.md).

### What We NEVER Collect

The plugin **never** collects, transmits, or stores:

- GPS coordinates or location data
- Zone definitions, boundaries, addresses, or names
- User identifiers (names, emails, phone numbers, device IDs, advertising IDs)
- Personal information of any kind
- User behavior patterns or movement data
- Cross-app tracking identifiers

---

## How to Opt Out

Disable telemetry with one line of code:

```dart
await Polyfence.instance.initialize(
  analyticsConfig: AnalyticsConfig(
    disableTelemetry: true,
  ),
);
```

When disabled: zero data is transmitted, no network calls are made for analytics, and all plugin features continue to work normally.

---

## How We Use the Data

Telemetry is used exclusively to:

- Monitor plugin performance across devices and platforms
- Detect and prioritize bug fixes
- Measure the impact of optimizations
- Guide product decisions (e.g., which zone types to optimize)

We **do not** sell data, share it with third parties, use it for advertising, or link it across apps.

---

## Data Storage & Security

- **Stored in:** Supabase PostgreSQL (encrypted at rest and in transit)
- **Transmitted via:** HTTPS only
- **Retention period:** 24 months, then automatically deleted
- **No third-party analytics:** We do not use Google Analytics, Mixpanel, Amplitude, or similar services
- **Request earlier deletion:** Email [hello@polyfence.io](mailto:hello@polyfence.io) with your app package name

---

## Legal Compliance

### GDPR (European Union)

**Legal basis:** Legitimate interest (Article 6(1)(f) GDPR) — improving plugin performance and reliability.

We believe this processing aligns with legitimate interest because we minimize data, do not transmit location or PII, disclose practices clearly, and offer a simple opt-out. **Classification of fields (e.g. whether an app package name is personal data in a given context) can vary; consult qualified counsel** if your processing or jurisdiction requires a formal assessment.

**Your rights (EU developers):**

- **Access:** Request data collected from your app
- **Erasure:** Request deletion of your app's telemetry
- **Object:** Opt out of telemetry at any time
- **Portability:** Request telemetry data in machine-readable format

Contact: [hello@polyfence.io](mailto:hello@polyfence.io)

### CCPA (California)

We do not sell personal information. Whether specific telemetry fields qualify as **personal information** under CCPA can depend on context; **consult counsel** if your use case requires a formal determination.

### Other Jurisdictions

We comply with PIPEDA (Canada), LGPD (Brazil), and the Australian Privacy Act through data minimization, transparent disclosure, and opt-out mechanisms.

---

## Children's Privacy

The plugin does not knowingly collect data from children under 13. If your app targets children, we recommend disabling telemetry: `AnalyticsConfig(disableTelemetry: true)`.

Review applicable regulations (COPPA, GDPR Article 8) for your use case.

---

## Your Responsibility as a Developer

If your application uses Polyfence to collect location data from your users, **you** are responsible for:

- Your own privacy policy covering location data collection
- Obtaining necessary user consent for location tracking
- Complying with applicable privacy regulations in your jurisdictions
- Disclosing Polyfence telemetry in your privacy policy (if enabled)

Polyfence provides the tools — how you use them in your app is your responsibility.

---

## Open Source Transparency

The plugin is open source under the MIT License. You can verify every claim in this policy:

- **Source code:** [github.com/polyfence/polyfence-flutter](https://github.com/polyfence/polyfence-flutter)
- **Telemetry implementation:** [lib/src/services/analytics_service.dart](lib/src/services/analytics_service.dart)
- **Field-by-field reference:** [doc/TELEMETRY.md](doc/TELEMETRY.md)
- **Network verification:** Use Charles Proxy or Wireshark to inspect actual payloads

---

## Changes to This Policy

- **Major changes:** Email notification to registered developers + GitHub issue where feasible
- **Minor changes:** Updated "Last Updated" date on this page
- **All changes:** Summarized in the [CHANGELOG](CHANGELOG.md)

**Where the law requires stronger notice or consent for material changes, we will comply.** Review this page when the date changes, especially if telemetry or retention affects your app’s disclosures.

---

## Contact

- **Privacy questions:** [hello@polyfence.io](mailto:hello@polyfence.io) (48-hour response)
- **Data requests and deletion:** [hello@polyfence.io](mailto:hello@polyfence.io) (30-day response)
- **Security vulnerabilities:** [hello@polyfence.io](mailto:hello@polyfence.io) (see [SECURITY.md](./SECURITY.md))
- **General inquiries:** [hello@polyfence.io](mailto:hello@polyfence.io)
- **Technical support:** [GitHub Issues](https://github.com/polyfence/polyfence-flutter/issues)

---

**TL;DR:** The plugin collects anonymous performance telemetry by default (opt-out with one line). No location data, no PII, no user identifiers — ever. Data retained 24 months, then deleted. Open source — verify our claims in the code.
