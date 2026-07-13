# Project Management and Git Flow

## Decision

Use GitHub Issues + GitHub Projects + Pull Requests.

Do not add Trello in P0.

Reason: GitHub Projects already supports table, board and roadmap views
and integrates issues and pull requests. GitHub sub-issues provide
parent/child progress. A second project system would duplicate state.

## Work hierarchy

``` text
Idea
        ↓
Product Review (42_PRODUCT_REVIEW.md)
        ↓
Product hypothesis / Investigation
        ↓
Epic issue
        ↓
Atomic sub-issues
        ↓
Branch
        ↓
Pull Request
        ↓
Tests + CI + evidence
        ↓
Merge
        ↓
Project status/metrics
```

New features do not skip Product Review. See [`42_PRODUCT_REVIEW.md`](42_PRODUCT_REVIEW.md).

## Issue types by label

GitHub labels:

``` text
type:feature
type:bug
type:investigation
type:architecture
type:quality
type:design
type:experiment
type:docs

area:maintenance
area:notes
area:history
area:odometer
area:ai
area:analytics
area:design-system
area:platform

priority:P0
priority:P1
priority:P2

status:blocked
status:needs-evidence
```

Do not encode status in both label and Project field unless automation
requires it.

## GitHub Project fields

Minimum:

``` text
Status
Priority
Area
Type
Phase
Target
```

Status:

``` text
Backlog
Ready
In progress
In review
Blocked
Done
```

Views:

### Board --- Current work

Group by Status. Filter current target.

### Table --- Backlog

Sort Priority then Phase.

### Roadmap

Epics/investigations only. Do not put every atomic task on a Gantt-like
timeline.

### Quality / Debt

Filter `type:quality` and bugs.

## Epic rule

An epic describes an outcome/hypothesis.

Example:

``` text
EPIC: Deterministic maintenance status
```

Sub-issues:

``` text
MNT-001 Stable MaintenanceOperationID
MNT-010 Distance policy
MNT-011 Unknown baseline
MNT-012 Time policy
MNT-013 Distance OR time
MNT-030 Snapshot projection
```

GitHub parent/sub-issue progress becomes the epic progress indicator.

## Atomic issue rule

One issue should normally map to one branch and one PR.

Exception: - investigation with no code; - tiny documentation
correction.

Issue must use `16_TASK_TEMPLATE.md` concepts.

## Branch naming

``` text
feat/123-maintenance-distance-policy
fix/245-partial-service-reset
investigate/88-posthog-spike
quality/102-ci-domain-tests
design/130-status-hero
docs/77-competitive-research
```

Issue number is mandatory.

## Git flow

Use trunk-based GitHub Flow, not Git Flow with `develop`, `release/*`
and long-lived feature branches.

``` text
main
  ↑
short-lived branch
  ↑
PR
  ↑
required checks
  ↑
squash merge
```

`main` is always releasable in engineering terms.

TestFlight release cadence is independent.

## Commit rule

During branch development, commits may follow the TDD story:

``` text
test: cover unknown maintenance baseline
feat: return unknown without completion
refactor: extract progress calculation
```

PR is squash-merged with:

``` text
MNT-011 Return unknown for missing maintenance baseline (#123)
```

Do not force Conventional Commits everywhere unless release automation
needs them.

## Pull request template

``` text
## Problem
## Behavior changed
## Intentionally unchanged
## Tests first / evidence
## Screenshots
## Logging
## Analytics
## Performance / Instruments
## Privacy
## Risks
## Issue
Closes #...
```

For UI PRs screenshots are required.

For performance-sensitive PRs attach metric evidence.

## WIP limit

Solo developer:

``` text
In progress: max 2 atomic issues
```

One product/domain task and one small parallel research/design task are
acceptable.

Do not open five coding branches.

## Investigation flow

``` text
Issue: type:investigation
→ evidence links
→ comparison table/spike
→ decision
→ ADR if architecture changes
→ implementation issues
```

An investigation is not closed with "looks good."

## Agent rule

Coding agent receives: - issue URL/text; - relevant ADR/docs; - explicit
task scope.

Agent must return: - tests written first; - files changed; - commands
run; - results; - risks; - deviations from issue.

Agent cannot silently expand the issue.

## Weekly product review

Once per week:

``` text
Review beta/product evidence
Review current epic progress
Review blocked investigations
Review quality ledger
Review diary entries
Select LinkedIn story candidate
Reorder only P0/P1 work
```

This is a 30-minute product review, not sprint ceremony.

## Metrics

Track monthly:

``` text
issues completed
median issue cycle time
PR CI success on first run
reopened bugs
escaped regressions
WIP violations
investigation → adopted/deferred/rejected count
```

Do not optimize developer productivity by lines of code, commits or
story points.

## Decision

No Trello.

Revisit only if non-technical collaborators need a simpler planning
surface.
