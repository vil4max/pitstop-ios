# Optional host backends (not required for just build)

## Simulator interaction

Simulator interaction (launch, screenshot, tap, inspect) uses Claude Code's
built-in iOS Simulator tool. XcodeBuildMCP and the xcode-tools MCP are reserve
backends: off by default, reversible, not part of the default loadout
(KIT-D-008).

## XcodeBuildMCP and xcode-tools (reserve)

Both return from reserve only for a task that specifically needs them — LLDB
and physical-device workflows have no built-in-tool equivalent today. Runtime
builds (`just build`, `just test`, `just run-sim`) always run through the
Runtime itself, never through an MCP path, and never require either.
