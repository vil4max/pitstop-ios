# Maintenance Engine Specification

## Objective

Build a deterministic engine that answers:

1.  What maintenance operations are known?
2.  What policy applies to each operation?
3.  What is the current progress/status of each operation?
4.  Which operations naturally converge into the next practical service
    visit?
5.  What was actually completed and which cycles must reset?

## Core separation

``` text
Maintenance Engine
"What is due and when?"
        ↓
Service Planner
"What should be combined into one visit?"
        ↓
Service Plan
"What does the owner intend to do?"
        ↓
Service Visit
"What was actually done?"
        ↓
Maintenance Completion
"Which cycles reset?"
```

## Rule families

The pure Swift spike must support:

``` text
distance
time
distance OR time, first threshold wins
engine hours OR time
condition/vehicle-reported remaining value
advanced workload experiment
```

Persistence representation is explicitly out of scope until the pure
domain model is accepted.

## Simple owner cadence first

Default mental model:

> I change engine oil every 5/7.5/8/10/15 thousand km.

The app must support a simple per-operation interval without exposing
advanced calculations.

Example:

``` text
last engine oil service: 12,300 km
user interval: 7,500 km
next anchor: 19,800 km
```

The interval is a planning horizon, not an oil-condition diagnosis.

## Independent mandatory anchors

Frequent and rare mandatory cycles are equal domain citizens.

Examples: - engine oil service; - DSG/transmission service; - transfer
case/AWD coupling/Haldex service; - brake fluid by time; - other
verified drivetrain-fluid procedures.

Each operation/procedure has its own cycle.

## Practical service composition

In real use, a driver usually combines nearby work into one visit.
Official maintenance schedules also commonly compose work by
mileage/time milestones.

Therefore the planner should default toward a practical combined visit.

Example:

``` text
Oil due at 60,000
Haldex due at 60,000
DSG due at 62,000
Cabin filter recommended
Air filter changed 4,000 km ago
```

Proposed scope:

``` text
NEXT SERVICE ~60,000 KM

Required / due
- Engine oil service
- Haldex service

Due nearby
- DSG service

Consider
- Cabin filter

Not needed now
- Air filter
```

## Composition classes

### Required with procedure

A verified procedure component.

Example only when supported by applicable source:

``` text
engine oil service
→ oil
→ oil filter
→ sealing element
```

Behavior: - preselected in procedure draft; - provenance available; -
actual completion still confirmed.

### Due

Operation has reached its effective policy threshold.

Behavior: - included by default in suggested scope.

### Due nearby

Operation is not due yet but enters the planner's grouping window around
the next visit.

Behavior: - included or strongly suggested by default; - original
operation anchor remains unchanged until work is actually completed.

### Recommended / optional

A consumable or operation that may be reasonable at this visit but is
not currently due under an authoritative/effective rule.

Behavior: - shown under `Consider`; - not treated as deferred if
omitted; - omission does not create overdue state.

### Relevant notes

Active service-context notes.

Behavior: - displayed separately from maintenance work; - never
automatically converted to completed operations.

## Grouping rules

P0 planner must be deterministic.

Conceptual inputs:

``` text
distance proximity
time proximity
operation grouping eligibility
procedure relationships
current service anchor
```

Do not ask the LLM whether DSG is "close enough."

The planner may use explicit grouping tolerances for the Arteon fixture
during the spike.

A future knowledge source may provide operation-specific grouping
semantics.

## Partial service

Example plan:

``` text
Oil
DSG
Haldex
Cabin filter
```

Actual document/user confirmation:

``` text
Oil ✓
DSG ✓
Haldex ✕
Cabin filter ✕
```

Result:

``` text
oil cycle resets
DSG cycle resets
Haldex remains due
cabin filter remains unchanged
```

A service visit is still a valid history event.

## Unknown baseline

If policy is known but last completion is unknown:

``` text
status = unknown
```

Never calculate from zero by default.

Possible progressive prompt:

> Do you remember roughly when DSG service was last performed?

Unknown data must not block onboarding.

## Early completion

If oil was planned at 19,800 but actually changed at 18,900:

``` text
new cycle baseline = 18,900
```

Next anchor derives from actual completion unless a future policy
explicitly uses a fixed-grid schedule.

Independent DSG/Haldex anchors do not shift.

## Procedure inference

If user says:

> Changed the oil.

The interpreter may produce:

``` text
Engine Oil Service draft

likely procedure components:
[x] engine oil
[x] oil filter
[x] sealing element
```

Only if an applicable verified procedure supports that composition.

Copy must indicate that these are draft assumptions.

The user can correct them.

## Success criteria for engine v1

-   Same input facts always produce same status.
-   AI is not required.
-   Independent operation cycles pass parameterized tests.
-   Unknown baseline never becomes due by arithmetic from zero.
-   Early completion resets only completed operations.
-   Partial service resets only confirmed operations.
-   Service Planner can compose a multi-operation scope.
-   Optional items do not become due merely because they were suggested.
-   Current seeded Arteon data can be adapted without immediate
    destructive migration.

## Failure criteria

-   localized title is used as primary operation identity;
-   `ServiceVisit.isCompleted` resets all child work;
-   oil remains a permanent special-case engine;
-   grouping changes an operation's anchor before completion;
-   planner depends on generative output;
-   a source recommendation is applied without applicability/provenance.
