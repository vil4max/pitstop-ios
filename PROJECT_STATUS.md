# PitStop — Project Status

**Project State:** Active — product baseline implementation
**Unfrozen (2026-09-16):** the owner unfroze product feature implementation.
Work follows the spec pyramid ([`docs/core.md`](docs/core.md)) and the agent
development loop (`docs/engineering/agent-loop-and-gitflow.md`). Runtime AI
stays deferred by core priority P4 and the ordering constraint below.

---

# Product loop

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
- Implementation Active
- Product Baseline Pending
- AI Deferred

---

## Work rules

Allowed:

- documentation
- architecture clarification
- terminology cleanup
- specification refactoring
- product baseline feature implementation (domain, persistence, Car Board, Road) and its verification tooling

Not allowed until the product baseline (M3) is complete:

- runtime AI
- provider integration
- prompt engineering
- evaluation implementation

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
this distinction does not move tasks earlier.

Next task: CB-005; CB-001…004 are implemented; INV-ROAD is decided in ADR 0008; DOM-003 and ENG-004 are implemented on unmerged branches (see [`docs/planning/work-plan.md`](docs/planning/work-plan.md)).

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
