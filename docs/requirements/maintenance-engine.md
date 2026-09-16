# Maintenance Engine Specification

Core: P1, P2, P3, C2, C5

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

Implements core constraint C5 ([`../core.md`](../core.md#constraints)).

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

## Requirements

Status `proposed` means derived from the contract text above and awaiting owner approval.

### REQ-MAINT-001 — Operation becomes due at its policy threshold
Status: proposed
Core: P3
Source: [Rule families](#rule-families), [Due](#due)
Given an operation with a distance or time policy and a known last completion
When current progress reaches the effective policy threshold
Then the operation status is due

### REQ-MAINT-002 — Distance-or-time policy uses the first threshold reached
Status: proposed
Core: P3
Source: [Rule families](#rule-families)
Given an operation with a distance OR time policy and a known last completion
When either the distance or the time threshold is reached first
Then the operation status is due without waiting for the other threshold

### REQ-MAINT-003 — Simple owner interval derives the next anchor
Status: proposed
Core: P3
Source: [Simple owner cadence first](#simple-owner-cadence-first)
Given a last completion distance and a user per-operation distance interval
When the engine calculates the operation
Then the next anchor equals the last completion distance plus the interval

### REQ-MAINT-004 — Each operation keeps an independent cycle
Status: proposed
Core: C5
Source: [Independent mandatory anchors](#independent-mandatory-anchors), [Early completion](#early-completion), [Success criteria for engine v1](#success-criteria-for-engine-v1), [Failure criteria](#failure-criteria)
Given several operations, frequent and rare, each with its own policy
When a completion is confirmed for one operation
Then only that operation's cycle resets and other anchors do not shift

### REQ-MAINT-005 — Due operations are composed into one suggested scope
Status: proposed
Core: P3
Source: [Practical service composition](#practical-service-composition), [Due](#due), [Success criteria for engine v1](#success-criteria-for-engine-v1)
Given several operations whose status is due
When the Service Planner builds the next service scope
Then all due operations are included by default in that one scope

### REQ-MAINT-006 — Due-nearby operations join the suggested scope
Status: proposed
Core: P3
Source: [Practical service composition](#practical-service-composition), [Due nearby](#due-nearby)
Given an operation that is not due but is inside the planner's grouping window
When the Service Planner builds the next service scope
Then the operation appears in the scope as due nearby

### REQ-MAINT-007 — Grouping does not change an operation anchor
Status: proposed
Core: C5
Source: [Due nearby](#due-nearby), [Failure criteria](#failure-criteria)
Given an operation grouped into a scope as due nearby
When the scope is built and no completion is confirmed
Then the operation's original anchor is unchanged

### REQ-MAINT-008 — Verified procedure components are preselected with provenance
Status: proposed
Core: C2, P3
Source: [Required with procedure](#required-with-procedure), [Procedure inference](#procedure-inference)
Given an operation with an applicable verified procedure
When a procedure draft is created for that operation
Then its required components are preselected and their provenance is available

### REQ-MAINT-009 — Draft components are not completed until confirmed
Status: proposed
Core: C5
Source: [Required with procedure](#required-with-procedure), [Procedure inference](#procedure-inference)
Given a procedure draft with preselected components
When actual completion has not been confirmed
Then no component or operation cycle is reset

### REQ-MAINT-010 — Optional items are shown under Consider
Status: proposed
Core: P3
Source: [Practical service composition](#practical-service-composition), [Recommended / optional](#recommended--optional)
Given an item that is recommended but not due under an effective rule
When the Service Planner builds the next service scope
Then the item appears under `Consider`, not under due work

### REQ-MAINT-011 — Omitted or suggested optional items do not become overdue
Status: proposed
Core: C5
Source: [Recommended / optional](#recommended--optional), [Success criteria for engine v1](#success-criteria-for-engine-v1)
Given an optional item suggested in a scope
When the visit is recorded without that item
Then the item is not deferred, not due, and not overdue because of the suggestion

### REQ-MAINT-012 — Relevant notes never become completed operations
Status: proposed
Core: C5
Source: [Relevant notes](#relevant-notes)
Given an active service-context note
When a scope is built or a visit is recorded
Then the note is not converted into a completed operation

### REQ-MAINT-013 — Planner is deterministic and independent of generative output
Status: proposed
Core: P3
Source: [Grouping rules](#grouping-rules), [Failure criteria](#failure-criteria)
Given the same distance, time, eligibility, procedure, and anchor inputs
When the Service Planner builds a scope with no generative model available
Then it produces the same scope every time

### REQ-MAINT-014 — Partial service resets only confirmed operations
Status: proposed
Core: C5
Source: [Partial service](#partial-service), [Success criteria for engine v1](#success-criteria-for-engine-v1), [Failure criteria](#failure-criteria)
Given a plan with several operations
When the visit confirms some operations and marks others not done
Then confirmed cycles reset and unconfirmed operations keep their prior status

### REQ-MAINT-015 — Partial service visit is a valid history event
Status: proposed
Core: C5
Source: [Partial service](#partial-service)
Given a visit where only some planned operations were confirmed
When the visit is recorded
Then it is stored as a history event containing only the confirmed work

### REQ-MAINT-016 — Unknown baseline yields unknown status
Status: proposed
Core: C2
Source: [Unknown baseline](#unknown-baseline), [Success criteria for engine v1](#success-criteria-for-engine-v1)
Given an operation with a known policy and an unknown last completion
When the engine calculates status
Then status is unknown and never due by arithmetic from zero

### REQ-MAINT-017 — Unknown baseline does not block onboarding
Status: proposed
Core: P2, C2
Source: [Unknown baseline](#unknown-baseline)
Given operations whose last completion is unknown
When the user goes through onboarding
Then onboarding completes without requiring those baselines

### REQ-MAINT-018 — Early completion rebaselines from the actual completion
Status: proposed
Core: C5
Source: [Early completion](#early-completion), [Success criteria for engine v1](#success-criteria-for-engine-v1)
Given an operation planned at an anchor and a completion-based policy
When completion is confirmed earlier than the anchor
Then the new cycle baseline is the actual completion and the next anchor derives from it

### REQ-MAINT-019 — No component inference without an applicable verified procedure
Status: proposed
Core: C2, P3
Source: [Procedure inference](#procedure-inference), [Failure criteria](#failure-criteria)
Given an operation with no applicable verified procedure or provenance
When the interpreter produces an operation draft
Then no procedure components are preselected or applied

### REQ-MAINT-020 — Inferred components are labeled as draft assumptions
Status: proposed
Core: P3
Source: [Procedure inference](#procedure-inference)
Given a draft with components inferred from a verified procedure
When the draft is shown to the user
Then the copy indicates the components are draft assumptions

### REQ-MAINT-021 — User can correct inferred draft components
Status: proposed
Core: P1
Source: [Procedure inference](#procedure-inference)
Given a draft with inferred procedure components
When the user changes the component selection
Then the draft reflects the user's correction

### REQ-MAINT-022 — Same facts produce the same status without AI
Status: proposed
Core: P3
Source: [Success criteria for engine v1](#success-criteria-for-engine-v1)
Given the same policies and confirmed completion facts
When the engine calculates status repeatedly with no AI available
Then the status is identical each time
