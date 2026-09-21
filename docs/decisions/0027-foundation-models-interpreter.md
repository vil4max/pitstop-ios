# Foundation Models Interpreter

**Status:** Accepted for implementation (agent decision under owner delegation,
2026-09-21); owner review pending; feature off by default\
**Task:** CAP-005 (investigation + adapter)\
**Builds on:** [`0011-interpreted-capture-without-a-model.md`](0011-interpreted-capture-without-a-model.md),
[`0015-interpretation-deadline-and-cancellation.md`](0015-interpretation-deadline-and-cancellation.md),
[`0006-capture-confirmation-policy.md`](0006-capture-confirmation-policy.md),
[`0021-analytics-boundary.md`](0021-analytics-boundary.md)\
**Contracts:** [`../core.md`](../core.md) (P3, P4),
[`../engineering/ai-architecture.md`](../engineering/ai-architecture.md),
[`../requirements/capture-pipeline.md`](../requirements/capture-pipeline.md)
(REQ-CAPTURE-006, 007, 013, 014, 015, 016, 021, 022, 025),
[`../planning/ai-roadmap.md`](../planning/ai-roadmap.md) (golden set, telemetry)

## Context

CAP-005 asks whether Apple's on-device model can interpret Russian captures into
the typed `MemoryProposal` the validator already accepts. ADR 0011 left a slot
for it: a third `SemanticInterpreting` conformance that changes nothing
downstream. Core P4 still puts runtime AI after the product baseline, so this is
a spike behind the boundary, not a shipped feature.

## API facts (iOS 27 SDK, Xcode 27.0, checked 2026-09-21)

Sources: the iOS 27 simulator SDK interface of `FoundationModels`, Apple's
documentation, and a probe run on the session simulator.

| Fact | Source |
|---|---|
| `SystemLanguageModel.default.availability` is `.available` or `.unavailable(reason)`; reasons are `deviceNotEligible`, `appleIntelligenceNotEnabled`, `modelNotReady`. The device must support Apple Intelligence and have it turned on; the model may still be downloading. | [SystemLanguageModel](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel), [Generating content…](https://developer.apple.com/documentation/foundationmodels/generating-content-and-performing-tasks-with-foundation-models) |
| `supportsLocale(_:)` (default `Locale.current`) and `supportedLanguages` say which languages the model accepts; a prompt in an unsupported language throws `GenerationError.unsupportedLanguageOrLocale`. Guardrails apply only to supported languages. | [Supporting languages and locales](https://developer.apple.com/documentation/foundationmodels/supporting-languages-and-locales-with-foundation-models) |
| Apple Intelligence languages for the 27.0 releases: English, Danish, Dutch, French, German, Italian, Norwegian, Portuguese, Spanish, Swedish, Turkish, Vietnamese, Chinese (simplified and traditional), Japanese, Korean. **Russian and Ukrainian are not listed.** | [How to get Apple Intelligence](https://support.apple.com/en-us/121115) (published 2026-09-14) |
| For a non-US-English locale, Apple recommends starting the instructions with the exact phrase "The person's locale is <identifier>." and writing built-in prompts in a supported language. | [Supporting languages and locales](https://developer.apple.com/documentation/foundationmodels/supporting-languages-and-locales-with-foundation-models) |
| Guided generation: `@Generable` structs and enums with `@Guide(description:)`; property names and descriptions are model input. `respond(to:generating:options:)` returns typed content. `GenerationOptions(samplingMode: .greedy, maximumResponseTokens:)`; the `sampling:` spelling is deprecated in the 27 SDK. | SDK interface; [Generating content…](https://developer.apple.com/documentation/foundationmodels/generating-content-and-performing-tasks-with-foundation-models) |
| The context window is 4,096 tokens for instructions, prompts and output together; `contextSize` and `tokenCount(for:)` exist since 26.4. A session answers one request at a time. | [Generating content…](https://developer.apple.com/documentation/foundationmodels/generating-content-and-performing-tasks-with-foundation-models), SDK interface |
| Errors: `LanguageModelSession.GenerationError` (`exceededContextWindowSize`, `assetsUnavailable`, `guardrailViolation`, `unsupportedGuide`, `unsupportedLanguageOrLocale`, `decodingFailure`, `rateLimited`, `concurrentRequests`, `refusal`); iOS 27 adds `LanguageModelError` for model errors. `prewarm(promptPrefix:)` exists on the session. | SDK interface; [Foundation Models updates](https://developer.apple.com/documentation/updates/foundationmodels) |
| The iOS 27 model differs from 26.x; Apple asks apps to retest prompts per model version. | [Foundation Models updates](https://developer.apple.com/documentation/updates/foundationmodels) |

Probe on the session simulator (`claude-Pitstop-1b8d76c5`, iOS 27.0, Mac host
with Apple Intelligence on): `availability: available`; `supportedLanguages`:
da, de, en (AU, GB, IN), es (419, US), fr (CA), it, ja, ko, nb, nl, pt (PT), sv,
tr, vi, zh (HK, TW); `supportsLocale(ru_RU) = false`,
`supportsLocale(uk_UA) = false`, `supportsLocale(en_US) = true`;
`contextSize` reported 0 on the simulator.

## Decision

### The adapter

`FoundationModelsInterpreter` (app target, `Infrastructure/Interpretation/`)
conforms to `SemanticInterpreting` and never writes anything.

1. Input longer than 400 characters proposes nothing: a capture is a short
   thought, and a document would spend the context and the 6-second deadline.
2. The capture's language is detected with `NLLanguageRecognizer`. When no
   language has a probability of at least 0.6, the language is unknown; the
   input locale is not used as a fallback, because it says what the person set,
   not what they wrote. Only languages whose hedge, plan and future words the
   deterministic guard covers are sent to the model: English today (Russian is
   covered too, but the model rejects it). An unknown or uncovered language,
   an unavailable model, or a language the model does not support **throws**
   (`unsupportedLanguage` or `modelUnavailable(reason)`), so the pipeline keeps
   the wording raw (ADR 0011, REQ-CAPTURE-007).
3. Hedged wording returns `nil` before the model is asked, using the rule-based
   interpreter's own hedge words (`RuleBasedInterpreter.isHedged`), so an
   intention stays a Note by the same deterministic rule (REQ-CAPTURE-014).
   On the model path only, `ModelDraftMapper.isHedged` adds English future and
   planning wording ("will", "I'll", "going to", "have to", "plan", "book",
   "tomorrow", "next week", and similar). The shipped rules keep their ADR 0011
   list, so "did the scheduled brake fluid change at 60000" is still read as
   done work by the rules.
4. Otherwise a fresh `LanguageModelSession` with English instructions and the
   locale phrase generates a `CaptureDraftSchema`: `reportsCompletedAction`,
   `kind` (maintenance completion, car wash, odometer reading, other),
   `operation` (the seven catalog operations, `several`, `noOperation`),
   `odometerKm`, `amount`. Greedy sampling, at most 120 response tokens.
   Generation errors are rethrown as `generationFailed`.
5. `ModelDraftMapper` (domain, model-agnostic) turns the draft into a proposal
   under guards that can only remove meaning:
   - hedged wording → `nil` (again, for any other drafter);
   - `reportsCompletedAction == false` → `nil` for work and washing;
   - a completion needs exactly one catalog operation, else `nil`;
   - every number must be written in the capture (`GroundedNumbers`: grouped
     digits, "85k", and the Russian and Ukrainian words for "thousand"); an ungrounded mileage or price is dropped, and a
     reading without a grounded number is `nil`;
   - mileage must be plausible and at least 100; a price equal to the mileage,
     or to any number written as a mileage (after "at", "на", a mileage word,
     or before a distance unit), is dropped, so presence alone never makes a
     number a price;
   - `rawText` and `sourceInputID` are the input's, so the validator's source
     check still applies;
   - confidence is a fixed 0.5, below `ConfirmationPolicy`'s 0.8 floor, so a
     model-proposed odometer reading is confirmed, never auto-accepted. The
     policy already confirms completions and events (REQ-CAPTURE-016).

The model never picks the outcome or the command (core P3); the validator,
`ConfirmationPolicy` and domain commands are unchanged (REQ-CAPTURE-015, 021).
Screen context is not passed to the model (REQ-CAPTURE-022).

### Composition and order

`InterpreterChain` asks interpreters in order and returns the first proposal.
The composition is **rules first, then Foundation Models**:

- the rules are deterministic, instant, and the only path that understands
  Russian and Ukrainian, which the model rejects;
- a later member cannot override an earlier answer, so the model can only add
  recall where the rules found nothing;
- the whole chain still runs inside the one `InterpretationDeadline` of 6
  seconds (ADR 0015); the rules cost nothing, so the model keeps the full budget.

Model-first was rejected: it would add model latency to every capture and let a
non-deterministic answer replace a deterministic one for exactly the phrasings
the rules were built to be sure about.

### Feature flag

`InterpreterComposition` in `AppEnvironment` selects the interpreters. The
default everywhere is `.ruleBased` (unchanged behaviour). Only a DEBUG launch
argument, `-pitstop-foundation-models`, selects the chain. Release builds
cannot turn it on. Turning it on in Release is an owner decision (see "Rollout
gate").

### Telemetry

`input_interpretation_completed` already carries `interpreter_version`,
`availability`, `result` and `latency_bucket` (ADR 0021), all closed values
without raw text (REQ-CAPTURE-025). The chain reports a new closed value,
`rule_based_1_foundation_models_1`, and only in the DEBUG composition; Release
keeps `rule_based_1`. **Proposed for owner review:**

- accept that value into the taxonomy before any Release use;
- report which member answered per capture (a stage field such as
  `interpreterMember`), because the composition-level version cannot tell a
  rule answer from a model answer;
- report a closed unavailability reason (`unsupported_language`,
  `model_unavailable`, `generation_failed`) so the `error` result in ADR 0021
  becomes observable.

## Evaluation

Golden set: `PitstopTests/Capture/Evaluation/CaptureGoldenSet.swift`, 48
fictional captures (19 positive, 6 ambiguous, 6 unsupported, 3 correction, 14
hedged; 29 ru, 14 en, 5 uk). The correct answer for every non-positive case is
"no proposal". Harness: `InterpreterEvaluation` scores precision and recall per
kind (a wrong field counts as both a false positive and a false negative),
correctness per category, unexpected proposals, and latency buckets.

The deterministic lane (`just verify`) runs the golden set against the rules and
asserts that no work or event is proposed where the wording must stay raw. The model lane runs only with
`TEST_RUNNER_PITSTOP_AI_EVAL=1` and when the model is available; reports are
result-bundle attachments.

Results, session simulator, 2026-09-21:

| Interpreter | Completion P / R | Reading P / R | Car wash P / R | Unexpected proposals | Unavailable |
|---|---|---|---|---|---|
| `rule_based_1` | 100% (8/8) / 80% (8/10) | 57% (4/7) / 100% (4/4) | 100% (3/3) / 60% (3/5) | 2 (readings) | 0 |
| Foundation Models alone | n/a (0 proposals) | n/a | n/a | 0 | 40 of 48 |
| Rules, then Foundation Models | same as rules | same as rules | same as rules | 2 (the rules' readings) | 24 of 48 |

- **Model quality: not measured.** Russian and Ukrainian captures were rejected
  as unsupported, as the probe predicted. All four English positive captures
  reached generation and failed on the simulator with a `LanguageModelError`
  whose underlying errors are `com.apple.SensitiveContentAnalysisML` error 15
  and `ModelManagerServices.ModelManagerError` 1001: the input safety
  classifier's assets were not usable on the simulator. One short English
  reading ("Odometer reads 45,600 km") was detected below 0.6 confidence and
  never sent. Hedged English captures never reached the model.
- **Latency: not measured.** Every call ended in under 250 ms because none
  generated.
- Rules false positives (pre-existing, rules unchanged by CAP-005): English
  plans that name a mileage ("Going to change the oil at 90000 km", "Planning
  to replace the cabin filter at 95000 km") become odometer readings with no
  confidence, which the policy auto-accepts. No work or event is proposed, so
  REQ-CAPTURE-014 holds, but a planned mileage is recorded as the current one.
  Fixing it changes the ADR 0011 rules and is an owner item.
- Rules misses: a Russian report of an all-wheel-drive coupling service,
  stated with its mileage in kilometres, becomes an odometer reading with the
  right number (the rules have no completion verb for "serviced"); Ukrainian
  past-tense verbs for "replaced" and "washed", and a Russian wash phrased as
  "went to the car wash, paid 900" without a washing verb, are not recognised.

## Safety guards (summary)

Hedge rule plus English future and planning words before and after the model; unknown language never sent; the model's own tense flag only
suppresses; catalog-only operations; one operation per completion; grounded
numbers; plausible mileage; confidence below the auto-accept floor; throws on
unavailability, unsupported language and generation failure; long input
skipped; cancellation propagates; the chain cannot override a rule answer;
validator, policy and commands unchanged; no raw text in any event.

## Rejected alternatives

- **A cloud LLM** (Private Cloud Compute, a third-party API). It sends the
  user's words off the device, needs consent and privacy-manifest changes, and
  adds a network dependency to a capture that must work offline (core P1).
  `PrivateCloudComputeLanguageModel` is new in iOS 27 and outside this spike.
- **Model-only decisions** (letting the model choose the outcome, confidence or
  command). Core P3: AI proposes, the deterministic system decides.
- **Trusting the model's hedge detection.** A missed intention would record
  work that was never done; the deterministic rule is cheap and already tested.
- **Model first, rules as fallback.** See "Composition and order".
- **Translating Russian input to English before prompting.** Not evaluated. It
  would add a second model (and its language download) inside the same
  deadline, and a translation error would become a structured fact about the
  user's car.

## Rollout gate for the owner

The flag stays off in Release until all of these hold:

1. On a physical Apple Intelligence device, the model lane runs the golden set
   with generation succeeding, and reports precision of at least 95% per kind,
   zero unexpected proposals, and p90 latency under 3 seconds.
2. Apple Intelligence supports a language the owner's users write in; today it
   does not support Russian or Ukrainian, so for the current audience the model
   adds nothing and the rules remain the interpreter.
3. The owner accepts the telemetry value and the per-member reporting above.
4. The golden set grows from observed (redacted) failures per the test
   strategy.

## Open for owner review

- Whether CAP-005 is closed as "investigated; model unusable for ru/uk on iOS
  27" or kept open for a device evaluation of English captures.
- The rules' English plan-with-mileage false positive above: whether to add
  future and planning words to the shipped rules, at the cost of completions
  such as "did the scheduled brake fluid change at 60000", which the rules must
  keep reading as done.
- Extending the rules to Ukrainian completion and washing verbs and hedge
  words (the Ukrainian "need to" is not a hedge word today); this would change
  the ADR 0011 rule scope, which CAP-005 leaves unchanged.
- The proposed telemetry value and fields.
