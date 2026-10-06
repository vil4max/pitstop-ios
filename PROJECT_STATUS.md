# PitStop — Project Status

**State:** active; the iOS 27 redesign and the car profile shipped to TestFlight 1.2.0 from `main`  
**Next:** iPhone Duo layout hardening for 1.3.0 (see [`docs/operations/releases/1.2.0.md`](docs/operations/releases/1.2.0.md) for what 1.2.0 contains)  
**Repository:** public `vil4max/pitstop-ios`  
**TestFlight:** version 1.2.0 (tag `tf-1.2.0-1`, 2026-09-25); delivery is tag-gated (ADR 0013)

Work follows the spec pyramid ([`docs/core.md`](docs/core.md)): core,
requirements and decisions, tests named with `REQ-<AREA>-NNN`, code.
Project conventions are in [`AGENTS.md`](AGENTS.md).

---

## Where the project is

- The original backlog (domain inventory, engineering bootstrap, Road
  investigations, Car Board, Pit and Remember, progressive discovery, system
  capture through the App Group widget, analytics, maintenance intelligence
  investigation) is delivered on `main`. Decision records and `git log`
  record what was delivered.
- The car's dashboard service reading as a maintenance anchor is delivered with
  schema V4 (ADR 0035).
- A recommendation provenance fixture exists in test-only code with a fictional
  car and the fictional market "XM"; production maintenance types are
  unchanged. Real manufacturer data is not shipped.
- The app icon shows Pit's round head from the redesign (ADR 0037), and the app
  draws the same head as the utility control, without glass (ADR 0039).
- Requirements: most REQ IDs are `Status: Proposed`; the approved ones
  (including the iOS 27 redesign set, the Mark-as-done merge-conflict set and
  the car profile set) are fingerprinted in `docs/requirements/.spec-lock.json`.

## Current implementation status

Source of truth for what exists on `main`:
[`docs/engineering/domain-inventory.md`](docs/engineering/domain-inventory.md).

| Area | Status on `main` |
|---|---|
| Product contracts / specs | Present under `docs/` (see `docs/README.md`) |
| Car context | Persisted provisional car, optional name and mileage edit |
| Car Board | Design language, four live tiles, utility layer (ADR 0009) |
| Persistence | SwiftData behind a command-only store, schema V4 in the App Group container; V1 to V3 frozen (ADR 0007, 0016, 0032, 0035, 0036) |
| Widgets | Data-free capture widget and Open Pit control; read-only next-service widget (ADR 0025, 0036) |
| Notes | Save, find, correct, archive without AI |
| History | Record and correct events; timeline of events and confirmed completions |
| Service | Deterministic engine, visit planner, track / track several / mark done / change interval / undo / stop tracking; the car's dashboard reading as an anchor, entered on Service or through Pit (ADR 0010, 0031, 0033, 0035) |
| Road | Deterministic projection, tile and screen; user-stated planned dates, insurance expiry first, added and corrected on Road; labelled date estimate; "from dashboard" when a reading decided (ADR 0008, 0032, 0034, 0035) |
| Remember / Pit | Raw and rule-based interpreted capture end to end, confirmation, deadline, current-mileage question (ADR 0006, 0011, 0015–0019) |
| System capture | Siri intent, App Shortcuts, voice clarification, Open Pit control and data-free widget (ADR 0023–0026) |
| Analytics | Provider-neutral boundary and PostHog HTTP adapter, consent off by default, no project key (ADR 0021, 0022) |
| Runtime AI | Foundation Models interpreter behind a DEBUG launch argument only; off in Release (ADR 0027) |

## Rules

- Core priority P4 ([`docs/core.md`](docs/core.md)) gates runtime AI: no runtime
  AI in Release builds until the ADR 0027 rollout gate is passed and beta
  evidence validates the core (INV-PROD-001).
- Product features start with Product Review
  ([`docs/engineering/product-review-process.md`](docs/engineering/product-review-process.md)).
- Local `just verify` is the implementation gate; documentation-only changes
  use proportional checks.

---

## Reading order

1. [`PROJECT_STATUS.md`](PROJECT_STATUS.md) (this file)
2. [`docs/requirements/product-overview.md`](docs/requirements/product-overview.md)
3. [`docs/requirements/product-charter.md`](docs/requirements/product-charter.md)
4. [`docs/engineering/domain-inventory.md`](docs/engineering/domain-inventory.md)
5. [`docs/decisions/0004-product-design-rationale.md`](docs/decisions/0004-product-design-rationale.md)

Then the behaviour contracts as needed:

- Capture: `docs/requirements/capture-pipeline.md`
- AI runtime: `docs/engineering/ai-architecture.md`, `docs/planning/ai-roadmap.md`
- Car Board / Road / Pit: `car-board-screen`, `road-domain-and-ui`, `pit-behavior-and-motion`
- Full map: `docs/README.md`

---

## Document responsibilities

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

Do not create parallel sources of truth. Cross-reference the owning document instead of duplicating it.
