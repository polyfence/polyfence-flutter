# Consistency Checks

## Requires

Ruby ≥ 2.6 for the runner. macOS ships this by default. The `scripts/consistency-check.sh` bash dispatcher exits with a clear message if `ruby` is not on `PATH`. (Other polyfence repos use TypeScript or Python runners; the YAML schema is identical across runtime ports.)

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

Note: this repo gitignores `docs/` (website build output); the runbook lives under `doc/` alongside other developer docs.
