# PitStop — Project Status

**Project State:** Active — product baseline delivered; open work in the work plan  
**Next task:** MNT-INT-002 — Recommendation provenance fixture, waiting for an owner decision ([`docs/planning/work-plan.md`](docs/planning/work-plan.md))  
**Repository:** public `vil4max/pitstop-ios` with rewritten history (ADR 0014)  
**TestFlight:** version 1.1.0 (tag `tf-1.1.0-2`); delivery is tag-gated (ADR 0013)

Work follows the spec pyramid ([`docs/core.md`](docs/core.md)) and the agent
development loop ([`docs/engineering/agent-loop-and-gitflow.md`](docs/engineering/agent-loop-and-gitflow.md)).
The owner assigns tasks. Agent entry: tracked root `AGENTS.md`; the local
project marker is gitignored.

---

## Product loop

1. **Design** — owner-formulated problem / MVP ([`docs/core.md`](docs/core.md), [`docs/requirements/product-charter.md`](docs/requirements/product-charter.md)).
2. **Develop** — agent-assisted delivery with human review.
3. **Deploy** — ship a usable build (TestFlight / App Store as applicable).
4. **Maintain** — post-ship iteration with metrics and user feedback.

---

## Where the project is

- Every card of the original backlog (DOM, ENG, INV-ROAD, CB, CAP, DISC, SYS
  through SYS-006, ANL, MNT-INT-001) is delivered on `main`. The GitHub board
  was deleted; the work plan lists only open work, and ADRs plus `git log`
  record what was delivered.
- MNT-VR-002, the car's dashboard service reading as a maintenance anchor, is
  delivered with schema V4 (ADR 0035).
- Remaining work: two planned tasks (MNT-INT-002 and SYS-007), the iOS 27
  redesign cards, owner-only device checks, and owner decisions. All are in
  [`docs/planning/work-plan.md`](docs/planning/work-plan.md).
- Requirements: 166 REQ IDs are `Status: proposed`; REQ-BOARD-026 and REQ-ICON-001
  are approved. Tests cite the proposed IDs.

## Current implementation status

Source of truth for what exists on `main`:
[`docs/engineering/domain-inventory.md`](docs/engineering/domain-inventory.md).

| Area | Status on `main` |
|---|---|
| Product contracts / specs | Present under `docs/` (see `docs/README.md`) |
| Car context | Persisted provisional car, optional name and mileage edit |
| Car Board | Design language, four live tiles, utility layer (ADR 0009) |
| Persistence | SwiftData behind a command-only store, schema V4; V1 to V3 frozen (ADR 0007, 0016, 0032, 0035) |
| Notes | Save, find, correct, archive without AI |
| History | Record and correct events; timeline of events and confirmed completions |
| Service | Deterministic engine, visit planner, track / track several / mark done / change interval / undo / stop tracking; the car's dashboard reading as an anchor, entered on Service or through Pit (ADR 0010, 0031, 0033, 0035) |
| Road | Deterministic projection, tile and screen; owner-stated planned dates, insurance expiry first, added and corrected on Road; labelled date estimate; "from dashboard" when a reading decided (ADR 0008, 0032, 0034, 0035) |
| Remember / Pit | Raw and rule-based interpreted capture end to end, confirmation, deadline, current-mileage question (ADR 0006, 0011, 0015–0019) |
| System capture | Siri intent, App Shortcuts, voice clarification, Open Pit control and data-free widget (ADR 0023–0026) |
| Analytics | Provider-neutral boundary and PostHog HTTP adapter, consent off by default, no project key (ADR 0021, 0022) |
| Runtime AI | Foundation Models interpreter behind a DEBUG launch argument only; off in Release (ADR 0027) |

## Work rules

- Core priority P4 ([`docs/core.md`](docs/core.md)) gates runtime AI on this
  file: no runtime AI in Release builds until the owner decides the ADR 0027
  rollout gate and beta evidence validates the core (INV-PROD-001).
- Product features start with Product Review
  ([`docs/engineering/product-review-process.md`](docs/engineering/product-review-process.md)).
- Local `just verify` is the implementation gate; documentation-only changes
  use proportional checks.

---

## Resume checklist

1. [`PROJECT_STATUS.md`](PROJECT_STATUS.md) (this file)
2. [`docs/planning/work-plan.md`](docs/planning/work-plan.md)
3. [`docs/requirements/product-overview.md`](docs/requirements/product-overview.md)
4. [`docs/requirements/product-charter.md`](docs/requirements/product-charter.md)
5. [`docs/engineering/domain-inventory.md`](docs/engineering/domain-inventory.md)
6. [`docs/decisions/0004-product-design-rationale.md`](docs/decisions/0004-product-design-rationale.md)

Then open behavioural owners as needed:

- Capture: `docs/requirements/capture-pipeline.md`
- AI runtime: `docs/engineering/ai-architecture.md`, `docs/planning/ai-roadmap.md`
- Car Board / Road / Pit: `car-board-screen`, `road-domain-and-ui`, `pit-behavior-and-motion`
- Full map: `docs/README.md`

---

## Ownership reminder

| Document | Answers |
|---|---|
| Root `README.md` | Repository entry point |
| `PROJECT_STATUS.md` | Current project state and the runtime AI gate |
| `docs/requirements/product-charter.md` | Product contract (what) |
| `docs/engineering/ai-architecture.md` | Runtime AI contract |
| `docs/requirements/capture-pipeline.md` | Capture / Remember contract |
| `docs/engineering/domain-inventory.md` | Implementation snapshot |
| `docs/planning/ai-roadmap.md` | Deferred AI direction |
| `docs/decisions/0004-product-design-rationale.md` | Architectural / product reasoning (why) |
| `docs/planning/work-plan.md` | Open work and owner decisions |

Do not create parallel sources of truth. Cross-reference owners instead of duplicating them.
