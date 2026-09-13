# pitstop-ios — notes for AI agents

**Project context:** `personal` — local marker: `.agents/project-context.yaml`.

## Development entry

Read `PROJECT_STATUS.md`, then the **Agent development loop** in
`specs/24_PROJECT_MANAGEMENT_AND_GITFLOW.md` for implementation tasks.
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
- Task input: `specs/16_TASK_TEMPLATE.md`; evidence: PR and `specs/19_DEVELOPMENT_DIARY_AND_blog.md`.

`Tooling/backend/build/` contains tracked shell executors, not build output.
Keep `Tooling/runtime.local.yml`, `.codex/`, and local markers untracked.

## reference product

This repo is the reference product for:

> AI-assisted Product Engineer — design, develop, deploy, maintain.

When unfrozen / actively shipping, complete one end-to-end loop:

1. Owner-formulated problem / MVP (charter already exists).
2. AI-assisted delivery with human engineering review (agents as workflow, not unsupervised ship).
3. Deploy (TestFlight / App Store as applicable).
4. Maintain 1–2 months with metrics and feedback.

Do not start parallel pet products for the same reference goal.

## Freeze awareness

Read `PROJECT_STATUS.md` first. The approved infrastructure exception permits
agent-loop setup and verification of the existing app while product features
remain frozen. No feature/AI runtime implementation until unfreeze.

Product baseline (through M3) still precedes runtime AI features. Agent-assisted coding workflow during baseline work is allowed when the project is unfrozen and the owner asks for implementation.

## System over random

- Prefer specs + work plan over random feature ideas.
- Prefer one shipped loop over more architecture documents without ship.
- Do not claim production AI product maturity until runtime AI is shipped and evidenced.
