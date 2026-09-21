# SYS-001 App Intent investigation

**Status:** Investigated (agent, 2026-09-21); owner decisions recorded in
[ADR 0023](../../decisions/0023-remember-intent.md) (2026-09-21)\
**Task:** SYS-001 (Phase 6, `work-plan.md`); informs SYS-002, SYS-003, SYS-006\
**Register:** [`../investigations.md`](../investigations.md) (also answers part of
INV-SYS-001, INV-CAP-003 and INV-ARCH-001)\
**Contracts:** [`../../core.md`](../../core.md) (C4),
[`../../requirements/capture-pipeline.md`](../../requirements/capture-pipeline.md)
(Siri / App Intents; REQ-CAPTURE-002, 003, 005, 009, 016),
ADR [0006](../../decisions/0006-capture-confirmation-policy.md),
[0011](../../decisions/0011-interpreted-capture-without-a-model.md),
[0015](../../decisions/0015-interpretation-deadline-and-cancellation.md)

This record follows the register format (Question, Evidence, Options,
Decision, Why, Rejected alternatives, Implementation impact, Follow-up tasks).
It changes no code and no requirement. Platform statements cite Apple
documentation read on 2026-09-21 (live `developer.apple.com` pages, iOS 27 SDK
documentation); where the documentation is silent, the record says so instead
of filling the gap from memory.

## Question

The card: "Investigate RememberInPitStopIntent constraints." Five
sub-questions:

1. How an App Intent accepts free text, runs with or without opening the app,
   which time limits apply, and how it reaches the SwiftData store (app target
   versus App Intents extension).
2. How confirmation fits: proposals that need it (maintenance completion)
   versus raw saves, and which result and prompt surfaces exist on iOS 27.
3. App Shortcuts for SYS-003: phrases, parameter limits, localization
   (en, ru, uk), and Siri voice specifics for SYS-006.
4. How system cancellation and time limits map onto `InterpretationDeadline`
   and REQ-CAPTURE-005.
5. The design for SYS-002.

## Evidence

### Repository state (2026-09-21, `main` at 628fda2)

- **Source cases exist.** `CaptureSource` already has `siri` and `shortcut`
  (`Pitstop/Domain/Capture/CapturePipelineTypes.swift`). No App Intents code,
  App Group entitlement, or extension target exists.
- **One pipeline.** `RememberPipeline.remember(_:mode:)` returns `saved`,
  `needsConfirmation`, `needsClarification`, or `nothingToSave`, and exposes
  `confirm`, `preserveRaw`, `answer`, and `cancel` (ADR 0011). Pit uses
  interpreted mode with `RuleBasedInterpreter` (`AppCoordinator`).
- **Cancellation is already safe.** The pipeline checks `Task.isCancelled`
  after interpretation and again immediately before the write, and returns
  `nothingToSave` with `capture_discarded` (ADR 0015). The interpretation
  deadline is 6 seconds.
- **Store location.** The SwiftData store is
  `URL.applicationSupportDirectory/Pitstop.store`, inside the app's own
  container (`PersistenceContainer.defaultStoreURL`). `SwiftDataCarMemoryStore`
  is a `@ModelActor`.
- **Temporary storage.** When the on-disk store cannot be opened,
  `AppEnvironment.live()` falls back to an in-memory store
  (`persistence == .temporary`).
- **Composition.** `PitstopApp` builds `AppCoordinator()`, which calls
  `AppEnvironment.live()` itself; nothing outside the coordinator can reach the
  environment today.
- **Locale.** `CaptureInput.localeIdentifier` defaults to `"ru_RU"` and Pit
  does not pass one. `RuleBasedInterpreter` understands Russian and English
  only (ADR 0011).
- **Refresh.** Surfaces reload on appear and after a Pit answer; nothing
  reloads when the app returns to the foreground (`RootView`), so a save made
  while the app is suspended would not show until the next navigation.

### Apple documentation

**Parameters and free text.**

- An intent declares input with `@Parameter`; a non-optional parameter is
  required and the system requests a value when needed; an optional one can be
  requested later with `needsValueError(_:)` ([params]).
  `IntentParameter` has string initializers with `inputOptions` and
  `requestValueDialog`, and `requestValue(_:)` ([intent-parameter],
  [string-param]).
- Free text cannot be spoken as part of an App Shortcut phrase: "it's not
  possible to gather an arbitrary string from the user in the initial
  utterance"; open-ended values are collected with a value prompt
  ([wwdc22-10170]).

**Foreground, background, and where code runs.**

- `openAppWhenRun` is deprecated since iOS 26 ("Please provide
  'supportedModes' instead") ([open-app-when-run]).
- `supportedModes: IntentModes` (iOS 26) takes `.background` and
  `.foreground(.immediate | .dynamic | .deferred)`; `systemContext.currentMode`
  and `canContinueInForeground` report the runtime choice;
  `continueInForeground(_:alwaysConfirm:)` moves to the foreground and throws
  when that is not possible ([supported-modes], [intent-modes],
  [continue-foreground]).
- Modes are a suggestion. "An app intent in your App Intents extension always
  runs in the background"; if the app is in the foreground and the intent is in
  both targets, the app runs it; when no mode is set the intent typically runs
  in the background ([runtime-behavior]).
- `allowedExecutionTargets` (iOS 27) restricts an intent to `.main`,
  `.appIntentsExtension`, or `.widgetKitExtension` ([execution-targets]).
- An App Intents extension runs intents "when your app isn't running"; shared
  code goes in a framework or package declared with `AppIntentsPackage`
  ([app-extension], [runtime-behavior]). Data shared between an app and its
  extension goes through an App Group shared container ([app-groups]);
  SwiftData exposes `ModelConfiguration.GroupContainer` for that
  ([group-container]).
- Dependencies are registered with `AppDependencyManager` and read with
  `@Dependency`; "The system can run app intents soon after your app or app
  extension launches, so register dependent objects as soon as possible"
  ([first-intent]).
- `authenticationPolicy` defaults to `.alwaysAllowed`, which runs "including
  when the device is locked"; `.requiresLocalDeviceAuthentication` is suggested
  when the intent reads data that is encrypted while locked ([auth-policy]).

**Time limits and cancellation.**

- "In iOS … the system gives tasks 30 seconds to run in the background unless
  you use the methods of this protocol" (`LongRunningIntent`, iOS 27, which
  requires regular progress reports) ([long-running]).
- `CancellableIntent` (iOS 26.4) lists the cancellation causes: no progress
  past the 30-second limit, or the person cancelling in Siri, Live Activities,
  or Shortcuts; `IntentCancellationReason` is `.timeout` or `.userCancelled`;
  the standard `withTaskCancellationHandler` works in `perform()` when the
  reason is not needed ([cancellable], [cancel-reason]).
- The documentation does not say whether time spent waiting on a confirmation
  prompt counts toward the 30 seconds. This is unverified.

**Confirmation, choices, and results.**

- `requestConfirmation()` (iOS 16) and
  `requestConfirmation(conditions:actionName:dialog:)` (iOS 18) return normally
  on confirm and throw on cancel; iOS 18 and iOS 26 variants add a SwiftUI
  snippet or an interactive `SnippetIntent` to the prompt
  ([request-confirmation], [request-confirmation-18],
  [request-confirmation-snippet]). `ConfirmationActionName` offers `.log`,
  `.add`, `.set`, and `custom(...)` ([action-name]).
- `requestChoice(between:dialog:)` (iOS 26) presents a list of
  `IntentChoiceOption` values and throws when the person picks `.cancel` or
  dismisses ([request-choice], [choice-option]).
- Results: `ProvidesDialog` with `IntentDialog(full:supporting:)`,
  `ReturnsValue`, `ShowsSnippetView`, `ShowsSnippetIntent` / `SnippetIntent`
  (interactive, iOS 26), and `OpensIntent` ([first-intent], [snippets],
  [snippet-intent], [dialog]). "When someone performs an action with Siri AI
  that invokes your app intent, the system might not display `IntentDialog` or
  `ShowsSnippetView`" ([first-intent], [snippets]).
- The older confirmation variants `requestConfirmation(result:…)` and
  `requestConfirmation(output:…)` are deprecated ([app-intent]).
- iOS 27 adds `systemContext.isVoiceOnly` ("make sure a person can understand
  responses and dialog without visuals") and `systemContext.locale` (the
  request's locale "can differ from the app's current locale")
  ([is-voice-only], [context-locale]). `IntentSystemContext` exposes only
  `currentMode`, `isVoiceOnly`, `locale`, and `preciseTimestamp`
  ([system-context]); no documented property tells a Siri voice request apart
  from a Shortcuts, Spotlight, or Action button run.

**App Shortcuts and phrases.**

- An app has at most ten App Shortcuts and at most 1,000 trigger phrases
  including parameter combinations; "All trigger phrases must contain your app
  name or an app name synonym" ([wwdc23-10102], [hig-app-shortcuts]).
- A shortcut "can include a single optional value, or parameter"; parameters
  are for "a fixed set of well-known parameter values" ([hig-app-shortcuts],
  [wwdc22-10170]).
- Phrases are localized through a String Catalog named `AppShortcuts`, which
  the build fills from the `AppShortcutsProvider`; each locale can add phrases
  ([wwdc23-10102]). App Shortcuts are available as soon as the app is
  installed ([app-shortcuts], [hig-app-shortcuts]).
- HIG: straightforward tasks that people finish "without leaving their current
  context work best"; "Include all critical information in the full dialogue
  text" for audio-only devices ([hig-app-shortcuts]).
- Siri language support for Ukrainian and recognition of the Latin name
  "PitStop" inside Russian and Ukrainian phrases are not stated in the pages
  read; they need a device check.

**Testing.**

- App Intents Testing (iOS 27) runs intents out of process through the real
  App Intents infrastructure from a UI testing bundle, looking intents up by
  name and passing primitive parameters ([intents-testing],
  [intents-testing-guide]).

## Options

### A. Where the intent runs

| Option | Store access | Foreground possible | Cost |
|---|---|---|---|
| A1 App target only (`allowedExecutionTargets: .main`) | Same process, same `ModelContainer` and `@ModelActor` store as the UI | Yes | Cold background launch runs `PitstopApp.init` |
| A2 App Intents extension | Needs the store moved to an App Group container, a second process writing the same SQLite file, and shared code in a framework | No, always background | Store migration, entitlement, framework split, cross-process refresh |
| A3 Both, via a shared framework | As A2 | App only | All of A2 plus duplicate registration |

### B. How a proposal that needs confirmation is handled

| Option | Behaviour | Works voice-only or locked |
|---|---|---|
| B1 Ask in place with `requestChoice` | Three options matching Pit: record it, save the words only, cancel | Yes (spoken choice) |
| B2 Ask in place with `requestConfirmation` | Two options: confirm or cancel | Yes, but "save the words only" is lost |
| B3 Open the app to the Pit sheet | `continueInForeground`, then show the pending capture | No: fails when a foreground transition is not allowed, and leaves the user's context |
| B4 Never confirm from Siri; save the words raw | Completion becomes a Note | Yes, but the user asked for a completion and gets a Note |

### C. Mode

| Option | Behaviour |
|---|---|
| C1 Interpreted (`RuleBasedInterpreter`, as Pit) | Same meaning as Pit for the same words (C4) |
| C2 Raw only | Every Siri capture is a Note; no confirmation path |

### D. Source value

No documented signal separates Siri voice from other intent runs, so one
intent cannot honestly emit both `siri` and `shortcut`.

## Decision

Recommended to the owner; nothing is implemented.

1. **A1, app target only.** `RememberInPitStopIntent` lives in the app target
   with `allowedExecutionTargets = [.main]` and
   `supportedModes = [.background]`. No extension, App Group, or store move.
2. **C1, interpreted mode**, with the same interpreter, observer, and deadline
   as Pit, built from the same `AppEnvironment`.
3. **B1, confirm in place with `requestChoice`.** A proposal that returns
   `needsConfirmation` is described in one spoken sentence (operation and
   mileage, as the Pit card shows) and offers "Record it", "Save the words
   only", and cancel. They call `pipeline.confirm`, `pipeline.preserveRaw`, and
   `pipeline.cancel`; a thrown cancel writes nothing (REQ-CAPTURE-005). The app
   is never opened by this intent.
4. **Clarification in SYS-002 is not asked by voice.** `needsClarification`
   offers "Save the words only" or cancel, and says which detail can be added
   in PitStop. Asking the missing field by voice is deferred to SYS-006.
   With `RuleBasedInterpreter` this is rare: completion mileage is optional in
   the validator, and every proposal it makes names its operation.
5. **Source `.siri` for every run of this intent**, documented as "an App
   Intents entry (Siri, Shortcuts, Spotlight, Action button)"; `shortcut`
   stays unused until the owner decides (question 3).
6. **Refuse temporary storage.** When `persistence == .temporary`, the intent
   fails with a visible error instead of saving to memory that disappears when
   the background process ends (REQ-CAPTURE-009).

### SYS-002 design

**Placement.**

- `Pitstop/App/Intents/RememberInPitStopIntent.swift`: the `AppIntent`
  adapter only (title, parameter, modes, targets, dialogs).
- `Pitstop/Features/SystemCapture/SystemCaptureHandler.swift`: the testable
  logic. It takes a `RememberPipeline`, the persistence state, a clock, and a
  `CaptureDecisionPrompting` protocol (choice between record, words only, and
  cancel), and returns a `SystemCaptureReply` value (saved to Notes, saved as a
  completion, a reading, a car wash; or failure). The intent maps the reply to
  an `IntentDialog` and maps prompting to `requestChoice`.
- `PitstopApp.init` builds `AppEnvironment.live()` once, passes it to
  `AppCoordinator(environment:)`, and registers the handler with
  `AppDependencyManager.shared`. One `ModelContainer` per process, shared by
  the UI and the intent.

**Input.**

```swift
@Parameter(title: "Thought", requestValueDialog: "What should PitStop remember?")
var text: String
```

The handler builds
`CaptureInput(payload: .text(text), source: .siri, capturedAt: now(),
localeIdentifier: systemContext.locale.identifier, visibleFeature: nil)`.
`.text` rather than `.transcript`: the intent receives a string and cannot
tell whether it was spoken or typed. The locale comes from the request
(iOS 27), not from the app default.

**Replies** (`ProvidesDialog`, full text speakable on audio-only devices):

| Pipeline outcome | Reply |
|---|---|
| `saved(_, preservedRaw: true)` | "Saved to Notes as you said it." (REQ-CAPTURE-008, 010) |
| `saved(_, preservedRaw: false)` | Names the destination: "Oil change recorded in History at 84,200 km." / "Mileage set to 84,200 km." |
| `needsConfirmation` | `requestChoice` as in decision 3, then one of the rows above |
| `needsClarification` | Choice of "Save the words only" or cancel (decision 4) |
| `nothingToSave` | Nothing said beyond "Nothing to remember." for blank text; silent after cancellation |
| `RememberError.notSaved` or temporary storage | Throws an error with a localized description: "PitStop couldn't save that." (REQ-CAPTURE-009) |
| `RememberError.alreadySaved` | "That's already saved." |

No raw text is repeated back in dialogs or logs (REQ-CAPTURE-025); the reply
names kinds and typed values only.

**Cancellation and time.** The intent adds no timer of its own. A system
cancellation (timeout at 30 seconds or the person cancelling) cancels the
`perform()` task; the pipeline's existing checks turn that into
`nothingToSave` before any write. `InterpretationDeadline.standard` (6 s)
fits inside 30 s with margin, so a stalled model degrades to a raw save
instead of a system timeout. `LongRunningIntent` is not needed.
`CancellableIntent` is optional: the reason could feed a `capture_discarded`
analytics property later, but the pipeline already behaves correctly without
it.

**Refresh.** `RootView` reloads the visible surface when `scenePhase` becomes
`.active`, so a save made while the app was suspended shows on return.

**Testing.**

- Unit tests on `SystemCaptureHandler` with a fake prompter and the real
  pipeline over an in-memory SwiftData store, as in `RememberEndToEndTests`:
  thought → Notes with `source == .siri`; oil change → prompt → "Record it" →
  History; "Save the words only" → Note; cancel → no change
  (REQ-CAPTURE-005); cancelled task → no change; temporary storage → error and
  no write; locale passed through; every source emits only `CaptureInput`
  (REQ-CAPTURE-002, 003).
- A static check that the intent file imports no persistence type (the adapter
  only calls the handler).
- `perform()` itself stays thin enough that the handler tests cover it; an App
  Intents Testing run needs a UI test target, which the project does not have
  (owner question 5).
- Device smoke for SYS-006, not SYS-002: Siri voice in Russian and English,
  locked phone, audio-only reply.

## Why

- **App target.** The store sits in the app's container. An extension would
  force an App Group store move (a data migration of every existing store) and
  two processes writing one SQLite file, for a benefit (running while the app
  is not running) that a background launch of the app already gives. The
  foreground stays available for later needs.
- **Interpreted.** Core C4: the same words must mean the same thing from every
  source. Raw-only Siri would make "I changed the oil at 84,200" a Note from
  Siri and a completion from Pit.
- **Confirm in place.** HIG favours tasks finished without leaving the current
  context; the main Siri use is hands-busy (in or near the car), where opening
  the app is the worst outcome and may be impossible. `requestChoice` keeps
  Pit's three outcomes, including "Save as written", which `requestConfirmation`
  cannot express. REQ-CAPTURE-016 still holds by construction: only
  `pipeline.confirm` issues a permit.
- **One source value.** Recording `siri` for a Shortcuts run and `shortcut` for
  a voice run would make the source distribution wrong in a way nobody can
  detect; one honest value is better.

## Rejected alternatives

- **App Intents extension (A2, A3).** Store migration and cross-process writes
  for no user-visible gain now. Revisit only if background launch of the app
  proves too slow (INV-CAP-003).
- **Opening the app for confirmation (B3).** Fails where Siri matters most, and
  `continueInForeground` throws when a transition is not allowed.
- **`requestConfirmation` only (B2).** Loses "Save the words only".
- **Raw only (B4, C2).** Violates C4's one meaning per input.
- **`openAppWhenRun`.** Deprecated since iOS 26.
- **Free text in the phrase** ("Remember in PitStop that …"). Not supported by
  App Shortcuts; Siri asks for the text instead.
- **An interactive `SnippetIntent` confirmation in SYS-002.** Siri AI may not
  show snippets, and a spoken choice already works on every surface; a snippet
  can be added later for Spotlight and Shortcuts.

## Implementation impact

- No domain change: `CaptureSource.siri`, the pipeline, the confirmation
  policy, and the cancellation guards already exist.
- App layer: `PitstopApp` owns the environment and registers the dependency;
  `AppCoordinator` takes the environment instead of building it.
- New files: the intent adapter, `SystemCaptureHandler`, its tests.
- `RootView`: reload on `scenePhase == .active`.
- Localization: intent title, parameter title, request dialog, choice labels,
  and replies in `Localizable.xcstrings` (en, ru, uk); phrases in a new
  `AppShortcuts.xcstrings` (SYS-003).
- ADR: SYS-002 records decisions 1–6 as an ADR (source value, in-place
  confirmation, app-target placement).
- Pit's own `CaptureInput` also omits the locale; the same fix applies there
  (not part of SYS-002 unless the owner wants it).

### SYS-003 (App Shortcut) notes

- One `AppShortcutsProvider` entry for `RememberInPitStopIntent`, with no
  parameter in the phrase; Siri then asks for the text with the request dialog.
- Every phrase contains `\(.applicationName)`. English: "Remember in
  \(.applicationName)", "Note in \(.applicationName)". Russian and Ukrainian
  phrases are written by the owner or a native speaker in `AppShortcuts`
  String Catalog; the agent does not invent them.
- Budget: one of ten shortcuts; a handful of phrases per locale against the
  1,000 limit.
- `SiriTipView` in Pit or Notes can surface the phrase (discoverability,
  INV-SYS-001).

### SYS-006 (Siri capture slice) notes

- Check on a device: Siri in Russian, English, and (if supported) Ukrainian;
  recognition of "PitStop" inside non-English phrases; app name synonyms if
  it is not recognised.
- Use `systemContext.isVoiceOnly` to keep replies short and complete when
  there is no screen.
- Measure cold background launch to reply time (INV-CAP-003) and whether the
  choice prompt counts toward the 30-second limit.
- Decide whether to ask a missing field by voice (decision 4).

## Follow-up tasks (proposals only; not created as issues)

| Proposed ID | Title | Type | Depends on | Est |
|---|---|---|---|---:|
| SYS-002 | RememberInPitStopIntent as designed above | implementation | owner answers 1–4 | 2d |
| SYS-003 | App Shortcut with localized phrases | implementation | SYS-002, owner phrases for ru and uk | 1d |
| SYS-006 | Siri device checks and voice clarification | implementation | SYS-002, physical device | 3d |
| ENG-UIT-001 | UI test target with App Intents Testing smoke | engineering | owner question 5 | 1d |
| CAP-LOC-001 | Pass the request locale into Pit's `CaptureInput` | implementation | — | 0.5d |

## Owner decisions (summary)

1. **Confirmation surface:** in-place `requestChoice` (recommended) versus
   opening the Pit sheet.
2. **Odometer readings from voice:** ADR 0006 auto-accepts a reading with no
   conflict. A misheard number from Siri would be written without a prompt.
   Keep the table (recommended: yes, a lower reading is already a conflict and
   the reading is correctable), or make `source == .siri` readings
   `confirmCompact`.
3. **Source value:** one value `siri` for every intent run (recommended), or
   rename it (for example `appIntent`) and drop `shortcut`.
4. **Locked device:** keep `.alwaysAllowed` (capture from a locked phone in a
   mount) after a device check that the store is readable while locked, or
   require authentication. Recommended: `.requiresLocalDeviceAuthentication`
   until that check is done.
5. **UI test target:** add one for App Intents Testing now, or rely on handler
   unit tests until SYS-006.
6. **Retry after failure (REQ-CAPTURE-009):** Siri cannot keep the input for a
   retry. Accept that the reply only says it was not saved (recommended; the
   raw text is not stored anywhere to keep it private), or keep a pending draft
   for Pit to offer on next launch.

## Sources

[app-intent]: https://developer.apple.com/documentation/appintents/appintent
[open-app-when-run]: https://developer.apple.com/documentation/appintents/appintent/openappwhenrun
[supported-modes]: https://developer.apple.com/documentation/appintents/appintent/supportedmodes
[intent-modes]: https://developer.apple.com/documentation/appintents/intentmodes
[continue-foreground]: https://developer.apple.com/documentation/appintents/appintent/continueinforeground(_:alwaysconfirm:)
[runtime-behavior]: https://developer.apple.com/documentation/appintents/configuring-the-runtime-behavior-of-your-app-intents
[execution-targets]: https://developer.apple.com/documentation/appintents/intentexecutiontargets
[app-extension]: https://developer.apple.com/documentation/appintents/app-extension
[app-groups]: https://developer.apple.com/documentation/xcode/configuring-app-groups
[group-container]: https://developer.apple.com/documentation/swiftdata/modelconfiguration/groupcontainer-swift.struct
[first-intent]: https://developer.apple.com/documentation/appintents/creating-your-first-app-intent
[params]: https://developer.apple.com/documentation/appintents/adding-parameters-to-an-app-intent
[intent-parameter]: https://developer.apple.com/documentation/appintents/intentparameter
[string-param]: https://developer.apple.com/documentation/appintents/intentparameter-string
[auth-policy]: https://developer.apple.com/documentation/appintents/appintent/authenticationpolicy
[long-running]: https://developer.apple.com/documentation/appintents/longrunningintent
[cancellable]: https://developer.apple.com/documentation/appintents/cancellableintent
[cancel-reason]: https://developer.apple.com/documentation/appintents/intentcancellationreason
[request-confirmation]: https://developer.apple.com/documentation/appintents/appintent/requestconfirmation()
[request-confirmation-18]: https://developer.apple.com/documentation/appintents/appintent/requestconfirmation(conditions:actionname:dialog:)
[request-confirmation-snippet]: https://developer.apple.com/documentation/appintents/appintent/requestconfirmation(conditions:actionname:dialog:showdialogasprompt:snippetintent:)-3vewj
[action-name]: https://developer.apple.com/documentation/appintents/confirmationactionname
[request-choice]: https://developer.apple.com/documentation/appintents/appintent/requestchoice(between:dialog:)
[choice-option]: https://developer.apple.com/documentation/appintents/intentchoiceoption
[snippets]: https://developer.apple.com/documentation/appintents/displaying-static-and-interactive-snippets
[snippet-intent]: https://developer.apple.com/documentation/appintents/snippetintent
[dialog]: https://developer.apple.com/documentation/appintents/intentdialog
[system-context]: https://developer.apple.com/documentation/appintents/intentsystemcontext
[is-voice-only]: https://developer.apple.com/documentation/appintents/intentsystemcontext/isvoiceonly
[context-locale]: https://developer.apple.com/documentation/appintents/intentsystemcontext/locale
[app-shortcuts]: https://developer.apple.com/documentation/appintents/app-shortcuts
[hig-app-shortcuts]: https://developer.apple.com/design/human-interface-guidelines/app-shortcuts
[wwdc22-10170]: https://developer.apple.com/videos/play/wwdc2022/10170/
[wwdc23-10102]: https://developer.apple.com/videos/play/wwdc2023/10102/
[intents-testing]: https://developer.apple.com/documentation/appintentstesting
[intents-testing-guide]: https://developer.apple.com/documentation/appintentstesting/testing-your-app-intents-code

All pages above were read on 2026-09-21. Version facts (iOS 26 for
`supportedModes`, `requestChoice`, `SnippetIntent`; iOS 26.4 for
`CancellableIntent`; iOS 27 for `allowedExecutionTargets`, `LongRunningIntent`,
`isVoiceOnly`, `locale`, App Intents Testing) come from each page's
availability metadata. The two WWDC sessions are Apple videos; their
statements were read from the published transcripts.
