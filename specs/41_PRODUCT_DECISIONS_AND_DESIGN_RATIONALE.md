# PitStop — Product Decisions and Design Rationale

**Status:** Living design rationale  
**Purpose:** Preserve why PitStop looks and behaves the way it does

This document is **not** a specification.

This document is **not** a roadmap.

This document is **not** an implementation contract.

Specifications describe **what** the system does.

This document explains **why** those decisions were made.

It exists so future development can resume without rediscovering months of design work.

Authoritative behaviour remains in the owning specs. Prefer links over duplication.

---

# Project Status

Current status:

- Product implementation paused.
- Architecture continues only through documentation.
- No new runtime features.
- No AI implementation.
- Product baseline has higher priority than AI.

See also [`PROJECT_STATUS.md`](../PROJECT_STATUS.md) and the freeze rules in [`40_AI_ENGINEERING_ROADMAP.md`](40_AI_ENGINEERING_ROADMAP.md).

---

# Product Vision

PitStop is **not**:

- a maintenance tracker
- a garage manager
- an OBD scanner
- an AI chatbot
- a car encyclopedia

Those shapes force vehicle-first or tool-first thinking. They push the driver into forms, health scores, or chat before memory has value.

PitStop is:

> **A smart driver's journal and contextual memory for a car.**

Another way to express the same idea:

> **Pit remembers the car together with the driver.**

The product starts from the driver's memory rather than from vehicle configuration.

Owner for product statement and jobs: [`01_PRODUCT_CHARTER.md`](01_PRODUCT_CHARTER.md).  
Owner for idea validation before new features: [`42_PRODUCT_REVIEW.md`](42_PRODUCT_REVIEW.md).  
Owner for product framing: [`README.md`](README.md).

---

# Product Principles

## Driver first

The product exists for the driver.

The vehicle is context.

The driver is the primary entity.

Reasoning: a complete vehicle profile is optional for journaling. A driver who can capture meaning immediately gets value even when make, VIN, and intervals are still unknown.

## Remember

The central capability is **Remember**.

Everything eventually becomes remembering.

Examples:

- remember fuel
- remember service
- remember expenses
- remember something strange
- remember where something happened

Capture is the primary product capability because friction at the moment of memory is the failure mode the product exists to remove.

Owner: [`01_PRODUCT_CHARTER.md`](01_PRODUCT_CHARTER.md), [`34_CAPTURE_PIPELINE_SPEC.md`](34_CAPTURE_PIPELINE_SPEC.md).

## Product before AI

AI is infrastructure.

The product must remain useful without AI.

If deterministic software solves a problem better, deterministic software wins.

Reasoning: model availability, language quality, and vendor churn must not define whether PitStop is usable. Correctness must survive AI being off.

Owner summary: [`README.md`](README.md), [`04_AI_ARCHITECTURE.md`](04_AI_ARCHITECTURE.md).

## Deterministic truth

AI proposes.

The deterministic domain decides.

Only deterministic code owns product truth.

Reasoning: maintenance cycles, vehicle facts, and history must remain explainable and testable without trusting a model session.

Owners: [`02_DOMAIN_MODEL.md`](02_DOMAIN_MODEL.md), [`03_MAINTENANCE_ENGINE.md`](03_MAINTENANCE_ENGINE.md), [`04_AI_ARCHITECTURE.md`](04_AI_ARCHITECTURE.md).

## Unknown stays unknown

PitStop never fabricates vehicle facts.

Unknown information remains unknown until:

- user confirms
- user edits
- deterministic logic derives it safely

Reasoning: invented mileage, fuel type, or service state creates false confidence and unsafe maintenance pressure.

Owner: [`01_PRODUCT_CHARTER.md`](01_PRODUCT_CHARTER.md), [`README.md`](README.md).

---

# Mental Model

The application is centered around the **Car Board**.

The Car Board is the home surface.

Everything else extends it.

Primary surfaces:

- Car Board
- Road
- Notes
- Service
- History
- Car profile
- Settings

This intentionally replaces the traditional tab bar as the primary mental model.

Reasoning:

- A tab bar implies equal peer destinations and a “pick a database” habit.
- Car Board keeps the car visually primary and treats tiles as summary plus entrance.
- Road is a first-class visualisation of what matters next, not a buried list.
- Remember is the capture verb that feeds the board; it is not a competing home tab.

Owners: [`17_PRODUCT_DESIGN.md`](17_PRODUCT_DESIGN.md), [`31_CAR_BOARD_SCREEN_CONTRACT.md`](31_CAR_BOARD_SCREEN_CONTRACT.md), [`32_ROAD_DOMAIN_AND_UI_CONTRACT.md`](32_ROAD_DOMAIN_AND_UI_CONTRACT.md).

---

# Progressive Discovery

The product intentionally avoids heavy onboarding.

Rejected ideas:

- mandatory registration
- mandatory VIN
- mandatory vehicle profile
- mandatory questionnaire
- mandatory voice onboarding

Instead:

The user receives value immediately.

Vehicle knowledge grows naturally over time.

Questions appear only when they unlock measurable value.

Reasoning: classical onboarding optimises for data completeness. PitStop optimises for early usefulness with sparse data. Asking only high-value questions protects trust and keeps progressive discovery measurable.

Owner: [`01_PRODUCT_CHARTER.md`](01_PRODUCT_CHARTER.md).

---

# Capture Philosophy

Every capture source is equal.

There is only one Capture Pipeline.

Sources include:

- text
- voice
- Siri
- Widget
- Shortcut
- Pit

Input source never determines domain behavior.

Everything becomes structured meaning through the same pipeline, then deterministic validation and mutation.

Reasoning: source-specific mutation paths create inconsistent truth and duplicate stacks (for example Siri writing persistence directly). One pipeline keeps tests, confirmation policy, and raw preservation shared.

Owner: [`34_CAPTURE_PIPELINE_SPEC.md`](34_CAPTURE_PIPELINE_SPEC.md).  
Runtime AI roles: [`04_AI_ARCHITECTURE.md`](04_AI_ARCHITECTURE.md).

Conceptual pipeline:

```text
CaptureInput
        ↓
Semantic Interpreter
        ↓
Memory Proposal
        ↓
Validation
        ↓
Confirmation Policy
        ↓
Domain Mutation
        ↓
Persistence
```

AI only participates in interpretation.

Everything after that is deterministic.

---

# AI Philosophy

AI exists to understand intent.

AI does not own product behavior.

Detailed MAY / MUST NOT lists and confirmation policy live in [`04_AI_ARCHITECTURE.md`](04_AI_ARCHITECTURE.md) and [`34_CAPTURE_PIPELINE_SPEC.md`](34_CAPTURE_PIPELINE_SPEC.md).

Reasoning behind the major AI boundaries:

| Idea | Why |
|---|---|
| Intelligence abstraction / `IntelligenceService` | Features must not import provider SDKs; vendors remain replaceable ([`README.md`](README.md)) |
| Provider abstraction | Architecture should outlive Foundation Models, PCC, Claude, OpenAI, Gemini, and future providers |
| Deterministic domain ownership | Product truth must remain testable without a model |
| MemoryProposal | Chat text must never become product state; typed meaning can be validated |
| Validation before mutation | Providers cannot bypass domain invariants |
| Explainability | The driver should understand why Pit suggests something |
| Evaluation | Prompt and provider changes need measurable quality ([`13_TEST_STRATEGY.md`](13_TEST_STRATEGY.md)); long-term evaluation direction in [`40_AI_ENGINEERING_ROADMAP.md`](40_AI_ENGINEERING_ROADMAP.md) |

Long-term AI direction and freeze rules: [`40_AI_ENGINEERING_ROADMAP.md`](40_AI_ENGINEERING_ROADMAP.md).  
AI Product Analyst (development workflow, not app runtime): [`30_AI_PRODUCT_ANALYTICS.md`](30_AI_PRODUCT_ANALYTICS.md).

---

# Pit Philosophy

Pit is not the product.

Pit is the persistent companion.

Intended character:

- minimal
- calm
- expressive eyes
- event-driven
- supportive
- never annoying
- never guilt-inducing
- persistent companion
- always available on primary and detail surfaces
- not navigation
- not a chat tab
- not a generic AI assistant

Pit helps remember.

Pit does not replace the application.

The app remains useful without Pit.

Owner: [`33_PIT_BEHAVIOR_AND_MOTION_SPEC.md`](33_PIT_BEHAVIOR_AND_MOTION_SPEC.md).  
Utility placement: [`35_BOTTOM_UTILITY_LAYER_SPEC.md`](35_BOTTOM_UTILITY_LAYER_SPEC.md).

---

# UX Decisions

Accepted:

- Car Board as home
- Remember as primary capability
- Progressive discovery
- Utility layer for Settings and Pit
- Persistent Pit
- Native Apple interaction patterns
- Tiles as summary plus entrance
- Road as a primary visualisation

Deferred:

- drag and drop
- advanced customization / configurable tile order
- shared cars
- cloud collaboration
- CarPlay unless validated

Owners: [`17_PRODUCT_DESIGN.md`](17_PRODUCT_DESIGN.md), [`08_ROADMAP.md`](08_ROADMAP.md), [`31_CAR_BOARD_SCREEN_CONTRACT.md`](31_CAR_BOARD_SCREEN_CONTRACT.md).

---

# Rejected Alternatives

These ideas were consciously rejected. Do not rediscover them as “obvious” product defaults.

## Product

- AI-first application
- maintenance-only application
- garage manager
- chatbot as primary UI
- OBD / diagnostic scanner identity

## UX

- classical onboarding funnel
- mandatory car profile before value
- mandatory registration before value
- mandatory VIN / questionnaire / voice onboarding
- tab bar as product center

## AI

- AI writing directly into storage
- provider-specific business logic in features or domain
- autonomous product decisions
- prompt-driven architecture as product truth
- AI-owned confirmation policy or maintenance rules

Related local ADR rejections for maintenance anchors: [`10_ADR_001_MAINTENANCE_ANCHORS.md`](10_ADR_001_MAINTENANCE_ANCHORS.md).

---

# Deferred Research

These ideas are intentionally postponed.

They are research directions.

They are not backlog commitments.

- Multi-agent workflows
- MCP
- Long-term memory
- Vision
- Voice conversation
- Dynamic Profiles
- Cloud orchestration
- Provider benchmarking
- AI evaluation framework implementation
- Shared vehicles
- Cloud sync
- Smart reminders powered by AI

Executable product backlog remains [`38_WORK_PLAN.md`](38_WORK_PLAN.md).  
Deferred AI phase framing: [`40_AI_ENGINEERING_ROADMAP.md`](40_AI_ENGINEERING_ROADMAP.md).  
MCP outside iOS runtime: [`30_AI_PRODUCT_ANALYTICS.md`](30_AI_PRODUCT_ANALYTICS.md).

---

# Architecture Philosophy

The product should outlive model vendors.

Architecture should survive AI trends.

Prefer deterministic software.

Use AI only where it creates measurable value.

Protect product truth.

Keep AI behind explicit boundaries.

Measure quality.

Resume product baseline work before any AI implementation.
