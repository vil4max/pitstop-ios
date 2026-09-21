#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

if ! cfg_bool format true; then
  echo "format skipped (runtime.yml format: false)"
  exit 0
fi

if ! have swiftformat; then
  echo "swiftformat not installed — brew bundle --file=$(brewfile_path)" >&2
  exit 1
fi

ROOT="$(project_root)"
CONF="$TOOLING_ROOT/.swiftformat"
[[ -f "$CONF" ]] || CONF="$ROOT/.swiftformat"
[[ -f "$CONF" ]] || CONF="$RUNTIME_ROOT/templates/swiftformat"
# CI checks and never rewrites: a rewrite on a runner would pass a commit whose
# committed files are still unformatted.
if [[ "${CI:-}" == true ]]; then
  swiftformat "$ROOT" --config "$CONF" --lint
else
  swiftformat "$ROOT" --config "$CONF"
fi
