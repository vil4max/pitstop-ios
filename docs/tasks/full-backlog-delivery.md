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
| CAP-003 | `CAP-003/pit-eyes` | committed | `just verify` passed; simulator: 40 sampled frames of the Pit control, 39 identical and 1 transient (rare idle motion, as designed); independent review: 2 high + 4 medium + 3 low, then 3 medium + 2 low, then 1 low, all repaired; ADR 0012 |
| CAP-004 | `CAP-004/pit-capture` | committed | `just verify` passed; simulator (tap-free `-pitstop-pit`): a completion stops at confirmation showing the operation and mileage, a thought is saved as written with a link to Notes; independent review: 2 high + 3 medium, then 1 medium + 1 low, then no findings |
| CAP-006 | `main` (8c498e9) | committed | `just verify` passed; `RawFallbackTests` covers hung, timely and throwing interpreters and both cancellation paths; with the write guard disabled both REQ-CAPTURE-005 tests failed; independent review: 5 low findings, all fixed; no simulator smoke (no hang or cancellation is reachable from the UI yet) |
| CAP-007 | `main` | committed | `just verify` passed; `RememberEndToEndTests` drives the real Pit view model, pipeline, rule-based interpreter, SwiftData store and Car Board view model: thought → Notes tile, oil change → confirmation → timeline, wash → History, mileage → header, cancel → no change, intention → note only, relaunch keeps both; simulator (`simctl launch` with `-pitstop-pit` and a Russian oil-change phrase at 84 200 km): confirmation shown with operation, date and 84 200 km; confirming on the simulator not done (the simulator tap client failed to initialise); independent review: the Car Board header ignored completion mileage while Service counted it; the owner chose the newest observation (REQ-BOARD-026, approved 2026-09-21), implemented in a follow-up commit |
| DISC-001 | `main` | committed | `just verify` passed; registry rejects questions without value or deferral path; question state persists through SwiftData schema V2 (lightweight migration from V1, V1 frozen by a schema-pinning test, V1 store migration tested); attention policy fed from persisted state; independent review: no high, 1 medium (V1 not frozen) and 3 low, all fixed |
| DISC-002 | `main` | committed | `just verify` passed; ADR 0017: current-mileage question on Service, asked only while a distance rule is blocked by stale or unknown mileage; answer writes `recordOdometerReading`; `MileageQuestionEndToEndTests` shows Service and Road going from blocked to 2,000 km remaining on real SwiftData stores; simulator (`-pitstop-demo-data -pitstop-demo-stale-mileage -pitstop-open service -pitstop-show-question`): the question card opened over Service; answering on the simulator not done; independent review: 1 high (Reduce Motion blocked every question), 1 medium (question replaced the composer), 3 low, all repaired; repairs not re-reviewed |
| DISC-003 | `main` | committed | `just verify` passed (`verify OK (DoD)`); ADR 0018: every question declares its return after an answer, a deferral, and a dismissal, enforced by the policy from persisted `resolvedAt` and by the command itself (`asked` before the return throws `notReturned`, nothing saved); an answer holds for its interval and then only while relevance says it unlocks nothing (mileage question: 90 days, the reading's current window), a deferral returns after 14 days, a dismissal never; an unreadable stored resolution reads as `closed` and never returns; no schema change; `PitQuestionReturnTests` (policy, fixed dates: deferral return, 7-day global dismissal, `never`, answer hold, 12-hour block, reopen and rejected early asks), `MileageQuestionReturnTests` (view model, fake stores), `SwiftDataPitQuestionStoreTests` (rejected ask saves nothing, unreadable row stays closed), `MileageQuestionEndToEndTests` (SwiftData store reopened from a file: deferral back at 14 d, answer back once stale, 12-hour block, dismissal final a year later; the 7-day cross-question silence is covered with fixtures only); independent review: no high, 1 medium (ask could reopen a question before its return) and 3 low, all repaired; repairs re-reviewed with no findings; owner decision open: REQ-PIT-008 says an answered question "is not asked again", ADR 0018 proposes "while that answer still holds" (requirement text unchanged; return tests are tagged ADR-0018); no simulator smoke (returns need days of clock time) |
| — | TestFlight | uploaded | 1.0 (202609211) built from e11d469, signed with team BTHRDS7254, uploaded 2026-09-21 to the App Store Connect record "PitStop: Car Journal" (`dev.vil4max.pitstop`); `just release --check` passed first. Symbols were not uploaded: Release uses `DEBUG_INFORMATION_FORMAT = dwarf`, so the archive has no dSYM |
| DISC-004 | `main` | committed | `just verify` passed (`verify OK (DoD)`) after the review repairs; ADR 0019: surfaces report activity to Pit as a union of per-source reports (`PitActivitySources`, `PitActivityReporter` in the environment): scroll views on Car Board and every feature screen report `scrolling`, focused editor fields `editing`, every editor sheet and the Service undo confirmation `modalTask`, withdrawn on disappear; the Pit capture sheet is unchanged; motion audit: every state required by accepted behaviour was already triggered, no state added (hidden and closed eyes stay unused); `PitActivityReportingTests` (aggregation, idle loop stops and resumes from a running loop, question not asked while an editor is open or a field is focused, a scroll at the ask moment defers the question until the interface settles again via `PitAskTrigger`); simulator (tap-free `-pitstop-demo-data -pitstop-demo-stale-mileage -pitstop-open service -pitstop-show-question`): the question still opened over Service, so no activity is stuck after appear; scrolling and editors not exercised on the simulator; `recentlyDismissed` still not reported (ADR 0019 open question); independent review: no high, 1 medium (a scroll at the 2-second ask lost the question for the visit) and 2 low (idle-loop tests never started the loop; this row claimed committed), all repaired; repairs re-reviewed with no findings |
| DOM-004 | `main` | committed | ADR 0020 maps all 15 open points of ADR 0001: 9 already decided with code and test evidence (independent cycles, anchor wording, reset from actual completion, deterministic non-authoritative grouping, grouping windows, policy separation, status authority, unknown baseline, plan vs visit), 5 decided as agent decisions (no fixed-grid policy type in the first slice; equal grouping eligibility; no title adapter and frozen stored IDs; seeded visits gone with nothing to migrate; code-owned catalog), 4 owner questions with recommended answers (A promote ADR 0001 to Accepted; B verified recommendation and procedure data source; C Service Plan vs multi-operation visit order; D legacy data import); one proposed requirement change (maintenance-engine success criterion on seeded Arteon data), requirement text unchanged; ADR 0001 gets a closure section and its one non-English word replaced; tests added, no production code changed: `lateCompletionRebaselines`, `operationIDsAreStable`, `uncataloguedOperationKeepsIdentity` (ADR-0020); `just verify` passed (`verify OK (DoD)`, 334 tests, 0 failed); independent review: no high or medium, 3 low (overstated initializer guarantee, wrong string key, unsourced work-plan claim) and 1 nit (row count), all repaired; repairs not re-reviewed |
| MNT-INT-001 | `main` | committed | Investigation record `docs/planning/investigations/mnt-int-001-maintenance-intelligence.md` (register format; linked from `investigations.md`, INV-VEH-002 and INV-MNT-001): manufacturer data no-go for app-supplied schedules (OEM document terms forbid redistribution, EU RMI access is fee-based and repair-only, commercial APIs are US-focused with terms behind sign-up, vPIC has no schedules), owner cadence stays the only policy source, a provenance and applicability shape is proposed for a fixture-only test on a fictional car (MNT-INT-002); presets no-go for numeric bundles, conditional go for an operation-set starter with owner intervals, which needs a missing stop-tracking command (MNT-POL-001); Road go for owner-stated dated events (insurance expiry first; the projector already places them, storage, commands and entry are missing), no-go for derived inspection dates and mileage-rate estimates; 16 external sources cited, no schedule copied; owner decisions listed in the record; docs only: `git diff --check` and a Cyrillic scan run, no app build |
| ENG-002 | `main` (working tree) | committed | ADR 0021: provider-neutral boundary in the app target (`AnalyticsClient`, `AnalyticsTracking<Event>`, closed `AnalyticsValue` built only from `Bool` or `CaseIterable` string enums), consent gate with the default off (`notAsked` sends nothing; owner question), production composition is a gated no-op, DEBUG `-pitstop-analytics-log` writes events to OSLog only; no SDK, network or dependency added. Wired from the taxonomy: `input_interpretation_completed`, `draft_saved`, `draft_cancelled`, `note_created` (via `CaptureAnalyticsObserver` fanned out next to `CaptureStageLogger`), `note_context_opened`, `note_archived` (Notes), `odometer_updated` (capture, car editor, mileage question); proposed `REVIEW` events for Pit questions and tile opens added to `analytics.md`, not collected. Tests `PitstopTests/Analytics/` (27 test functions, ADR-0002/ADR-0021): reflection over every event case, declared-values check, taxonomy names, consent off records nothing, stage mapping, end-to-end Pit capture and Notes editor; a mutation that opened the consent gate failed 3 of them. `just verify` passed (`verify OK (DoD)`, 356 tests, 0 failed, lint 0 serious); independent review: no high or medium, 4 low (evicted captures re-created outside the bound; `draft_saved` counted auto-accepted proposals that were never shown; archive context filter reported as opened; missing tests for contextual notes, the mileage answer and a directly confirmed reading), all repaired, repairs not re-reviewed; no simulator smoke (no visible behaviour) |
| ANL-001 | `main` (working tree) | committed | ADR 0022 (owner chose HTTP without the SDK, 2026-09-21): `PostHogAnalyticsClient` behind `AnalyticsClient` over an injected `AnalyticsHTTPTransport` (ephemeral `URLSession`, neutral `User-Agent` and `Accept-Language`), `POST /batch/`, in-memory queue (batch 20, 30 s interval, flush on background, bound 200 dropping the oldest), 3 attempts with 2 s/4 s backoff, a 60 s pause of size-triggered flushes after giving up, no disk persistence; every event carries `$process_person_profile: false` and `$geoip_disable: true`, only closed ENG-002 values and a consent-scoped random UUID; Settings toggle "Share anonymous usage data" (en/ru/uk), off by default, consent and ID in `UserDefaults` behind `AnalyticsPreferenceStorage`, withdrawal deletes the ID and the queue; key and host from `Config/Analytics.xcconfig` (empty) plus an ignored `Analytics.local.xcconfig`, merged into Info.plist; empty values compose the gated no-op; `PrivacyInfo.xcprivacy` declares `UserDefaults` (`CA92.1`). Tests `PostHogAnalyticsClientTests` (ADR-0021/ADR-0022): payload per catalog event, forbidden keys, consent off, withdrawal, stale identity, batching, interval, bounded queue, retry/backoff with a recording sleeper, refused batches, the pause after giving up, transport failure isolation, configuration parsing and composition; mutations removing `$geoip_disable` or the queue discard on withdrawal failed the suite (the discard mutation only after the withdrawal test was tightened). Built with a fictional local key: the bundle Info.plist carried it; without the local file both values were empty. `just verify` passed (`verify OK (DoD)`, 380 test cases, 0 failed, lint 0 serious); independent review: no high or medium, 4 low (ADR overstated in-flight withdrawal, default headers leaked app/OS/locale, background flush ran on the main actor, retry storm while offline), all repaired, repairs not re-reviewed; no simulator smoke; no PostHog project exists, so no event was delivered |
| SYS-001 | `main` (working tree) | committed | Investigation record `docs/planning/investigations/sys-001-app-intents.md` (register format; linked from `investigations.md`, INV-SYS-001 and INV-CAP-003), from live Apple documentation read 2026-09-21 (URLs in the record): `openAppWhenRun` deprecated since iOS 26 in favour of `supportedModes`; background intents get 30 seconds unless `LongRunningIntent` (iOS 27); `allowedExecutionTargets` (iOS 27) restricts the process; `requestChoice` (iOS 26) and `requestConfirmation` throw on cancel; App Shortcut phrases need the app name and cannot carry free text (Siri asks for it); `systemContext.locale` and `isVoiceOnly` (iOS 27); no documented signal separates Siri voice from other intent runs. SYS-002 design: intent in the app target only, background mode, interpreted pipeline shared with Pit, in-place three-way `requestChoice` for proposals needing confirmation, refuse temporary storage, source `.siri`, request locale into `CaptureInput`, handler unit-tested with a fake prompter; six owner questions in the record; docs only: `git diff --check` and a Cyrillic scan run, no app build |
| SYS-002 | `main` (working tree) | committed | ADR 0023 (owner decisions 2026-09-21): `RememberInPitStopIntent` in the app target (`allowedExecutionTargets = .main`, `supportedModes = .background`, `authenticationPolicy = .requiresLocalDeviceAuthentication`; APIs checked against the iOS 27 SDK interface and Apple docs), thin `perform()` over `RememberIntentHandler` (pipeline, persistence and clock injected; `RememberPrompting` per call), registered with `AppDependencyManager` from `PitstopApp.init`, which now builds `AppEnvironment.live()` once for the coordinator and the handler; `AppCoordinator.interpretedPipeline(_:)` shared by Pit and the intent (same interpreter, logger, analytics observer); `CaptureInput` source `.siri`, payload `.text`, request locale; confirmation asked in place with `requestChoice` (Record it / Save the words only / Cancel), clarification offers words only or Cancel, dismissal rethrown with no write; temporary storage refused before interpretation; failures thrown as `AppIntentError` "Not saved" with no retry draft (owner-accepted REQ-CAPTURE-009 exception); 25 spoken strings in en/ru/uk naming destinations and typed values, never the words; `RootView` re-checks the pending Pit question and refreshes Car Board and the visible surface when the scene returns from the background (not on launch or Control Center); `perform()` ends with a detached analytics flush; the returned choice option is mapped by position, an unmatched one is logged and treated as cancel. Tests `RememberIntentHandlerTests` (15, incl. the flush) and `RememberSpeechTests` (4 functions, parameterized) (REQ-CAPTURE-00x, ADR-0023) over the real pipeline and an in-memory SwiftData store with a fake prompter; `MileageQuestionEndToEndTests.siriMileageSilencesQuestion`. Built intent metadata shows explicit local-device authentication, background mode and the main target. `just verify` passed (`verify OK (DoD)`, 398 tests, 0 failed, lint 0 serious); independent review: no high or medium, 4 low (question not re-checked on return, background runs never flushed analytics, refresh on every activation, choice mapped by equality fall-through), all repaired, repairs not re-reviewed; no simulator or device smoke (no UI test target; Siri voice, locked phone, Ukrainian Siri and the 30-second limit are SYS-006 device checks) |
| SYS-003 | `main` (working tree) | committed | ADR 0024 (agent decision under owner delegation, owner review pending): `PitStopShortcuts` declares two App Shortcuts, Remember (`RememberInPitStopIntent`, Siri asks for the words) then Open Pit (new `OpenPitIntent`: `supportedModes = .foreground(.immediate)`, `.main`, `.requiresLocalDeviceAuthentication`; APIs checked against the iOS 27 SDK interface and Apple docs); `OpenPitIntent` records a request on an injected `@MainActor @Observable CaptureSurfaceRequests` (created in `PitstopApp.init`, passed through `AppCoordinator` to `RootView`, registered with `AppDependencyManager`), which `RootView` takes with `onChange(initial: true)` and opens the Pit sheet over the current surface (REQ-PIT-013, REQ-CAPTURE-023); while a feature editor or prompt reports `.modalTask` (`PitPresenceModel.isFeatureTaskPresented`, root utility sheet excluded) the request stays pending and opens Pit when it closes, instead of being consumed by a sheet SwiftUI cannot present (review finding); phrases with `${applicationName}` in `AppShortcuts.xcstrings` (en, ru, uk string sets; the ADR describes the wording in English); titles and the Open Pit description in `Localizable.xcstrings`. Tests `AppShortcutsTests` (extracted App Intents metadata and compiled phrase tables: two shortcuts in order, every phrase and variant names the app, no duplicates, every locale covers every phrase, Open Pit modes) `CaptureSurfaceRequestsTests` (incl. deferral) and `FeatureTaskPresentationTests` (ADR-0024). Simulator smoke on `claude-Pitstop-1b8d76c5`: Shortcuts app lists PitStop's Remember and Open Pit; Open Pit opens the Pit sheet with the app warm and terminated; with a draft in the note editor it defers, keeps the draft, and opens Pit after Cancel. `just verify` passed (`verify OK (DoD)`, 411 tests, 0 failed, lint 0 serious) after the review repairs; independent review: 2 medium, 2 low, all repaired, repairs re-reviewed: one low (list failure alerts on Notes and Service did not block the deferred request) fixed; Siri voice recognition of ru and uk phrases is a SYS-006 device check |
| SYS-004 | `main` (working tree) | committed | Investigation record `docs/planning/investigations/sys-004-widgets.md` (register format; linked from `investigations.md`, INV-SYS-002, INV-SYS-003, INV-CAP-003 and INV-CAP-004), from live Apple documentation read 2026-09-21 (URLs in the record) and the iOS 27.0 SDK interfaces: controls (iOS 18) open the app only through an `OpenIntent` action compiled into both the app and the widget extension, other control intents run in the extension in the background; widget buttons should do more than open the app, so open-only widgets use `widgetURL`/`Link` (`onOpenURL`); widgets do not resolve intent parameters and have no text input; `openAppWhenRun` is deprecated and an error in an extension; `allowedExecutionTargets` (iOS 27) keeps `perform()` in the app; data needs an App Group and a store move. Local evidence: OneCart ships a WidgetKit extension from a JSON `project.xcproj` on the same Runtime (embed copy phase, `<host>.` bundle ID, equal `MARKETING_VERSION`). SYS-005 recommendation: data-free, no App Group; an Open Pit control plus a static small/circular widget via `widgetURL`, `OpenPitIntent` adopting `OpenIntent` with a one-case target, a `Shared/` folder in both targets, target created with Xcode 27.2 tooling; acceptance, tests and five owner questions (bundle ID, surfaces, URL scheme, intent change, data later) in the record; docs only: `git diff --check` and a Cyrillic scan run, no app build |

## Open for owner

- Proposed contract additions awaiting approval: the `capture_discarded`
  pipeline stage (ADR 0006).
- Release builds produce no dSYM (`DEBUG_INFORMATION_FORMAT = dwarf`), so
  TestFlight crash reports will not be symbolicated. Switching Release to
  `dwarf-with-dsym` is a one-line project change; not done yet.
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
- DOM-004 owner questions A–D and one proposed requirement change are listed
  in ADR 0020 ("Owner questions", "Proposed requirement change").
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
