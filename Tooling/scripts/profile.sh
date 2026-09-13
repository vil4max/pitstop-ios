#!/usr/bin/env bash
set -euo pipefail
echo '{"ok":false,"reason":"not_configured","command":"profile","availability":"stub"}'
echo "just profile is a stub — use xctrace / Instruments later." >&2
exit 1
