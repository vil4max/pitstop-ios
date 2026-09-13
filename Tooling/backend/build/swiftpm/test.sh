#!/usr/bin/env bash
set -euo pipefail
if [[ -f Package.swift ]]; then
  swift test
else
  echo "swiftpm backend requires Package.swift" >&2
  exit 1
fi
