# Domain Model

Core: P1, P3, C2, C4, C5

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

No reading means unknown mileage, not zero. A provisional display value must
not create an Odometer Reading or become a maintenance baseline.

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

Notes hold thoughts, observations, and intentions. They must remain readable
without semantic metadata. The user can correct or archive a Note; AI must not
replace its original wording. Archiving changes its visibility/status, not the
truth of a service operation or a History Event.

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

A Note about intended work is not a History Event. Recording that work happened
requires the appropriate domain command and confirmation policy; a service
event produces completions only for the operations actually confirmed.

Feature surfaces read these records and derived projections. Car Board and
Road do not maintain independent copies of historical truth.

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

## Requirements

Status `proposed` means derived from the contract text above and awaiting owner approval.

### REQ-DOMAIN-001 — Odometer truth is reading history
Status: proposed
Core: P1
Source: [Vehicle](#vehicle), [Odometer Reading](#odometer-reading), [Source-of-truth matrix](#source-of-truth-matrix)
Given a vehicle with recorded Odometer Readings
When latest reading or mileage rate is needed
Then it is projected from reading history and Vehicle holds no scalar odometer source of truth

### REQ-DOMAIN-002 — No reading means unknown mileage
Status: proposed
Core: C2
Source: [Odometer Reading](#odometer-reading)
Given a vehicle with no Odometer Reading
When mileage is read
Then mileage is unknown and it is never zero

### REQ-DOMAIN-003 — Provisional display value is not a reading
Status: proposed
Core: C2, C5
Source: [Odometer Reading](#odometer-reading)
Given a provisional mileage display value
When it is shown or used
Then no Odometer Reading is created and it does not become a maintenance baseline

### REQ-DOMAIN-004 — Required procedure composition has provenance
Status: proposed
Core: C2
Source: [Maintenance Procedure](#maintenance-procedure)
Given a Maintenance Procedure with required components
When its composition is defined
Then every required component carries provenance

### REQ-DOMAIN-005 — Preselected components are not completion
Status: proposed
Core: C5
Source: [Maintenance Procedure](#maintenance-procedure)
Given a draft with preselected likely required components
When the draft is not confirmed
Then no Maintenance Completion is recorded for them

### REQ-DOMAIN-006 — Custom policy keeps official recommendation
Status: proposed
Core: P1
Source: [Maintenance Policy](#maintenance-policy), [Source-of-truth matrix](#source-of-truth-matrix), [Forbidden conflations](#forbidden-conflations)
Given an official Maintenance Recommendation for an operation
When the user confirms a custom policy
Then the custom policy becomes the effective policy and the official recommendation record is unchanged

### REQ-DOMAIN-007 — Progress derives from completions and policy
Status: proposed
Core: C5
Source: [Maintenance Progress](#maintenance-progress), [Source-of-truth matrix](#source-of-truth-matrix)
Given an effective policy and confirmed completions
When Maintenance Progress is calculated
Then it starts from the latest relevant completion or baseline and only confirmed actual work resets the cycle

### REQ-DOMAIN-008 — Suggested scope is not plan or history
Status: proposed
Core: P3, C5
Source: [Service Planner](#service-planner), [Suggested Service Scope](#suggested-service-scope), [Source-of-truth matrix](#source-of-truth-matrix)
Given the Service Planner produced a Suggested Service Scope
When the owner has not accepted it
Then no Service Plan exists for it and no History Event or completion is created

### REQ-DOMAIN-009 — Planned work is not performed work
Status: proposed
Core: C5
Source: [Service Plan](#service-plan), [Forbidden conflations](#forbidden-conflations)
Given an accepted Service Plan with included work
When no actual visit is confirmed
Then no Maintenance Completion is created and maintenance cycles stay unchanged

### REQ-DOMAIN-010 — Completions only for confirmed operations
Status: proposed
Core: C5
Source: [Service Visit / Service History Event](#service-visit--service-history-event), [History Event](#history-event), [Forbidden conflations](#forbidden-conflations)
Given a service visit with some operations confirmed performed
When the visit is recorded
Then completions exist only for confirmed operations and unconfirmed operations stay unchanged

### REQ-DOMAIN-011 — Note raw text is authoritative
Status: proposed
Core: P1, P3
Source: [Note](#note), [Source-of-truth matrix](#source-of-truth-matrix)
Given a Note with rawText
When AI derives semantic metadata
Then rawText is unchanged and AI never replaces the original wording

### REQ-DOMAIN-012 — Note readable without semantic metadata
Status: proposed
Core: P1, P3
Source: [Note](#note), [Source-of-truth matrix](#source-of-truth-matrix), [Forbidden conflations](#forbidden-conflations)
Given a Note with no semantic metadata or contexts
When the Note is shown
Then its rawText is readable and note context is derived, not the raw note

### REQ-DOMAIN-013 — Archiving a Note changes only its status
Status: proposed
Core: C5
Source: [Note](#note)
Given an active Note about service work
When the user archives it
Then its status is archived and no History Event or Maintenance Completion is created or changed

### REQ-DOMAIN-014 — Note contexts are canonical only
Status: proposed
Core: P3
Source: [Note Context](#note-context)
Given AI assigns Note Contexts in beta
When the assignment is validated
Then only carWash, service, or shopping are accepted and zero contexts is valid

### REQ-DOMAIN-015 — Intended work Note is not History
Status: proposed
Core: C5
Source: [History Event](#history-event), [Forbidden conflations](#forbidden-conflations)
Given a Note about intended work
When it is saved
Then no History Event is created and recording the work requires a domain command and confirmation

### REQ-DOMAIN-016 — Surfaces keep no copy of history
Status: proposed
Core: P1
Source: [History Event](#history-event)
Given a History Event is corrected
When Car Board or Road is shown
Then they reflect the corrected record and hold no independent copy of historical truth

### REQ-DOMAIN-017 — Severity is deterministic
Status: proposed
Core: P3
Source: [Source-of-truth matrix](#source-of-truth-matrix)
Given a maintenance state with AI phrasing available
When severity is determined
Then the deterministic engine decides it and AI supplies phrasing only

### REQ-DOMAIN-018 — AI draft is never final truth
Status: proposed
Core: P3, C4
Source: [Source-of-truth matrix](#source-of-truth-matrix), [Forbidden conflations](#forbidden-conflations)
Given an AI draft with any confidence
When domain validation has not accepted it
Then it remains a pending proposal and no domain truth is written
