# First Pit Question: Current Mileage

**Status:** Accepted for implementation (agent decision under owner delegation,
2026-09-21); owner review pending\
**Task:** DISC-002\
**Contracts:** [`../requirements/pit-behavior-and-motion.md`](../requirements/pit-behavior-and-motion.md)
(REQ-PIT-002, 003, 006–012, 018–020),
[`../requirements/car-board-screen.md`](../requirements/car-board-screen.md) (REQ-BOARD-026),
[`../requirements/road-domain-and-ui.md`](../requirements/road-domain-and-ui.md) (REQ-ROAD-006),
core C2, C3 and C4, [`0010-maintenance-engine-rules.md`](0010-maintenance-engine-rules.md),
[`0012-pit-presence-and-attention.md`](0012-pit-presence-and-attention.md),
[`0016-question-registry.md`](0016-question-registry.md)

## Context

ADR 0016 built the question registry and persisted question state, but the
product list was empty and nothing in the app asked anything. The card asks for
one question that measurably improves Service or Road.

Service and Road already know exactly when they cannot do their arithmetic.
ADR 0010 counts remaining kilometres only from a current mileage observation:
the newest odometer reading or completion mileage (REQ-BOARD-026), and only
while it is at most 90 days old. Otherwise a distance rule is blocked with a
named reason (`DistanceBlock.mileageUnknown` or `.mileageStale`), Service shows
no kilometres for it, and Road moves a mileage-only milestone to its "waiting
for mileage" list (REQ-ROAD-006). Core C2 forbids filling the gap by estimation.

## Decision

### The question: "What is on the odometer now?"

`CurrentMileageQuestion` (`service.currentMileage`) is the only product
question. It belongs to Service, unlocks `serviceStatus`, and has priority 10.

Why this question first:

- **One fact feeds every distance rule.** A single reading unblocks every
  tracked operation whose distance rule is blocked by the car's mileage, on
  Service and Road at once. No other missing fact has that reach.
- **The need is computed, not guessed.** The engine already reports the block,
  so relevance is a pure function of existing state with no new heuristics.
- **It is cheap and certain to answer.** The user reads one number off the
  dashboard; there is no judgement, unit ambiguity, or interval to recall.
- **It needs no new write path.** The answer is an ordinary
  `DomainCommand.recordOdometerReading`, validated and stored exactly as a
  reading from the car editor (core C4).

### Relevance gates the policy

A registered question is offered only when its answer would change something
now (core C3). `PitQuestionRegistry.relevantQuestionIDs(maintenance:)` maps each
product ID to a relevance rule; an ID without a rule is never relevant, so a
future question cannot be asked by accident. The mileage question is relevant
while at least one operation has `distanceBlock` `mileageUnknown` or
`mileageStale`. `completionMileageMissing` does not count: today's reading
cannot fix a completion saved without mileage.

The relevant set filters the registry before `PitAttentionPolicy` runs, so the
policy's own rules still decide: idle UI (REQ-PIT-006), the question's surface
(REQ-PIT-007), unresolved only (REQ-PIT-008), a declared unlock (REQ-PIT-009),
and the 12-hour interruption and 7-day dismissal cooldowns derived from
persisted state (REQ-PIT-010).

### Asking, answering, and declining

`PitQuestionViewModel` reads the car's facts, runs the engine, and asks the
policy. It records `asked` before it shows anything; if that write fails, Pit
stays silent rather than ask without a cooldown. The root view evaluates two
seconds after each navigation, so arriving is not treated as idleness. The
activity comes from `PitPresenceModel`. When this ADR shipped it knew only
about the Pit and Settings sheets and Reduce Motion (the ADR 0012 limit), so Pit
could ask while an editor sheet was open; amended by ADR 0019, which reports
editor sheets, scrolling, and focused fields.
The activity is read live, once for the policy and again right before `asked`
is recorded, because the reads in between suspend; if the interface stopped
being idle meanwhile, nothing is recorded or shown.

Reduce Motion is not activity. `PitAttentionPolicy.allowsInterruption` ignores
it, so it changes how Pit asks, never whether. Before this, the policy required
the raw activity to be empty, and with Reduce Motion on Pit could never ask.

A question that is asked makes Pit startle, then knock (ADR 0012); with Reduce
Motion the knock is shown without the startle or animation (REQ-PIT-018). The
Pit control gains the accessibility value "Has a question", stated as a value
rather than announced (REQ-PIT-019).

Opening Pit keeps Remember as the primary surface (REQ-PIT-013). A pending
question is a compact card above the composer: the user can write and save a
note without touching it, and the question stays pending; or answer or decline
it in the same sheet. Only one question is ever shown (REQ-PIT-003). With a
question pending the composer does not take focus on open, so the keyboard does
not cover the card. The card uses standard controls: a heading,
the reason, the last recorded mileage labelled as history (never as today's,
REQ-PIT-002), a number field, Save, "I don't know yet", and "Don't ask"
(REQ-PIT-020).

- **Save** validates the text like the car editor, writes the reading with a
  domain command, and only then records `answered`. If the reading fails, the
  question stays open with an error. If only the resolution fails, the mileage
  is current anyway, so relevance keeps the question from returning.
- **I don't know yet** records `deferred` and writes nothing about the car.
  The mileage stays unknown or stale (core C2), and Service keeps naming the
  blocked rule. One control covers "I don't know" and "later": both mean the
  fact is not available now, and two buttons with the same effect would only
  add a choice.
- **Don't ask** records `dismissed`, which starts the 7-day dismissal cooldown
  for every question; the mileage question itself never returns
  (`afterDismissal: .never`).
- Closing the sheet, or saving a note, without choosing leaves the question
  pending: Pit keeps knocking until one of the three is chosen.
- **The fact arrives another way.** After every capture save the pending
  question's relevance is checked again (`revalidate()`). If a mileage said to
  Pit (a mileage such as "odometer 84200") already unblocked the rules, the question goes quiet
  and Pit stops knocking, with no resolution recorded: nothing was answered or
  declined, so it may be asked again when the mileage goes stale. Filling the
  card afterwards would only record a redundant reading. A read failure keeps
  the question, because the facts are then unknown. The same check runs after
  every navigation, so a reading saved in the car editor silences the question
  once the user moves on.

After an answer, the visible surface and Car Board reload under the sheet, and
the card is replaced by "Mileage saved: N km" above the composer.

### Declared value and deferral path

- **Claim:** every tracked operation whose distance rule was blocked by unknown
  or stale mileage gets remaining kilometres on Service, and its mileage
  milestone leaves Road's waiting list.
- **Without an answer:** Service keeps the distance rule blocked and names the
  reason; a time rule still decides a partial status. The user can record
  mileage in the car editor at any time.
- **Return:** `notBefore(14 days)` after a deferral, `never` after a dismissal,
  and `notBefore(90 days)` after an answer, the time a reading counts as
  current (ADR 0018). The question also has to be relevant again.

### How the value is measured

- **Mechanism, now:** `MileageQuestionEndToEndTests` drives the real SwiftData
  stores on one container: before the answer Service reports the oil rule as
  `mileageStale` with no kilometres and Road lists it as waiting for mileage;
  after the answer both show 2,000 km remaining. The relevance rule guarantees
  that every ask can unblock at least one rule.
- **Product, in the beta:** once analytics exists (ANL-001), record per
  question the outcome (answered, deferred, dismissed) and, for an answer, the
  number of operations whose distance block cleared. Never record the mileage
  itself. The claim holds if answers clear at least one block and the
  answer rate beats dismissals. Until then, persisted question state already
  holds the outcome per device.

### App wiring

`AppEnvironment` builds `SwiftDataPitQuestionStore` on the car memory's
container. If the container cannot be opened, `UnavailablePitQuestionStore`
fails every call, so `asked` cannot be recorded and Pit asks nothing. If the
product registry were rejected (a test builds it, so only a skipped gate
could cause this), the app logs the error and uses `PitQuestionRegistry.empty`.

DEBUG launch arguments for tap-free smoke checks: `-pitstop-demo-stale-mileage`
(with `-pitstop-demo-data`) ages the demo reading to 120 days, and
`-pitstop-show-question` opens Pit as soon as it asks.

## Rejected alternatives

- **Oil or other interval questions ("How often do you change oil?").** A
  policy answer changes one operation, and defaults already exist for it. The
  mileage reading changes every distance rule.
- **"When was the last service?"** Answering it well needs the date, the
  mileage, and the operation: a capture flow, not a one-field question, and
  it belongs to confirmation through the Capture Pipeline.
- **Asking on Road or Car Board too.** Service is where the blocked rule is
  named and explained, so the question arrives with its reason. Road benefits
  from the same answer without a second question.
- **Prefilling the field with the last known mileage.** It would invite the
  user to confirm an old number as today's (core C2). The last value is shown
  as history only.
- **A new question-specific write, or writing the reading from the view.**
  Core C4: car facts change only through domain commands; the existing
  `recordOdometerReading` validates the value like every other reading.
- **Estimating mileage from time and past readings.** Core C2 and ADR 0010
  forbid it.
- **A push notification when the mileage goes stale.** REQ-PIT-011 keeps
  questions in the app.
- **Separate "I don't know" and "Later" buttons.** Same effect and the same
  stored resolution; see above.
- **The question card in place of the composer.** The first implementation
  showed the card instead of the composer until the question was settled.
  Capture was then reachable only by deferring the question, which silences it
  for good (see open questions), so the user paid for a note with a lost
  question, against REQ-PIT-013.

## Open questions for owner review

- **Deferral return and final answers.** Resolved by ADR 0018 (DISC-003): a
  deferred mileage question returns after 14 days, an answered one after
  90 days, and either only while the mileage is stale or unknown. A dismissal
  stays final. The REQ-PIT-008 wording this relies on is proposed there.
- **Editor sheets are not reported as activity.** Resolved by ADR 0019
  (DISC-004): editor sheets are reported as modal tasks, and scrolling and
  focused fields as activity, so Pit no longer asks while one is open.
- **Pit keeps knocking after the user leaves Service.** The question is asked
  on Service, but the pending knock stays on every screen until it is settled,
  and the card can be answered from anywhere. In-memory only: after a relaunch
  the unresolved question waits out the 12-hour cooldown and is asked again on
  Service.
- **`mileageUnknown` is rare.** Since REQ-BOARD-026 a completion saved with its
  mileage is an observation, so a car with any completion mileage has at worst
  stale mileage. The rule keeps both reasons because both mean the same missing
  fact.
- **Priority 10 is arbitrary** with one question; the scale is set when the
  second question is registered.
