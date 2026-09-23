# Task — iOS 27 redesign round and iPhone Duo hardening to TestFlight 1.2.0

Assignee: Claude Code session (pitstop-ios), host Claude desktop
State: claimed
Requested by: owner (direct, 2026-09-23)
Evidence: pending
Depends-on: none
Parallelism: none

## Current status and authorization

Current outcome: round opened; RD-000 is next. No card has landed.
Authorized scope: owner, in this session on 2026-09-23, answering the plan
questions and approving the plan: "Yes, unfreeze now"; "Whole backlog,
per-card gates" (the whole sequence is approved once; each card is briefed
and committed as it lands); TestFlight "After redesign + Duo land";
SYS-008 "Harden on SDK 27.0" (keep the Xcode 27.0 toolchain, no iOS 27.1
API; `ArrangementView` and the full-screen opt-in become a later card);
REQ-BOARD-017 "Approve the new wording now"; push "Local only, ask at the
end" (nothing leaves this Mac until the merge, then one question for
pushing `main` and `tf-1.2.0-1`).
Blocking decisions: none
Permitted deviations: RD-010 is re-estimated from 0.5d to about 2d because
REQ-UTILITY-012 and REQ-PIT-026 are not implemented on `main` (every sheet
covers the utility layer; `RootView.swift` ignores the keyboard for it).
Material assumptions: the design-rule check (REQ-DESIGN-002, 004) runs as a
Swift Testing suite inside `just verify`, because `Tooling/**` belongs to the
shared Runtime and `baseline.py` rejects drift in `Tooling/.swiftlint.yml`;
verified by `just verify` failing on a planted literal.
Next step: RD-000 Writer steps below.
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
| Round opening (docs) | REQ-BOARD-017 wording | — | in progress | — |
| RD-000 design system | REQ-DESIGN-001…004 | — | planned | — |
| RD-001 Car Board | REQ-BOARD-001…028 | RD-000 | planned | — |
| RD-002 Road | REQ-ROAD-004, 008…015, 027…029 | RD-000 | planned | — |
| RD-003 Service | Service tests, REQ-DESIGN-001 | RD-000 | planned | — |
| RD-004 Track several | ADR 0033 tests | RD-003 | planned | — |
| RD-005 History | HistoryTests | RD-000 | planned | — |
| RD-006 Notes | NotesTests | RD-000 | planned | — |
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

## Untested scope

- REQ-GRAMMAR-003 text clipping at the largest Dynamic Type size: manual,
  per card.
- iPhone Duo on screen: the iOS 27.1 simulator runtime is not installed on
  this Mac (owner-only DEV-DUO).

## Writer steps

Round opening:

- [ ] Unfreeze the status docs, record SYS-008 scope and this brief: diff review
- [ ] Approve the REQ-BOARD-017 title wording: diff review

## Current checklist

- [ ] Round opening committed
- [ ] RD-000…RD-012 and SYS-008 committed with `just verify` and review evidence
- [ ] `redesign/ios27` merged into `main`, version 1.2.0, `just release --check`
- [ ] Owner authorized the push; `tests.yml` green; `just tf-check` Ready; `tf-1.2.0-1` pushed
