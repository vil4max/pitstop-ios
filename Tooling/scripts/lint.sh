#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

if ! cfg_bool lint true; then
  echo "lint skipped (runtime.yml lint: false)"
  exit 0
fi

if ! have swiftlint; then
  echo "swiftlint not installed — brew bundle --file=$(brewfile_path)" >&2
  exit 1
fi

ROOT="$(project_root)"
CONF="$TOOLING_ROOT/.swiftlint.yml"
[[ -f "$CONF" ]] || CONF="$ROOT/.swiftlint.yml"
[[ -f "$CONF" ]] || CONF="$RUNTIME_ROOT/templates/swiftlint.yml"
(cd "$ROOT" && swiftlint --config "$CONF")
