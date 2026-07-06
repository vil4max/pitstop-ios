# Capture Pipeline Specification

**Status:** P0 architecture and product contract

## Product capability

The product action is **Remember**.

> Capture first. Interpret safely. Mutate deterministically.

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
SemanticInterpreter
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

## Acceptance criteria

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
