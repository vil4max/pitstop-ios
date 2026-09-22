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
| As-built overview — diagrams of the delivered system | [engineering/system-overview.md](engineering/system-overview.md) |
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
- `decisions/0029-app-icon-pit-eyes.md` — ICON-001: Liquid Glass app icon from Pit's resting eyes in one Icon Composer document (`Pitstop/AppIcon.icon`), appiconset removed, dark fill specialization key shape, six appearances, how to edit
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
- `decisions/0020-maintenance-anchor-closure.md` — ADR 0001 open questions: evidence, fixed grid deferred, stable IDs pinned, owner questions on data and plan scope
- `requirements/capture-pipeline.md`
- `engineering/domain-inventory.md`

## AI

- `engineering/ai-architecture.md` — runtime AI architecture owner
- `operations/ai-product-analytics.md` — AI Product Analyst workflow (not app runtime)
- `planning/ai-roadmap.md` — deferred AI roadmap (not an implementation contract)

## Engineering, tests, observability and quality

- [`engineering/system-overview.md`](engineering/system-overview.md) — as-built system overview with Mermaid diagrams: context, layers, capture pipeline, entry points, Pit states and questions, data model, projections, delivery, feature matrix
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
- `decisions/0013-shared-ci-and-tag-gated-testflight.md` — shared CI, tag-gated TestFlight, tag authority
- `decisions/0014-public-repository.md` — public visibility, hosted runners, history rewrite
- `decisions/0015-interpretation-deadline-and-cancellation.md` — interpreter deadline, cancelled captures write nothing
- `decisions/0016-question-registry.md` — Pit question registry, value and deferral declarations, persisted question state, schema V2
- `decisions/0017-first-question-current-mileage.md` — first Pit question: current mileage when stale or unknown, relevance gate, answer through `recordOdometerReading`
- `decisions/0018-attention-cooldown-and-return.md` — declared return after answer, deferral, and dismissal; answers hold for their interval, relevance decides after it; asking reopens a question
- `decisions/0019-pit-activity-reporting.md` — surfaces report scrolling, editing, and editor sheets to Pit as a union of per-source reports; motion audit of `PitState` against accepted behaviour
- `decisions/0028-pit-eyes-and-motion.md` — PIT-MOTION-001: livelier Pit eyes (lids, highlight parallax, springs, micro-saccades, sheet-only breathing) and every motion-language state wired: double blink, listening blinks, post-input transition, glance and closed eyes after a save, closed eyes on leaving, knock bumps; Reduce Motion mapping; glance outside the sheet deferred
- `decisions/0011-interpreted-capture-without-a-model.md` — interpreter protocol, rule-based stand-in, confirmation and clarification flow
- `decisions/0006-capture-confirmation-policy.md` — confirmation outcome table and mutation permit
- `decisions/0023-remember-intent.md` — `RememberInPitStopIntent`: app-target background intent, in-place `requestChoice` confirmation, unlocked phone only, source `.siri`, temporary storage refused, no retry draft
- `decisions/0024-app-shortcuts.md` — App Shortcuts: Remember (Siri asks for the words) and Open Pit (foreground intent routed to the Pit sheet through an injected request object); en, ru and uk phrases pending owner review
- `decisions/0025-widgets-and-controls.md` — `PitstopWidgets` extension: Open Pit control and data-free small/circular widget, `OpenPitIntent` as `OpenIntent` in a `Shared/` folder, `pitstop://pit` as the only URL, no App Group
- `decisions/0026-siri-voice-clarification.md` — Siri asks the one missing field by voice (number prompt or catalog choice, one repeat, "I don't know" keeps the words), voice-only replies name PitStop, no `LongRunningIntent`, owner device check list
- `decisions/0030-capture-locale.md` — CAP-LOC-001: in-app captures carry `Locale.current` read per capture, injected from `AppEnvironment`; no `ru_RU` default; the locale is a model hint, never the language gate
- `decisions/0031-stop-tracking-an-operation.md` — MNT-POL-001: user-only `stopTrackingOperation` command removes the owner's `userCustom` policy; completions, History and recommendations stay; confirmation names the operation; no undo action, no schema change
- `decisions/0032-planned-dated-events.md` — ROAD-EVT-001: owner-stated planned dates (insurance expiry, or `other` with an optional 40-character label) entered and corrected on Road; three user-only commands; one insurance expiry on Road per car; schema V3 by a lightweight stage, V2 frozen; insurance shows on Road only
- `decisions/0033-track-several-starter.md` — MNT-PRE-001: "Track several" on Service; the owner picks untracked operations, enters every interval (unselected quick picks 5,000/7,500/10,000/15,000 km and 6/12/24 months, labelled as common choices), confirms one summary; items saved one at a time as `userCustom` with per-item result and retry of failed items; gearbox and drive answers only reorder and are never stored
- `decisions/0027-foundation-models-interpreter.md` — CAP-005 spike: Foundation Models adapter behind `SemanticInterpreting` with deterministic post-model guards, rules-first `InterpreterChain`, off by default (DEBUG launch argument only), golden set and evaluation lane; Russian and Ukrainian unsupported by Apple Intelligence on iOS 27, model quality not measured
- `decisions/0005-toolchain-and-project-format.md` — Swift 6, iOS 27, file-system-synchronized project

## Analytics and beta

- `operations/analytics.md`
- `operations/release-and-beta.md`
- `decisions/0002-analytics-service.md`
- `decisions/0021-analytics-boundary.md` — provider-neutral analytics boundary, closed event values, consent off by default, first wired events
- `decisions/0022-posthog-http-adapter.md` — PostHog adapter over HTTP without the SDK, in-memory batching and retry, anonymous consent-scoped ID, Settings opt-in, key supplied outside the repository
- `operations/analytics-questions.md`
- `operations/ai-product-analytics.md`

## Planning and execution

- `planning/roadmap.md`
- `planning/work-plan.md` — open work and owner decisions only
- `planning/investigations.md`
- `planning/investigations/mnt-int-001-maintenance-intelligence.md` — manufacturer data, presets, richer Road milestones: sources, licences, recommendation
- `planning/investigations/sys-001-app-intents.md` — App Intents for Remember through Siri: API facts, design, owner questions
- `planning/investigations/sys-004-widgets.md` — widgets and controls for fast capture; cost of a data widget (SYS-007)
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
