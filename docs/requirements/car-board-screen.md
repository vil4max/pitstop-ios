# Car Board Screen Contract

**Status:** P0 product contract

Core: P1, P2, P3, P5, C1, C2, C5

## Purpose

Car Board is the root product surface.

> Home is the car. Everything else is a view into its memory.

It must answer:
1. Which car context am I looking at?
2. What matters next?
3. What do I remember about it?
4. Where can I quickly continue?

## Non-goals

- generic dashboard builder;
- fleet overview;
- tab-bar replacement with hidden navigation;
- full maintenance report;
- analytics dashboard;
- mandatory profile completion.

## First-launch state

Render immediately with a provisional car context:

```text
displayName: My New Car
odometer: unknown until a mileage observation exists (a reading, or a completion saved with its mileage)
vehicle facts: unknown
```

This state is editable and explicitly provisional in the domain. UI must not falsely claim the user bought a new car.

Omit numeric mileage or label it unknown until supplied. A display placeholder
is not a confirmed reading and must not feed Service or Road calculations.

No authentication or setup gate.

## Composition

Leading composition:

```text
MY CAR
Arteon / My New Car

[            CAR HERO             ]

[              ROAD               ]

[      NOTES      ][    SERVICE   ]
[ summary         ][ summary      ]

[     HISTORY     ][ future slot  ]

[ Settings ]                         [ Pit Eyes ]
```

Exact visual spacing belongs to the design system.

## Tile contract

A tile is `summary + entrance`.

A tile must expose meaningful state before tap.

The [charter feature map](product-charter.md#product-loop-and-feature-responsibilities)
defines what the destination does. Tile implementation does not establish that
the destination can save, retrieve, or correct records.

Allowed V1 sizes:

```text
.full
.half
```

V1 order is product-defined.

Conceptual descriptor:

```text
TileDescriptor
- id
- kind
- size
- defaultOrder
- visibilityPolicy
```

This descriptor exists to avoid architectural lock-in. Do not implement a generic layout engine.

## Required V1 tiles

### Road

`.full`

Shows the current/default Road horizon. See `road-domain-and-ui.md`.

### Notes

`.half`

Candidate summary:
- active/relevant note count;
- latest or contextually relevant note;
- recency.

Sparse state must invite capture without looking like an error.

Input: saved Notes, including raw Notes without AI metadata. The destination
lets the user read, correct, and archive them. A context filter must not make
unclassified Notes disappear from the main list.

### Service

`.half`

Candidate summary:
- nearest maintenance anchor;
- remaining distance/time;
- calm/attention state.

Must not display a health score.

Input: deterministic operation states from confirmed policies and completion
facts. The destination owns maintenance orientation and planning; the tile
does not infer that service happened or invent a baseline when facts are absent.

### History

`.half`

Candidate summary:
- latest meaningful event;
- recency.

Input: recorded vehicle events. The destination shows what happened and the
known supporting facts; an unconfirmed plan or archived Note is not an event.

## Car Hero

Shows:
- car visual;
- display name;
- only minimal supporting car context that has proven value.

Do not fill the hero with technical specifications.

Fallback visual strategy is defined in `product-design.md`.

## Sparse data policy

Unknown data is normal.

Do not render:
- `n/a` metric circles;
- empty charts;
- fake health values;
- large blank cards;
- setup checklists dominating Home.

Prefer:
- intentional summary copy;
- one useful next action;
- a neutral visual state.

## Navigation

Tapping a tile opens its owned feature surface.

Settings and Pit are not Car Board tiles.

No classical tab bar in the leading V1 hypothesis.

## Analytics questions

Measure:
- which Car Board surfaces are opened;
- whether Remember is used before profile enrichment;
- whether sparse-state actions are used;
- Road engagement;
- time to first meaningful memory;
- time to first corrected/enriched car fact.

Do not collect raw note or voice content.

## Accessibility

- tile labels expose summary meaning to VoiceOver;
- reading order follows visual order;
- Road has a non-visual semantic summary;
- Car Hero image has meaningful or intentionally decorative accessibility treatment;
- utility controls remain reachable with large text.

## Test-first scenarios

1. provisional car renders without vehicle facts;
2. unknown service state does not render fake urgency;
3. Notes sparse state remains actionable;
4. tile order is deterministic;
5. tile tap routes to correct feature;
6. Settings and Pit remain available;
7. Dynamic Type does not hide tile meaning;
8. Road semantic summary is available without animation.

## Acceptance criteria

- usable without setup;
- car context is visually primary;
- Road is present;
- required summary tiles communicate state before tap;
- no empty navigation tiles;
- no mandatory authentication;
- no tab bar;
- Settings and Pit remain one tap away.

## Failure criteria

- Home becomes a setup funnel;
- provisional data is presented as known truth;
- tiles show mostly icons and labels;
- sparse state looks broken;
- Car Board requires Pit to navigate;
- Road is decorative only.

## Requirements

Status `proposed` means derived from the contract text above and awaiting owner approval.

### REQ-BOARD-001 — First launch opens Car Board without gates
Status: proposed
Core: P2
Source: [First-launch state](#first-launch-state), [charter](product-charter.md#first-launch-contract), [Acceptance criteria](#acceptance-criteria), [Failure criteria](#failure-criteria)
Given no car context has been saved
When the app launches for the first time
Then Car Board renders immediately with no authentication, VIN, make/model, engine, fuel type, gearbox, or multi-step onboarding step

### REQ-BOARD-002 — Provisional car renders without vehicle facts
Status: proposed
Core: C1, C2
Source: [First-launch state](#first-launch-state), [charter](product-charter.md#first-launch-contract), [Test-first scenarios](#test-first-scenarios)
Given the first-launch provisional car context
When Car Board renders
Then Car Hero shows the display name "My New Car" and no vehicle facts

### REQ-BOARD-003 — Provisional context is marked provisional and editable
Status: proposed
Core: P1, C2
Source: [First-launch state](#first-launch-state), [charter](product-charter.md#first-launch-contract), [Failure criteria](#failure-criteria)
Given the first-launch car context
When the domain state is inspected
Then the context is marked provisional and accepts user edits

### REQ-BOARD-004 — Unknown mileage is never shown as 0 km
Status: proposed
Core: C2
Source: [First-launch state](#first-launch-state), [charter](product-charter.md#first-launch-contract)
Given no mileage observation exists: no valid odometer reading and no completion saved with its mileage
When Car Board renders
Then numeric mileage is omitted or shown with an explicit unknown label, never as 0 km

### REQ-BOARD-005 — Supplied zero reading is shown
Status: proposed
Core: C2
Source: [charter](product-charter.md#first-launch-contract)
Given the user supplied an odometer reading of 0
When Car Board renders
Then mileage is shown as 0 km

### REQ-BOARD-006 — Missing reading does not feed Service or Road
Status: proposed
Core: C2
Source: [First-launch state](#first-launch-state)
Given no valid odometer reading exists
When Service and Road states are calculated
Then no zero or placeholder mileage is used as a calculation input

### REQ-BOARD-007 — Tile order is deterministic
Status: proposed
Core: P5
Source: [Composition](#composition), [Tile contract](#tile-contract), [Test-first scenarios](#test-first-scenarios)
Given the same car context data
When Car Board renders repeatedly
Then tiles appear in the same product-defined default order

### REQ-BOARD-008 — V1 tiles use only full and half sizes
Status: proposed
Core: P5
Source: [Tile contract](#tile-contract), [Required V1 tiles](#required-v1-tiles)
Given the V1 tile set
When tile descriptors are built
Then Road is .full, Notes, Service, and History are .half, and no other size is used

### REQ-BOARD-009 — Tiles communicate state before tap
Status: proposed
Core: P5
Source: [Tile contract](#tile-contract), [Acceptance criteria](#acceptance-criteria), [Failure criteria](#failure-criteria)
Given any required V1 tile
When Car Board renders
Then the tile shows a summary of its state, not only an icon and label

### REQ-BOARD-010 — Road tile is present
Status: proposed
Core: P5
Source: [Road](#road), [Acceptance criteria](#acceptance-criteria)
Given any car context, including the provisional one
When Car Board renders
Then the Road tile shows the current or default Road horizon

### REQ-BOARD-011 — Notes sparse state remains actionable
Status: proposed
Core: P2, P5
Source: [Notes](#notes), [Test-first scenarios](#test-first-scenarios), [Failure criteria](#failure-criteria)
Given no saved Notes
When Car Board renders
Then the Notes tile invites capture and shows no error state

### REQ-BOARD-012 — Notes tile includes raw Notes
Status: proposed
Core: P1, P3
Source: [Notes](#notes)
Given a saved raw Note without AI metadata
When Car Board renders
Then the Notes tile summary accounts for that Note

### REQ-BOARD-013 — No health score or fake health values
Status: proposed
Core: C2
Source: [Service](#service), [Sparse data policy](#sparse-data-policy)
Given any maintenance data, including none
When Car Board renders
Then no health score or fake health value is displayed

### REQ-BOARD-014 — Unknown service state shows no fake urgency
Status: proposed
Core: C2
Source: [Service](#service), [Test-first scenarios](#test-first-scenarios)
Given no confirmed maintenance policies or completion facts
When Car Board renders
Then the Service tile shows no attention or urgency state

### REQ-BOARD-015 — Service tile does not infer completion or baseline
Status: proposed
Core: C2, C5
Source: [Service](#service)
Given no confirmed completion fact for an operation
When the Service tile summary is built
Then it neither shows that service happened nor derives remaining distance or time from an invented baseline

### REQ-BOARD-016 — History tile shows only recorded events
Status: proposed
Core: C5
Source: [History](#history)
Given only unconfirmed plans or archived Notes and no recorded events
When Car Board renders
Then the History tile shows no latest event

### REQ-BOARD-017 — Car Hero shows visual and name without specifications
Status: proposed
Core: P5
Source: [Car Hero](#car-hero)
Given any car context
When Car Board renders
Then Car Hero shows a car visual and display name and no technical specification list

### REQ-BOARD-018 — Sparse data renders no placeholder metrics
Status: proposed
Core: C2, P5
Source: [Sparse data policy](#sparse-data-policy), [Failure criteria](#failure-criteria)
Given unknown car and maintenance data
When Car Board renders
Then no `n/a` metric circles or empty charts are rendered

### REQ-BOARD-019 — Tile tap opens its owned surface without Pit
Status: proposed
Core: P3
Source: [Navigation](#navigation), [Test-first scenarios](#test-first-scenarios), [Failure criteria](#failure-criteria)
Given Car Board is shown
When the user taps a tile
Then the tile's owned feature surface opens without involving Pit

### REQ-BOARD-020 — Settings and Pit stay one tap away outside tiles
Status: proposed
Core: P3, P5
Source: [Composition](#composition), [Navigation](#navigation), [Test-first scenarios](#test-first-scenarios), [Acceptance criteria](#acceptance-criteria)
Given Car Board is shown
When the user looks for Settings or Pit
Then each is reachable with one tap and neither is rendered as a tile

### REQ-BOARD-021 — Tile labels expose summary meaning to VoiceOver
Status: proposed
Core: P5
Source: [Accessibility](#accessibility)
Given VoiceOver is on
When focus moves to a tile
Then the spoken label includes the tile's summary meaning

### REQ-BOARD-022 — Accessibility reading order follows visual order
Status: proposed
Core: P5
Source: [Accessibility](#accessibility)
Given VoiceOver is on
When the user navigates Car Board sequentially
Then elements are read in visual order

### REQ-BOARD-023 — Road has a semantic summary without animation
Status: proposed
Core: P5
Source: [Accessibility](#accessibility), [Test-first scenarios](#test-first-scenarios), [Failure criteria](#failure-criteria)
Given Road is shown with animation disabled or unavailable
When assistive technology reads the Road tile
Then a non-visual semantic summary of Road is available

### REQ-BOARD-024 — Car Hero image has explicit accessibility treatment
Status: proposed
Core: P5
Source: [Accessibility](#accessibility)
Given Car Hero is shown
When the accessibility tree is inspected
Then the car image has a meaningful label or is marked decorative

### REQ-BOARD-025 — Large text keeps tile meaning and utility controls
Status: proposed
Core: P5
Source: [Accessibility](#accessibility), [Test-first scenarios](#test-first-scenarios)
Given the largest Dynamic Type size
When Car Board renders
Then tile summary meaning stays visible and Settings and Pit remain reachable

### REQ-BOARD-026 — Header mileage is the newest mileage observation
Status: approved (owner, 2026-09-21)
Core: C2
Source: [First-launch state](#first-launch-state); [`../decisions/0010-maintenance-engine-rules.md`](../decisions/0010-maintenance-engine-rules.md)
Given a completion saved with its mileage is newer than any odometer reading
When Car Board renders
Then the header shows that mileage, the same value Service counts from, and saving the same number in the car editor while that mileage is stale records a fresh reading
