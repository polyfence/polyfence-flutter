#!/usr/bin/env bash
# Verify the polyfence-core dependency pin matches across Android
# (android/build.gradle) and iOS (ios/polyfence.podspec), and that neither
# pins a pre-release build. Catches drift where one platform bumps the engine
# pin and the other doesn't, and catches a local testing pin riding to release.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# Android: implementation 'io.polyfence:polyfence-core:X.Y.Z'
GRADLE_COORD=$(grep -E "io\.polyfence:polyfence-core:" android/build.gradle 2>/dev/null \
  | grep -oE "io\.polyfence:polyfence-core:[^'\"]+" \
  | head -1)
GRADLE_VER=$(echo "$GRADLE_COORD" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)

# iOS: s.dependency 'PolyfenceCore', '~> X.Y.Z'
PODSPEC_LINE=$(grep -E "s\.dependency\s+'PolyfenceCore'" ios/polyfence.podspec 2>/dev/null | head -1)
PODSPEC_VER=$(echo "$PODSPEC_LINE" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)

if [ -z "$GRADLE_VER" ]; then
  echo "polyfence-core-version-sync: could not extract polyfence-core version from android/build.gradle"
  exit 1
fi

if [ -z "$PODSPEC_VER" ]; then
  echo "polyfence-core-version-sync: could not extract PolyfenceCore version from ios/polyfence.podspec"
  exit 1
fi

# A -SNAPSHOT pin resolves only from a developer's mavenLocal, so a shipped
# build would fail to resolve for every consumer. The comparison below reads
# only the numeric triple, so the qualifier is invisible to it — reject it
# explicitly rather than letting a local testing pin ride to release.
if [[ "$GRADLE_COORD" == *-SNAPSHOT* ]]; then
  echo "polyfence-core-version-sync: android/build.gradle pins a SNAPSHOT of polyfence-core"
  echo "  $GRADLE_COORD"
  echo "Fix: pin the released version. A SNAPSHOT resolves only from mavenLocal and would not resolve for consumers."
  exit 1
fi

# mavenLocal() ahead of the remote repositories is the companion half of a
# SNAPSHOT pin and has the same shipping hazard: it makes a build depend on
# whatever happens to be in the developer's ~/.m2.
if grep -qE '^\s*mavenLocal\(\)' android/build.gradle; then
  echo "polyfence-core-version-sync: android/build.gradle declares mavenLocal()"
  echo "Fix: remove it. A build that resolves from a developer's ~/.m2 is not reproducible for consumers."
  exit 1
fi

if [ "$GRADLE_VER" != "$PODSPEC_VER" ]; then
  echo "polyfence-core-version-sync: polyfence-core version mismatch between platforms"
  echo "  android/build.gradle:   $GRADLE_VER"
  echo "  ios/polyfence.podspec:  $PODSPEC_VER"
  echo "Fix: update both files to the same polyfence-core version. The podspec uses '~> X.Y.Z' (twiddle-wakka); Android pins exactly."
  exit 1
fi

echo "OK: polyfence-core pinned to $GRADLE_VER on both platforms"
exit 0
