# PitStop — Project Status

**Project State:** Active — Agent SDLC learning phase
**Reason:** Understanding and building the agent-assisted development loop
(see `specs/24_PROJECT_MANAGEMENT_AND_GITFLOW.md`, "Agent development loop")
**Note (2026-09-16):** Previously recorded as "Frozen" (personal/interview
priority); corrected per owner. The freeze rules below (feature
implementation, runtime AI, deployment, personal publication) still stand until
the owner separately unfreezes them — this correction only fixes the
active/frozen state declaration, it does not by itself authorize product
feature work.

**2026-09-13 infrastructure exception:** the owner authorized the PitStop
agent development loop setup: project Entry, deterministic verification tooling,
CI configuration, independent review, and checks of the existing app baseline.
Product feature implementation remains paused. This exception does not start
DOM-002 or authorize runtime AI, deployment, or personal publication.

---

# reference product loop

**Role:** this repository is the reference product for the private target:

> AI-assisted Product Engineer able to design, develop, deploy, and maintain a modern product.

**Loop to complete after unfreeze (one product, not three pets):**

1. **Design** — owner-formulated problem / MVP (charter: [`specs/01_PRODUCT_CHARTER.md`](specs/01_PRODUCT_CHARTER.md)).
2. **Develop** — AI-assisted delivery with human review (agents as engineering workflow).
3. **Deploy** — ship a usable build (TestFlight / App Store as applicable).
4. **Maintain** — 1–2 months of post-ship iteration with metrics and user feedback.

**Ordering constraint (unchanged):** complete the product baseline through M3 before runtime AI features (Foundation Models / interpreted Remember). All CAP-* delivery, including raw saving without a model, remains scheduled for M4. Agent-assisted coding during baseline work is a workflow choice, not early AI product scope.

personal wording belongs to `[private notes]` and its
presentation configuration. Record demonstrated workflow results separately
from shipped AI product capabilities; installation alone proves neither.

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

“Complete the product baseline before AI” means establish the domain and screen foundation on `main` through **M3** in [`specs/38_WORK_PLAN.md`](specs/38_WORK_PLAN.md):

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

Source of truth for what exists on `main`: [`specs/39_DOMAIN_INVENTORY.md`](specs/39_DOMAIN_INVENTORY.md).

| Area | Status on `main` |
|---|---|
| Product contracts / specs | Present and authoritative under `specs/` |
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

1. [`PROJECT_STATUS.md`](PROJECT_STATUS.md) (this file) — including reference product loop
2. [`specs/README.md`](specs/README.md)
3. [`specs/01_PRODUCT_CHARTER.md`](specs/01_PRODUCT_CHARTER.md)
4. [`specs/39_DOMAIN_INVENTORY.md`](specs/39_DOMAIN_INVENTORY.md)
5. [`specs/41_PRODUCT_DECISIONS_AND_DESIGN_RATIONALE.md`](specs/41_PRODUCT_DECISIONS_AND_DESIGN_RATIONALE.md)
6. [`specs/40_AI_ENGINEERING_ROADMAP.md`](specs/40_AI_ENGINEERING_ROADMAP.md)

Then open behavioural owners as needed:

- Capture: `34_CAPTURE_PIPELINE_SPEC.md`
- AI runtime: `04_AI_ARCHITECTURE.md`
- Car Board / Road / Pit: `31`, `32`, `33`
- Work plan: `38_WORK_PLAN.md`
- Full map: `00_DOCUMENTATION_INDEX.md`

Do not resume AI implementation first.

Complete the product baseline before any AI work.

---

## Ownership reminder

| Document | Answers |
|---|---|
| Root `README.md` | Repository entry point |
| `PROJECT_STATUS.md` | Current project state / freeze / resume |
| `01_PRODUCT_CHARTER.md` | Product contract (what) |
| `04_AI_ARCHITECTURE.md` | Runtime AI contract |
| `34_CAPTURE_PIPELINE_SPEC.md` | Capture / Remember contract |
| `39_DOMAIN_INVENTORY.md` | Implementation snapshot |
| `40_AI_ENGINEERING_ROADMAP.md` | Deferred AI direction |
| `41_PRODUCT_DECISIONS_AND_DESIGN_RATIONALE.md` | Architectural / product reasoning (why) |
| `38_WORK_PLAN.md` | Executable backlog |

Do not create parallel sources of truth. Cross-reference owners instead of duplicating them.

---

## Resume rule

Do not resume AI implementation first.

Complete the product baseline before any AI work.
