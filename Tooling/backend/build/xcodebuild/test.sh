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

if have xcbeautify; then
  xcodebuild "${ARGS[@]}" | xcbeautify
else
  xcodebuild "${ARGS[@]}"
fi
