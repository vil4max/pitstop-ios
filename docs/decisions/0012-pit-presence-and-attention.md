# Pit Presence and Attention

**Status:** Accepted for implementation (agent decision under owner delegation,
2026-09-21); owner review pending. The constants are hypotheses, to be revisited
with beta evidence.\
**Task:** CAP-003\
**Contracts:** [`../requirements/pit-behavior-and-motion.md`](../requirements/pit-behavior-and-motion.md),
[`../requirements/bottom-utility-layer.md`](../requirements/bottom-utility-layer.md),
[`0009-design-language.md`](0009-design-language.md)

## Context

The utility layer has carried a static Pit mark since CB-002. The contract asks
for semantic motion, an idle policy that is explicitly not a fixed timer, and an
attention policy that decides when Pit may interrupt. None of those is a view
concern: they are rules about the product's behaviour, and they must be testable
without a screen.

## Decision

### Motion is a small vocabulary, and the affordance never depends on it

`PitState` is the contract's own list: hidden, resting, blink, look
left/right/up, fixed gaze, side gaze, startle, knock, closed eyes. The glyph
renders a state; the eyelid is the eye's height and the gaze is the highlight
moving inside it, so Pit has no body, mouth, or mascot expression.

Pit is identified by its shape and its label. With Reduce Motion the glyph is
drawn in its current state with no animation, and the control keeps its
position, hit target, and VoiceOver label. "Pit's life must not depend on
animation" is satisfied by construction, not by an extra code path.

### Idle motion is drawn, not scheduled

`PitIdleScheduler` draws an action from a weighted vocabulary: blink 45%, a
glance left, right, or up 26% together, and the remaining 29% is stillness —
an explicit "do nothing" outcome, which is why a whole session may contain no
visible idle motion (REQ-PIT-004). The delay is drawn from 4 to 19 seconds and a
6-second cooldown follows every action, so motion can never become constant.

The scheduler is a value with an injected random source, so a test can fix the
draws and assert the schedule. It can only ever return idle actions; a startle
or a knock is never scheduled, because those mean something and are asked for
by name.

Any activity at all — scrolling, editing, capturing, a modal task, Reduce
Motion, a recent dismissal — stops idle motion and returns Pit to rest
(REQ-PIT-005). Stopping is not pausing: the loop ends and starts again when the
interface is idle.

### Interruption is a separate, stricter policy

"Pit may look alive without permission. Pit may interrupt only for measurable
value." `PitAttentionPolicy` answers with at most one question, and only when

- the interface is idle (REQ-PIT-006),
- the question belongs to the surface the user is on (REQ-PIT-007),
- it is unresolved — answered, deferred, and dismissed are all final for this
  purpose (REQ-PIT-008),
- at least 12 hours have passed since the last interruption, and
- at least 7 days have passed since the last dismissal.

A dismissal silences Pit for longer than an answer does, because a dismissal is
a statement about the interruption itself. Among eligible questions the highest
priority wins, and ties are broken by a stable ID, so the choice is
deterministic.

Asking is two beats: a startle, then a knock — Pit reacts before it explains.
With Reduce Motion it is the knock alone.

## Rejected alternatives

- **A repeating timer with a random phase.** The contract forbids a fixed
  interval, and a timer makes stillness impossible to express.
- **Motion state inside the view.** It would be untestable and would drift from
  the interruption rules, which are product decisions.
- **Letting the scheduler request attention.** Looking alive and interrupting
  are different permissions; merging them is the failure the contract warns
  about.
- **Storing the interruption budget in the view model now.** Persisted
  question state belongs to DISC-001; the policy takes the elapsed times as
  inputs so it can be wired to either.

## Limits, and what is not done here

- Nothing yet reports `.scrolling` or `.editing` from the surfaces, and the
  editor sheets presented by Car Board and the feature screens are not reported
  as modal tasks. Only the utility sheets and Reduce Motion drive the activity
  today, so REQ-PIT-005 is modelled and tested but not fully wired. The wiring
  belongs with the capture surface (CAP-004) and DISC-004.
- No question is defined yet, so the attention policy has no caller. DISC-001
  and DISC-002 own the registry and the first question.
- The cooldown values and the weights are hypotheses. Evidence to collect:
  how often Pit is dismissed, and whether an answered question changes Service
  or Road behaviour as the value claim assumes.
