# Polyfence Flutter SDK — Privacy Policy

**Effective Date:** March 26, 2026  
**Last Updated:** October 15, 2026

**Applies to:** the Polyfence Flutter SDK (`package:polyfence`) only. Server-side and SaaS-side privacy posture is described separately at https://polyfence.io/privacy.

---

## Where this fits in the Polyfence platform

This package is the Flutter bridge over `polyfence-core` — the same zones you define once also run on-device here, on IoT (polyfence-embedded), and on the Polyfence server. This document covers the open-source SDK; the [platform privacy policy](https://polyfence.io/privacy) covers your polyfence.io account and SaaS-side processing.

---

## Overview

The SDK surfaces geofencing to Dart while native engines (Kotlin on Android, Swift on iOS) perform the geometric work. Optional anonymous platform telemetry flows through the bridge when enabled; end-user location and zone geometry stay under your app’s control unless you send them elsewhere.

### Zero PII about your end users

Polyfence collects **zero PII about your end users. We never ask who they are.** The personal information in our system is about you, not them — your account details and billing, same as any paid SaaS, identical to what Stripe or Vercel hold about you.

This SDK **never sends** GPS coordinates, raw location fixes, addresses, end-user names, contact fields, advertising identifiers, or cross-app tracking tokens off the device. Zone perimeters stay on the device too, with one opt-in exception described below. Telemetry, which is on by default, is limited to aggregates and operational signals described in [`doc/TELEMETRY.md`](doc/TELEMETRY.md). It never contains coordinates, end-user identifiers or end-user PII.

---

## What we hold about your end users

| Data class | What we hold | When |
| --- | --- | --- |
| **Zone events** | None from this SDK. It hands zone events to your app's code and never sends them to us. If your devices or servers report zone events to the Polyfence platform, we hold zone references only (`zone_id`, `device_id`, timestamp), with no coordinates. | Only for events you send to the platform. |
| **Anonymous platform telemetry** | Aggregates only, such as accuracy averages, event frequencies and error counts. Some are derived from location or motion: average speed at events and activity mix (the dwell-time fields are in the payload, but core 3.1.0 leaves them empty). No end-user identifiers, no coordinates, no PII. Carries your app's package name. | Opt-out (one-line disable). |
| **Raw positions** | None from this SDK. If your devices or servers send positions to the Polyfence platform, they are kept only when you turn retention on. | Only when you turn retention on. |

> **Zero PII about end users. We never ask who they are.**

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
| **Raw positions** | **Not sent by this SDK** | None from this SDK. If your devices or servers send positions to the Polyfence platform, they are kept only when you turn retention on. |
| **Anonymous platform aggregates** | **Opt-OUT** with one-line disable | Collected by default to fuel product improvements everyone benefits from. Never coordinates, never end-user identifiers, never PII. Carries your app's package name, and a link to your Polyfence account if you configure an API key. Industry-standard pattern (Stripe, Vercel, Cloudflare, Sentry). |
| **Zone events** | **Not sent by this SDK** | The SDK gives them to your code and never sends them to us. Events your devices or servers report to the Polyfence platform are what we deliver there. |

Different defaults for different data — control on every axis, no privacy theatre.

---

## Honest qualifiers

- **`device_id` is pseudonymous.** This SDK does not send it. On the Polyfence platform we cannot tell who a `device_id` belongs to, but you can, so it is still personal data, and we treat it as data we hold for you.
- **`display_name`** is user-typed and could contain PII ("John's truck"). Our `firmware_visible_name` flag defaults FALSE, so the name stays on the SaaS DB only and never reaches the firmware unless you explicitly turn it on. The customer chose to type it.
- **Customer account PII** (email, billing) is unavoidable for a paid SaaS. We don't pretend otherwise — neither does Stripe.

---

## What this SDK sends

On its own, this SDK never puts positions, end-user identifiers or end-user PII in anything it sends. What it sends is the telemetry listed in [`doc/TELEMETRY.md`](doc/TELEMETRY.md): aggregates, some of them derived from location, plus your app's package name. Each upload reaches us from the device's IP address, which our code does not store. All geofence math runs in `polyfence-core` (Kotlin on Android, Swift on iOS), not in Dart. See [`polyfence-core` PRIVACY.md](https://github.com/polyfence/polyfence-core/blob/main/PRIVACY.md) for the engine’s privacy claims.

### The one exception: OS wake fences (opt-in, off by default)

Phones close background apps to reclaim memory. If you want a zone crossing to still be caught while your app is
closed, you can set `osGeofenceWakeEnabled` in `PolyfenceConfiguration`. It ships **off**, and only your own app
code turns it on.

With it on, the SDK registers **zone perimeters** — a centre point and a radius for the zones nearest the device —
with the phone's own geofence service: Google Play Services on Android, CoreLocation on iOS. That list describes
**your zones**, not your user: no position, no device identifier, and nothing about the person carrying the phone
travels with it. When the operating system sees a boundary crossed it does one thing — it wakes your app.
Polyfence's engine remains the only thing that decides what actually happened, evaluating every zone with full
polygon geometry in-process.

What that costs you, stated plainly: turning it on discloses part of your zone geography to Apple or Google. They
already know where the device is — that is the platform your app runs on, not something Polyfence introduces — but
they do not know where your zones are until your app registers them. That is why it stays off until you choose
otherwise.

- **How much** — only the zones nearest the device: at most 20 on iOS (Apple's cap) and 50 on Android by default,
  however many you have. Lower it with `osGeofenceMaxRegions`. The set is re-chosen as the device travels, so over
  a long journey more of your zones can be disclosed than the cap alone suggests.
- **How precisely** — these platforms understand circles only, so a polygon zone is registered as a circle drawn
  around it. What they hold is a rougher outline than the zone you drew, never a sharper one.
- **Who receives it** — the operating system on your user's own phone. Nothing on this path reaches Polyfence
  servers, so Apple and Google are not processing anything on our behalf. This is a disclosure **your app** makes,
  and it belongs in your privacy policy rather than ours.
- **What your users are asked** — waking a closed app needs a background location grant ("Allow all the time" on
  Android, "Always" on iOS). Leave the setting off and the SDK asks only for location while your app is in use.

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

When telemetry is enabled, the SDK sends anonymous performance and reliability signals (for example, detection counts, timing, GPS accuracy in meters without coordinates, zone counts by size, and error-class tallies). There are no end-user identifiers, no location fixes, and no free-text PII in those payloads. Each payload does carry your app's package name, which is a required field, and if you configure an API key the session is linked to your Polyfence account. For a complete field-by-field breakdown with examples, see [`doc/TELEMETRY.md`](doc/TELEMETRY.md).

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

Every change moves the **Last Updated** date at the top of this page, including small ones, so if that date hasn't moved, nothing here has changed. We don't send policy updates by email. When a change affects what the SDK sends or how we handle it, we describe it in plain terms here and in the [CHANGELOG](CHANGELOG.md).

**Where the law requires stronger notice or consent for material changes, we will comply.** Review this page when the date changes, especially if telemetry or retention affects your app’s disclosures.

---

## Contact

- **Privacy questions, data requests, deletion, security vulnerabilities, or general inquiries:** [hello@polyfence.io](mailto:hello@polyfence.io) (48-hour response target)
- **Technical support:** [GitHub Issues](https://github.com/polyfence/polyfence-flutter/issues)

---

**Summary:** Anonymous platform telemetry is on by default with a one-line opt-out. **Zero PII about your end users** in our SDK telemetry path: no coordinates, no end-user identifiers, no end-user PII. Customer account data for polyfence.io follows the platform policy. Open source — verify our claims in the code.
