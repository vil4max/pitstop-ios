# pitstop-ios — notes for AI agents

**Project context:** `personal` — local marker: `.agents/project-context.yaml`.

## Development entry

Read `PROJECT_STATUS.md`, then the **Agent development loop** in
`docs/engineering/agent-loop-and-gitflow.md` for implementation tasks.
That loop explicitly delegates independent review to a separate agent when
the host supports it. If unavailable, report independent review as pending.

Shared behavior and skills: `${AGENTS_KIT_ROOT:-${DEV_ROOT:-$HOME/Developer/Personal}/agent-engineering-kit}`.
Open its `AGENTS.md` when shared policy is not loaded. Project execution uses
the installed `Tooling/` slice from `ios-agent-toolchain`.

- Project/scheme: `Pitstop.xcodeproj` / `Pitstop`.
- Simulator and gate settings: `Tooling/runtime.yml`.
- Environment: `just doctor --json`.
- Local implementation gate: `just verify`.
- PR gate: `just verify-ci` (includes formatting check and the same Runtime gate).
- Release preflight after committing verified contents: `just release --check`.
- Task input: `docs/tasks/template.md`; evidence: the PR.

`Tooling/backend/build/` contains tracked shell executors, not build output.
Keep `Tooling/runtime.local.yml`, `.codex/`, and local markers untracked.

## Spec pyramid

Start from [`docs/core.md`](docs/core.md) (approved 2026-09-16). Layers:
core → `docs/requirements/` + `docs/decisions/` → tests named with
`REQ-<AREA>-NNN` → code. Index: [`docs/README.md`](docs/README.md). Method:
kit skill `spec-pyramid`.

- Change starts at the highest affected layer; propose, do not approve, core
  or requirement edits.
- Bug → failing spec with a REQ ID first, then the fix.
- Record a lesson only when a check or upper layer changed:
  [`docs/lessons.md`](docs/lessons.md).

## Project state

Read `PROJECT_STATUS.md` first. Product feature implementation is unfrozen
(2026-09-16); the owner still assigns tasks. Product baseline (through M3)
precedes runtime AI features (core P4).

## System over random

- Prefer specs + work plan over random feature ideas.
- Prefer one shipped loop over more architecture documents without ship.
- Do not claim production AI product maturity until runtime AI is shipped and evidenced.
