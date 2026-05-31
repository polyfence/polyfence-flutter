#!/bin/bash
# Verify android/build.gradle plugin version matches pubspec.yaml version.
# Catches drift where the gradle line gets missed during a version bump.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PUBSPEC_VER=$(grep "^version:" pubspec.yaml | sed 's/version: //' | sed 's/+.*//')
GRADLE_VER=$(grep -E "^version '" android/build.gradle | awk -F"'" '{print $2}')

if [ -z "$PUBSPEC_VER" ]; then
  echo "android-gradle-version-sync: could not extract version from pubspec.yaml"
  exit 1
fi

if [ -z "$GRADLE_VER" ]; then
  echo "android-gradle-version-sync: could not extract version from android/build.gradle"
  exit 1
fi

if [ "$PUBSPEC_VER" != "$GRADLE_VER" ]; then
  echo "android-gradle-version-sync: version mismatch"
  echo "  pubspec.yaml:         $PUBSPEC_VER"
  echo "  android/build.gradle: $GRADLE_VER"
  echo "Fix: run scripts/sync_version.sh"
  exit 1
fi
