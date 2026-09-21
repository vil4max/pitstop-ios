# Interpretation Deadline and Cancellation

**Status:** Accepted for implementation (agent decision under owner delegation,
2026-09-21); owner review pending. The deadline value is a hypothesis.\
**Task:** CAP-006\
**Contracts:** [`../requirements/capture-pipeline.md`](../requirements/capture-pipeline.md)
(REQ-CAPTURE-005, 006, 007, 008),
[`0006-capture-confirmation-policy.md`](0006-capture-confirmation-policy.md),
[`0011-interpreted-capture-without-a-model.md`](0011-interpreted-capture-without-a-model.md)

## Context

CAP-002 made an unavailable interpreter safe: a thrown error or "no meaning"
saves the wording raw. Two cases were still open before a model is wired in
CAP-005:

- **An interpreter that never answers.** The pipeline awaited it without limit.
  The Pit surface stayed in its working state with Close and swipe-to-dismiss
  disabled, so the user was stuck and the input was never saved. A model that stalls is
  as unavailable as one that throws.
- **A cancelled capture could still write.** The interpreter's
  `CancellationError` was treated like any other failure, so the wording was
  then saved raw, contradicting REQ-CAPTURE-005. Nothing cancels a capture
  task today, but App Intents and Siri (SYS-*) will.

## Decision

- `RememberPipeline` asks the interpreter through an `InterpretationDeadline`.
  When the deadline passes first, the capture continues exactly as if the
  interpreter had found no meaning: the wording is saved, the user is told it
  was saved as written (REQ-CAPTURE-008), and `raw_preserved` is reported.
- The race resumes the caller as soon as either side finishes and never awaits
  the loser. The loser is cancelled, so a cooperative interpreter stops; one
  that ignores cancellation is simply abandoned rather than awaited.
- The default limit is **6 seconds**. It is long enough for a short on-device
  generation and short enough that a stalled one does not feel like a hang. It
  is injectable, so tests decide the race instead of waiting on a clock.
- **A cancelled capture writes nothing.** A capture cancelled during
  interpretation stops right after it, before any store read, so a
  cancellation-aware read cannot turn it into a "not saved, retry" failure. The
  last point before a write checks again as the backstop that every path goes
  through: raw, interpreted, confirmed and clarified captures all obey it. Both
  report `capture_discarded` and return `nothingToSave`. This widens
  `capture_discarded`, which ADR 0006 still lists as a proposed stage pending
  owner approval, from blank input to cancellation.
- A timed-out interpretation is reported as `interpretation_completed` with no
  proposal kind, the same way a thrown interpreter error already was.

## Rejected alternatives

- **A task group with a timeout child.** A task group waits for every child
  when it ends, so an interpreter that ignores cancellation would still hold
  the capture until it returned.
- **No deadline until a model exists.** The fallback is the safety net for that
  model; adding it after CAP-005 would ship the model first and the net second.
- **A new `cancelled` outcome.** Callers that cancel do not read the result,
  and the surface already treats `nothingToSave` as "back to composing".
  Another case would widen every switch for no reader.

## Open for owner review

- The 6-second limit. Evidence to collect with CAP-005: interpretation latency
  on device, and how often captures fall back because of the deadline rather
  than because nothing was understood.
