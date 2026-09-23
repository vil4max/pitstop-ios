# Task — iOS 27 redesign round and iPhone Duo hardening to TestFlight 1.2.0

Assignee: Claude Code session (pitstop-ios), host Claude desktop
State: claimed
Requested by: owner (direct, 2026-09-23)
Evidence: pending
Depends-on: none
Parallelism: none

## Current status and authorization

Current outcome: RD-000…RD-005 landed on `redesign/ios27`; RD-006 is next.
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
Blocking decisions: none
Permitted deviations: RD-010 is re-estimated from 0.5d to about 2d because
REQ-UTILITY-012 and REQ-PIT-026 are not implemented on `main` (every sheet
covers the utility layer; `RootView.swift` ignores the keyboard for it).
Material assumptions: the design-rule check (REQ-DESIGN-002, 004) runs as a
Swift Testing suite inside `just verify`, because `Tooling/**` belongs to the
shared Runtime and `baseline.py` rejects drift in `Tooling/.swiftlint.yml`;
verified by `just verify` failing on a planted literal.
Next step: RD-006 Writer steps (drafted when the card starts).
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
| RD-006 Notes | NotesTests | RD-000 | in progress | — |
| RD-007 Pit capture sheet | REQ-PIT-021, 025 | RD-000 | planned | — |
| RD-008 Sparse states | REQ-GRAMMAR-004 | RD-000 | planned | — |
| RD-009 Widgets | WidgetEntryTests | RD-000 | planned | — |
| RD-010 Utility layer in sheets | REQ-UTILITY-012, REQ-PIT-026 | RD-000 | planned | — |
| RD-011 Pit character | REQ-PIT-022…024 | RD-000 | planned | — |
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

- [ ] Notes: grouped rows, meta line, archive glyph plus swipe and VoiceOver action, wrapping context chips: NotesTests
- [ ] Notes docs: mockup deviations, system-overview row, work-plan row: diff review

## Resume prompt

Pitstop session, task `docs/tasks/redesign-ios27.md` on branch
`redesign/ios27`. Read `AGENTS.md`, this brief and the work-plan row of the
next card only. Check `git status` (clean, on `redesign/ios27`, no leftover
`.claude/worktrees/*` checkout; remove a finished writer worktree only after
confirming its commits are on the branch) and `git log -1`. Then continue at
"Next step" above: draft the next card's Writer steps in this brief, commit
that dispatch, and hand the card to a `slice-writer` subagent with
`agent-artifacts/2026-09-23/pitstop-ios27-redesign/work/writer-rules.md`.
Integrate each card by cherry-pick after an independent `/code-review`, run
`just verify`, record the evidence here, and push `redesign/ios27` (the
owner's per-card backup decision). This prompt authorizes no merge into
`main`, no push of `main` and no tag: those wait for the owner's word in the
session.

## Current checklist

- [x] Round opening committed
- [ ] RD-000…RD-012 and SYS-008 committed with `just verify` and review evidence
- [ ] `redesign/ios27` merged into `main`, version 1.2.0, `just release --check`
- [ ] Owner authorized the push; `tests.yml` green; `just tf-check` Ready; `tf-1.2.0-1` pushed
