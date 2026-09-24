# Task — iOS 27 redesign round and iPhone Duo hardening to TestFlight 1.2.0

Assignee: Claude Code session (pitstop-ios), host Claude desktop
State: claimed
Requested by: owner (direct, 2026-09-23)
Evidence: pending
Depends-on: none
Parallelism: none

## Current status and authorization

Current outcome: RD-000…RD-011 landed on `redesign/ios27`; the overnight run
ended at the RD-011 boundary on 2026-09-24 (RD-012 was out of the night's
scope).
Authorized scope: owner, in this session on 2026-09-23, answering the plan
questions and approving the plan: "Yes, unfreeze now"; "Whole backlog,
per-card gates" (the whole sequence is approved once; each card is briefed
and committed as it lands); TestFlight "After redesign + Duo land";
SYS-008 "Harden on SDK 27.0" (keep the Xcode 27.0 toolchain, no iOS 27.1
API; `ArrangementView` and the full-screen opt-in become a later card);
REQ-BOARD-017 "Approve the new wording now"; push "Local only, ask at the
end" (nothing leaves this Mac until the merge, then one question for
pushing `main` and `tf-1.2.0-1`). Changed by the owner in this session on
2026-09-23 ("Yes, push after each card"): `redesign/ios27` is pushed to
origin as an off-machine backup after each card lands with `just verify`
green and its review done; `main` and the tag still wait for the end.
Overnight run, owner in this session on 2026-09-23: "Одобряю ночной план
целиком: RD-007…RD-011 по одному writer, после каждой карточки just verify,
review и backup push ветки, RD-012 не брать. Не спрашивай меня: решения в
рамках brief и mockup принимай сам и записывай отклонения. Проверки на
экране, которые требуют запроса доступа, пропускай и отмечай «not checked».
Остановись на последней чистой границе, только если gate не проходит после
3 попыток или нужно что-то вне brief. … К 09:00 по Киеву остановись с
актуальным Resume prompt." The owner also approved the context reset at the
RD-006 boundary in the same message.
Blocking decisions: none. Owner decisions pending for the end of the round:
REQ-MAINT-040 (proposed), the REQ-UTILITY-012 status line, the
REQ-DESIGN-004 amendment, follow-up cards (History/Notes empty before load;
NextServiceWidget restyle; a Mark-as-done save still running after its
sheet closed; two RD-011 test-strength lows), the knock glow contrast
(ADR 0039: about 1.3–3.3:1 against the full glow, about 8:1 with Increase
Contrast; the mockup draws it this way), and the device checks DEV-WIDGET
and DEV-PIT-SHEET.
Permitted deviations: RD-010 is re-estimated from 0.5d to about 2d because
REQ-UTILITY-012 and REQ-PIT-026 are not implemented on `main` (every sheet
covers the utility layer; `RootView.swift` ignores the keyboard for it).
Material assumptions: the design-rule check (REQ-DESIGN-002, 004) runs as a
Swift Testing suite inside `just verify`, because `Tooling/**` belongs to the
shared Runtime and `baseline.py` rejects drift in `Tooling/.swiftlint.yml`;
verified by `just verify` failing on a planted literal.
Next step: the owner's decisions listed under Blocking decisions, then RD-012
Writer steps (drafted when the card starts).
Out of scope: iOS 27.1 API, a Runtime or toolchain change, a snapshot-testing
dependency, the SYS-007 widget avatar, camera entry for the car photo, and
every item under "Owner decisions pending" in the work plan.
Failure conditions: a screen loses behaviour or an existing test changes
meaning; a colour literal or `glassEffect` outside `DesignSystem/` reaches a
commit; a real photo, VIN, plate or personal detail enters the public
repository; anything is pushed without the owner's word in this session.

Process per card: failing REQ-tagged tests first, implementation, light, dark
and AX-XL previews, `just verify`, simulator screenshots against the mockup
frame, independent `/code-review` in a fresh subagent, repair (at most three
iterations), one commit per Writer step. The delivered row leaves the work
plan and its `system-overview.md` row is updated in the card's last commit.
Screenshots and review verdicts go to
`agent-artifacts/2026-09-23/pitstop-ios27-redesign/outputs/`, not the
repository.

## Slices

All slices commit on the local branch `redesign/ios27`, cut from `main` at
`ab6b60c`, strictly in this order.

| Slice | Requirements | Depends on | State | Evidence |
|---|---|---|---|---|
| Round opening (docs) | REQ-BOARD-017 wording | — | done | `f50cb7e`, `6b3d589` |
| RD-000 design system | REQ-DESIGN-001…004 | — | done | `3674b52`…`c901d10` and the docs commit; `just verify` passed; review: 2 medium + 3 low, then 1 medium + 5 low, all repaired |
| RD-001 Car Board | REQ-BOARD-001…028 | RD-000 | done | `8cdc992`…`286fcae`; `just verify` passed per step (writer); review: 0 high/medium, 4 low (2 repaired, `isCompact` dead code left to RD-002, bookkeeping fixed) |
| RD-002 Road | REQ-ROAD-004, 008…015, 027…029 | RD-000 | done | `0871525`…`087a3bd`; `just verify` per step (writer); review: 0 high/medium, 2 low, both repaired |
| RD-003 Service | Service tests, REQ-DESIGN-001 | RD-000 | done | `ec7e63e`…`0386c0c`; `just verify` per step (writer); review: 0 high/medium, 2 low, both repaired |
| RD-004 Track several | ADR 0033 tests | RD-003 | done | `a7452ad`…`a1ae952`; `just verify` per step (writer); review: 1 medium + 4 low, then 2 medium + 2 low, then 0 high/medium + 3 low, all repaired |
| RD-005 History | HistoryTests | RD-000 | done | `41f3697`…`b682104`; `just verify` per step; review: 0 high/medium, 2 low, both repaired |
| RD-006 Notes | NotesTests | RD-000 | done | `0ea4f8a`…`eb45fd8`; `just verify` per step; review: 1 medium + 1 low, both repaired |
| RD-007 Pit capture sheet | REQ-PIT-021, 025 | RD-000 | done | `d0357c0`…`72c39cf`; `just verify` per step; review: 1 medium + 5 low, then 1 medium + 1 low, then 0 high/medium + 4 low; all repaired except two test-coverage lows (accepted) |
| RD-008 Sparse states | REQ-GRAMMAR-004 | RD-000 | done | `c426bfa`…`1944c46`; `just verify` per step; review: 1 medium + 2 low (one low out of scope, filed as a follow-up), then no findings |
| RD-009 Widgets | WidgetEntryTests | RD-000 | done | `5f724f1`…`b49448b`; `just verify` per step; review: 0 high/medium + 3 low, repaired; then 0 high/medium + 3 low, accepted |
| RD-010 Utility layer in sheets | REQ-UTILITY-012, REQ-PIT-026 | RD-000 | done | `a161608`…`250b36e`; `just verify` per step; review: 1 high + 3 medium + 1 low; 1 medium + 3 low; 1 medium + 4 low; 1 medium + 1 low; then 0 high/medium + 1 pre-existing low (follow-up); four repair iterations, the third and fourth approved by the owner |
| RD-011 Pit character | REQ-PIT-022…024 | RD-000 | done | `69a7113`…`dce4225`; `just verify` per step; review: 1 medium + 6 low, all repaired; then 0 high/medium + 2 low (test strength), accepted |
| RD-012 Car profile | REQ-BOARD-017, 029…031, REQ-DESIGN-005 | RD-001 | planned | — |
| SYS-008 iPhone Duo hardening | REQ-ADAPT (proposed in the card) | RD-012 | planned | — |
| Release 1.2.0 | `just tf-check` Ready | SYS-008 | planned | — |

Acceptance for each RD slice is its row in
[`../planning/work-plan.md`](../planning/work-plan.md); Writer steps are
added here when the slice starts.

## Evidence history

- 2026-09-23, `redesign/ios27` from `ab6b60c`: owner approved the plan in this
  session; kit git sync OK.
- 2026-09-23, RD-000: `just verify` passed on the combined tree three times
  (before review, after round 1, after round 2); independent `/code-review`
  round 1 found 2 medium + 3 low (Road waiting milestones drawn as ahead;
  implicit colours after `?`/`:`/`,` not caught; glass button types not
  caught; step labels could not wrap; ADR contrast figure), round 2 found
  1 medium + 5 low (implicit colours at line start, after `{`, `return`,
  `in`; halo outside the glyph box; `pitGlass` ignoring Increase Contrast;
  over-broad glass type match; `.quaternary`; ADR preview claim); all
  repaired, and the loop stopped because round 2 found as many as round 1.
  A planted `Color.blue` made REQ-DESIGN-004 fail. The per-step commits
  were not verified one by one. No simulator run: RD-000 changes no screen.
- 2026-09-23, RD-001 (slice-writer): `just verify` passed before each of its
  six commits; simulator screenshots light, dark, AX5 and first launch in the
  evidence folder (`rd-001/`); VoiceOver order set in code but not read on the
  simulator (accessibility inspector timed out). Independent `/code-review`:
  no high or medium; 4 low. Repaired: Road tile labels (kept hidden at AX
  sizes after an AX5 check showed truncation; titles now wrap) and one shared
  `DashedRoadLine`. Left: `RoadLaneView.isCompact` has no caller, removed in
  RD-002. The repair diff was read by the integrator, not re-reviewed by a
  subagent (round 1 had no high or medium findings).
- 2026-09-23, owner via the orchestrator: no rush to release; the iPhone Duo
  on-screen check blocks no card. The Duo device type exists here but neither
  installed runtime (iOS 27.0, 27.2 `24B5084k`) supports it.
- 2026-09-23, RD-002 (slice-writer): `just verify` passed before each of its
  seven commits; screenshots in `rd-002/` (populated light and dark, "Back to
  now" after scrolling, AX5 lane, list and separators, empty, waiting for
  mileage, planned-date editor); the load-failure state was not reachable on
  screen. Independent `/code-review`: no high or medium; 2 low (separator
  inset at AX sizes; a tautological REQ-ROAD-029 test), both repaired, the
  new test shown to fail on a mutated post height. Not seen on screen:
  VoiceOver, ru/uk, the Reduce Motion setting, a lane cluster.
- 2026-09-23, RD-003 (slice-writer): `just verify` passed before each of its
  seven commits; `ServiceShareTrackTests` (11 tests, 12 cases) and
  `ServiceTrackMenuTests` (4); a planted removal of the freshness check made
  the stale-mileage and 90-day tests fail; screenshots in `rd-003/`.
  Decisions: the track also needs an owner interval in the deciding
  dimension; the empty state waits for the first successful load; "Not
  enough facts" moved to `contentSecondary` (Car Board chip too). Review: no
  high or medium; 2 low (duplicated glyph-column row, redundant menu rule),
  both repaired, Road and Service re-checked at default and AX5. At exactly
  90 days the track still draws, matching ADR 0008's staleness rule. Not seen
  on screen: VoiceOver, ru/uk, the old-reading line, the load-failure banner,
  the Track menu while loading.
- 2026-09-23, RD-004 (slice-writer): `just verify` passed before each of its
  six commits; new `ChipFlowLayout` (wrapping chips) with `ChipFlowLayoutTests`
  and a pure quick-pick selection rule; screenshots in `rd-004/`. Review
  round 1: 1 medium (measuring and placing could break chip lines
  differently) + 4 low; round 2: 2 medium (the added 0.5 pt tolerance caused
  new mismatches and an unguarded re-measure) + 2 low; round 3: no high or
  medium, 3 low; all repaired, each fix shown to fail against a mutant of the
  old logic. The integrator ran the integrated build on the simulator:
  Service "Track" menu, Track several Choose and Intervals steps, chips wrap
  without overlap, and tapping "7 500 km" fills the field and selects only
  that chip. Not seen on screen: the disabled Confirm, the failed-save
  Result, VoiceOver, ru/uk.
- 2026-09-23, RD-005 (slice-writer, finished by the integrator):
  `HistoryMonthTests` (month boundaries, time zone, same-day order, year
  change; a mutant ignoring the time zone failed 5 of 8); screenshots in
  `rd-005/`. Review: no high or medium; 2 low (the rail dot reused the
  "due" glyph; the chevron vanished at accessibility sizes). The writer
  stalled for about 35 minutes mid-repair, most likely on an unanswered
  simulator-access prompt; the integrator stopped it, finished the repair
  in its worktree, ran `just verify` there, integrated, and checked History
  on the simulator at the default size and AX5 (plain rail dot, chevron under
  the text). Unexplained: a `just run-sim` started from the writer worktree
  showed the pre-RD-005 History, although earlier writers saw their own
  builds that way; the check was redone after integration. Not seen on
  screen: the event editor, VoiceOver, ru/uk.
- 2026-09-23, RD-006 (slice-writer): `just verify` passed before each commit;
  `NotesPresentationTests`; swipe inside the scroll view via iOS 27
  `swipeActionsContainer()`; screenshots in `rd-006/`. Review: 1 medium (the
  archive glyph's 44 pt frame sat outside its button, so only the symbol took
  taps) + 1 low (row padding no longer opened the note); the integrator
  repaired both, ran `just verify`, and checked Notes on the simulator: rows,
  archive glyphs, and a trailing swipe revealing Archive. Not checked on
  screen: the VoiceOver action, the editor, restore, ru/uk.
- 2026-09-23, RD-007 (slice-writer): `just verify` passed before each commit
  (the two simulator fixes were verified together); `PitCaptureDetentsTests`,
  `PitSheetMomentTests`, `PitEqualWidthRowTests`, a new REQ-CAPTURE-005 Close
  test; existing Capture and Pit tests unchanged; screenshots in `rd-007/`.
  Review round 1: 1 medium (Remember under the keyboard at accessibility
  sizes with Pit's question pending, REQ-PIT-025) + 5 low; round 2: 1 medium
  (Remember prominent beside the question's Save below accessibility sizes)
  + 1 low; round 3: 0 high/medium + 4 low (citations, a contradicting mockup
  note, stale comments, a commit body narrating the process); all repaired
  by the writer, except the round-1 lows that the REQ-PIT-021/025 tests check
  pure logic, not the view (backed by the simulator), and a commit-pairing
  note. Decision within the mockup: while Pit's question is pending, Remember
  is quiet at every text size, so the question's Save is the one prominent
  action. The integrator ran `just verify` after the fast-forward: passed.
  Not checked on screen: typing with the question pending at AX sizes, the
  composer refocus after an answer, the quiet inline Remember below AX sizes,
  the working spinner, the stacked decline pair, VoiceOver, ru/uk. The
  Capture section's "one prominent action" rule had no REQ ID; the owner
  approved it as REQ-PIT-027 in this session on 2026-09-23 ("Утверждаю"),
  recorded with the test renamed in 62c6830 after RD-008 landed.
- 2026-09-23, RD-008 (slice-writer): `just verify` passed before each commit;
  `SparseStateTests` (11) and a first-launch board test (REQ-GRAMMAR-004,
  REQ-BOARD-018); wording and the string catalog unchanged;
  `FeatureEmptyState` deleted; screenshots in `rd-008/`. Review round 1:
  1 medium (the EmptyState disc scaled with Dynamic Type, pushing actions
  off-screen; the mockup keeps it at 64 pt) + 2 low (a disabled first action
  kept the on-accent label; new tests treated a never-loaded History/Notes
  as known-empty); all repaired; round 2: no findings. The integrator ran
  `just verify` after the fast-forward and REQ-PIT-027: passed. Not checked
  on screen: the Road and Service actions below the fold at the largest
  size (reachable by scrolling), the empty Archived scope, the rendered
  disabled-first-action preview, VoiceOver, ru/uk. Follow-up for the owner
  (pre-existing, out of scope): History and Notes show their empty state
  before the first load and beside the load-failure banner, which claims an
  unread fact (core C2); Service already waits for `hasLoaded`.
- 2026-09-23, RD-009 (slice-writer): `just verify` passed before each commit;
  `PitColor`, `DesignTokens` and `PitTypography` moved to `Shared/DesignSystem/`
  and `GlyphDisc` extracted, with no project change; `CaptureWidgetSourceTests`
  (content, link, accented disc, no data read) and `DesignRulesTests` now
  also cover `Shared/` and `PitstopWidgets/` (named exemption:
  `NextServiceWidget.swift`); item 1 repair verified by mutation. Review
  round 1: 3 low (tests matched the Lock Screen branch; the gallery check
  was untracked; the design-system doc stated the old rule scope), all
  repaired; round 2: 3 low, accepted (the small-family scope anchors on the
  first `default:`; `readsNoData` scans a hand-kept file list; ADR 0038
  still states the original Features-only scope — a decision record, left
  as written). The integrator ran `just verify` after the fast-forward:
  passed. Not checked: the gallery in tinted and dark (DEV-WIDGET, now
  named in that row); the screenshots in `rd-009/` are a layout replica.
  Incident: the writer called the Xcode MCP `XcodeOpenWorkspace`, which left
  an approval request in Xcode for the owner (reported; writer rules now
  forbid Xcode MCP tools). Owner decisions: the REQ-DESIGN-004 proposed
  amendment (tests already enforce the wider scope; approve it or relabel
  the tests) and a follow-up card to restyle `NextServiceWidget` (SYS-007).
- 2026-09-23/24, RD-010 (slice-writer, not integrated): 5 step commits and
  14 repair commits on `worktree-agent-a40f1ea888bd47c34`, `just verify`
  before each, failing-first or mutation evidence for each repair. Pit
  rides in every non-Pit sheet (`pitSheet`, `pitStaysInSheet`), capture
  opens over a sheet and returns to it, Pit is disabled while a sheet
  saves, and Mark as done no longer duplicates a completion Pit recorded
  while it was open (REQ-MAINT-040, proposed). Simulator: the Pit sheet at
  the medium detent floats inset and hides the whole layer; at AX-XXXL it
  opens large. Not checked on screen: Pit inside any feature sheet or
  Settings (tracked as the owner-only `DEV-PIT-SHEET` row on the branch).
  Review: round 1, 1 high (a same-day rule dropped deliberate repeats and
  REQ-MAINT-031 supersede) + 3 medium + 1 low; round 2, 1 medium (typed
  input dropped silently) + 3 low; round 3, 1 medium (no VoiceOver
  feedback) + 4 low, where the stop rule applied and the owner approved one
  last repair in this session; round 4, 1 medium + 1 low open (see
  Blocking decisions). Owner decisions from this card: REQ-MAINT-040
  (proposed) and the REQ-UTILITY-012 status-line update the writer
  proposed (the medium-detent result).
- 2026-09-24, RD-010 resumed: the owner said "Продолжай" after the stop
  report, taken as the fourth repair. The writer rebased its branch onto
  452e4ea (only this brief differed) and split reading from opening Mark
  as done (a losing read changes nothing; an unreadable store refuses to
  open with the list's "not saved" alert), failing-first tests for both.
  Round 5: 0 high/medium, 1 low that predates the card (a Mark-as-done
  save still running after its sheet closed writes to the next sheet's
  state), filed as a follow-up. The integrator fast-forwarded to 250b36e
  and ran `just verify`: passed.
- 2026-09-24, RD-011 (slice-writer): `just verify` passed before each
  commit; `PitHead` draws the ADR 0037 icon geometry (icon not regenerated)
  and replaces the glass circle in the layer, in sheets and in the capture
  sheet header; `PitPose` per motion state (REQ-PIT-022), accent eyes on
  knock (REQ-PIT-023), head motion only in motion-table states
  (REQ-PIT-024); `PitEyesGlyph` removed, the ADR 0028 life plan kept in
  `PitEyeLife.swift`; ADR 0039 amends ADR 0009 (no glass on the Pit
  control). Screenshots and renders in `rd-011/`. The safety classifier was
  unavailable during the writer's run; the integrator audited the branch
  (scope, no Tooling/project/icon change, no push, `main` untouched). The
  first review run failed on an API network error and was resumed. Review
  round 1: 1 medium (per-layer shadows under the face screen) + 6 low, all
  repaired; round 2 (read without the skill, inside the time box): 0
  high/medium + 2 low on test strength (the pressed-tint render test sits
  inside rounding; the disabled test does not guard the style's own
  compositing group), accepted as follow-ups. The integrator fast-forwarded
  to dce4225, ran `just verify` (passed) and pushed the branch. Not checked
  on screen: the pressed state, Pit inside a feature sheet, Reduce
  Transparency, VoiceOver.

## Untested scope

- REQ-GRAMMAR-003 text clipping at the largest Dynamic Type size: manual,
  per card.
- iPhone Duo on screen: the iOS 27.1 simulator runtime is not installed on
  this Mac (owner-only DEV-DUO).

## Writer steps

Round opening:

- [x] Unfreeze the status docs, record SYS-008 scope and this brief: diff review — f50cb7e
- [x] Approve the REQ-BOARD-017 title wording: diff review — 6b3d589

RD-000:

- [x] Stage tint, on-accent colour and typography roles: `PitColorTests` — 3674b52
- [x] Status glyph vocabulary and status chip: `StatusGlyphTests`, `RoadProjectorTests` — d6aabc7
- [x] Stage, empty state, glass pill, step strip, share track: `RemainingShareTrackTests`, previews build — aece984
- [x] Design rules in `just verify`, Track several accent literals: `DesignRulesTests` — c901d10
- [x] ADR 0038 and the design-system, overview, plan and status docs: diff review — b898e56

RD-001 (writer: a `slice-writer` subagent of this session in its own
worktree from `2520d77`; output: step commits on its branch plus a report
of checks and screenshots; the integrator cherry-picks onto `redesign/ios27`
after an independent `/code-review`; SHAs below are the integrated ones):

- [x] Stage hero: mileage with recency from the newest observation date, glass pencil for edit: REQ-BOARD-027 tests — 8cdc992, repair 7acb6d2
- [x] Tile anatomy: title row chevron, primary and secondary lines, status chip where a state exists, Road tile state markers: REQ-BOARD-028 tests — 123eb03
- [x] Car Board docs: mockup deviations, system-overview row, work-plan row: diff review — ae76645
- [x] Review repair: Road tile labels wrap, AX hiding justified: `just verify` — 428639f
- [x] Review repair: one shared dashed road line: `just verify` — 286fcae

RD-002 (writer: a `slice-writer` subagent in its own worktree from the
dispatch commit; same output and integration as RD-001):

- [x] Draw the missing Road load-failure frame in the mockup page: diff review — 0871525
- [x] Road lane: roadside signs with state glyphs on one road line, "Back to now" glass pill, no compact mode: REQ-ROAD-028, 029 tests — 5d8b7f2
- [x] Grouped milestone list under "Ahead" and "Waiting for mileage" mirroring the lane, one-line past summary, tertiary estimate: REQ-ROAD-027 tests — c5aca16
- [x] Simulator repair: lane signs in proportion at accessibility sizes: `just verify` — 1bda0a5
- [x] Road docs: mockup deviations, system-overview row, work-plan row: diff review — 9662778
- [x] Review repair: list separators start at the row text at every size: `just verify` — 7b9624f
- [x] Review repair: falsifiable REQ-ROAD-029 geometry test: `just verify`, mutant failed — 087a3bd

RD-003 (writer: a `slice-writer` subagent in its own worktree from the
dispatch commit; same output and integration as RD-001):

- [x] Draw the missing Service frames (dashboard "old reading" row; "Track" menu with "Track several" disabled while loading): diff review — ec7e63e
- [x] One "Track" toolbar menu with the delivered items and disable rules; visible "Mark as done"; more menu with the dashboard-reading entries: existing Service tests — ce7028f
- [x] Share Road's grouped list section: `just verify` — fd91156
- [x] Grouped "Next visit" and "Tracked" lists with status chips and the remaining-share track under its freshness rule: share-track tests — be60cff
- [x] Service docs: mockup deviations, system-overview row, work-plan row: diff review — 980fe84
- [x] Review repair: one shared glyph-column row and more-menu label for Road and Service: `just verify` — f419bd4
- [x] Review repair: Track menu rule stated as canTrackOne: ADR-0033 menu tests — 0386c0c

RD-004 (writer: a `slice-writer` subagent in its own worktree from the
dispatch commit; same output and integration as RD-001):

- [x] Track several sheet: step strip, tinted quick-pick chips, stacked Confirm and Back: ADR 0033 tests — a7452ad
- [x] Track several docs: mockup deviations, system-overview row, work-plan row: diff review — aa52eed
- [x] Review repair: chip lines broken the same way in both layout passes: `ChipFlowLayoutTests` — 76fb3be
- [x] Review repair: disabled Confirm keeps its dimming; strip index derived: `TrackSeveralTests` — b88d91e
- [x] Round-2 repair: chip lines decided from the proposal in both passes, no tolerance: `ChipFlowLayoutTests`, mutant failed — df6e161
- [x] Round-3 repair: reported width covers an unshrinkable chip; faster boundary sweep: `ChipFlowLayoutTests`, mutants failed — a1ae952

RD-005 (writer: a `slice-writer` subagent in its own worktree from the
dispatch commit; same output and integration as RD-001):

- [x] History: month groups with a rail, distinct completions with a "corrected on Service" line: HistoryTests and a month-grouping test — 41f3697
- [x] History docs: mockup deviations, system-overview row, work-plan row: diff review — ae7f3a1
- [x] Review repair (finished by the integrator): plain rail dot, chevron kept at accessibility sizes: `just verify`, simulator — b682104

RD-006 (writer: a `slice-writer` subagent in its own worktree from the
dispatch commit; same output and integration as RD-001):

- [x] Notes: grouped rows, meta line, archive glyph plus swipe and VoiceOver action, wrapping context chips: NotesTests — 0ea4f8a
- [x] Notes docs: mockup deviations, system-overview row, work-plan row: diff review — a3629a5
- [x] Review repair (integrator): 44 pt archive target, whole-row tap opens the note: `just verify`, simulator — eb45fd8

RD-007 (writer: a `slice-writer` subagent in its own worktree from the
dispatch commit; same output and integration as RD-001; the eyes stay
`PitCaptureEyes` until RD-011 draws the head):

- [x] Sheet opens at the large detent at accessibility text sizes: REQ-PIT-025 tests — d0357c0
- [x] One moment at a time: eyes beside the moment title, composer with mode picker and a prominent capsule action, the pending question card above the composer, Close cancels unsent words: REQ-PIT-021 tests, Capture and Pit tests unchanged — 5e8e961
- [x] Confirmation quotes the raw words first, then every fact to be written; the saved state names the destination and offers one way to continue: Capture tests — 6171c71
- [x] Simulator repair: Remember above the keyboard at accessibility sizes; equal-width decline pair: `just verify`, simulator — ca9104a, e587cc7
- [x] Pit capture docs: mockup deviations, system-overview row, work-plan row: diff review — cce5e08
- [x] Review repair: Remember pinned at accessibility sizes with the question pending; detent fixed at open; composer refocus after an answer; equal-width row guards: `just verify`, `PitEqualWidthRowTests` — 7356892, f2058ac, 03111ea, 009a8e5
- [x] Round-2 repair: Remember quiet at every text size while the question is pending: `PitSheetMomentTests` — 93f1e3c
- [x] Round-3 repair: citations, mockup notes and comments match the rule: `just verify` — 72c39cf

RD-008 (writer: a `slice-writer` subagent in its own worktree from the
dispatch commit; same output and integration as RD-001):

- [x] Road, Service, History and Notes empty states use the design-system `EmptyState` (tinted glyph disc, headline, at most one sentence, one or two actions, top third), wording unchanged: REQ-GRAMMAR-004 tests, existing empty-state tests unchanged — c426bfa
- [x] First-launch Car Board against the "First minute" frame: no placeholder metric on a surface without records: REQ-GRAMMAR-004 and REQ-BOARD tests — 50ae194
- [x] Sparse states docs: mockup deviations, system-overview rows, work-plan row: diff review — 3b25a67
- [x] Review repair: 64 pt disc at every text size; a disabled first action dims its label; sparse tests from a loaded empty store: `just verify` — cccdb90, 4dc7bc6, 1944c46
- [x] REQ-PIT-027 approved by the owner; the RD-007 prominence test renamed: `just verify` — 62c6830

RD-009 (writer: a `slice-writer` subagent in its own worktree from the
dispatch commit; same output and integration as RD-001; scope is the
delivered "Remember" widget only: the work plan keeps the SYS-007 widgets,
now delivered as the next-service widget (ADR 0036), out of these cards):

- [x] The design tokens and glyph disc the widget needs compile into the widget target through `Shared/`, with no project-setting change and the app unchanged: `DesignRulesTests`, `just verify` — 5f724f1
- [x] "Remember" widget restyled with the shared glyph disc and tokens; content, intent and tap target unchanged; no data read: `WidgetEntryTests` — 9f93613
- [x] Widgets docs: mockup deviations, system-overview row, work-plan row (SYS-007 frames recorded as that card's input): diff review — 06e3aac
- [x] Review repair: small-family source checks, DEV-WIDGET row names the gallery check, colour-literal rule scope in the design-system doc: `just verify`, mutation — 2b55522, e405a09, b49448b

RD-010 (writer: a `slice-writer` subagent in its own worktree from the
dispatch commit; same output and integration as RD-001; the layer's
geometry and Settings stay unchanged):

- [x] Pit stays on screen inside every sheet other than the capture surface, at the bottom-trailing spot and above the keyboard; Settings is not shown over a sheet; both return to the layer when the sheet closes: REQ-UTILITY-012 tests — a161608
- [x] Tapping Pit in a sheet opens the capture surface over it, and closing returns to the same sheet with its input unchanged: REQ-PIT-026 tests — cadc8b3
- [x] Pit is disabled while Track several, the planned-date editor or the dashboard reading is saving: REQ-PIT-026 edge-case tests — 3f6be08
- [x] A capture over "Mark as done" for the same operation leaves no duplicate completion when the editor then saves: completion tests — 9702b95
- [x] Utility layer docs: medium- and large-detent simulator result, system-overview rows, work-plan row: diff review — 04eba5e
- [x] Review repair: completion recorded while the editor is open; Open Pit while capture is open; falsifiable saving guard; DEV-PIT-SHEET row; close on teardown: `just verify`, failing-first — d9d2709, 940b738, d02ed1f, 6f28af9, b88fda3
- [x] Round-2 repair: same-date rule keeps typed input (sheet stays open, "Save anyway"); snapshot from the store; waiting request met; teardown source check: `just verify` — 172c383, be521fc, 1d7fc6d, 3fa02b6
- [x] Round-3 repair (owner-approved): REQ-MAINT-040 proposed; VoiceOver announcement; recheck on "Save anyway"; no snapshot on read failure; late sheet guard: `just verify`, mutation — 2f32a0d, 7165af2, f7ac37e, b52e8b1, f7d4efe
- [x] Round-4 repair (owner: "Продолжай"): read and open split; no sheet on an unreadable store: `just verify`, failing-first — 09cb070, 250b36e

RD-011 (writer: a `slice-writer` subagent in its own worktree from the
dispatch commit; same output and integration as RD-001; the head keeps
the delivered icon geometry of ADR 0037, so no icon is regenerated, and a
needed geometry change stops the card for the owner):

- [x] Pit head component: pearl shell, bezel, navy visor and lit lens eyes, with Reduce Transparency and Increase Contrast variants, matching the ADR 0037 icon geometry: head geometry tests, previews — 69a7113
- [x] The head replaces the glass circle in the utility layer, in the Pit control inside sheets and in the capture sheet header, keeping the pressed-state feedback: `UtilityLayer` and `PitInSheet` tests, ADR 0028 tests unchanged — aa8f35c
- [x] Every motion state has a distinct static pose with inward eye tilt at most 6°: REQ-PIT-022 tests — 261b706
- [x] A knock turns the eyes to the accent and back, with or without Reduce Motion; no other state uses the accent: REQ-PIT-023 tests — a808b54
- [x] The head tilts or lifts only in motion-table states and is still when resting or idle; Reduce Motion shows the poses without animation: REQ-PIT-024 tests — 551fd58
- [x] ADR amending ADR 0009 for the Pit control (no glass) and the Pit character docs: mockup deviations, system-overview rows, work-plan row: diff review — 6f40809
- [x] Review repair: one shadow from the head outline; disabled Pit dims as one object; pressed tint follows the knock; knock from the tested keyframes; contrast and finish wording: `just verify`, render tests — 4461ce7, 568e789, e525955, dceba65, dce4225

## Resume prompt

Pitstop session, task `docs/tasks/redesign-ios27.md` on branch
`redesign/ios27`. The overnight run (RD-007…RD-011) is finished; nothing is
authorized to run unattended now. Owner decisions pending are listed under
Blocking decisions. Read `AGENTS.md`, this brief and the
work-plan row of the next card only. Check `git status` (clean, on `redesign/ios27`, no leftover
`.claude/worktrees/*` checkout; remove a finished writer worktree only after
confirming its commits are on the branch) and `git log -1`. Then continue at
"Next step" above: draft the next card's Writer steps in this brief, commit
that dispatch, and hand the card to a `slice-writer` subagent with
`agent-artifacts/2026-09-23/pitstop-ios27-redesign/work/writer-rules.md`.
Integrate each card after an independent `/code-review`: with one writer at a
time and nothing committed to `redesign/ios27` between its dispatch commit
and integration, run `git merge --ff-only worktree-agent-<id>`, then
`git worktree remove <path>` (no `--force`) and `git branch -d
worktree-agent-<id>`; none of these prompt the owner. If the fast-forward
fails, stop at that boundary; never fall back to `git branch -D` overnight.
Then run `just verify`, commit the "record integration" brief update after
the merge, and push `redesign/ios27` (the owner's per-card backup
decision). Overnight (see Authorized scope): run
RD-007…RD-011 in order without asking the owner, decide within the brief and
the mockup and record deviations, mark on-screen checks that need an access
prompt "not checked", skip RD-012, and stop at the last clean card boundary
by 09:00 Kyiv (06:00 UTC), or earlier if the gate fails after three repairs
or a card needs something outside the brief. Keep the registry next_step
current (`features/session/registry.py set <session id> --next-step`). SYS-008
depends on RD-012 and is not started overnight. This prompt authorizes no
merge into `main`, no push of `main` and no tag: those wait for the owner's
word in the session.

## Current checklist

- [x] Round opening committed
- [ ] RD-000…RD-012 and SYS-008 committed with `just verify` and review evidence
- [ ] `redesign/ios27` merged into `main`, version 1.2.0, `just release --check`
- [ ] Owner authorized the push; `tests.yml` green; `just tf-check` Ready; `tf-1.2.0-1` pushed
