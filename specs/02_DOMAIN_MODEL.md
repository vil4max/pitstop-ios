# Domain Model

## Ubiquitous language

### Vehicle

Identity and stable configuration of the current car.

Vehicle is not the owner of a scalar odometer source of truth.

### Odometer Reading

A mileage fact recorded at a time with a source.

``` text
value
unit
recordedAt
source
```

Latest valid reading is a projection.

### Maintenance Operation

A stable identity for a recurring or trackable maintenance concern.

Examples:

``` text
engineOilService
dsgService
awdCouplingService
brakeFluid
cabinFilter
airFilter
```

Do not use localized titles as domain identity.

### Maintenance Procedure

Defines the composition of a known service procedure for a specific
applicability/source.

Example concept:

``` text
Engine Oil Service

required components:
- engine oil
- oil filter
- sealing element, when applicable by verified procedure
```

Required composition must have provenance. The app may preselect likely
required components in a draft, but actual completion still requires
confirmation/evidence.

### Maintenance Recommendation

A sourced default recommendation.

Dimensions may include:

``` text
manufacturer
market
model
generation
model year
engine/powertrain
transmission
drivetrain
service regime
operation/procedure
rule
source revision
```

### Maintenance Policy

The effective rule selected for one operation on one vehicle.

Source: - official/default recommendation; - user custom policy; -
vehicle-reported condition.

A custom policy never overwrites the official recommendation record.

### Maintenance Anchor

Internal term for the recurring service horizon produced by a policy.

An anchor is not a claim that a component becomes bad at an exact
kilometer.

### Maintenance Completion

Confirmed evidence that one maintenance operation/procedure was
performed.

``` text
operationID
performedAt
odometer?
engineHours?
sourceEventID
```

### Maintenance Progress

Calculated progress from the latest relevant completion/baseline under
the effective policy.

### Maintenance Status

Domain status:

``` text
unknown
upToDate
approaching
due
```

The domain may later preserve richer progress/window information, but
public color severity remains conservative.

### Service Planner

Deterministic domain service that composes independent maintenance
states into a practical proposed visit.

Inputs: - operation statuses; - anchor/window proximity; - procedure
composition; - grouping rules; - recent completion facts.

Output: - suggested service scope.

### Suggested Service Scope

Derived proposal. Not historical truth and not yet the owner's plan.

Sections:

``` text
required procedure components
due operations
due-nearby operations
recommended/optional consumables
relevant service notes
```

### Service Plan

The owner's accepted/edited plan for a future visit.

The plan may contain included and omitted work. Do not create Jira-like
status complexity unless real usage requires it.

### Service Visit / Service History Event

An actual event.

Contains: - date; - odometer; - dealer/service place optional; - money
optional; - actual confirmed performed operations; - source document
optional.

Only actual confirmed operations create MaintenanceCompletion records.

### Note

A raw thought the owner does not want to forget.

Source of truth:

``` text
rawText
createdAt
status
```

Status v1:

``` text
active
archived
```

Semantic metadata is derived.

### Note Context

Canonical navigation contexts in beta:

``` text
carWash
service
shopping
```

AI may assign zero or more canonical contexts. It may not create
arbitrary navigation contexts in beta.

### History Event

A real event in vehicle life.

Kinds in beta:

``` text
service
carWash
odometer
insurance
purchase
other
```

Money is an optional event attribute, not a separate accounting domain.

## Source-of-truth matrix

  -----------------------------------------------------------------------
  Concern                 Source of truth         Derived
  ----------------------- ----------------------- -----------------------
  User note               raw note text           semantic
                                                  contexts/topics

  Odometer                reading history         latest reading, mileage
                                                  rate

  Official interval       verified                displayed default
                          recommendation +        
                          provenance              

  User interval           confirmed policy        next anchor/status

  Maintenance completion  confirmed actual work   cycle reset

  Service plan            owner accepted plan     presentation/grouping

  Service visit           actual history event    spend summaries

  Severity                deterministic engine    AI phrasing

  AI draft                never final truth       pending proposal
  -----------------------------------------------------------------------

## Forbidden conflations

Do not conflate: - recommendation with effective policy; - planned work
with performed work; - visit completion with task completion; -
operation with localized task title; - service procedure with service
visit; - AI confidence with domain validity; - note context with raw
note; - expense with standalone accounting transaction.
