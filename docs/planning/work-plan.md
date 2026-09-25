# Work Plan

**Status:** Active since 2026-09-23 (owner unfroze it); see [`../PROJECT_STATUS.md`](../../PROJECT_STATUS.md)  
**Next task:** SYS-008 (1.3.0), after the owner's device check of `tf-1.2.0-1` ([`../operations/releases/1.2.0.md`](../operations/releases/1.2.0.md)); FIX-LOAD-001/002, FU-6, FU-7 and LAB-001 are queued  
**Scope:** open work only. A delivered task leaves this file; ADRs and `git log` keep its record  
**WIP limit:** 1 implementation task **In progress** (solo)  
**Estimates:** ideal focused dev days  
**Process:** [`../engineering/agent-loop-and-gitflow.md`](../engineering/agent-loop-and-gitflow.md)

## Plan

No implementation card is open outside the redesign section below. The
redesign round is under way: RD-000 (design system, ADR 0038), RD-001
(Car Board), RD-002 (Road), RD-003 (Service), RD-004 (Track several),
RD-005 (History), RD-006 (Notes), RD-007 (Pit capture sheet), RD-008 (sparse states), RD-009 (widgets), RD-010 (utility layer in sheets) and RD-011 (Pit character, ADR 0039) have landed on `redesign/ios27`, and RD-012 is next; the app shows the same Pit head as the icon (ICON-002, ADR 0037).

Not scheduled: ENG-UIT-001 (UI test target for App Intents Testing; not added
now per ADR 0023, decision 6) and INV-CAP-004 (microphone start from an
external entry; needs a voice capture path in Pit).

SYS-008 (iPhone Duo layout hardening) follows TestFlight 1.2.0 as its own
round, for 1.3.0 (owner, 2026-09-24: "1.2.0 after RD-012"). Owner decision (2026-09-23): harden the layouts on the iOS 27.0 SDK
and keep the Xcode 27.0 toolchain; no iOS 27.1 API. Apple's
[Xcode 27.1 beta release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27_1-release-notes)
list the iPhone Duo Simulator runtime, and
[`ArrangementView`](https://developer.apple.com/documentation/swiftui/arrangementview)
is iOS 27.1 beta API. Adopting it, the full-screen opt-in and the hinge APIs
wait for a follow-up card once Xcode 27.1 ships. The toolbar audit on the
iPhone Duo Simulator is part of UI-TB-001 (owner, 2026-09-24).

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
[0038](../decisions/0038-ios27-surface-tiers.md). Not part of these cards: the SYS-007 widgets (FU-2 restyled the next-service widget on 2026-09-24; the mockup's medium "Road" widget is not delivered); RD-003 restyled the delivered
MNT-VR-002 row line and kept its sheet and menu entries without changing their wording.
ROAD-EST-002 has landed its estimate line on Road; RD-002 kept it as
delivered. Text-clipping at accessibility
sizes (REQ-GRAMMAR-003) is a manual check listed under "Not verified
on screen" until a snapshot-testing card exists.

| ID | Screen | Est | Depends on | Status | Acceptance (summary) |
|---|---|---:|---|---|---|
| UI-TB-001 | Toolbar priorities on narrow and iPhone Duo widths: every sheet keeps its title readable. Audit (2026-09-24, iPhone SE 3rd generation, 375 pt, ru, default and largest text size): pushed screens fit (Notes, Road and History have one icon-only item; the Service "Track" menu keeps its text and the bar caps its size); sheets truncate the inline title between two text buttons, e.g. Track several "Отслеживать н…" and Track an operation "Отслежив…", in `SaveSheetScaffold` (car editor, note, event, planned date, interval, dashboard reading) and `TrackSeveralView`; Mark as done fits. No `visibilityPriority` or `ToolbarItemGroup` is used. Options for the design session, per sheet: standard glyph buttons through `ButtonRole.close` / `.confirm` (iOS 26.0) for Cancel, Save and Next; shorter ru/uk titles; or the title moved into the content with an empty bar title. The iPhone Duo folded and unfolded check waits for the iPhone Duo Simulator, which ships with Xcode 27.1 (owner download) | 1d | RD-000 | planned (design decision) | Every sheet title readable at 375 pt in en, ru and uk at the default text size; bar items keep their order and roles; checked on iPhone Duo folded and unfolded once the simulator is available |
| FIX-LOAD-001 | Profile: fix. Service and Road show their empty state beside the "not loaded" banner after a failed reload (FU-1 review finding 1, pre-existing, core C2): `ServicePresentation.swift` guards on `hasLoaded` only and `RoadView.swift` renders `projection.sparseState` without checking `isLoadFailed`; History and Notes already show only the banner (FU-1) | 0.5d | RD-012 | planned (owner, 2026-09-24: after RD-012) | A failing test first: an empty store loads, then a reload throws, and Service and Road show only the failure banner with its retry, never "Nothing tracked" or Road's sparse state beside it, matching History and Notes; `just verify`; one review |
| FIX-LOAD-002 | Profile: fix. Car Board tiles claim there are no notes and no history when the first load fails (FU-1 review finding 2, pre-existing, core C2): `CarBoardViewModel.load()` keeps the `.empty` defaults when it throws and `CarBoardTileContent.swift` starts every tile from `sparseHeadline` / `sparseDetail` | 0.5d | RD-012 | planned (owner, 2026-09-24: after RD-012) | A failing test first: a first load that throws shows the retry row without tiles stating that nothing is recorded; `just verify`; one review |
| FU-6 | Profile: fix. Car photo robustness, from the RD-012 reviews (lows, not repaired in the round): an original with alpha is JPEG-encoded without flattening (`CarPhotoStore.swift:126`); a cancelled decode can overwrite a newer photo, the hero and Road tile decode the same file twice, and a replaced photo's bitmaps stay cached (`CarVisual.swift:138`, `:91`, `:45`); the view model's photo id follows only a reload (`CarBoardViewModel.swift:159`); files stay unreferenced if the app dies between writing them and the command, or when deleting old files fails; an undecodable pick shows only the generic failure (`CarEditorView.swift:42`); the failed-load line is not announced to VoiceOver (`CarEditorView.swift:114`); an untouched stale-mileage confirmation whose store read fails closes as saved, and the read and the write are separate store calls (`CarBoardViewModel.swift:300`, `:192`, from the 1.2.0 stale-draft fix) | 1d | RD-012 | planned | A failing test first for each behaviour; unreferenced files under `CarPhotos/` are swept on launch; `just verify`; one review |
| FU-7 | Profile: fast. Car profile test hygiene, from the RD-012 reviews: pin that the widget leaves a shipped V4 store untouched (`NextServiceWidgetTests.swift:340`); retag the editor lock test away from REQ-BOARD-029 (`CarEditorTests.swift:56`); rename `failedLoadKeepsTheSavedPhoto` and cover remove, pick, failed pick (`CarEditorTests.swift:137`, `:156`); read the whole `ScreenHeader(` call in the placement test and check the avatar's order in the stacked header (`CarAvatarPlacementTests.swift:131`, `:164`); scope `RootView`'s car-picture read to a small view (`RootView.swift:95`); cover a completion or dashboard reading saved by Pit while the editor's reload fails (`CarEditorOpeningTests.swift:156`); drop the stale "(REQ-MAINT-040, proposed)" comments (`ServiceViewModel.swift:29`, `:278`, gate review) | 0.5d | RD-012 | planned | Each test fails when its behaviour is broken; `just verify` |
| LAB-001 | Check whether Pitstop ships any lab experiment (for example the DEBUG-only Foundation Models path, ADR 0027) and name kit KIT-D-046's rule in `docs/core.md`: a lab experiment reaches TestFlight only, gated at run time by StoreKit's `AppTransaction` environment (Xcode or sandbox), never the App Store | 0.5d | RD-012 | planned | Each experiment listed with its gate; the core rule proposed for the owner's approval |
| ABOUT-001 | Profile: round. Settings → About gains the line on who makes PitStop and how, and a "Source code on GitHub" row (REQ-UTILITY-013, proposed; the rules come from the orchestrator's check of the kit and the App Review Guidelines, `agent-artifacts/2026-09-25/app-disclosure/outputs/answer.md`); Pitstop only | 0.5d | SYS-008 | planned (owner, 2026-09-25: after SYS-008) | REQ-UTILITY-013 approved in the round's package; en, ru and uk strings; the link opens the public repository; no banned word in any language |

## Owner-only work

| ID | Item | Source |
|---|---|---|
| MNT-INT-003 | Private licence and terms review of one real maintenance source, outside this repository (MNT-INT-002 is done; needs a market decision) | [MNT-INT-001 record](investigations/mnt-int-001-maintenance-intelligence.md) |
| DEV-SIRI | Device check list: Siri in ru and uk, reply language, locked phone, prompt time against the 30-second limit | ADR 0026 |
| DEV-WIDGET, DEV-PIT-SHEET | Deferred, device-only (owner, 2026-09-24): now What to Test items 1–11 in [`../operations/releases/1.2.0.md`](../operations/releases/1.2.0.md) (KIT-D-027), checked on the TestFlight 1.2.0 build after RD-012 | REQ-WIDGET-001, 002, 004, 009, 011, 012, REQ-UTILITY-012, REQ-PIT-026; ADR 0025, 0026, 0036 |
| DEV-ICON | Home Screen app icon on a device in dark, clear and tinted styles; glass tuning by eye in Icon Composer | ADR 0029, ADR 0037 |
| DEV-FM | Device evaluation of English captures with Foundation Models; then close or keep CAP-005 open, decide the Release rollout gate and the `interpreter_version` value | ADR 0027 |

## Owner decisions pending

- RD-012 design-session items (design decisions are made there): the soft
  ground shadow the mockup draws under the lifted car (not drawn); the Pit
  saved-state header's alignment at accessibility sizes, Pit's head centred
  on the stacked avatar and title; the placeholder's `contentSecondary` tint,
  translucent in dark so the horizon shows through the wheels; the car
  editor's partial-save message and the writer's ru and uk wording for the
  new editor strings (`carEditor.failure.profileOnly`, the photo and body
  rows, the failed-load line).
- Requirements: 175 REQ IDs are `Status: proposed` (SYS-007 added REQ-WIDGET-001…010; MNT-VR-002 added
  REQ-MAINT-030…039 and REQ-ROAD-026 and reworded REQ-MAINT-023 as the owner
  approved in substance). 53 are approved: REQ-BOARD-017, REQ-BOARD-026, REQ-ICON-001,
  REQ-ROAD-007, 022, 023, the iOS 27 redesign set approved in the design
  session on 2026-09-22 (REQ-DESIGN-001…005, REQ-GRAMMAR-001…004,
  REQ-BOARD-027…031, REQ-ROAD-027…029, REQ-PIT-021…027, REQ-UTILITY-012),
  REQ-WIDGET-011, 012, REQ-MAINT-040…056 (2026-09-24) and REQ-BOARD-032…034 (RD-012). Approval is an owner
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
