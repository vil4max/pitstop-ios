# Tooling

Agent Runtime slice from [ios-agent-toolchain](https://github.com/vil4max/ios-agent-toolchain). Not product code.

| Path | Role |
|------|------|
| `justfile` | Runtime recipes — imported by the app root `justfile` |
| `Brewfile` | CLI deps (`just`, `swiftlint`, `swiftformat`, `xcbeautify`, …) |
| `runtime.yml` | App-owned: scheme / project / simulator / lint-format-test flags |
| `runtime.local.yml.example` | Copy to `runtime.local.yml` for local overrides (gitignored) |
| `runtime.manifest.json` | Declared Runtime commands / capabilities |
| `.runtime-lock` | Automatic content identity used for compatible worktree materialization |
| `.swiftformat` / `.swiftlint.yml` | **App-owned** style configs (`just format` / `just lint`) |
| `scripts/` | Shell implementations invoked by recipes |
| `backend/` | Build adapters (`xcodebuild` baseline; others optional) |
| `docs/host-backends.md` | Notes on optional host build adapters |
| `docs/style-config.md` | Style manual + full catalog of default lint/format settings |

## Ownership

| Artifact | Owner | `just harness-update` (`--force`) |
|----------|-------|-----------------------------------|
| `Tooling/**` except app-owned files below | Runtime | overwrites |
| `Tooling/runtime.yml` | App | not touched (`install --reset-config`) |
| `Tooling/.swiftlint.yml` / `.swiftformat` | App | not touched (`install --reset-style`) |
| App root `justfile` | App | never overwritten after first create |
| App root `scripts/*` | App | never touched |

Style how-to: [docs/style-config.md](docs/style-config.md).

## From the app repo root

```bash
brew bundle --file=Tooling/Brewfile
just doctor
just build
just test
just verify
just run-sim
```

`just harness-update` refreshes this slice from
`~/Developer/Personal/ios-agent-toolchain` or `IOS_AGENT_RUNTIME_ROOT`.
