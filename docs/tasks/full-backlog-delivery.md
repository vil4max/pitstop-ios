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

## Untested scope

- The launch screen was not inspected in the simulator after `5da5135`.
- DOM-003 has no async pipeline, persistence, logging, or UI; REQ-CAPTURE-004,
  005, 007–013, 023–025 stay uncovered until CAP-* and ENG-004.
- SwiftFormat adds trailing commas that SwiftLint then warns about (3 warnings,
  none serious); the app-owned lint config was left unchanged pending owner input.

## Closure

When the backlog is done: update `docs/planning/work-plan.md`, ask the owner to
reconfirm deletion of GitHub Project #2 (irreversible), and write the flow
report to `agent-artifacts/2026-09-20/pitstop-full-backlog/outputs/`.
