#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# An installed Tooling/scripts/verify.sh targets the app around it (below, DoD).
# The Runtime source checkout has no app to build: its own `just verify` is the
# contract-test gate instead, every tests/*.sh plus each generator's --check
# (none exist yet) (KIT-D-037).
if [[ "$(basename "$(dirname "$SCRIPT_DIR")")" != "Tooling" ]]; then
  exec "$SCRIPT_DIR/run-contract-tests.sh"
fi

# An installed Tooling/ that cannot find its own scripts is broken (a partial
# install, an interrupted worktree checkout) rather than missing an optional
# extra: fail with one clear message instead of whichever script happens to
# crash first with a raw "No such file" (KIT-D-037). capabilities.sh and
# baseline.py stay optional below (older minimal installations may lack
# either) and are not required here.
required_scripts=(lib.sh verification-state.py format.sh lint.sh build.sh test.sh)
missing_scripts=()
for required in "${required_scripts[@]}"; do
  [[ -f "$SCRIPT_DIR/$required" ]] || missing_scripts+=("$required")
done
if [[ "${#missing_scripts[@]}" -gt 0 ]]; then
  echo "verify: installed Tooling/scripts/ is missing ${missing_scripts[*]}; run \`just harness-update\` to repair it" >&2
  exit 1
fi

# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"
# Older minimal installations may not include backend capability detection.
if [[ -f "$SCRIPT_DIR/capabilities.sh" ]]; then
  # shellcheck source=capabilities.sh
  source "$SCRIPT_DIR/capabilities.sh"
fi

receipt() { python3 "$SCRIPT_DIR/verification-state.py" "$@"; }
receipt invalidate
# The shared baseline first: drifted pipeline files or simulator settings fail
# before any build. A sibling Runtime source checkout, when IOS_AGENT_RUNTIME_ROOT
# names one, adds lag and style warnings; there is no default path to reach back
# into (KIT-D-037) — without it, baseline just skips that comparison.
if [[ -f "$SCRIPT_DIR/baseline.py" ]]; then
  runtime_checkout="${IOS_AGENT_RUNTIME_ROOT:-}"
  if [[ -n "$runtime_checkout" && -d "$runtime_checkout/scripts" && "${CI:-}" != true ]]; then
    python3 "$SCRIPT_DIR/baseline.py" "$(project_root)" --runtime "$runtime_checkout"
  else
    python3 "$SCRIPT_DIR/baseline.py" "$(project_root)"
  fi
fi
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
