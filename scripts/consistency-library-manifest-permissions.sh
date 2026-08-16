#!/usr/bin/env bash
# Assert android/src/main/AndroidManifest.xml declares exactly the library-owned
# permission set - no more, no fewer.
#
# Manifest merging is build-time, so a <uses-permission> added here is inherited
# by every consuming app whether or not it uses the feature behind it. The set
# below is the one the plugin's own service and receiver cannot run without and
# that costs an integrator nothing at store-review time. Anything that carries a
# Google Play review cost or gates an opt-in feature is declared by the consumer;
# see doc/ANDROID_PERMISSIONS.md.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

MANIFEST="android/src/main/AndroidManifest.xml"

if [ ! -f "$MANIFEST" ]; then
  echo "FAIL: $MANIFEST missing"
  exit 1
fi

EXPECTED=$(cat <<'EOF'
android.permission.ACCESS_COARSE_LOCATION
android.permission.ACCESS_FINE_LOCATION
android.permission.FOREGROUND_SERVICE
android.permission.FOREGROUND_SERVICE_LOCATION
android.permission.POST_NOTIFICATIONS
android.permission.RECEIVE_BOOT_COMPLETED
android.permission.VIBRATE
android.permission.WAKE_LOCK
EOF
)

# Strip XML comments first so a permission named inside the explanatory block
# is not counted as a declaration.
ACTUAL=$(perl -0777 -pe 's/<!--.*?-->//gs' "$MANIFEST" \
  | grep -o '<uses-permission[^>]*android:name="[^"]*"' \
  | sed 's/.*android:name="//; s/"//' \
  | sort)

if [ "$ACTUAL" != "$EXPECTED" ]; then
  echo "FAIL: library manifest permission set drifted"
  echo
  echo "Unexpected (remove from the library, declare in the consuming app):"
  comm -13 <(echo "$EXPECTED") <(echo "$ACTUAL") | sed 's/^/  + /'
  echo "Missing (library components need these):"
  comm -23 <(echo "$EXPECTED") <(echo "$ACTUAL") | sed 's/^/  - /'
  echo
  echo "The library declares only permissions its own <service> and <receiver>"
  echo "cannot run without. Permissions with a Google Play review cost, or that"
  echo "gate an opt-in feature, belong to the consuming app - document them in"
  echo "doc/ANDROID_PERMISSIONS.md and the README instead of adding them here."
  exit 1
fi

echo "OK: library manifest declares exactly the 8 library-owned permissions"
exit 0
