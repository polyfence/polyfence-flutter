# Polyfence Flutter SDK — Privacy Policy

**Effective Date:** March 26, 2026  
**Last Updated:** May 16, 2026

**Applies to:** the Polyfence Flutter SDK (`package:polyfence`) only. Server-side and SaaS-side privacy posture is described separately at https://polyfence.io/privacy.

---

## Where this fits in the Polyfence platform

This package is the Flutter bridge over `polyfence-core` — the same zones you define once also run on-device here, on IoT (polyfence-embedded), and on the Polyfence server. This document covers the open-source SDK; the [platform privacy policy](https://polyfence.io/privacy) covers your polyfence.io account and SaaS-side processing.

---

## Overview

The SDK surfaces geofencing to Dart while native engines (Kotlin on Android, Swift on iOS) perform the geometric work. Optional anonymous platform telemetry flows through the bridge when enabled; end-user location and zone geometry stay under your app’s control unless you send them elsewhere.

### Zero PII about your end users

Polyfence collects **zero PII and zero identifiable data about your end users.** The only personal information in our system is YOUR account info (email, billing) — same as any paid SaaS, identical to what Stripe or Vercel hold about you.

This SDK **never collects, transmits, or stores** GPS coordinates, raw location fixes, zone boundaries, addresses, end-user names, contact fields, advertising identifiers, or cross-app tracking tokens. Telemetry, when enabled, is limited to aggregates and operational signals described in [`doc/TELEMETRY.md`](doc/TELEMETRY.md) — never coordinates, never end-user identifiers, never end-user PII.

---

## What we hold about your end users

| Data class | What we hold | When |
| --- | --- | --- |
| **Zone events** | Zone references only (`zone_id`, `device_id`, timestamp). No PII. No coordinates. | Always — this is the product value. |
| **Anonymous platform telemetry** | Aggregates only — accuracy averages, event frequencies, error counts. No identifiers, no coordinates, no PII. | Opt-out (one-line disable). |
| **Raw positions** | Not collected by default. Opt-in retention only. When opted in: positions only — never names / phones / emails / health / etc. | Opt-in only. |

> **Zero PII. Zero identifiable data about end users.**

---

## What we hold about YOU (the customer)

| Data class | What we hold |
| --- | --- |
| Account email | Standard B2B SaaS PII. |
| Billing / payment | Handled by payment processor; we don't store card data. |
| API keys + audit log | Pseudonymous credentials + access trail. |

> **Minimal customer PII. Identical to what every paid SaaS holds.**

---

## Different defaults for different data classes

| Data class | Default | Why |
| --- | --- | --- |
| **Raw positions** | **Opt-IN** | We don't have your customers' location data unless you explicitly turn retention on. |
| **Anonymous platform aggregates** | **Opt-OUT** with one-line disable | Collected by default to fuel product improvements everyone benefits from. Never coordinates, never identifiers, never PII. Industry-standard pattern (Stripe, Vercel, Cloudflare, Sentry). |
| **Zone events** | **Always** | They're the value we deliver — collecting them isn't surveillance, it's the product. |

Different defaults for different data — control on every axis, no privacy theatre.

---

## Honest qualifiers

- **`device_id` is pseudonymous** (hashed identifier). Not PII per se. If you correlate it against your own user database, it becomes identifiable on **your** side — never on ours. GDPR-clean pseudonymisation.
- **`display_name`** is user-typed and could contain PII ("John's truck"). Our `firmware_visible_name` flag defaults FALSE, so the name stays on the SaaS DB only and never reaches the firmware unless you explicitly turn it on. The customer chose to type it.
- **Customer account PII** (email, billing) is unavoidable for a paid SaaS. We don't pretend otherwise — neither does Stripe.

---

## This SDK never collects, transmits, or stores

On its own, this SDK **never collects, transmits, or stores** location data, end-user identifiers, or end-user PII. All geofence math runs in `polyfence-core` (Kotlin on Android, Swift on iOS), not in Dart. See [`polyfence-core` PRIVACY.md](https://github.com/polyfence/polyfence-core/blob/main/PRIVACY.md) for the engine’s privacy claims.

---

## polyfence-flutter specific

Anonymous platform telemetry is **enabled by default**. Disable with one line:

```dart
await Polyfence.instance.initialize(
  analyticsConfig: AnalyticsConfig(disableTelemetry: true),
);
```

Field-by-field telemetry contract: see [`doc/TELEMETRY.md`](doc/TELEMETRY.md).

---

## Anonymous platform telemetry (detail)

When telemetry is enabled, the SDK sends anonymous performance and reliability signals (for example, detection counts, timing, GPS accuracy in meters without coordinates, zone shape counts, and error-class tallies). There are no user identifiers, no location fixes, and no free-text PII in those payloads. For a complete field-by-field breakdown with examples, see [`doc/TELEMETRY.md`](doc/TELEMETRY.md).

When telemetry is disabled, zero analytics data is transmitted; SDK features continue to work normally.

---

## How we use telemetry

Telemetry is used exclusively to monitor SDK health across devices and platforms, prioritize fixes, measure optimizations, and guide product decisions. We **do not** sell data, share it with third parties for advertising, or use it for cross-app profiling.

---

## Data storage and security

For enabled telemetry:

- **Stored in:** Supabase PostgreSQL (encrypted at rest and in transit)
- **Transmitted via:** HTTPS only
- **Retention:** 24 months, then automatically deleted
- **No third-party analytics stacks:** We do not route SDK telemetry through Google Analytics, Mixpanel, Amplitude, or similar consumer analytics products
- **Earlier deletion:** Email [hello@polyfence.io](mailto:hello@polyfence.io) with your app package name

---

## Legal compliance

### GDPR (European Union)

**Legal basis:** Legitimate interest (Article 6(1)(f) GDPR) — improving SDK performance and reliability.

We minimize data, do not transmit coordinates or end-user PII in telemetry, disclose practices here, and offer a simple opt-out. **Classification of specific fields (e.g. whether an app package name is personal data in a given context) can vary; consult qualified counsel** if your processing or jurisdiction requires a formal assessment.

**Your rights (EU developers):** access, erasure, objection, and portability for data tied to your app’s telemetry. Contact: [hello@polyfence.io](mailto:hello@polyfence.io).

### CCPA (California)

We do not sell personal information. Whether specific telemetry fields qualify as **personal information** under CCPA can depend on context; **consult counsel** if your use case requires a formal determination.

### Other jurisdictions

We align with PIPEDA (Canada), LGPD (Brazil), and the Australian Privacy Act through data minimization, transparent disclosure, and opt-out mechanisms.

---

## Children's privacy

The SDK does not target children and does not knowingly collect data from children under 13 for analytics. If your app targets children, disable telemetry: `AnalyticsConfig(disableTelemetry: true)`. Review COPPA, GDPR Article 8, and related rules for your use case.

---

## Your responsibility as a developer

If your application collects location or personally identifiable information from users, **you** are responsible for your own privacy policy, consent, regulatory compliance, and for disclosing Polyfence telemetry in your app’s privacy materials when telemetry is enabled.

---

## Open source transparency

The SDK is open source under the MIT License. You can verify claims in this policy:

- **Source:** [github.com/polyfence/polyfence-flutter](https://github.com/polyfence/polyfence-flutter)
- **Telemetry implementation:** [`lib/src/services/analytics_service.dart`](lib/src/services/analytics_service.dart)
- **Field-level reference:** [`doc/TELEMETRY.md`](doc/TELEMETRY.md)

---

## Changes to this policy

- **Major changes:** Email notification to registered developers and a GitHub issue where feasible
- **Minor changes:** Updated **Last Updated** date on this page
- **All changes:** Summarized in [CHANGELOG](CHANGELOG.md)

**Where the law requires stronger notice or consent for material changes, we will comply.** Review this page when the date changes, especially if telemetry or retention affects your app’s disclosures.

---

## Contact

- **Privacy questions, data requests, deletion, security vulnerabilities, or general inquiries:** [hello@polyfence.io](mailto:hello@polyfence.io) (48-hour response target)
- **Technical support:** [GitHub Issues](https://github.com/polyfence/polyfence-flutter/issues)

---

**Summary:** Anonymous platform telemetry is on by default with a one-line opt-out. **Zero PII about your end users** in our SDK telemetry path: no coordinates, no end-user identifiers, no end-user PII. Customer account data for polyfence.io follows the platform policy. Open source — verify our claims in the code.
