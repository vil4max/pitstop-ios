# Style configuration (SwiftLint / SwiftFormat)

How style is configured in Runtime **0.2.1+**, what the default templates contain, and how to tighten rules safely.

Canonical templates in this repo:

- [`templates/swiftlint.yml`](../templates/swiftlint.yml) → installed as `Tooling/.swiftlint.yml`
- [`templates/swiftformat`](../templates/swiftformat) → installed as `Tooling/.swiftformat`

Runtime commands: `just lint` / `just format` / `just verify` (see [api.md](api.md)).

## Ownership (do not lose edits)

| File | Owner | `install --force` / `just harness-update` | Reset |
|------|-------|------------------------------------------|-------|
| `Tooling/.swiftlint.yml` | **App** | not overwritten | `install.sh … --reset-style` |
| `Tooling/.swiftformat` | **App** | not overwritten | `install.sh … --reset-style` |
| `templates/swiftlint.yml` / `templates/swiftformat` | Runtime (this repo) | source of defaults for **new** installs and `--reset-style` | edit here for fleet-wide defaults |

Also related (not style engines, but gates):

| Key in `Tooling/runtime.yml` | Default | Effect |
|------------------------------|---------|--------|
| `lint` | `true` | when `false`, `just lint` / verify skip SwiftLint |
| `format` | `true` | when `false`, `just format` / verify skip SwiftFormat |

## How to improve (manual)

### A. Tighten for **one app** (recommended first)

1. Edit the app files (committed with the app):
   - `Tooling/.swiftlint.yml`
   - `Tooling/.swiftformat`
2. From the app root:

```bash
just lint
just format
just verify
```

3. Commit the Tooling style files with the app. `just harness-update` will **not** wipe them.

4. Optionally log the change in the harness [friction-log.md](friction-log.md) if you expect the same tightening in a second app.

### B. Tighten the **default for all new / reset apps**

1. Edit the harness templates (`templates/swiftlint.yml`, `templates/swiftformat`).
2. Update this doc when the behavior changes. The installed `.runtime-lock` is
   generated automatically from Runtime content; no manual version bump exists.
3. Existing apps keep their app-owned configs until you explicitly reset:

```bash
~/Developer/Personal/ios-agent-toolchain/scripts/install.sh /path/to/app --force --reset-style
```

Or only reset style without forcing the whole slice: `--reset-style` alone is enough to rewrite the two style files (other Tooling files still follow normal `--force` rules).

### C. Promote a recipe (not style) into Runtime

If the improvement is a **new `just` command**, not a lint rule — use [friction-log.md](friction-log.md) (second repeat / second app → harness).

---

## SwiftLint — current default setup

File: `Tooling/.swiftlint.yml` (from `templates/swiftlint.yml`).

Tool versions on the reference Mac when this doc was written: SwiftLint **0.65.x** (exact version comes from Homebrew; see `just env`).

### Behavior summary

SwiftLint enables its **built-in default rule set**, then applies the overrides below.

- Rules listed under `disabled_rules` are **off**.
- Rules listed under `opt_in_rules` are **on** (they are not part of the default set until opted in).
- Everything else follows SwiftLint defaults for the installed CLI version (see `swiftlint rules` locally for the full list).

### Keys in the template (every setting)

| Key / setting | Value in template | Meaning |
|---------------|-------------------|---------|
| `disabled_rules` | list | Rules that would otherwise run but are turned **off** |
| `disabled_rules` → `trailing_whitespace` | disabled | Does **not** fail on trailing spaces at end of lines (SwiftFormat often owns whitespace) |
| `opt_in_rules` | list | Extra rules enabled on top of defaults |
| `opt_in_rules` → `empty_count` | enabled | Prefers `.isEmpty` over `.count == 0` (and similar empty checks) |
| `excluded` | list of paths | Directories/files skipped by lint |
| `excluded` → `Pods` | excluded | CocoaPods vendor tree |
| `excluded` → `.build` | excluded | SwiftPM build products |
| `excluded` → `DerivedData` | excluded | Xcode DerivedData (if present under the scanned root) |
| `line_length` | `120` | Soft/hard line length threshold used by the `line_length` rule (SwiftLint default rule; warning/error thresholds follow SwiftLint’s rule defaults unless you add nested keys) |
| `identifier_name` | mapping | Configures the `identifier_name` rule |
| `identifier_name.min_length` | `2` | Minimum identifier length (allows short names like `id`, `x`) |

### Not set in the template (inherit SwiftLint defaults)

Examples of commonly customized keys that are **absent** today (defaults apply):

- `included` — not set (SwiftLint decides from the working directory; Runtime runs `swiftlint` from the app root)
- `reporter` — default reporter
- `force_cast` / `force_try` / `force_unwrapping` — default severity
- `type_body_length`, `file_length`, `function_body_length` — default limits
- `analyzer_rules` — not configured
- custom `rules:` / `custom_rules:` — none

To inspect the effective rule list on your machine:

```bash
cd /path/to/app
swiftlint rules
swiftlint lint --config Tooling/.swiftlint.yml
```

### How Runtime invokes SwiftLint

`Tooling/scripts/lint.sh`:

1. Skip if `runtime.yml` `lint: false`.
2. Require `swiftlint` on `PATH` (Brewfile: `Tooling/Brewfile`).
3. Config path: `Tooling/.swiftlint.yml`, else app-root `.swiftlint.yml`, else harness `templates/swiftlint.yml`.
4. Run from the app root: `swiftlint --config <conf>`.

---

## SwiftFormat — current default setup

File: `Tooling/.swiftformat` (from `templates/swiftformat`).

Tool versions on the reference Mac when this doc was written: SwiftFormat **0.62.x**.

### Options in the template (every setting)

| Option | Value | Meaning |
|--------|-------|---------|
| `--swiftversion` | `5.10` | Language version SwiftFormat uses for parsing/formatting decisions |
| `--indent` | `4` | Indent width: **4 spaces** (matches Brain `swift-formatting` preference) |
| `--maxwidth` | `120` | Wrap / width guidance aligned with SwiftLint `line_length: 120` |
| `--disable consecutiveBlankLines` | disabled | Do **not** enforce collapsing consecutive blank lines |
| `--disable blankLinesAtStartOfScope` | disabled | Do **not** remove/require blank lines at the start of `{ … }` scopes (keeps room for project taste / MARK layout) |
| `--exclude Pods` | excluded | Skip CocoaPods tree |
| `--exclude .build` | excluded | Skip SwiftPM build dir |
| `--exclude DerivedData` | excluded | Skip DerivedData if under the tree |

### Not set in the template (SwiftFormat defaults apply)

Examples absent today:

- `--allman`, `--semicolons`, `--commas`, `--wraparguments`, `--trimwhitespace` — tool defaults
- `--header` / file header insertion — not used
- `--swiftversion` beyond `5.10` — not auto-synced to the Xcode project’s `SWIFT_VERSION`
- rule enable lists beyond the two `--disable` entries — all other SwiftFormat rules stay at defaults

List rules for your CLI:

```bash
swiftformat --rules
swiftformat --config Tooling/.swiftformat --dryrun .
```

### How Runtime invokes SwiftFormat

`Tooling/scripts/format.sh`:

1. Skip if `runtime.yml` `format: false`.
2. Require `swiftformat` on `PATH`.
3. Config path: `Tooling/.swiftformat`, else app-root `.swiftformat`, else harness `templates/swiftformat`.
4. Run: `swiftformat <app-root> --config <conf>` (formats in place).

---

## Other style-related Runtime config

### `todo_scan` (`Tooling/runtime.yml`)

| Key | Default | Meaning |
|-----|---------|---------|
| `todo_scan` | `false` | When `true`, `just verify` fails if `rg` finds `TODO(`, `FIXME(`, or `#warning` in `*.swift` |

Not SwiftLint — a separate verify gate (see [dod.md](dod.md)).

### Brew formulas

See [brewfile.md](brewfile.md): `swiftlint` and `swiftformat` are required when the matching `runtime.yml` flags are `true`.

---

## Checklist after changing style

```text
[ ] Edited the correct owner file (app Tooling/ vs harness templates/)
[ ] just lint
[ ] just format
[ ] just verify
[ ] If template changed: version bump + this doc updated + --reset-style only where intended
[ ] Friction log updated if the same tightening is needed in a second app
```
