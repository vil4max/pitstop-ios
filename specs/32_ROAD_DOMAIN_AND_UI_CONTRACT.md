# Road Domain and UI Contract

**Status:** P0 product hypothesis requiring investigation

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
