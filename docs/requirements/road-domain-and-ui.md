# Road Domain and UI Contract

**Status:** P0 product hypothesis requiring investigation

Core: P3, P5, C2

## Purpose

Road is a compact visual timeline of meaningful car milestones.

The car stands toward the left. Relevant future milestones appear ahead. Past events are lower priority and may be compressed.

Road is not a literal map, odometer chart, or decorative illustration.

## User value

> Show me what is meaningfully ahead for this car without making me inspect lists.

## Milestone eligibility

Candidate milestone types:
- maintenance anchor approaching/due;
- required service;
- insurance expiry when known and relevant;
- explicit meaningful planned vehicle event.

Not a Road milestone by default:
- car wash;
- ordinary note;
- generic app reminder;
- every history event;
- low-confidence AI suggestion.

Milestone eligibility must be deterministic.

## Road projection

Conceptual input:

```text
RoadContext
- currentDate
- latestValidOdometer?
- maintenanceStates
- explicitFutureEvents
- insuranceState?
```

Conceptual output:

```text
RoadProjection
- currentPosition
- futureMilestones
- compressedPastSummary?
- horizon
- semanticSummary
```

Road projection is pure/testable domain logic. UI does not independently decide milestone eligibility.

## Mixed time and mileage

Milestones may be date-based, mileage-based, or both.

Do not fake conversion between time and mileage without an explicit supported projection model.

A date estimate on a distance milestone is the explicit supported projection
model of ROAD-EST-002 ([ADR 0034](../decisions/0034-mileage-rate-estimate.md)):
a labelled range derived from the car's own reading history, shown apart from
the fact, never stored, and never used to place, order, or cluster anything.

If mileage is stale or unknown:
- preserve date-based milestones;
- mark mileage-dependent confidence/state appropriately;
- do not invent current mileage.

The initial implementation may use deterministic lane/spacing rules rather than a mathematically literal scale.

## Initial viewport

The initial viewport must always communicate useful Road state.

The car must not face an apparently empty road merely because the nearest milestone is beyond a literal scale.

The projection may:
- choose a bounded relevant horizon;
- compress empty distance;
- surface the nearest eligible milestone;
- show a calm explicit no-known-milestones state.

Do not create fake milestones to fill space.

## Horizon

Working hypothesis: approximately six months or an equivalent meaningful mileage horizon.

This is not yet a fixed product constant. Validate through `INV-ROAD-001`.

Forward scrolling may expose later milestones.

## Past

Past is lower priority.

If many past events exist:
- compress them;
- expose a “look back” affordance or compact history marker;
- do not allocate equal spatial weight to the entire past.

History remains the authoritative event browsing surface.

## Return to current position

After Road scrolling, provide an obvious deterministic return to the default/current position.

INVESTIGATE exact interaction:
- automatic snap after leaving/re-entering;
- explicit current-position control;
- native scroll-position behaviour.

Do not invent a custom gesture.

## Overdue milestones

Overdue is not danger by default.

Road must distinguish:
- approaching;
- due;
- overdue;
- unknown/stale dependency.

Semantic colour follows the design system. Red remains reserved for genuine danger/error semantics.

## Overlap

Multiple milestones may converge.

The projection must define deterministic clustering or spacing.

Do not let labels overlap unpredictably.

Service clustering and Road visual clustering are related but not identical:
- Service Planner may group operations into a visit;
- Road may visually cluster nearby milestones.

## Planned dated events

Proposed with ROAD-EVT-001 ([ADR 0032](../decisions/0032-planned-dated-events.md)).

The owner can state a future date for the car: an insurance expiry, or another
date with an optional short name of their own. Only the date is kept; PitStop
never asks for an insurer, a policy number, or an amount, and never derives a
date from law, locale, registration year, or a mileage rate.

- The owner adds a date from the Road screen and corrects or deletes it from
  the Road list; deleting asks first and names the date.
- The date is a plan, not a History event, and resets nothing.
- One insurance expiry is on Road per car at a time.
- The date stays on Road as due for 14 days after it passes, then leaves Road
  and stays stored.

## Motion

The car may have subtle motion when state changes or Road recenters, subject to Reduce Motion.

The car does not need to continuously drive.

Road meaning must remain understandable with motion disabled.

## Analytics questions

- Is Road opened/scrolled?
- Do users open milestone details?
- Is the nearest milestone understood?
- How often is Road empty due to missing data?
- Does Road cause profile enrichment?
- Are clustered milestones opened as a group or individually?

## Test-first scenarios

1. no known milestones;
2. one date milestone;
3. one mileage milestone with current mileage;
4. mileage milestone with stale mileage;
5. mixed time/mileage milestones;
6. nearest milestone outside literal horizon;
7. multiple overlapping milestones;
8. overdue milestone;
9. large past history;
10. return to default position;
11. Reduce Motion;
12. semantic summary generation.

## Acceptance criteria

- Road communicates a useful future horizon;
- milestone eligibility is deterministic;
- no fake mileage projection;
- initial viewport is not accidentally empty;
- past can be compressed;
- return-to-current behaviour is defined before production implementation;
- non-visual semantic summary exists.

## Failure criteria

- Road is decoration;
- every reminder becomes a milestone;
- the UI invents mileage;
- labels overlap unpredictably;
- a car faces empty space while known relevant milestones exist;
- Road becomes a second History screen.

## Investigation IDs

- `INV-ROAD-001` horizon and spacing
- `INV-ROAD-002` mixed time/mileage representation
- `INV-ROAD-003` clustering
- `INV-ROAD-004` return to current position

## Requirements

Status `proposed` means derived from the contract text above and awaiting owner approval.

### REQ-ROAD-001 — Eligible milestone types appear on Road
Status: proposed
Core: P3
Source: [Milestone eligibility](#milestone-eligibility), [Test-first scenarios](#test-first-scenarios)
Given a RoadContext with an approaching or due maintenance anchor, a required service, or an explicit meaningful planned vehicle event
When the Road projection is computed
Then each of them appears in futureMilestones

### REQ-ROAD-002 — Non-milestone items stay off Road
Status: proposed
Core: P3
Source: [Milestone eligibility](#milestone-eligibility), [Failure criteria](#failure-criteria)
Given a car wash, an ordinary note, a generic app reminder, a history event, or a low-confidence AI suggestion
When the Road projection is computed
Then none of them becomes a Road milestone by default

### REQ-ROAD-003 — Projection is deterministic
Status: proposed
Core: P3
Source: [Milestone eligibility](#milestone-eligibility), [Road projection](#road-projection), [Overlap](#overlap), [Acceptance criteria](#acceptance-criteria)
Given the same RoadContext
When the Road projection is computed repeatedly
Then milestone eligibility, clustering, and spacing are identical each time

### REQ-ROAD-004 — UI does not decide eligibility
Status: proposed
Core: P3
Source: [Road projection](#road-projection)
Given a RoadProjection
When the Road UI renders
Then it shows exactly the milestones the projection returned and adds or removes none

### REQ-ROAD-005 — Date milestones survive stale or unknown mileage
Status: proposed
Core: C2
Source: [Mixed time and mileage](#mixed-time-and-mileage), [Test-first scenarios](#test-first-scenarios)
Given date-based milestones and a stale or unknown latestValidOdometer
When the Road projection is computed
Then the date-based milestones are preserved

### REQ-ROAD-006 — Mileage milestones flag stale or unknown dependency
Status: proposed
Core: C2
Source: [Mixed time and mileage](#mixed-time-and-mileage), [Overdue milestones](#overdue-milestones)
Given a mileage-dependent milestone and a stale or unknown latestValidOdometer
When the Road projection is computed
Then that milestone is marked with an unknown/stale dependency state

### REQ-ROAD-007 — No invented mileage or time conversion
Status: approved (owner, 2026-09-22)
Core: C2
Source: [Mixed time and mileage](#mixed-time-and-mileage), [Acceptance criteria](#acceptance-criteria), [Failure criteria](#failure-criteria), [ADR 0034](../decisions/0034-mileage-rate-estimate.md)
Given date-based or mileage-based milestones
When the Road projection is computed or rendered
Then each milestone is placed, ordered and labelled by its own dimension; time is not converted to mileage or mileage to time except in the labelled date estimate of REQ-ROAD-022; and current mileage is never invented

### REQ-ROAD-008 — Known milestones are visible in the initial viewport
Status: proposed
Core: P5
Source: [Initial viewport](#initial-viewport), [Test-first scenarios](#test-first-scenarios), [Failure criteria](#failure-criteria)
Given at least one known eligible future milestone, including one beyond a literal scale
When Road opens at its default position
Then the initial viewport shows the nearest eligible milestone instead of empty road

### REQ-ROAD-009 — Honest no-known-milestones state
Status: proposed
Core: C2, P5
Source: [Initial viewport](#initial-viewport), [Test-first scenarios](#test-first-scenarios)
Given a RoadContext with no eligible milestones
When Road opens
Then it shows a calm explicit no-known-milestones state and no fake milestones

### REQ-ROAD-010 — Large past is compressed
Status: proposed
Core: P5
Source: [Past](#past), [Test-first scenarios](#test-first-scenarios), [Failure criteria](#failure-criteria)
Given many past events
When the Road projection is computed
Then the past is compressed into a compact history marker or "look back" affordance without equal spatial weight

### REQ-ROAD-011 — Distinct milestone states
Status: proposed
Core: P3, C2
Source: [Overdue milestones](#overdue-milestones), [Test-first scenarios](#test-first-scenarios)
Given milestones that are approaching, due, overdue, or have an unknown/stale dependency
When Road renders them
Then each state is distinguishable from the others

### REQ-ROAD-012 — Overdue is not shown as danger
Status: proposed
Core: P5
Source: [Overdue milestones](#overdue-milestones)
Given an overdue milestone with no genuine danger or error
When Road renders it
Then it uses design-system semantic colour and not the red danger/error colour

### REQ-ROAD-013 — Converging milestone labels do not overlap
Status: proposed
Core: P5
Source: [Overlap](#overlap), [Test-first scenarios](#test-first-scenarios), [Failure criteria](#failure-criteria)
Given multiple milestones that converge on Road
When Road renders them
Then their labels do not overlap

### REQ-ROAD-014 — Road meaning survives Reduce Motion
Status: proposed
Core: P5
Source: [Motion](#motion), [Test-first scenarios](#test-first-scenarios)
Given Reduce Motion is enabled
When Road state changes or Road recenters
Then the car motion is not played and Road meaning remains understandable

### REQ-ROAD-015 — Non-visual semantic summary
Status: proposed
Core: P5
Source: [Road projection](#road-projection), [Test-first scenarios](#test-first-scenarios), [Acceptance criteria](#acceptance-criteria)
Given any RoadContext, including one with no known milestones
When the Road projection is computed
Then it includes a semanticSummary available as a non-visual description of Road

### REQ-ROAD-016 — The owner can state a planned date
Status: proposed
Core: P1, C2
Source: [Planned dated events](#planned-dated-events), [ADR 0032](../decisions/0032-planned-dated-events.md)
Given the owner enters an insurance expiry, or another date with or without a short name, from the Road screen
When the date is saved
Then only its kind, day, and name are stored, it is not a History event, and it appears on Road labelled by days left

### REQ-ROAD-017 — Planned dates are validated before anything is stored
Status: proposed
Core: C2
Source: [Planned dated events](#planned-dated-events), [ADR 0032](../decisions/0032-planned-dated-events.md)
Given a planned date earlier than 14 days ago or more than ten years ahead, or a name that is blank, spans lines, or is longer than 40 characters
When it is saved
Then it is rejected with a reason and nothing is stored

### REQ-ROAD-018 — One insurance expiry on Road per car
Status: proposed
Core: P3
Source: [Planned dated events](#planned-dated-events), [ADR 0032](../decisions/0032-planned-dated-events.md)
Given an insurance expiry that is still on Road
When another insurance expiry is added, or another date is changed into one
Then it is rejected, and correcting the existing expiry, or adding one after it has left Road, still works

### REQ-ROAD-019 — Planned dates can be corrected and deleted
Status: proposed
Core: P1
Source: [Planned dated events](#planned-dated-events), [ADR 0032](../decisions/0032-planned-dated-events.md)
Given a planned date on the Road list
When the owner edits it, or confirms a delete dialog that names it
Then the same plan changes or is removed, cancelling the dialog changes nothing, and no History, completion, or policy changes

### REQ-ROAD-020 — A passed planned date leaves Road after 14 days
Status: proposed
Core: P5
Source: [Planned dated events](#planned-dated-events), [ADR 0008](../decisions/0008-road-projection-rules.md)
Given a planned date that has passed
When the Road projection is computed
Then the date is shown as due for 14 days after it and is not a milestone afterwards, while the stored date is kept

### REQ-ROAD-021 — Planned dates survive relaunch and schema migration
Status: proposed
Core: P1
Source: [Planned dated events](#planned-dated-events), [ADR 0032](../decisions/0032-planned-dated-events.md)
Given planned dates and a store written by an earlier schema version
When the app opens the store again
Then the planned dates, car memory, and Pit question state are all intact

### REQ-ROAD-022 — A distance milestone may carry a labelled date estimate
Status: approved (owner, 2026-09-22)
Core: C2, P5
Source: [Mixed time and mileage](#mixed-time-and-mileage), [ADR 0034](../decisions/0034-mileage-rate-estimate.md)
Given a distance-placed milestone with known remaining kilometres and an eligible reading history (REQ-ROAD-023)
When the Road projection is computed
Then the milestone carries an estimated date range derived from the reading history, labelled as an estimate, and its placement, order and state are the same as without it

### REQ-ROAD-023 — No estimate without enough recent readings
Status: approved (owner, 2026-09-22)
Core: C2
Source: [Mixed time and mileage](#mixed-time-and-mileage), [ADR 0034](../decisions/0034-mileage-rate-estimate.md)
Given fewer than 3 observations in the last 365 days, a span under 60 days, a newest observation older than 90 days, fewer than 2 usable pairs, no remaining kilometres, a range wider than twice its early bound, or a bound more than 730 days away
When the Road projection is computed
Then the milestone carries no estimate and nothing else changes

### REQ-ROAD-026 — A milestone decided by a dashboard reading says so
Status: proposed
Core: C2
Source: [Mixed time and mileage](#mixed-time-and-mileage), [ADR 0035](../decisions/0035-dashboard-service-reading.md)
Given a maintenance milestone whose deciding anchor came from the car's dashboard reading
When the milestone is labelled on Road or the Road tile
Then its fact reads "from dashboard" after the distance or days; a milestone decided by the owner's interval has no such suffix; placement, dimension, order and state are derived as for any other anchor, with no conversion

