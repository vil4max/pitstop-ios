# Capture Locale for In-App Input

**Status:** Accepted for implementation (agent decision under owner delegation,
2026-09-22); owner review pending\
**Task:** CAP-LOC-001\
**Builds on:** [`0023-remember-intent.md`](0023-remember-intent.md) (Siri passes
`systemContext.locale`), [`0027-foundation-models-interpreter.md`](0027-foundation-models-interpreter.md)
(language gate, locale phrase in the instructions)\
**Contracts:** [`../requirements/capture-pipeline.md`](../requirements/capture-pipeline.md)
(REQ-CAPTURE-002, REQ-CAPTURE-026)

## Context

`CaptureInput.localeIdentifier` defaulted to `ru_RU`. Siri passed the request
locale (ADR 0023); Pit and the Notes editor passed nothing, so every typed
capture claimed Russian whatever the person used. The only reader today is
`SystemModelDrafter`, which names a non-US-English locale in the model
instructions ("The person's locale is …", ADR 0027). An English speaker's
capture therefore told the model the person was Russian.

A typed capture has no request locale the way a Siri request does. Candidates:

| Source | What it says | Availability |
|---|---|---|
| Keyboard input language (`UITextInputMode.primaryLanguage` of the active text input) | The keyboard the person typed with | Belongs to the first responder; SwiftUI `TextField` does not expose it, it changes mid-text, and dictation or paste bypass it. Not reliable. |
| `Bundle.main.preferredLocalizations.first` | The app localization in use (en, ru, uk) | Language only; loses the region. |
| `Locale.current` | The app's locale | Apple: represents "the locale currently used by the app", based on the system locale, "any app-specific locale choice made in the Settings app", and the availability of the preferred locale in the app ([`Locale.current`](https://developer.apple.com/documentation/foundation/locale/current)). Language resolved against the app's localizations, plus the person's region. |

## Decision

1. An in-app capture carries `Locale.current.identifier`, read **at the moment
   of capture**. `AppEnvironment.locale` (`@Sendable () -> Locale`, live value
   `{ Locale.current }`) is the single source; `AppCoordinator` injects it
   into `PitCaptureViewModel` and `NotesViewModel`. Reading per capture
   (not once at launch) follows Apple's note that `current` does not change
   after it is read, while a language or region change in Settings can happen
   while the app runs.
2. `CaptureInput.localeIdentifier` has no default. Every source names its
   locale: Siri the request locale (ADR 0023), Pit and the Notes editor the
   app locale. The `ru_RU` fallback is removed: no `CaptureInput` is stored,
   so there are no legacy inputs to decode. Tests that do not care use a
   test-only initializer with a fixture locale.
3. The locale stays a **hint**. It reaches every interpreter unchanged
   (`InterpreterChain` passes the same input), and the Foundation Models path
   uses it only for the instructions' locale phrase. The language gate keeps
   deciding from the written text (ADR 0027, decision 2): an English app
   locale does not send Russian text to the model, and a Russian app locale
   does not keep English text away from it. `RuleBasedInterpreter` does not
   read the locale; its word lists already cover both languages.

## Rejected alternatives

- **Keyboard input language.** Not readable from SwiftUI text fields, and not
  meaningful for pasted or dictated text.
- **Preferred localization only.** Drops the region that the locale phrase and
  later number or date reading may need.
- **Locale as a gate fallback or `NLLanguageRecognizer.languageHints` prior.**
  ADR 0027 keeps the gate on what was written; a setting would push ambiguous
  short captures toward a language the person may not have used, which the
  hedge rule then cannot guard. Changing it is an ADR 0027 decision, not this
  task.
- **Keep the `ru_RU` default for "legacy" inputs.** Nothing persists a
  `CaptureInput`; a default would only hide a source that forgot its locale.

## Consequences

- An English-locale person's typed captures no longer carry a Russian locale
  phrase to the model.
- A Ukrainian or Russian UI with English text still sends English to the model
  with a `uk_…`/`ru_…` locale phrase, as Apple recommends for a non-US locale.
- Tests: REQ-CAPTURE-026 in `PitCaptureViewModelTests`, `NotesTests`,
  `FoundationModelsInterpreterTests` (gate and chain).
