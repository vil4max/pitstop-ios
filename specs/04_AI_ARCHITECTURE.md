# AI Architecture

## Role of the local model

Foundation Models is an interface layer between human language and the
deterministic PitStop domain.

Allowed roles:

1.  **Input Interpreter**
2.  **Attention Editor**
3.  Later: **document extraction assistant**
4.  Later: **planned-vs-actual reconciliation assistant**

The model is not the maintenance engine.

## Input Interpreter

Pipeline:

``` text
text / transcript / recognized document text
        ↓
InputInterpreter
        ↓
structured draft
        ↓
domain validation
        ↓
user confirmation
        ↓
domain command
        ↓
persistence
        ↓
recalculation
```

Initial supported intents:

``` text
note
odometer
carWashHistory
basicServiceHistory
```

Later:

``` text
insurance
purchase
maintenancePolicyDraft
documentServiceDraft
```

## Draft rule

A model output is a draft, never persisted truth.

Every draft must be: - typed; - validatable without the model; -
editable; - cancellable; - observable through non-sensitive telemetry.

## Fallback

Foundation Models availability must be checked.

Core product behavior must survive: - ineligible device; - Apple
Intelligence disabled; - model unavailable; - unsupported language
behavior; - generation error.

Fallback: - Notes always work. - Manual odometer update always works. -
Explicit maintenance/history flows remain available. - Unsupported
natural input may be saved as a raw note after user confirmation.

## Guided generation before broad tool calling

Use the smallest model capability that solves the task.

Preferred progression:

``` text
typed guided generation
→ evaluation
→ only then tool calling where the model truly needs app knowledge/actions
```

Tool calling is justified when the model must retrieve current app state
or invoke bounded domain capabilities.

Example future tools:

``` text
searchActiveNotes(context)
getMaintenanceSnapshot()
getOperationHistory(operationID)
```

Mutation tools should be approached conservatively. Prefer drafts and
explicit domain commands.

## Evaluations are part of the feature

Every supported intent requires a golden dataset.

Initial minimum: 50 real phrases.

Coverage: - Russian; - Ukrainian automotive vocabulary in otherwise
Russian speech; - English automotive terms; - typos; - speech-like
fragments; - omitted currency; - relative dates; - ambiguous operation
names; - unsupported requests.

For each case record:

``` text
input
expected intent
expected required fields
allowed optional differences
must ask/confirm ambiguity
must not infer
```

Model quality gates:

``` text
supported intent classification ≥ 90% on local golden set
critical numeric extraction ≥ 95%
unsafe silent mutation = 0
unsupported input data loss = 0
```

These are initial engineering gates, not claims of statistical product
quality.

## Tool-calling evaluation

When tools are introduced, evaluate: - expected tool trajectory; -
argument values; - call ordering; - no unnecessary mutation call; - no
repeated tool loop.

## Prompt/version observability

Every interpretation result should have non-sensitive technical metadata
available locally/logged:

``` text
interpreterVersion
model availability state
intent
latency bucket
result type
validation outcome
draft edited?
saved?
```

Do not log raw input in production telemetry by default.

Debug builds may support an explicit local-only AI trace.

## Attention Editor

Input: - deterministic `MaintenanceSnapshot`; - selected relevant
notes/counts; - no hidden world knowledge required.

Output: - one short title; - one short detail; - optional highlighted
entity ID.

Constraints: - cannot change severity; - cannot invent vehicle
condition; - cannot invent a due date; - deterministic fallback always
exists.

## AI feature success criteria

A natural-input feature is successful when it reduces input friction
without reducing trust.

Measure: - save rate; - edit-before-save rate; - cancel rate; - fallback
rate; - interpretation latency; - repeated retry rate.

Failure: - user learns prompt tricks; - drafts need routine structural
repair; - AI feature becomes required to access a core capability; -
telemetry requires collecting private raw notes to understand basic
failures.
