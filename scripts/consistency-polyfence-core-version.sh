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
# `|| true` so a coordinate carrying no numeric triple at all, such as
# 'latest.release', leaves GRADLE_VER empty and reaches the checks below
# instead of aborting here under `set -o pipefail` with nothing printed.
GRADLE_VER=$(echo "$GRADLE_COORD" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)

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

# Exact version on Android too. Gradle accepts dynamic selectors: a '3.0.0+'
# prefix, a '[3.0.0,3.1.0)' range, 'latest.release'. The cross-platform
# comparison below reads only the numeric triple, so '3.0.0+' and '3.0.0'
# compare equal and a floating Android pin would pass unnoticed. Reject the
# selector explicitly: this check exists to stop the two platforms resolving
# different engines, and that can start from either side.
GRADLE_VERSION_SPEC="${GRADLE_COORD##*:}"
if [ -n "$GRADLE_COORD" ] && ! printf '%s' "$GRADLE_VERSION_SPEC" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  echo "polyfence-core-version-sync: android/build.gradle does not pin polyfence-core to an exact version"
  echo "  $GRADLE_COORD"
  echo "Fix: pin a single version, as in io.polyfence:polyfence-core:3.0.0. A dynamic selector lets Android resolve a core the podspec does not pin."
  exit 1
fi

# iOS: s.dependency 'PolyfenceCore', 'X.Y.Z'
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

# Both platforms pin exactly, so the engine changes only when this repo says
# so. An optimistic operator here ('~>', '>=') would let iOS resolve a newer
# core on the next pod install while Android stayed on the pinned version,
# putting one plugin version on two different engines. The comparison below
# reads only the numeric triple, so an operator is invisible to it: reject it
# explicitly rather than letting the asymmetry grow back unnoticed.
if echo "$PODSPEC_LINE" | grep -qE '~>|>=|<=|>|<'; then
  echo "polyfence-core-version-sync: ios/polyfence.podspec does not pin PolyfenceCore exactly"
  echo "  $PODSPEC_LINE"
  echo "Fix: drop the version operator so the line reads s.dependency 'PolyfenceCore', '$GRADLE_VER'. Android pins exactly; an optimistic iOS pin lets the two platforms drift onto different engines."
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
  echo "Fix: update both files to the same polyfence-core version. Both platforms pin exactly, so they move together."
  exit 1
fi

echo "OK: polyfence-core pinned to $GRADLE_VER on both platforms"
exit 0
