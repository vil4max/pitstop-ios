#!/usr/bin/env bash
# Release preflight: the committed contents pass the full gate.
#
# Usage: scripts/release-check.sh
#
# It fails on uncommitted or untracked files, runs `ios-verify --all` (lint of
# every Swift file, build, unit tests) on the clean tree, and fails when the run
# changed a tracked file or HEAD moved. `ios-verify` keeps no record of a pass,
# so the preflight runs the gate itself instead of trusting an earlier run.
# The tag checks of a TestFlight round are ci_scripts/tf-check.sh
# (docs/operations/testflight.md).
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
cd "$root"

# The ios-dev plugin puts ios-verify on the PATH; IOS_VERIFY names another copy.
gate="${IOS_VERIFY:-ios-verify}"
command -v "$gate" >/dev/null 2>&1 \
  || { echo "release-check: $gate not found; enable the ios-dev plugin or set IOS_VERIFY" >&2; exit 2; }

clean() {
  [[ -z "$(git status --porcelain --untracked-files=all)" ]]
}

clean || { echo "release-check: commit the contents to release first; the working tree is not clean" >&2; exit 1; }
head="$(git rev-parse HEAD)"

"$gate" --all

clean || { echo "release-check: the gate changed the working tree; review and commit, then rerun" >&2; exit 1; }
[[ "$(git rev-parse HEAD)" == "$head" ]] || { echo "release-check: HEAD moved during the run; rerun" >&2; exit 1; }
echo "Release preflight OK: verified contents match HEAD $head"
