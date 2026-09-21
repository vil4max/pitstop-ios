#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../scripts" && pwd)"
# shellcheck source=../../../scripts/lib.sh
source "$SCRIPT_DIR/lib.sh"

SCHEME="$(scheme_name)"
[[ -n "$SCHEME" ]] || { echo "scheme missing — set runtime.yml scheme" >&2; exit 1; }

PROJ="$(find_xcodeproj)"
WS="$(find_xcworkspace)"
# A build for testing targets the test device, so verify never touches the run device.
if [[ "${RUNTIME_XCODEBUILD_BUILD_FOR_TESTING:-false}" == true ]]; then
  DEST="$(destination_spec test)"
else
  DEST="$(destination_spec)"
fi

ACTION=build
if [[ "${RUNTIME_XCODEBUILD_BUILD_FOR_TESTING:-false}" == true ]]; then
  ACTION=build-for-testing
fi

ARGS=(-scheme "$SCHEME" -destination "$DEST" -configuration Debug)
while IFS= read -r flag; do ARGS+=("$flag"); done < <(xcodebuild_validation_flags)
while IFS= read -r flag; do ARGS+=("$flag"); done < <(xcodebuild_ci_flags)
ARGS+=("$ACTION")
if [[ -n "$WS" ]]; then
  ARGS=(-workspace "$WS" "${ARGS[@]}")
elif [[ -n "$PROJ" ]]; then
  ARGS=(-project "$PROJ" "${ARGS[@]}")
else
  echo "no .xcodeproj / .xcworkspace found" >&2
  exit 1
fi

if have xcbeautify; then
  xcodebuild "${ARGS[@]}" | xcbeautify
else
  xcodebuild "${ARGS[@]}"
fi
