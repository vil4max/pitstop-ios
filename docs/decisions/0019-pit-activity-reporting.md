# Pit Activity Reporting and the Motion Audit

**Status:** Accepted for implementation (agent decision under owner delegation,
2026-09-21); owner review pending.\
**Task:** DISC-004\
**Contracts:** [`../requirements/pit-behavior-and-motion.md`](../requirements/pit-behavior-and-motion.md)
(REQ-PIT-004, 005, 006, 017, 018; "Motion language", "Idle policy"),
[`0012-pit-presence-and-attention.md`](0012-pit-presence-and-attention.md),
[`0017-first-question-current-mileage.md`](0017-first-question-current-mileage.md),
[`0018-attention-cooldown-and-return.md`](0018-attention-cooldown-and-return.md)

## Context

ADR 0012 modelled what the interface is doing as `PitActivity` and made idle
motion stop, and questions wait, for any of it. Only the root view reported
anything: the Settings and Pit sheets and Reduce Motion. Car Board and the
feature screens scroll, their editor sheets take text, and none of that reached
Pit. Two consequences were recorded as limits in ADR 0012 and ADR 0017: Pit
could blink while the user scrolled or typed in an editor (against REQ-PIT-005),
and the mileage question could be asked while an editor sheet was open (against
REQ-PIT-006).

DISC-004 is "motion states required by accepted Pit behaviour only". So the
task is two things: check that every motion state the accepted behaviour
requires is triggered, and make the activity that silences motion and
questions real.

## Decision

### Activity is a union of reports, one per source

`PitActivitySources` (domain, a value) holds one `PitActivity` per
`PitActivitySource` and exposes their union. A source always reports its whole
current activity: a report replaces the source's previous one, and an empty
report withdraws it. Nothing is counted, so a source that reports twice is
still one source and one withdrawal clears it. Each reporting view instance
creates its own source, so two editors, or an editor and a scroll view, never
clear each other.

`PitPresenceModel` keeps these sources in place of the single interface value
it had, still apart from Reduce Motion and from a pending question.
`setInterface(_:)` became `report(_:from:)`. The root view reports the utility
sheets as the fixed source `utilitySheet`, exactly as before: the Pit sheet is
`capturing`, Settings is `modalTask`. Pit's own capture sheet is unchanged.

### Surfaces report through the environment

The root view puts a `PitActivityReporter` in the environment of its
navigation stack; it forwards to the root's `PitPresenceModel`. Screens do not
know Pit: they use three modifiers.

- `pitActivity(_:while:)` reports an activity while a condition holds. It
  reports on appear and on change, and withdraws on disappear, so a sheet
  closed by a swipe or a screen popped mid-task never leaves activity behind.
- `pitReportsScrolling()` sits on each scroll view: the vertical one in Car
  Board and in `FeatureScaffold` (Notes, History, Service, Road, and pending
  surfaces), the Road lane, and the Notes context chips. It reports `scrolling`
  while the scroll phase is anything but idle, and resets on disappear because
  a screen left mid-scroll gets no final phase change.
- `pitReportsEditing()` sits on each text field of the car editor, the history
  event editor, and the Service track and mark-done sheets. It reports
  `editing` while the field has focus. The note editor already binds focus, so
  it uses `pitActivity(.editing, while: isFocused)` rather than a second focus
  binding on the same field.

Every editor sheet and the Service undo confirmation is reported as
`modalTask` from the presenting screen, driven by the same state that presents
it: the car editor on Car Board, the note editor, the history event editor, and
the Service track, change-interval, and mark-done sheets.

The reporter is equal by the model it forwards to. The root view re-renders on
every blink; a reporter built from a fresh closure each time would invalidate
every reporting view in the app.

### A question waits for the interface to settle again

The root view checks for a question two seconds after each navigation (ADR
0017). With surfaces reporting, a list still moving at that moment makes the
check see `scrolling`, and before this change nothing checked again until the
next navigation, so the question was lost for the visit. The check is now keyed
by `PitAskTrigger`: the navigation path plus `PitPresenceModel.isInterfaceIdle`
(no surface reports anything). Any change restarts it, so navigation or a new
activity cancels a pending check, and every return to an idle interface starts
a fresh two-second settle and a fresh check. Closing an editor sheet is such a
return, so it is covered too.

`isInterfaceIdle` ignores Reduce Motion and Pit's own pending question. Reduce
Motion never blocks a question (ADR 0017), and counting the question would
restart the check while Pit is asking, cancelling the startle's pause before
the knock. A repeat check after a resolved question costs one read: the
question is no longer silent-and-due, and the 12-hour cooldown holds.

### Scrolling means any scroll, not only fast scrolling

The contract says idle motion stops during "fast scrolling". The phase does
not say how fast, and a moving list is not idle UI for REQ-PIT-006 either, so
any scroll counts. The idle scheduler already allows a whole session without
motion, so the stricter reading costs nothing visible.

### Motion audit

Accepted behaviour means the requirements that ADRs 0012, 0017, and 0018
implement. The requirements themselves are still `proposed`.

| State (contract) | Required by | Triggered by |
|---|---|---|
| resting | REQ-PIT-005 (yield to activity) | `PitPresenceModel` whenever activity is not idle, after every idle action, and after a question ends |
| blink | REQ-PIT-004 (baseline idle action) | `PitIdleScheduler` via the idle loop in `PitPresenceModel` |
| look left / right | REQ-PIT-004 (idle observation) | `PitIdleScheduler` |
| look up | REQ-PIT-004 (idle wandering) | `PitIdleScheduler` |
| startle | ADR 0012, REQ-PIT-018 (react before asking) | `PitPresenceModel.askPermissionToInterrupt()`, skipped with Reduce Motion |
| knock | ADR 0012, 0017, REQ-PIT-018 (request to interrupt) | `askPermissionToInterrupt()`; the capture sheet while a question, confirmation, or clarification waits |
| fixed gaze | CAP-004 capture surface (listening) | `PitCaptureView` while composing |
| side gaze | CAP-004 capture surface (thinking) | `PitCaptureView` while a capture is being interpreted or saved |
| hidden | none: "may hide visual detail when inactive" is optional | not triggered; drawable |
| closed eyes | none: no requirement asks for a completion motion | not triggered; drawable |
| double blink | none: "rare natural variation" | not in `PitState` |
| glance at object | none; it needs a model of UI objects | not in `PitState` |

Every state the accepted behaviour requires was already triggered. The gap was
the activity that stops them, which this ADR closes. No state was added, and
the idle vocabulary and weights are unchanged.

## Tests

`PitActivityReportingTests.swift`:

- `PitActivitySourcesTests`: add and withdraw, overlapping sources stay busy
  until the last one goes, a repeated report replaces instead of counting,
  withdrawing an unknown or already withdrawn source changes nothing.
- `PitActivityReportingTests`: with the idle loop running and blinking, a
  reported scroll, edit, or modal task stops every further state, and motion
  resumes once it is withdrawn;
  overlapping surfaces keep Pit still until both are gone; a surface report
  never clears Reduce Motion; the environment reporter forwards to the model.
- `PitQuestionViewModelTests` (extension): the mileage question is not asked,
  and nothing is recorded, while an editor sheet is reported, and is asked once
  it closes; a focused field blocks it even with Reduce Motion on; a scroll at
  the ask moment gives no question, the busy trigger neither settles nor asks,
  and once the scroll stops a new trigger settles again and the question is
  asked; a check cancelled during its settle asks nothing.
- `isInterfaceIdle` ignores Reduce Motion and a pending question, and follows
  surface reports.

The SwiftUI modifiers themselves (appear, change, disappear, scroll phase,
focus) have no unit tests. A tap-free simulator launch on Service with stale
mileage still showed the question, so the scroll view reporting on appear
leaves no activity behind; opening an editor or scrolling during the settle
delay was not exercised on the simulator.

## Rejected alternatives

- **An `@Observable` activity tracker shared through the environment.** A
  second observable object that the root must mirror into `PitPresenceModel`,
  one render late: a question evaluated in between would read stale activity.
  Reporting straight into the model keeps one source of truth, read live.
- **A counter per activity kind.** An unbalanced add or remove, such as a
  disappear without an appear, would leave Pit still for the rest of the
  session. Per-source replacement cannot drift.
- **A closure in the environment.** Simplest, but a new closure on every root
  render invalidates every reader; see "equal by the model".
- **Reporting the modal task from inside the sheet.** It would cover every
  presentation automatically, but depends on the sheet's content appearing and
  disappearing on time; the presenting state is what the screen already owns
  and what closing the sheet resets.
- **Keyboard notifications for editing.** They say a keyboard is up, not which
  surface owns it, and do not cover hardware keyboards.
- **Adding closed eyes on a saved capture, or hidden when inactive.** No
  accepted requirement asks for them, and the card excludes decorative motion.

## Open questions for owner review

- **Recent dismissal is not reported.** REQ-PIT-005 lists "recent Pit
  dismissal", and `PitActivity.recentlyDismissed` exists, but nothing sets it.
  Dismissing a question already silences questions for 7 days (ADR 0012); how
  long idle motion should also stop after it is not decided.
- **Alerts are not reported.** The failure alerts on Notes and Service lists
  are notices, not tasks; the alerts inside editor sheets are covered by the
  sheet's modal task.
- **Closed eyes and hidden** stay drawable but unused until a requirement
  asks for them.
