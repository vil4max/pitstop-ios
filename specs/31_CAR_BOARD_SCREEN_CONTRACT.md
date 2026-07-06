# Car Board Screen Contract

**Status:** P0 product contract

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
odometer: 0
vehicle facts: unknown
```

This state is editable and explicitly provisional in the domain. UI must not falsely claim the user bought a new car.

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

Shows the current/default Road horizon. See `32_ROAD_DOMAIN_AND_UI_CONTRACT.md`.

### Notes

`.half`

Candidate summary:
- active/relevant note count;
- latest or contextually relevant note;
- recency.

Sparse state must invite capture without looking like an error.

### Service

`.half`

Candidate summary:
- nearest maintenance anchor;
- remaining distance/time;
- calm/attention state.

Must not display a health score.

### History

`.half`

Candidate summary:
- latest meaningful event;
- recency.

## Car Hero

Shows:
- car visual;
- display name;
- only minimal supporting car context that has proven value.

Do not fill the hero with technical specifications.

Fallback visual strategy is defined in `17_PRODUCT_DESIGN.md`.

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
