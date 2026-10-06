# PitStop — project facts

<!-- repository-visibility-policy -->
Repository visibility: **PUBLIC**.

## Data handling

Everything committed here is public, including history, commit messages,
issues, and pull requests. Never add real vehicle data (VIN, plates, policy
numbers, payments), personal or financial details, or personal plans; use
fictional examples. A private-data scan runs before every push. Never
commit credentials, tokens, passwords, session data, or private keys.
<!-- /repository-visibility-policy -->

## What the app is

PitStop is an iOS 27 app that keeps a car's memory: save a thought, record what
was actually done, and see which service and dates come next. Swift 6 language
mode, SwiftUI, SwiftData, App Intents, WidgetKit, MVVM. Product contracts are in
`docs/requirements/`, decisions in `docs/decisions/`, status in
`PROJECT_STATUS.md`, the documentation index in `docs/README.md`.

## Folder structure

- `Pitstop/` — app target: `App/` (composition, intents), `DesignSystem/`,
  `Domain/` (pure domain code: capture, maintenance, road, store, vehicle),
  `Features/` (screens and view models per feature), `Infrastructure/`
  (persistence, analytics, logging, interpretation, car photo).
- `PitstopWidgets/` — widget and control extension; `Shared/` — code compiled
  into both targets.
- `PitstopTests/` — Swift Testing and XCTest suites, grouped like the app.
- `Config/` — build configuration; `ci_scripts/` — Xcode Cloud scripts;
  `Tooling/` — installed build and release tooling; `docs/` — specifications.

## Build and test

- Project and scheme: `Pitstop.xcodeproj` / `Pitstop`.
- Simulator and gate settings: `Tooling/runtime.yml`.
- Environment check: `just doctor --json`.
- Gate: `just verify` (build, format, lint, tests).
- Release preflight after committing verified contents: `just release --check`.
- CI: a push to `main` runs the tests on GitHub-hosted runners and builds
  nothing. TestFlight builds are tag-gated
  ([ADR 0013](docs/decisions/0013-shared-ci-and-tag-gated-testflight.md),
  `Tooling/docs/testflight.md`).
- `Tooling/backend/build/` contains tracked shell executors, not build output.
  Keep `Tooling/runtime.local.yml` untracked.
- Documentation-only and configuration-only changes need no app build.

## Conventions

- Spec pyramid: core ([`docs/core.md`](docs/core.md)) → requirements and
  decisions → tests named `REQ-<AREA>-NNN` → code. A change starts at the
  highest affected layer; a bug starts with a failing test named with its
  requirement ID.
- AI proposes; deterministic domain code validates and decides. Persistence sits
  behind a command-only store. Runtime AI stays behind its rollout gate (core
  P4, ADR 0027): the Foundation Models path runs in debug builds only.
- Unknown data stays unknown; no invented vehicle facts.
- Colours come from design-system roles, never literals in features.
- Strings live in String Catalogs (en, uk, ru).
- Examples, fixtures and mockups use fictional data only.
- Commit messages follow Conventional Commits: `<type>[(<scope>)]: <summary>`
  with a lowercase imperative summary and no final period.
