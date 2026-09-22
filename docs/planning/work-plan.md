# Work Plan

**Status:** Active; see [`../PROJECT_STATUS.md`](../../PROJECT_STATUS.md)  
**Next task:** MNT-INT-002 — Recommendation provenance fixture (fictional car, tests only)  
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
| MNT-INT-002 | Recommendation provenance fixture (fictional car, tests only) | 1d | owner decision | next | [MNT-INT-001 record](investigations/mnt-int-001-maintenance-intelligence.md), area 1 | Stop at owner cadence or run it now; target market |
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

- Requirements: 166 REQ IDs are `Status: proposed` (MNT-VR-002 added
  REQ-MAINT-030…039 and REQ-ROAD-026 and reworded REQ-MAINT-023 as the owner
  approved in substance); REQ-BOARD-026 and REQ-ICON-001 are approved. Approval is an owner action.
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
  ADR 0026, ADR 0027, ADR 0030, ADR 0031, ADR 0032 (including its three
  delegated answers: entry on Road, an optional label on `other`, insurance on
  Road only), ADR 0033 (including its three delegated answers: build now,
  unselected quick picks of 5,000 / 7,500 / 10,000 / 15,000 km and 6 / 12 / 24
  months labelled as common choices, car-type answers reorder only and are not
  stored), ADR 0035 (the proposed analytics events; its four implementation
  choices were approved by the owner on 2026-09-22).
- Product scope without a task yet: multi-operation visit recording and
  accepted Service Plans (ADR 0020 C), procedure components with provenance,
  the "Consider" list, engine-hours rules; undo reaches only the newest
  completion of an operation; History amounts have no currency; the Notes tile
  shows note text in the app switcher snapshot (count only, text, or a
  setting).

## Not verified on screen

Covered by tests but not exercised in the simulator or on a device: Road lane
scrolling, "Back to now", clusters, Reduce Motion and the milestone date
estimate line; the Service actions
(track, track several, mark done, change interval, undo, stop tracking); editing a planned
date and the ru/uk editor strings (adding and deleting one were checked in en on
the simulator, 2026-09-22); adding and correcting History events;
correcting, archiving and restoring notes; the dashboard reading sheet, the
"Car says" line, "old" wording, supersede by "Mark done", delete, the Road
"from dashboard" suffix and the Pit dashboard capture (MNT-VR-002); VoiceOver order, AX5 text size,
Reduce Transparency and ru/uk strings on screen; question returns that need
days of clock time.

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
- Capture locale: CAP-LOC-001, Pit and the Notes editor pass the app's
  current locale into `CaptureInput`; the `ru_RU` default is gone (ADR 0030).
- Stop tracking: MNT-POL-001, the owner removes their own policy for an
  operation behind a confirmation; completions and History stay, and the
  operation returns to Track (ADR 0031).
- Planned dates: ROAD-EVT-001, the owner adds an insurance expiry or another
  date with an optional name on Road, and edits or deletes it there; one
  insurance expiry on Road per car; schema V3 with V2 frozen (ADR 0032).
- Track several: MNT-PRE-001, the owner picks untracked operations on
  Service, enters every interval (optional unselected quick picks), confirms
  one summary; items are saved one at a time as the owner's own policies with a
  per-item result and retry of failed items; gearbox and drive answers only
  reorder the list and are never stored (ADR 0033).
- Analytics: ENG-002, ANL-001 (ADR 0021, 0022); maintenance intelligence
  investigation MNT-INT-001.
- Investigations ROAD-EST-001 (mileage-rate estimate) and MNT-VR-001
  (dashboard countdown); both approved by the owner on 2026-09-22 and
  scheduled as ROAD-EST-002 and MNT-VR-002.
- Road date estimate: ROAD-EST-002, a distance milestone carries a labelled
  date range derived from the reading history and shown under the kilometre
  fact; derived on read, never stored, and it changes no placement, order or
  cluster (REQ-ROAD-007, 022, 023 approved 2026-09-22; ADR 0034).
- Dashboard reading: MNT-VR-002, the owner enters what the car's display says
  is left (distance with an explicit km / mi unit and/or days, odometer with a
  distance) on Service or through a confirmed Pit capture; derived anchors, the
  earlier anchor per dimension, superseded by a newer completion, "old" after
  180 days without expiry, visible until deleted; Road says "from dashboard"
  when the reading decided; schema V4 with V3 frozen (ADR 0035).
- Architecture: ARCH-001, the inward dependency rule restored: the persistence
  mode and the mileage and amount parsers moved to `Features/Shared`, so no
  feature reads `AppEnvironment` or another feature's view model.
- TestFlight: 1.0.0 and 1.1.0 rounds (tags `tf-1.0.0-1`, `tf-1.1.0-1`).
