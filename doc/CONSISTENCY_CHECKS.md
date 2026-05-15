# Consistency Checks

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
| pubspec-description-geofencing | `pubspec.yaml` description mentions geofencing |

## Phase 3

`pubspec-readme-version-sync` already covered `doc/TELEMETRY.md` in Phase 2; Phase 3 adds explicit privacy/telemetry cross-links and package-description copy hygiene. Flutter’s `PRIVACY.md` is not yet on the Role-1 template headline verbatim — a headline-alignment check is deferred until that propagation lands.

Note: this repo gitignores `docs/` (website build output); the runbook lives under `doc/` alongside other developer docs.
