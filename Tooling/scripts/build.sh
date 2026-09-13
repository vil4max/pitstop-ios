#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"
# shellcheck source=capabilities.sh
source "$SCRIPT_DIR/capabilities.sh"

[[ -n "$BACKEND_ROOT" ]] || { echo "backend root missing — expected Tooling/backend or ./backend" >&2; exit 1; }

BACKEND="$(select_build_backend)"
echo "build backend: $BACKEND"

case "$BACKEND" in
  xcode_tools)
    exec "$BACKEND_ROOT/build/xcode_tools/build.sh"
    ;;
  xcodebuild_mcp)
    exec "$BACKEND_ROOT/build/mcp/build.sh"
    ;;
  swiftpm)
    exec "$BACKEND_ROOT/build/swiftpm/build.sh"
    ;;
  xcodebuild|*)
    exec "$BACKEND_ROOT/build/xcodebuild/build.sh"
    ;;
esac
