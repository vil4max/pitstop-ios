# Work Plan

**Status:** Active; see [`../PROJECT_STATUS.md`](../../PROJECT_STATUS.md)  
**Next task:** CAP-LOC-001 — pass the request locale into Pit's `CaptureInput`  
**Scope:** open work only. A delivered task leaves this file; ADRs and `git log` keep its record  
**WIP limit:** 1 implementation task **In progress** (solo)  
**Estimates:** ideal focused dev days  
**Process:** [`../engineering/agent-loop-and-gitflow.md`](../engineering/agent-loop-and-gitflow.md)

## Plan

Order is the pick-up order. `next` is the one task to start; `planned` waits
for its dependency or owner decision. SYS-007 is last because it moves the
store that TestFlight testers already hold.

| ID | Title | Est | Depends on | Status | Source | Owner decision needed |
|---|---|---:|---|---|---|---|
| CAP-LOC-001 | Pass the request locale into Pit's `CaptureInput` | 0.5d | — | next | [SYS-001 record](investigations/sys-001-app-intents.md), ADR 0023 | — |
| MNT-POL-001 | Stop tracking an operation (remove the owner's policy) | 1d | — | planned | [MNT-INT-001 record](investigations/mnt-int-001-maintenance-intelligence.md), area 2 | — |
| ROAD-EVT-001 | Planned dated events: storage, commands, entry; insurance expiry first | 3d | owner decision | planned | [MNT-INT-001 record](investigations/mnt-int-001-maintenance-intelligence.md), area 3 | Where the user enters a dated event; user label on `other`; whether insurance expiry also shows on Car Board |
| MNT-PRE-001 | "Track several" starter with owner intervals | 2d | MNT-POL-001, product review gate | planned | [MNT-INT-001 record](investigations/mnt-int-001-maintenance-intelligence.md), area 2 | Build now or after beta evidence; allowed cadence chip values; whether car-class questions may become vehicle facts |
| MNT-INT-002 | Recommendation provenance fixture (fictional car, tests only) | 1d | owner decision | planned | [MNT-INT-001 record](investigations/mnt-int-001-maintenance-intelligence.md), area 1 | Stop at owner cadence or run it now; target market |
| ROAD-EST-001 | Mileage-rate estimate for distance milestones (investigation) | 1d | ROAD-EVT-001 | planned | [MNT-INT-001 record](investigations/mnt-int-001-maintenance-intelligence.md), R5 | Whether estimates are wanted at all; requires a REQ-ROAD-007 change |
| MNT-VR-001 | Vehicle-reported remaining value as a rule (investigation) | 1d | — | planned | [MNT-INT-001 record](investigations/mnt-int-001-maintenance-intelligence.md), R6 | — |
| SYS-007 | Widget with car data: App Group, store move, next-service widget | 3d+ | SYS-005 | planned | [SYS-004 record](investigations/sys-004-widgets.md), "Cost of a data widget"; ADR 0025 | Approve the data widget; register the App Group; accept the ADR 0007 change and a device migration check |

Not scheduled: ENG-UIT-001 (UI test target for App Intents Testing; not added
now per ADR 0023, decision 6) and INV-CAP-004 (microphone start from an
external entry; needs a voice capture path in Pit).

## Owner-only work

| ID | Item | Source |
|---|---|---|
| MNT-INT-003 | Private licence and terms review of one real maintenance source, outside this repository (after MNT-INT-002 and a market decision) | [MNT-INT-001 record](investigations/mnt-int-001-maintenance-intelligence.md) |
| DEV-SIRI | Device check list: Siri in ru and uk, reply language, locked phone, prompt time against the 30-second limit | ADR 0026 |
| DEV-WIDGET | Widget gallery, Control Center, Lock Screen control, Action button, Shortcuts listing | ADR 0025, ADR 0026 |
| DEV-FM | Device evaluation of English captures with Foundation Models; then close or keep CAP-005 open, decide the Release rollout gate and the `interpreter_version` value | ADR 0027 |

## Owner decisions pending

- Requirements: 136 REQ IDs are `Status: proposed`; only REQ-BOARD-026 is
  approved. Approval is an owner action.
- ADR 0020: questions A–D (promote ADR 0001, recommendation data source,
  Service Plan vs multi-operation visit order, legacy data import) and the
  proposed maintenance-engine success-criterion change. The legacy spike source
  is no longer kept anywhere (ADR 0014).
- ADR 0018: REQ-PIT-008 wording ("is not asked again" versus "while that answer
  still holds").
- ADR 0006: the proposed `capture_discarded` pipeline stage.
- ADR 0022: PostHog project and key, and the consent decision (off by default
  under ADR 0021).
- ADR 0024, ADR 0026: review of the ru and uk App Shortcut and Siri phrases.
- Owner review of the agent decisions that say so in their status: ADR 0024,
  ADR 0026, ADR 0027.
- Product scope without a task yet: multi-operation visit recording and
  accepted Service Plans (ADR 0020 C), procedure components with provenance,
  the "Consider" list, engine-hours rules; undo reaches only the newest
  completion of an operation; History amounts have no currency; the Notes tile
  shows note text in the app switcher snapshot (count only, text, or a
  setting).

## Not verified on screen

Covered by tests but not exercised in the simulator or on a device: Road lane
scrolling, "Back to now", clusters and Reduce Motion; the Service actions
(track, mark done, change interval, undo); adding and correcting History
events; correcting, archiving and restoring notes; VoiceOver order, AX5 text
size, Reduce Transparency and ru/uk strings on screen; question returns that
need days of clock time.

## Delivered

Per-card rows were removed on 2026-09-21; `git log` holds them, including the
retired delivery brief `docs/tasks/full-backlog-delivery.md`. Decisions are
indexed in [`../README.md`](../README.md) under `decisions/`.

- M1 engineering bootstrap: BOOT-001, ENG-001, ENG-003 (local `just verify`
  gate plus shared hosted CI and rulesets, ADR 0013, 0014).
- M2–M3 domain and Car Board: DOM-001…004, ENG-004, INV-ROAD-001…004, CB-001…007
  (ADR 0007–0010, 0020).
- M4 Remember: CAP-001…007 (ADR 0006, 0011, 0015, 0027).
- Progressive discovery: DISC-001…004 (ADR 0012, 0016–0019).
- Pit motion: PIT-MOTION-001, livelier eyes and the full motion language
  (owner request 2026-09-21, ADR 0028).
- App icon: ICON-001, Pit's eyes as a Liquid Glass Icon Composer icon
  (owner decision 2026-09-21, ADR 0029).
- Launch screen: the old "P" artwork replaced by Car Board's plain grouped
  background, per HIG "Launching" (ADR 0029, "Launch screen").
- System capture: SYS-001…006 (ADR 0023–0026).
- Analytics: ENG-002, ANL-001 (ADR 0021, 0022); maintenance intelligence
  investigation MNT-INT-001.
- TestFlight: 1.0.0 and 1.1.0 rounds (tags `tf-1.0.0-1`, `tf-1.1.0-1`).
