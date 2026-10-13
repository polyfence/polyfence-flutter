# Consistency Checks

## Requires

Ruby ≥ 2.6 for the runner. macOS ships this by default. The `scripts/consistency-check.sh` bash dispatcher exits with a clear message if `ruby` is not on `PATH`. Other polyfence SDK repos use different runtime ports of the same YAML schema.

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

## Results

Each check prints `PASS <id>`, `SKIP <id> (<reason>)`, or `FAIL <id>` with the `fix:` text from the YAML, then a summary line counting each. A skip means the check did not run, so it never counts as a pass. Skips do not fail the run (a missing optional tool must not block a push), but the summary names every skipped check as not verified and says `all passed` only when nothing was skipped.

A `subprocess` script reports a skip by printing `SKIP_REASON: <why>` as its last line of stdout and exiting 77. Both are required: exit 77 without that last line is reported as FAIL, so a script that happens to die with 77 cannot pass itself off as a skip. Exit 0 always means PASS, so a script that exits 0 is reported as FAIL if any line of its stdout or stderr matches `^\s*SKIP\b` or `^\s*SKIP_REASON:` (at any indentation, so `SKIP x`, `  SKIP x` and `SKIP: x` all count).

The run exits 0 when nothing failed, 1 when a check failed, and 2 when the run itself is wrong: no `consistency-checks.yaml`, a `--check` id that matches no entry (`FAIL: no check with id <id>`), or a selection that verified nothing: no check ran at all (`RESULT: no checks ran`, for example `--remote-only` in this repo, which has no `remote-query` checks), or every selected check was skipped (`RESULT: nothing verified`, for example `--check` on a single optional check whose tool is missing).

## Phase 3

`pubspec-readme-version-sync` already covered `doc/TELEMETRY.md` in Phase 2; Phase 3 adds explicit privacy/telemetry cross-links, package-description copy hygiene, and the Role-1 Zero PII headline check on `PRIVACY.md`.

Note: this repo gitignores `docs/` (website build output); the runbook lives under `doc/` alongside other developer docs.
