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

- Product baseline implementation is active (unfrozen 2026-09-16).
- No runtime AI implementation before the product baseline is complete.
- Product baseline has higher priority than AI.

See also [`PROJECT_STATUS.md`](../../PROJECT_STATUS.md) and the AI deferral rules in [`../planning/ai-roadmap.md`](../planning/ai-roadmap.md).

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

> **PitStop remembers the car together with the driver.**

The product starts from the driver's memory rather than from vehicle configuration.

Owner for product statement and jobs: [`../requirements/product-charter.md`](../requirements/product-charter.md).  
Owner for idea validation before new features: [`../engineering/product-review-process.md`](../engineering/product-review-process.md).  
Owner for product framing: [`product-overview.md`](../requirements/product-overview.md).

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

Owner: [`../requirements/product-charter.md`](../requirements/product-charter.md), [`../requirements/capture-pipeline.md`](../requirements/capture-pipeline.md).

## Product before AI

AI is infrastructure.

The product must remain useful without AI.

If deterministic software solves a problem better, deterministic software wins.

Reasoning: model availability, language quality, and vendor churn must not define whether PitStop is usable. Correctness must survive AI being off.

Owner summary: [`product-overview.md`](../requirements/product-overview.md), [`../engineering/ai-architecture.md`](../engineering/ai-architecture.md).

## Deterministic truth

AI proposes.

The deterministic domain decides.

Only deterministic code owns product truth.

Reasoning: maintenance cycles, vehicle facts, and history must remain explainable and testable without trusting a model session.

Owners: [`../requirements/domain-model.md`](../requirements/domain-model.md), [`../requirements/maintenance-engine.md`](../requirements/maintenance-engine.md), [`../engineering/ai-architecture.md`](../engineering/ai-architecture.md).

## Unknown stays unknown

PitStop never fabricates vehicle facts.

Unknown information remains unknown until:

- user confirms
- user edits
- deterministic logic derives it safely

Reasoning: invented mileage, fuel type, or service state creates false confidence and unsafe maintenance pressure.

Owner: [`../requirements/product-charter.md`](../requirements/product-charter.md), [`product-overview.md`](../requirements/product-overview.md).

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
- Car context
- Settings

This intentionally replaces the traditional tab bar as the primary mental model.

Reasoning:

- A tab bar implies equal peer destinations and a “pick a database” habit.
- Car Board keeps the car visually primary and treats tiles as summary plus entrance.
- Road is a first-class visualisation of what matters next, not a buried list.
- Remember is the capture verb that feeds the board; it is not a competing home tab.

Owners: [`../requirements/product-design.md`](../requirements/product-design.md), [`../requirements/car-board-screen.md`](../requirements/car-board-screen.md), [`../requirements/road-domain-and-ui.md`](../requirements/road-domain-and-ui.md).

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

Owner: [`../requirements/product-charter.md`](../requirements/product-charter.md).

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

Every input uses the same proposal, validation, and command boundaries. A raw
thought can remain a Note without model interpretation; supported interpretation
may propose stronger meaning but cannot establish truth on its own.

Reasoning: source-specific mutation paths create inconsistent truth and duplicate stacks (for example Siri writing persistence directly). One pipeline keeps tests, confirmation policy, and raw preservation shared.

Owner: [`../requirements/capture-pipeline.md`](../requirements/capture-pipeline.md).  
Runtime AI roles: [`../engineering/ai-architecture.md`](../engineering/ai-architecture.md).

Conceptual pipeline:

```text
CaptureInput
        ↓
Raw preservation OR Semantic Interpreter
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

Detailed MAY / MUST NOT lists and confirmation policy live in [`../engineering/ai-architecture.md`](../engineering/ai-architecture.md) and [`../requirements/capture-pipeline.md`](../requirements/capture-pipeline.md).

Reasoning behind the major AI boundaries:

| Idea | Why |
|---|---|
| Intelligence abstraction / `IntelligenceService` | Features must not import provider SDKs; vendors remain replaceable ([`product-overview.md`](../requirements/product-overview.md)) |
| Provider abstraction | Architecture should outlive Foundation Models, PCC, Claude, OpenAI, Gemini, and future providers |
| Deterministic domain ownership | Product truth must remain testable without a model |
| MemoryProposal | Chat text must never become product state; typed meaning can be validated |
| Validation before mutation | Providers cannot bypass domain invariants |
| Explainability | The driver should understand why Pit suggests something |
| Evaluation | Prompt and provider changes need measurable quality ([`../engineering/test-strategy.md`](../engineering/test-strategy.md)); long-term evaluation direction in [`../planning/ai-roadmap.md`](../planning/ai-roadmap.md) |

Long-term AI direction and deferral rules: [`../planning/ai-roadmap.md`](../planning/ai-roadmap.md).  
AI Product Analyst (development workflow, not app runtime): [`../operations/ai-product-analytics.md`](../operations/ai-product-analytics.md).

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

Owner: [`../requirements/pit-behavior-and-motion.md`](../requirements/pit-behavior-and-motion.md).  
Utility placement: [`../requirements/bottom-utility-layer.md`](../requirements/bottom-utility-layer.md).

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

Owners: [`../requirements/product-design.md`](../requirements/product-design.md), [`../planning/roadmap.md`](../planning/roadmap.md), [`../requirements/car-board-screen.md`](../requirements/car-board-screen.md).

---

# Rejected Alternatives

These ideas were consciously rejected. Do not rediscover them as “obvious” product defaults.
The binding summary is the Non-goals section of [`../core.md`](../core.md); this section keeps the reasoning.

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

Related local ADR rejections for maintenance anchors: [`0001-maintenance-anchors.md`](0001-maintenance-anchors.md).

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
- Pet/companion-style Pit persona (inspired by mewmori.com's pet mechanic and
  OpenAI Codex's mascot use) — tension: conflicts with the current "Pit Eyes /
  Behind the UI" visual hypothesis (`../requirements/product-design.md`), which explicitly
  rejects "oversized cute mascot eyes" and "Pixar-like body language"; see the
  open `INV-PROD-005 Pit value vs mascot noise` investigation
  (`../planning/investigations.md`).

Executable product backlog remains [`../planning/work-plan.md`](../planning/work-plan.md).  
Deferred AI phase framing: [`../planning/ai-roadmap.md`](../planning/ai-roadmap.md).  
MCP outside iOS runtime: [`../operations/ai-product-analytics.md`](../operations/ai-product-analytics.md).

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
