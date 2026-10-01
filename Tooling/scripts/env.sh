#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

echo "Runtime: $(harness_version)"
echo "PWD: $PWD"
for b in just git gh yq jq swift swift-format swiftlint xcodebuild xcbeautify xcrun; do
  # swift-format is not on PATH: the Xcode toolchain provides it through xcrun.
  if [[ "$b" == swift-format ]]; then
    run=(xcrun swift-format)
    present=false
    if have xcrun && xcrun --find swift-format >/dev/null 2>&1; then present=true; fi
  else
    run=("$b")
    present=false
    if have "$b"; then present=true; fi
  fi
  if [[ "$present" == true ]]; then
    ver="$("${run[@]}" --version 2>/dev/null | head -n 1 || true)"
    echo "$b: ${ver:-present}"
  else
    echo "$b: MISSING"
  fi
done
if have xcodebuild; then
  xcodebuild -version 2>/dev/null || true
fi
echo "scheme: $(scheme_name)"
echo "simulator: $(sim_name) (tests: $(sim_test_name))"
echo "xcodeproj: $(find_xcodeproj)"
echo "prefer: $(cfg_get backend.prefer auto)"
