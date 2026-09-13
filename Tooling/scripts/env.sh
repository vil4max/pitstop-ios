#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

echo "Runtime: $(harness_version)"
echo "PWD: $PWD"
for b in just git gh yq jq swift swiftformat swiftlint xcodebuild xcbeautify xcrun; do
  if have "$b"; then
    ver="$($b --version 2>/dev/null | head -n 1 || true)"
    echo "$b: ${ver:-present}"
  else
    echo "$b: MISSING"
  fi
done
if have xcodebuild; then
  xcodebuild -version 2>/dev/null || true
fi
echo "scheme: $(scheme_name)"
echo "simulator: $(sim_name)"
echo "xcodeproj: $(find_xcodeproj)"
echo "prefer: $(cfg_get backend.prefer auto)"
