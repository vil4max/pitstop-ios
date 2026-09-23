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

The planner may use explicit grouping tolerances for the Kestrel fixture
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
-   Current seeded demo data can be adapted without immediate
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

### REQ-MAINT-023 — Stopping tracking removes only the owner's policy
Status: proposed
Core: P1, C5
Source: [Simple owner cadence first](#simple-owner-cadence-first), [ADR 0031](../decisions/0031-stop-tracking-an-operation.md), [ADR 0035](../decisions/0035-dashboard-service-reading.md)
Given an operation the owner tracks with their own interval, with confirmed completions and History events
When the owner stops tracking it
Then only the owner's policy is removed and completions, History events, any recommendation and any dashboard reading stay; with no other policy and no dashboard reading left, the operation leaves Service and Road and is offered again under Track, where tracking it again resumes from the kept completions; with another policy left, that policy applies instead and the operation stays on Service; with a dashboard reading left, the operation stays on Service and Road under that reading until the owner deletes the reading (rewording approved in substance by the owner, 2026-09-22, ADR 0035)

### REQ-MAINT-024 — Stopping tracking needs a confirmation that names the operation
Status: proposed
Core: P1
Source: [ADR 0010](../decisions/0010-maintenance-engine-rules.md) (undo confirmation pattern), [ADR 0031](../decisions/0031-stop-tracking-an-operation.md)
Given a tracked operation on Service
When the owner chooses to stop tracking it
Then nothing is removed until the owner confirms a dialog that names the operation, says that history stays and, when another policy remains, says that it applies instead; cancelling changes nothing

### REQ-MAINT-025 — "Track several" starts from the untracked operations with nothing chosen
Status: proposed
Core: C2, P1
Source: [Simple owner cadence first](#simple-owner-cadence-first), [ADR 0033](../decisions/0033-track-several-starter.md)
Given the owner opens "Track several" on Service
When the starter appears
Then it offers every catalog operation that is not tracked yet, selects none of them, fills no interval, and leaves both car-type questions unanswered; the owner selects and deselects operations freely

### REQ-MAINT-026 — Each chosen operation needs the owner's own valid interval
Status: proposed
Core: C2
Source: [Simple owner cadence first](#simple-owner-cadence-first), [ADR 0033](../decisions/0033-track-several-starter.md)
Given operations selected in "Track several"
When the owner moves on to the confirmation
Then every operation must have a distance and/or time interval that passes the same validation as the single Track sheet, each failing operation is marked by name, and quick picks offered as common choices are never preselected, only fill a field when tapped, stay editable, and are never called a recommendation

### REQ-MAINT-027 — Nothing is saved before one confirmation that lists everything
Status: proposed
Core: P1, C2
Source: [ADR 0006](../decisions/0006-capture-confirmation-policy.md), [ADR 0033](../decisions/0033-track-several-starter.md)
Given valid intervals for the chosen operations
When the owner has not confirmed the summary that lists every operation with its interval
Then nothing is written; cancelling at any step writes nothing; after confirmation each item is saved as the owner's own policy (`userCustom`) and Service, Road and Car Board show it on reload

### REQ-MAINT-028 — Items are saved one at a time and a failure is reported per item
Status: proposed
Core: P1
Source: [ADR 0033](../decisions/0033-track-several-starter.md)
Given a confirmed "Track several" summary
When saving one item fails
Then the other items are still saved, the result names each item as saved or not saved, and retrying saves only the items that failed

### REQ-MAINT-029 — Car-type answers only reorder the starter list
Status: proposed
Core: C2
Source: [ADR 0033](../decisions/0033-track-several-starter.md)
Given the optional gearbox and drive questions in "Track several"
When the owner answers them
Then only the order of the offered operations changes; no operation is selected or hidden, and no answer is stored as a vehicle fact or written anywhere

### REQ-MAINT-030 — A dashboard reading is its own observation, never a policy or a completion
Status: proposed
Core: C2, C5
Source: [Rule families](#rule-families), [ADR 0035](../decisions/0035-dashboard-service-reading.md)
Given the owner enters what the car's display says is left for one operation
When the reading is saved
Then it is stored as a dashboard reading with its operation, date, odometer, remaining distance with unit and/or remaining days; at least one remaining value is required, the odometer is required with a distance, values outside −50,000…100,000 km or −365…1,095 days are rejected; no policy and no completion is written, and the operation gets anchors and a status without a completion

### REQ-MAINT-031 — Only the newest reading counts, until newer confirmed work supersedes it
Status: proposed
Core: C5
Source: [ADR 0035](../decisions/0035-dashboard-service-reading.md)
Given several dashboard readings of one operation, or a reading and a completion of it
When the engine calculates the operation
Then only the newest reading is used, and not at all once a confirmed completion of that operation supersedes it: on a later calendar day by that day, on the same day when the completion was saved after the reading; a new reading replaces the stored one for every reader, and a replayed confirmation of an older reading is rejected as already saved, never overwriting a newer one

### REQ-MAINT-032 — The earlier anchor wins per dimension
Status: proposed
Core: P3, C2
Source: [Rule families](#rule-families), [ADR 0035](../decisions/0035-dashboard-service-reading.md)
Given an owner interval with a known baseline and a valid dashboard reading for the same operation
When the engine calculates the operation
Then each dimension uses the earlier of the two anchors, an exact tie going to the owner's interval, and the state says whether the deciding anchor came from the reading

### REQ-MAINT-033 — The share is measured against the owner's interval, otherwise the reported value
Status: proposed
Core: P3
Source: [ADR 0035](../decisions/0035-dashboard-service-reading.md)
Given a reading that decides a dimension
When the remaining share is calculated
Then the denominator is the owner's interval for that dimension when one exists, otherwise the value the car reported at the time; 480 km left of a reported 3,200 km is approaching

### REQ-MAINT-034 — Stale mileage blocks only the distance part of a reading
Status: proposed
Core: C2
Source: [ADR 0035](../decisions/0035-dashboard-service-reading.md), [ADR 0010](../decisions/0010-maintenance-engine-rules.md)
Given a dashboard reading with a distance and days
When no mileage observation is newer than 90 days
Then the distance part is blocked with the existing mileage reason and the days part still decides; a reading with an odometer is itself a mileage observation; an owner distance rule that has no completion to count from is reported as not counted, so a status decided by the reading's days alone is partial

### REQ-MAINT-035 — A reading shows its age, is called old after 180 days, and never expires
Status: proposed
Core: C2
Source: [ADR 0035](../decisions/0035-dashboard-service-reading.md)
Given a dashboard reading
When Service shows it
Then the line names the reading's date, says the reading is old once it is more than 180 days old, and the reading keeps counting until the owner replaces it, marks the work done or deletes it

### REQ-MAINT-036 — A reading keeps its operation visible until the reading is deleted
Status: proposed
Core: P1, C2
Source: [ADR 0035](../decisions/0035-dashboard-service-reading.md), [ADR 0031](../decisions/0031-stop-tracking-an-operation.md)
Given an operation with a stored dashboard reading and no policy, or whose tracking the owner stopped
When Service and Road are shown
Then the operation stays on them until the owner deletes the reading; deleting waits for a confirmation that names the operation, says that its readings go with the mileage they were entered at, and that completions, History and the interval stay; cancelling changes nothing

### REQ-MAINT-037 — The unit is kept as entered
Status: proposed
Core: C2
Source: [ADR 0035](../decisions/0035-dashboard-service-reading.md)
Given a remaining distance entered in miles or kilometres
When it is stored and shown
Then the value and its unit are stored and shown as entered, the unit is chosen explicitly (defaulting to the newest reading's unit), and miles convert to kilometres only for anchor arithmetic

### REQ-MAINT-038 — An overdue reading is accepted and reads as due
Status: proposed
Core: C2
Source: [ADR 0035](../decisions/0035-dashboard-service-reading.md), [REQ-ROAD-012](road-domain-and-ui.md)
Given a car that shows a negative remaining distance or number of days
When the owner enters it
Then it is accepted within bounds, said in words as overdue, and the operation's status is due; Road shows it as attention, not danger

### REQ-MAINT-039 — A reading from capture always needs confirmation and asks one question at a time
Status: proposed
Core: C3, C4, P1
Source: [ADR 0006](../decisions/0006-capture-confirmation-policy.md), [ADR 0035](../decisions/0035-dashboard-service-reading.md)
Given a capture such as "dashboard says service in 3200 km and 45 days"
When it passes through the Remember pipeline
Then it becomes a dashboard reading proposal only when the display is named and a countdown marker ("in", "через", "до ТО", "overdue by", "просрочено на") precedes the value or "left" / "overdue" follows its unit, never from a number after "пробег", "odometer" or a bare "на" or followed by "пробега", an "overdue" capture without a readable countdown keeps only its words and never becomes a mileage, and never instead of a completion the same words report; the proposal is never auto-accepted; the operation is asked first and never guessed, the odometer is asked when a distance is given, a proposal with no remaining value is incomplete; nothing is written before confirmation, cancelling writes nothing, and "I don't know" keeps only the words

### REQ-MAINT-040 — Mark as done after Pit recorded the same work never records it twice and never drops the owner's entry
Status: proposed
Core: C2, C5
Source: [Pit availability](pit-behavior-and-motion.md#availability), [REQ-PIT-026](pit-behavior-and-motion.md), [ADR 0035](../decisions/0035-dashboard-service-reading.md)
Given the Mark as done sheet is open for an operation, and Pit records a completion of that operation while it is open
When the owner confirms the sheet
Then a completion Pit recorded for another date is kept and the owner's completion is recorded separately; for the same date with the odometer left empty or equal to Pit's, nothing more is recorded and the sheet closes as saved; otherwise the sheet stays open, says in place (and to VoiceOver) that Pit already saved this work for that date, and records the owner's entry only on "Save anyway", which rechecks the entry first; editing the date or the odometer removes the message; completions stored before the sheet opened, the same day included, do not count (REQ-MAINT-031)
