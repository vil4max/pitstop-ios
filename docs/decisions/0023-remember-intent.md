# Remember in PitStop App Intent

**Status:** Accepted for implementation (owner decisions 2026-09-21)\
**Task:** SYS-002\
**Investigation:** [`../planning/investigations/sys-001-app-intents.md`](../planning/investigations/sys-001-app-intents.md)\
**Contracts:** [`../core.md`](../core.md) (C4),
[`../requirements/capture-pipeline.md`](../requirements/capture-pipeline.md)
(REQ-CAPTURE-002, 003, 005, 008, 009, 010),
[`0006-capture-confirmation-policy.md`](0006-capture-confirmation-policy.md),
[`0011-interpreted-capture-without-a-model.md`](0011-interpreted-capture-without-a-model.md),
[`0015-interpretation-deadline-and-cancellation.md`](0015-interpretation-deadline-and-cancellation.md)

## Context

The capture contract names `RememberInPitStopIntent` as a source that emits a
`CaptureInput` and never builds domain entities (REQ-CAPTURE-003). SYS-001
investigated the iOS 27 App Intents surface and proposed a design with six
owner questions. The owner answered them on 2026-09-21. This record fixes the
decisions that SYS-002 implements; the phrase shortcut (SYS-003) and device
checks (SYS-006) follow separately.

The APIs below were checked against the iOS 27 simulator SDK interface
(`AppIntents.swiftinterface`) and Apple's documentation pages cited in the
SYS-001 record, on 2026-09-21.

## Decision

### Placement and process

- `Pitstop/App/Intents/RememberInPitStopIntent.swift` is the adapter only:
  title, the `text` parameter with a request dialog, modes, targets,
  authentication, the Siri choice prompt, and the spoken result.
- `Pitstop/Features/SystemCapture/RememberIntentHandler.swift` holds the
  logic, testable without App Intents. It takes the `RememberPipeline`, the
  persistence state, and a clock by initializer, and a `RememberPrompting`
  value per call. `RememberSpeech` maps questions and replies to localized
  text.
- `allowedExecutionTargets = .main` and `supportedModes = .background`: the
  intent runs in the app process and never opens the app. The store sits in the
  app's own container, so an App Intents extension would need an App Group
  store move and two processes writing one SQLite file.
- `PitstopApp.init` builds `AppEnvironment.live()` once, passes it to
  `AppCoordinator(environment:)`, and registers the handler with
  `AppDependencyManager.shared` before any scene exists (Apple: register
  dependencies as soon as possible, because the system can run an intent soon
  after launch). The intent reads it with `@Dependency`. One process, one
  `ModelContainer`, one store shared by the UI and the intent.
- `AppCoordinator.interpretedPipeline(_:)` builds the interpreted pipeline for
  both Pit and the intent: the same `RuleBasedInterpreter`, deadline, logger,
  and analytics observer (core C4).

### Owner decisions (2026-09-21)

1. **Confirm in place.** A proposal that returns `needsConfirmation` is asked
   with `requestChoice(between:dialog:)`: "Record it", "Save the words only",
   and the system Cancel option. They call `pipeline.confirm`,
   `pipeline.preserveRaw`, and `pipeline.cancel`. `requestChoice` throws when
   the person cancels or dismisses; the handler then reports the capture as
   discarded and rethrows, so nothing is written (REQ-CAPTURE-005).
2. **Clarification is not asked by voice yet.** `needsClarification` offers
   "Save the words only" or Cancel, and says the detail can be added in the
   app. Asking the missing field by voice waits for SYS-006 (done in
   [ADR 0026](0026-siri-voice-clarification.md)).
3. **Only an unlocked phone.** `authenticationPolicy =
   .requiresLocalDeviceAuthentication`: Apple documents it as requiring the
   person to unlock the device that runs the intent, even when the request
   came from an unlocked Apple Watch. `.requiresAuthentication` was not chosen
   because an unlocked paired device would satisfy it while the phone stays
   locked.
4. **Spoken mileage follows Pit.** ADR 0006 is unchanged for the Siri source:
   an ordinary reading is auto-accepted; a reading below the latest one is a
   conflict and is asked, naming both values.
5. **One source value.** Every run records `CaptureSource.siri`, which here
   means "an App Intents entry" (Siri, Shortcuts, Spotlight, Action button).
   `IntentSystemContext` exposes no property that tells a voice request apart,
   so emitting `shortcut` for some runs would be a guess. `shortcut` stays
   unused.
6. **No UI test target now.** App Intents Testing needs a UI testing bundle;
   the handler tests cover the logic, and `perform()` only maps values.
7. **No pending draft after a failure (REQ-CAPTURE-009 exception).** When the
   write fails, the intent throws an `AppIntentError` whose description is
   "Not saved … please say it again". The words are not kept anywhere for a
   later retry. REQ-CAPTURE-009 asks for the input to stay available; Siri
   cannot hold it, and a stored draft would keep private raw text outside the
   memory the person chose to save. The owner accepted this exception.

### Input

`CaptureInput(payload: .text(text), source: .siri, capturedAt: now(),
localeIdentifier: systemContext.locale.identifier)`. `.text` because the
intent receives a string and cannot tell whether it was spoken or typed.
`systemContext.locale` (iOS 27) is the request's locale, which can differ from
the app's. `visibleFeature` is nil: no surface is visible to lend a prior.
Pit still passes no locale (proposed CAP-LOC-001).

### Temporary storage

When `AppEnvironment.persistence == .temporary` (the on-disk store could not be
opened, or a test/demo launch), the handler refuses before building an input
and the intent fails with "PitStop's storage isn't available right now — open
PitStop to check." Saving into memory that disappears with a background
process would report a save that did not last (REQ-CAPTURE-009).

### Replies

Replies are `ProvidesDialog` text, complete without a screen, in en, ru, and
uk. They name the destination and typed values only and never repeat the words
(REQ-CAPTURE-025):

| Handler reply | Spoken |
|---|---|
| saved, preserved raw | "Saved to Notes as you said it." (REQ-CAPTURE-008) |
| saved to Notes / Service / History / Car Board | "Saved to Notes." / "Recorded in Service." / "Recorded in History." / "Updated on your car's board." (REQ-CAPTURE-010) |
| already saved | "That's already saved in PitStop." |
| nothing to save | "There was nothing to remember." |
| cancelled (Cancel chosen or task cancelled) | "Nothing was saved." |
| not saved | thrown error: "Not saved. PitStop couldn't save that — please say it again." |
| storage unavailable | thrown error, as above |

Confirmation questions name the operation and mileage ("Record Engine oil as
done at 84,200 km?"), a reading ("Set the mileage to 85,000 km? The last
recorded mileage is 91,500 km, which is higher."), or only the kind (events,
vehicle facts, notes). Every string resource carries the request locale, and
operation names are resolved in the same locale.

### Cancellation and time

No timer of its own. A system cancellation (the 30-second background limit or
the person cancelling) cancels `perform()`'s task; the pipeline's checks
(ADR 0015) turn it into `nothingToSave` before any write, and a choice that
arrives after cancellation is treated as Cancel. The 6-second interpretation
deadline fits well inside 30 seconds.

### Choice mapping

`SiriPrompter` maps the option `requestChoice` returns by its position among
the options offered (`firstIndex(of:)`), not by falling through to Cancel. An
option that matches none is logged (without content) and treated as Cancel, so
it writes nothing. Whether the system returns an option equal to the one
offered is not documented and needs a device check (SYS-006).

### Analytics flush

Queued analytics live in memory and are sent when RootView sees the scene go
to the background (ADR 0022). A background Siri run never shows a scene, so
`perform()` ends with `RememberIntentHandler.flushAnalytics()`, the same
detached utility-priority flush over `AnalyticsPipelineControlling`. With
analytics off the pipeline is the no-op or its queue is empty. The flush is
detached so the reply does not wait for the network; the system may suspend
the process before it finishes, and the events then wait for the next flush
in that process (a limitation, not data leaving without consent).

### Refresh

`RootView` records when the scene goes to the background and, on the next
`.active`, re-checks Pit's pending question (`pitQuestion.revalidate()`) and
reloads Car Board and the visible surface, so a save made while the app was
suspended shows on return and a mileage saved through Siri silences a pending
mileage question (REQ-PIT-009). The first activation after launch and returns
from Control Center or an alert (`inactive` → `active`) reload nothing, so no
load overlaps the launch load.

## Tests

`PitstopTests/SystemCapture/RememberIntentHandlerTests.swift`
(REQ-CAPTURE-00x, ADR-0023), a fake prompter over the real pipeline and an
in-memory SwiftData store: a thought saved as said with source `.siri`; locale,
source, payload, and time in the `CaptureInput`; completion → prompt →
record / words only / Cancel / dismissed prompt; clarification → words only /
Cancel; an ordinary reading auto-accepted; a lower reading asked with both
values; temporary storage refused before interpretation; a failed write
reported as not saved; a cancelled task writes nothing; blank words.
`RememberSpeechTests`: every reply translated in en, ru, uk; distinct
destinations; questions never contain the words; typed values spoken. The
handler suite also checks that `flushAnalytics()` flushes the pipeline, and
`MileageQuestionEndToEndTests` checks that a mileage saved through the handler
silences a pending mileage question once it is re-checked.

## Rejected alternatives

- **App Intents extension.** Store migration to an App Group and
  cross-process writes, for no user-visible gain while a background launch of
  the app works.
- **Opening the app for confirmation** (`continueInForeground`). Fails where
  Siri matters most (hands busy, possibly no foreground transition allowed) and
  leaves the person's context.
- **`requestConfirmation`.** Two outcomes only; "Save the words only" would be
  lost.
- **Raw-only Siri capture.** The same words would mean different things from
  Siri and from Pit (C4).
- **`.alwaysAllowed` authentication.** Rejected by the owner until a device
  check shows the store is readable while locked; `.requiresAuthentication`
  is rejected above.
- **Keeping a pending draft after a failure.** See owner decision 7.
- **Returning a dialog for failures.** A thrown error marks the run as failed
  in Shortcuts, so automations can tell a failure from a save.

## Open questions

- **Ukrainian Siri.** Whether Siri accepts Ukrainian requests, and whether it
  recognises "PitStop" inside Russian and Ukrainian speech, is not stated in
  the pages read. It needs a device check (SYS-006).
- **Does the choice prompt count toward the 30-second limit?** Undocumented;
  measure on a device (SYS-006).
- **Voice-only replies.** `systemContext.isVoiceOnly` is not used yet; the
  replies are already complete sentences.
- **Returned choice option identity.** Whether `requestChoice` returns an
  option equal to the one offered (see Choice mapping); an unmatched option is
  treated as Cancel until a device check confirms it.
- **Resource locale in dialogs.** Resources carry `systemContext.locale`;
  whether Siri honours it over the app's language needs a device check.
- **Cold launch time** to the first reply (INV-CAP-003).
- **App Intents Testing smoke** once a UI test target exists (ENG-UIT-001).
- **Phrases** for the App Shortcut (SYS-003); ru and uk phrases come from the
  owner or a native speaker.
