# PitStop Engineering & Product Documentation

**Status:** authoritative working source of truth  
**Primary platform:** iOS  
**Current product boundary:** one car context per user for the first product slice  
**Core product statement:** **PitStop is a smart driver's journal and contextual memory for a car.**

> PitStop remembers the car with the driver.

## Product model

PitStop starts from the driver, not from a complete vehicle profile.

```text
CAR BOARD
    ↓
ROAD + NOTES + SERVICE + HISTORY
    ↑
REMEMBER
    ↑
Pit / Siri / Widget / Shortcuts / direct UI
```

Core lifecycle:

```text
THINK → REMEMBER → MEMORY PROPOSAL → SAFE DOMAIN MUTATION
DO    → HISTORY
FACTS + POLICIES → MAINTENANCE STATE → ROAD
```

The application must remain useful without AI and without Pit. Pit is a persistent helper for capture, clarification, and progressive discovery. Pit is not navigation and is not the product itself.

## First-launch rule

Do not block value with authentication, a vehicle form, or a classical onboarding funnel.

Open into a usable Car Board with a provisional car context:

```text
name: My New Car
mileage: 0
vehicle details: unknown
```

Unknown data must degrade gracefully. Learn vehicle context progressively and ask only questions that unlock measurable value.

## Root information architecture

The leading root IA is **Car Board**, not a classical tab bar.

Primary product surfaces:
- Car Board
- Road
- Notes
- Service
- History
- Car profile/data
- Settings

Settings and Pit live in a persistent bottom utility layer. Settings is one tap away. Pit is always available on primary and detail screens.

## Core capability: Remember

`Remember` is the product capability and preferred product verb.

All capture sources feed one semantic pipeline:

```text
voice / text / shortcut / widget / Siri / Pit
                ↓
          CaptureInput
                ↓
       Semantic Interpreter
                ↓
         Memory Proposal
                ↓
        Confirmation Policy
                ↓
          Domain Mutation
```

The source does not determine the domain operation.

## Maintenance boundary

Maintenance remains a deterministic domain and an important PitStop capability. It is not the entire product mental model.

```text
Vehicle facts
    ↓
Maintenance knowledge
    ↓
Effective per-operation policies
    ↓
Independent maintenance cycles
    ↓
Maintenance state / plans
    ↓
Road milestones + Service surface
    ↓
Confirmed completion
    ↓
History + cycle resets for confirmed work only
```

## Engineering rule

> AI interprets input and proposes typed meaning. Deterministic domain code owns truth and mutation.

Experimental technology belongs behind explicit boundaries. Product correctness must not depend on model availability.

## Documentation map

Start with:
1. `01_PRODUCT_CHARTER.md`
2. `17_PRODUCT_DESIGN.md`
3. `31_CAR_BOARD_SCREEN_CONTRACT.md`
4. `32_ROAD_DOMAIN_AND_UI_CONTRACT.md`
5. `33_PIT_BEHAVIOR_AND_MOTION_SPEC.md`
6. `34_CAPTURE_PIPELINE_SPEC.md`
7. `08_ROADMAP.md`

See `00_DOCUMENTATION_INDEX.md` for the complete map.

## Spec lifecycle

Two classes of documents:

**Permanent contracts** — product and engineering behaviour (`01`, `02`, `03`, `17`, `31`–`36`, `34`, `05`–`06`, `13`–`14`, `21`–`23`, `25`–`26`). Keep `**Status:**` at the top. Never delete when a task ships.

**Executable backlog** — tracked in [`38_WORK_PLAN.md`](38_WORK_PLAN.md). When work starts:

1. Create one GitHub issue (template: `16_TASK_TEMPLATE.md`).
2. Set work-plan row to `tracked` with issue number.
3. Remove duplicated acceptance text from `08_ROADMAP.md`.
4. On completion: `done`; delete empty roadmap rows.

Status values: `contract` | `ready` → `tracked` → `done` | `deferred` | `cancelled`.

WIP limit: **1** active implementation issue (solo).

Legacy tab-bar spike: branch `legacy/spike`. Current product: `main`.

**GitHub Project:** [PitStop board](https://github.com/users/vil4max/projects/2). Create with `gh project create --owner vil4max --title "PitStop"`. Columns: Backlog → Ready → In progress (max 1) → In review → Done. Labels: `domain`, `ui`, `capture`, `investigation`, `ci`, `p0`, `p1`, `blocked`.

## Current explicit decisions

- Smart driver's journal / contextual car memory is the primary mental model.
- User-first, not vehicle-first.
- One provisional car context exists immediately.
- No mandatory authentication before value.
- No mandatory voice.
- No mandatory vehicle questionnaire.
- Progressive discovery replaces a binary onboarding-completed model.
- Car Board is the leading root IA.
- No classical tab bar in the leading hypothesis.
- Tiles are summary + entrance.
- V1 tile order and sizes are product-defined.
- Drag and drop is deferred to V2.
- Road is a primary product visualisation.
- Pit is a restrained persistent helper.
- Pit Eyes / Behind the UI is the working visual hypothesis.
- Remember is the core capture capability.
- One Capture Pipeline serves all capture sources.
- Native Apple interaction patterns are the default.
- Existing seeded/hard-coded records must be audited before domain migration.
