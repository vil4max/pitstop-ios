# Capture Pipeline Specification

**Status:** P0 architecture and product contract

Core: P1, P3, C2, C3, C4, C5

## Product capability

The product action is **Remember**.

> Capture first. Interpret safely. Mutate deterministically.

## Two modes, one capability

**Raw Remember** saves a thought without assigning stronger meaning. It is a
normal useful mode, not only an error fallback, and needs no model.

**Interpreted Remember** proposes typed meaning such as an odometer reading or
maintenance completion. Interpretation does not make the proposal a fact.

Both modes share validation, confirmation policy, domain commands, persistence,
and an inspectable result. Pit and system entry points are sources, not separate
versions of Remember. Delivery remains staged by `../planning/work-plan.md`; describing
raw mode does not authorize CAP-* implementation before the current freeze and
milestone gates permit it.

## Sources

All sources produce the same input contract:
- Pit voice;
- Pit text;
- direct app capture;
- Home Screen widget;
- Siri;
- App Shortcuts;
- later document recognition;
- CarPlay only if validated.

The source does not choose the final domain entity.

## CaptureInput

Conceptual model:

```text
CaptureInput
- id
- payload
- source
- capturedAt
- locale
- selectedVehicleID?
- visibleFeature?
- visibleEntityID?
```

`payload` may initially support:

```text
text
transcript
recognizedDocumentText
```

Raw source content is privacy-sensitive.

## Pipeline

```text
CaptureInput
    ↓
Proposal creation
(deterministic raw preservation OR SemanticInterpreter)
    ↓
MemoryProposal
    ↓
ProposalValidator
    ↓
ConfirmationPolicy
    ↓
DomainCommandMapper
    ↓
DomainCommand
    ↓
Domain mutation
    ↓
Persistence
    ↓
Derived projections recalculate
```

Raw mode produces a `rawNote` proposal without a model call. Interpreted mode
uses `SemanticInterpreter` to propose a supported kind. Both enter the same
`ProposalValidator` / `ConfirmationPolicy` path; neither writes directly to
persistence. Cancellation performs no mutation in either mode.

## MemoryProposal

Candidate kinds:

```text
rawNote
contextualNote
odometerReading
vehicleFact
maintenanceCompletion
maintenancePolicyDraft
vehicleEvent
expense
reminderCandidate
unknown
```

The initial implementation should support only validated product-core kinds. Unsupported meaning must degrade to raw preservation.

Each proposal includes:
- kind;
- extracted typed fields;
- source input reference;
- confidence/ambiguity metadata where available;
- missing required fields;
- validation result.

The model does not decide persistence.

## Raw preservation rule

Interpretation failure must not lose user input.

If safe structure cannot be produced:
- preserve as raw memory when the user expects saving;
- clearly communicate that it was saved without stronger interpretation;
- allow later correction/reclassification.

Do not silently discard.

## Saved result and later use

- Report saving only after persistence succeeds; make failure visible and keep
  the input available for retry rather than presenting a false success.
- Show the destination of the saved result. Raw and contextual Notes remain
  accessible from Notes even without AI metadata.
- Reopening the app must not lose a successfully saved memory.
- Let the user inspect and correct the stored result. AI reclassification must
  not silently rewrite the original wording or confirm performed work.
- An intention such as "replace the wipers" remains a Note unless a supported
  proposal and policy explicitly permit another operation. It is not proof of
  completion and does not implicitly create a reminder or Road milestone.

## ConfirmationPolicy

Deterministic outcomes:

```text
autoAcceptSafe
confirmCompact
clarify
preserveRaw
rejectUnsupported
```

Policy inputs may include:
- proposal kind;
- mutation impact;
- ambiguity;
- required field completeness;
- conflicting existing facts;
- source.

Examples requiring confirmation or clarification:
- maintenance completion that resets an anchor;
- exact vehicle fact used for recommendation applicability;
- custom maintenance interval change;
- replacement of an existing known fact.

A low-risk raw Note may be auto-accepted if product UX validates this behaviour.

## Clarification

Ask one thing at a time.

Prefer:
- Yes / No;
- 2–4 choices;
- `Other`;
- `I don't know`.

Do not turn clarification into a form.

## Domain mutation boundary

Only deterministic domain commands mutate product state.

Examples:

```text
CreateNote
RecordOdometerReading
RecordVehicleFact
ConfirmMaintenanceCompletion
SetMaintenancePolicy
RecordVehicleEvent
RecordExpense
```

Commands validate invariants independently of AI.

## Context

Current screen context provides priors, not constraints.

Example:
- input captured from Service may become a Note;
- input captured from Notes may become a maintenance completion proposal.

## System integration

### Siri / App Intents

Conceptual intent:

```text
RememberInPitStopIntent
```

The intent produces `CaptureInput`. It does not construct arbitrary domain entities directly.

### Widget

Target flow:

```text
widget tap → capture surface → listening/capture
```

Do not route through Car Board first.

Investigate microphone activation and latency constraints.

## Observability

Log stages with correlation ID:
- capture_received;
- interpretation_started;
- interpretation_completed;
- proposal_validated;
- confirmation_required;
- clarification_required;
- domain_command_created;
- mutation_completed;
- raw_preserved;
- pipeline_failed.

Do not log raw content.

## Analytics questions

- source distribution;
- time to saved memory;
- proposal kind distribution;
- clarification rate;
- confirmation rate;
- raw-preservation rate;
- correction/reclassification rate;
- pipeline abandonment;
- AI-unavailable fallback rate.

## Test-first scenarios

1. every source maps to `CaptureInput`;
2. screen context does not force proposal kind;
3. valid low-risk proposal maps to a command;
4. maintenance completion cannot reset a cycle before confirmation policy permits;
5. conflicting vehicle fact requires safe handling;
6. unsupported interpretation preserves raw input;
7. AI unavailable preserves raw input;
8. only domain commands mutate persistence;
9. telemetry excludes raw content;
10. correlation ID spans the pipeline;
11. one clarification at a time;
12. cancellation performs no mutation.
13. explicit raw mode uses no model and reaches the same validation/command path;
14. saved raw Notes remain findable after relaunch without classification;
15. persistence failure does not report successful saving.

## Acceptance criteria

Implements core constraint C4 ([`../core.md`](../core.md#constraints)).

- one pipeline for all sources;
- no source-specific domain mutation path;
- no direct AI persistence;
- raw input is not lost;
- confirmation is risk-based;
- domain commands own mutation;
- pipeline is testable without UI.

## Failure criteria

- Siri creates SwiftData entities directly;
- Pit has a separate interpretation stack;
- model output is persisted as truth;
- unsupported input disappears;
- every AI result requires a large confirmation form;
- screen context hard-locks interpretation.

## Related specifications

- `../engineering/ai-architecture.md` — runtime AI trust boundary and model roles
- `../engineering/domain-inventory.md` — capture types not present on `main` today
- `product-charter.md` — Remember product job
- `../planning/ai-roadmap.md` — deferred AI direction (not a pipeline contract)
- `../PROJECT_STATUS.md` — freeze / resume status

## Requirements

Status `proposed` means derived from the contract text above and awaiting owner approval.

### REQ-CAPTURE-001 — Raw mode saves without a model through the shared path
Status: proposed
Core: P1, P3, C4
Source: [Two modes, one capability](#two-modes-one-capability); [Pipeline](#pipeline); [Test-first scenarios](#test-first-scenarios) 13
Given the user chooses explicit Raw Remember
When a CaptureInput is submitted
Then a `rawNote` MemoryProposal is created without a SemanticInterpreter call, and it passes through ProposalValidator, ConfirmationPolicy, and a DomainCommand like any other proposal

### REQ-CAPTURE-002 — Every source enters one pipeline as CaptureInput
Status: proposed
Core: C4
Source: [Two modes, one capability](#two-modes-one-capability); [Sources](#sources); [Test-first scenarios](#test-first-scenarios) 1; [Acceptance criteria](#acceptance-criteria); [Failure criteria](#failure-criteria)
Given any capture source (Pit voice, Pit text, direct app capture, widget, Siri, App Shortcuts)
When the user captures a thought
Then the source produces a CaptureInput, and the same pipeline processes it, with no source-specific interpretation stack

### REQ-CAPTURE-003 — Sources never construct domain entities
Status: proposed
Core: C4
Source: [Sources](#sources); [Siri / App Intents](#siri--app-intents); [Acceptance criteria](#acceptance-criteria); [Failure criteria](#failure-criteria)
Given a capture source such as `RememberInPitStopIntent`
When it is invoked
Then it emits only a CaptureInput, and no domain entity is created or persisted outside a DomainCommand

### REQ-CAPTURE-004 — Only domain commands mutate persistence
Status: proposed
Core: P3, C4
Source: [Pipeline](#pipeline); [MemoryProposal](#memoryproposal); [Domain mutation boundary](#domain-mutation-boundary); [Test-first scenarios](#test-first-scenarios) 8; [Acceptance criteria](#acceptance-criteria); [Failure criteria](#failure-criteria)
Given a MemoryProposal from raw or interpreted mode
When the pipeline processes it
Then persistence changes only by executing a DomainCommand, and model output is never written to persistence directly

### REQ-CAPTURE-005 — Cancellation performs no mutation
Status: proposed
Core: P3
Source: [Pipeline](#pipeline); [Test-first scenarios](#test-first-scenarios) 12
Given a capture in progress in raw or interpreted mode
When the user cancels
Then no domain mutation and no persistence change occurs

### REQ-CAPTURE-006 — Unsupported meaning degrades to raw preservation
Status: proposed
Core: P1
Source: [MemoryProposal](#memoryproposal); [Raw preservation rule](#raw-preservation-rule); [Test-first scenarios](#test-first-scenarios) 6; [Acceptance criteria](#acceptance-criteria); [Failure criteria](#failure-criteria)
Given a CaptureInput whose interpretation is unsupported or cannot produce safe structure
When the user expects saving
Then the input is preserved as raw memory, and it is not silently discarded

### REQ-CAPTURE-007 — AI unavailable preserves raw input
Status: proposed
Core: P1, P3
Source: [Raw preservation rule](#raw-preservation-rule); [Test-first scenarios](#test-first-scenarios) 7
Given the SemanticInterpreter is unavailable
When the user captures a thought
Then the input is preserved as raw memory without loss

### REQ-CAPTURE-008 — Raw-preserved result is communicated as such
Status: proposed
Core: P1
Source: [Raw preservation rule](#raw-preservation-rule)
Given input was preserved without stronger interpretation
When the saved result is shown
Then the user is told it was saved without stronger interpretation

### REQ-CAPTURE-009 — Saving is reported only after persistence succeeds
Status: proposed
Core: P1
Source: [Saved result and later use](#saved-result-and-later-use); [Test-first scenarios](#test-first-scenarios) 15
Given a DomainCommand whose persistence fails
When the pipeline completes
Then no successful save is reported, and the failure is visible and the input remains available for retry

### REQ-CAPTURE-010 — Saved result shows its destination
Status: proposed
Core: P1
Source: [Saved result and later use](#saved-result-and-later-use)
Given persistence succeeded
When the saved result is shown
Then it identifies where the memory was saved

### REQ-CAPTURE-011 — Saved Notes survive relaunch without classification
Status: proposed
Core: P1, P3
Source: [Saved result and later use](#saved-result-and-later-use); [Test-first scenarios](#test-first-scenarios) 14
Given a raw or contextual Note was saved successfully without AI metadata
When the app is relaunched
Then the Note is still present and findable from Notes

### REQ-CAPTURE-012 — Stored result can be inspected and corrected
Status: proposed
Core: P1
Source: [Raw preservation rule](#raw-preservation-rule); [Saved result and later use](#saved-result-and-later-use)
Given a saved memory, including one preserved as raw
When the user opens it
Then the user can inspect the stored result and correct or reclassify it

### REQ-CAPTURE-013 — Reclassification keeps original wording and confirms no work
Status: proposed
Core: P1, P3, C5
Source: [Saved result and later use](#saved-result-and-later-use)
Given a saved memory with original wording
When AI reclassification is applied
Then the original wording is unchanged, and no maintenance completion is confirmed as a result

### REQ-CAPTURE-014 — An intention remains a Note
Status: proposed
Core: C5
Source: [Saved result and later use](#saved-result-and-later-use)
Given a capture expressing an intention such as "replace the wipers"
When no supported proposal and policy explicitly permit another operation
Then it is saved as a Note, and no maintenance completion, reminder, or Road milestone is created

### REQ-CAPTURE-015 — ConfirmationPolicy is deterministic
Status: proposed
Core: P3
Source: [ConfirmationPolicy](#confirmationpolicy)
Given identical policy inputs for a validated MemoryProposal
When ConfirmationPolicy evaluates it
Then it returns the same outcome, one of `autoAcceptSafe`, `confirmCompact`, `clarify`, `preserveRaw`, `rejectUnsupported`

### REQ-CAPTURE-016 — Maintenance completion needs confirmation before a cycle reset
Status: proposed
Core: P3, C5
Source: [ConfirmationPolicy](#confirmationpolicy); [Test-first scenarios](#test-first-scenarios) 4
Given a `maintenanceCompletion` proposal that would reset an anchor
When ConfirmationPolicy has not permitted the mutation
Then no maintenance cycle is reset, and the policy outcome requires confirmation or clarification

### REQ-CAPTURE-017 — Exact or conflicting vehicle facts need confirmation
Status: proposed
Core: P3, C2
Source: [ConfirmationPolicy](#confirmationpolicy); [Test-first scenarios](#test-first-scenarios) 5
Given a `vehicleFact` proposal that conflicts with or replaces a known fact, or sets an exact fact used for recommendation applicability
When ConfirmationPolicy evaluates it
Then the outcome is `confirmCompact` or `clarify`, not `autoAcceptSafe`

### REQ-CAPTURE-018 — Custom maintenance interval change needs confirmation
Status: proposed
Core: P3
Source: [ConfirmationPolicy](#confirmationpolicy)
Given a proposal that changes a custom maintenance interval
When ConfirmationPolicy evaluates it
Then the outcome is `confirmCompact` or `clarify`, not `autoAcceptSafe`

### REQ-CAPTURE-019 — Valid low-risk proposal maps to a command without a large form
Status: proposed
Core: P3
Source: [ConfirmationPolicy](#confirmationpolicy); [Test-first scenarios](#test-first-scenarios) 3; [Acceptance criteria](#acceptance-criteria); [Failure criteria](#failure-criteria)
Given a valid low-risk MemoryProposal
When the pipeline processes it
Then DomainCommandMapper produces a DomainCommand, and no large confirmation form is required

### REQ-CAPTURE-020 — Clarification asks one thing at a time
Status: proposed
Core: C3
Source: [Clarification](#clarification); [Test-first scenarios](#test-first-scenarios) 11
Given ConfirmationPolicy returns `clarify`
When clarification is presented
Then exactly one question is asked at a time, and clarification is not presented as a form

### REQ-CAPTURE-021 — Domain commands validate invariants independently of AI
Status: proposed
Core: P3
Source: [Domain mutation boundary](#domain-mutation-boundary)
Given a DomainCommand that violates a domain invariant
When it is executed, regardless of whether AI produced the proposal
Then the command rejects it and no mutation occurs

### REQ-CAPTURE-022 — Screen context is a prior, not a constraint
Status: proposed
Core: C4
Source: [Context](#context); [Test-first scenarios](#test-first-scenarios) 2; [Failure criteria](#failure-criteria)
Given a CaptureInput with a `visibleFeature` such as Service or Notes
When a proposal is created
Then the proposal kind is not forced by that feature

### REQ-CAPTURE-023 — Widget opens capture directly
Status: proposed
Core: C4
Source: [Widget](#widget)
Given the Home Screen widget
When the user taps it
Then the capture surface opens without routing through Car Board first

### REQ-CAPTURE-024 — Correlation ID spans the pipeline
Status: proposed
Core: C4
Source: [Observability](#observability); [Test-first scenarios](#test-first-scenarios) 10
Given one CaptureInput processed by the pipeline
When pipeline stages are logged
Then every logged stage for that input carries the same correlation ID

### REQ-CAPTURE-025 — Telemetry excludes raw content
Status: proposed
Core: P1
Source: [Observability](#observability); [Test-first scenarios](#test-first-scenarios) 9; [CaptureInput](#captureinput)
Given a CaptureInput with text, transcript, or recognized document payload
When pipeline stages are logged
Then no log or telemetry event contains the raw content
