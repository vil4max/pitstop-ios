#!/usr/bin/env bash
set -euo pipefail
echo "xcode_tools build provider not healthy in this environment; falling back is handled by scripts/build.sh" >&2
echo "Open Xcode with the project for Apple MCP tools, or use xcodebuild (default auto)." >&2
exit 1
