# PitStop Documentation Index

Spec pyramid: each layer details the one above it. Change starts at the
highest affected layer; evidence from operations flows back up.

| Layer | Source |
|---|---|
| L0 core — goal, language, priorities, constraints | [core.md](core.md) (approved) |
| L1 requirements — behaviour contracts | [requirements/](requirements/) |
| L1 decisions — ADRs and design rationale | [decisions/](decisions/) |
| L2 specs — tests named with `REQ-<AREA>-NNN` | `PitstopTests/` |
| Engineering — architecture, standards, agent loop, product review gate | [engineering/](engineering/) |
| Operations — observability, telemetry, analytics, beta | [operations/](operations/) |
| Tasks — task template and briefs | [tasks/](tasks/) |
| Planning — roadmap, work plan, investigations (not requirements) | [planning/](planning/) |
| Lessons — failures that changed a check | [lessons.md](lessons.md) |

## Start here

1. `../PROJECT_STATUS.md` (status — read when resuming)
2. `core.md`
3. `requirements/product-overview.md`
4. `requirements/product-charter.md`
5. `engineering/product-review-process.md` (mandatory idea validation before new features)
6. `decisions/0004-product-design-rationale.md`
7. `engineering/domain-inventory.md`
8. `planning/work-plan.md`

## Product, UX and IA

- `requirements/product-charter.md`
- `engineering/product-review-process.md` — mandatory Idea Validation & Product Review before new features
- `requirements/product-design.md`
- `engineering/design-system-module.md`
- `requirements/app-icon.md`
- `requirements/car-board-screen.md`
- `requirements/road-domain-and-ui.md`
- `requirements/pit-behavior-and-motion.md`
- `requirements/bottom-utility-layer.md`
- `requirements/screen-grammar.md`
- `decisions/0004-product-design-rationale.md` — product why / rejected alternatives (not a behaviour contract)

## Domain

- `requirements/domain-model.md`
- `requirements/maintenance-engine.md`
- `decisions/0001-maintenance-anchors.md`
- `decisions/0010-maintenance-engine-rules.md` — status rule, unknown handling, planner window, Service surface scope
- `planning/legacy-domain-audit.md`
- `requirements/capture-pipeline.md`
- `engineering/domain-inventory.md`

## AI

- `engineering/ai-architecture.md` — runtime AI architecture owner
- `operations/ai-product-analytics.md` — AI Product Analyst workflow (not app runtime)
- `planning/ai-roadmap.md` — deferred AI roadmap (not an implementation contract)

## Engineering, tests, observability and quality

- `engineering/engineering-standard.md`
- `operations/observability.md`
- `engineering/test-strategy.md`
- `operations/telemetry-contract.md`
- `decisions/0003-logging.md`
- `engineering/quality-and-ci.md`
- `engineering/modular-architecture.md`
- `decisions/0009-design-language.md` — surfaces vs glass controls, colour roles, hero fallback, tile layout, utility layer
- `decisions/0008-road-projection-rules.md` — INV-ROAD-001…004 outcomes: horizon, mixed dimensions, clustering, return to now
- `decisions/0007-persistence.md` — SwiftData behind a command-only store, schema rules
- `decisions/0012-pit-presence-and-attention.md` — Pit motion vocabulary, idle drawing, interruption budget
- `decisions/0011-interpreted-capture-without-a-model.md` — interpreter protocol, rule-based stand-in, confirmation and clarification flow
- `decisions/0006-capture-confirmation-policy.md` — confirmation outcome table and mutation permit
- `decisions/0005-toolchain-and-project-format.md` — Swift 6, iOS 27, file-system-synchronized project

## Analytics and beta

- `operations/analytics.md`
- `operations/release-and-beta.md`
- `decisions/0002-analytics-service.md`
- `operations/analytics-questions.md`
- `operations/ai-product-analytics.md`

## Planning and execution

- `planning/roadmap.md`
- `planning/work-plan.md`
- `planning/investigations.md`
- `tasks/template.md`
- `engineering/agent-loop-and-gitflow.md`
- `engineering/product-review-process.md` — gate before feature implementation

## Product hierarchy

```text
PitStop
└── Car Board
    ├── Road
    ├── Notes
    ├── Service
    ├── History
    └── Car context

Persistent utility layer
├── Settings
└── Pit

Capture capability
└── Remember
    └── Capture Pipeline
```

## Documentation rule

Do not create a second specification for an already-owned concept without first deciding whether the existing owner should be extended. Avoid parallel source-of-truth documents.

The consolidated brainstorm was migration input, not a permanent competing specification. Its accepted decisions have been integrated into the authoritative documents in this folder.
