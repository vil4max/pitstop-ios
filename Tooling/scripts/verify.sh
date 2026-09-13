#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"
# Older minimal installations may not include backend capability detection.
if [[ -f "$SCRIPT_DIR/capabilities.sh" ]]; then
  # shellcheck source=capabilities.sh
  source "$SCRIPT_DIR/capabilities.sh"
fi

receipt() { python3 "$SCRIPT_DIR/verification-state.py" "$@"; }
receipt invalidate
"$SCRIPT_DIR/format.sh"
verified_state="$(receipt fingerprint)"
"$SCRIPT_DIR/lint.sh"

# Build test artifacts once; a second xcodebuild test would compile them again.
if declare -F select_build_backend >/dev/null && [[ "$(select_build_backend)" == xcodebuild ]]; then
  RUNTIME_XCODEBUILD_BUILD_FOR_TESTING=true "$SCRIPT_DIR/build.sh"
  RUNTIME_XCODEBUILD_WITHOUT_BUILDING=true "$SCRIPT_DIR/test.sh"
else
  "$SCRIPT_DIR/build.sh"
  "$SCRIPT_DIR/test.sh"
fi

if cfg_bool todo_scan false; then
  if have rg; then
    if rg -n 'TODO\(|FIXME\(|#warning' --glob '*.swift' "$(project_root)" ; then
      echo "todo_scan found markers" >&2
      exit 1
    fi
  fi
fi

if cfg_bool tests true && cfg_bool lint true; then
  receipt record "$verified_state"
else
  echo "Release evidence not recorded: tests or lint disabled." >&2
fi
echo "verify OK (DoD)"
