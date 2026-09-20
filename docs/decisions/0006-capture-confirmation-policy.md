# Capture Confirmation Policy and Mutation Permit

**Status:** Accepted for implementation (agent decision under owner delegation,
2026-09-20); owner review pending\
**Task:** DOM-003\
**Contract:** [`../requirements/capture-pipeline.md`](../requirements/capture-pipeline.md)

## Context

The contract names five confirmation outcomes and lists examples that need
confirmation, but it does not give the rule for each proposal kind, and it does
not say what stops code from mapping a proposal to a command without asking the
policy. Both had to be fixed before tests could be written.

## Decision

### Draft versus validated content

`MemoryProposal` keeps flat optional `extracted*` fields because a draft from
an interpreter is legitimately incomplete. `ProposalValidator` converts it into
`ValidatedContent`, an enum whose cases carry only non-optional required
fields. Everything after the validator works on the typed form, so a missing
field cannot reach a command.

The validator also requires `proposal.rawText` to equal the input's raw content
and `sourceInputID` to match. A producer that paraphrases the user is treated
as untrusted and the input is preserved raw (core P1, REQ-DOMAIN-011).

### Outcome table

| Validation result | Outcome |
|---|---|
| Blank input | `rejectUnsupported` |
| `reminderCandidate`, `unknown`, implausible value, future date, unreadable year, source or vehicle mismatch | `preserveRaw` |
| Supported kind with a missing required field | `clarify`, one field at a time |
| Any conflict with a known fact | `confirmCompact` |
| Note (raw or contextual) | `autoAcceptSafe` |
| Odometer reading, no conflict | `autoAcceptSafe`; `confirmCompact` if model confidence < 0.8 |
| Vehicle fact `name` with no known value | `autoAcceptSafe`; `confirmCompact` if model confidence < 0.8 |
| Vehicle fact `make`, `model`, `year`, `vin` | `confirmCompact` |
| Maintenance completion, policy change, vehicle event, expense | `confirmCompact` always |

Note kinds skip the vehicle and date guards. They are the raw fallback, so a
guard that rejected them would leave no path to a `CreateNote` command and the
wording would be lost (core P1). A note made for another vehicle is saved to
the single current car context (core C1).

A reading below the latest known reading is a conflict, not an error: the
earlier reading may be the wrong one, so the user decides. The provisional
name `My New Car` is a placeholder, so replacing it is not a conflict (core C2).

Confidence can only raise the required confirmation. It never makes an invalid
proposal valid, which keeps "AI confidence" and "domain validity" separate as
the domain model requires. A proposal without confidence comes from a
deterministic producer and is treated as certain about its own parse.

### Mutation permit

`DomainCommandMapper` takes a `MutationPermit` and nothing else. The permit's
initializer is file-private to `ConfirmationPolicy`, and the permit carries the
`ValidatedProposal` it authorizes; `ValidatedProposal` can only be created by
the validator. The policy issues a permit for `autoAcceptSafe`, or for
`confirmCompact` once the user confirmed. Because the mapper maps the content
inside the permit, a permit cannot be paired with other content, including a
second proposal that reuses the same ID. REQ-CAPTURE-016 therefore holds by
construction instead of by convention in each caller.

An earlier draft bound the permit to the proposal ID only. Independent review
showed that a caller-chosen ID let a note permit authorize a completion, so
that form was rejected.

A permit is a value and is not consumed. Applying one twice is prevented where
commands are executed (CAP-002), not here.

### Commands check themselves

`DomainCommand.validate(now:)` repeats the range, date, and amount checks. The
validator is the normal path, but commands will also be built by direct UI
entry (CB-003…005), which never passes through a proposal.

An expense is a `HistoryEvent` that must carry an amount, not a new entity:
money is an event attribute in the domain model.

## Raw pipeline pulled forward (CB-003)

`RememberPipeline.rememberRaw` was implemented with CB-003, ahead of CAP-001/002,
because Notes cannot "save a thought" without a capture path and core C4 forbids
a second, Notes-only path. It covers Raw Remember only: no interpreter, no
confirmation UI. It reports `saved` only after the store returned, maps blank
input to `nothingToSave`, and throws for any other non-valid validation so that
a future interpreted path cannot lose input by falling through. CAP-001/002
extend this type; they do not replace it.

`UpdateNoteCommand` is the user's own correction or archive action. "Original
wording is authoritative" constrains models, not the author: the user may
rewrite their note, and `DomainCommandMapper` never emits this command, so no
proposal, interpreted or raw, can reach it.

The Notes view model outlives its screen, so every visit resets to the active
main list with no context filter; a filter left over from an earlier visit
would hide unclassified notes (REQ-BOARD-012).

## Rejected alternatives

- **Typed associated values on `MemoryProposal.kind`.** Cannot represent a
  partially extracted draft, which is the normal interpreter output and the
  input to clarification.
- **A `confirmed: Bool` parameter on the mapper.** Any caller can pass `true`;
  the permit makes the policy the only source of authorization.
- **Rejecting a reading below the latest one.** Loses a correction the user
  may be making on purpose.
- **Auto-accepting high-confidence completions.** A completion resets a
  maintenance cycle (core C5); the cost of a silent wrong reset is higher than
  one tap.

## Open for owner review

- The 0.8 confidence floor is a placeholder until CAP-005 produces evaluation
  data.
- 5,000,000 km is a sanity bound, not a product rule. The future tolerance is
  five minutes of clock skew; a wider window would let "I will change the oil
  tomorrow" be confirmed as performed work (REQ-DOMAIN-009).
