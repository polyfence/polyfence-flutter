#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export CONSISTENCY_REPO_ROOT="$ROOT"
exec ruby "$ROOT/scripts/consistency_check_runner.rb" "$@"
