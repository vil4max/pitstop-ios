# Interpreted Capture Without a Model

**Status:** Accepted for implementation (agent decision under owner delegation,
2026-09-21); owner review pending\
**Task:** CAP-002\
**Contracts:** [`../requirements/capture-pipeline.md`](../requirements/capture-pipeline.md),
[`../engineering/ai-architecture.md`](../engineering/ai-architecture.md),
[`0006-capture-confirmation-policy.md`](0006-capture-confirmation-policy.md)

## Context

CAP-002 is "proposal and confirmation without a live model". The confirmation
path could not be built or tested while the only producer of proposals was the
raw factory, which always yields a `rawNote` that the policy auto-accepts: no
proposal ever needed confirming, so the branch did not exist.

A model is also out of scope by project gate (P4, CAP-005). The pipeline
therefore needs a producer that is not a model.

## Decision

### An interpreter is an adapter behind a protocol

`SemanticInterpreting` returns an optional proposal:

- `nil` means "no supported meaning here". It is an ordinary answer, not a
  failure, and the capture continues as Raw Remember.
- Throwing means the interpreter itself is unavailable. The input is preserved
  raw all the same (REQ-CAPTURE-007), and the caller is not told to retry.

`NoSemanticInterpreter` (proposes nothing) is the default, so every existing
caller keeps raw behaviour. `RuleBasedInterpreter` is the implementation used
until CAP-005; a Foundation Models adapter will be a third conformance and will
not change anything downstream.

### The rules are deliberately narrow

`RuleBasedInterpreter` proposes only three kinds, and only for explicit
phrasings in Russian and English:

| Recognised | Proposal |
|---|---|
| A past-tense verb of completion plus exactly one operation | `maintenanceCompletion` |
| A washing verb | `vehicleEvent(.carWash)`, with a price when one is written |
| A mileage word plus a plain number | `odometerReading` |

Everything else proposes nothing. Guards that matter more than the patterns:

- **Hedged wording is never a report of work.** "надо", "хочу", "пора",
  "should", "need to", a question mark, and the like suppress interpretation
  entirely. An intention stays a Note (REQ-CAPTURE-014).
- **Two operations in one sentence produce nothing.** That is a visit with
  several jobs, which this interpreter cannot express, and confirming half of
  it would be worse than saving the wording.
- **A number with a decimal separator is never a mileage.** It is a price or a
  volume. Mileage is the largest plain number of at least 100 that is within
  the domain's plausible range.

This is not language understanding, and it is not meant to grow into it. Its
job is to exercise the proposal, confirmation, and mutation path with real
data, and to keep interpreted mode useful when no model is available.

### What the pipeline returns

`RememberPipeline.remember(_:mode:)` now answers with one of:

- `saved(result, preservedRaw:)` — persisted. `preservedRaw` is true when no
  stronger meaning was applied, which is what the surface tells the user
  (REQ-CAPTURE-008).
- `needsConfirmation(PendingCapture)` — validated, but the policy demands
  confirmation. Nothing was written. `confirm(_:)` writes it; `preserveRaw(_:)`
  saves the wording instead; `cancel(_:)` writes nothing at all
  (REQ-CAPTURE-005).
- `needsClarification(ClarificationRequest)` — one field is missing. The
  request names that one field and counts the rest, so the surface asks one
  thing at a time (REQ-CAPTURE-020). `answer(_:with:)` takes a typed
  `ClarificationAnswer`; `.unknown` is a valid answer and preserves the raw
  wording.
- `nothingToSave` — blank input.

An answer can only add structure: `MemoryProposal.answering(_:)` copies the
draft and never touches `rawText` (REQ-DOMAIN-011).

Raw mode is the same code path with the raw factory and no interpreter call. It
cannot return `needsConfirmation`, because a raw note is always auto-accepted;
if it ever did, the pipeline reports `pipeline_failed` rather than silently
saving something else.

## Rejected alternatives

- **Waiting for CAP-005 to build the confirmation path.** It would leave the
  most safety-relevant branch of the pipeline untested until a model exists.
- **A model-shaped mock in tests only.** The app would have no working
  interpreted mode when the model is unavailable, and the mock would drift from
  the real path.
- **Broader patterns (fuzzy matching, stemming, synonym lists).** Every false
  positive here is a wrong confirmation prompt about the user's own car. The
  cost of proposing nothing is one extra tap; the cost of proposing wrongly is
  trust.
- **Letting the interpreter decide the outcome or the command.** The validator
  and the policy own that; the interpreter only suggests (core P3).

## Open for owner review

- The rule set covers Russian and English only, and no synonyms beyond the
  lists in the source. A user writing "менял масло вчера" is understood;
  "обслужил двигатель" is not, and is saved raw.
- Pit capture (CAP-004) defaults to interpreted mode and always shows "Save as
  written" next to it, so raw saving is one tap and never hidden.
