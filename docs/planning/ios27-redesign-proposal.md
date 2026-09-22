# iOS 27 redesign: proposal for owner approval

**Status:** Approved by the owner on 2026-09-22. The requirement deltas are
applied to the requirement files on 2026-09-22 (owner: "design decisions
are made and approved in the design session"); ADRs are still written by the
cards. Earlier text: requirement and ADR edits still happen card by card (spec
pyramid: propose, then approve per file). No app code changed yet; the app
icon shipped ahead of the cards with Pit's head (ICON-002, ADR 0037)\
**Mockups:** [`../design/ios27-mockups.html`](../design/ios27-mockups.html),
a self-contained HTML page kept in the repository until the redesign is fully
implemented (owner decision 2026-09-22: not published to Figma). Open it in a
browser; toggles for light / dark / side by side and accessibility text size.
A private Artifact copy exists for the owner's convenience only\
**Figma:** the owner's private file `PitStop iOS 27` holds variables, text
styles and components only; the owner decided on 2026-09-22 not to build
screen pages there, so it is not a design source for the cards\
**Scope:** Car Board, Road, Service (with Track several), History, Notes, Pit
capture sheet, first-minute and sparse states, widgets and control, utility
layer and Settings\
**Contracts kept:** [`../core.md`](../core.md) C2 (no invented facts), C3
(one question at a time), C5 (only confirmed completed work resets a cycle
or enters History), P5 (native by default); ADR 0006 (confirmation before a
write)\
**Cards:** section "Redesign (iOS 27)" in [`work-plan.md`](work-plan.md)

All names, dates, mileages and amounts in the mockups are fictional.

## 1. Rationale

The delivered app already follows the product design direction: calm grouped
surfaces, one cloud-blue accent, amber for maintenance attention, glass only
in the utility layer (ADR 0009). What it lacks is a hierarchy between the
surfaces: every row on Service, History, Notes and Road is its own 26 pt card,
so a list of facts weighs the same as the car itself, and status is carried
by coloured text alone.

The proposal keeps the root concept ("home is the car, everything else is a
view into its memory") and sorts every surface into three tiers:

| Tier | Surfaces | Treatment |
|---|---|---|
| Stage | Car Hero, Road lane, Pit's eyes, the empty-state glyph disc | The only tinted, custom-drawn surfaces; `surfaceTint` (accent at 10–22 %, 14–28 % in dark) |
| Grouped lists | Service rows, History entries, Notes, Road milestone list, every form | One inset-grouped container per section (native list geometry), rows separated by hairlines |
| Glass controls | Utility layer, toolbar actions, "Back to now", the sheet's primary action | Liquid Glass; nothing else is glass |

Car Board tiles stay cards because a card is the "entrance" affordance; they
get a fixed anatomy (title row with chevron, primary line, status chip,
secondary line).

Status is never colour alone: a **status chip** is a word, a glyph and a
colour. The glyph vocabulary is one shape per state, shared by chips, Road
markers and widgets: ring = ahead / up to date, half-filled = approaching,
filled = due, filled with a ring = past due, dashed = unknown or waiting for
mileage. Red is not used for any maintenance state.

Native components remain the default (forms, sheets, segmented controls,
menus, confirmation dialogs, ContentUnavailableView semantics); custom drawing
is limited to the stage tier and the chip.

## 2. What each screen changes

Details, per-state frames and the light/dark and Dynamic Type notes are in
the mockups; this list is the checklist for the cards.

- **Car Board.** Hero becomes a tinted stage with the car large, a dashed
  horizon, one mileage line with its recency ("47 560 km · updated 9 days
  ago", derived from the newest observation date), and a small glass pencil
  as the edit affordance. The Road tile draws the projection's initial slots
  as markers. Tiles get the chip and the chevron.
- **Road.** The car drives along the road and the milestones stand on the
  road ahead of it as roadside information signs (owner idea 2026-09-22): a
  small plate on a post with the state glyph, the car's wheels and every
  post on one road line, labels under the road (REQ-ROAD-029). Markers use
  the shape vocabulary; "Back to now" is a glass
  pill inside the lane card, shown only when the lane has left the car; the
  milestone list is one grouped list under "Ahead", with "Waiting for
  mileage" as a second group; the past summary stays one line. The
  ROAD-EST-002 estimate line (landed) stays a tertiary line under the fact,
  prefixed "Estimate:" and never coloured as a state; the Car Board tile
  shows no estimate.
- **Service.** One "Track" toolbar menu with the delivered "Track an
  operation" and "Track several" items (owner decision 4); "Next visit" as a
  grouped suggestion with its footer; tracked rows in one list with the chip,
  the fact line, a visible "Mark as done" and the more menu. New
  **remaining-share track**: a 5 pt bar whose length is the used share of the
  owner's own interval, drawn only when the interval, the last completion
  and a mileage observation newer than 90 days are known; no bar for
  `unknown` or stale mileage. The MNT-VR-002 dashboard reading (delivered in
  the working tree, catalog keys `service.report.*`) keeps its secondary line
  ("Car says 3 200 km / 45 days · Sep 20", "an old reading" after 180 days),
  its superseded state and its "Dashboard reading" sheet; RD-003 restyles
  them, it does not change their wording. The menu labels reuse
  `service.track` ("Track an operation", disabled when nothing is
  untracked) and `service.trackSeveral` ("Track several", disabled unless
  Service has loaded and something is untracked); the menu button itself is
  "Track" (one new string).
- **Track several.** A four-step strip (Choose, Intervals, Confirm, Result);
  quick picks as tinted chips; Confirm and Back as stacked full-width buttons.
- **History.** One grouped list per month with a header and a thin rail;
  completions distinct (green dot, seal glyph, no chevron) with a line saying
  they are corrected on Service.
- **Notes.** Rows in one list, body-weight text, a meta line with recency and
  context, archive glyph per row plus swipe; chips wrap at AX sizes.
- **Pit capture sheet.** Eyes at 2.2× beside a title that names the moment
  ("Remember", "Is this right?", "One thing", "Saved."); composer, mode
  picker and a prominent capsule action; the pending question card above the
  composer; confirmation quotes the raw words first.
- **First minute and sparse states.** No onboarding flow. One EmptyState
  composition: tinted glyph disc, headline, one sentence, one action, placed
  in the top third.
- **Widgets.** Delivered widget unchanged in content; SYS-007 frames show a
  small "Next service" and a medium "Road" widget built from the same chip and
  lane primitives and the semantic summary sentence.
- **Utility layer and Settings.** Unchanged geometry (56 pt circles, 20 pt
  inset, safe-area inset for scroll content); Settings unchanged.

## 3. Proposed deltas to the specification files

Each delta is a proposal. Requirement wording follows the Given / When / Then
form of the existing files. IDs are provisional: they continue each file's
sequence as of 2026-09-22 (after REQ-ROAD-026 and REQ-MAINT-039 from
MNT-VR-002), and the implementing card takes the next free ID in the file
when it lands if another card has used these first. Files without
requirements today (product-design, screen-grammar, design-system-module) get
their first ones.

### 3.1 `requirements/product-design.md`

- Add a section **Surface tiers** after "Visual principle" with the table in
  §1 and the sentence: "A surface belongs to exactly one tier; glass is never
  applied to content."
- Add to **Visual principle**: "Status is a word, a glyph and a colour
  together; the glyph vocabulary is one shape per state (ring, half, filled,
  filled with ring, dashed)."
- Add to **Car image**: "The hero sits on a tinted stage; the tint is the
  accent at low opacity, never a second hue."
- New requirements:
  - **REQ-DESIGN-001 — Status is never colour alone.** Given any maintenance
    or Road state shown to the user, When it is rendered, Then a word and a
    state glyph accompany the colour, and the glyph shape differs per state.
  - **REQ-DESIGN-002 — Glass is reserved for floating controls.** Given a
    primary or detail screen, When surfaces are inspected, Then only the
    utility layer, toolbar actions and explicitly floating controls use
    Liquid Glass, and content surfaces are opaque.
  - **REQ-DESIGN-003 — One tint, one accent.** Given the stage tier, When it
    is rendered, Then its tint is `accentPrimary` at a token-defined opacity,
    and no other surface is tinted.

### 3.2 `requirements/screen-grammar.md`

- **Header**: add "Trailing actions live in the navigation toolbar as glass
  buttons; related actions form one toolbar menu (owner decision 4). The large title stays in
  the content (inline navigation title), as delivered."
- **Surfaces**: add `surfaceTint` and `contentOnAccent` to the conceptual
  roles; add a **List geometry** paragraph: "Repeated records of one kind
  (rows) live in one inset-grouped container per section with hairline
  separators. A card (26 pt radius) is reserved for entrances (Car Board
  tiles) and the stage tier. Fields inside forms use 18 pt; nested radii are
  concentric."
- **Empty and sparse states**: add the EmptyState composition (glyph disc,
  headline, one sentence, one action; top third of the content).
- New section **Dynamic Type reflow** with the rules the mockups annotate:
  half tiles to full rows at accessibility sizes; chips wrap instead of
  scrolling; row actions move under the text; horizontally scrolling lanes
  grow in height and never clip; fixed-size controls are only the utility
  circles and toolbar glyphs.
- New requirements:
  - **REQ-GRAMMAR-001 — Rows live in grouped containers.** Given a screen
    section listing records of one kind, When it renders, Then the records
    are rows in one grouped container, not one card per record.
  - **REQ-GRAMMAR-002 — Header and toolbar grammar.** Given a detail screen,
    When it renders, Then it shows eyebrow, large title and, if any, its
    actions in the navigation toolbar as glass buttons.
  - **REQ-GRAMMAR-003 — Text never clips at accessibility sizes.** Given the
    largest Dynamic Type size, When any primary or detail screen renders,
    Then no text is truncated below its meaning, chips wrap, and every
    control keeps a 44 pt target.
  - **REQ-GRAMMAR-004 — Sparse state composition.** Given an owned surface
    with no records, When it renders, Then it shows a glyph, a headline, at
    most one sentence and at most two actions, and no placeholder metric.

### 3.3 `requirements/car-board-screen.md`

- **Car Hero**: replace "Shows: car visual; display name; only minimal
  supporting car context that has proven value" with: "Shows the car visual
  on a tinted stage, the newest mileage observation with its recency, and one
  edit affordance. The display name is the screen title."
- **Tile contract**: add the anatomy: "title row with the surface name and a
  chevron; primary line; optional status chip; secondary line".
- **Road tile**: add "draws the projection's initial slots as markers using
  the state glyph vocabulary; the semantic summary sentence stays visible".
- New requirements:
  - **REQ-BOARD-027 — Mileage recency is derived, not guessed.** Given a
    newest mileage observation with a date, When Car Board renders, Then the
    hero shows the observation's age in whole days or a coarser unit, from
    that date only, and shows no recency when no observation exists.
  - **REQ-BOARD-028 — Tile anatomy is shared.** Given the four V1 tiles,
    When they render, Then each shows the title row, a primary line and a
    secondary line, and a status chip only where a state exists.

### 3.4 `requirements/road-domain-and-ui.md`

- **Overdue milestones**: add the glyph vocabulary and "Past due is drawn
  with the due colour and a ring, never `statusDanger`".
- **Return to current position**: close the INVESTIGATE with the delivered
  answer as delivered: "Every visit starts at the car. After scrolling, a
  'Back to now' button under the lane, inside the lane card, returns to the
  car; Reduce Motion returns without animation." Mark INV-ROAD-004
  answered. RD-002 then restyles that button as a glass pill; the position
  stays in the lane card. The code session verifies this wording before it
  is accepted.
- **Past**: keep; note the one-line summary pointing to History is the
  compact history marker.
- New requirements:
  - **REQ-ROAD-027 — Milestone list mirrors the lane.** Given a Road
    projection with slots, When Road renders, Then the same milestones appear
    as text rows in the same order under the lane, and a milestone that is
    only in the lane or only in the list does not exist.
  - **REQ-ROAD-028 — Back to now is explicit and conditional.** Given the
    lane scrolled away from the car, When Road renders, Then a labelled
    control returns the lane to the car, and the control is absent while the
    lane's leading item is the car.
- REQ-ROAD-022 and 023 (ROAD-EST-002) are approved and implemented. The
  redesign keeps the delivered estimate line as it is: tertiary text,
  "Estimate: Oct 12 – Nov 20" within the current year, and with years when
  either bound leaves it, for example "Estimate: Dec 10, 2026 – Jan 11,
  2027"; never
  coloured as a state, in the milestone list and in the full Road lane
  slots; "from your mileage readings" is only in the VoiceOver label; the
  Car Board tile shows no estimate.

### 3.5 `requirements/bottom-utility-layer.md`

- **Safe areas and scrolling**: close the INVESTIGATE: "Text input lives in
  sheets; the layer never rides up over the keyboard and is unchanged when
  the sheet closes." The app has no full-screen covers today; if one is
  added, it covers the layer too (a rule for the future, not a delivered
  fact). The code session verifies this wording before it is accepted.
- New requirement, pending a simulator check: Pit opens at the medium detent
  and iOS 27 sheets float inset, so whether the layer is fully hidden
  behind a medium sheet is checked on the simulator (RD-010) before the
  wording below is proposed for approval; if the layer shows beside a
  medium sheet, the requirement says "not moved and not reachable" instead.
  - **REQ-UTILITY-012 — Sheets cover the layer.** Given a sheet is
    presented, When the keyboard or the sheet is shown, Then the utility
    layer is neither visible above the sheet nor moved, and it is in its
    position when the sheet closes.

### 3.6 `requirements/pit-behavior-and-motion.md`

- **Capture**: add the sheet layout: "eyes beside a title that names the
  moment; composer with a mode picker; one prominent action; a pending Pit
  question above the composer; confirmation shows the raw words first, then
  every fact to be written; the saved state shows the destination in words
  and one way to continue. The sheet opens at the medium detent, at the large
  detent for accessibility text sizes." The large detent at accessibility
  sizes is a deliberate behaviour change in RD-007 (today the sheet always
  opens at medium, `PitCaptureView`); see §5.
- New requirement:
  - **REQ-PIT-021 — The capture sheet is not a transcript.** Given any
    sequence of captures in one sheet session, When the sheet renders, Then
    it shows only the current moment (composing, working, confirming,
    clarifying or saved) and never a history of earlier turns.

### 3.6b Pit's eyes: gaze reference (owner reference, 2026-09-22)

The owner pointed at EVE and WALL-E as references for Pit's gaze and asked
for an analysis that accounts for animation and PitStop's use of Pit
(capture, one clarification, progressive discovery). The mockups' "Eye
reference analysis" panel holds the comparison and the state strips; the
conclusion:

- **Borrowed from the EVE type:** expression lives in the outline of each
  eye (lens, flattened lens, shallow arc); lit shapes read on a dark field,
  which the icon already does (white eyes on blue); everything survives at
  15 pt and at 40 px.
- **Borrowed from the WALL-E type:** the two eyes are independent pieces that
  tilt and turn a few degrees toward what they look at; looking and noticing
  are half of the motion table.
- **Not borrowed:** head, visor, stalks, housings, glow, colour, proportions;
  the inward "\ /" angle that reads as anger (Pit does not evaluate the
  user). Pit stays two shapes with no body.
- **Recommendation:** lens geometry with per-eye tilt capped at 10° (6° for
  the inward attention pose on knock); closed eyes become a shallow upward
  arc so "completion / leaving" reads as content. The motion table, idle
  policy, cooldowns, timings and Reduce Motion mapping of ADR 0028 stay as
  they are; only the drawn geometry and a tilt dimension change.

Deltas:

- `product-design.md`, **Pit visual hypothesis**: add "Reference for
  expression mechanics only: lit lens shapes whose outline and tilt carry the
  state. No character, body or costume is copied."
- `pit-behavior-and-motion.md`, **Visual hypothesis**: add the per-state
  pose table from the mockups (resting 6° outward, listening 0° and 6 %
  taller, thinking both rolled 10°, knock 6° inward and lifted, closed as an
  upward arc) and the rule "inward tilt is attention, never judgement".
- New requirement **REQ-PIT-022 — Eye poses are distinct without animation.**
  Given each state in the motion table, When Pit is drawn with animation
  disabled, Then every state has a distinct static geometry (outline, tilt or
  offset) and the inward tilt never exceeds 6°.
- `app-icon.md`: unchanged wording; the icon is regenerated from the new
  `PitEyeShape` per ADR 0029 "Editing" (REQ-ICON-002). REQ-ICON-001 was
  later reworded to the head (§3.6d).
- ADR 0028 is not edited; a follow-up ADR records the geometry change and
  the reference, and the vocabulary test keeps one geometry per state.
- The lens geometry applies to every Pit mark: the utility control, the
  capture sheet and the app icon (owner, 2026-09-22).
- Utility control (owner decision 8, option A): neutral glass with
  `contentPrimary` eyes, as delivered. New: during a knock the eyes are
  drawn in `accentPrimary`, and they return to `contentPrimary` when the
  knock ends. With Reduce Motion the colour change stays as a static state
  change (the lifted pose without bumps, ADR 0028). VoiceOver is unchanged:
  the knock is still announced once as the value "Has a question".
- New requirement **REQ-PIT-023 — A knock is also a colour change.** Given
  Pit knocks, in the utility layer or in the capture sheet, When the eyes
  are drawn, Then the eyes
  use the accent colour for the knock, with or without Reduce Motion, and
  return to the content colour when the knock ends; no other state uses the
  accent.

### 3.6c Car profile: photo, one neutral placeholder, avatar (owner answers, 2026-09-22)

The owner asked for a proper neutral placeholder and their own photo of the
car used everywhere, like a car profile in a social network. Answers given in
the design session:

- **Photo form:** the car is lifted out of the owner's photo on device
  (Vision foreground instance mask) and stands on the tinted stage where the
  placeholder stood; if lifting fails, the whole photo is shown under a soft
  mask.
- **Placeholder:** without a photo the car is a neutral side-view
  silhouette in flat system grey (#8E8E93), facing right (the car drives left
  to right, toward the road ahead), with no lights, badges, make or model.
  The owner picks the body in the car editor, SUV (default) or sedan
  (owner decision 2026-09-22):
  [`../design/assets/car-placeholder.png`](../design/assets/car-placeholder.png)
  and `car-placeholder-sedan.png`. It replaces the delivered
  `AbstractCarView`. Earlier drafts (six drawn body types, a drawn
  three-quarter view, a three-quarter image of a real model) were rejected
  or deleted.
- **Where the car appears:** where it matters and is pleasant to see: the
  Car Board stage, the Road tile and Road "Now", a 28 pt avatar in detail
  screen headers, a 44 pt avatar in Pit's saved state and question card, and
  the SYS-007 data widgets. Not in Settings, forms, list rows or the
  data-free widget.
- **Profile scope:** photo, name, body (SUV or sedan) and mileage. Make, model and year stay
  vehicle facts from capture and are not shown on the hero.

Asset rule (public repository): an image ships only as original artwork or
with a recorded permissive licence (for example MIT, Apache 2.0, CC0), and
the source goes into the car-profile ADR. The owner's SUV and sedan images
were generated with AI by the owner on 2026-09-22 and supplied for PitStop;
provenance is recorded in
[`../design/assets/README.md`](../design/assets/README.md), and they may be
committed. SF Symbols (`car.side.fill`) were
considered: Apple's licence limits them to interfaces and mock-ups for Apple
platforms, and they are icon-weight at hero size.

Privacy constraint (history rewritten on 2026-09-21 to remove real-car
data): a real owner photo can show a plate, a VIN sticker or a location. It
is a runtime image in the app container only. It is never committed as an
asset, never in the mockups, never in the Figma file, never in analytics.
Designs and tests use the placeholder or a clearly fictional illustration.
The pre-push private-data scan does not recognise images, so reviewers check
every added binary.

Deltas:

- `product-design.md`, **Car image**: replace the fallback order with
  "1. the owner's photo, lifted onto the stage when possible; 2. the neutral
  placeholder". The "validated model-aware / make-aware visual" steps are
  removed: no make or model imagery is planned.
- `car-board-screen.md`, **Car Hero**: "Shows the owner's photo or the
  neutral placeholder on a tinted stage, the newest mileage observation with
  its recency, and one edit affordance; editing opens the car editor with
  photo, name and mileage."
- `REQ-BOARD-017` Then line, replacing "Car Hero shows a car visual and
  display name and no technical specification list": "Then Car Board shows
  the car visual in the hero and the display name as the screen title, and
  no technical specification list".
- `screen-grammar.md`, **Header**: allow a 28 pt car avatar before the
  eyebrow on detail screens; the large hero stays on Car Board only.
- New requirements:
  - **REQ-BOARD-029 — The owner's photo is optional and stays on device.**
    Given the owner picks a photo in the car editor, When it is saved, Then
    it is stored as a file in the app container, shown on the stage, and
    never sent to analytics, logs or any network; widgets read it only as a
    file in the App Group container after SYS-007, never inside a timeline
    entry.
  - **REQ-BOARD-030 — Without a photo the car is the neutral placeholder.**
    Given no photo, When any surface shows the car, Then it shows the one
    neutral placeholder, never a make, model or body type the owner did not
    state.
  - **REQ-BOARD-031 — A failed subject lift still shows the car.** Given a
    photo whose subject cannot be lifted, When the stage renders, Then the
    whole photo is shown under the stage mask and no error is shown.
- Persistence: the photo reference is a new field of the car context, so
  the card adds the next schema version after the newest one on `main` at
  that time, freezes the previous one (ADR 0007, 0016), and tests migration
  from every shipped version. The photo itself is a file in the app
  container (or SwiftData external storage), never a row value; deleting
  the photo removes the file.
- Photo source: `PhotosPicker` only, which needs no permission. A camera
  entry would need `NSCameraUsageDescription` and a denied-permission state;
  it is not in RD-012.
- The widget avatar depends on SYS-007: the data widgets need the App Group
  store move first, and the photo file moves with it.
- A new ADR records the fallback order, the placeholder's source and
  licence, the lift approach, storage, and the privacy rule.

### 3.6d Pit as a character (owner request, 2026-09-22)

The owner asked for a full image of Pit with a head, with EVE (WALL-E's
friend) as the reference. The mockups' "Pit, the character" section shows
the proposal:

- **Head:** an original round head, pearl white with a soft top-left light
  and a hairline; in the utility layer the whole 56 pt circle is the head
  (owner direction 2026-09-22); no body, mouth or hands.
- **Face screen:** a deep navy visor (the icon's dark fill) set in a thin
  grey bezel, with a gloss and a faint glow behind the lit lens eyes.
- **Eyes:** the approved lens pair (§3.6b), lit in soft white; on a knock
  they turn cloud blue and the glow strengthens (REQ-PIT-023).
- **Motion:** the eyes carry every state of the motion table unchanged
  (ADR 0028). The head adds only a tilt up to 6° (thinking, knock) and a
  lift up to 3 pt (startle, knock); it is otherwise still. Reduce Motion
  shows the poses without animation.
- **Borrowed from the reference:** lit eyes on a dark glass face and
  expression by eye shape and tilt. **Not borrowed:** EVE's upright egg
  shape, arms, glow colour and proportions.
- **Where:** the utility control (the 56 pt circle is the head) and the Pit
  sheet header (44 pt). The widget and control keep the capture
  glyph (ADR 0025).

Spec conflicts the owner decides:

- `product-design.md` "Pit visual hypothesis" says the eyes are the
  character, Pit does not require a body, and "Avoid: robot". Proposed
  wording: "Pit is a small companion head with a face screen and lit eyes;
  no body, mouth or hands; not a mechanic, not a mascot."
- REQ-ICON-001 (approved) keeps the icon eyes-only. The head goes on the icon
  only if the owner re-approves that requirement; the icon is then rebuilt in
  Icon Composer (ADR 0029).
- ADR 0028 stays; a follow-up ADR records the head and its two moves.
- New requirement **REQ-PIT-024 — The head never moves on its own.** Given
  Pit is resting or idle, When no motion-table state is active, Then the
  head neither tilts nor lifts; only the states in the motion table move it.

Decided 2026-09-22: the round head is chosen and its wording is applied to
`product-design.md` ("Pit visual identity"); REQ-PIT-024 is approved; the
app icon shows the same head at rest: REQ-ICON-001 is reworded from the
eyes to the head (owner decision 2026-09-22) and the icon was rebuilt in Icon
Composer ahead of the redesign as ICON-002 (ADR 0037).

### 3.6e Pit is always on screen (owner rule, 2026-09-22)

Pit is the anchor point for talking to the app, so he is never hidden: the
utility control on primary and detail screens, the same bottom-trailing spot
inside every other sheet (above the keyboard while typing), and the header
of the Pit sheet. Tapping him inside a sheet opens capture over it; closing
returns to the sheet with its input intact. The owner kept the current head
(pearl round head, navy visor, lit lens eyes with a halo) over three
alternatives the same day. Applied to `pit-behavior-and-motion.md`
(REQ-PIT-026), `bottom-utility-layer.md` (REQ-UTILITY-012 rewritten and
approved) and `product-design.md`. ADR 0024's deferral of an external "Open
Pit" request while an editor is open stays for Siri, Shortcuts and widgets;
a tap on Pit inside the sheet is the owner's own action and opens at once.

### 3.7 `requirements/app-icon.md`

- The icon shows Pit's head at rest (REQ-ICON-001 reworded, owner decision
  2026-09-22); the utility control, the sheet header and the icon share one
  geometry (REQ-ICON-002). Owner question: whether the data-free widget should show
  Pit's eyes instead of the capture glyph (ADR 0025 chose the glyph so the
  widget shows the action, not the icon; the proposal keeps the glyph).

### 3.8 `engineering/design-system-module.md`

- **Color API**: add `PitStopColor.surfaceTint` and `contentOnAccent`; note
  `statusUpToDate` is the delivered name for `statusPositive`.
- **Typography**: add the role → SwiftUI text style table: display →
  largeTitle bold; title → title3 semibold; headline → headline; body →
  body; supporting → subheadline / footnote; caption → caption / caption2.
- **Components**: replace the candidate list with the ones the mockups
  repeat: `StageSurface`, `StatusChip`, `GroupedList` row helpers (or plain
  `List` with `.insetGrouped`), `EmptyState`, `RemainingShareTrack`,
  `GlassPill`, `StepStrip`, `ScreenHeader` (exists), `TileCard` (exists),
  `PitEyesGlyph` (exists).
- **Design-system tests**: add "a preview matrix per component: light, dark,
  default and accessibility-extra-large text".
- New requirement:
  - **REQ-DESIGN-004 — Features use roles, not literals.** Given feature code,
    When it is inspected, Then it uses `PitColor` roles and the shared
    components and contains no colour literal.

### 3.9 `engineering/system-overview.md`

- Descriptive page; update after each card lands (feature matrix rows for
  Car Board, Road, Service, History, Notes, Pit, widgets), not before.

### 3.10 ADRs

- A new ADR "iOS 27 visual refresh: surface tiers" should record the tier
  rule, the status glyph vocabulary, the remaining-share track (and why it is
  not a health score), the grouped-list decision and the rejected
  alternatives (glass tiles; a tab bar; a custom font; colour-only status; a
  single estimated date on Road). The implementing card numbers it after the
  newest ADR on `main` at that time.
- ADR 0009 stays, with one amendment. Its "Two layers: calm content, glass
  controls" rule says only the utility layer uses Liquid Glass and names
  `glassEffect(.regular.interactive(), in: .circle)` for both circles. The
  round Pit head is the whole 56 pt control with no glass disc, so the
  redesign ADR (written with RD-011) amends ADR 0009 for the Pit control;
  Settings and the other floating controls stay glass. ADR 0009 "Tiles"
  covers only the Car Board descriptor and the AX reflow; the new ADR adds
  the list-geometry rule for detail screens and supersedes nothing there.

## 4. Owner decisions

All items below were decided by the owner on 2026-09-22; the owner then
approved the proposal as a whole in chat the same day. No item is open.

1. **Approved.** The three-tier rule and the status glyph vocabulary (§1).
2. **Approved with a constraint.** The remaining-share track on Service rows
   is drawn only when the interval, the last completion and a mileage
   observation newer than 90 days are all known. Stale data must not produce
   a confident-looking share.
3. **Approved.** The mileage recency line on the hero. The age comes from the
   newest mileage observation, including a completion that carries mileage,
   the same source REQ-BOARD-026 uses for the header figure.
4. **Decided: one "Track" menu**, not two actions in a glass group. After
   MNT-PRE-001 "Track several" is disabled until Service has loaded, and a
   half-disabled glass group reads badly. The mockups and RD-003 follow this.
5. **Decided: keep the capture glyph** on the widget, not Pit's eyes
   (ADR 0025).
6. **Decided.** The redesign does not wait for ROAD-EST-002 or MNT-VR-002,
   but the Road and Service cards (RD-002, RD-003) start only after
   MNT-VR-002 has landed in `main`, so those views are not rewritten twice.
7. **Approved.** Card order as proposed: RD-000 first, then Car Board, Road,
   Service, Track several, History, Notes, Pit, sparse states, widgets last
   with SYS-007.
8. **Approved: lens geometry** with per-eye tilt (§3.6b); the app icon is
   regenerated from it. **Decided 2026-09-22: utility control option A**,
   neutral glass with `contentPrimary` eyes, plus an accent on knock: while
   Pit knocks (utility layer or sheet), the lens eyes take `accentPrimary` for the knock and return to
   `contentPrimary` when it ends. Option B (accent disc) is rejected: it reads
   as a floating action button, outweighs Settings, is always loud, spends the
   one accent outside the stage, and leaves no step left for the knock.
9. **Closed 2026-09-22.** Figma: the Starter plan allows 3 pages and one
   mode per collection; the owner decided not to build screen pages in
   Figma. The mockup page in `docs/design/` is the design source until the
   redesign is implemented; the Figma file keeps tokens and components.
10. **Answered 2026-09-22.** Car profile (§3.6c): lifted photo on the
    stage, the owner's AI-generated side-view placeholders facing right, SUV
    (default) or sedan, avatar where it matters (headers, Road, Pit,
    SYS-007 widgets), scope photo + name + mileage. Card RD-012.

### Corrections accepted on 2026-09-22

- REQ-DESIGN-004 needs a real check: RD-000 adds a SwiftLint custom rule or a
  script wired into `just verify` that fails on colour literals under
  `Features/`; that check is part of RD-000's acceptance.
- REQ-GRAMMAR-003 cannot be unit-tested and the project has no snapshot
  tests: it is worded as a manual check ("verified on the simulator at the
  largest Dynamic Type size after each card") and listed under "Not verified
  on screen" in the work plan. A snapshot-testing card is not proposed now
  (design-system-module.md defers snapshot dependencies).
- The two INVESTIGATE closures (Road "Back to now", sheets covering the
  utility layer, §3.4 and §3.5) stay proposals until the code session has
  verified their wording against the code.
- Flow: the RD cards run strictly one at a time on one redesign branch;
  `main` stays releasable to TestFlight at any moment.
- Sequencing: RD-002 and RD-003 wait for MNT-VR-002 on `main`. ROAD-EST-002
  landed on `main` in commit 0248633; its estimate line is a tertiary line under
  the fact, prefixed "Estimate:", never coloured as a state, and the Car
  Board tile shows no estimate (no room in the compact lane). The mockups say
  the same.

## 5. What stays and what changes in behaviour

Unchanged: data, capture rules, Pit's attention policy and motion timings
(ADR 0028), analytics, the widget's capture glyph (ADR 0025). No tab bar, no
onboarding, no custom font, no user-resizable tiles. The mockups reuse the
catalog's English values, including the delivered estimate and dashboard
reading strings.

Deliberate behaviour and asset changes, each owned by its card:

| Change | Card |
|---|---|
| Service toolbar: two buttons become one "Track" menu (one new string) | RD-003 |
| Hero recency line ("updated 9 days ago"; new strings) | RD-001 |
| Pit sheet opens at the large detent at accessibility text sizes | RD-007 |
| Track several step strip (four new step names) | RD-004 |
| Pit eye geometry and a regenerated app icon | RD-011 |
| Car photo, neutral placeholder, avatar; new schema version | RD-012 |

## 6. Implementation details the cards must settle

Gaps an implementer will hit; each card answers the ones it owns in its ADR
or PR, not here.

- **Reduce Transparency and Increase Contrast** (RD-000): glass pills, the
  hero pencil and `surfaceTint` fall back to opaque `surfaceSecondary` with a
  hairline, and the tint rises to a contrast-safe opacity.
- **Recency line** (RD-001, REQ-BOARD-027): the unit ladder (today, days,
  weeks, months), the string keys, and what shows for a completion carrying
  mileage but no reading date (the completion's own date is the age).
- **Remaining-share track** (RD-003): past 100 % the bar is full and the
  state word carries the overdue meaning; a time-only interval draws the
  time share; with both dimensions or a dashboard reading, the bar draws the
  dimension that decided the status.
- **Glyph vocabulary** (RD-000): custom shapes in `StatusChip`, mapped from
  both sets of today's `systemImage` values, so VoiceOver meaning stays with
  the word. Road (`RoadPresentation.swift`): `circle` ahead → ring,
  `circle.lefthalf.filled` approaching → half, `circle.fill` due → filled,
  `exclamationmark.circle.fill` past due → filled with ring, waiting for
  mileage → dashed. Service (`ServicePresentation.swift`):
  `checkmark.circle` up to date → ring, `clock.badge.exclamationmark`
  approaching → half, `exclamationmark.circle` due → filled,
  `questionmark.circle` unknown ("Not enough facts") → dashed.
- **Missing frames** (RD-002, RD-003): the dashboard "old reading" row, the
  Road load failure, and the Track menu with "Track several" disabled while
  Service loads; each card draws them in the mockup page before building.
- **Glass check** (RD-000, REQ-DESIGN-002): `just verify` also fails when
  `glassEffect` appears outside `DesignSystem/`.

## 7. Verification of this proposal

- Mockups written as static HTML and published as a private Artifact; the
  agent could not view the published page in its browser (not signed in), so
  a visual pass by the owner is the first check.
- No build, test or simulator run was needed: no code changed.
