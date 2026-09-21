# Siri voice clarification

**Status:** Accepted for implementation (agent decision under owner delegation, 2026-09-21); owner review pending\
**Task:** SYS-006\
**Builds on:** [`0023-remember-intent.md`](0023-remember-intent.md) (owner decisions: in-place
`requestChoice`, unlocked phone only, spoken mileage as in Pit, failure "not saved"),
[`0024-app-shortcuts.md`](0024-app-shortcuts.md),
[`0025-widgets-and-controls.md`](0025-widgets-and-controls.md)\
**Contracts:** [`../core.md`](../core.md) (C3, C4),
[`../requirements/capture-pipeline.md`](../requirements/capture-pipeline.md)
(REQ-CAPTURE-002, 005, 008, 009, 020, 025),
[`0006-capture-confirmation-policy.md`](0006-capture-confirmation-policy.md),
[`0011-interpreted-capture-without-a-model.md`](0011-interpreted-capture-without-a-model.md),
[`0015-interpretation-deadline-and-cancellation.md`](0015-interpretation-deadline-and-cancellation.md)\
**Investigation:** [`../planning/investigations/sys-001-app-intents.md`](../planning/investigations/sys-001-app-intents.md)

## Context

ADR 0023 shipped `RememberInPitStopIntent` with confirmation asked in place,
but a `needsClarification` outcome only offered "Save the words only" or
Cancel: the missing detail could be added in the app, not by voice. Pit asks
the same missing field on screen, one question at a time (REQ-CAPTURE-020),
with a number field for mileage and amount, a list for the operation and the
event kind, and "I don't know" always available (core C2). The Siri path
therefore gave a weaker result for the same words than Pit, which core C4
does not allow when the surface can ask.

SYS-006 closes that gap and adds the device check list that ADR 0023, 0024
and 0025 deferred.

## Decision

### One question per missing field, through the same pipeline

`RememberIntentHandler` answers a `needsClarification` outcome by asking the
one field in `ClarificationRequest.question`, then calls
`pipeline.answer(request, with:)`. The pipeline re-validates and may return
another clarification, a confirmation, or a save; the handler loop asks the
next question only after that, so exactly one question is open at a time and
clarification is never a form (REQ-CAPTURE-020). Every write still goes
through the validator, `ConfirmationPolicy`, mapper, and store (C4).

| Missing field | Siri prompt | Answer mapping |
|---|---|---|
| `odometerKm` | `$text.requestValue(_:)` with "What was the mileage, in kilometres?" | spoken text → `CarBoardViewModel.kilometers(from:)` (Pit's parser) → `.odometerKm` |
| `amount` | `$text.requestValue(_:)` with "How much did it cost?" | spoken text → `HistoryViewModel.amount(from:)` (Pit's parser), then a grouped whole number → `.amount` |
| `operationID` | `requestChoice` over `MaintenanceOperationID.catalog`, "I don't know", Cancel | option position → `.operation` |
| `eventKind` | `requestChoice` over `HistoryEventKind.userSelectable`, "I don't know", Cancel | option position → `.eventKind` |
| `vehicleFact`, `policyInterval` | `requestChoice`: "Save the words only" or Cancel (as in ADR 0023) | Pit cannot ask these in one step either |

The choice lists and titles are the ones Pit shows (`PitCaptureView`);
`RememberIntentHandler.options(for:)` builds the list and the handler refuses
an answer outside it. Options are mapped back by their position among the
options offered, as in ADR 0023.

### Reading a spoken number

Dictation surrounds digits with words and units ("84 200 km", "1500 ₽").
The handler parses only the span from the first to the last ASCII digit, with
Pit's parsers, so the limits and the grouping rules are Pit's (the odometer
maximum, "84.5" rejected as a possible decimal). Around that span:

- **A word after the number must be a unit.** Kilometre forms for mileage,
  the currency names of the rule-based interpreter (rouble, hryvnia, euro,
  dollar and their abbreviations) for amounts, matched as word prefixes so
  inflected forms count. Anything else ("84k", "84 thousand", "1.5
  thousand", "I don't know, about 80 thousand") makes the answer unreadable,
  because reading only the digits would record a value a thousand times too
  small. Symbols such as "₽" are not letters and pass.
- **A mileage below 1 km is unreadable**, like one above the plausible
  maximum, so the repeat rule applies instead of a silent fallback to the
  words through the validator.
- **Grouped whole amounts.** An amount that Pit's money parser rejects is
  accepted when it is a grouped whole number ("1,200" → 1200), because
  English dictation groups thousands and three digits after a separator are
  never a fraction of money.

The two Pit parsers became `nonisolated` pure functions so the handler can
call them off the main actor; their behaviour is unchanged.

### A spoken number is always heard back before it is written

Pit shows a typed number on screen before it is submitted; a spoken number
is only what Siri transcribed. The handler therefore calls
`pipeline.answer(request, with:, confirmBeforeWriting: true)` for mileage and
amount answers. The pipeline then returns `needsConfirmation` where
`ConfirmationPolicy` would have auto-accepted (an ordinary reading), and the
existing confirmation question names the value ("Set the mileage to
84,200 km?"). The flag can only add a confirmation; it never relaxes the
policy, and results that already need confirmation (completions, events,
expenses) are unchanged. Choice answers are not affected: the person heard
the option they picked.

### Unreadable answers: asked once more, then the words are kept

A first answer that yields no number is asked again with a different
sentence ("I didn't catch the mileage. What was it, in kilometres?"). A
second unreadable answer is treated as "I don't know": the pipeline saves the
words without the structure and the reply says "Saved to Notes as you said
it" (REQ-CAPTURE-008). The rule is bounded because re-asking without end
would only run into the system time limit, and keeping the words is the
pipeline's own fallback for meaning it cannot trust (REQ-CAPTURE-006). A
wrong guess is never written.

### "I don't know"

- In a choice prompt it is an explicit option, titled as in Pit.
- In a number prompt the spoken answer is compared, whole and without case or
  punctuation, with a localized phrase list in the request locale; an answer
  that contains a digit never matches, because a number was said
  (`intent.remember.answer.unknown`: for example "I don't know", "no idea";
  the ru and uk lists carry the common equivalents). "I don't know, about 80
  thousand" is not a match either; its scale word makes the number unreadable,
  so the question is asked again.
- Either way the handler calls `pipeline.answer(request, with: .unknown)`,
  which keeps the words (core C2).

### Cancel and dismissal

Every prompt goes through one helper: Cancel, a thrown dismissal, or a task
cancelled while the prompt was open calls `pipeline.cancel` once and ends
with no write (REQ-CAPTURE-005). A cancelled second question discards the
answer to the first one too, because nothing is written until the pipeline
saves. A dismissal is rethrown so Siri and Shortcuts see the run end, as in
ADR 0023.

### Voice-only wording

`systemContext.isVoiceOnly` (iOS 27) is passed to `RememberSpeech`. Apple
asks intents to make "responses and dialog" understandable "without visuals"
when it is true, and to consult it for dynamic output ([is-voice-only]). Two
things change:

- Saved replies name the app with the destination ("Saved in PitStop Notes.",
  "Updated on your car's board in PitStop."), because no app card is seen.
- Number questions add how to answer ("Say a number, or say “I don't
  know”."), because neither a keyboard nor an "I don't know" button is shown.

Other replies ("Nothing was saved.", failures) already say everything and do
not change. No sentence repeats the words the person said
(REQ-CAPTURE-025); the tests render every question in en, ru and uk, with
and without a screen, and look for the words.

### Why re-ask `text` instead of a new parameter

App Intents asks for a value only through a declared parameter:
`IntentParameter.requestValue(_:)` "request[s] a value from the user for this
parameter" ([request-value]); `AppIntent` itself has `requestChoice` but no
free-value prompt (checked in the iOS 27 SDK interface). The words are
captured into the `CaptureInput` before any question, so the prompter reuses
`$text.requestValue(_:)` with the question as its dialog. A second optional
parameter would appear in the Shortcuts editor as an input nobody should fill
ahead of the question.

### Time budget and the 30-second limit

Apple documents that a background task gets up to 30 seconds and that the
system can cancel an intent that "didn't report progress and exceeded its
30-second runtime limit" ([cancellable], [long-running]). The documentation
does not say whether time spent waiting on `requestValue` or
`requestChoice` counts toward that limit; the pages read describe the limit
for work, and the prompts say only that execution "resumes only after the
person selects an option" ([request-choice]).

- The non-interactive parts are bounded: interpretation has its 6-second
  deadline (ADR 0015), store reads and the write are local SQLite work, and
  answering a question does not call the interpreter again.
- The interactive part is at most one number question plus one repeat, or
  one choice, per missing field, and one confirmation. If the system does
  count prompt time and cancels the run, the pipeline's cancellation checks
  turn it into "nothing written" (ADR 0015, REQ-CAPTURE-005); a partial answer
  is never saved.
- **`LongRunningIntent` is not adopted.** Apple describes it for tasks such as
  file operations, synchronisation and inference that need more background
  time, with regular progress reports ([long-running]); it does not mention
  prompts, and the capture has no long-running work to report. The device
  check below measures whether a slow answer ends the run.

### Reachability today

The rule-based interpreter (ADR 0011) never returns a proposal with a missing
required field: it proposes a completion only with an operation, a car wash
with its kind, and a reading only with a number. With it, the Siri path
asks confirmations but never a clarification, exactly as Pit does. The voice
clarification becomes reachable when an interpreter that can leave a field
open ships (Foundation Models, CAP-005). It is built and tested now so the
Siri path does not fall behind Pit when that happens; device checks 5 to 8
wait for it.

## Tests

`PitstopTests/SystemCapture/RememberIntentHandlerTests.swift`, suite
"Remember in PitStop voice clarification" (REQ-CAPTURE-005, 008, 020, 025,
ADR-0026), a fake prompter over the real pipeline and an in-memory SwiftData
store: a missing mileage asked and recorded; an operation chosen from the
catalog and then confirmed as a separate question; an event kind chosen; an
amount read from "1 500 ₽"; an unreadable number asked once more and then
recorded; two unreadable numbers keeping the words; "I don't know" for a
number and for a choice; a cancelled second question writing nothing and
discarding once; a dismissed number prompt; no question on the way containing
the words; the spoken-number parser, accepted and rejected cases. The
existing suite now checks the words-only question for a field that cannot be
asked by voice and a cancelled number question.
`RememberSpeechTests` adds the new questions to the "never the words" and
"translated" checks, voice-only saved replies naming PitStop in en, ru and
uk, unchanged non-save replies, the voice hint on number questions, distinct
repeat questions, translated and distinct option titles, and "I don't know"
recognition in en, ru and uk.

## Device checks (owner)

Run on a physical iPhone with iOS 27, PitStop installed from TestFlight or
Xcode, a car with a recorded mileage, and Siri set to the language under
test. Record the result and the date next to each line (pass, fail, or the
observed behaviour).

| # | Check | Steps | Expected result |
|---|---|---|---|
| 1 | English phrase | Say "Remember in PitStop", then "changed the oil at 84,200" | Siri asks to record the oil change at 84,200 km; "Record it" writes it; the reply is "Recorded in Service." |
| 2 | Russian phrase and name | Siri in Russian: say the Russian Remember phrase from `AppShortcuts.xcstrings`, then a thought | Siri starts PitStop's Remember (not a web search or another app) and asks what to remember in Russian |
| 3 | Ukrainian Siri | Look for Ukrainian in Settings → Siri → Language; if present, repeat check 2 in Ukrainian | Either Ukrainian is not offered (note it), or the Ukrainian phrase starts Remember and the prompts are in Ukrainian |
| 4 | Reply language | Device language English, Siri language Russian; save a note by voice | The reply is in the Siri request's language (Russian); note which language was used if not |
| 5 | Mileage by voice (after CAP-005) | Say a completion the interpreter returns without a mileage it needs, or a reading without a number; answer "eighty-four thousand two hundred" | Siri asks for the mileage in kilometres, then asks to set it to 84,200 km; "Record it" records it; note how Siri transcribed the number (digits, or words that make it ask again) |
| 6 | Unreadable answer (after CAP-005) | At the mileage question, answer "a lot", then "a lot" again | The question is repeated once with "I didn't catch…"; then the words are saved and the reply says they were saved as said |
| 7 | "I don't know" (after CAP-005) | At a mileage question answer "I don't know", and the Russian equivalent with Siri in Russian | No repeat; the words are saved as said |
| 8 | Operation choice (after CAP-005) | Trigger a completion without an operation; listen to the choice | Siri offers the catalog operations, "I don't know" and Cancel; picking one leads to the confirmation question; note whether Siri reads the options aloud in voice-only mode |
| 9 | Returned option identity | Pick "Record it" in check 1 (and an option in check 8 once reachable) | The chosen option is acted on (not treated as Cancel); an "Unmatched choice option" log line would mean the system returns a different option value (ADR 0023) |
| 10 | Cancel mid-way | At the confirmation in check 1 say "Cancel" (after CAP-005 also at the second question of a two-question capture) | "Nothing was saved."; nothing new in Notes, Service, History or Car Board |
| 11 | Voice-only reply | With AirPods and the phone in a pocket (or CarPlay), save a note | The reply names PitStop and Notes ("Saved in PitStop Notes."); the number question adds "Say a number, or say I don't know" |
| 12 | Locked phone | Lock the phone, say "Remember in PitStop" | Siri asks to unlock first (`requiresLocalDeviceAuthentication`); nothing is saved until the phone is unlocked |
| 13 | Prompt time limit | At a question wait 35 seconds, then answer | Either the answer is accepted (prompt time does not count) or Siri ends the run; in the second case nothing is written; note which |
| 14 | Cold launch | Force-quit PitStop, then run check 1 | The first question arrives without an error; note the time to the first prompt (INV-CAP-003) |
| 15 | Lock Screen control (SYS-005) | Add the Open Pit control to the Lock Screen; tap it while locked | The phone asks to unlock, then PitStop opens with the Pit sheet |
| 16 | Action button (SYS-005) | Assign the Open Pit control to the Action button; press it with the app terminated | PitStop opens with the Pit sheet |
| 17 | Widget gallery (SYS-005) | Add the small and the Lock Screen circular PitStop widgets; tap each | Both appear in the gallery; each tap opens the Pit sheet |
| 18 | Shortcuts listing | Open Shortcuts → App Shortcuts → PitStop, and search "Open Pit" in the action list | Remember and Open Pit are listed; Open Pit appears once, not once per target (app and widget extension) |

## Rejected alternatives

- **A second `@Parameter` for the answer.** It would show in the Shortcuts
  editor as an input to fill in advance; see "Why re-ask `text`".
- **Typed `Int` or `Double` parameters for mileage and amount.** Siri would
  parse the number, but "I don't know" could not be said, and the value would
  bypass Pit's parsers.
- **`requestDisambiguation` over entities for the operation.** It needs an
  `AppEntity` for operations and an entity query for a fixed list that
  `requestChoice` already presents.
- **Re-asking until the answer is readable.** Unbounded; the run would end at
  the system limit with nothing saved, while keeping the words saves what the
  person said.
- **Auto-accepting a spoken mileage as ADR 0006 does for a typed or
  interpreted one.** A misheard number would be written without the person
  hearing it; the confirmation costs one "Record it".
- **Reading multiplier words ("thousand", "k").** Number words differ per
  language and are not parsed anywhere else in the app; asking again is
  predictable.
- **Saving the words silently after the first unreadable answer.** One
  misheard number would lose the structure the person was about to give.
- **Opening the app for the missing detail** (`continueInForeground`).
  Rejected for confirmation by the owner in ADR 0023 for the same reasons:
  hands busy, locked context, no guarantee a foreground transition is allowed.
- **`LongRunningIntent`.** Documented for long work with progress reports, not
  for prompts; see "Time budget".
- **Recognising "I don't know" with a model or fuzzy matching.** Runtime AI is
  deferred (core P4); a whole-phrase list is predictable and testable.

## Open items

- **Reachability.** Voice clarification is exercised only by tests until an
  interpreter returns incomplete proposals (CAP-005); see "Reachability
  today".
- **Device checks** above are pending; SYS-006 stays "implemented, device
  checks pending" until the owner records them.
- **Prompt time and the 30-second limit** (check 13) and **cold launch time**
  (check 14) are unmeasured.
- **Ukrainian Siri** availability and recognition of "PitStop" in ru and uk
  (checks 2, 3) are unverified; the ru and uk App Shortcut phrases and the
  "I don't know" phrase lists await review by the owner or a native speaker.
- **Number transcription.** How Siri writes spoken numbers in each language
  (digits, grouping, words) decides how often the repeat is needed (check 5);
  number words ("eighty-four thousand") are not parsed.
- **Returned option identity** (check 9) carries over from ADR 0023.
- **App Intents Testing** smoke once a UI test target exists (ENG-UIT-001).

## Sources

Read on 2026-09-21 through the local Apple documentation index (Cupertino)
and checked against the iOS 27.0 simulator SDK interface
(`AppIntents.swiftinterface`: `IntentParameter.requestValue(_:)`,
`AppIntent.requestChoice(between:dialog:)`, `IntentChoiceOption`,
`IntentSystemContext.isVoiceOnly` and `locale` at iOS 27,
`LongRunningIntent` at iOS 27).

[request-value]: https://developer.apple.com/documentation/appintents/intentparameter/requestvalue(_:)-592nd
[request-choice]: https://developer.apple.com/documentation/appintents/appintent/requestchoice(between:dialog:)
[is-voice-only]: https://developer.apple.com/documentation/appintents/intentsystemcontext/isvoiceonly
[long-running]: https://developer.apple.com/documentation/appintents/longrunningintent
[cancellable]: https://developer.apple.com/documentation/appintents/cancellableintent
