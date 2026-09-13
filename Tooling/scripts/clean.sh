#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

ROOT="$(project_root)"
rm -rf "$ROOT/.build" 2>/dev/null || true
echo "clean: removed .build if present"
echo "tip: just reset also clears DerivedData for this project name"
