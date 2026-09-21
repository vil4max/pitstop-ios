#!/usr/bin/env bash
# Deletes this app's leftovers: shut-down "Clone N of <device>" simulators that
# killed or hung test runs left behind, and test devices of worktrees that no
# longer exist. Other apps' devices and every booted device are left alone.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

/usr/bin/python3 "$SCRIPT_DIR/sim-device.py" clean "$(sim_test_name)" "$(sim_name)"

live=()
while IFS= read -r path; do
  live+=("$(basename "$path")")
done < <(git -C "$(project_root)" worktree list --porcelain 2>/dev/null | sed -n 's/^worktree //p')
/usr/bin/python3 "$SCRIPT_DIR/sim-device.py" prune "$(sim_test_base_name)" ${live[@]+"${live[@]}"}
