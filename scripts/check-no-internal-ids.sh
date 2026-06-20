#!/usr/bin/env bash
# Fails if an internal decision-ID (Dxxx) or job-code (Jxx) appears in a public
# or published file. These reference the internal repo's DECISION_LOG / job
# tracker — meaningless and leaky to external readers. lib/ ships on pub.dev,
# so a leaked Dxxx reaches consumers. See polyfence-internal L213.
#
# Scope: tracked human-authored docs (*.md) and Dart source (lib/).
# Versions (1.0.1) and hex don't match the word-boundaried Dxxx/Jxx pattern.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if matches=$(git grep -nEw 'D[0-9]{3}|J[0-9]{2}' -- '*.md' 'lib/' 2>/dev/null); then
  echo "FAIL: internal decision/job IDs leaked into public docs/source:"
  echo "$matches"
  echo
  echo "Strip the (Dxxx)/(Jxx) tokens — keep the reasoning. Internal IDs live"
  echo "only in polyfence-internal (DECISION_LOG / job tracker). See L213."
  exit 1
fi
echo "OK: no internal decision/job IDs in public docs/source"
exit 0
