# Current Domain Audit

**Scope:** findings from the current public PitStop repository discussed
during product/domain audit.\
**Required next action:** verify every finding against the full local
workspace before refactoring.

## VehicleConfig

Observed conceptual fields include: - VIN; - make/model/model year; -
purchase date; - engine label; - scalar odometer and updated date; -
average monthly mileage; - mileage baseline values; - seed version; -
photo data.

Issues: - odometer is scalar rather than a time series; - mileage
projection inputs are persisted into vehicle config; - photo support
already exists and must be audited before building a new hero-photo
feature.

Target: - Vehicle identity/config; - OdometerReading facts; - derived
mileage projection.

## ServiceVisitEntity

Currently appears to represent both: - future planned/template
service; - completed historical visit.

It carries target mileage/window and completion/dealer/cost data.

Issue: - schedule and history are conflated.

Target direction: - independent operation policies; - derived suggested
scope; - optional ServicePlan; - actual Service History Event.

## ServiceTaskEntity

Current task catalog already resembles a maintenance-operation
catalog: - engine oil; - oil filter; - air/cabin filters; - spark
plugs; - DSG oil; - brake fluid; - axle oil; - coolant; - belts; -
Haldex; - others.

Issue: - recurring identity is scoped to a visit/task instance; -
localized title/slug mapping appears to participate in identity.

Target: - stable `MaintenanceOperationID`; - current title mapping
becomes a compatibility adapter.

## MaintenanceEngine

Observed logic groups:

### Oil-specific lifecycle

Concepts: - last oil change; - km since oil; - next oil window; - oil
due soon.

Issue: - oil has a special parallel engine.

Target: - engine-oil service becomes a normal first-class maintenance
operation/policy.

### Visit-plan logic

Concepts: - last completed visit; - nearest pending visit; - km
remaining; - estimated date/months/days; - service window; - premature
completion.

Issue: - assumes ordered seeded future visits.

Target: - retain until operation-cycle adapter proves replacement
behavior.

### Reminder helpers

Insurance/service estimate helpers are deterministic and conceptually
valid.

## Seed importer

Current seed mechanism appears to: - create seeded vehicle; - insert
visits/tasks; - synchronize completed seed state; - replace pending
template visits when seed version changes.

Risk: - pending seed template updates are incompatible with user-owned
per-operation policies.

Required rule: - before custom policies ship, seed templates must stop
being authoritative over future maintenance policy.

## Oil duplication

Current domain appears to represent oil through: - oil-specific engine
logic; - `includesOilChange` visit flag; - engine-oil task identity.

This is duplicate representation of one domain fact.

Target: - confirmed completion of `engineOilService` is the source of
truth; - visit "includes oil" is derived.

## Completion semantics risk

Current visit completion/task synchronization must be audited for an
assumption equivalent to:

``` text
visit completed → applicable tasks completed
```

Target invariant:

``` text
actual confirmed operation performed → only that cycle resets
```

## Cost model

Current visit cost appears UAH/profile-specific.

Defer refactor until History/Money phase unless it blocks maintenance
completion.

## Required audit output before code change

Create a verified table:

  ---------------------------------------------------------
  Current Current Domain problem Temporary Target concept
  type/file responsibility adapter
  ---------------------------------------------------------

------------------------------------------------------------------------

Also create:

  ---------------------------------------------
  Current Stable Confidence Evidence Unmapped
  task/title operation ID reason
  ---------------------------------------------

------------------------------------------------------------------------

No schema migration is authorized by this audit.

## Existing seeded note-like data --- mandatory preservation audit

The current application already contains code-seeded note-like/use-case
data, including examples such as:

-   film/wrap application (`поклейка пленок`);
-   floor mats (`коврики`);
-   other existing code-defined owner reminders/thoughts.

These are **existing product behavior and domain evidence**, not
disposable demo content.

Before Notes refactoring:

1.  Locate every code-seeded note/task/reminder-like value in the
    workspace.
2.  Record its source file, current type, fields, display location and
    user-visible behavior.
3.  Classify each item as:
    -   `Note candidate`;
    -   `MaintenanceOperation candidate`;
    -   `History/Expense candidate`;
    -   `VehicleProfile fact`;
    -   `Seed/demo fixture only`;
    -   `Unresolved — INVESTIGATE`.
4.  Create characterization tests for current behavior where practical.
5.  Define an explicit mapping/migration table before deleting or
    replacing the current types.

Refactoring must not silently delete, rename semantically, or
reinterpret these existing cases.

### Required audit table

  ------------------------------------------------------------------------------------
  Existing      Current     Current     Proposed    Migration/adaptation   Test
  value/use     type/file   behavior    domain                             
  case                                                                     
  ------------- ----------- ----------- ----------- ---------------------- -----------
  Film/wrap     verify in   verify      likely Note INVESTIGATE            required
  application   repo                                                       

  Floor mats    verify in   verify      likely Note INVESTIGATE            required
                repo                                                       
  ------------------------------------------------------------------------------------

The classifications above are hypotheses until verified against the
repository.

### Refactoring invariant

> Existing seeded owner thoughts are product discovery evidence.

The new Notes model must prove it can represent the current examples
before the old representation is removed.

### Failure criterion

The Notes refactor fails if an existing seeded case disappears because
it was treated as hardcoded/demo data without audit.
