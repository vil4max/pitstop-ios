# Pit Eyes and the Full Motion Language

**Status:** Accepted for implementation (owner request 2026-09-21); the drawing amended by
[ADR 0039](0039-pit-head-control.md) (2026-09-24): Pit is drawn as `PitHead` with one `PitPose` per state,
`PitEyesGlyph`, `PitEyeShape` and `PitEyeGeometry` are removed, and the knock's bumps are dips from the lifted
pose; the sequences, timings, life and Reduce Motion rules below are unchanged\
**Task:** PIT-MOTION-001\
**Builds on:** [`0009-design-language.md`](0009-design-language.md) (Pit mark),
[`0012-pit-presence-and-attention.md`](0012-pit-presence-and-attention.md),
[`0019-pit-activity-reporting.md`](0019-pit-activity-reporting.md) (motion audit)\
**Contracts:** [`../requirements/pit-behavior-and-motion.md`](../requirements/pit-behavior-and-motion.md)
("Motion language", "Idle policy", "Accessibility"; REQ-PIT-004, 005, 017,
018, 019)

## Context

The owner asked on 2026-09-21 for Pit's eyes to be refined, to look more alive,
and to be animated in the app as the specification describes: Pit thinks, Pit
looks aside, and so on. The "Motion language" table lists twelve states or
actions. The ADR 0019 audit found that three of them were never shown (closed
eyes, hidden) or not modelled at all (double blink, glance at object), because
no accepted requirement asked for them then. The owner request is that ask.

Before this change the glyph was two static capsules with a highlight that
jumped between positions under one short ease. A blink was a height change, a
knock a 3-point shift, and nothing moved in between states.

## Decision

### Motion sequences live in models; the view renders one state

A sequence is a list of `PitBeat` values (domain): a state and the minimum time
it stays before the next one. Two players show beats:

- `PitPresenceModel` (utility layer): idle actions, startle then knock, and
  leaving.
- `PitCaptureEyes` (Pit sheet, new): the transitions between capture moments,
  computed by the pure `PitCaptureChoreography.beats(from:to:reduceMotion:)`,
  the listening blinks, and bounded life after each state change.

Both take an injected scheduler and sleep, so every sequence is asserted in a
test without a screen. `PitEyesGlyph` only draws a `PitState` and a
`PitEyeLife` value (a small offset and scale) that the sheet's model sets.

A beat keeps its hold even if the next moment arrives early. A fast
interpretation therefore still shows the side gaze for 0.6 s before the
proposal instead of skipping it.

### Every state in the table, and where it is triggered

| Spec row | Meaning | Implementation |
|---|---|---|
| hidden | not visually active | Drawable (dimmed); still not triggered: hiding is optional in "Availability", and the mark stays visible as the affordance |
| resting | available and waiting | Default in the utility layer; after every idle action; after a saved capture's closed eyes |
| blink | alive / idle | `PitIdleAction.blink` (baseline, weight 0.41); listening blink; the transition blink after input |
| double blink | rare natural variation | `PitIdleAction.doubleBlink`: blink, open 0.16 s, blink; weight 0.04 carved out of blink, so the total motion weight (0.71) and the stillness share (29%) are unchanged. Not a `PitState`: it is two blinks |
| look left/right | idle observation | `PitIdleAction.lookLeft/lookRight`, held 0.9 s so the gaze spring settles |
| look up | idle wandering thought | `PitIdleAction.lookUp`, lids open a little wider |
| glance at object | noticed UI context | New `PitState.glance`: after a save, the sheet's eyes look down toward the saved result and its destination, the only UI object whose position relative to the eyes is fixed. See "Deferred" |
| fixed gaze | listening | Sheet composer; micro-saccades; fewer blinks (below) |
| side gaze | thinking | Sheet while working, up and aside, with a slow drift |
| startle | remembered something | Before a knock in the utility layer: quick lift (-2 pt) and widening (openness 1.15) with a snappy spring |
| knock | requests permission to interrupt | Lift (-3 pt) plus two small bumps played on entry, in the utility layer and for a proposal or clarification in the sheet |
| close eyes | completion / leaving | Sheet: glance, then closed eyes 0.7 s, then resting after a save. Utility layer: `PitPresenceModel.leave()` when the Pit sheet closes, unless a question is still knocking |

### Listening blinks less

`PitIdleScheduler.nextPlan(_:activity:sinceLastAction:)` has a `listening`
mode: its only action is a single blink at weight 0.22 (about half the idle
blink weight) with the delay drawn from 4 to 26 s instead of 19 s, and the same
6 s cooldown. Looking around would read as not listening, so it is excluded.
Listening is the capture activity, so in this mode `capturing` and `editing`
do not count as busy; Reduce Motion and every other activity still stop it.
The idle mode is unchanged: any activity stops it (REQ-PIT-005).

### The post-input transition

The contract's candidate `fixed gaze → blink → side gaze → proposal` is the
choreography from listening (or from Pit's question in the composer) to
working, a proposal, or a save. A save that arrives without a drawn working
phase still gets the blink and side gaze first. The proposal is the knock (a
confirmation asks permission to write), as it was before this change. A saved
capture ends `glance → closed eyes → resting`.

### Visual refinement within ADR 0009

The mark stays two eyes with a highlight; no body, mouth, brows, or
expression. Size, spacing, hit target, label, hint, and value are unchanged.

- **Lids.** `PitEyeShape` is a capsule whose top edge is the upper lid. The
  lid comes down from the top and flattens as it closes, the lower lid rises a
  little, and they meet at 72% of the height, so a blink reads as a lid, not a
  shrinking pill. A closed eye keeps a lid line just over 1 pt thick.
- **Squash and widen.** The eye gets up to 14% wider as it closes and wider
  again past full openness (startle).
- **Gaze.** The whole eye shifts up to 1.2 pt toward its gaze and the
  highlight up to 2.4 pt more, so direction reads through parallax. A second,
  fainter highlight gives depth. Highlights fade as the lid passes 35% and are
  clipped by the lid.
- **Timing.** Blinks close in 0.07 s and reopen with a small spring; gaze
  changes use a spring with slight overshoot (bounce 0.3); a startle snaps
  (bounce 0.4); closed eyes ease over 0.3 s. The trailing eye follows 25 ms
  later, so the pair never moves as one rigid piece.
- **Bounded life** (`PitEyeLifePlan`, played by `PitCaptureEyes`): see
  below.
- **Colours** are `PitColor.contentPrimary` and `surfaceSecondary`, so dark
  mode follows the system roles.

### Life is bounded and irregular

After the sheet's eyes enter fixed gaze, side gaze, or resting, a few small
steps follow: micro-saccade jumps while listening, a slow drift while
thinking, and a breath (1.5% scale in, then out) in all three. Each step
waits a random 0.5–1.6 s from an injected random source, the steps stop once
the next would pass a 5 s window, and a final step returns to still. Pit then
holds perfectly still until the next state change. Nothing redraws while Pit
is still: the glyph animates only between the values the model sets, with no
timeline.

This keeps the life inside the idle policy without an exception to it:

- REQ-PIT-004: no step runs on a fixed period, and a state can only produce a
  bounded burst, so motion never becomes constant.
- REQ-PIT-005: text editing (composer focus) and scrolling the sheet play no
  life and stop running life at once; scrolling also stops the listening
  blinks until it ends. The time of the last listening blink is kept on the
  model, so restarting the loop when the activity changes never shortens the
  6 s cooldown.
- REQ-PIT-017: Reduce Motion plays no life, and the glyph draws none even if
  a model sent some.

The utility-layer mark never gets any life, so on screens Pit is still between
drawn idle actions. The request suggested gentle breathing when idle there;
constant breathing on the always-visible mark would break REQ-PIT-004 and the
failure criteria ("idle animation is constant"), so it is not drawn.

### Reduce Motion

| Motion | With Reduce Motion |
|---|---|
| Idle actions (blink, double blink, looks) | None (unchanged, REQ-PIT-017) |
| Listening blinks, micro-saccades, drift, breathing | None |
| Transient beats still queued when Reduce Motion turns on | Dropped (blink, glance) |
| Transition blink after input, glance after a save | Dropped; side gaze, knock, closed eyes and resting remain as state changes |
| Startle then knock | Knock alone (unchanged, REQ-PIT-018) |
| Knock | The lifted pose without the bumps |
| Closed eyes on leaving | Kept: a state change, not wandering |
| Any state change | Drawn without animation |

The glyph reads Reduce Motion itself, so the utility layer no longer applies
its own animation. VoiceOver is unchanged: the glyph is hidden from
accessibility and only a knock sets the control's value (REQ-PIT-019).

## Tests

- `PitPresenceTests.swift`: all idle actions are drawn and none is a knock;
  a double blink is drawn, less than a fifth as often as a blink, and is
  `blink, resting, blink, resting`; listening draws only blinks, fewer than
  idle, with longer delays; listening ignores capturing and editing but yields
  to Reduce Motion, scrolling, modal tasks and dismissal; leaving shows closed
  eyes then resting and never erases a knock; an earlier leave waking late
  never reopens the eyes of a later one (`PitLeavingTests.swift`); the idle
  loop plays a double blink.
- `PitEyesGlyphTests.swift`: every `PitState` has a distinct geometry; closed
  eyes show no highlight and keep a drawable lid line; a life plan stays
  inside the window, ends still, and has varying intervals within 0.5–1.6 s;
  no life while editing or scrolling, with Reduce Motion, or in other
  states; listening
  jumps, thinking drifts, resting only breathes.
- `PitCaptureEyesTests.swift`: the choreography for input, direct saves,
  proposals and Reduce Motion; the thinking hold; phase mapping; the model
  emits `fixed gaze, blink, side gaze, knock` and `…, glance, closed eyes,
  resting`; the Reduce Motion flow; Reduce Motion turned on mid-sequence drops
  the queued blink and glance; listening blinks without looking around;
  scrolling stops listening blinks; a restarted listening loop keeps the blink
  cooldown; life ends still and stays still; editing and scrolling stop life;
  returning to the composer drops queued beats.
- Existing activity tests still show that no idle motion runs during
  scrolling, editing, or a modal task.

Rendering was checked by rendering every state with `ImageRenderer` in light
and dark mode, and on the simulator. There is no snapshot test target.

## Rejected alternatives

- **Lottie or Rive animations.** A new dependency and binary assets for two
  shapes; the states would be opaque to tests, and Reduce Motion variants would
  need separate files.
- **A sprite or SF Symbol sequence.** Cannot blend between gaze positions or
  follow springs.
- **Sequences inside the view (`phaseAnimator`, chained `withAnimation`).**
  Untestable and would drift from the semantic rules; only the knock's two
  bumps are a keyframe animation, because they are the drawing of one state.
- **A `doubleBlink` state.** It would need a drawing identical to blink, which
  the vocabulary test forbids, and it is a sequence, not a pose.
- **A glance driven by measured UI geometry.** See "Deferred".

## Deferred

- **Glance at object outside the sheet.** Looking at a real UI object (a tile
  that changed, a new History row) needs a model of noticed UI context: which
  object, where it is relative to the utility mark, and when noticing is
  allowed without becoming an interruption. None of that exists, and the
  attention policy has no rule for it. Only the sheet's fixed-position glance
  is implemented.
- **Hidden.** Still not triggered; "Availability" makes it optional.
- **Recent dismissal** still does not stop idle motion (ADR 0019 open
  question).
- The constants (weights, holds, spring values) are hypotheses to revisit on
  a device.
