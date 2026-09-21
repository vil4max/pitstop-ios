# App Shortcuts: Remember and Open Pit

**Status:** Accepted for implementation (agent decision under owner delegation, 2026-09-21); owner review pending\
**Task:** SYS-003 ("Shortcut into capture surface")\
**Investigation:** [`../planning/investigations/sys-001-app-intents.md`](../planning/investigations/sys-001-app-intents.md) (SYS-003 notes)\
**Contracts:** [`../core.md`](../core.md) (C4),
[`../requirements/capture-pipeline.md`](../requirements/capture-pipeline.md)
(REQ-CAPTURE-002, 003, 023),
[`../requirements/pit-behavior-and-motion.md`](../requirements/pit-behavior-and-motion.md)
(REQ-PIT-013), [`0023-remember-intent.md`](0023-remember-intent.md)

## Context

SYS-002 shipped `RememberInPitStopIntent` (ADR 0023). It is an ordinary App
Intent, so it appears in Shortcuts only as an action a person has to find and
add. Siri and Spotlight offer an intent by phrase only when the app declares it
in an `AppShortcutsProvider` ([app-shortcuts], [provider]). The card asks for a
"shortcut into capture surface".

Two capture surfaces exist: Siri's own (Remember runs in the background and
asks for the words) and Pit's sheet in the app (REQ-PIT-013). The capture
contract lists App Shortcuts as a source (REQ-CAPTURE-002) and asks that an
entry from outside the app opens capture without routing through Car Board
(REQ-CAPTURE-023, written for the widget).

The APIs below were checked on 2026-09-21 against the iOS 27 simulator SDK
interface (`AppIntents.swiftinterface`) and Apple's documentation pages linked
at the end.

## Decision

### Two App Shortcuts, in this order

| Shortcut | Intent | Short title | Symbol | Runs |
|---|---|---|---|---|
| Remember | `RememberInPitStopIntent` (ADR 0023, unchanged) | `shortcut.remember.title` | `text.bubble` | In the background; Siri asks for the words |
| Open Pit | `OpenPitIntent` (new) | `shortcut.openPit.title` | `square.and.pencil` | Opens the app on the Pit sheet |

Remember comes first: the HIG asks to order shortcuts by importance, and
capture without leaving the current context is the product's main system entry
([hig-app-shortcuts]). Two of the ten allowed shortcuts are used
([hig-app-shortcuts], [wwdc23-10102]).

`PitStopShortcuts` (`Pitstop/App/Intents/PitStopShortcuts.swift`) declares
both with `AppShortcut(intent:phrases:shortTitle:systemImageName:)`
([app-shortcut-init]). Phrases stay literals in the provider because the
compiler extracts them at build time ([app-shortcuts]); no phrase carries a
parameter, because free text cannot be a phrase parameter ([hig-app-shortcuts],
SYS-001), and Remember's `requestValueDialog` asks for the words.

### Open Pit

- `supportedModes = .foreground(.immediate)`: the system brings the app to the
  foreground before `perform()` runs ([supported-modes], [immediate]).
  `openAppWhenRun` is deprecated since iOS 26 (SYS-001). The built metadata
  shows `openAppWhenRun: true`, `supportedModes: 2`.
- `allowedExecutionTargets = .main`, as Remember: the code lives in the app
  bundle, which is the only place that can run in the foreground
  ([runtime-behavior]).
- `authenticationPolicy = .requiresLocalDeviceAuthentication`, the owner's
  Remember rule (ADR 0023, decision 3): the car's memory shows only on an
  unlocked phone.
- `perform()` is `@MainActor` and only calls `CaptureSurfaceRequests.request()`.
  It returns no dialog: the open sheet is the answer.

### Routing into the Pit sheet

`CaptureSurfaceRequests` (`Pitstop/App/CaptureSurfaceRequests.swift`) is a
`@MainActor @Observable` object with `request()`, `isPending`, and
`take(isPresentationBlocked:)`. `PitstopApp.init` creates one, passes it to
`AppCoordinator(environment:captureRequests:)` (and from there to `RootView`),
and registers the same instance with `AppDependencyManager` next to the
Remember handler; the intent reads it with `@Dependency`. There is no
singleton: the process-wide registration is the App Intents dependency
mechanism already used by ADR 0023.

`RootView` observes the pair (pending request, feature task presented) with
`onChange(initial: true)`. `take` clears the request and returns true only
when Pit can actually open; `RootView` then sets its sheet to `.pit`, exactly
what a tap on Pit does (REQ-PIT-013).

**A feature editor defers the request.** The Notes, History, and Service
editors and the Car Board editor are sheets presented by screens below
`RootView`. SwiftUI does not present a second sheet from an ancestor while a
descendant presents one, so setting `sheet = .pit` then would leave the root's
state at `.pit` with nothing shown: Pit presence would believe capture is
running and the Pit button would do nothing. Those screens already report
`.modalTask` to Pit while their editor or undo prompt is shown (ADR 0019);
`PitPresenceModel.isFeatureTaskPresented` is that report from any source
other than the root's own utility sheet. While it holds, the request stays
pending, unconsumed; when the editor closes, the gate changes and Pit opens.

Deferring was chosen over dismissing the editor first: dismissing from the
root would need a new channel into every feature's editor state and would
throw away an unsaved draft the person may be in the middle of, while
deferral keeps the draft and only delays Pit until the person finishes or
cancels. The cost is that a request made while an editor is open opens Pit
later, when that editor closes, even if the person has moved on; it opens
once and over the same surface.

Consequences:

- **Cold launch.** The request is kept until taken; `initial: true` takes it
  when the content first appears, after DEBUG demo preparation. Checked on the
  simulator: Shortcuts, then Open Pit, with the app terminated opens the Pit
  sheet.
- **Warm app.** The change fires immediately; checked on the simulator too.
- **Note editor open.** Checked on the simulator: with a draft in the New note
  editor, Open Pit from Shortcuts returns to the editor with the draft intact;
  Cancel closes it and the Pit sheet opens; after Close, tapping Pit opens it
  again.
- **Repeated requests** before the UI takes one open Pit once.
- **Current surface kept.** The sheet opens over whatever screen the person was
  on; that screen stays the capture prior (REQ-CAPTURE-022), as for a tap.
  Nothing routes through Car Board (REQ-CAPTURE-023).
- **Settings open.** The root owns that sheet, so it does not block; the sheet
  item switches from Settings to Pit.
- **Pit already open.** `sheet` is already `.pit`; nothing changes.

Pit's own capture then runs its usual `CaptureInput` with source `pit`: Open Pit
opens the surface, it does not capture (REQ-CAPTURE-003).

### Phrases

`${applicationName}` is the build-time form of `\(.applicationName)`
([application-name]); the system substitutes the app's display name,
`CFBundleDisplayName` "PitStop" in every locale (`InfoPlist.xcstrings`).
Phrases live in `Pitstop/Resources/Localizations/AppShortcuts.xcstrings`, the
catalog name the build reads for App Shortcut phrases ([wwdc23-10102]); each
locale lists its variants as a string set. The en set repeats the source
phrases so that `en.lproj` gets its own table even though the development
region is ru.

The localized wording is data and lives only in the catalogs; this record
describes it in English. The owner reviews it in
`AppShortcuts.xcstrings` (phrases) and `Localizable.xcstrings`
(`shortcut.remember.title`, `shortcut.openPit.title`, `intent.openPit.title`,
`intent.openPit.description`).

| Source phrase (en) | ru variants | uk variants |
|---|---|---|
| "Remember in PitStop" | 2: the imperatives "remember" and "write down", each followed by "in PitStop" | 2: the same two imperatives |
| "Make a note in PitStop" | 1: "make a note in PitStop" | 1: the same |
| "Open Pit in PitStop" | 2: "open the capture in PitStop" and "open Pit in PitStop" | 2: the same |
| "Show Pit in PitStop" | 1: "show Pit in PitStop" | 1: the same |

Wording choices:

- **Informal imperative.** A spoken command addressed to Siri, the form people
  naturally use for one.
- **Pit's name** follows the app's own localization (`utility.pit`) and is
  declined as a character (animate accusative) where a phrase names Pit.
- **"Open the capture"** reuses the noun of the existing Pit button hint
  (`utility.pit.hint`), so the Open Pit tile title and intent title use that
  noun instead of Pit's declined name, which reads oddly on a button. The
  description mirrors the same hint.
- **Ukrainian preposition** follows euphony: the vowel form (transliterated
  "u") between consonants, the consonant form ("v") after a vowel.
- **Apostrophe** is ASCII, matching the existing Ukrainian strings.
- The Remember tile title reuses the word of `pit.save`.

## Tests

`PitstopTests/SystemCapture/AppShortcutsTests.swift` (ADR-0024,
REQ-CAPTURE-002, REQ-CAPTURE-023, REQ-PIT-013), run hosted in the app so they
read what the build hands the system:

- `PitStopShortcuts.appShortcuts` has two entries; the extracted App Intents
  metadata (`Metadata.appintents/extract.actionsdata`) lists
  `RememberInPitStopIntent` then `OpenPitIntent`, with the two short-title keys
  and a symbol each.
- Every source phrase contains `${applicationName}`, and no phrase belongs to
  two shortcuts.
- For en, ru, and uk, the compiled `AppShortcuts.strings` covers every source
  phrase, every variant contains `${applicationName}`, and no variant repeats.
- `OpenPitIntent` declares `.foreground(.immediate)`, `.main`, and
  `.requiresLocalDeviceAuthentication`.
- `CaptureSurfaceRequestsTests`: nothing pending at start; a request is taken
  once and cleared; repeated requests coalesce; a later request is pending
  again; a blocked take neither opens Pit nor consumes the request, which
  opens Pit once unblocked.
- `FeatureTaskPresentationTests`: a feature source reporting `.modalTask`
  blocks until withdrawn; the root's utility sheet, scrolling, and editing do
  not block.
- The metadata and compiled-phrase formats the helpers parse are undocumented
  build outputs; each `#require` names what was missing, so a toolchain format
  change reads as such rather than as a product defect.

The `RootView` binding (`onChange`, then `sheet = .pit`) is SwiftUI glue with
no logic of its own; it was checked by simulator smoke runs instead (Shortcuts
app, PitStop, Open Pit: app warm, app terminated, and a note editor open).

## Rejected alternatives

- **Remember only.** Covers Siri but not the card's "into capture surface":
  a person who wants to type, see the confirmation card, or answer Pit's
  question has no direct way into the sheet.
- **Open Pit only.** Loses hands-free capture, the reason SYS-002 exists.
- **Remember with `.foreground` fallback** (open the sheet with the words
  filled in). ADR 0023 rejected foreground confirmation; a second intent keeps
  both behaviours predictable.
- **`OpenIntent` or a URL scheme.** `OpenIntent` needs a target entity, and
  PitStop has no entity for "the capture surface"; a custom URL scheme would
  add a public entry point that any app or web page can trigger, for the same
  result.
- **Dismissing a feature editor to open Pit.** See "A feature editor defers
  the request": it would discard an unsaved draft and needs a channel into
  every feature's editor state.
- **A static or global request flag.** Would work, but hides a dependency in
  domain-free app code and cannot be replaced in tests; the injected object
  follows ADR 0023's composition.
- **Popping to Car Board before opening Pit.** The visible surface is a useful
  prior (REQ-CAPTURE-022) and REQ-CAPTURE-023 asks not to route through Car
  Board.
- **More phrases now.** Apple's sample notes that Siri also matches similar,
  not identical, wording ([sample-app-intents]); more variants are cheap to add after the device check
  shows what people actually say.
- **`SiriTipView` in Pit.** Discoverability (INV-SYS-001) is a separate change
  to Pit's layout; not part of this card.

## Open questions

- **Siri recognition in ru and uk (SYS-006, device).** Whether Siri accepts
  Ukrainian at all, and whether it hears the Latin name "PitStop" inside
  Russian and Ukrainian phrases, is not stated in the pages read. If it does not,
  add a Cyrillic transliteration of the name as an app name synonym
  ([wwdc23-10102] allows a synonym in place of the name); the declaring key was
  not found in the current documentation pages and must be confirmed first.
- **Phrase wording (owner).** The ru and uk phrases and titles are the
  agent's, written under delegation; the owner reviews them in the catalogs, in
  particular which Open Pit variant ("open the capture" or "open Pit") should
  be first, and the ASCII apostrophe.
- **Development region.** The app's development region is ru while the catalog
  source language is en; the en string set avoids relying on the fallback. A
  device check in English confirms the en phrases are offered.
- **Spotlight and Action button.** Both use the same metadata; not checked on
  the simulator.

## References

[app-shortcuts]: https://developer.apple.com/documentation/appintents/app-shortcuts
[provider]: https://developer.apple.com/documentation/appintents/appshortcutsprovider
[app-shortcut-init]: https://developer.apple.com/documentation/appintents/appshortcut/init(intent:phrases:shorttitle:systemimagename:)-8yntq
[application-name]: https://developer.apple.com/documentation/appintents/appshortcutphrasetoken/applicationname
[supported-modes]: https://developer.apple.com/documentation/appintents/appintent/supportedmodes
[immediate]: https://developer.apple.com/documentation/appintents/intentmodes/foregroundmode/immediate
[runtime-behavior]: https://developer.apple.com/documentation/appintents/configuring-the-runtime-behavior-of-your-app-intents
[hig-app-shortcuts]: https://developer.apple.com/design/human-interface-guidelines/app-shortcuts
[wwdc23-10102]: https://developer.apple.com/videos/play/wwdc2023/10102/
[sample-app-intents]: https://developer.apple.com/documentation/appintents/acceleratingappinteractionswithappintents

- App Shortcuts overview: <https://developer.apple.com/documentation/appintents/app-shortcuts>
- `AppShortcutsProvider`: <https://developer.apple.com/documentation/appintents/appshortcutsprovider>
- `AppShortcut` initializer: <https://developer.apple.com/documentation/appintents/appshortcut/init(intent:phrases:shorttitle:systemimagename:)-8yntq>
- `AppShortcutPhraseToken.applicationName`: <https://developer.apple.com/documentation/appintents/appshortcutphrasetoken/applicationname>
- `supportedModes`: <https://developer.apple.com/documentation/appintents/appintent/supportedmodes>
- `IntentModes.ForegroundMode.immediate`: <https://developer.apple.com/documentation/appintents/intentmodes/foregroundmode/immediate>
- Configuring the runtime behavior of your app intents: <https://developer.apple.com/documentation/appintents/configuring-the-runtime-behavior-of-your-app-intents>
- HIG, App Shortcuts: <https://developer.apple.com/design/human-interface-guidelines/app-shortcuts>
- WWDC23 "Spotlight your app with App Shortcuts": <https://developer.apple.com/videos/play/wwdc2023/10102/>
- Sample, Accelerating app interactions with App Intents: <https://developer.apple.com/documentation/appintents/acceleratingappinteractionswithappintents>
