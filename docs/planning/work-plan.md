# Work Plan

**Status:** Active since 2026-09-23 (owner unfroze it); see [`../PROJECT_STATUS.md`](../../PROJECT_STATUS.md)  
**Next task:** RD-010 (`next`); the round is tracked in [`../tasks/redesign-ios27.md`](../tasks/redesign-ios27.md)  
**Scope:** open work only. A delivered task leaves this file; ADRs and `git log` keep its record  
**WIP limit:** 1 implementation task **In progress** (solo)  
**Estimates:** ideal focused dev days  
**Process:** [`../engineering/agent-loop-and-gitflow.md`](../engineering/agent-loop-and-gitflow.md)

## Plan

No implementation card is open outside the redesign section below. The
redesign round is under way: RD-000 (design system, ADR 0038), RD-001
(Car Board), RD-002 (Road), RD-003 (Service), RD-004 (Track several),
RD-005 (History), RD-006 (Notes), RD-007 (Pit capture sheet), RD-008 (sparse states) and RD-009 (widgets) have landed on `redesign/ios27`, and RD-010 is next; the app icon already shows the redesigned Pit (ICON-002, ADR 0037) as its announcement.

Not scheduled: ENG-UIT-001 (UI test target for App Intents Testing; not added
now per ADR 0023, decision 6) and INV-CAP-004 (microphone start from an
external entry; needs a voice capture path in Pit).

SYS-008 (iPhone Duo layout hardening) closes the redesign round, after
RD-012. Owner decision (2026-09-23): harden the layouts on the iOS 27.0 SDK
and keep the Xcode 27.0 toolchain; no iOS 27.1 API. Apple's
[Xcode 27.1 beta release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27_1-release-notes)
list the iPhone Duo Simulator runtime, and
[`ArrangementView`](https://developer.apple.com/documentation/swiftui/arrangementview)
is iOS 27.1 beta API. Adopting it, the full-screen opt-in and the hinge APIs
wait for a follow-up card once Xcode 27.1 ships.

## Redesign (iOS 27)

Proposal: [`ios27-redesign-proposal.md`](ios27-redesign-proposal.md),
approved by the owner on 2026-09-22; the mockup page lives in
[`../design/ios27-mockups.html`](../design/ios27-mockups.html) until the
redesign is implemented (no Figma screens by owner decision). RD-000 went first because
every screen card uses its components. The cards run strictly one at a time
on one redesign branch (`redesign/ios27`), because they share the design
system, the string catalog and the same screens; `main` stays releasable to
TestFlight throughout, and the branch merges when the last card lands.
Each card is one screen, keeps that screen's behaviour and tests, adds
light/dark and accessibility-extra-large previews, updates
`docs/design/ios27-mockups.html` if the screen deviates from it, and updates the screen's row in
`docs/engineering/system-overview.md`. The redesign ADR is
[0038](../decisions/0038-ios27-surface-tiers.md). Not part of these cards: the SYS-007 widgets (the next-service widget keeps its delivered look; the mockup's small "Next service" and medium "Road" frames are the input for a later card that restyles it, not yet scheduled); RD-003 restyled the delivered
MNT-VR-002 row line and kept its sheet and menu entries without changing their wording.
ROAD-EST-002 has landed its estimate line on Road; RD-002 kept it as
delivered. Text-clipping at accessibility
sizes (REQ-GRAMMAR-003) is a manual check listed under "Not verified
on screen" until a snapshot-testing card exists.

| ID | Screen | Est | Depends on | Status | Acceptance (summary) |
|---|---|---:|---|---|---|
| RD-010 | Utility layer and Settings: no geometry change; REQ-UTILITY-012 test; Settings unchanged | 0.5d | RD-000 | next | Layer position identical on Car Board and every detail screen; Pit stays on screen inside every sheet and above the keyboard (REQ-UTILITY-012, REQ-PIT-026), checked on the simulator at the medium and large detents; tapping Pit in a sheet opens capture over it and returns with the input intact; edge cases checked: a capture over "Mark as done" for the same operation leaves no duplicate completion when the editor then saves; Pit is disabled while Track several, the planned date editor or the dashboard reading is saving; above the keyboard Pit covers neither a sheet's trailing controls nor a keyboard accessory, at AX sizes (and in landscape if the app supports it) |
| RD-011 | Pit character: round head (the utility circle itself) with a navy visor and lit lens eyes (owner request, proposal §3.6d), per-eye tilt, head tilt and lift only in motion-table states, accent eyes on knock; the head matches the delivered icon geometry (ADR 0037), and a geometry change regenerates the icon in this card | 2d | RD-000 | planned | Every motion state has a distinct static pose (REQ-PIT-022); inward tilt ≤ 6°; knock uses the accent (REQ-PIT-023); head still when idle (REQ-PIT-024); ADR 0028 tests pass; Reduce Motion poses checked; the head keeps the pressed-state feedback the glass circle gave (scale and highlight on touch); Reduce Transparency and Increase Contrast variants of the shell, bezel and visor; contrast and separation of the head checked over light and dark scrolling content; the ADR amends ADR 0009 for the Pit control (no glass) |
| RD-012 | Car profile: `PhotosPicker` in the car editor (no camera), on-device subject lift onto the stage, the owner's side-view placeholders facing right, SUV (default) or sedan chosen in the car editor, replacing `AbstractCarView` (AI-generated by the owner, provenance in `docs/design/assets/README.md`), 28 / 44 pt avatar in headers, Road "Now" and Pit; the next schema version after the newest on `main`, previous one frozen; car-profile ADR | 3d | RD-001 | planned | REQ-BOARD-029…031, REQ-DESIGN-005 and the REQ-BOARD-017 wording change; migration tests from every shipped schema version; photo stored as a file, never in a row, analytics, logs, a widget timeline entry or the repository; placeholder source and licence recorded; failed lift falls back to the masked photo; deleting the photo removes the file; widget avatar waits for SYS-007 |

## Owner-only work

| ID | Item | Source |
|---|---|---|
| MNT-INT-003 | Private licence and terms review of one real maintenance source, outside this repository (MNT-INT-002 is done; needs a market decision) | [MNT-INT-001 record](investigations/mnt-int-001-maintenance-intelligence.md) |
| DEV-SIRI | Device check list: Siri in ru and uk, reply language, locked phone, prompt time against the 30-second limit | ADR 0026 |
| DEV-WIDGET | Widget gallery (capture and next-service widgets), Control Center, Lock Screen control and rectangular/inline widget, Action button, Shortcuts listing; TestFlight upgrade check of the store move; first Xcode Cloud archive carries the App Group in both profiles | ADR 0025, ADR 0026, ADR 0036 |
| DEV-ICON | Home Screen app icon on a device in dark, clear and tinted styles; glass tuning by eye in Icon Composer | ADR 0029, ADR 0037 |
| DEV-FM | Device evaluation of English captures with Foundation Models; then close or keep CAP-005 open, decide the Release rollout gate and the `interpreter_version` value | ADR 0027 |

## Owner decisions pending

- Requirements: 176 REQ IDs are `Status: proposed` (SYS-007 added REQ-WIDGET-001…010; MNT-VR-002 added
  REQ-MAINT-030…039 and REQ-ROAD-026 and reworded REQ-MAINT-023 as the owner
  approved in substance). 29 are approved: REQ-BOARD-026, REQ-ICON-001,
  REQ-ROAD-007, 022, 023, and the iOS 27 redesign set approved in the design
  session on 2026-09-22 (REQ-DESIGN-001…005, REQ-GRAMMAR-001…004,
  REQ-BOARD-027…031, REQ-ROAD-027…029, REQ-PIT-021…026, REQ-UTILITY-012). Approval is an owner
  action; design decisions are made and approved in the design session.
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
days of clock time; after each RD card lands, text clipping at the
largest Dynamic Type size on that screen (REQ-GRAMMAR-003, manual).

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
  (owner decision 2026-09-21, ADR 0029); ICON-002 redrew it as Pit's round
  head from the redesign, shipped ahead of the redesign (owner decision
  2026-09-22, ADR 0037).
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
- Recommendation provenance fixture: MNT-INT-002, test-only provenance and
  applicability shape with a fictional schedule (Example Motors Kestrel,
  fictional market "XM"); every fictional rule is expressible, a mismatch or an
  unknown fact yields no recommendation, the owner's policy stays effective;
  no production change. Owner decision 2026-09-22 under the "do everything"
  delegation; production-model gaps are listed in the MNT-INT-001 record.
- Pre-redesign preparation: PREP-002, 004, 005, 009, 010, 011, 012, 014 and
  015, behaviour- and pixel-preserving except the fictional example name. The
  unreachable pending surface and its string are gone (PREP-011);
  `DesignSystem/Components/LoadFailureBanner` serves five screens (PREP-002);
  `Features/Shared` gains `FeatureEmptyState` (PREP-004), `SaveSheetScaffold`
  for six editors, with `MarkDoneView` keeping its in-form confirmation
  (PREP-005), `FeatureFormat` for day recency, mileage and amount precision
  (PREP-010), and `ProgressText` with the neutral `progress.*` keys shared by
  Service and Road (PREP-009); `RootView` and `ServiceView` bodies are under the
  80-line lint warning (PREP-012); tests share `TestViewModels` and `TestStore`
  from `PitstopTests/Support` (PREP-014); fixtures, demo data and the car-name
  placeholder use the fictional Kestrel and VIN-like values that cannot be
  real (PREP-015). PREP-006 was not done: `Color.accentColor` does not follow
  `.tint`, so the two Track several uses do not render `PitColor.accentPrimary`
  today, and routing them through it is a visible colour change left to the
  redesign.
- Data widget: SYS-007, App Group `group.dev.vil4max.pitstop`, a one-time
  non-destructive move of the store into the group container, and a
  read-only "Next service" widget that shows Service's first operation
  through the shared engine and opens Service (ADR 0036).
- TestFlight: 1.0.0 and 1.1.0 rounds (tags `tf-1.0.0-1`, `tf-1.1.0-1` to `tf-1.1.0-3`).
