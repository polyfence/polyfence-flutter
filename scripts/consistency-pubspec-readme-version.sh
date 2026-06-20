#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

ver="$(grep -E '^version:' pubspec.yaml | head -1 | awk '{print $2}')"
if [ -z "$ver" ]; then
  echo "could not read version from pubspec.yaml"
  exit 1
fi

grep -qF "$ver" README.md || { echo "pubspec version ${ver} not found in README.md"; exit 1; }
grep -qF "$ver" doc/TELEMETRY.md || { echo "pubspec version ${ver} not found in doc/TELEMETRY.md"; exit 1; }
grep -qF "polyfencePluginVersion = '$ver'" lib/src/version.dart || { echo "lib/src/version.dart polyfencePluginVersion out of sync with pubspec ${ver} (it is stamped into plugin_version telemetry)"; exit 1; }
