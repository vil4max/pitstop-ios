# Engineering Standard

## Development mode

PitStop uses **test-first development** for domain behavior.

The required loop:

``` text
RED
write a failing behavior test

GREEN
implement the smallest correct behavior

REFACTOR
improve design with all tests green

OBSERVE
verify logs/analytics contracts

DOCUMENT
update decision/task documentation
```

No "write implementation and ask an agent to generate tests afterward"
for domain logic.

## Atomic task rule

A task is atomic when: - it has one primary behavior change; -
acceptance criteria can be verified independently; - failure can be
diagnosed without inspecting an entire epic; - it can be reverted
without reverting unrelated behavior.

Bad task:

> Refactor maintenance and add AI.

Good tasks:

> Introduce stable `MaintenanceOperationID` in pure Swift.

> Calculate distance progress for one operation from a known completion.

> Return `.unknown` when the completion baseline is missing.

> Compose due operations into a `SuggestedServiceScope`.

## Mandatory task sections

Every implementation task uses `16_TASK_TEMPLATE.md`.

Required: - Problem. - Scope. - Non-goals. - Preconditions. - Behavior
examples. - Acceptance criteria. - Failure criteria. - Tests first. -
Logging. - Analytics. - Documentation. - Rollback/risk notes.

## Definition of Ready

A task may start only when: - domain term is defined; - source of truth
is known; - inputs/outputs are known; - non-goals are written; -
acceptance and failure criteria exist; - test cases are listed; -
analytics decision is explicit: event / no event; - logging decision is
explicit.

## Definition of Done

A task is done only when: - acceptance criteria pass; - required tests
were written first or the task explicitly documents why test-first is
impossible; - tests pass locally; - no unrelated test is disabled; -
structured logging is added where the behavior crosses an important
boundary; - analytics event is added only if required by the telemetry
contract; - no private raw text is accidentally logged; - docs/ADR are
updated if the domain contract changed; - dead compatibility code
introduced by the task is removed or tracked; - build warnings
introduced by the task = 0.

## Testing technology

Use Swift Testing for new pure domain tests where practical.

Use XCTest where required by: - existing suite integration; - UI
testing; - APIs/tooling better served by XCTest.

Do not rewrite all existing XCTest solely to adopt Swift Testing.

## Test naming

Behavior-oriented names:

``` text
status is unknown when completion baseline is missing
early oil completion resets only oil cycle
partial service leaves unperformed Haldex due
planner groups DSG when it enters the configured service window
```

Avoid implementation names such as:

``` text
testCalculate2
testManagerMethod
```

## Test fixtures

Fixtures are explicit domain examples, not production recommendations
unless sourced.

Required abstraction fixtures: - Arteon custom oil cadence; - DSG
independent distance cycle; - AWD/Haldex independent cycle; -
brake-fluid time cycle; - BMW-like vehicle-reported condition fixture; -
unknown baseline; - partial service; - early completion.

Each fixture must state:

``` text
TEST FIXTURE — NOT OFFICIAL MAINTENANCE GUIDANCE
```

unless backed by a documented source.

## Agent workflow

Coding agents may: - inspect; - propose; - write the failing test; -
implement the smallest behavior; - run tests; - report diff and risk.

Agents must not: - redesign persistence without an accepted ADR; -
convert product hypotheses into requirements; - invent maintenance
values; - disable failing tests; - add broad abstractions "for future
flexibility" without a current test case.

## Commit/PR unit

Prefer one domain behavior or one infrastructure capability per
PR/commit sequence.

Each review summary should answer:

``` text
What behavior changed?
Which test proves it?
Which source of truth changed?
What is intentionally unchanged?
Which log/event lets us observe it?
```
