# Attention Cooldown and Question Return

**Status:** Accepted for implementation (agent decision under owner delegation,
2026-09-21); owner review pending. The intervals are hypotheses, to be revisited
with beta evidence.\
**Task:** DISC-003\
**Contracts:** [`../requirements/pit-behavior-and-motion.md`](../requirements/pit-behavior-and-motion.md)
(REQ-PIT-008, 010, 012; "Interruption budget"), core C3,
[`0012-pit-presence-and-attention.md`](0012-pit-presence-and-attention.md),
[`0016-question-registry.md`](0016-question-registry.md),
[`0017-first-question-current-mileage.md`](0017-first-question-current-mileage.md)

## Context

ADR 0012 made every resolution final: once a question was answered, deferred,
or dismissed, the attention policy never offered it again. ADR 0016 let each
question declare when it may return after a deferral or a dismissal, but the
policy ignored the declaration. ADR 0017 showed the cost with the first real
question: "I don't know yet" silenced the current-mileage question on the
device for good, and so did an answer, although a reading stops being current
after 90 days and the rules it unblocked are blocked again.

The contract asks for two things that pull in opposite directions: do not
repeat a deferred question (REQ-PIT-012), and interrupt only when the answer
unlocks value (core C3). A question that never returns fails the second as
surely as one that returns every day fails the first.

## Decision

### Every resolution has a declared return

`PitDeferralPath` gains `afterAnswer` next to `afterDeferral` and
`afterDismissal`. Each is `never` or `notBefore(interval)`, measured from
`PitQuestionState.resolvedAt`, and the registry rejects a non-positive
interval for any of the three. A question is declared with all three, so the
return behaviour of every product question is visible in one place.

`PitDeferralPath.hasReturned(_:now:)` answers whether a stored resolution has
run its course. `PitQuestionRegistry.questions(with:now:)` joins a returned
question as `unresolved`, so the attention policy's existing filter
(`resolution == .unresolved`) enforces the declared path without a second rule.
The policy's registry entry points pass their `now`, so every caller that asks
the policy from persisted state gets the return rules.

A resolved row without `resolvedAt` cannot be measured and stays closed.
Commands always set both, so only a damaged row can lack it, and silence is the
safe direction (core C3). For the same reason an unreadable stored resolution
now reads as a new `PitQuestion.Resolution.closed`, which has no return rule,
instead of `deferred` (ADR 0016), which would now return after the question's
deferral interval. No command produces `closed`; an answer or a decline
replaces it like any other resolution.

### An answer holds for its interval; relevance decides after that

An answered question returns only when both hold:

1. its `afterAnswer` interval has passed, and
2. its relevance rule (ADR 0017) says an answer would change something now.

The interval is repeat suppression: whatever the facts do, the user is not
asked for the same answer again sooner. Relevance is the value test: past the
interval, the question stays quiet for as long as the answer, or any newer
fact, still unlocks what the question promised.

For the current-mileage question `afterAnswer` is
`notBefore(MaintenanceRules.mileageStaleAfter)`, the 90 days for which the
engine counts a reading as current. The answer holds exactly as long as the
reading it wrote. After that the question returns only if no newer mileage
arrived: a reading from the car editor or a capture keeps the mileage current,
the question irrelevant, and Pit silent.

### Deferral and dismissal follow their own declarations

- A deferred question returns after `afterDeferral`: 14 days for the mileage
  question, if the mileage is still stale or unknown then.
- A dismissed question returns after `afterDismissal`; `never` for the mileage
  question. A dismissal of any question still starts the global 7-day
  dismissal cooldown (ADR 0012), so a dismissal silences every other question
  for 7 days and itself for as long as it declares.
- The 12-hour interruption cooldown is still global and still derived from the
  newest `lastAskedAt` across all questions, so a returned question also waits
  12 hours after any ask, including its own last one.

### Asking opens the question again

The `asked` command now resets the stored resolution to `unresolved` and
clears `resolvedAt`; `lastAskedAt` and `lastDismissedAt` are kept. The stored
resolution is therefore the outcome of the latest ask. Without this, a returned
answered question could not be declined (a deferral of an answered question is
rejected as `alreadyAnswered`), and a returned deferral would still carry the
old time. That guard still protects an answer that has not been asked again.

The command enforces the declared return itself: `PitQuestionCommand.applied`
takes the question's `PitDeferralPath`, and an `asked` for a resolved question
whose return has not come throws `notReturned`, so the store saves nothing. An
answer therefore cannot be turned back into a question by a caller that skipped
the attention policy; the policy and the store apply the same
`hasReturned` rule.

An ask that the user leaves unanswered behaves as before: the question is
unresolved, and it is asked again after the 12-hour cooldown while it is
relevant.

### No schema change

Everything is derived from the fields schema V2 already stores
(`resolution`, `lastAskedAt`, `lastDismissedAt`, `resolvedAt`) plus the
declarations in code. V1 and V2 are untouched and no migration is needed.

## Tests

`PitQuestionReturnTests` covers the policy with fixture questions and fixed
dates: a deferral returns only after its interval; a dismissal silences others
for 7 days and itself per its path; `never` stays never; an answer holds for
its interval and then only while relevant; a due return still waits 12 hours
after any ask; an ask reopens a returned question, and an ask before the
return (`never`, or inside the interval) is rejected; a resolution without a
time stays closed. `SwiftDataPitQuestionStoreTests` checks that a rejected ask
saves nothing and that an unreadable stored resolution reads as `closed` and
never returns. `MileageQuestionReturnTests.swift` (part of the
`PitQuestionViewModelTests` suite) covers the mileage question on a fake store:
an answer stays quiet while the mileage is current (including a newer editor
reading past the 90 days) and returns once it is stale; a deferral returns
after 14 days and can be deferred again; a dismissal never returns.
`MileageQuestionEndToEndTests` repeats, through a real SwiftData store reopened
from a file at each step: a deferral returning after 14 days, an answer
returning once the mileage is stale, the 12-hour repeat block, and a dismissal
that is still final a year later. At 90 days after the answer the reading is
still current, so that quiet step shows relevance and the answer interval
together, not the interval alone. The global 7-day dismissal silence across
questions needs a second question, so it is covered with fixtures
(`PitQuestionReturnTests`, and through SwiftData in
`SwiftDataPitQuestionStoreTests`), not end to end.

## Rejected alternatives

- **Relevance alone reopens an answered question.** Simple, and correct for
  the mileage question, but a future question whose answer does not clear its
  own relevance would be asked every 12 hours. The declared interval bounds the
  repetition for every question.
- **A per-question "answer holds" predicate over the car's facts.** More
  precise in theory, but relevance already is that predicate; a second one per
  question would be two rules that can disagree.
- **A new persisted field, such as `returnsAt` or an "answer valid until"
  date.** It would copy what `resolvedAt` and the declaration already give and
  need schema V3 and a migration. A changed declaration would also not reach
  rows written under the old one.
- **Keeping the stored resolution on re-ask and allowing a deferral after an
  answer when `lastAskedAt` is later than `resolvedAt`.** It keeps the old
  outcome visible, but spreads one rule over two commands and still leaves a
  returned deferral reading as the old one.
- **A shorter repeat window than the 90-day staleness for the mileage answer.**
  Relevance would keep the question silent anyway while the reading is current;
  a shorter interval only matters if the reading were deleted, and then asking
  again is the right outcome after 90 days too.

## Open questions for owner review

- **REQ-PIT-008 says an answered question "is not asked again".** This ADR
  reads it as "not asked again while its answer holds". Proposed wording, not
  applied: "Given a Pit question the user has answered, When Pit evaluates
  whether to interrupt while that answer still holds, Then that question is
  not asked again." The requirement stays `proposed` until the owner decides.
- **14 days after "I don't know yet"** is a guess. Evidence to collect with
  ANL-001: how often a returned deferral is answered versus deferred again. A
  question deferred repeatedly returns every 14 days for as long as the
  mileage stays stale; a back-off after repeated deferrals may be needed.
- **"Don't ask" is final for the mileage question.** A user who dismissed it
  keeps blocked distance rules until they record mileage elsewhere. Service
  names the reason, so the fact is not hidden, but a settings entry to reset
  dismissed questions may be wanted later.
- **Clock changes.** As in ADR 0016, a resolution time in the future delays a
  return until the clock catches up; that is the safe direction.
