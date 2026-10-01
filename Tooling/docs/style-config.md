# Style configuration (SwiftLint / swift-format)

How style is configured in Runtime **0.2.1+**, what the default templates contain, and how to tighten rules safely.

Canonical templates in this repo:

- [`templates/swiftlint.yml`](../templates/swiftlint.yml) → installed as `Tooling/.swiftlint.yml`
- [`templates/swift-format`](../templates/swift-format) → installed as `Tooling/.swift-format`

Runtime commands: `just lint` / `just format` / `just verify` (see [api.md](api.md)).

## Ownership (do not lose edits)

| File | Owner | `install --force` / `just harness-update` | Reset |
|------|-------|------------------------------------------|-------|
| `Tooling/.swiftlint.yml` | **Runtime** with `pipeline: shared`, otherwise app | overwritten from the template on the shared pipeline; otherwise kept | `install.sh … --reset-style` |
| `Tooling/.swift-format` | **Runtime** with `pipeline: shared`, otherwise app | same | `install.sh … --reset-style` |
| `templates/swiftlint.yml` / `templates/swift-format` | Runtime (this repo) | the one style of every app on the shared pipeline | edit here; every app picks it up with its next update |

Every app on the shared pipeline has the same style (owner decision,
2026-09-21): an app-local rule change fails `just baseline` and is overwritten by
the next update. Three apps had three configs — Swift 5.10 vs 6.0 parsing,
trailing commas required in two apps and forbidden in the third, eight rules
disabled in one — so a change reviewed in one app was formatted differently in
the next. Change the template instead. The error thresholds were measured against all three
apps when set: none failed except one 8-member tuple in a OneCart test fixture,
which its sync turns into a struct rather than raising the limit for every app.
Measure a template change against every app before it lands.

Also related (not style engines, but gates):

| Key in `Tooling/runtime.yml` | Default | Effect |
|------------------------------|---------|--------|
| `lint` | `true` | when `false`, `just lint` / verify skip SwiftLint |
| `format` | `true` | when `false`, `just format` / verify skip swift-format |

## How to improve (manual)

### A. Tighten for **one app** (only an app not on the shared pipeline)

1. Edit the app files (committed with the app):
   - `Tooling/.swiftlint.yml`
   - `Tooling/.swift-format`
2. From the app root:

```bash
just lint
just format
just verify
```

3. Commit the Tooling style files with the app. `just harness-update` will **not** wipe them.

4. Optionally log the change in the harness [backlog](planning/backlog.md) if you expect the same tightening in a second app.

### B. Tighten the **default for all new / reset apps**

1. Edit the harness templates (`templates/swiftlint.yml`, `templates/swift-format`).
2. Update this doc when the behavior changes. The installed `.runtime-lock` is
   generated automatically from Runtime content; no manual version bump exists.
3. Existing apps keep their app-owned configs until you explicitly reset:

```bash
~/Developer/Personal/agent-tools/ios-agent-toolchain/scripts/install.sh /path/to/app --force --reset-style
```

Or only reset style without forcing the whole slice: `--reset-style` alone is enough to rewrite the two style files (other Tooling files still follow normal `--force` rules).

### C. Promote a recipe (not style) into Runtime

If the improvement is a **new `just` command**, not a lint rule — use the [backlog](planning/backlog.md) (second repeat / second app → harness).

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
| `disabled_rules` → `trailing_whitespace` | disabled | Does **not** fail on trailing spaces at end of lines (swift-format owns whitespace) |
| `opt_in_rules` | list | Extra rules enabled on top of defaults |
| `opt_in_rules` → `empty_count` | enabled | Prefers `.isEmpty` over `.count == 0` (and similar empty checks) |
| `opt_in_rules` → `force_unwrapping` | enabled (warning) | Flags `!` unwraps; the owner's Swift policy allows them only with a justification |
| `cyclomatic_complexity.ignores_case_statements` | `true` | A `switch` over enum cases does not count as branching logic |
| `function_body_length` | warning 80, error 120 | SwiftUI bodies run longer than the default 50/100 |
| `type_body_length` | warning 300, error 500 | Errors fail verify, so the error sits above the largest type in any app (381 lines) |
| `large_tuple` | warning 3, error 5 | Same reasoning; a 3+ member tuple still warns |
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
- `force_cast` / `force_try` — default severity
- `file_length` — default limits
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

## swift-format — current default setup

File: `Tooling/.swift-format` (from `templates/swift-format`), a JSON file.

Tool: Apple's swift-format, shipped in the Xcode toolchain (Xcode 16 or later) and run as `xcrun swift-format`.
Nothing is installed with Homebrew, and the version is the toolchain's: `just env` prints it (`main` today), so it
cannot be pinned apart from Xcode.

### Settings in the template (every setting)

| Key | Value | Meaning |
|-----|-------|---------|
| `version` | `1` | Configuration schema version |
| `lineLength` | `120` | Wrap width, aligned with SwiftLint `line_length: 120` (swift-format's own default is 100) |
| `indentation.spaces` | `4` | Indent width: **4 spaces** (swift-format's own default is 2) |
| `rules.NoAccessLevelOnExtensionDeclaration` | `false` | Rule off. Keeps `private extension Foo { … }` as the apps write it; the rule would move the access level onto every member |
| `rules.UseLetInEveryBoundCaseVariable` | `false` | Rule off. Keeps the hoisted `case let .loaded(value, date)`; the rule would rewrite it to `case .loaded(let value, let date)` |
| `rules.OrderedImports` | `false` | Rule off. Keeps the import order the apps already have; the rule would sort it differently |

The three disabled rules keep today's code style: with them on, swift-format would rewrite `private extension`,
hoisted `case let` and the import order in every app.

### Not set in the template (swift-format defaults apply)

- every other rule stays at its default (on, except the few that swift-format ships off, such as `NeverForceUnwrap`)
- `respectsExistingLineBreaks` `true`, `maximumBlankLines` `1`, `lineBreakBeforeEachArgument` `false`
- `multiElementCollectionTrailingCommas` `true`: multiline collections get a trailing comma, which SwiftLint's
  `trailing_comma: mandatory_comma` agrees with
- no exclude list: swift-format has no exclude option (see the file list below)

Print the effective configuration of an app, and see what the formatter would change:

```bash
xcrun swift-format dump-configuration --effective --configuration Tooling/.swift-format
xcrun swift-format lint --strict --configuration Tooling/.swift-format App/File.swift
```

### How Runtime invokes swift-format

`Tooling/scripts/format.sh`:

1. Skip if `runtime.yml` `format: false`.
2. Require the Xcode toolchain's swift-format: `xcrun --find swift-format` must succeed. Otherwise the script exits 1
   and says the Xcode toolchain provides it; there is no Homebrew repair.
3. Config path: `Tooling/.swift-format`, else app-root `.swift-format`, else harness `templates/swift-format`.
4. File list: swift-format has no exclude option, so Runtime passes the tracked Swift files from `git ls-files`,
   minus any under `Pods`, `.build`, `DerivedData` and `.claude`. It never walks the project root. The root must be a
   git repository, and a new file is formatted once it is added to git.
5. Locally: `xcrun swift-format format --in-place --parallel --configuration <conf> <files>` (formats in place).
   With `CI=true`: `xcrun swift-format lint --strict …`, so any warning fails and nothing is rewritten.

### Apps installed with the previous formatter

`install.sh` (and so `just harness-update`) writes `Tooling/.swift-format` and removes the previous formatter's config
files: the app's own in `Tooling/` and at the app root, and the template copy under `Tooling/templates/`. Nothing reads
them any more, and no flag keeps them. The app then needs one
format commit, because swift-format wraps and indents some constructs differently; list that commit in
`.git-blame-ignore-revs`.

---

## Other style-related Runtime config

### `todo_scan` (`Tooling/runtime.yml`)

| Key | Default | Meaning |
|-----|---------|---------|
| `todo_scan` | `false` | When `true`, `just verify` fails if `rg` finds `TODO(`, `FIXME(`, or `#warning` in `*.swift` |

Not SwiftLint — a separate verify gate (see [dod.md](dod.md)).

### Brew formulas

See [brewfile.md](brewfile.md): `swiftlint` is required when `lint: true`. swift-format is not a Brewfile entry; it comes with Xcode and is required when `format: true`.

---

## Checklist after changing style

```text
[ ] Edited the correct owner file (app Tooling/ vs harness templates/)
[ ] just lint
[ ] just format
[ ] just verify
[ ] If template changed: lint every app on the shared pipeline with it first (0 errors), update this doc
[ ] Friction log updated if the same tightening is needed in a second app
```

## Paths in `excluded`

SwiftLint resolves `excluded` paths against the directory of its config file.
The config lives in `Tooling/`, so an entry must start with `../` to reach the
repository root: `../DerivedData`, `../.claude`. Unprefixed entries only work
for a config placed at the root. Apps installed before 2026-09-21 carry
unprefixed entries that never matched; add the `../` lines by hand —
`harness-update` does not rewrite app-owned style files. swift-format has no
exclusions at all; `format.sh` hands it an explicit file list (see above). The
template also aligns two SwiftLint rules with swift-format's output
(`trailing_comma`, `opening_brace`); copy those blocks if the linter warns about
formatted code.
