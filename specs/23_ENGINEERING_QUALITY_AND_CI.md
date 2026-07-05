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

#### Tell PitStop / Foundation Models

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

Full CI remains authoritative. Hooks are convenience, not security.

## CI pipeline

Use GitHub Actions.

### PR required checks

``` text
quality
build
domain-tests
integration-tests
```

`quality`: - formatting check; - SwiftLint; - forbidden architecture
imports; - warning policy.

`build`: - clean build selected scheme/configuration.

`domain-tests`: - pure Swift/domain package tests.

`integration-tests`: - persistence/adapters and critical integration
suite.

### Scheduled checks

Weekly:

``` text
Periphery report
dependency update/status report
large-fixture performance lane
```

### Release/TestFlight workflow

On version tag or manual dispatch:

``` text
required checks green
→ archive
→ export/upload TestFlight
→ release metadata artifact
→ quality ledger reminder/check
```

Start with manual approval before TestFlight upload.

## CI metrics

Track:

``` text
CI duration
build duration
domain test duration
integration test duration
test count
flaky test count
warnings
lint violations
scheduled dead-code findings
performance baseline regressions
```

The purpose is to learn CI/CD operations, not build a dashboard before
there is data.

Store machine-readable reports as workflow artifacts where practical.

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

Protect `main` with a ruleset/branch protection: - pull request
required; - required status checks; - branch must be up to date if CI
semantics require it; - no force push; - no direct normal development
push; - linear history preferred.

For a solo project, required human approval is optional and may create
ceremony without quality. CI is mandatory.

## Quality Definition of Done addition

Every phase/epic closes only when: - correctness tests pass; - CI is
green; - quality ledger row is added; - required Instruments profile is
recorded; - material regression has an issue or is fixed; -
analytics/privacy smoke check passes for changed telemetry.
