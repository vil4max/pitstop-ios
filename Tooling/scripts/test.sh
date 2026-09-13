#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"
# shellcheck source=capabilities.sh
source "$SCRIPT_DIR/capabilities.sh"

if ! cfg_bool tests true; then
  echo "tests skipped (runtime.yml tests: false)"
  exit 0
fi

[[ -n "$BACKEND_ROOT" ]] || { echo "backend root missing — expected Tooling/backend or ./backend" >&2; exit 1; }

BACKEND="$(select_build_backend)"
echo "test backend: $BACKEND"

case "$BACKEND" in
  xcode_tools)
    exec "$BACKEND_ROOT/build/xcode_tools/test.sh"
    ;;
  xcodebuild_mcp)
    exec "$BACKEND_ROOT/build/mcp/test.sh"
    ;;
  swiftpm)
    exec "$BACKEND_ROOT/build/swiftpm/test.sh"
    ;;
  xcodebuild|*)
    exec "$BACKEND_ROOT/build/xcodebuild/test.sh"
    ;;
esac
