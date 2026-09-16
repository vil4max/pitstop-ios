# PitStop — Project Status

**Project State:** Active — Agent SDLC learning phase
**Reason:** Understanding and building the agent-assisted development loop
(see `docs/engineering/agent-loop-and-gitflow.md`, "Agent development loop")
**Note (2026-09-16):** Previously recorded as "Frozen"; corrected per owner.
The freeze rules below (feature implementation, runtime AI, deployment) still stand until
the owner separately unfreezes them — this correction only fixes the
active/frozen state declaration, it does not by itself authorize product
feature work.

**2026-09-13 infrastructure exception:** the owner authorized the PitStop
agent development loop setup: project Entry, deterministic verification tooling,
CI configuration, independent review, and checks of the existing app baseline.
Product feature implementation remains paused. This exception does not start
DOM-002 or authorize runtime AI or deployment.

---

# Product loop after unfreeze

1. **Design** — owner-formulated problem / MVP ([`docs/core.md`](docs/core.md), [`docs/requirements/product-charter.md`](docs/requirements/product-charter.md)).
2. **Develop** — agent-assisted delivery with human review.
3. **Deploy** — ship a usable build (TestFlight / App Store as applicable).
4. **Maintain** — post-ship iteration with metrics and user feedback.

**Ordering constraint (unchanged):** complete the product baseline through M3 before runtime AI features (Foundation Models / interpreted Remember). All CAP-* delivery, including raw saving without a model, remains scheduled for M4. Agent-assisted coding during baseline work is a workflow choice, not early AI product scope.

Agent entry: tracked root `AGENTS.md`; local project marker is gitignored.

---

# Project Phase

- Architecture Complete
- Documentation Stable
- Implementation Paused
- Product Baseline Pending
- AI Deferred

---

## Freeze rules

Allowed:

- documentation
- architecture clarification
- terminology cleanup
- specification refactoring
- the bounded infrastructure setup and existing-baseline checks authorized above

Not allowed:

- runtime AI
- provider integration
- prompt engineering
- evaluation implementation
- feature implementation

---

## Product baseline (resume definition)

“Complete the product baseline before AI” means establish the domain and screen foundation on `main` through **M3** in [`docs/planning/work-plan.md`](docs/planning/work-plan.md):

- domain fixtures and capture-boundary tests (DOM-*)
- persistence for provisional car context (ENG-004)
- Car Board tiles wired to real domain projections
- Road projection and UI

M3 is a foundation checkpoint, not completion of the save-and-retrieve product
loop. Tile completion alone does not prove Notes, History, or Service readiness;
the work plan records the distinction.

**Remember / Capture delivery (M4, CAP-*) stays deferred until M3.** Remember
includes useful raw saving without AI as well as optional interpreted capture;
this distinction does not move tasks earlier or change the freeze.

Open after unfreeze: DOM-002.

---

## Current implementation status

Source of truth for what exists on `main`: [`docs/engineering/domain-inventory.md`](docs/engineering/domain-inventory.md).

| Area | Status on `main` |
|---|---|
| Product contracts / specs | Present and authoritative under `docs/` (see `docs/README.md`) |
| Provisional car context | Partial (`ProvisionalCarContext`) |
| Car Board | Placeholder UI |
| Capture / Remember pipeline | Not started (intentional; after product baseline) |
| Intelligence / AI runtime | Not started (intentionally deferred) |
| Maintenance engine | Not on `main` (legacy on `legacy/spike` only) |
| Persistence | Intentionally deferred to ENG-004 |
| Notes / Service / History / Road | Not started (product baseline work) |

AI and Remember are specified, not implemented. Product baseline remains higher priority than AI.

---

# Resume Checklist

Recommended order:

1. [`PROJECT_STATUS.md`](PROJECT_STATUS.md) (this file)
2. [`docs/requirements/product-overview.md`](docs/requirements/product-overview.md)
3. [`docs/requirements/product-charter.md`](docs/requirements/product-charter.md)
4. [`docs/engineering/domain-inventory.md`](docs/engineering/domain-inventory.md)
5. [`docs/decisions/0004-product-design-rationale.md`](docs/decisions/0004-product-design-rationale.md)
6. [`docs/planning/ai-roadmap.md`](docs/planning/ai-roadmap.md)

Then open behavioural owners as needed:

- Capture: `docs/requirements/capture-pipeline.md`
- AI runtime: `docs/engineering/ai-architecture.md`
- Car Board / Road / Pit: `car-board-screen`, `road-domain-and-ui`, `pit-behavior-and-motion`
- Work plan: `docs/planning/work-plan.md`
- Full map: `docs/README.md`

Do not resume AI implementation first.

Complete the product baseline before any AI work.

---

## Ownership reminder

| Document | Answers |
|---|---|
| Root `README.md` | Repository entry point |
| `PROJECT_STATUS.md` | Current project state / freeze / resume |
| `docs/requirements/product-charter.md` | Product contract (what) |
| `docs/engineering/ai-architecture.md` | Runtime AI contract |
| `docs/requirements/capture-pipeline.md` | Capture / Remember contract |
| `docs/engineering/domain-inventory.md` | Implementation snapshot |
| `docs/planning/ai-roadmap.md` | Deferred AI direction |
| `docs/decisions/0004-product-design-rationale.md` | Architectural / product reasoning (why) |
| `docs/planning/work-plan.md` | Executable backlog |

Do not create parallel sources of truth. Cross-reference owners instead of duplicating them.

---

## Resume rule

Do not resume AI implementation first.

Complete the product baseline before any AI work.
