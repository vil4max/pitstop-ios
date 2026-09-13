#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"
# shellcheck source=capabilities.sh
source "$SCRIPT_DIR/capabilities.sh"

echo "=== diagnose ==="
echo "harness: $(harness_version)"
echo "scheme: $(scheme_name)"
echo "configuration: Debug"
echo "simulator: $(sim_name)"
echo "destination: $(destination_spec)"
echo "xcodeproj: $(find_xcodeproj)"
echo "xcworkspace: $(find_xcworkspace)"
echo "backend.prefer: $(cfg_get backend.prefer auto)"
echo "backend.selected: $(select_build_backend)"
if have xcodebuild; then
  echo "--- xcodebuild -version ---"
  xcodebuild -version || true
fi
if have swift; then
  echo "--- swift --version ---"
  swift --version 2>&1 | head -n 2 || true
fi
if have xcrun; then
  echo "--- simctl (matching name) ---"
  xcrun simctl list devices available 2>/dev/null | grep -F "$(sim_name)" || echo "(no match)"
fi
DD="${HOME}/Library/Developer/Xcode/DerivedData"
echo "DerivedData: $DD"
if [[ -d "$DD" ]]; then
  du -sh "$DD" 2>/dev/null || true
fi
if [[ -f "${CURSOR_MCP_JSON:-$HOME/.cursor/mcp.json}" ]]; then
  echo "mcp.json: present"
else
  echo "mcp.json: missing"
fi
if command -v cursor >/dev/null 2>&1; then
  echo "cursor CLI: present"
else
  echo "cursor CLI: (not on PATH)"
fi
echo "=== end diagnose ==="
