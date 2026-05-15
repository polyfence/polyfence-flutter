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

Note: this repo gitignores `docs/` (website build output); the runbook lives under `doc/` alongside other developer docs.
