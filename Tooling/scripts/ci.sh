#!/usr/bin/env bash
# The CI entry point: the same gate as `just verify`, plus a result bundle at a
# fixed path for the job summary, artifacts and a requirement-trace join.
#
# An app with extra CI work (another test plan, coverage conversion) overrides
# the `ci` recipe in its root justfile and calls this script first; the GitHub
# workflow is identical in every app and only runs `just ci`.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

export RUNTIME_RESULT_BUNDLE="${RUNTIME_RESULT_BUNDLE:-$(project_root)/build/ci/results/tests.xcresult}"
"$SCRIPT_DIR/verify.sh"
echo "ci OK (result bundle: $RUNTIME_RESULT_BUNDLE)"
