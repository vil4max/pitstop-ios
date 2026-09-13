#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../scripts" && pwd)"
# shellcheck source=../../../scripts/lib.sh
source "$SCRIPT_DIR/lib.sh"

SCHEME="$(scheme_name)"
[[ -n "$SCHEME" ]] || { echo "scheme missing — set runtime.yml scheme" >&2; exit 1; }

PROJ="$(find_xcodeproj)"
WS="$(find_xcworkspace)"
DEST="$(destination_spec)"

ACTION=test
if [[ "${RUNTIME_XCODEBUILD_WITHOUT_BUILDING:-false}" == true ]]; then
  ACTION=test-without-building
fi

ARGS=(-scheme "$SCHEME" -destination "$DEST" -configuration Debug "$ACTION")
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
