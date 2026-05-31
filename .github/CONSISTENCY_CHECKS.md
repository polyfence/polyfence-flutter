# Consistency Checks

## Requires

Ruby ≥ 2.6 for the runner. macOS ships this by default. The `scripts/consistency-check.sh` bash dispatcher exits with a clear message if `ruby` is not on `PATH`. Other polyfence repos use TypeScript (polyfence, polyfence-react-native) or Python (polyfence-intelligence) runners; the YAML schema is identical across runtime ports.

## Overview

`consistency-checks.yaml` lists declarative drift checks. Entrypoint `scripts/consistency-check.sh` shells Ruby (`scripts/consistency_check_runner.rb`). Wired into `scripts/pre-push-checks.sh`.

```bash
bash scripts/consistency-check.sh --local-only
```

## Checks shipped

| id | intent |
| --- | --- |
| bootstrap-files-not-tracked | Guardrail scaffold stays untracked |
| pubspec-readme-version-sync | pubspec semver echoed in README + doc/TELEMETRY.md |
| dart-analyze-clean | Static analysis passes |
| readme-cites-brand-positioning | Canonical pitch anchor present |
| privacy-md-links-telemetry-doc | `PRIVACY.md` links `doc/TELEMETRY.md` |
| privacy-md-zero-pii-headline | `PRIVACY.md` includes the verbatim Role-1 Zero PII headline |
| pubspec-description-geofencing | `pubspec.yaml` description mentions geofencing |

## Phase 3

`pubspec-readme-version-sync` already covered `doc/TELEMETRY.md` in Phase 2; Phase 3 adds explicit privacy/telemetry cross-links, package-description copy hygiene, and the Role-1 Zero PII headline check on `PRIVACY.md`.

Note: this repo gitignores `docs/` (website build output); the runbook lives under `doc/` alongside other developer docs.
