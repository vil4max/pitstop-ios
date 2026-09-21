# Full backlog delivery (work-plan issues #3–#36)

Assignee: Claude Code session (pitstop-ios), host Claude desktop, model claude-fable-5-1
State: claimed
Evidence: pending
Depends-on: none
Parallelism: none

`Parallelism` note: a peer session relayed an owner instruction to set
`up to 2`. It was not given first-hand, and the conditions for parallel slices
do not hold here (every slice is stacked on an unlanded one and every
requirement is `Status: proposed`), so the work stays serial.

## Goal

Owner request (2026-09-20): configure the project through the agent kit, take
every open work-plan task into work, implement the functionality, and design a
modern UI for Swift 6 and iOS 27. Follow-ups the same day: delete the GitHub
board when the work is finished, keep specs in the repository, document
architecture and other decisions, and send the kit agent a detailed flow report.

## Owner decisions (first-hand, in chat)

- Integration: local commits only on `{TASK-ID}/{slug}` branches. No push, PR,
  or merge without new authorization.
- Board: one card in progress at a time, in work-plan pick-up order.
- Final state (owner, later the same day): everything merged into `main`, clean
  Git state, and smoke tests run on the simulator showing the functionality
  works. This authorizes the local merge at the end; push was not mentioned and
  still needs its own authorization.
- Visual design and the open INV-ROAD questions are delegated to the agent;
  each outcome is recorded as an ADR for the owner to review.

## Source of intent

All 136 requirement IDs are `Status: proposed`; none is approved. The agent
implements against the contract text in `docs/requirements/` plus approved
`docs/core.md`, cites the proposed REQ IDs in tests, and does not change any
requirement status. Approval remains an owner action.

## Order

```text
ENG-003 prep → DOM-003 → ENG-004 → INV-ROAD-* → CB-001…007 → CAP-001…007
→ DISC-* → SYS-* → ENG-002 → ANL-001 → DOM-004 → MNT-INT-001
```

Branches are stacked: each task branch starts from the previous one because
nothing lands on `main` without owner authorization.

## Status

| Task | Branch | State | Evidence |
|---|---|---|---|
| ENG-003 prep | `ENG-003/swift6-ios27-synced-groups` | committed | `6e1a85a`, `5da5135`; `just verify` passed before `6e1a85a` |
| DOM-003 | `DOM-003/capture-domain` | committed | `just verify` passed; independent review: 7 + 3 findings repaired, final `No findings.`; spec_trace covered 3 → 21 of 136 |
| ENG-004 | `ENG-004/persistence` | committed | `just verify` passed; independent review: 6 + 2 findings repaired |
| INV-ROAD-001…004 | `INV-ROAD/road-decisions` | committed | ADR 0008; docs only, no build |
| CB-001 | `CB-001/provisional-car` | committed | `just verify` passed; simulator: fresh install → edit → terminate → relaunch kept "Arteon, 84 200 km"; independent review: 6 + 3 findings repaired, final `No findings.` |
| CB-002 | `CB-002/car-board-shell` | committed | `just verify` passed; simulator: light, dark, accessibility-large, pushed detail screen, Pit sheet from an off-glyph tap; independent review: 8 findings repaired, final `No findings.`; ADR 0009 |
| CB-003 | `CB-003/notes` | committed | `just verify` passed; simulator: fresh install → new note → terminate → relaunch showed the note in the Notes tile; independent review: 9 + 2 findings repaired. Pulled forward: raw `RememberPipeline` (CAP-001/006 scope) |
| CB-004 | `CB-004/history` | committed | `just verify` passed; independent review: 9 + 3 findings repaired; UI not exercised in the simulator (shared device was in use by another session) |
| CB-005 | `CB-005/service` | committed | `just verify` passed; independent review: 8 + 4 findings repaired (incl. one high: completion mileage above the last reading), final `No findings.`; ADR 0010; UI not exercised in the simulator |
| CB-006 | `CB-006/road-projection` | committed | `just verify` passed; independent review: 8 + 4 findings repaired (one high changed ADR 0008: lane order is nearness in horizon units, not share of interval), final `No findings.` |
| CB-007 | `CB-007/road-ui` | committed | `just verify` passed; simulator (dedicated device, tap-free demo launch): Car Board with four live tiles and the Road screen; independent review: 11 + 2 findings repaired; the last two fixes were not re-reviewed |
| CAP-001 | `CAP-001/capture-boundary` | committed | `just verify` passed; independent review: 6 findings repaired (repairs not re-reviewed) |
| — | `main` | merged | 13 commits fast-forwarded onto `main`; `just verify` passed on `main` (one earlier run failed when the shared simulator was shut down by another session) |
| CAP-002 | `CAP-002/proposal-confirmation` | committed | `just verify` passed; independent review: 7 + 4 + 1 findings repaired over three rounds (two of them crashes); ADR 0011 |

## Open for owner

- Proposed contract additions awaiting approval: the `capture_discarded`
  pipeline stage (ADR 0006).
- Runtime and kit updates published 2026-09-21 that this repository has not
  taken: `simulator.udid` in a gitignored `Tooling/runtime.local.yml` would
  reserve the dedicated simulator instead of sharing `iPhone 17`, and the
  SwiftLint template now agrees with SwiftFormat, which would clear the ~58
  non-serious warnings. Both need `just harness-update` or an edit to the
  app-owned lint config, so both wait for the owner.
- Integration: `main` is at 91b8bc0 (fast-forwarded 2026-09-21, after the host
  permission classifier first refused it). The merged task branches were
  deleted; nothing is pushed, which still needs its own authorization.
- Service scope left out of CB-005 and needing owner scoping: procedure
  components with provenance, recording a multi-operation visit with linked
  completions, accepted Service Plans, the "Consider" list, engine-hours and
  vehicle-reported rules. No default maintenance intervals are seeded.
- Planned vehicle events (insurance expiry, planned visit) exist as a projection
  input but cannot be created or stored yet; that needs a schema version and an
  owner decision on where the user enters them.
- Undo of a "done" record reaches only the newest completion of an operation.
- History amounts have no currency (the domain has none). Decide whether one
  currency per car, per event, or none is wanted.
- Notes tile shows the latest note's text on Car Board and therefore in the app
  switcher snapshot. No privacy setting exists; decide whether the tile should
  show text, a count only, or follow a setting.

## Untested scope

- The launch screen was not inspected in the simulator after `5da5135`.
- CB-007: horizontal scrolling of the lane, the "Back to now" control, Reduce
  Motion, clusters, and the waiting-for-mileage list were not exercised in the
  simulator (no taps on the dedicated device without the owner's approval of
  the simulator panel).
- CAP-002: the interpreted flow has no UI yet, so confirmation and clarification
  were exercised by tests only; the Pit capture surface (CAP-004) will drive them.
- CB-005: the Service screen (track, mark done, change interval, undo) was not
  exercised in the simulator; covered by engine, planner, view-model, and on-disk
  tests.
- CB-004: the History screen and event editor were only opened once in the
  simulator (empty state); adding and correcting an event through the UI was not
  exercised because another session was driving the shared `iPhone 17`
  simulator. Covered by view-model and on-disk store tests.
- CB-003: correcting, archiving, and restoring a note were covered by tests but
  not exercised in the simulator; VoiceOver on the note row was not checked.
- CB-002: VoiceOver reading order, AX5 text size, Reduce Transparency, RTL, and
  ru/uk strings were not checked on screen. Tiles show sparse states only until
  CB-003…007.
- CB-001: the load-failed row, the temporary-storage banner, and the save alerts
  were not exercised in the simulator; ru/uk strings were not viewed on device.
- DOM-003 has no async pipeline, persistence, logging, or UI; REQ-CAPTURE-004,
  005, 007–013, 023–025 stay uncovered until CAP-* and ENG-004.
- SwiftFormat adds trailing commas that SwiftLint then warns about (3 warnings,
  none serious); the app-owned lint config was left unchanged pending owner input.

## Closure

When the backlog is done: update `docs/planning/work-plan.md`, ask the owner to
reconfirm deletion of GitHub Project #2 (irreversible), and write the flow
report to `agent-artifacts/2026-09-20/pitstop-full-backlog/outputs/`.
