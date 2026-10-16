#!/usr/bin/env bash
# Fails when an error type polyfence-core can emit has no mapping in this
# bridge's PolyfenceErrorType surface.
#
# An unmapped native code does not fail loudly — PolyfenceError.fromMap falls
# back to PolyfenceErrorType.unknown, so the error still reaches onError and a
# consumer simply cannot tell it apart from anything else unmapped. That is
# invisible in every test that does not assert on the specific type, which is
# how the same gap reached this bridge twice.
#
# Two halves, both offline, registered as separate checks so that a run which
# could not reach polyfence-core reports the second half as skipped rather than
# passed:
#
#   (no argument) CORE_ERROR_TYPES below is the contract. Every entry must
#      resolve to a PolyfenceErrorType: either its camelCase form is an enum
#      value, or it is listed explicitly in _extraNativeCodesForType (which is
#      how a code is deliberately resolved to `unknown`). Needs only this repo.
#
#   --against-core  Extracts the type strings a polyfence-core checkout emits
#      and diffs them against CORE_ERROR_TYPES, so a type added upstream is
#      caught here rather than at the next device test. With no checkout found
#      it exits 77 with a SKIP_REASON line, which the runner reports as SKIP.
#
# Set POLYFENCE_CORE_PATH to point --against-core at a checkout in a
# non-default place.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

ERROR_SOURCE="lib/src/errors/polyfence_error.dart"

MODE="mapping"
case "${1:-}" in
  "") ;;
  --against-core) MODE="against-core" ;;
  *)
    echo "FAIL: unknown argument '$1' (expected none or --against-core)"
    exit 1
    ;;
esac

# Every `type` string polyfence-core passes to PolyfenceErrorManager.reportError
# (directly or through reportGpsError / reportServiceError / reportBatteryError)
# on either platform.
CORE_ERROR_TYPES=(
  analytics_upload_failed
  battery_optimization_required
  configuration_error
  gps_accuracy_poor
  gps_error
  gps_permission_denied
  gps_service_disabled
  gps_timeout
  gps_unreliable
  low_battery
  memory_low
  network_timeout
  os_geofence_permission_denied
  os_geofence_queue_disabled
  os_geofence_registration_failed
  pending_events_evicted
  permission_revoked
  polygon_self_intersecting
  service_killed
  service_restart_failed
  service_start_failed
  wake_lock_timeout
  zone_load_failed
  zone_storage_failed
  zone_validation_failed
)

snake_to_camel() {
  awk -F_ '{ printf "%s", $1; for (i = 2; i <= NF; i++) printf "%s%s", toupper(substr($i,1,1)), substr($i,2) }' <<<"$1"
}

if [[ "$MODE" == "mapping" ]]; then
  if [[ ! -f "$ERROR_SOURCE" ]]; then
    echo "FAIL: $ERROR_SOURCE not found — the error-type surface moved."
    exit 1
  fi

  unmapped=()
  for code in "${CORE_ERROR_TYPES[@]}"; do
    camel="$(snake_to_camel "$code")"
    # An enum value whose name is the camelCase form resolves algorithmically via
    # PolyfenceError.fromMap's snake_case normalisation.
    if grep -qE "^[[:space:]]*${camel},[[:space:]]*$" "$ERROR_SOURCE"; then
      continue
    fi
    # Otherwise the code must be listed in _extraNativeCodesForType, which is
    # where a code is deliberately routed to an existing type (including
    # `unknown`) rather than getting one of its own.
    if grep -qE "'${code}'" "$ERROR_SOURCE"; then
      continue
    fi
    unmapped+=("$code")
  done

  if (( ${#unmapped[@]} > 0 )); then
    echo "FAIL: polyfence-core error types with no PolyfenceErrorType mapping:"
    for code in "${unmapped[@]}"; do
      echo "  - $code  (expected enum value '$(snake_to_camel "$code")' or an entry in _extraNativeCodesForType)"
    done
    echo
    echo "Add each to the PolyfenceErrorType enum in $ERROR_SOURCE, or list it"
    echo "under _extraNativeCodesForType when it should resolve to an existing"
    echo "type. Mirror the decision in polyfence-react-native's NATIVE_CODE_TO_TYPE."
    exit 1
  fi

  echo "OK: ${#CORE_ERROR_TYPES[@]} core error types all map to a PolyfenceErrorType"
  exit 0
fi

CORE_DIR=""
for candidate in \
  "${POLYFENCE_CORE_PATH:-}" \
  "$ROOT/../polyfence-core" \
  "$ROOT/../../polyfence-core" \
  "$ROOT/../../../polyfence-core" \
  "$ROOT/../../../../polyfence-core"
do
  [[ -n "$candidate" && -d "$candidate/android/src/main" ]] || continue
  CORE_DIR="$candidate"
  break
done

if [[ -z "$CORE_DIR" ]]; then
  echo "SKIP_REASON: no polyfence-core checkout (set POLYFENCE_CORE_PATH)"
  exit 77
fi

live="$(
  grep -rhoE '(reportError|reportGpsError|reportServiceError|reportBatteryError)\([^)]*' \
    "$CORE_DIR/android/src/main" "$CORE_DIR/ios/Classes" 2>/dev/null \
    | grep -oE '(type|errorType)?[[:space:]]*[:=]?[[:space:]]*"[a-z][a-z0-9_]+"' \
    | grep -oE '"[a-z][a-z0-9_]+"' \
    | tr -d '"' \
    | sort -u
)"

# The extractor sees the first string literal after each call site, which is the
# type argument at every call but also picks up context-map keys where the type
# was passed as a variable. Only strings that are NOT in the roster matter, and
# a false positive there is a prompt to look rather than a silent pass.
missing="$(comm -23 <(echo "$live") <(printf '%s\n' "${CORE_ERROR_TYPES[@]}" | sort -u) || true)"
# Known non-type strings the extractor cannot distinguish from a type argument.
missing="$(echo "$missing" | grep -vxE 'android|ios|platform|type|details|error|timestamp|severity|source' || true)"

if [[ -n "$missing" ]]; then
  echo "FAIL: polyfence-core emits error types absent from CORE_ERROR_TYPES:"
  echo "$missing" | sed 's/^/  - /'
  echo
  echo "Core checkout: $CORE_DIR"
  echo "Add each to CORE_ERROR_TYPES in this script AND give it a mapping in"
  echo "$ERROR_SOURCE, then mirror both in polyfence-react-native."
  exit 1
fi

echo "OK: roster matches the error types emitted by $CORE_DIR"
exit 0
