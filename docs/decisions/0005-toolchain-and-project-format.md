# Toolchain Baseline and Project Format

**Status:** Accepted (owner directive, 2026-09-20)\
**Decision:** build with the Swift 6 language mode, target iOS 27.0, and let
Xcode derive target membership from the file system.

## Context

The backlog adds well over a hundred source files. The project listed every
file by hand in `project.pbxproj` (object version 56), so each new file needed
four coordinated edits, and a missed edit silently dropped a test file from
the run. The targets also compiled in the Swift 5 language mode, which reports
data-race problems as warnings that nobody is forced to read.

## Decision

- `SWIFT_VERSION = 6.0` for both targets, so isolation and `Sendable`
  violations fail the build instead of surfacing at runtime.
- `SWIFT_APPROACHABLE_CONCURRENCY = YES`. Default actor isolation stays
  `nonisolated`: the domain layer is pure value types that persistence and
  projections use off the main actor, and a module-wide `@MainActor` default
  would force `nonisolated` annotations across that whole layer. UI types opt
  in to `@MainActor` explicitly.
- `IPHONEOS_DEPLOYMENT_TARGET = 27.0`. PitStop has no shipped user base to
  keep on iOS 26, and a single OS floor removes availability branches from
  the design-system and Foundation Models code.
- Project object version 77 with `PBXFileSystemSynchronizedRootGroup` for
  `Pitstop/` and `PitstopTests/`. A file is a target member because of where
  it lives. `Pitstop.entitlements.example` is the only membership exception,
  because it is a template and must not ship in the bundle.

## Rejected alternatives

- **Keep manual file references.** No benefit for a single-module app, and it
  is the most likely way for an agent-authored change to lose a file.
- **Generate the project (XcodeGen / Tuist).** Adds a dependency and a
  generation step to every checkout; synchronized groups solve the same
  problem natively.
- **`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.** Convenient for views, but
  wrong for the domain and persistence layers described above.

## Consequences

- Anything placed under `Pitstop/` ships in the app. Templates, notes, and
  scratch files belong elsewhere or in the exception set.
- Xcode 16 or later is required to open the project; the documented floor is
  Xcode 27.
