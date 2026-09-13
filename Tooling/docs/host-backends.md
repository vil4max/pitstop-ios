# Optional host backends (not required for just build)

## Apple xcode-tools (Cursor)

Enable the built-in Xcode MCP in Cursor. Keep Xcode open with the app project for a healthy toolset (`BuildProject`, tests, etc.).

Runtime still builds via `xcodebuild` when tools are empty or Xcode is closed.

## XcodeBuildMCP (optional)

Third-party CLI MCP for simulator workflows without Xcode UI. Never required for `just build`.
