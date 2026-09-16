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
Status: proposed
Core: C2
Source: [Mixed time and mileage](#mixed-time-and-mileage), [Acceptance criteria](#acceptance-criteria), [Failure criteria](#failure-criteria)
Given date-based or mileage-based milestones and no explicit supported projection model
When the Road projection is computed or rendered
Then time is not converted to mileage or mileage to time, and current mileage is never invented

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
