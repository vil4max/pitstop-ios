# PitStop Engineering & Product Documentation

**Status:** authoritative working source of truth  
**Primary platform:** iOS  
**Current product boundary:** one car context per user for the first product slice  
**Core product statement:** **PitStop is a smart driver's journal and contextual memory for a car.**  
**Project state:** Frozen — see [`../PROJECT_STATUS.md`](../PROJECT_STATUS.md)

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

Open into a usable Car Board with a provisional car context. Do not invent vehicle facts such as mileage, age, fuel type, or service state. Unknown data remains unknown until supplied or safely inferred.

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

## Intelligence boundary

AI/model access is a replaceable infrastructure concern, not a feature-level dependency.

```text
Feature / Capture Pipeline
            ↓
   Intelligence abstraction
            ↓
  Apple on-device / PCC / external model provider
```

Feature and domain code must not depend on a concrete vendor SDK or model family. The intelligence boundary owns provider selection, model-session lifecycle, request/response adaptation, and capability differences.

The semantic contract above the boundary is typed product meaning such as a `Memory Proposal`, not provider-specific chat messages or tool-call payloads. Provider-specific orchestration, including programmatic tool execution or multi-agent workflows, must remain behind the intelligence boundary.

Do not add orchestration complexity until a concrete product flow requires it. Prefer the cheapest deterministic or single-model path that satisfies the product contract.

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

Resume / freeze reading order: [`../PROJECT_STATUS.md`](../PROJECT_STATUS.md).

Start with:
1. `01_PRODUCT_CHARTER.md`
2. `42_PRODUCT_REVIEW.md` (mandatory idea validation before new features)
3. `41_PRODUCT_DECISIONS_AND_DESIGN_RATIONALE.md`
4. `39_DOMAIN_INVENTORY.md`
5. `17_PRODUCT_DESIGN.md`
6. `31_CAR_BOARD_SCREEN_CONTRACT.md`
7. `32_ROAD_DOMAIN_AND_UI_CONTRACT.md`
8. `33_PIT_BEHAVIOR_AND_MOTION_SPEC.md`
9. `34_CAPTURE_PIPELINE_SPEC.md`
10. `04_AI_ARCHITECTURE.md`
11. `40_AI_ENGINEERING_ROADMAP.md` (deferred direction only)
12. `08_ROADMAP.md` / `38_WORK_PLAN.md`

See `00_DOCUMENTATION_INDEX.md` for the complete map.

## Spec lifecycle

Two classes of documents:

**Permanent contracts** — product and engineering behaviour (`01`, `02`, `03`, `17`, `31`–`36`, `34`, `05`–`06`, `13`–`14`, `21`–`23`, `25`–`26`). Keep `**Status:**` at the top. Never delete when a task ships.

**Executable backlog** — tracked in [`38_WORK_PLAN.md`](38_WORK_PLAN.md). When work starts:

1. Complete Product Review for new features ([`42_PRODUCT_REVIEW.md`](42_PRODUCT_REVIEW.md)).
2. Create one GitHub issue (template: `16_TASK_TEMPLATE.md`).
3. Set work-plan row to `tracked` with issue number.
4. Remove duplicated acceptance text from `08_ROADMAP.md`.
5. On completion: `done`; delete empty roadmap rows.

Status values: `contract` | `ready` → `tracked` → `done` | `deferred` | `cancelled`.

WIP limit: **1** active implementation issue (solo).

Legacy tab-bar spike: branch `legacy/spike`. Current product: `main`.

**GitHub Project:** [PitStop board #2](https://github.com/users/vil4max/projects/2) — full backlog as issues #1–#36. One task **In progress** at a time (solo).

**Branch naming:** `{TASK-ID}/{slug}` e.g. `DOM-001/domain-inventory`. PR must pass CI (branch check, SwiftFormat, build, tests).

**Branch protection (enable in repo settings):** require PR + status checks `branch-name`, `quality`, `build-and-test` before merge to `main`.

## Current explicit decisions

- Smart driver's journal / contextual car memory is the primary mental model.
- User-first, not vehicle-first.
- One provisional car context exists immediately.
- Provisional context must not fabricate vehicle facts.
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
- AI/model providers live behind an intelligence abstraction.
- Feature and domain code must not depend on concrete model vendor SDKs.
- Native Apple interaction patterns are the default.
- Existing seeded/hard-coded records must be audited before domain migration.
