# Test Strategy

## Principle

Domain behavior is test-first.

The highest-value tests protect: - maintenance truth; - partial
completion; - data interpretation boundaries; - migration/adapters; - AI
draft contracts.

## Layers

### Pure domain tests

Fast, deterministic, no SwiftData, no Firebase, no Foundation Models
session.

Covers: - policies; - progress; - statuses; - planner; - procedure
composition; - Money; - validation.

Target: majority of business behavior.

### Adapter tests

Covers: - current seeded visits/tasks → operation completions; - title
compatibility mapping; - persistence projection.

Use controlled in-memory persistence where required.

### AI evaluations

Covers: - intent; - typed fields; - numeric extraction; - ambiguity
behavior; - tool trajectory later.

Not a substitute for domain tests.

### Integration tests

Covers: - domain command → persistence → snapshot rebuild; - history
event → completion → cycle reset.

### UI tests

Only critical flows: - one-glance status accessibility; - car-wash notes
one-action path; - Remember draft save; - partial service
confirmation.

Do not UI-test every SwiftUI layout.

## Required maintenance matrix

  Case                                          Expected
  --------------------------------------------- ---------------------------------
  Known distance baseline, below approach       upToDate
  Enters approach window                        approaching
  Reaches anchor                                due
  Missing baseline                              unknown
  Early oil completion                          oil baseline resets from actual
  Early oil completion                          DSG baseline unchanged
  Partial visit: oil+DSG done, Haldex skipped   Haldex remains due
  Optional cabin filter omitted                 no deferred/due mutation
  Due-nearby DSG grouped                        original DSG anchor unchanged
  Same facts repeated                           identical snapshot

## Parameterized tests

Use parameterized tests for interval/status boundaries and mapping
catalogs.

Boundary values are mandatory:

``` text
threshold - 1
threshold
threshold + 1
```

## Property/invariant thinking

Even without a property-testing framework, encode invariants:

-   Completing operation A cannot reset operation B.
-   Grouping cannot mutate a maintenance baseline.
-   Unknown baseline cannot produce numeric progress.
-   AI draft cannot directly create a completion.
-   Optional recommendation omission cannot create overdue state.
-   Snapshot generation is deterministic for equal input.

## AI golden set

Version in repository without real private beta content.

Use synthetic/redacted phrases derived from observed patterns.

Each new production-supported intent requires: - positive cases; -
ambiguous cases; - unsupported cases; - malformed numeric cases.

## Regression rule

Every production bug gets: 1. failing regression test/evaluation; 2.
minimal fix; 3. log/analytics review: could telemetry have detected the
class earlier?

## Test tags

Suggested tags:

``` text
.domain
.adapter
.persistence
.aiEvaluation
.integration
.uiCritical
.migration
```

## CI gate

Minimum: - build; - domain tests; - adapter tests; - integration tests
that do not require unavailable device AI.

AI/device-dependent evaluations may run in a separate explicit lane.

No merge with disabled failing tests unless an issue and expiry
condition are documented.
