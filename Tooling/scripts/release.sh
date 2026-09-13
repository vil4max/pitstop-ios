#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ "${1:-}" == "--check" && "$#" -eq 1 ]]; then
  exec python3 "$SCRIPT_DIR/verification-state.py" check
fi
if [[ "$#" -gt 0 ]]; then
  echo "Usage: release.sh [--check]" >&2
  exit 2
fi
echo '{"ok":false,"reason":"not_configured","command":"release","availability":"stub"}'
echo "just release is a stub — configure Fastlane later." >&2
exit 1
