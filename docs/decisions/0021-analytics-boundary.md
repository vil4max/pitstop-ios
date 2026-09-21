# Analytics Boundary

**Status:** Accepted for implementation (agent decision under owner delegation,
2026-09-21); owner review pending\
**Task:** ENG-002\
**Contracts:** [`0002-analytics-service.md`](0002-analytics-service.md),
[`0003-logging.md`](0003-logging.md),
[`0006-capture-confirmation-policy.md`](0006-capture-confirmation-policy.md),
[`../operations/analytics.md`](../operations/analytics.md),
[`../operations/analytics-questions.md`](../operations/analytics-questions.md),
[`../operations/telemetry-contract.md`](../operations/telemetry-contract.md),
core P2 and C4

## Context

ADR 0002 selects PostHog as the beta candidate and fixes the architecture
boundary: feature code never imports a provider, each feature owns a typed
event, and a provider-neutral layer owns the encoded event, `AnalyticsClient`,
a no-op client, and a recording client for tests. `ANL-001` is the PostHog
vertical slice; it adds a package, which needs owner approval.

ENG-002 builds that boundary first, without an SDK, a network call, or a new
dependency, so `ANL-001` becomes one adapter behind an interface that already
has events flowing through it.

Two inputs constrain the design:

- The capture pipeline already reports `CaptureStageEvent` values that carry
  only a correlation ID and closed enums (ADR 0006, REQ-CAPTURE-025). Product
  events for Remember can be derived from those stages, so raw capture text
  never needs to reach analytics code at all.
- The analytics documents define no consent model. The privacy contract lists
  what may never be sent, but nothing says whether collection is on by
  default or how a user opts in.

## Decision

### Layers

```text
Feature view model / CaptureAnalyticsObserver
    ↓ AnalyticsTracking<FeatureEvent>      (typed, feature-owned event)
AnalyticsTracker<FeatureEvent>
    ↓ AnalyticsClient                       (AnalyticsEvent: name + closed values)
ConsentGatedAnalyticsClient
    ↓ AnalyticsClient
NoAnalyticsClient | LoggingAnalyticsClient (DEBUG) | provider adapter (ANL-001)
```

- `AnalyticsTracking<Event>` is the protocol a feature depends on, injected
  through its initializer with a no-op default. A feature sees only its own
  event type: `NotesAnalyticsEvent`, `OdometerAnalyticsEvent`,
  `CaptureAnalyticsEvent`. There is no app-wide analytics type that conforms
  to every feature protocol (ADR 0002, "Module rule").
- `AnalyticsClient.send(_:)` is the provider boundary. The provider adapter
  from `ANL-001` implements it; nothing else changes.
- The code lives in the app target: `Pitstop/Infrastructure/Analytics/` for the
  neutral layer and one `*Analytics.swift` file next to each feature for its
  events. No package is extracted (ADR 0002, `modular-architecture.md`).

### Event catalog rules

- Event and parameter names are enum cases (`AnalyticsEventName`,
  `AnalyticsProperty`) whose raw values are the snake_case names of
  `analytics.md`. Feature code refers to cases, never to strings.
- `AnalyticsValue` has two initializers: from a `Bool`, and from a case of an
  `AnalyticsCategory` (a `CaseIterable` string enum). There is no initializer
  from a string, a number, a date, or a dictionary, so raw capture text, note
  wording, names, VINs, amounts, and exact mileage cannot be sent by
  construction, and the cardinality of every property is known before release.
- Analytics enums spell values independently of the domain enums they map
  from (`CaptureIntent` for `ProposalKind`, `AnalyticsNoteContext` for
  `NoteContext`). Each mapping is an exhaustive switch, so a new domain case is
  a compile error until someone decides how it is reported.
- A parameter the code cannot know is omitted, not guessed.
- Only events listed in `analytics.md` are implemented. Events for shipped
  features that the taxonomy lacks are recorded there as `REVIEW` proposals
  and are not collected (`analytics-questions.md`: an event without an `AQ-*`
  owner is not collected).

### Consent default

No consent state is defined by the analytics documents, so the default is
**off**: `ConsentGatedAnalyticsClient` forwards an event only when consent is
`granted`, and `notAsked` counts as no. Consent is read on every event, so a
future setting can change it without rebuilding the trackers.

The production composition is a consent-gated `NoAnalyticsClient` with
consent `notAsked`: nothing is collected and nothing leaves the device. The
App Privacy answers and the privacy manifest do not change.

A DEBUG launch argument, `-pitstop-analytics-log`, composes the gate with
`granted` consent and `LoggingAnalyticsClient`, which writes each event to the
`analytics` OSLog category. It persists and transmits nothing (ADR 0003) and
exists so a developer can watch the funnel on a simulator.

### Events wired

| Event | Emitted by | Notes |
| --- | --- | --- |
| `input_interpretation_completed` | `CaptureAnalyticsObserver` on `interpretation_completed` | `result`: `draft` for a typed proposal, `fallback` for no meaning, `unsupported` for `unknown`; `latency_bucket` from `interpretation_started` on a monotonic clock, omitted when the start was not observed; `interpreter_version` and `availability` from the composition (`rule_based_1` for Pit) |
| `draft_saved` | observer on `mutation_completed` of a non-raw proposal the user was shown | `edited` is true when the user supplied a missing field through clarification; the confirmation surface has no other editing |
| `draft_cancelled` | observer on `capture_discarded` after a proposal was shown, or on a raw save after a shown proposal (declined meaning, "I don't know" to a clarification, or an answered draft that could only be kept as wording) | `stage`: `preview` after confirmation was required, `edit` after clarification |
| `note_created` | observer on `mutation_completed` of `rawNote` or `contextualNote` | Covers Pit and the Notes editor, which both use the pipeline (core C4). `context_count_bucket` is `0` for a raw note and omitted for a contextual note, because the stage does not carry the context set |
| `note_context_opened` | `NotesViewModel.select(context:)` when a context filter is opened on the active list | `active_note_count_bucket` counts active notes in that context; filtering the archive is not reported |
| `note_archived` | `NotesViewModel.setStatus(.archived, …)` after the write succeeds | `source_context` is the filter the note was archived from; restoring is not reported |
| `odometer_updated` | observer for captured readings; `CarBoardViewModel.saveCar` and `PitQuestionViewModel.answer` after the reading is written | Capture sources map to `natural` or `siri`, typed entries to `explicit`. A captured reading that stopped for confirmation reports `anomaly_confirmation = accepted`: ADR 0006 asks for confirmation only on a conflict or low confidence, and the stage does not say which |

**Draft rule.** A draft is a proposal the user saw: a confirmation or a
clarification was shown. Only drafts produce `draft_saved` or
`draft_cancelled`, so `draft_save_rate` and `draft_cancel_rate` in AQ-004
share one denominator, and every shown draft ends in exactly one of them
unless the capture is abandoned without a terminal stage. An auto-accepted
interpreted proposal was never shown; it is not a draft event, and its fact
events (`note_created`, `odometer_updated`) still fire. Its share is visible as
`input_interpretation_completed` with `result = draft` minus shown drafts.

The observer joins stages by correlation ID. It keeps state only for captures
in progress, keeps it after `pipeline_failed` (the surface lets the user retry
the same capture), drops it on `mutation_completed` or `capture_discarded`, and
holds at most 16 unfinished captures, dropping the oldest. Only
`capture_received` creates a journey; later stages update an existing one, so
an evicted capture cannot come back outside the bound, and its remaining
stages report no draft event and no latency. It runs next to
`CaptureStageLogger` through `CaptureStageObservers`, a fan-out observer, so
neither knows about the other.

### Registry events not wired yet

| Event | Why not now |
| --- | --- |
| `car_context_first_enriched` | Needs an onboarding start moment for `duration_bucket` and a definition of "first enriched" for the provisional car; no onboarding flow exists |
| `history_event_created` | Its `kind` is a `HistoryEventKind`, which a capture stage does not carry; wiring only the History editor would undercount captured events. Needs either a proposal-kind-level parameter or a stage field (owner question 3) |
| `maintenance_status_viewed`, `service_scope_viewed`, `service_plan_edited` | Service Plans are not implemented; status viewing is ready to wire but was kept out to keep the slice reviewable |

## Tests

`PitstopTests/Analytics/`, tagged `ADR-0002` or `ADR-0021`:

- `AnalyticsBoundaryTests`: every typed event case carries only `Bool` and
  `AnalyticsCategory` values (reflection, like the `CaptureStageEvent` test);
  every encoded value is a declared case; event and parameter names match the
  taxonomy and are snake_case; the sample catalog covers every event name;
  `notAsked` and `declined` consent record nothing; `granted` forwards the
  event unchanged; bucket edges.
- `CaptureAnalyticsMappingTests`: stage sequences for a raw note, a
  contextual note, an auto-accepted reading (no draft event), a confirmed
  reading (`accepted` anomaly), a fallback, a cancelled preview, a declined
  draft, a clarified draft, a retry after a failed write, blank input, and
  eviction (later stages of an evicted capture re-create nothing and report
  no latency).
- `CaptureAnalyticsEndToEndTests`: the Pit view model with the real pipeline
  and rule-based interpreter reports interpretation and a saved draft for a
  confirmed capture, with no raw content in any event; the same capture with
  consent not asked records nothing; "I don't know" to a shown clarification
  ends the draft as cancelled and creates a note; a note from the Notes editor
  is `note_created` from the explicit source.
- `FeatureAnalyticsTests`: context opened and archive from Notes; a context
  filter on the archive is not `note_context_opened`; restore is not an
  archive; a car-editor reading and a mileage-question answer are
  `odometer_updated` from the explicit source.

The test spy is `RecordingAnalyticsClient` in `PitstopTests/Support/`.

## Rejected alternatives

- **Add the PostHog SDK now.** It is a new dependency, which needs owner
  approval, and it is `ANL-001`'s job to measure launch impact, offline
  behaviour, and privacy-manifest implications. Doing both at once would make
  the boundary untestable without the SDK.
- **A free-form `track(name: String, properties: [String: Any])`.** It is the
  escape hatch ADR 0002 and ADR 0003 forbid and cannot prove that raw content
  stays out.
- **Pass raw capture data to the analytics observer and filter it there.** The
  stage event already excludes raw content by type; filtering would move the
  guarantee from construction to review.
- **Extend `CaptureStageEvent` with note contexts and history kinds.** It would
  change the ADR 0006 observability contract for two parameters; left as owner
  question 3.
- **One `AppAnalytics` type conforming to every feature protocol.** Rejected by
  ADR 0002.
- **Consent on by default for TestFlight builds.** No document or owner
  decision grants it; defaulting off is reversible, defaulting on is not.
- **Store consent in `UserDefaults` now.** There is no surface to ask the user
  and nothing is sent, so a stored value would have no writer.

## Open questions for owner review

1. **Consent model.** Should the beta ask for analytics opt-in (where: first
   launch, Settings, both), or does the TestFlight tester agreement count as
   consent for invited testers? Recommended: an explicit toggle in Settings,
   off by default, plus a one-time ask during the beta; no collection before
   an answer.
2. **Proposed events.** `analytics.md` now lists `REVIEW` proposals for shipped
   features (Pit question lifecycle, Car Board tile opens). Each needs an
   `AQ-*` owner or an approved investigation before it is collected.
3. **Capture detail for history and contexts.** Allow `CaptureStageEvent` to
   carry the proposed `HistoryEventKind` and a note-context count bucket (both
   closed types), so `history_event_created` and `note_created` can be complete
   for captured facts? Recommended: yes, as an ADR 0006 amendment.
4. **`interpretation_completed.result = error`.** The pipeline turns a throwing
   or late interpreter into "no meaning" before reporting, so `error` is never
   emitted and such captures count as `fallback`. Keep, or add a stage reason?
5. **`anomaly_confirmation` precision.** A confirmed captured reading reports
   `accepted` whether the confirmation was for a lower reading or for low
   confidence. Acceptable for the beta, or should the stage carry the reason?
