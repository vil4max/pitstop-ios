# AI Architecture

## Trust boundary

> AI interprets human input. AI does not own product truth.

Runtime:

```text
CaptureInput
    ↓
Semantic Interpreter
    ↓
MemoryProposal
    ↓
Deterministic validation
    ↓
ConfirmationPolicy
    ↓
DomainCommand
    ↓
Domain mutation + persistence
```

Product analytics:

```text
Analytics evidence
    ↓
AI-assisted interpretation
    ↓
Product hypothesis
```

These are separate systems. Do not merge runtime semantic interpretation with AI Product Analyst workflows.

## Role of the model

Allowed roles:
1. Semantic Interpreter for Remember.
2. Clarification proposal generator.
3. Attention editor for bounded summaries.
4. Later: document extraction assistant.
5. Later: planned-vs-actual reconciliation assistant.

The model is not:
- the maintenance engine;
- the Road engine;
- persistence;
- a direct SwiftData writer;
- a diagnostic system;
- the owner of confirmation policy.

## Capture architecture

All sources produce `CaptureInput`.

```text
Pit voice
Pit text
Siri
App Shortcut
Widget capture
Direct app capture
Recognized document text
        ↓
CaptureInput
```

A source may add context:

```text
source
selectedVehicleID
visibleFeature
visibleEntityID
locale
timestamp
```

Context changes semantic priors. It must not constrain the interpreter to one domain.

Example: input from the Service screen may still become a Note.

## MemoryProposal

A model output is a typed proposal, never persisted truth.

Conceptual proposal kinds:

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

A proposal must be:
- typed;
- validatable without the model;
- inspectable;
- cancellable;
- convertible to deterministic domain commands;
- observable through privacy-safe telemetry.

If confidence or domain support is insufficient, preserve the input as a raw memory proposal rather than invent structure.

## Confirmation policy

Confirmation is a deterministic policy owned outside the model.

Possible outcomes:

```text
autoAcceptSafe
confirmCompact
clarify
preserveRaw
rejectUnsupported
```

Always investigate/confirm high-impact mutations such as:
- maintenance completion that resets a cycle;
- exact vehicle facts used for applicability;
- destructive replacement of existing data;
- custom maintenance interval changes.

Do not ask for confirmation merely because AI was involved. Confirmation cost must correspond to mutation risk and ambiguity.

## Foundation Models

Apple Foundation Models may be a preferred local interpreter where available and validated.

Availability must be checked.

The product must survive:
- ineligible device;
- Apple Intelligence disabled;
- model unavailable;
- unsupported language quality;
- generation failure;
- schema failure.

Fallback order is a product/architecture decision to validate. The safe terminal fallback is preserving the raw capture.

## Pit and AI

Pit is a product interaction layer, not the model.

Pit may:
- open capture;
- show a proposal;
- ask one clarification;
- communicate completion;
- progressively ask a high-value question.

Pit must not imply model certainty where the proposal is ambiguous.

## Testing

Test:
- source-to-`CaptureInput` mapping;
- interpreter schema decoding;
- proposal validation;
- confirmation policy;
- proposal-to-command mapping;
- unsupported/ambiguous fallback;
- AI unavailable fallback;
- raw input preservation;
- privacy-safe telemetry.

Model quality evaluation is separate from deterministic unit tests.

## Related specifications

- `34_CAPTURE_PIPELINE_SPEC.md` — Capture / Remember pipeline owner
- `02_DOMAIN_MODEL.md`
- `03_MAINTENANCE_ENGINE.md`
- `33_PIT_BEHAVIOR_AND_MOTION_SPEC.md`
- `30_AI_PRODUCT_ANALYTICS.md` — separate AI Product Analyst workflow
- `39_DOMAIN_INVENTORY.md` — implementation snapshot (`main`)
- `40_AI_ENGINEERING_ROADMAP.md` — deferred AI roadmap (not an implementation contract)
- `../PROJECT_STATUS.md` — freeze / resume status
