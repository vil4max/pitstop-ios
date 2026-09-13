#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

"$SCRIPT_DIR/clean.sh"

SCHEME="$(scheme_name)"
DD="${HOME}/Library/Developer/Xcode/DerivedData"
if [[ -n "$SCHEME" && -d "$DD" ]]; then
  find "$DD" -maxdepth 1 -type d -name "${SCHEME}-*" -exec rm -rf {} + 2>/dev/null || true
  echo "reset: cleared DerivedData for ${SCHEME}-*"
else
  echo "reset: no scheme-derived DerivedData cleared"
fi
