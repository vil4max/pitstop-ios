#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../scripts" && pwd)"
# shellcheck source=../../../scripts/lib.sh
source "$SCRIPT_DIR/lib.sh"

SCHEME="$(scheme_name)"
[[ -n "$SCHEME" ]] || { echo "scheme missing — set runtime.yml scheme" >&2; exit 1; }

PROJ="$(find_xcodeproj)"
WS="$(find_xcworkspace)"
DEST="$(destination_spec test)"
TEST_UDID=""
[[ "$DEST" == *",id="* ]] && TEST_UDID="${DEST##*,id=}"
# A reserved device (simulator.test_udid) belongs to the person who reserved it:
# it is never erased, only reported.
RESERVED_TEST_UDID="$(cfg_get "simulator.test_udid" "")"

# An instance of the app already running on the test device takes the launch
# request, and the test environment (XCTest injection) is dropped: xcodebuild then
# waits in BootstrappingHang and fails with "The test runner hung before
# establishing connection". The system relaunches an app with a Live Activity or
# widgets after one manual launch, so the instance survives between runs.
# Drive Check lost a day of release runs to it, first blamed on load and on code.
stop_running_app() {
  local state bundle
  [[ -n "$TEST_UDID" ]] || return 0
  state="$(/usr/bin/python3 "$SCRIPT_DIR/sim-device.py" state "$TEST_UDID" 2>/dev/null || true)"
  [[ "$state" == Booted ]] || return 0
  bundle="$(bundle_id_for_scheme 2>/dev/null || true)"
  [[ -n "$bundle" ]] || return 0
  if xcrun simctl terminate "$TEST_UDID" "$bundle" >/dev/null 2>&1; then
    echo "test device: stopped a running $bundle before the run (a leftover instance hangs the test runner)"
  fi
}

ACTION=test
if [[ "${RUNTIME_XCODEBUILD_WITHOUT_BUILDING:-false}" == true ]]; then
  ACTION=test-without-building
fi

ARGS=(-scheme "$SCHEME" -destination "$DEST" -configuration Debug)
while IFS= read -r flag; do ARGS+=("$flag"); done < <(xcodebuild_validation_flags)
while IFS= read -r flag; do ARGS+=("$flag"); done < <(xcodebuild_ci_flags)
if [[ -n "${RUNTIME_RESULT_BUNDLE:-}" ]]; then
  # xcodebuild refuses to overwrite a bundle, and a stale one would be read as this run's.
  rm -rf "$RUNTIME_RESULT_BUNDLE"
  mkdir -p "$(dirname "$RUNTIME_RESULT_BUNDLE")"
  ARGS+=(-resultBundlePath "$RUNTIME_RESULT_BUNDLE")
fi
ARGS+=("$ACTION")
if [[ -n "$WS" ]]; then
  ARGS=(-workspace "$WS" "${ARGS[@]}")
elif [[ -n "$PROJ" ]]; then
  ARGS=(-project "$PROJ" "${ARGS[@]}")
else
  echo "no .xcodeproj / .xcworkspace found" >&2
  exit 1
fi

# Extra arguments select a subset (-only-testing:Target/Class); without this
# passthrough agents bypass the Runtime with raw xcodebuild for one test.
ARGS+=("$@")

LOG="$(mktemp "${TMPDIR:-/tmp}/runtime-test.XXXXXX")"
trap 'rm -f "$LOG"' EXIT

run_tests() {
  if [[ -n "${RUNTIME_RESULT_BUNDLE:-}" ]]; then rm -rf "$RUNTIME_RESULT_BUNDLE"; fi
  if have xcbeautify; then
    xcodebuild "${ARGS[@]}" 2>&1 | tee "$LOG" | xcbeautify
  else
    xcodebuild "${ARGS[@]}" 2>&1 | tee "$LOG"
  fi
}

runner_hung() {
  grep -qE 'hung before establishing connection|BootstrappingHang|Test runner never began executing tests' "$LOG"
}

stop_running_app
status=0
run_tests || status=$?
if ((status != 0)) && runner_hung; then
  echo "test runner hang: XCTest never connected to the app on the test device. This is the device's state, not load and not the code under test." >&2
  if [[ -z "$TEST_UDID" || "$TEST_UDID" == "$RESERVED_TEST_UDID" ]]; then
    echo "The device is reserved or unresolved, so it is left alone: erase it (xcrun simctl erase <udid>) and rerun." >&2
    exit "$status"
  fi
  # The failure happens before any test runs, so one retry on a clean device
  # cannot hide a failing test; a second hang is reported as is.
  echo "Erasing the app's own test device and retrying once." >&2
  /usr/bin/python3 "$SCRIPT_DIR/sim-device.py" reset "$TEST_UDID"
  status=0
  run_tests || status=$?
  if ((status != 0)) && runner_hung; then
    echo "test runner hang again on a freshly erased device: check the scheme's test host and the app's launch path." >&2
  fi
fi
exit "$status"
