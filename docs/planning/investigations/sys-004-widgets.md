# SYS-004 Widget investigation

**Status:** Investigated (agent, 2026-09-21); owner decisions pending\
**Task:** SYS-004 (Phase 6, `work-plan.md`); specifies SYS-005 "Widget capture slice"\
**Register:** [`../investigations.md`](../investigations.md) (also answers
INV-SYS-002, INV-SYS-003 and the widget part of INV-CAP-003 and INV-CAP-004)\
**Contracts:** [`../../core.md`](../../core.md) (C4),
[`../../requirements/capture-pipeline.md`](../../requirements/capture-pipeline.md)
(Widget; REQ-CAPTURE-002, REQ-CAPTURE-023),
[`../../requirements/car-board-screen.md`](../../requirements/car-board-screen.md),
ADR [0005](../../decisions/0005-toolchain-and-project-format.md),
[0007](../../decisions/0007-persistence.md),
[0023](../../decisions/0023-remember-intent.md),
[0024](../../decisions/0024-app-shortcuts.md)

This record follows the register format (Question, Evidence, Options,
Decision, Why, Rejected alternatives, Implementation impact, Follow-up tasks).
It changes no code and no requirement. Platform statements cite Apple
documentation read on 2026-09-21 from the live `developer.apple.com` pages
(their JSON form, which carries the availability metadata) and, where named,
the iOS 27.0 simulator SDK interfaces. Where the documentation is silent, the
record says so and turns the gap into a SYS-005 check instead of filling it
from memory.

## Question

The card: "Fast-capture widget platform constraints." Five sub-questions:

1. Which system surfaces fit "tap → capture surface" on iOS 27: Home Screen
   and Lock Screen widgets (static tap, `Link`, interactive `Button`),
   controls (Control Center, Lock Screen, Action button), and the Action
   button; which of them can open the app on a specific surface and which run
   an intent in the background.
2. Whether a widget or control can reuse `OpenPitIntent` from the app target,
   or needs the intent compiled into the widget extension, and what that means
   for the single app target and its file-system-synchronized folder.
3. Whether the widget needs data (App Group, shared SwiftData store, reloads),
   or SYS-005 can ship a data-free entry first; the cost of moving the store.
4. Project and tooling constraints: adding a Widget Extension target to the
   JSON project, bundle ID, signing, entitlements, Xcode Cloud, and the
   Runtime's single-target assumptions.
5. The smallest valuable SYS-005 slice, its acceptance, tests, and owner
   questions.

## Evidence

### Repository state (2026-09-21, `main` at 289b0fa)

- **Routing exists.** `OpenPitIntent` (`Pitstop/App/Intents/OpenPitIntent.swift`)
  is a plain `AppIntent` with `supportedModes = .foreground(.immediate)`,
  `allowedExecutionTargets = .main`, and
  `authenticationPolicy = .requiresLocalDeviceAuthentication`. Its `perform()`
  calls `CaptureSurfaceRequests.request()` through `@Dependency`. `RootView`
  takes the request and opens the Pit sheet over the current surface, deferring
  while a feature editor is presented (ADR 0024). Nothing routes through Car
  Board, which is REQ-CAPTURE-023's condition.
- **`CaptureSurfaceRequests`** (`Pitstop/App/CaptureSurfaceRequests.swift`)
  imports only `Observation`; it has no app dependencies.
- **No URL handling.** No `onOpenURL`, `onContinueUserActivity`, or
  `CFBundleURLTypes` exists (`Config/Info.plist` holds only the PostHog keys).
- **One app target, no entitlements.** `project.xcproj` has two targets,
  `Pitstop` (application, `dev.vil4max.pitstop`, `MARKETING_VERSION` 1.1.0)
  and `PitstopTests`. `CODE_SIGN_ENTITLEMENTS` is not set;
  `Pitstop.entitlements.example` is a template excluded from the target
  (ADR 0005). Membership comes from two `"kind": "folder"` entries
  (`Pitstop/` → `Pitstop`, `PitstopTests/` → `PitstopTests`).
- **Store location.** `PersistenceContainer.defaultStoreURL` is
  `URL.applicationSupportDirectory/Pitstop.store`, passed explicitly as
  `ModelConfiguration(schema:url:)`; there is no App Group (ADR 0007).
  TestFlight build 1.0 was uploaded on 2026-09-21, so testers can hold data
  in that location.
- **Pit capture is text.** No `Speech` or `AVAudio` code exists in the app, so
  the "listening" step of the capture contract's widget flow has nothing to
  start yet; microphone activation stays open under INV-CAP-004.
- **Runtime.** `Tooling/runtime.yml` names one scheme (`Pitstop`) and the
  project; the shared scheme builds implicit dependencies. `run-sim.sh`
  prefers `${SCHEME}.app` among built products. `bundle_id_for_scheme`
  (`Tooling/scripts/lib.sh`) picks the `application` product's bundle ID.
  `tf-check` and `tf-promote` require every `MARKETING_VERSION` in the project
  to be equal (`project_versions.py` reads all targets).
  `ci_scripts/ci_post_clone.sh` rewrites every `CURRENT_PROJECT_VERSION` key
  in `project.xcproj`, so an extension target that carries the key gets the
  same Xcode Cloud build number.
- **A sibling app already does this.** OneCart (same owner, same Runtime,
  `~/Developer/Personal/apps/OneCart`) has a WidgetKit extension in a JSON
  `project.xcproj`: target `OneCartWidgets`, `"product-type": "app-extension"`,
  bundle ID `<host>.OneCartWidgets`, same `MARKETING_VERSION` as the app,
  `SKIP_INSTALL = YES`, an `Info.plist` with `NSExtensionPointIdentifier`
  `com.apple.widgetkit-extension`, and on the app target a
  `{"kind": "copy", "name": "Embed App Extensions", "bundle-base-path": "plugins-directory"}`
  build phase plus `"dependencies": ["OneCartWidgets"]`. Its JSON conversion
  commit (c8a64a0) is contained in its `tf-1.5.0-2` and `v1.5.0` tags. By the
  Runtime's rules a `v` tag marks a commit whose own TestFlight round was
  submitted, which is indirect evidence that Xcode Cloud archives a JSON
  project with an embedded widget extension. The Xcode Cloud logs themselves
  were not read.
- **Installed tools.** `Xcode.app` 27.0 (selected) and `Xcode-beta.app` 27.2.
  The Xcode MCP `XcodeNewTarget` tool accepts a template identifier and
  `embedInAppNamed`, and documents that the Widget Extension template appends
  "Extension" to the target name and that an embedded target's bundle ID is
  prefixed by the host's. It was not run (docs-only task).

### Apple documentation

**Which surfaces open the app, and how.**

- A widget's plain tap opens the app; `widgetURL(_:)` chooses the screen, and
  `Link` adds further targets on `systemSmall`, `accessoryRectangular`, and
  larger families. The app receives the URL in `onOpenURL(perform:)`. Without
  a URL the system passes an `NSUserActivity` whose `userInfo` names the
  widget kind and family ([linking], [user-info-key], [widget-url]). A view
  hierarchy may carry only one `widgetURL`; more is undefined behavior
  ([widget-url]).
- Interactive widgets use `Button` or `Toggle` with an App Intent on
  `systemSmall` through `systemExtraLarge` and on `accessoryCircular` and
  `accessoryRectangular` on iPhone ([interactivity]). Apple states: "An
  interaction with a button or toggle should do more than open the app," and
  directs open-only interactions to `Link` and `widgetURL(_:)`
  ([interactivity]). On a locked device buttons and toggles are inactive until
  the person authenticates ([interactivity]).
- By default a widget button's intent runs in the widget extension's process;
  it runs in the app's process when `openAppWhenRun` is true or the intent
  conforms to `AudioPlaybackIntent`, `ForegroundContinuableIntent`,
  `LiveActivityIntent`, or `PushToTalkTransmissionIntent` ([interactivity]).
  Widgets do not resolve intent parameters; values must be assigned
  ([interactivity]). The system reloads the timeline after `perform()`
  returns ([interactivity]).
- `openAppWhenRun` is deprecated since iOS 26 ("Please provide
  'supportedModes' instead"), and setting it to true "generates an error if
  the app intent runs in an app extension" ([open-app-when-run]).
  `supportedModes` (iOS 26) is "only a suggestion": for WidgetKit controls in a
  widget extension "the system runs the control's app intent from the
  extension in the background," while `OpenIntent` (and a few other system
  intent protocols) "automatically configure the `supportedModes` property to
  run the app intent in the foreground" ([runtime-behavior], [supported-modes]).
- Controls (`ControlWidget`, iOS 18) live in the widget extension and appear in
  Control Center, on the Lock Screen, and on the Action button
  ([control-widget], [controls]). A control button can "take someone to a
  specific area of your app" ([controls]). To open the app, the action must be
  an `OpenIntent`, and "the system requires the Target Membership of the app
  intent to be set to both the app and the widget extension to open the app"
  ([controls]). The iOS 27 SDK has a dedicated
  `ControlWidgetButton.init(action:label:)` overload constrained to
  `Action: OpenIntent` (WidgetKit `.swiftinterface`); Apple describes control
  buttons as stateless, for fire-and-forget actions such as launching an app
  ([control-button]). With an `OpenIntent`
  action the Action button's default hint reads "Hold to Open" the app
  ([control-refinements]).
- `OpenIntent` (iOS 16, not deprecated) requires a `target` parameter whose
  type conforms to `AppValue` (an `AppEntity` or `AppEnum`); the system brings
  the app to the foreground to run it ([open-intent]; AppIntents
  `.swiftinterface`: `associatedtype Value : AppValue`, `var target`).
- Controls take `authenticationPolicy` from their intent, and
  `privacySensitive()` redacts their state while locked ([control-refinements]).
  The HIG asks to require authentication for security-relevant actions and to
  hide sensitive information when locked ([hig-controls]).
- The Action button runs an App Shortcut or a control; the HIG notes that the
  system already offers opening an app, and prefers actions that do not leave
  the current context ([hig-action-button], [hig-controls]). PitStop's two App
  Shortcuts (ADR 0024) are therefore already assignable to the Action button;
  an "Open Pit" control adds the same entry with the control's hint.
- HIG, widgets: "Replicating an app icon offers little additional value";
  widgets should offer "useful actions and deep links to key areas," and a tap
  should open the app "at the right location" ([hig-widgets]).

**Where intent code must live.**

- For interactive widgets: "add your custom app intent to your widget
  extension target and your app target" ([interactivity]).
- For controls that open the app: membership in both the app and the widget
  extension ([controls]).
- Code that can run in the foreground must live in the app bundle or in a
  shared framework the app includes; the compiler writes App Intents metadata
  into each bundle that compiles the code. A shared framework needs an
  `AppIntentsPackage` type in the framework and in each including bundle
  ([runtime-behavior], [app-intents-package]). A Swift package must be a
  binary framework to carry intents ([runtime-behavior]).
- `allowedExecutionTargets` (iOS 27) restricts which bundle performs an intent
  compiled into several: `.main`, `.appIntentsExtension`,
  `.widgetKitExtension` ([execution-targets], [allowed-execution-targets]).

**Data sharing.**

- A widget extension runs in its own process and renders archived views from
  timeline entries ([interactivity], [widget-extension]). Timeline reloads are
  budgeted (typically 40 to 70 a day for a frequently viewed widget); reloads
  while the app is in the foreground or after a widget's own intent do not
  count ([up-to-date]).
- Sharing data between an app and its extension uses an App Group container
  (`containerURL(forSecurityApplicationGroupIdentifier:)`, a `group.` ID
  registered in the developer account) ([app-groups]). SwiftData's
  `ModelConfiguration.GroupContainer.automatic` "tells SwiftData to use the
  app's primary group container as the root location" ([group-container],
  [group-container-automatic]). PitStop passes an explicit URL; the
  documentation does not say which wins when both apply, so any App Group
  change needs a test that the store stays where it is until migrated.
- Widgets marked `privacySensitive` are redacted on the Lock Screen and in
  Always On when the person chooses so; a data-protection entitlement can hide
  the whole widget until unlock ([widget-extension]).
- A widget appears in the gallery only after the app has been launched once
  after install ([widget-extension]).

**Project format.** Xcode 27.2 writes the JSON `.xcproj` format, which "is
compatible with Xcode 27 and later" and is meant to be easier for agents to
edit ([project-format], [xcode-27-2]). Apple publishes no schema for extension
targets in that format; the OneCart file above is the working local example.
Adding a target through the Widget Extension template is documented for the
Xcode UI (File > New > Target > Widget Extension, "Include Control")
([widget-extension], [controls]).

## Options

### A. Surface

| Surface | Opens a specific surface | Runs in background | Data needed | Fit for "tap → capture surface" |
|---|---|---|---|---|
| Control button (Control Center, Lock Screen, Action button) with `OpenIntent` | Yes, the documented path | No: `OpenIntent` runs in the app, foreground | No | **Best** |
| Home Screen small widget, whole-widget tap with `widgetURL` | Yes, via URL | No | No (static entry) | Good, but must not read as a copy of the app icon |
| Lock Screen `accessoryCircular` widget with `widgetURL` | Yes, via URL | No | No | Good; overlaps the Lock Screen control |
| Widget `Button(intent:)` that only opens the app | Possible via app-process rules | — | No | Against Apple's guidance ("should do more than open the app") |
| Widget or control that captures in the background | — | Yes | Store access (App Group) and text input, which widgets lack and widget intents cannot ask for | No: widgets do not resolve parameters; Siri's Remember already covers hands-free capture |
| Action button | Via App Shortcut (shipped) or the control | Remember runs in the background (ADR 0023) | No | Already covered; the control adds one more assignable entry |

### B. How the control reaches `OpenPitIntent`

1. **`OpenPitIntent` adopts `OpenIntent`** with a one-case `AppEnum` target
   (for example `CaptureSurface.pit`, default value set), compiled into both
   targets. One intent for Shortcuts, Siri, and the control; no duplicate
   action in the Shortcuts app. Risk: the App Shortcut and its tests must
   keep working with a target parameter.
2. **A second intent** (`OpenPitFromControlIntent: OpenIntent`,
   `isDiscoverable = false`) shared with the extension, sharing the request
   code. Safe fallback if option 1 breaks the App Shortcut.
3. **Plain `AppIntent` with `supportedModes = .foreground(.immediate)` in the
   control.** Undocumented for controls; the runtime article says control
   intents run in the extension in the background. Rejected.

### C. How the code reaches the extension

1. **Shared source folder** (for example `Shared/`) whose folder entry lists
   both targets in `target-membership`, holding `OpenPitIntent.swift`,
   `CaptureSurfaceRequests.swift`, and the target enum. Uses the existing
   file-system-synchronized model; nothing else from `Pitstop/` enters the
   extension.
2. **Per-file membership exceptions** that add single files under `Pitstop/`
   to the extension. The JSON format's exception entries seen so far only
   exclude files (`"exclusions"`); adding to a second target is unverified.
3. **Shared framework with `AppIntentsPackage`.** Documented, but adds a
   third target, embedding, and package plumbing for three small files.

### D. Home Screen widget routing

1. **`widgetURL` with a custom scheme** (for example `pitstop://pit`),
   registered in `CFBundleURLTypes`, handled by `onOpenURL` →
   `CaptureSurfaceRequests.request()`. Documented end to end. Any app or web
   page can open the URL; it only opens the Pit sheet, which needs an unlocked
   phone anyway.
2. **No URL; `NSUserActivity` with the widget kind** in
   `onContinueUserActivity`. No public scheme, but the activity type to
   register for is not stated on the pages read; needs a spike.

### E. Data

1. **Data-free first** (static entry, no App Group).
2. **Data now**: App Group, store moved into the group container, a
   read-only store opened from the extension, `WidgetCenter` reloads after
   writes, Lock Screen redaction.

## Decision

Agent recommendation for SYS-005, pending the owner questions below:

1. **Ship a data-free slice.** No App Group, no store access, no timeline
   data, no entitlements on either target.
2. **Primary surface: an "Open Pit" control** (`ControlWidgetButton` in a
   `StaticControlConfiguration`) usable from Control Center, the Lock Screen,
   and the Action button, whose action is `OpenPitIntent` adopting `OpenIntent`
   (option B1; B2 is the fallback if B1 breaks the App Shortcut).
3. **Secondary surface: one static Home Screen widget** (`systemSmall`, and
   `accessoryCircular` for the Lock Screen) that is itself a "Remember" button
   in look (Pit's glyph and the capture noun), opening the Pit sheet through
   `widgetURL` (option D1). REQ-CAPTURE-023 names the Home Screen widget, so
   the slice satisfies it directly; the look must say "capture", not repeat
   the app icon ([hig-widgets]).
4. **Share code through a `Shared/` folder** (option C1): the intent, its
   target enum, and `CaptureSurfaceRequests`.
5. **Keep `.main` and authentication.** `allowedExecutionTargets = .main`
   stays, so `perform()` only runs in the app even though the extension
   compiles it; `.requiresLocalDeviceAuthentication` stays (ADR 0023 rule).
6. **Add the target with Xcode, not by hand**: Xcode 27.2 (UI, or
   `XcodeNewTarget` with the Widget Extension template, Include Control on,
   Live Activity and configuration intent off, `embedInAppNamed: Pitstop`),
   then review and trim the JSON diff against the OneCart shape.

## Why

- Controls are the only surface whose documented way to open the app lands on
  a chosen place (`OpenIntent`) without a URL, and they cover three system
  spaces with one declaration.
- The existing routing (`CaptureSurfaceRequests`, deferral while an editor is
  open) already meets REQ-CAPTURE-023; every new entry only has to call
  `request()` in the app process. Pit's own capture then produces the
  `CaptureInput` (source `pit`), so C4 holds with no source-specific path.
- Opening Pit needs no car data; showing data needs an App Group and a store
  move with its own migration risk for TestFlight testers. Separating the two
  lets the entry ship without touching persistence.
- A shared folder keeps the synchronized-folder model of ADR 0005 and adds no
  framework or package; the files involved have no app dependencies beyond
  `Observation` and `AppIntents`.
- Creating the target with Xcode's template yields the embed phase, product
  reference, `Info.plist` extension point, and signing settings together;
  OneCart shows the resulting JSON shape builds and ships on this Runtime.

## Rejected alternatives

- **Capture inside the widget or control** (Remember from a button). Widgets
  have no text input and do not resolve intent parameters ([interactivity],
  [widget-extension]); the store is not reachable from the extension without
  an App Group. Hands-free capture already exists through Siri (ADR 0023).
- **Widget `Button(intent: OpenPitIntent())`.** Apple's guidance reserves
  widget buttons for actions that do more than open the app ([interactivity]).
- **Plain foreground `AppIntent` on the control.** The runtime article says
  control intents run in the extension in the background; only `OpenIntent` is
  documented to open the app ([runtime-behavior], [controls]).
- **`openAppWhenRun`.** Deprecated since iOS 26 and an error in an extension
  ([open-app-when-run]).
- **Shared framework / `AppIntentsPackage`.** Correct but heavier than three
  shared files; revisit if the extension later needs domain or persistence
  code.
- **Data widget in SYS-005** (next service, Pit state). Needs the App Group
  migration below; a separate, owner-approved task.
- **Hand-writing the extension target in `project.xcproj`.** Possible (the
  OneCart shape is known) but no Apple schema exists; a template-created diff
  is easier to trust and review.

## Implementation impact

### SYS-005 scope

- New target `PitstopWidgets` (Widget Extension), folder `PitstopWidgets/`,
  `WidgetBundle` with `OpenPitControl` and `CaptureWidget`; bundle ID per owner
  question 1; `MARKETING_VERSION` equal to the app's (tf-check blocks
  otherwise) and a `CURRENT_PROJECT_VERSION` key so `ci_post_clone.sh`
  rewrites it; `IPHONEOS_DEPLOYMENT_TARGET` 27.0, Swift 6, same concurrency
  settings; no entitlements.
- App target: `"dependencies": ["PitstopWidgets"]` and the "Embed App
  Extensions" copy phase (created by the template).
- `Shared/` folder with membership in both targets: `OpenPitIntent.swift`
  (adds `OpenIntent` and a `target` of a one-case `AppEnum`),
  `CaptureSurfaceRequests.swift`, and the enum. `@Dependency` resolves only in
  the app, which is the only process allowed to perform it.
- Localization: `OpenPitIntent`'s `LocalizedStringResource` keys and the
  control and widget names must resolve inside the extension bundle, which
  does not see `Pitstop/Resources/Localizations`. Either the extension gets
  its own string catalog with those keys (en, ru, uk) or the strings name
  their table and bundle; check which the metadata extractor accepts.
- URL route: `CFBundleURLTypes` with the scheme (owner question 3), `onOpenURL`
  in `RootView` that calls `captureRequests.request()` for the Pit URL and
  ignores every other URL.
- `RootView` behavior is unchanged: deferral while an editor is open, one
  sheet over the current surface.
- Docs: an ADR for the widget extension (surfaces, sharing, routing, data-free
  decision), REQ-CAPTURE-023 evidence, ADR 0005 consequence note (a second
  shipping target and the `Shared/` folder), `Tooling` needs no change.

### Acceptance (proposed)

1. The Pit control appears in the Control Center gallery and the Lock Screen
   and Action button pickers; tapping it with the app terminated, in the
   background, and in the foreground opens the Pit sheet over the last
   surface, never via Car Board (REQ-CAPTURE-023).
2. With a note editor open and a draft typed, the control defers: the draft is
   kept and Pit opens after the editor closes (ADR 0024 behavior).
3. The small and circular widgets appear in the widget gallery after one app
   launch; a tap opens the Pit sheet in the same three app states.
4. On a locked phone, the control or widget asks for unlock before the app
   shows anything.
5. The Shortcuts app still lists Remember and Open Pit once each; the Open Pit
   App Shortcut still opens the sheet.
6. No App Group, entitlement, or store change; the store path is unchanged.
7. `just verify` passes; `tf-check` finds one `MARKETING_VERSION`.

### Test strategy

- Unit (app test target, hosted): the URL router maps the Pit URL to one
  request and ignores others; `OpenPitIntent` declares `OpenIntent`, `.main`,
  and local-device authentication, and its target enum has one case;
  `AppShortcutsTests` still pass and the extracted metadata lists Open Pit
  once.
- Build-level: a test or `verify` step that the built `Pitstop.app` contains
  `PlugIns/PitstopWidgets.appex` with the expected bundle ID prefix and
  versions (read from the built products, as `AppShortcutsTests` reads
  metadata).
- The extension itself has no logic to unit test; the control and widget are
  declarations. Simulator smoke covers acceptance 1 to 5 (Control Center and
  Home Screen are reachable on the simulator); Lock Screen and Action button
  are device checks, grouped with SYS-006.

### Cost of a data widget (for a later task)

- App Group `group.dev.vil4max.pitstop` registered in the developer account
  and added to both targets; entitlements files become real (ADR 0005 keeps
  the template excluded).
- Store move: before the first `ModelContainer` opens, move `Pitstop.store`
  and its `-wal`/`-shm` companions from Application Support to the group
  container, only when the target does not exist; fall back to the old path on
  failure; never open both. TestFlight testers hold data, so this needs a
  migration test with a V2 store fixture and a device check. ADR 0007 changes.
- Two processes on one SQLite store: the extension opens it read-only in the
  timeline provider; the app calls `WidgetCenter` reloads after writes that
  change what the widget shows, within the reload budget ([up-to-date]).
- Privacy: car data on the Lock Screen and in StandBy needs
  `privacySensitive` or the data-protection entitlement ([widget-extension]).
- Explicit URL versus `GroupContainer.automatic`: test that adding the App
  Group entitlement alone does not relocate the store.

## Follow-up tasks (proposals only; not created as issues)

| ID | Title | Type | Depends on | Est |
|---|---|---|---|---|
| SYS-005 | Widget capture slice (control + static widget, data-free) | implementation | this record, owner questions 1–4 | 3d |
| SYS-WID-002 | Data widget: App Group, store migration, next-service widget | investigation → implementation | SYS-005, owner question 5 | 3d+ |
| INV-CAP-004 | Microphone start from an external entry | investigation | a voice capture path in Pit | — |

## Owner decisions (summary)

1. **Bundle ID of the extension:** `dev.vil4max.pitstop.widgets`
   (recommended; must start with the app's ID) or the template default
   `dev.vil4max.pitstop.PitstopWidgets`. It is permanent once shipped.
2. **Surfaces in SYS-005:** control and static Home Screen/Lock Screen widget
   (recommended), or the control only, deferring the Home Screen widget until
   it can show data (HIG: a widget that only repeats the app icon adds little).
3. **URL scheme:** register `pitstop://` for the widget (recommended; any app
   can then open the Pit sheet, nothing else), or spend a spike on the
   `NSUserActivity` route without a scheme.
4. **`OpenPitIntent` as `OpenIntent`:** change the shipped intent (one Open Pit
   action everywhere, recommended) or add a hidden control-only intent.
5. **Data later:** may a future widget show car data (next service, Pit
   state) on the Home Screen and Lock Screen? If yes, approve an App Group and
   the store migration as their own task.

## Sources

[interactivity]: https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities
[linking]: https://developer.apple.com/documentation/widgetkit/linking-to-specific-app-scenes-from-your-widget-or-live-activity
[widget-url]: https://developer.apple.com/documentation/swiftui/view/widgeturl(_:)
[user-info-key]: https://developer.apple.com/documentation/widgetkit/widgetcenter/userinfokey
[widget-extension]: https://developer.apple.com/documentation/widgetkit/creating-a-widget-extension
[up-to-date]: https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date
[controls]: https://developer.apple.com/documentation/widgetkit/creating-controls-to-perform-actions-across-the-system
[control-refinements]: https://developer.apple.com/documentation/widgetkit/adding-refinements-and-configuration-to-controls
[control-widget]: https://developer.apple.com/documentation/swiftui/controlwidget
[control-button]: https://developer.apple.com/documentation/widgetkit/controlwidgetbutton
[open-intent]: https://developer.apple.com/documentation/appintents/openintent
[open-app-when-run]: https://developer.apple.com/documentation/appintents/appintent/openappwhenrun
[supported-modes]: https://developer.apple.com/documentation/appintents/appintent/supportedmodes
[runtime-behavior]: https://developer.apple.com/documentation/appintents/configuring-the-runtime-behavior-of-your-app-intents
[execution-targets]: https://developer.apple.com/documentation/appintents/intentexecutiontargets
[allowed-execution-targets]: https://developer.apple.com/documentation/appintents/appintent/allowedexecutiontargets
[app-intents-package]: https://developer.apple.com/documentation/appintents/appintentspackage
[app-groups]: https://developer.apple.com/documentation/xcode/configuring-app-groups
[group-container]: https://developer.apple.com/documentation/swiftdata/modelconfiguration/groupcontainer-swift.struct
[group-container-automatic]: https://developer.apple.com/documentation/swiftdata/modelconfiguration/groupcontainer-swift.struct/automatic
[project-format]: https://developer.apple.com/documentation/xcode/updating-your-xcode-project-configuration-file-format
[xcode-27-2]: https://developer.apple.com/documentation/xcode-release-notes/xcode-27_2-release-notes
[hig-widgets]: https://developer.apple.com/design/human-interface-guidelines/widgets
[hig-controls]: https://developer.apple.com/design/human-interface-guidelines/controls
[hig-action-button]: https://developer.apple.com/design/human-interface-guidelines/action-button

All pages above were read on 2026-09-21. Version facts (iOS 16 for
`OpenIntent`, iOS 17 for interactive widgets and `AppIntentsPackage`, iOS 18
for controls, iOS 26 for `supportedModes` and the `openAppWhenRun`
deprecation, iOS 27 for `allowedExecutionTargets` and `IntentExecutionTargets`)
come from each page's availability metadata or its text. The `OpenIntent` and
`ControlWidgetButton` signatures were read from the iOS 27.0 simulator SDK
`.swiftinterface` files of AppIntents and WidgetKit.
