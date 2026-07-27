#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

ver="$(grep -E '^version:' pubspec.yaml | head -1 | awk '{print $2}')"
if [ -z "$ver" ]; then
  echo "could not read version from pubspec.yaml"
  exit 1
fi

# Check the specific sentinel forms, not just that the version string appears
# somewhere in the file. Bare-string presence passed while the visible
# `<!-- pf:version -->` install-snippet block silently held a stale prior
# version, because the CHANGELOG / upgrade text elsewhere contained the new
# string. Anchor on the exact sentinel spans that scripts/sync_version.sh
# writes so drift in either sentinel fails the check.
grep -qF "<!-- pf:version -->^${ver}<!-- /pf:version -->" README.md || {
  echo "README.md <!-- pf:version --> sentinel not synced to ${ver}"
  echo "Fix: run scripts/sync_version.sh after bumping pubspec.yaml."
  exit 1
}
grep -qF "<!-- pf:version-plain -->${ver}<!-- /pf:version-plain -->" README.md || {
  echo "README.md <!-- pf:version-plain --> sentinel not synced to ${ver}"
  echo "Fix: run scripts/sync_version.sh after bumping pubspec.yaml."
  exit 1
}
grep -qF "\"plugin_version\": \"${ver}\"" doc/TELEMETRY.md || {
  echo "doc/TELEMETRY.md \"plugin_version\" payload example not synced to ${ver}"
  echo "Fix: run scripts/sync_version.sh after bumping pubspec.yaml."
  exit 1
}
grep -qF "polyfencePluginVersion = '$ver'" lib/src/version.dart || { echo "lib/src/version.dart polyfencePluginVersion out of sync with pubspec ${ver} (it is stamped into plugin_version telemetry)"; exit 1; }
