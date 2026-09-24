# Task — Align Pitstop's process docs with the kit (KIT-D-043)

Assignee: Pitstop (local_1b8d76c5-4a66-436c-9d0f-8e59157a2252), host Claude desktop
State: done
Requested by: SDLC Orchestrator relaying owner request (2026-09-24)
Evidence: `f8383b1`…`37343af` on `redesign/ios27`; `just verify` passed on `37343af` (verify OK: build, lint and the unit test suite; no test targets these docs); `brief_lint.py --root . --strict` 0 problems; `spec_trace.py --root .` no unknown IDs
Depends-on: none
Parallelism: none
Profile: fast

## Current status and authorization

Current outcome: done; the six Writer steps landed, plus the SYS-008 scheduling line in `work-plan.md` (`37343af`).
Authorized scope: the owner approved the pilot-minimum package on 2026-09-24
("да", kit `docs/tasks/ios-sdlc-review.md`, "### Pilot-minimum package"),
whose pilot plan makes this alignment card its own `Profile: fast` brief
before the first product round (KIT-D-043 point 2: Pitstop goes first). In
this session on 2026-09-24 the owner approved the RD-012 pilot plan
(ExitPlanMode), whose Part A is this card, and chose "1.2.0 after RD-012
(Recommended)" for the release scope.
Blocking decisions: none.
Permitted deviations: none.
Material assumptions: the What to Test draft lives in
`docs/operations/releases/1.2.0.md` until the `tf-1.2.0-1` annotation is
written from it (KIT-D-027 point 1); checked against
`Tooling/docs/testflight.md`, "Round procedure".
Next step: none; RD-012 opens in `rd-012-car-profile.md`.
Requirements: none (process documents only).
Acceptance specs: `brief_lint.py --root . --strict` clean; `spec_trace.py --root .`
reports no unknown IDs; `just verify` passes on the last commit.
Owned files: `docs/engineering/agent-loop-and-gitflow.md`, `AGENTS.md`,
`docs/tasks/redesign-ios27.md`, `CHANGELOG.md`,
`docs/decisions/0005-toolchain-and-project-format.md`,
`docs/operations/releases/1.2.0.md`, `docs/planning/work-plan.md`, this brief.
Out of scope: `docs/tasks/template.md`, the PR template, product docs and
code; any Runtime (`Tooling/**`) change; the Copilot commit block
(KIT-D-043 point 3 belongs to the kit's `sync-commit-policy.py`).
Failure conditions: a project fact (scheme, gate command, CI, tag format,
branch naming) is lost; kit policy is restated instead of linked; a process
contradiction listed in KIT-D-043 survives.

## Evidence history

- 2026-09-24: claimed from `redesign/ios27` at `73e3c3d` (`086dc4c`).
- 2026-09-24, `37343af`: `just verify` → verify OK (build, lint, unit tests;
  20:06–20:07 UTC); `brief_lint.py --root . --strict` → 2 briefs, 0 problems;
  `spec_trace.py --root .` → 225 requirements, 167 covered, no unknown IDs;
  `git diff --check` clean per commit. The kit's KIT-D-043 registry static
  test is not run: it is not part of the pilot's landed scripts.

## Untested scope

- Documents only: no test covers their wording; the checks are the lints
  named under Acceptance specs.

## Writer steps

- [x] Trunk-based fast-forward flow, kit review scale and brief evidence in `agent-loop-and-gitflow.md`: `git diff --check` — f8383b1
- [x] `AGENTS.md` points to the loop and the brief, tag authority to the kit: `git diff --check` — 9aa083a
- [x] Drop the Resume-prompt residue from `redesign-ios27.md`, move RD-012 out and SYS-008 after 1.2.0: `brief_lint.py --root . --strict` — 5af607e
- [x] `CHANGELOG.md` with `## [unreleased]`: file present — 1e3766b
- [x] ADR 0005 marks the Xcode 27.2 beta as an experiment (KIT-D-040): `git diff --check` — f60e370
- [x] DEV-WIDGET and DEV-PIT-SHEET as What to Test items in `releases/1.2.0.md`: `git diff --check` — ad2c89e

## Current checklist

- [x] every Writer step landed, `just verify` passed, `State: done`
