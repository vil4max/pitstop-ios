# AI Engineering Roadmap

**Status:** Deferred Roadmap  
**Scope:** Long-term AI direction and pause-time knowledge preservation  
**Numbering note:** `39_DOMAIN_INVENTORY.md` already owns index `39`; this document is `40`

This document captures long-term AI direction for PitStop.

It is **not** an implementation contract.

Existing implementation contracts remain authoritative. Prefer and extend these owners instead of replacing them:

- [`04_AI_ARCHITECTURE.md`](04_AI_ARCHITECTURE.md) — runtime AI trust boundary and model roles
- [`34_CAPTURE_PIPELINE_SPEC.md`](34_CAPTURE_PIPELINE_SPEC.md) — Remember / Capture Pipeline
- [`39_DOMAIN_INVENTORY.md`](39_DOMAIN_INVENTORY.md) — what exists on `main` today
- [`13_TEST_STRATEGY.md`](13_TEST_STRATEGY.md) — AI evaluation / golden-set rules
- [`README.md`](README.md) — intelligence boundary summary

---

# Why this document exists

PitStop implementation is intentionally paused.

Architectural AI decisions were captured here so future work can resume without repeating months of design debate.

This roadmap preserves:

- the audited current state of AI-related contracts and code
- long-term direction that must not be mistaken for present runtime behaviour
- freeze rules that keep AI work deferred until the product baseline is active again

When implementation resumes, start from the product baseline and the authoritative owners above. Use this document for direction, not as a parallel source of truth.

## AI Product Engineering Map

This section connects PitStop's product direction with a full AI Product
Engineering learning loop. It is a planning and study map only; it does not
authorize runtime AI work while the project is frozen and does not replace the
owning specifications below.

Keep two tracks separate:

- **AI-assisted development** — how the owner uses agents to investigate,
  design, implement, verify, review, release, and learn from PitStop.
- **AI inside PitStop** — where the shipped product may use a model to
  interpret input or provide bounded assistance.

The first track may support ordinary product-baseline work after unfreeze. The
second track starts only after the baseline is useful without AI.

### Full-cycle loop

```text
Problem / trigger
    → JTBD + Product Review
    → product and domain contract
    → design + bounded work plan
    → agent-assisted implementation
    → deterministic verification + defect-first review
    → AI evaluation where a model is involved
    → TestFlight / beta release
    → bounded telemetry + interviews
    → evidence-backed product decision
    → updated contract, investigation, or task
```

The release loop is complete only when a usable slice is deployed and
maintained long enough to produce feedback. “The model works” is not a product
success criterion.

### Capability map

| Capability | User problem | AI role | Deterministic boundary | Eval | Telemetry | Release gate |
|---|---|---|---|---|---|---|
| Product baseline: Car Board, Notes, Service, History, Road | The driver cannot understand what matters about the car at a glance | None required; prefer deterministic projections | Domain state, persistence, and projections own truth | Domain, integration, and critical UI tests | Approved P0 product events; no raw content | M3 exit criteria in [`38_WORK_PLAN.md`](38_WORK_PLAN.md); core beta gate in [`15_RELEASE_AND_BETA.md`](15_RELEASE_AND_BETA.md) |
| Raw Remember capture | A thought is easy to lose when the user must choose a record type first | No model required for initial capture; preserve the input | `CaptureInput`, raw preservation, and one command path | Source mapping, cancellation, unavailable-AI, and raw-preservation cases in [`34_CAPTURE_PIPELINE_SPEC.md`](34_CAPTURE_PIPELINE_SPEC.md) | `input_interpretation_completed`, `draft_saved`, `draft_cancelled` with bounded fields | CAP-001, CAP-006, and a usable capture surface |
| Contextual note interpretation | The driver wants to save meaning without filling out a form or maintaining taxonomy | Propose typed note meaning and, when safe, a context | Proposal validation plus deterministic `CreateNote`; original wording remains available | Golden set: positive, ambiguous, unsupported, and correction cases | Result, intent, latency bucket, interpreter version; never raw text | CAP-002, CAP-004, CAP-005, CAP-007 plus `INV-CAP-001` decision |
| Odometer capture | Numeric facts are slow and error-prone to enter manually | Extract an odometer value from natural input | Range/anomaly validation and deterministic `RecordOdometerReading` | Boundary, malformed-number, conflict, and correction cases | `odometer_updated` without the exact value | Domain validation, confirmation policy, and data-integrity release gate |
| Progressive vehicle facts | The driver needs useful personalization without a VIN-first setup | Propose a fact only when it is explicitly present or safely confirmed | Unknown remains unknown; user confirmation and deterministic `RecordVehicleFact` | Missing, conflicting, and unsupported fact cases | Bounded enrichment mode and source; avoid identifying combinations | `INV-VEH-003`, persistence baseline, and Product Review |
| Maintenance completion | A service memory should update the right cycle without creating false urgency | Suggest a possible completion and missing fields | Validation, risk-based confirmation, and deterministic cycle reset | Separate high-risk false-classification set; partial-completion invariants | Pipeline stage/reason plus bounded maintenance outcomes | CAP-002, maintenance matrix in [`13_TEST_STRATEGY.md`](13_TEST_STRATEGY.md), and beta stop criteria |
| Document extraction | A service document contains useful facts but is costly to transcribe | Later: extract a bounded proposal from OCR/document text | Redacted input, typed validation, user confirmation, and domain commands | Redacted golden documents, OCR errors, omissions, and unsupported layouts | Stage, reason, latency bucket; never OCR or invoice text | Separate investigation and explicit release decision; not part of the first AI slice |
| Contextual recall and Pit assistance | The driver needs a previous memory at the right moment, without a generic chat workflow | Later: bounded clarification, summary, or relevance assistance | Stored history and deterministic retrieval remain authoritative; Pit is optional | Retrieval relevance, clarification usefulness, dismissal, and no-Pit usability | `note_context_opened`, bounded Pit outcomes, interruption/cooldown data | Product investigations `INV-PROD-001`, `INV-PROD-005`, and beta evidence |
| AI-assisted product analytics | The owner needs to turn small-beta evidence into the next discriminating investigation | Interpret a deterministic evidence package and propose hypotheses | AQ thresholds, query results, privacy rules, and human product decisions | Evidence-grounding and limitation-awareness checks | Analytics channel only; no raw notes or silent event creation | `30_AI_PRODUCT_ANALYTICS.md`, approved `AQ-*`, and human decision |

The map deliberately keeps deterministic product work ahead of model work. A
model can be replaced or removed without changing the product's ownership of
truth, persistence, confirmation, or release decisions.

### First learning slice after the baseline

A useful candidate is the real-world prompt:

> “Перед зимой поменять дворники” / “Replace the wipers before winter.”

This is a study scenario, not yet an accepted product contract. Product Review
and the capture owners must decide whether its first supported meaning is a
contextual note, a reminder candidate, or another validated proposal kind.
The learning path is:

```text
raw input
    → CaptureInput
    → typed proposal
    → deterministic validation
    → risk-based confirmation or clarification
    → domain command
    → persistence and projection
    → correction path
    → golden-set evaluation
    → bounded telemetry
    → TestFlight feedback
```

This single slice is sufficient to study context engineering, structured
output, fallback, confirmation UX, evaluation, privacy-safe observability, and
post-release product learning without turning PitStop into an AI-first app.

---

# Current State (Repository Audit)

This section describes today's repository. It does not invent runtime behaviour.

Audit date context: pause before further PitStop implementation. Sources are `specs/` contracts plus the `main` implementation snapshot in `39_DOMAIN_INVENTORY.md`.

## AI-related specification owners

| Document | Owns |
|---|---|
| [`README.md`](README.md) | Product framing; Remember pipeline; intelligence boundary summary |
| [`01_PRODUCT_CHARTER.md`](01_PRODUCT_CHARTER.md) | Product jobs; progressive discovery; AI must not write persistence |
| [`02_DOMAIN_MODEL.md`](02_DOMAIN_MODEL.md) | Domain truth vs AI draft; Note context assignment limits |
| [`03_MAINTENANCE_ENGINE.md`](03_MAINTENANCE_ENGINE.md) | Deterministic maintenance; AI not required for engine truth |
| [`04_AI_ARCHITECTURE.md`](04_AI_ARCHITECTURE.md) | Runtime trust boundary; model roles; MemoryProposal; confirmation; Foundation Models fallbacks |
| [`06_OBSERVABILITY.md`](06_OBSERVABILITY.md) | `ai.interpreter` logging contract |
| [`12_LEARNING_LAB.md`](12_LEARNING_LAB.md) | Foundation Models study protocol and curriculum |
| [`13_TEST_STRATEGY.md`](13_TEST_STRATEGY.md) | AI evaluations; golden set; regression rule; CI lane separation |
| [`14_TELEMETRY_CONTRACT.md`](14_TELEMETRY_CONTRACT.md) | AI runtime observability vs product analytics; prohibited raw content |
| [`17_PRODUCT_DESIGN.md`](17_PRODUCT_DESIGN.md) | Product is not an AI chat wrapper |
| [`25_MODULAR_ARCHITECTURE.md`](25_MODULAR_ARCHITECTURE.md) | Domain must not import Foundation Models; target `FoundationModelsAdapter`; runtime vs AI Product Analyst separation |
| [`30_AI_PRODUCT_ANALYTICS.md`](30_AI_PRODUCT_ANALYTICS.md) | Separate AI-assisted analytics workflow (not app runtime interpretation) |
| [`33_PIT_BEHAVIOR_AND_MOTION_SPEC.md`](33_PIT_BEHAVIOR_AND_MOTION_SPEC.md) | Pit as product interaction layer, not the model |
| [`34_CAPTURE_PIPELINE_SPEC.md`](34_CAPTURE_PIPELINE_SPEC.md) | CaptureInput → proposal → validation → confirmation → domain commands |
| [`08_ROADMAP.md`](08_ROADMAP.md) / [`38_WORK_PLAN.md`](38_WORK_PLAN.md) | Phase index and CAP-* / DISC-* / SYS-* backlog |
| [`09_INVESTIGATIONS.md`](09_INVESTIGATIONS.md) | INV-CAP-* semantic risk; Foundation Models language quality |
| [`39_DOMAIN_INVENTORY.md`](39_DOMAIN_INVENTORY.md) | Authoritative inventory: capture/AI types not present on `main` |

Do not treat this roadmap as a second source of truth for topics already owned above. Extend the owner document when those topics change.

## Current AI boundaries

Documented trust boundary ([`04_AI_ARCHITECTURE.md`](04_AI_ARCHITECTURE.md), [`README.md`](README.md)):

> AI interprets human input. AI does not own product truth.

Runtime contract shape:

```text
CaptureInput
    ↓
Semantic Interpreter
    ↓
MemoryProposal
    ↓
Deterministic validation
    ↓
ConfirmationPolicy
    ↓
DomainCommand
    ↓
Domain mutation + persistence
```

Separate from runtime interpretation ([`04_AI_ARCHITECTURE.md`](04_AI_ARCHITECTURE.md), [`30_AI_PRODUCT_ANALYTICS.md`](30_AI_PRODUCT_ANALYTICS.md)):

```text
Analytics evidence
    ↓
AI-assisted interpretation
    ↓
Product hypothesis
```

These systems must not be merged.

**Code on `main` today:** no Semantic Interpreter, no MemoryProposal types, no ConfirmationPolicy, no Foundation Models adapter. See [`39_DOMAIN_INVENTORY.md`](39_DOMAIN_INVENTORY.md).

## Capture Pipeline

Owner: [`34_CAPTURE_PIPELINE_SPEC.md`](34_CAPTURE_PIPELINE_SPEC.md).

Contracted behaviour:

- Product verb is **Remember**.
- All sources produce one `CaptureInput` (Pit voice/text, direct capture, widget, Siri, App Shortcuts; later document recognition; CarPlay only if validated).
- Source does not choose the final domain entity.
- Screen context is priors, not hard constraints.
- Raw preservation on interpretation failure or AI unavailability.
- Only deterministic domain commands mutate state.

**Code on `main` today:** capture pipeline not started ([`39_DOMAIN_INVENTORY.md`](39_DOMAIN_INVENTORY.md)). Work-plan items CAP-001–CAP-007 remain tracked, not shipped ([`38_WORK_PLAN.md`](38_WORK_PLAN.md)).

## Remember capability

Owner product framing: [`README.md`](README.md), [`01_PRODUCT_CHARTER.md`](01_PRODUCT_CHARTER.md).

Remember is the core capture capability. Pit may open capture, show a proposal, ask one clarification, communicate completion, and ask progressive questions ([`04_AI_ARCHITECTURE.md`](04_AI_ARCHITECTURE.md), [`33_PIT_BEHAVIOR_AND_MOTION_SPEC.md`](33_PIT_BEHAVIOR_AND_MOTION_SPEC.md)).

Pit is not navigation, not a chat tab, not a generic AI assistant, and not required for the app to remain useful.

**Code on `main` today:** no Remember end-to-end path; Car Board is placeholder UI; Pit utility not wired ([`39_DOMAIN_INVENTORY.md`](39_DOMAIN_INVENTORY.md)).

## Intelligence abstraction

Documented in [`README.md`](README.md) and modular target notes in [`25_MODULAR_ARCHITECTURE.md`](25_MODULAR_ARCHITECTURE.md):

```text
Feature / Capture Pipeline
            ↓
   Intelligence abstraction
            ↓
  Apple on-device / PCC / external model provider
```

Documented constraints already present:

- Feature and domain code must not depend on a concrete vendor SDK or model family.
- Semantic contract above the boundary is typed product meaning (`MemoryProposal`), not provider chat text or tool-call payloads.
- Provider-specific orchestration (tool execution, multi-agent workflows) stays behind the intelligence boundary.
- Prefer the cheapest deterministic or single-model path that satisfies the product contract.
- Domain modules must not import Foundation Models ([`25_MODULAR_ARCHITECTURE.md`](25_MODULAR_ARCHITECTURE.md)).
- Apple Foundation Models may be a preferred local interpreter where available and validated; product must survive ineligible device, disabled Apple Intelligence, model unavailability, language quality failure, generation failure, and schema failure ([`04_AI_ARCHITECTURE.md`](04_AI_ARCHITECTURE.md)).
- Safe terminal fallback: preserve the raw capture.

**Code on `main` today:** no Intelligence abstraction type, no `FoundationModelsAdapter` package, no provider selection runtime.

## Deterministic domain ownership

Owners: [`02_DOMAIN_MODEL.md`](02_DOMAIN_MODEL.md), [`03_MAINTENANCE_ENGINE.md`](03_MAINTENANCE_ENGINE.md), [`34_CAPTURE_PIPELINE_SPEC.md`](34_CAPTURE_PIPELINE_SPEC.md).

Already decided:

- Deterministic domain code owns truth and mutation.
- AI draft is never final truth; it is a pending proposal.
- AI may assign Note contexts; it may not create free-form taxonomy as product truth ([`02_DOMAIN_MODEL.md`](02_DOMAIN_MODEL.md)).
- Maintenance engine truth does not require AI ([`03_MAINTENANCE_ENGINE.md`](03_MAINTENANCE_ENGINE.md)).
- Confirmation policy is deterministic and owned outside the model ([`04_AI_ARCHITECTURE.md`](04_AI_ARCHITECTURE.md), [`34_CAPTURE_PIPELINE_SPEC.md`](34_CAPTURE_PIPELINE_SPEC.md)).
- Progressive discovery: unknown vehicle facts remain unknown; do not fabricate mileage, age, fuel type, or service state ([`README.md`](README.md), [`01_PRODUCT_CHARTER.md`](01_PRODUCT_CHARTER.md)).

**Code on `main` today:** partial vehicle provisional context only (`ProvisionalCarContext`); maintenance engine, persistence, Notes/History/Service not started on `main` ([`39_DOMAIN_INVENTORY.md`](39_DOMAIN_INVENTORY.md)).

## Existing contracts (summary)

| Contract | Where documented | Implemented on `main` |
|---|---|---|
| App useful without AI / without Pit | [`README.md`](README.md), [`33_PIT_BEHAVIOR_AND_MOTION_SPEC.md`](33_PIT_BEHAVIOR_AND_MOTION_SPEC.md) | App shell only; AI not present |
| One Capture Pipeline for all sources | [`34_CAPTURE_PIPELINE_SPEC.md`](34_CAPTURE_PIPELINE_SPEC.md) | No |
| MemoryProposal typed, never persisted as truth | [`04_AI_ARCHITECTURE.md`](04_AI_ARCHITECTURE.md), [`34_CAPTURE_PIPELINE_SPEC.md`](34_CAPTURE_PIPELINE_SPEC.md) | No |
| Risk-based ConfirmationPolicy | [`04_AI_ARCHITECTURE.md`](04_AI_ARCHITECTURE.md), [`34_CAPTURE_PIPELINE_SPEC.md`](34_CAPTURE_PIPELINE_SPEC.md) | No |
| Domain commands own mutation | [`34_CAPTURE_PIPELINE_SPEC.md`](34_CAPTURE_PIPELINE_SPEC.md) | No |
| Intelligence / provider abstraction | [`README.md`](README.md) | No |
| Foundation Models preferred local path + raw fallback | [`04_AI_ARCHITECTURE.md`](04_AI_ARCHITECTURE.md) | No |
| AI golden set / evaluations separate from domain tests | [`13_TEST_STRATEGY.md`](13_TEST_STRATEGY.md) | Spec only |
| AI runtime observability separate; P0 does not auto-enable product AI observability | [`14_TELEMETRY_CONTRACT.md`](14_TELEMETRY_CONTRACT.md) | Spec only |
| AI Product Analyst is a development workflow, not iOS runtime | [`30_AI_PRODUCT_ANALYTICS.md`](30_AI_PRODUCT_ANALYTICS.md), [`25_MODULAR_ARCHITECTURE.md`](25_MODULAR_ARCHITECTURE.md) | Spec / staged hypothesis |
| MCP not part of iOS app architecture | [`30_AI_PRODUCT_ANALYTICS.md`](30_AI_PRODUCT_ANALYTICS.md) | Explicit non-goal for P0 app |

## Assumptions present in the repository

These are documented assumptions or open decisions, not completed runtime facts:

- Fallback provider order beyond raw preservation is still a product/architecture decision to validate ([`04_AI_ARCHITECTURE.md`](04_AI_ARCHITECTURE.md)).
- Foundation Models Russian / automotive language quality is an investigation (`INV-CAP-005` in [`09_INVESTIGATIONS.md`](09_INVESTIGATIONS.md)); work-plan spike `CAP-005` is tracked, not done.
- Acceptable semantic false-classification rates by mutation class remain open (`INV-CAP-001`).
- Which mutations may auto-accept remains open (`INV-CAP-002`).
- Initial MemoryProposal kinds should be limited to validated product-core kinds; unsupported meaning degrades to raw ([`34_CAPTURE_PIPELINE_SPEC.md`](34_CAPTURE_PIPELINE_SPEC.md), [`39_DOMAIN_INVENTORY.md`](39_DOMAIN_INVENTORY.md)).
- Modular `FoundationModelsAdapter` is a target direction, not a creation backlog ([`25_MODULAR_ARCHITECTURE.md`](25_MODULAR_ARCHITECTURE.md)).
- PostHog / AI Product Analyst staging is independent of Remember runtime ([`30_AI_PRODUCT_ANALYTICS.md`](30_AI_PRODUCT_ANALYTICS.md)).

## Deferred topics already recorded

Deferred or postponed in existing specs / roadmap (not invented here):

- Progressive discovery implementation (Phase 5 deferred in [`08_ROADMAP.md`](08_ROADMAP.md))
- System capture (Phase 6 deferred in [`08_ROADMAP.md`](08_ROADMAP.md))
- Maintenance intelligence (Phase 7 deferred in [`08_ROADMAP.md`](08_ROADMAP.md))
- Document extraction assistant; planned-vs-actual reconciliation assistant ([`04_AI_ARCHITECTURE.md`](04_AI_ARCHITECTURE.md) “Later”)
- Tool calling and adapters in Foundation Models curriculum ([`12_LEARNING_LAB.md`](12_LEARNING_LAB.md))
- Dedicated AI observability product ([`14_TELEMETRY_CONTRACT.md`](14_TELEMETRY_CONTRACT.md))
- MCP inside iOS runtime; custom MCP server; autonomous analytics agents ([`30_AI_PRODUCT_ANALYTICS.md`](30_AI_PRODUCT_ANALYTICS.md))
- Multi-agent / provider orchestration complexity until a concrete product flow requires it ([`README.md`](README.md))
- CarPlay capture unless validated ([`34_CAPTURE_PIPELINE_SPEC.md`](34_CAPTURE_PIPELINE_SPEC.md))

## Implementation snapshot (honest)

| Area | Spec status | Code on `main` |
|---|---|---|
| AI architecture contracts | Present (`04`, `34`, README) | Intentionally not implemented yet |
| Capture / Remember | Spec + CAP-* issues | Deferred until after product baseline |
| Intelligence abstraction | Spec boundary | Intentionally deferred |
| Foundation Models | Preferred path + learning lab | Intentionally deferred |
| Persistence schema | Domain concepts in `02` / `39` | Intentionally deferred to ENG-004 |
| Evaluation / golden set | Spec (`13`) | Dataset deferred until interpreter exists |
| AI Product Analytics | Separate staged workflow (`30`) | Not app runtime |
| Product baseline (Car Board / domain) | Contracts + inventory | Provisional car + placeholder Car Board only |

Resume AI implementation only after the product baseline is stable, and only by extending the owning specs plus measurable evaluation artifacts.

---

# Future Architecture

The following is intentional long-term direction. It must not be read as current runtime behaviour.

AI is not a product.

AI is infrastructure that helps the product understand user intent.

The deterministic domain remains the source of truth.

## Product principle

PitStop remembers the car with the driver.

AI helps understand what the driver means.

AI never owns product truth.

## Core architecture

Canonical pipeline ownership remains [`34_CAPTURE_PIPELINE_SPEC.md`](34_CAPTURE_PIPELINE_SPEC.md) and [`04_AI_ARCHITECTURE.md`](04_AI_ARCHITECTURE.md):

```text
CaptureInput
        │
        ▼
Semantic Interpreter
        │
        ▼
Memory Proposal
        │
        ▼
Validation
        │
        ▼
Confirmation Policy
        │
        ▼
Domain Mutation
        │
        ▼
SwiftData
```

Only deterministic code mutates domain state.

## Intelligence boundary

```text
Feature
    │
    ▼
Intelligence Service
    │
    ▼
Foundation Models
Private Cloud Compute
Claude
OpenAI
Gemini
Future providers
```

Business logic must never depend on a provider SDK.

Only the intelligence boundary knows providers.

Existing summary: [`README.md`](README.md) Intelligence boundary. Existing modular non-import rule: [`25_MODULAR_ARCHITECTURE.md`](25_MODULAR_ARCHITECTURE.md).

## AI responsibilities

AI MAY

- understand natural language
- classify intent
- extract entities
- summarize
- answer questions
- generate MemoryProposal

AI MUST NOT

- write SwiftData directly
- bypass validation
- execute domain mutations
- invent vehicle facts
- ignore confirmation policy

Detailed runtime roles and prohibitions: [`04_AI_ARCHITECTURE.md`](04_AI_ARCHITECTURE.md).

## Memory Proposal

AI returns structured meaning.

Conceptual fields for future engineering:

- intent
- confidence
- entities
- reasoning (optional)
- clarification request (optional)

No chat text should become product state.

Proposal kinds, validation requirements, and command mapping remain owned by [`04_AI_ARCHITECTURE.md`](04_AI_ARCHITECTURE.md), [`34_CAPTURE_PIPELINE_SPEC.md`](34_CAPTURE_PIPELINE_SPEC.md), and [`39_DOMAIN_INVENTORY.md`](39_DOMAIN_INVENTORY.md).

## Evaluation framework

Every AI change must be measurable.

Existing seed: [`13_TEST_STRATEGY.md`](13_TEST_STRATEGY.md) (AI evaluations, golden set, regression rule, separate CI lane).

### Golden Dataset

Representative real-world inputs.

Each sample contains

- user input
- expected proposal
- expected intent
- expected slots

### Regression Suite

Run after

- prompt changes
- provider changes
- framework updates

Measure

- parse accuracy
- intent accuracy
- slot accuracy
- clarification rate
- hallucination rate
- unsafe mutation rate

### Failure Corpus

Every production failure becomes a test.

No bug is fixed only in prompts.

Every fix extends the dataset.

### Provider Comparison

Support benchmarking

- Apple Foundation Models
- PCC
- Claude
- OpenAI
- Gemini

Compare

- latency
- quality
- cost
- energy
- privacy

## Agent engineering

AI should work like a junior engineer.

It proposes.

The system verifies.

The deterministic domain accepts or rejects.

Pattern

```text
AI proposes
    ↓
Validator
    ↓
Confirmation
    ↓
Domain
```

Never

```text
AI
    ↓
SwiftData
```

## Long-term direction

| Phase | Direction | Notes |
|---|---|---|
| 1 | Foundation Models | Aligns with preferred local path in `04`; learning lab in `12`; CAP-005 spike in work plan |
| 2 | Structured Output | Aligns with typed MemoryProposal / guided generation |
| 3 | Tool Calling | Curriculum stage in `12`; keep behind intelligence boundary |
| 4 | Evaluation Framework | Extends `13` golden set and regression rules |
| 5 | Provider Abstraction | Extends README intelligence boundary |
| 6 | Dynamic Profiles | Future; not present as a current runtime contract |
| 7 | Multi-provider Runtime | Future; prefer single-model path until needed |

Agents are intentionally postponed.

Executable product backlog for Remember remains CAP-* in [`38_WORK_PLAN.md`](38_WORK_PLAN.md), not this phase list.

## Non goals

No autonomous agent.

No background planner.

No self-modifying prompts.

No AI-owned business rules.

No AI-first architecture.

Product first.

AI second.

Related non-goals already owned by [`30_AI_PRODUCT_ANALYTICS.md`](30_AI_PRODUCT_ANALYTICS.md) for analytics workflows.

## Future research (deferred)

Interesting topics intentionally outside current architecture:

- Multi-agent workflows
- Autonomous planning
- Long-term memory
- MCP integration
- Cloud orchestration
- Self-improving prompts
- Reinforcement learning
- Fine-tuning
- Vision understanding
- Image generation
- Voice conversation
- Federated learning

MCP remains a possible development-tool concern only; not iOS runtime ([`30_AI_PRODUCT_ANALYTICS.md`](30_AI_PRODUCT_ANALYTICS.md)).

## Engineering invariants

The application must remain useful without AI.

Unknown facts remain unknown.

Deterministic code owns truth.

Every mutation is explainable.

Every AI decision is measurable.

Every provider is replaceable.

Architecture outlives model releases.

## Design philosophy

PitStop is not an AI application.

PitStop is a product that uses AI where AI creates measurable value.

Whenever deterministic software solves a problem better than AI,
prefer deterministic software.

Whenever AI is used,
keep it behind explicit boundaries,
measure its quality,
and never allow it to become the source of product truth.

The architecture should survive future model releases.
Model vendors will change.

The product architecture should not.

---

# Architecture Stability

The following decisions are stable architectural direction for AI work.

They may evolve, but only after an explicit architecture review.

They do **not** replace the authoritative owners listed at the top of this document.

## Stable

### Product before AI

AI is an implementation detail.

The product must remain valuable without AI.

### Deterministic domain

The domain owns truth.

AI never owns truth.

### Memory Proposal

AI produces structured meaning.

The domain decides whether it becomes product state.

### Provider abstraction

Features never know which model is used.

Providers are replaceable.

### Validation before mutation

Every mutation passes deterministic validation.

No provider may bypass validation.

### Progressive discovery

Unknown vehicle facts remain unknown.

AI must never fabricate facts.

### Explainability

Every accepted proposal must be explainable.

The user should understand why Pit suggests something.

### Measurable quality

Every AI improvement must be measurable.

No prompt change ships without evaluation.

### Human confirmation

AI suggests.

The user confirms.

The system executes.

(Confirmation cost remains risk-based per [`04_AI_ARCHITECTURE.md`](04_AI_ARCHITECTURE.md) and [`34_CAPTURE_PIPELINE_SPEC.md`](34_CAPTURE_PIPELINE_SPEC.md); do not require a large form merely because AI was involved.)

## Related documents

- [`04_AI_ARCHITECTURE.md`](04_AI_ARCHITECTURE.md) — runtime AI architecture owner
- [`34_CAPTURE_PIPELINE_SPEC.md`](34_CAPTURE_PIPELINE_SPEC.md) — Capture / Remember pipeline owner
- [`13_TEST_STRATEGY.md`](13_TEST_STRATEGY.md) — evaluation / golden-set owner
- [`30_AI_PRODUCT_ANALYTICS.md`](30_AI_PRODUCT_ANALYTICS.md) — AI Product Analyst workflow owner
- [`39_DOMAIN_INVENTORY.md`](39_DOMAIN_INVENTORY.md) — implementation inventory owner
- [`38_WORK_PLAN.md`](38_WORK_PLAN.md) — executable CAP-* backlog owner
- [`41_PRODUCT_DECISIONS_AND_DESIGN_RATIONALE.md`](41_PRODUCT_DECISIONS_AND_DESIGN_RATIONALE.md) — product why / rejected alternatives

---

# Project Freeze

Canonical freeze rules live in [`../PROJECT_STATUS.md`](../PROJECT_STATUS.md).

Summary: documentation and architecture clarification only. No runtime AI, provider integration, prompt engineering, evaluation implementation, or feature work.

Implementation resumes only after the product baseline becomes active again.

Do not resume AI implementation first.
Complete the product baseline before any AI work.
