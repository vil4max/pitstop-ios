# Engineering Quality, Instruments, CI/CD and Metrics

## Principle

Quality is measured at defined gates.

Do not "run Instruments before release" as an untracked ritual.

Every phase records a small quality snapshot and adds automated
regression protection where the metric is stable enough.

## Quality dimensions

``` text
correctness
build health
test health
static quality
performance
memory
responsiveness
launch
energy
binary/dependency cost
crash stability
product telemetry health
```

## Quality ledger

Store:

``` text
docs/quality/QUALITY_LEDGER.md
docs/quality/baselines/
```

One row per milestone:

  --------------------------------------------------------------------------------------------------------------
  Milestone   Build     Tests   Warnings   Lint   Dead   Launch   Snapshot     Peak   Hangs   Crash-free Notes
                                                  code                 p50   memory                      
  ----------- ------- ------- ---------- ------ ------ -------- ---------- -------- ------- ------------ -------

  --------------------------------------------------------------------------------------------------------------

Do not invent thresholds before the first baseline.

Workflow:

``` text
measure baseline
→ identify material risk
→ set regression budget
→ automate stable metric
```

## Instruments quality gate

### At the end of each product phase

Run a focused profile on a Release configuration/device where practical.

Required templates/checks by phase:

#### Domain engine / planner

-   Time Profiler for repeated snapshot rebuild.
-   Signpost interval for snapshot/planner if duration is
    product-relevant.
-   Allocations if repeated calculation grows memory.

Record: - fixture size; - iteration count; - median/representative
duration; - unexpected hot symbols.

#### SwiftData/history

-   Time Profiler.
-   Allocations.
-   Leaks.
-   repeated open/filter/archive flow.
-   large fixture dataset.

Record: - fetch/projection duration; - peak memory; - retained growth
after repeated flow.

#### Remember / Foundation Models

-   signposted interpretation latency;
-   main-thread responsiveness;
-   memory;
-   energy/power investigation after voice is added.

Record: - availability; - model/interpreter version; - p50/p95 local
evaluation latency where sample size permits; - UI hang observation.

#### Home/status/widget

-   app launch;
-   SwiftUI responsiveness/hitches;
-   widget timeline/render path;
-   main-thread work.

#### Voice/CarPlay later

-   energy;
-   CPU;
-   background behavior;
-   responsiveness.

Apple's Instruments and Xcode performance tooling are the primary source
for these measurements.

## Automated performance tests

Use XCTest performance tests for deterministic hot paths where baselines
are meaningful.

Candidate:

``` text
MaintenanceSnapshot build for 10/100/1000 operations
ServicePlanner composition for large fixture
History projection for large fixture
```

Use `XCTOSSignpostMetric` for signposted regions when appropriate.

Do not put unstable device-LLM latency into a blocking PR check
initially.

## Static quality toolchain

### Required P0

-   compiler warnings: zero new warnings;
-   SwiftLint;
-   swift-format or one selected formatter, not two competing
    formatters;
-   test suite;
-   build.

### Scheduled/non-blocking initially

-   Periphery unused-code scan.

Periphery can produce false positives around newer Swift/Xcode features;
introduce it as report-only, triage, then decide whether specific
findings can block.

## Local hooks

Use the `pre-commit` framework or repository script installation; hooks
must be versioned/configurable from the repo.

Pre-commit should be fast:

``` text
format check / format changed Swift files
SwiftLint changed files
forbidden pattern scan
```

Forbidden pattern examples:

``` text
print(
analytics provider SDK import outside adapter boundary
raw analytics string call
TODO without issue reference — optional policy
```

Do not run full simulator tests in pre-commit.

Pre-push:

``` text
build
fast domain tests
```

The local Runtime gate is authoritative for implementation verification.
Hooks provide early feedback; they are not security boundaries. Avoid rerunning
a completed gate on unchanged contents solely for another workflow stage.

## Local verification

The local Runtime gate is the implementation gate. GitHub Actions runs the
shared Runtime pipeline on a self-hosted runner on the owner's Mac (no hosted
macOS minutes) once the owner has completed the setup in ADR 0013; a push to
`main` then only runs tests
([ADR 0013](../decisions/0013-shared-ci-and-tag-gated-testflight.md)). A green
hosted run is additional evidence, not a substitute. Use `just verify` for app implementation and record the command, result, and
reviewed revision in the PR. Use proportional diff/link/config checks for
non-behavioral documentation changes, without an app build.

The current suite covers the existing app baseline; domain, persistence, and UI
coverage grow with their implementations. Preserve relevant failure evidence
locally and durable conclusions in `docs/lessons.md`. A passing gate does not
imply independent review or product acceptance.

Do not schedule Periphery, dependency reports, or performance lanes without a
specific investigation or measured regression risk. Run them on demand when
relevant. TestFlight delivery is tag-gated through the shared Runtime pipeline
(`Tooling/docs/testflight.md`), the same model as the other apps on the Runtime.

## Verification metrics

Record build/test duration, failures, warnings, and material performance
regressions when they help a current decision. Do not create a recurring report
or blocking threshold before there is a measured baseline and a reason to act.

## Regression budgets

After first three stable measurements, define budgets.

Example format, not initial values:

``` text
MaintenanceSnapshot 100 ops:
baseline p50 = X ms
blocking regression budget = +Y%

App launch:
baseline = X
investigate at +Y%
```

A budget must state: - hardware/simulator; - OS; - configuration; -
fixture; - sample method.

## GitHub quality enforcement

The ruleset JSON is a proposal, not evidence of active GitHub protection.
It may protect history and require a PR where the account supports rulesets,
but must not require a hosted check until the self-hosted runner is registered
and reliable. A solo project
does not need an extra approval ritual without a concrete review benefit.

## Quality Definition of Done addition

Close a phase/epic after relevant correctness tests and review pass. Record a
quality baseline or focused profile when that phase affects the measured path;
file or fix material regressions. Run analytics/privacy smoke checks when
telemetry changes. Documentation-only changes do not require these app gates.
