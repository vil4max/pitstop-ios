#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$SCRIPT_DIR/verify.sh"

echo "ci: danger slot (stub — skip)"
echo "ci: coverage slot (stub — skip)"
echo "ci: artifacts slot (stub — skip)"
echo "ci OK"
