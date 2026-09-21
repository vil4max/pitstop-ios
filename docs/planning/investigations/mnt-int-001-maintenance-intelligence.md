# MNT-INT-001 Maintenance intelligence investigations

**Status:** Investigated (agent, 2026-09-21); owner decisions pending\
**Task:** MNT-INT-001 (Phase 7, `work-plan.md`)\
**Register:** [`../investigations.md`](../investigations.md) (also answers INV-VEH-002 and part of INV-MNT-001)\
**Contracts:** [`../../core.md`](../../core.md) (P2, P3, P4, C2, C5),
[`../../requirements/maintenance-engine.md`](../../requirements/maintenance-engine.md),
[`../../requirements/domain-model.md`](../../requirements/domain-model.md),
[`../../requirements/road-domain-and-ui.md`](../../requirements/road-domain-and-ui.md),
ADR [0001](../../decisions/0001-maintenance-anchors.md),
[0007](../../decisions/0007-persistence.md),
[0008](../../decisions/0008-road-projection-rules.md),
[0010](../../decisions/0010-maintenance-engine-rules.md),
[0020](../../decisions/0020-maintenance-anchor-closure.md)

This record follows the register format (Question, Evidence, Options,
Decision, Why, Rejected alternatives, Implementation impact, Follow-up tasks).
It creates no requirement, changes no code, and stores no manufacturer data.
Every vehicle below is fictional. Statements about law and licences are the
agent's reading of public texts, not legal advice; the owner decides whether a
lawyer is needed before any data enters the app.

## Question

The card: "Manufacturer data, presets, and richer Road milestones after core
product validation." Four sub-questions:

1. **Manufacturer data.** Which sources could supply maintenance schedules and
   procedure compositions, under which licence and verification burden, which
   are viable for a solo app, and how would provenance fit the existing
   `MaintenancePolicy` source separation (ADR 0007, 0020)? This is ADR 0020
   owner question B.
2. **Presets.** What is a preset in this product, how can it be applied
   through existing commands without inventing facts (core C2), and what is the
   smallest valuable experiment?
3. **Richer Road milestones.** What can Road show beyond maintenance cycles,
   what data does each kind need, and which ADR 0008 gates apply?
4. **Recommendation.** Go or no-go per area, the smallest next experiment with
   acceptance and measurement, owner decisions, and proposed follow-up items.

## Evidence

### Repository state (2026-09-21, `main` at a6bc6d4)

- **Policy model.** `MaintenancePolicy` has `operationID`, optional
  `distanceIntervalKm`, optional `timeIntervalMonths`, and `source`
  (`defaultRecommendation`, `vehicleCondition`, `userCustom`), with precedence
  custom over condition over recommendation
  (`Pitstop/Domain/Maintenance/Maintenance.swift:32-76`). It carries no
  provenance, applicability, anchoring mode, or source revision.
- **Storage.** `MaintenancePolicyRecord` stores the same five fields and is
  keyed by vehicle, operation and source, so a custom policy never overwrites a
  recommendation row (`Pitstop/Infrastructure/Persistence/PitstopSchemaV1.swift:104-116`,
  ADR 0007). An unknown stored source reads back as `userCustom`
  (`RecordMapping.swift:123`).
- **Who writes policies.** Only `userCustom` is ever written: the Service
  "Track" sheet (`Pitstop/Features/Service/ServiceViewModel.swift:62-76`), the
  capture mapper (`Pitstop/Domain/Capture/DomainCommandMapper.swift:49-56`),
  and DEBUG demo data (`Pitstop/App/DemoData.swift:24-35`). No code path writes
  `defaultRecommendation` or `vehicleCondition`; no recommendation is seeded
  (ADR 0010).
- **Commands.** `DomainCommand` has `setMaintenancePolicy` but no command that
  removes a policy (`Pitstop/Domain/Capture/DomainCommands.swift:148-158`).
  Once an operation is tracked, the owner can change its interval but cannot
  stop tracking it.
- **Catalog.** Seven code-owned operation IDs, frozen raw values, grown by ID
  only (ADR 0020 Q9, Q11).
- **Vehicle facts.** `Vehicle` holds `name`, `make`, `model`, `year`, `vin`
  (`Pitstop/Domain/Vehicle/Vehicle.swift`). There is no market, generation,
  engine, transmission, drivetrain, or service regime, which are the
  applicability dimensions the domain model lists for a Maintenance
  Recommendation (`domain-model.md`, "Maintenance Recommendation").
- **Road inputs.** `RoadMilestone.Subject` is either `maintenance(operationID)`
  or `planned(PlannedVehicleEvent.Kind, id:)`, with kinds `insuranceExpiry`,
  `plannedVisit`, `other` (`Pitstop/Domain/Road/RoadProjection.swift:24-48`).
  `RoadProjector` already places planned events by date, keeps a passed date as
  due for 14 days and then drops it (`RoadProjector.swift:91-115`). Nothing
  outside tests supplies `RoadContext.plannedEvents`: there is no stored
  planned event, no command, and no entry UI (also listed under "Open for
  owner" in `../../tasks/full-backlog-delivery.md`). History has a past
  `insurance` event kind, which is a fact, not a future milestone.
- **Measurement.** Analytics questions AQ-005 (status trust) and AQ-006
  (planner alignment) exist in `../../operations/analytics-questions.md`; no
  events are emitted yet (ENG-002 and ANL-001 are open).
- **Validation gate.** The card is scheduled "after core product validation".
  No beta evidence exists yet for INV-PROD-001 (value after week one) or
  INV-PROD-002 (Remember habit). The roadmap stop condition "Manufacturer data
  becomes necessary before product value exists" and the charter failure
  "manufacturer data becomes a prerequisite for usefulness" both apply.

### External sources (area 1 and 3)

Retrieved 2026-09-21. Pages were read for availability and terms only; no
schedule was copied or stored.

| Source kind | What it provides | Licence and reuse, as published | Market | Evidence |
|---|---|---|---|---|
| Owner's manual and maintenance booklet on an OEM owner site | Per-model schedule, often split by service regime (normal, severe) | The site terms seen allow viewing and downloading "only for personal, non-commercial use" and forbid redistribution (Ford terms). The document is copyrighted; the schedule is a per-vehicle fact set inside it | One market per document | [Ford terms][ford-terms]; manuals are commonly published online by OEMs ([Edmunds guide][edmunds-manuals]) |
| OEM repair and maintenance information (RMI) portals | Service schedules, procedures, parts | EU: manufacturers must give independent operators access (Reg. 2018/858 Art. 61) and may charge "reasonable and proportionate fees" with hourly to yearly access (Art. 63). The access right serves repair; it does not grant redistribution to a consumer app. US: the 2014 right-to-repair MOU extends the Massachusetts law's access nationwide for independent repairers | Per OEM, per market | [Art. 61][eu-art61], [Art. 63][eu-art63], [2014 MOU][mou-2014], [CJEU C-319/22][cjeu-c319] |
| Commercial maintenance APIs | Schedules by VIN or year/make/model/trim, with items per interval | Pricing and terms behind sign-up; none of the pages seen states caching or redistribution rights. One provider states coverage as US vehicles only | Mostly US | [Vehicle Databases][vdb-api], [TorqueNode][torquenode], [CarMD CarScan docs][carmd], [DataOne service data][dataone], [Edmunds maintenance API docs][edmunds-api] |
| Government vehicle data (US) | VIN decoding, make, model, specifications; no schedules | Free public service with rate control | US | [NHTSA vPIC][vpic] |
| Law on periodic inspection (EU) | Minimum inspection frequency for passenger cars: four years after first registration, then every two years | Public law; national rules add detail | Per member state | [Directive 2014/45/EU Art. 5][eu-2014-45-art5] |
| Legal background for fact reuse | US: facts are not copyrightable; only original selection and arrangement of a compilation is. EU: a database maker may prevent extraction or re-use of a substantial part of a database | Background only; not a licence | US, EU | [Feist v. Rural][feist], [Directive 96/9/EC][eu-db-directive] |
| App distribution | App Review forbids unlicensed protected third-party material | Applies to OEM names, logos, and copied documents | Worldwide | [App Review Guidelines 5.2][apple-ip] |

## Options

### 1. Manufacturer data

| Option | Verification burden | Licence risk | Fit with core | Solo viability |
|---|---|---|---|---|
| M1. App-curated schedules transcribed from owner's manuals | High: per market, model year, powertrain, regime, and revision; every correction is the app's liability | Document terms forbid redistribution; EU database right may cover a substantial extraction | Satisfies C2 only with full provenance and applicability | No |
| M2. Licensed OEM RMI data | High, and per OEM | Fee-based access for repair; redistribution needs a separate licence per OEM | Good provenance | No |
| M3. Commercial API at runtime | Provider owns data quality; the app still has to check applicability and market | Terms unknown until sign-up; per-call cost | Needs network, a key held off-device (a backend), and vehicle identity input, which conflicts with P2 and the non-goals "VIN-first setup" and "mandatory cloud account" | Not now; possible later for one market |
| M4. Owner-transcribed cadence | The owner reads their own manual and enters the interval; no app verification | None for the app: the owner uses their own copy for personal use | Already supported: a `userCustom` policy (ADR 0010) | Yes, today |
| M5. Model-generated schedule | Unverifiable | Unknown training provenance | Violates C2, P3 and the non-goal "AI-generated maintenance truth" | Rejected |
| M6. Crowd or forum datasets | Unknown provenance | Unknown | Violates the charter failure "manufacturer defaults presented without provenance" | Rejected |

**Provenance model, whatever the source.** The domain model already separates
a Maintenance Recommendation (sourced) from a Maintenance Policy (effective
rule). The smallest shape that keeps ADR 0007's row separation:

```text
MaintenanceRecommendation            (new record, never edited by the user)
  id
  operationID                        (catalog ID)
  rule: distanceKm?, months?, anchoring (completionBased | fixedGrid)   (ADR 0020 Q3)
  applicability: make, model, generation?, modelYears, market,
                 engine?, transmission?, drivetrain?, serviceRegime?
  provenance: sourceKind, publisher, documentTitle, documentRevision,
              retrievedAt, verifiedBy, verifiedAt, licenceReference
  components: [componentID]?         (procedure composition, REQ-DOMAIN-004)

MaintenancePolicy (source = defaultRecommendation)
  recommendationID                   (new optional field; required for this source)
```

Rules: a recommendation becomes a policy only when every applicability field
it names matches a fact the user supplied or confirmed (C2); a mismatch or an
unknown fact leaves the operation without a recommendation instead of guessing
(maintenance-engine failure criterion "a source recommendation is applied
without applicability/provenance"). A `userCustom` policy still wins, and the
recommendation row is kept (REQ-DOMAIN-006). This needs a schema version
(the current record has no provenance column) and new vehicle facts for the
applicability dimensions.

### 2. Presets

A preset is a named, user-chosen bundle of operations, optionally with
intervals, for a class of car (for example "petrol, dual-clutch automatic,
AWD"), applied in one step instead of tracking operations one by one.

The C2 problem: a preset that ships numbers is an app recommendation. If the
numbers are unsourced it is invented truth; if they are sourced it is option M1
to M3 with the same licence and verification burden. So presets split:

| Option | Contents | C2 status |
|---|---|---|
| P1. Operation-set starter | Which catalog operations to track for a car class; the owner types or picks each interval; no value preselected | Safe: the class only reorders and preselects *operations to consider*, and each interval is user-supplied |
| P2. Owner-cadence chips | Quick-entry choices such as 5,000 / 7,500 / 10,000 / 15,000 km for oil, the "simple owner cadence" the engine spec names; none preselected, labelled as the owner's choice | Safe if no chip is preselected and the copy never calls it a recommendation; INV-MNT-003 validates the values |
| P3. Numeric class preset ("typical AWD compact: oil 10,000 km, DSG 60,000 km") | Intervals chosen by the app | Unsourced: rejected. Sourced: blocked on area 1 |
| P4. Copy my own set | Reapply the owner's current policies | No value with one car per user (C1) |

Application through existing commands: P1 and P2 produce one
`SetMaintenancePolicyCommand` per selected operation with `source: .userCustom`,
each validated by `DomainCommand.validate` (at least one positive interval).
Before applying, one confirmation lists every operation and interval (same
boundary as ADR 0006). Two gaps: commands execute one by one, so a failure part
way leaves some policies saved and the sheet must report which; and there is no
command to stop tracking an operation, so a wrongly applied starter cannot be
undone today.

### 3. Richer Road milestones

| Candidate | Data needed | Where it comes from | Current support | ADR 0008 gates |
|---|---|---|---|---|
| R1. Insurance expiry | One future date; nothing else (no insurer, no policy number) | User states it, in Remember or an editor | Kind and projection exist; no storage, command, or UI | Date dimension only; explicit statement (REQ-ROAD-001, 002); 14-day grace after the date |
| R2. Booked service visit | Date; optionally the operations the owner intends to do | User states it | Kind `plannedVisit` exists; no storage | Date dimension; must not become a Service Plan or reset anything (C5); links to owner question C |
| R3. Periodic inspection due | Next due date | User states it. Deriving it from first registration plus law needs country, vehicle category and national rules; the EU text is a minimum with national variation, and core C2 forbids inferring from locale alone | Would use `other` or a new kind | Date dimension; derivation rejected unless the owner states country and registration date and a rule table is sourced |
| R4. Other owner-stated dated events (warranty end, registration renewal, seasonal tyre change) | Date and a short user label | User states it | `other` exists but has no label field | As R1; a user label is needed to be readable |
| R5. Estimated date for a distance milestone ("oil around March") | At least two mileage observations over a meaningful span, a rate model, and uncertainty | Derived | Rejected in ADR 0008 and ADR 0010 until an explicit model is approved | Conflicts with REQ-ROAD-007 "no invented mileage or time conversion"; needs a requirement change, a model, and an estimate label |
| R6. Vehicle-reported remaining value ("service in 3,200 km / 45 days" on the dashboard) | The shown remaining value, the reading date and mileage | User reads it from the car | Rule family named in the engine spec; `vehicleCondition` source exists but is never written | A point-in-time value, not an interval: needs its own rule design before Road can place it |

Common gates from ADR 0008 that any new kind must pass: eligibility is decided
in the domain and never by the UI (REQ-ROAD-004); each milestone has one
dimension and no conversion (REQ-ROAD-007); the default horizon (6 months,
5,000 km) and the four-slot initial viewport stay, so more kinds compete for
the same slots; clustering by 21 days applies to all date milestones, planned
or maintenance; past events stay in History (REQ-ROAD-010); low-confidence
suggestions never become milestones (REQ-ROAD-002). ADR 0008 also lists the
evidence to collect before its constants change (how often Road opens with an
extended horizon, cluster expansion, "Back to now" use).

## Decision

Agent recommendation; each item needs the owner decision listed below it.

### Area 1 — Manufacturer data: no-go for app-supplied data; go for a fixture-only provenance check

- No manufacturer schedule, procedure, or preset value enters the app now.
  Owner cadence (M4) stays the only policy source, as ADR 0020 B recommends.
- **Smallest next experiment (MNT-INT-002, about 1 day, tests only).** Write
  the provenance and applicability shape above as a test fixture, not as
  production code, and express one fictional schedule for one fictional car:
  "Example Motors Kestrel, fictional market XM, 2.0 petrol, 7-speed dual-clutch,
  AWD, normal regime", with fictional rules such as oil 15,000 km or 12 months,
  dual-clutch fluid 60,000 km, coupling fluid 45,000 km or 36 months, brake
  fluid 24 months fixed from first registration, and an oil procedure with three
  components.
  - Acceptance: every fictional rule is expressible, including one fixed-grid
    rule (ADR 0020 Q3) and one procedure composition (REQ-DOMAIN-004); an
    applicability mismatch (other transmission) yields no recommendation; an
    unknown applicability fact yields no recommendation; a `userCustom` policy
    stays effective over it (REQ-DOMAIN-006); no real make, model, or value
    appears in the repository.
  - Measurement: the number of fictional rule shapes the model cannot express,
    and the vehicle facts it would need that the app does not collect. Zero
    inexpressible shapes and a short fact list mean the shape is ready for a
    real-source evaluation.
- **Real-source evaluation stays private.** Reading one real manual or one
  API's terms against the fixture checklist is owner work (or agent work in a
  private location), because real schedules must not enter this public
  repository.

Owner decisions: which market or markets PitStop targets for recommendations;
whether a paid licence or API subscription and a backend are acceptable at all;
whether a legal review is required before any source is used; and whether
recommendations wait for beta evidence (INV-PROD-001) as the card and roadmap
say.

### Area 2 — Presets: no-go for numeric presets; conditional go for an operation-set starter

- Numeric presets (P3) are rejected while area 1 is closed.
- **Smallest valuable experiment (MNT-PRE-001, about 2 days, after the product
  review gate in `../../engineering/product-review-process.md`).** A "Track
  several" sheet on Service: the owner answers two optional car-class
  questions ("dual-clutch or other automatic?", "all-wheel drive?"), which only
  reorder and preselect operations to consider; each selected operation needs
  an owner interval, typed or picked from unselected cadence chips (P2); one
  confirmation lists everything; each item is saved as a `userCustom` policy.
  - Acceptance: every saved policy has `source == .userCustom` and a
    user-entered interval; no interval is preselected; nothing is saved without
    the confirmation; a failed item is reported by name and the others stay
    saved; unit tests on the view model and an on-disk store test; copy never
    says "recommended".
  - Measurement (needs ENG-002 events): number of tracked operations per car
    after 7 days with and without the sheet; sheet abandonment; share of
    intervals changed within 30 days (a proxy for unconsidered picks); chip vs
    typed interval share (feeds INV-MNT-003).
- Prerequisite: a "stop tracking" command (MNT-POL-001), so a wrong pick can be
  undone (core P1: stored data can be corrected).

Owner decisions: whether one-by-one tracking is a real friction worth a sheet
(beta evidence first, or build now); whether cadence chips may show values at
all and which; whether car-class questions may reorder operations (they must
not become vehicle facts unless the owner says they should).

### Area 3 — Richer Road milestones: go for owner-stated dated events; no-go for derived ones

- **Smallest next experiment (ROAD-EVT-001, about 3 days).** Store planned
  dated events and let the user create, correct and delete one, starting with
  insurance expiry (R1): schema version with a `PlannedVehicleEventRecord`
  (id, vehicleID, kind, date, optional user label), commands to plan, correct
  and cancel, an entry point the owner chooses, and `RoadContext.plannedEvents`
  fed from the store.
  - Acceptance: a stated insurance expiry appears on Road labelled by days left
    (REQ-ROAD-001, 007); it is not a History event and resets nothing (C5); it
    leaves Road 14 days after the date (ADR 0008); correcting and deleting work;
    no insurer name or policy number is stored; lightweight migration from the
    current schema is tested; Remember may propose it only behind confirmation
    (ADR 0006).
  - Measurement: share of beta cars with at least one planned event; Road
    opens per active week before and after; how often a planned event is the
    only milestone on Road (sparse-car value, REQ-ROAD-008).
- R2 (booked visit) follows R1 only after owner question C (Service Plan
  order) is answered. R3 and R4 reuse the same record with a user label; no
  inspection date is derived. R5 (estimated dates) and R6 (vehicle-reported
  remaining) stay investigations.

Owner decisions: where the user enters a dated event (Road, Car Board header,
History editor, or Remember only); whether `other` gets a user label field;
whether insurance expiry is shown on the Car Board as well as Road; whether a
mileage-rate estimate (R5) is wanted at all, which requires changing
REQ-ROAD-007.

## Why

- **Value before data (P2, charter failures).** Owner cadence already gives
  Service and Road real milestones without manufacturer data; the card itself
  waits for product validation, and no beta evidence exists.
- **Truth and provenance (C2, P3).** Every source that could supply numbers
  either forbids redistribution, charges for repair-only access, hides its
  terms behind sign-up, or covers a different market. The only source that is
  both licence-free and verified for this car is the owner.
- **Solo cost.** A curated database multiplies verification by markets, model
  years, powertrains, regimes and revisions, and makes every error the app's.
  A runtime API needs a backend and a key, which the app does not have and the
  non-goals avoid.
- **Road already has the slot.** The projection places dated events today; the
  missing piece is storage and entry, which is cheaper than any derived
  milestone and adds no inferred facts.

## Rejected alternatives

- **Seeding sample recommendations to exercise provenance in the app.**
  Invented truth; the fixture belongs in tests (ADR 0020, rejected
  alternatives).
- **Scraping owner-manual portals or aggregator sites.** Terms forbid it and
  real data must not enter this public repository.
- **Letting a model propose intervals, even labelled as estimates.** Core
  non-goal "AI-generated maintenance truth".
- **A single global "conservative" preset.** ADR 0001 rejects global modes;
  owners mix custom oil with other cycles.
- **Deriving inspection or insurance dates from locale or registration
  year.** Core C2 forbids inference from locale alone, and national rules vary
  beyond the EU minimum.
- **Adding a `PolicySource` case for "copied from my manual".** The owner's
  entry is already `userCustom`; a new case would imply the app verified it.
  If a source note is wanted, it is a free-text field on the policy, not a new
  precedence level.

## Implementation impact

None in this task: no code, schema, requirement, or ADR text changes. If the
follow-ups are accepted:

- MNT-INT-002 adds test-only types; production `MaintenancePolicy` is
  unchanged until a real source is approved.
- MNT-POL-001 adds one `DomainCommand` case, its validation, store handling,
  and a Service action; no schema change (the row is deleted).
- MNT-PRE-001 is presentation plus repeated existing commands.
- ROAD-EVT-001 adds a schema version, three commands, a store query, and an
  entry UI; `RoadProjector` is unchanged.

## Follow-up tasks (proposals only; not created as issues)

| Proposed ID | Title | Type | Depends on | Est |
|---|---|---|---|---:|
| MNT-INT-002 | Recommendation provenance fixture (fictional car, tests only) | investigation | owner decision on area 1 scope | 1d |
| MNT-INT-003 | Private licence and terms review of one real source (outside this repository) | investigation, owner | MNT-INT-002, market decision | 1d |
| MNT-POL-001 | Stop tracking an operation (remove the owner's policy) | implementation | — | 1d |
| MNT-PRE-001 | "Track several" starter with owner intervals | implementation | MNT-POL-001, product review gate, ENG-002 events | 2d |
| ROAD-EVT-001 | Planned dated events: storage, commands, entry, insurance expiry first | implementation | owner decision on entry point | 3d |
| ROAD-EST-001 | Mileage-rate estimate for distance milestones | investigation | ROAD-EVT-001, REQ-ROAD-007 change | 1d |
| MNT-VR-001 | Vehicle-reported remaining value as a rule | investigation | — | 1d |
| (ENG-002 scope) | Events for AQ-005, AQ-006 and the measurements above | implementation | ENG-002 | — |

## Owner decisions (summary)

1. Area 1 scope: stop at owner cadence, or run MNT-INT-002 now; target market
   or markets; budget and backend acceptance for any paid source; legal review
   requirement.
2. Area 2: build the starter sheet now or after beta evidence; allowed chip
   values; whether class questions may become vehicle facts.
3. Area 3: entry point for dated events; user label on `other`; Car Board
   display of insurance expiry; whether R5 is wanted (requires changing
   REQ-ROAD-007).
4. Carried from ADR 0020: owner question A (promote ADR 0001), B (answered here
   as a recommendation, still an owner call), C (plan vs visit order, which
   gates R2).

## Sources

[ford-terms]: https://www.ford.com/help/terms/
[edmunds-manuals]: https://www.edmunds.com/how-to/how-to-find-your-car-owners-manual-online.html
[eu-art61]: https://www.legislation.gov.uk/eur/2018/858/article/61
[eu-art63]: https://www.legislation.gov.uk/eur/2018/858/article/63
[mou-2014]: https://www.autocare.org/news/latest-news/details/2014/01/22/Automakers-and-Aftermarket-Move-to-Preserve-Consumer-Choice-in-Auto-Repair-362
[cjeu-c319]: https://eur-lex.europa.eu/legal-content/EN/TXT/PDF/?uri=CELEX%3A62022CA0319
[vdb-api]: https://vehicledatabases.com/api/vehicle-maintenance
[torquenode]: https://torquenode.com/api/vehicle-maintenance-schedule
[carmd]: https://api.carmd.com/member/docs
[dataone]: https://www.dataonesoftware.com/vehicle-data-vin-decoding/vehicle-service-data
[edmunds-api]: https://developer.edmunds.com/api-documentation/vehicle/service_maintenance/v1/
[vpic]: https://vpic.nhtsa.dot.gov/api/
[eu-2014-45-art5]: https://www.legislation.gov.uk/eudr/2014/45/article/5
[feist]: https://supreme.justia.com/cases/federal/us/499/340/
[eu-db-directive]: https://eur-lex.europa.eu/legal-content/EN/TXT/PDF/?uri=CELEX:01996L0009-20190606
[apple-ip]: https://developer.apple.com/app-store/review/guidelines/#intellectual-property

- Ford, Terms and Conditions (site content use): <https://www.ford.com/help/terms/>
- Edmunds, finding an owner's manual online: <https://www.edmunds.com/how-to/how-to-find-your-car-owners-manual-online.html>
- Regulation (EU) 2018/858, Art. 61 (RMI access): <https://www.legislation.gov.uk/eur/2018/858/article/61>
- Regulation (EU) 2018/858, Art. 63 (RMI fees): <https://www.legislation.gov.uk/eur/2018/858/article/63>
- CJEU C-319/22 (access to vehicle information): <https://eur-lex.europa.eu/legal-content/EN/TXT/PDF/?uri=CELEX%3A62022CA0319>
- Auto Care Association, 2014 right-to-repair MOU announcement: <https://www.autocare.org/news/latest-news/details/2014/01/22/Automakers-and-Aftermarket-Move-to-Preserve-Consumer-Choice-in-Auto-Repair-362>
- Vehicle Databases maintenance API (US vehicles): <https://vehicledatabases.com/api/vehicle-maintenance>
- TorqueNode maintenance schedule API: <https://torquenode.com/api/vehicle-maintenance-schedule>
- CarMD CarScan API docs (listed by search; the page refused a connection on 2026-09-21): <https://api.carmd.com/member/docs>
- DataOne OEM service data: <https://www.dataonesoftware.com/vehicle-data-vin-decoding/vehicle-service-data>
- Edmunds maintenance API documentation (current availability to new developers not stated): <https://developer.edmunds.com/api-documentation/vehicle/service_maintenance/v1/>
- NHTSA vPIC API: <https://vpic.nhtsa.dot.gov/api/>
- Directive 2014/45/EU, Art. 5 (inspection frequency): <https://www.legislation.gov.uk/eudr/2014/45/article/5>
- Feist Publications v. Rural Telephone Service, 499 U.S. 340 (1991): <https://supreme.justia.com/cases/federal/us/499/340/>
- Directive 96/9/EC (legal protection of databases): <https://eur-lex.europa.eu/legal-content/EN/TXT/PDF/?uri=CELEX:01996L0009-20190606>
- Apple App Review Guidelines, 5.2 Intellectual Property: <https://developer.apple.com/app-store/review/guidelines/#intellectual-property>
