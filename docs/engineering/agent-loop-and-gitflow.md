# Project Management and Git Flow

## Decision

The backlog lives in the repository: [`../planning/work-plan.md`](../planning/work-plan.md)
lists open work only, multi-session tasks get a brief from
[`../tasks/template.md`](../tasks/template.md), and delivered work is recorded
by ADRs and commit history.

The GitHub Project board and its issues were retired on 2026-09-21: the board
had lost its cards when the pre-public repository was deleted (ADR 0014), and a
second planning surface duplicated the work plan. The template in
`.github/ISSUE_TEMPLATE/` remains for a task filed as an issue. Do not add Trello or another tracker; revisit only if
non-technical collaborators need a simpler planning surface.

## Work hierarchy

``` text
Idea
        ↓
Product Review (product-review-process.md)
        ↓
Product hypothesis / Investigation
        ↓
Work-plan row (ID, estimate, dependency, owner decision)
        ↓
Branch
        ↓
Local verification + independent review
        ↓
Fast-forward onto main
        ↓
ADR / brief evidence; row leaves the work plan
```

New features do not skip Product Review. See [`product-review-process.md`](product-review-process.md).

## Task rule

One work-plan row normally maps to one branch and one reviewable change.
Exceptions: an investigation with no code, or a tiny documentation correction.
When a task is delivered, remove its row from the work plan; the ADR index and
`git log` keep the record.

## Branch naming

Use `{TASK-ID}/{slug}`, matching [`../planning/work-plan.md`](../planning/work-plan.md),
for example `DOM-002/spec-derived-fixtures`. Name the task ID in the PR or commit body.

## Git flow

The kit's trunk-based policy applies (kit `rules/project-context.mdc`; the
merge method is the kit's, KIT-D-024): `main` is the single line, task
branches and worktrees are short-lived and use the naming above, and a
release is a tag on a verified commit of `main`
([`Tooling/docs/testflight.md`](../../Tooling/docs/testflight.md)).

`main` is always releasable in engineering terms. TestFlight release
cadence is independent.

## Commits and pull requests

Commit messages follow the kit commit policy; name the task ID in the
commit body. During a task, commits may follow the TDD story (test, then
the behaviour, then a refactor), one revertible change per commit.

A pull request is optional. When one is opened, use
[the repository PR template](../../.github/PULL_REQUEST_TEMPLATE.md) and mark
irrelevant sections as not applicable instead of inventing evidence. The
execution record is the task brief either way.

## WIP limit

Solo developer:

``` text
In progress: max 1 implementation task
```

An independent research/design investigation may run alongside implementation
without competing ownership of implementation files.

Do not open five coding branches.

## Investigation flow

``` text
Work-plan row: investigation
→ evidence links
→ comparison table/spike
→ decision
→ ADR if architecture changes
→ implementation rows in the work plan
```

An investigation is not closed with "looks good."

## Agent development

The process — framing, plan approval, writers, independent review, repair
limits, integration and round close — is the kit's: `docs/ai-os/task-lifecycle.md`, "Round in the Agentic SDLC flow",
in `${DEV_ROOT:-$HOME/Developer/Personal}/agent-tools/agent-engineering-kit`.
Review findings use the kit's scale (KIT-D-021) and its repair stop rules
(KIT-D-022); this repository does not restate them.

Project facts the process runs on:

- Brief: one per task in [`../tasks/`](../tasks/), with the kit brief schema;
  it is the execution record (owner decisions, checks run, review rounds,
  limitations). `PROJECT_STATUS.md` says whether product work is allowed.
- Gate: `just verify` (the installed Runtime); diagnose setup with
  `just doctor --json`; simulator and gate settings in `Tooling/runtime.yml`;
  `Tooling/.runtime-lock` identifies the installed Runtime content.
- CI: a push to `main` runs the shared tests workflow on GitHub-hosted
  runners (ADR 0013, 0014); it builds nothing, so local `just verify` is
  the gate.
- Documentation/config-only changes use proportional checks without an app
  build.
- Release preflight: `just release --check` after the verified contents are
  committed and the tree is clean; TestFlight per
  [`Tooling/docs/testflight.md`](../../Tooling/docs/testflight.md).
- Lessons: record a failure that changed a check in
  [`../lessons.md`](../lessons.md).

Demonstrated repository context, tool use, bounded recovery and independent
review can support a claim about an agent-assisted engineering workflow.
Shipped model interpretation, model evaluations and production AI outcomes
require separate evidence from M4+ work.

## Weekly product review

Once per week:

``` text
Review beta/product evidence
Review work-plan progress
Review blocked investigations
Review quality ledger
Review docs/lessons.md
Reorder only P0/P1 work
```

This is a 30-minute product review, not sprint ceremony.

## Metrics

Track monthly:

``` text
tasks completed
median task cycle time
local verification success on first run
reopened bugs
escaped regressions
WIP violations
investigation → adopted/deferred/rejected count
```

Do not optimize developer productivity by lines of code, commits or
story points.
