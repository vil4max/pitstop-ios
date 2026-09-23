# System Overview (As Built)

**Status:** Descriptive snapshot of `main`, verified against the code on
2026-09-22. It records what is implemented, not what is required.\
**Owners it summarises:** behaviour contracts live in
[`../requirements/`](../requirements/), decisions in
[`../decisions/`](../decisions/), the implementation inventory in
[`domain-inventory.md`](domain-inventory.md). When this page and an owner
disagree, the owner and the code win; fix this page in the same change.

This page is one file on purpose. It is a map with diagrams that points into
the owning documents; splitting it into a `docs/spec/` folder would create a
second specification tree next to `requirements/` and `decisions/`, which the
documentation rule in [`../README.md`](../README.md) forbids. Every diagram is
Mermaid, which GitHub renders in place.

Contents:

1. [System context](#1-system-context)
2. [Modules and layers](#2-modules-and-layers)
3. [Capture pipeline](#3-capture-pipeline)
4. [Entry points](#4-entry-points)
5. [Pit motion states](#5-pit-motion-states)
6. [Pit question lifecycle](#6-pit-question-lifecycle)
7. [Data model](#7-data-model)
8. [Maintenance and Road projections](#8-maintenance-and-road-projections)
9. [Delivery pipeline](#9-delivery-pipeline)
10. [Feature matrix](#10-feature-matrix)

All examples are fictional.

---

## 1. System context

```mermaid
flowchart LR
    user(["Driver"])

    subgraph phone["iPhone, iOS 27"]
        subgraph app["PitStop app process"]
            ui["SwiftUI app: Car Board, Notes, Service, History, Road, Settings, Pit sheet"]
            intents["App Intents: RememberInPitStopIntent, OpenPitIntent, PitStopShortcuts"]
            store[("SwiftData store Pitstop.store in the App Group container, schema V4")]
            analytics["Analytics boundary: consent gate, PostHog HTTP adapter"]
            fm["Foundation Models interpreter, DEBUG launch argument only"]
        end
        subgraph ext["PitstopWidgets extension"]
            widget["CaptureWidget, data-free"]
            nextService["NextServiceWidget, reads the store read-only"]
            control["OpenPitControl, Control Center and Lock Screen"]
        end
        siri["Siri, Shortcuts, Spotlight"]
        model["On-device system language model"]
    end

    posthog[("PostHog project, not configured")]
    subgraph delivery["Delivery"]
        gha["GitHub Actions: tests on push to main"]
        xcc["Xcode Cloud: archive of testflight branch"]
        tf["TestFlight group Internal"]
    end

    user --> ui
    user --> siri
    user --> widget
    user --> nextService
    user --> control
    siri --> intents
    intents --> store
    ui --> store
    widget -- "pitstop://pit" --> ui
    nextService -- "pitstop://service" --> ui
    nextService -. "read-only" .-> store
    ui -. "reloadTimelines after a saved command" .-> nextService
    control -- "OpenPitIntent" --> ui
    ui --> fm
    intents --> fm
    fm -.-> model
    ui --> analytics
    intents --> analytics
    analytics -. "only with a project key and user opt-in" .-> posthog
    gha --> xcc --> tf --> user
```

One process owns all car data. `PitstopApp` builds a single `AppEnvironment`
and registers the same `RememberIntentHandler` and `CaptureSurfaceRequests`
with `AppDependencyManager`, so a Siri save and the Pit sheet write to the
same SwiftData file ([`Pitstop/App/PitstopApp.swift`](../../Pitstop/App/PitstopApp.swift),
[ADR 0007](../decisions/0007-persistence.md), [ADR 0023](../decisions/0023-remember-intent.md)).
The store lives in the App Group container `group.dev.vil4max.pitstop`, moved
there once at launch from the app's own container. The widget extension's
capture widget and control are data-free and only open the Pit sheet
([ADR 0025](../decisions/0025-widgets-and-controls.md)); its next-service
widget opens the store read-only, runs the same maintenance engine as Service,
and opens Service through `pitstop://service`. The app remains the only writer
and asks WidgetKit to reload that widget after every saved command
([ADR 0036](../decisions/0036-app-group-store-and-next-service-widget.md)). Analytics leaves the
device only when the build carries `PostHogProjectAPIKey` and `PostHogHost`
and the user opted in under Settings; the repository ships no key, so the
gated no-op client is what runs ([ADR 0021](../decisions/0021-analytics-boundary.md),
[ADR 0022](../decisions/0022-posthog-http-adapter.md)). Foundation Models is
compiled in but composed only when a DEBUG build is launched with
`-pitstop-foundation-models` ([`InterpreterComposition.swift`](../../Pitstop/App/InterpreterComposition.swift),
[ADR 0027](../decisions/0027-foundation-models-interpreter.md)). Delivery is
outside the device: GitHub Actions only tests, Xcode Cloud only archives the
`testflight` branch ([ADR 0013](../decisions/0013-shared-ci-and-tag-gated-testflight.md)).

---

## 2. Modules and layers

```mermaid
flowchart TB
    subgraph appL["App (composition root)"]
        env["AppEnvironment"]
        coord["AppCoordinator"]
        root["RootView"]
        appIntents["Intents: RememberInPitStopIntent, PitStopShortcuts"]
        comp["InterpreterComposition, DemoData"]
    end

    subgraph featL["Features (MVVM)"]
        fCar["CarBoard"]
        fNotes["Notes"]
        fHist["History"]
        fServ["Service"]
        fRoad["Road"]
        fPit["Pit"]
        fSet["Settings"]
        fSys["SystemCapture"]
        fShared["Shared: FeatureScaffold, SaveSheetScaffold, FeatureFormat, ProgressText, PersistenceMode, InputParsing, WholeNumberInput, OdometerAnalytics"]
    end

    subgraph ds["DesignSystem"]
        dsC["PitEyesGlyph, UtilityLayer, TileCard, ScreenHeader, LoadFailureBanner, PitColor, DesignTokens"]
    end

    subgraph domL["Domain (Foundation and Synchronization only)"]
        dCap["Capture"]
        dMnt["Maintenance"]
        dRoad["Road"]
        dHist["History"]
        dNotes["Notes"]
        dPit["Pit"]
        dVeh["Vehicle"]
        dStore["Store protocols: CarMemoryStore"]
    end

    subgraph infL["Infrastructure (adapters)"]
        iPers["Persistence: SchemaV1 to SchemaV3 frozen, SchemaV4, stores"]
        iAna["Analytics: consent, PostHog, transport"]
        iInt["Interpretation: FoundationModelsInterpreter"]
        iLog["Logging: AppLog, CaptureStageLogger"]
    end

    subgraph sharedL["Shared (app and widget targets)"]
        sh["AppLink, CaptureSurface, CaptureSurfaceRequests, OpenPitIntent, NextServiceContent"]
    end

    subgraph wid["PitstopWidgets target"]
        w["PitstopWidgetsBundle, CaptureWidget, NextServiceWidget, OpenPitControl"]
    end

    appL --> featL
    appL --> infL
    appL --> domL
    appL --> sharedL
    featL --> domL
    featL --> ds
    featL --> infL
    ds --> domL
    infL --> domL
    wid --> sharedL
    wid -. "membership: maintenance domain, schemas, read-only reader" .-> domL
```

The app is one Xcode target whose folders act as layers; there are no Swift
packages yet (the package split in [`modular-architecture.md`](modular-architecture.md)
is a target direction). Domain files import only `Foundation` and
`Synchronization`, so SwiftUI, SwiftData, OSLog, PostHog and Foundation Models
stay out of it. Infrastructure implements Domain protocols
(`CarMemoryStore`, `PitQuestionStateStore`, `SemanticInterpreting`,
`CaptureStageObserving`) and depends on nothing above it. Features depend on
Domain, the DesignSystem, and the analytics protocols; the DesignSystem depends
on Domain only for `PitState` and `PitActivity`. No feature reads an App-layer
type: the persistence mode and the mileage and amount parsers live in
`Features/Shared` (ARCH-001). A few features still name another feature's
non-view-model types (see [Mismatches](#mismatches-found-while-writing-this-page)).
`Shared/` is a
folder compiled into both the app and the widget extension
(`Pitstop.xcodeproj/project.xcproj`), which is how the control reaches
`OpenPitIntent` and the "Remember" widget reaches the design roles in
`Shared/DesignSystem/` (`PitColor`, `PitTypography`, `DesignTokens`, `GlyphDisc`; RD-009). The extension also compiles a named set of domain and
persistence files through membership exceptions (ADR 0036). Folder roots: [`Pitstop/Domain`](../../Pitstop/Domain),
[`Pitstop/Infrastructure`](../../Pitstop/Infrastructure),
[`Pitstop/Features`](../../Pitstop/Features), [`Pitstop/App`](../../Pitstop/App),
[`Pitstop/DesignSystem`](../../Pitstop/DesignSystem), [`Shared`](../../Shared),
[`PitstopWidgets`](../../PitstopWidgets).

---

## 3. Capture pipeline

```mermaid
sequenceDiagram
    autonumber
    participant S as Surface: Pit sheet, Siri handler, Notes
    participant P as RememberPipeline
    participant O as CaptureStageObservers
    participant D as InterpretationDeadline 6 s
    participant I as InterpreterChain: rules, then optional model
    participant V as ProposalValidator
    participant C as ConfirmationPolicy
    participant M as DomainCommandMapper
    participant St as CarMemoryStore

    S->>P: remember(CaptureInput, mode)
    P->>O: capture_received
    alt blank input
        P->>O: capture_discarded
        P-->>S: nothingToSave
    else raw mode
        P->>P: RawProposalFactory builds rawNote
    else interpreted mode
        P->>O: interpretation_started
        P->>D: run(interpreter.interpret)
        D->>I: interpret(input)
        I-->>D: proposal or nil or error
        D-->>P: finished, timedOut, or thrown
        opt calling task cancelled
            P->>O: capture_discarded
            P-->>S: nothingToSave, no store access
        end
        P->>O: interpretation_completed with kind or none
        opt no meaning, timeout, or interpreter error
            P->>P: fall back to rawNote, degraded
        end
    end
    P->>St: currentVehicle, latest odometer reading
    P->>V: validate(proposal, input, context)
    V-->>P: valid, incomplete, preserveRaw, or empty
    P->>C: outcome(validation)
    P->>O: proposal_validated with outcome
    alt valid and autoAcceptSafe
        C-->>P: MutationPermit autoAccepted
    else valid and confirmCompact
        P->>O: confirmation_required
        P-->>S: needsConfirmation(PendingCapture)
        S->>P: confirm, preserveRaw, or cancel
    else incomplete
        P->>O: clarification_required
        P-->>S: needsClarification, one field
        S->>P: answer(field) or answer(unknown) or cancel
    else preserveRaw
        P->>P: save wording as rawNote
    end
    opt cancelled before the write
        P->>O: capture_discarded
        P-->>S: nothingToSave
    end
    P->>M: command(permit, now)
    P->>O: domain_command_created
    M-->>P: DomainCommand, validated again
    P->>St: execute(command, now)
    alt stored
        St-->>P: CommandResult
        P->>O: mutation_completed, then raw_preserved if degraded
        P-->>S: saved(result, preservedRaw)
    else duplicate record
        P-->>S: RememberError.alreadySaved
    else storage failure
        P->>O: pipeline_failed
        P-->>S: RememberError.notSaved, input kept for retry
    end
```

Every capture source goes through one `RememberPipeline`
([`RememberPipeline.swift`](../../Pitstop/Domain/Capture/RememberPipeline.swift),
[ADR 0011](../decisions/0011-interpreted-capture-without-a-model.md)). Raw
mode never calls an interpreter. Interpreted mode races the interpreter against
`InterpretationDeadline.standard` (6 s) and never awaits the loser; a timeout,
a thrown error, or "no meaning" all fall back to saving the wording raw and
report `raw_preserved` only after the write succeeds
([`InterpretationDeadline.swift`](../../Pitstop/Domain/Capture/InterpretationDeadline.swift),
[ADR 0015](../decisions/0015-interpretation-deadline-and-cancellation.md)).
The app composes `RuleBasedInterpreter` alone, or in a DEBUG launch
`InterpreterChain([RuleBasedInterpreter(), FoundationModelsInterpreter()])`, so
the model can only add meaning the rules did not find
([ADR 0027](../decisions/0027-foundation-models-interpreter.md)). The
validator is pure and is the only producer of `ValidatedProposal`; the
`ConfirmationPolicy` is the only producer of a `MutationPermit`, and the mapper
accepts nothing else, so no path writes around the policy
([`ConfirmationPolicy.swift`](../../Pitstop/Domain/Capture/ConfirmationPolicy.swift),
[ADR 0006](../decisions/0006-capture-confirmation-policy.md)). Notes and
confident odometer readings or low-risk vehicle facts are auto-accepted;
maintenance completions, policies, events, expenses, anything with a conflict
(a reading below the latest, a replaced fact) and anything below confidence
0.8 need confirmation. Clarification asks one missing field at a time, and
"I don't know" saves the wording. Cancellation is checked after
interpretation and again at the last point before a write. Stage telemetry
(`CaptureStageEvent`) carries only the correlation ID, stage, source, kind and
outcome, never the words, and fans out to `CaptureStageLogger` and
`CaptureAnalyticsObserver` ([`CaptureStageEvent.swift`](../../Pitstop/Domain/Capture/CaptureStageEvent.swift),
[`AppCoordinator.swift`](../../Pitstop/App/AppCoordinator.swift)).
`capture_discarded` is still a proposed stage pending owner approval
(ADR 0006, ADR 0015).

---

## 4. Entry points

```mermaid
flowchart LR
    tap(["Tap Pit in the utility layer"])
    siriR(["Siri or Shortcuts: Remember in PitStop"])
    openS(["Siri, Shortcuts, Spotlight: Open Pit in PitStop"])
    ctrl(["Control Center, Lock Screen, Action button: Open Pit control"])
    wdg(["Home or Lock Screen widget"])
    ext(["Any pitstop:// link"])
    notesAdd(["Notes: add note"])

    rememberIntent["RememberInPitStopIntent: background, unlocked phone, source siri"]
    handler["RememberIntentHandler"]
    prompts["requestChoice for confirm or clarify, requestValue for a number, one repeat"]
    openIntent["OpenPitIntent: OpenIntent, foreground immediate"]
    url["onOpenURL at scene root"]
    parse{"exactly pitstop://pit?"}
    ignored["logged and ignored"]
    requests["CaptureSurfaceRequests.isPending = true"]
    gate{"feature editor or modal task open?"}
    wait["request stays pending"]
    sheet["RootView presents Pit sheet"]
    pitVM["PitCaptureViewModel: source pitText, visibleFeature prior"]
    notesVM["NotesViewModel.add: source directApp, raw"]
    temp{"store durable?"}
    refused["reply: storage unavailable, nothing written"]
    pipeline[["RememberPipeline"]]

    tap --> sheet
    siriR --> rememberIntent --> handler --> temp
    temp -- no --> refused
    temp -- yes --> pipeline
    handler <--> prompts
    openS --> openIntent
    ctrl --> openIntent
    openIntent --> requests
    wdg --> url
    ext --> url
    url --> parse
    parse -- no --> ignored
    parse -- yes --> requests
    requests --> gate
    gate -- yes --> wait
    wait -- "editor closes" --> gate
    gate -- no --> sheet
    sheet --> pitVM --> pipeline
    notesAdd --> notesVM --> pipeline
```

There are two kinds of external entry. **Remember** runs the capture in place
without opening the app: `RememberInPitStopIntent` asks Siri for the words,
refuses when the session store is temporary, and hands the text to
`RememberIntentHandler`, which builds a `CaptureInput` with source `.siri` and
drives the same pipeline, asking at most one question at a time
([`RememberIntentHandler.swift`](../../Pitstop/Features/SystemCapture/RememberIntentHandler.swift),
[ADR 0023](../decisions/0023-remember-intent.md),
[ADR 0026](../decisions/0026-siri-voice-clarification.md)). A spoken mileage
or amount is parsed, asked once more if unreadable, and always confirmed before
it is written; an operation or event kind is a choice from the catalog; a
vehicle fact or interval can only be kept as words. **Open Pit** never
captures by itself: `OpenPitIntent` (Shortcuts, Spotlight, and the control)
and the widget's `pitstop://pit` link only set `CaptureSurfaceRequests`, and
`RootView` presents the Pit sheet when no feature editor blocks it, so a
request during a cold launch or under an open editor is deferred, not lost
([`CaptureSurfaceRequests.swift`](../../Shared/CaptureSurfaceRequests.swift),
[`CaptureSurface.swift`](../../Shared/CaptureSurface.swift),
[ADR 0024](../decisions/0024-app-shortcuts.md), ADR 0025). The URL parser
rejects any path, query, fragment, user or port. Inside the app, the Pit sheet
and adding a note are also capture sources (`.pitText`, `.directApp`); the car
editor, Service actions and History editor write through `DomainCommand`s
directly because they are forms, not captures.

---

## 5. Pit motion states

```mermaid
stateDiagram-v2
    state "Utility layer: PitPresenceModel" as Utility {
        state "resting" as u_rest
        state "blink" as u_blink
        state "look left, right, up" as u_look
        state "startle 0.35 s" as u_startle
        state "knock, two bumps" as u_knock
        state "closed eyes 0.7 s" as u_closed

        [*] --> u_rest
        u_rest --> u_blink : idle scheduler draws blink or double blink
        u_blink --> u_rest : after 0.14 s
        u_rest --> u_look : idle scheduler draws a look
        u_look --> u_rest : after 0.9 s
        u_rest --> u_startle : question chosen, motion allowed
        u_rest --> u_knock : question chosen, Reduce Motion
        u_startle --> u_knock
        u_knock --> u_rest : question answered, deferred, dismissed or gone quiet
        u_rest --> u_closed : Pit sheet closed, no question pending
        u_closed --> u_rest : latest leave only
    }

    state "Pit sheet: PitCaptureEyes" as Sheet {
        state "fixed gaze, listening" as s_fixed
        state "listening blink" as s_lblink
        state "knock, own question" as s_ask
        state "blink after input" as s_blink
        state "side gaze, thinking 0.6 s min" as s_side
        state "knock, proposal" as s_prop
        state "glance at result 0.6 s" as s_glance
        state "closed eyes 0.7 s" as s_closed
        state "resting" as s_rest

        [*] --> s_fixed : composing
        [*] --> s_ask : composing while a question waits
        s_fixed --> s_lblink : listening scheduler, weight 0.22
        s_lblink --> s_fixed
        s_fixed --> s_blink : submit, motion allowed
        s_ask --> s_blink : submit, motion allowed
        s_fixed --> s_side : submit, Reduce Motion
        s_ask --> s_side : submit, Reduce Motion
        s_blink --> s_side
        s_side --> s_prop : confirmation or clarification
        s_side --> s_glance : saved, motion allowed
        s_side --> s_closed : saved, Reduce Motion
        s_prop --> s_side : answer submitted
        s_prop --> s_glance : saved, motion allowed
        s_glance --> s_closed
        s_closed --> s_rest
        s_prop --> s_fixed : back to composing
        s_rest --> s_fixed : new capture
    }
```

Pit's eyes have two independent players that render one `PitState` each
([`PitPresence.swift`](../../Pitstop/Domain/Pit/PitPresence.swift),
[ADR 0012](../decisions/0012-pit-presence-and-attention.md),
[ADR 0019](../decisions/0019-pit-activity-reporting.md),
[ADR 0028](../decisions/0028-pit-eyes-and-motion.md)). In the utility layer,
`PitPresenceModel` runs the idle scheduler: an irregular weighted draw (blink
0.41, double blink 0.04, look left and right 0.10 each, look up 0.06, the
remaining 29% stillness) with a 4 to 19 s delay and a 6 s cooldown, and it
stops entirely while any surface reports scrolling, editing, capturing or a
modal task, while Reduce Motion is on, or while a question is pending
([`PitPresenceModel.swift`](../../Pitstop/Features/Pit/PitPresenceModel.swift)).
A chosen question plays startle then knock, or the knock alone with Reduce
Motion, and the knock holds until the question ends. Closing the Pit sheet
shows closed eyes for 0.7 s unless a question is knocking. In the sheet,
`PitCaptureEyes` plays the beats computed by `PitCaptureChoreography`:
listening holds a fixed gaze with rarer blinks (weight 0.22, delay up to 26 s),
input leads through blink and side gaze (held at least 0.6 s) to a proposal
knock or to glance, closed eyes and resting after a save
([`PitCaptureEyes.swift`](../../Pitstop/Features/Pit/PitCaptureEyes.swift)).
With Reduce Motion, idle actions, listening blinks, bounded "life"
(micro-saccades, drift, breathing), the post-input blink and the glance are
dropped; side gaze, knock without bumps, closed eyes and resting stay as state
changes. A double blink is two blink beats, not a state. `PitState.hidden` is
drawable (dimmed in `PitEyesGlyph`) but no model shows it, as ADR 0028 records.

---

## 6. Pit question lifecycle

```mermaid
flowchart TB
    reg["PitQuestionRegistry.product: CurrentMileageQuestion, context Service, priority 10, unlocks serviceStatus"]
    trig["PitAskTrigger: interface idle, then 2 s settle on the surface"]
    rel{"Relevant now? a tracked distance rule blocked by unknown or stale mileage"}
    join["registry.questions with persisted state: returned questions become unresolved"]
    pol{"PitAttentionPolicy: interface idle, surface matches, 12 h since last ask, 7 d since last dismissal"}
    silent(["Pit stays silent"])
    asked["execute asked: lastAskedAt = now, resolution unresolved"]
    knock["Pit startles and knocks"]
    card["Question card in the Pit sheet"]
    reval{"Facts changed before an answer? revalidate"}
    quiet["phase silent, no resolution stored"]
    ans["answered: reading saved via recordOdometerReading, resolvedAt = now"]
    def["deferred: I do not know yet, resolvedAt = now"]
    dis["dismissed: resolvedAt and lastDismissedAt = now"]
    retA{"90 d passed since answer?"}
    retD{"14 d passed since deferral?"}
    never(["never returns"])

    trig --> rel
    reg --> rel
    rel -- no --> silent
    rel -- yes --> join --> pol
    pol -- no --> silent
    pol -- yes --> asked --> knock --> card
    card --> reval
    reval -- "no longer relevant" --> quiet --> trig
    card --> ans
    card --> def
    card --> dis
    ans --> retA
    def --> retD
    dis --> never
    retA -- "yes, and still relevant" --> join
    retD -- yes --> join
    retA -- no --> silent
    retD -- no --> silent
```

The registry is the only source of questions, and a definition cannot exist
without a declared value and a declared return path
([`PitQuestionRegistry.swift`](../../Pitstop/Domain/Pit/PitQuestionRegistry.swift),
[ADR 0016](../decisions/0016-question-registry.md)). The one product question
asks for the current mileage on Service, and only while a tracked distance
rule is blocked because the mileage is unknown or older than 90 days
([`CurrentMileageQuestion.swift`](../../Pitstop/Domain/Pit/CurrentMileageQuestion.swift),
[ADR 0017](../decisions/0017-first-question-current-mileage.md)). `RootView`
checks only after the interface has been idle and the user has stayed on the
surface for 2 s; the check restarts after every navigation. The attention
policy then requires an idle interface (Reduce Motion does not count), the
matching surface, 12 hours since any ask and 7 days since any dismissal,
across all questions ([`PitPresence.swift`](../../Pitstop/Domain/Pit/PitPresence.swift)).
The ask is persisted before Pit knocks; if it cannot be persisted, Pit stays
silent ([`PitQuestionViewModel.swift`](../../Pitstop/Features/Pit/PitQuestionViewModel.swift)).
An answer writes the reading through the car store first and then records the
resolution. Return rules are declared per question and enforced by the store:
an answer holds for 90 days and returns only if still relevant, a deferral
returns after 14 days, a dismissal never returns, and a later "not now" cannot
undo an answer ([`PitQuestionState.swift`](../../Pitstop/Domain/Pit/PitQuestionState.swift),
[ADR 0018](../decisions/0018-attention-cooldown-and-return.md)). A capture or a
Siri save that supplies the mileage makes a pending question go quiet without
a resolution.

---

## 7. Data model

```mermaid
erDiagram
    VehicleRecord ||--o{ OdometerReadingRecord : "vehicleID"
    VehicleRecord ||--o{ MaintenancePolicyRecord : "vehicleID"
    VehicleRecord ||--o{ MaintenanceCompletionRecord : "vehicleID"
    VehicleRecord ||--o{ HistoryEventRecord : "vehicleID"
    VehicleRecord |o--o{ NoteRecord : "vehicleID, optional"
    VehicleRecord ||--o{ PlannedVehicleEventRecord : "vehicleID"
    HistoryEventRecord |o--o{ MaintenanceCompletionRecord : "sourceEventID, optional"

    VehicleRecord {
        UUID id PK
        string name
        string make "optional"
        string model "optional"
        int year "optional"
        string vin "optional"
        bool isProvisional
        date createdAt
    }
    OdometerReadingRecord {
        UUID id PK
        UUID vehicleID
        double value
        string unit "km or mi"
        date recordedAt
        string source "manualEntry, pitCapture, detected"
    }
    MaintenancePolicyRecord {
        UUID vehicleID
        string operationID
        int distanceIntervalKm "optional"
        int timeIntervalMonths "optional"
        string source "defaultRecommendation, vehicleCondition, userCustom"
    }
    MaintenanceCompletionRecord {
        UUID id PK
        UUID vehicleID
        string operationID
        date performedAt
        int odometerKm "optional"
        double engineHours "optional"
        UUID sourceEventID "optional"
    }
    HistoryEventRecord {
        UUID id PK
        UUID vehicleID
        string kind "service, carWash, odometer, insurance, purchase, other"
        date date
        int odometerKm "optional"
        decimal amount "optional"
        string note "optional"
    }
    NoteRecord {
        UUID id PK
        UUID vehicleID "optional"
        string rawText
        date createdAt
        string status "active or archived"
        string contexts "list: carWash, service, shopping"
    }
    PitQuestionStateRecord {
        string questionID PK "V2 and later"
        string resolution
        date lastAskedAt "optional"
        date lastDismissedAt "optional"
        date resolvedAt "optional"
    }
    PlannedVehicleEventRecord {
        UUID id PK "V3 and later"
        UUID vehicleID
        string kind "insuranceExpiry or other"
        string label "optional, other only, up to 40 characters"
        date date "start of the day"
        date createdAt
    }
    VehicleServiceReportRecord {
        UUID id PK "V4 and later"
        UUID vehicleID
        string operationID "only the newest reading per operation is read"
        date reportedAt
        int odometerKm "optional, required with a distance"
        double remainingDistance "optional, negative when overdue"
        string distanceUnit "km or mi, as entered"
        int remainingDays "optional, negative when overdue"
        string source "manualEntry or pitCapture"
        UUID completionIDsAtEntry "list, completions already saved when entered"
    }
```

The store keeps one car (created provisionally on first read) and its facts as
SwiftData records in `Library/Application Support/Pitstop.store` of the App
Group container (ADR 0036)
([`PitstopSchemaV1.swift`](../../Pitstop/Infrastructure/Persistence/PitstopSchemaV1.swift),
[`PitstopSchemaV2.swift`](../../Pitstop/Infrastructure/Persistence/PitstopSchemaV2.swift),
[`PitstopSchemaV3.swift`](../../Pitstop/Infrastructure/Persistence/PitstopSchemaV3.swift),
[`PitstopSchemaV4.swift`](../../Pitstop/Infrastructure/Persistence/PitstopSchemaV4.swift),
[`PersistenceContainer.swift`](../../Pitstop/Infrastructure/Persistence/PersistenceContainer.swift)).
Links are UUID fields, not SwiftData relationships. Schemas V1 and V2 are
frozen: any change to a record needs a new version with its own copy of the
class. V2 adds only `PitQuestionStateRecord` through a lightweight V1 to V2
stage in `PitstopMigrationPlan`; the question store shares the container and
file but is a separate actor with its own protocol, so no capture can change
question state ([ADR 0007](../decisions/0007-persistence.md), ADR 0016). V3
adds only `PlannedVehicleEventRecord` through a second lightweight stage, so a
V1 store passes both stages; the record has no field for an insurer, a policy
number or an amount ([ADR 0032](../decisions/0032-planned-dated-events.md)). V4
adds only `VehicleServiceReportRecord` through a third lightweight stage, and V3
is frozen too; every entered reading keeps its own row and ID, the engine counts
only the newest per operation and reads the others as mileage observations, so
a replayed confirmation is a duplicate rather than an overwrite, and the record has no interval field: it is an observation, never a
rule
([ADR 0035](../decisions/0035-dashboard-service-reading.md)). Policy rows are
keyed by vehicle, operation and source, so a custom interval never deletes a
recommendation row; the app ships no recommendation data today, so every
stored policy is `userCustom`. The only write path for car data is
`CarMemoryStore.execute(DomainCommand)`, which validates the command again and
rejects a repeated record ID as `duplicateRecord`
([`CarMemoryStore.swift`](../../Pitstop/Domain/Store/CarMemoryStore.swift),
[`DomainCommands.swift`](../../Pitstop/Domain/Capture/DomainCommands.swift)).
When the on-disk store cannot open, the session falls back to memory and the
UI says nothing will be kept (`PersistenceMode.temporary`).

---

## 8. Maintenance and Road projections

```mermaid
flowchart LR
    subgraph facts["Stored facts"]
        rd[("Odometer readings")]
        cp[("Maintenance completions")]
        pl[("Maintenance policies")]
        ev[("History events")]
        nt[("Notes")]
        vh[("Vehicle")]
        pe[("Planned dates")]
    end

    ctx["MaintenanceContext: newest observation of reading or completion mileage, not in the future; stale after 90 d"]
    eng["MaintenanceEngine: effective policy per operation, status unknown, upToDate, approaching at 15 percent left, due; distanceBlock reason"]
    plan["ServicePlanner: all due plus due nearby within 2,000 km or 45 d of the visit point"]
    tl["HistoryTimeline: events plus confirmed completions, newest first"]
    proj["RoadProjector: horizon 5,000 km or 183 d, clusters 1,500 km or 21 d per dimension, overdue past 10 percent, up to 4 initial slots"]
    ns["NotesSummary"]
    car["ProvisionalCarContext: name and observed km"]

    subgraph board["Car Board, re-projected on every return"]
        hero["Car hero"]
        tRoad["Road tile, full width"]
        tNotes["Notes tile"]
        tServ["Service tile: most urgent operation"]
        tHist["History tile"]
    end

    sServ["Service screen: states plus suggested visit scope"]
    sRoad["Road screen: lane, waiting for mileage, past summary"]

    rd --> ctx
    cp --> ctx
    ctx --> eng
    pl --> eng
    cp --> eng
    eng --> plan --> sServ
    eng --> sServ
    ev --> tl
    cp --> tl
    eng --> proj
    tl --> proj
    pe --> proj
    proj --> tRoad
    proj --> sRoad
    eng --> tServ
    tl --> tHist
    nt --> ns --> tNotes
    vh --> car
    ctx --> car --> hero
```

Nothing on Car Board, Service or Road is stored; every number is recomputed
from facts on load ([`CarBoardViewModel.swift`](../../Pitstop/Features/CarBoard/CarBoardViewModel.swift),
[`ServiceViewModel.swift`](../../Pitstop/Features/Service/ServiceViewModel.swift),
[`RoadViewModel.swift`](../../Pitstop/Features/Road/RoadViewModel.swift)).
`MaintenanceContext` takes the newest mileage observation, whether an odometer
reading or a completion recorded with its mileage, and treats it as stale after
90 days; only a current observation feeds distance arithmetic
([`MaintenanceEngine.swift`](../../Pitstop/Domain/Maintenance/MaintenanceEngine.swift),
[ADR 0010](../decisions/0010-maintenance-engine-rules.md),
[ADR 0020](../decisions/0020-maintenance-anchor-closure.md)). The engine
derives one state per effective policy from the last confirmed completion: the
smallest remaining share of the known dimensions decides, an operation with no
completion is `unknown`, and a blocked distance rule is named
(`mileageUnknown`, `mileageStale`, `completionMileageMissing`) and makes a
time-only status partial. `ServicePlanner` groups everything due with work due
within 2,000 km or 45 days of the visit point
([`ServicePlanner.swift`](../../Pitstop/Domain/Maintenance/ServicePlanner.swift)).
`RoadProjector` places milestones in one lane in horizon units, clusters within
a dimension only, never converts kilometres to days, and moves distance-only
milestones it cannot place to "waiting for mileage"
([`RoadProjector.swift`](../../Pitstop/Domain/Road/RoadProjector.swift),
[`RoadProjection.swift`](../../Pitstop/Domain/Road/RoadProjection.swift),
[ADR 0008](../decisions/0008-road-projection-rules.md)). The Road screen and
the Road tile both pass the stored planned dates into `RoadContext`; a date
stays on Road as due for 14 days after it passes and then leaves, while the row
stays stored. The owner adds a date from Road's toolbar and edits or deletes it
from the Road list; insurance has no tile of its own
([ADR 0032](../decisions/0032-planned-dated-events.md)). The board shows four tiles in a fixed V1 order
([`CarBoardTiles.swift`](../../Pitstop/Features/CarBoard/CarBoardTiles.swift),
[ADR 0009](../decisions/0009-design-language.md)) and reloads when the user
returns to it, when a utility sheet closes, and when the app returns from the
background.

---

## 9. Delivery pipeline

```mermaid
flowchart LR
    dev["Local change"]
    verify["just verify: baseline, format, lint, build for testing, tests"]
    push["git push to main, owner authorised"]
    tests["GitHub Actions tests.yml: just ci on hosted xcode-27 runner"]
    check["just tf-check: read-only, prints Ready and the tag commands"]
    tag["Annotated tag tf-MAJOR.MINOR.PATCH-BUILD on a commit of main"]
    promote["testflight.yml: tf-promote.sh checks main, MARKETING_VERSION, own green tests run"]
    branch["fast-forward testflight branch"]
    xcc["Xcode Cloud workflow TestFlight: Archive iOS, build number from CI_BUILD_NUMBER"]
    tfg["TestFlight group Internal"]
    vtag["v tag and App Review: owner only"]
    rules["Rulesets: main and testflight no deletion or force push; tf tags cannot move; v tags cannot move or be deleted"]

    dev --> verify --> push --> tests
    tests -- green --> check --> tag --> promote --> branch --> xcc --> tfg
    tfg -.-> vtag
    rules -.-> push
    rules -.-> tag
    rules -.-> branch
```

`just verify` is the implementation gate on the Mac; the hosted run on a push
to `main` repeats the tests and builds nothing for distribution
([`.github/workflows/tests.yml`](../../.github/workflows/tests.yml),
[ADR 0013](../decisions/0013-shared-ci-and-tag-gated-testflight.md),
[ADR 0014](../decisions/0014-public-repository.md)). A build is requested only
by a `tf-` tag: `testflight.yml` runs `Tooling/scripts/tf-promote.sh`, which
accepts the tag only when the commit is on `main`, every `MARKETING_VERSION`
equals the tag's version, and that commit has its own successful tests run;
it then fast-forwards `testflight`, which is the only branch the Xcode Cloud
workflow builds ([`.github/workflows/testflight.yml`](../../.github/workflows/testflight.yml),
[`Tooling/docs/testflight.md`](../../Tooling/docs/testflight.md)).
`ci_scripts/ci_post_clone.sh` sets the build number from Xcode Cloud. An agent
may push a `tf-` tag only after `just tf-check` prints `Ready`; `v` tags and
App Review are the owner's ([`AGENTS.md`](../../AGENTS.md)). The rulesets come
from [`Tooling/templates/github/rulesets/`](../../Tooling/templates/github/rulesets/).

---

## 10. Feature matrix

Verification status uses these terms. **Unit tests**: covered by the
`PitstopTests` suites named in the row, which `just verify` and the hosted tests
run. **Screen not verified**: listed under "Not verified on screen" in the
[work plan](../planning/work-plan.md). **Device check pending**: an owner-only
device check in the work plan. No row claims a manual check this page did not
record.

| Feature | User-visible behaviour | ADR(s) | Key code | Test suite(s) | Verification status |
|---|---|---|---|---|---|
| Design system | Surface tiers: tinted stage, grouped lists, glass only for floating controls; status as word + glyph + colour; typography roles; Reduce Transparency and Increase Contrast fallbacks; source rules against colour literals in features, shared code and redesigned widgets, and glass outside the design system | 0009, 0038 | `Shared/DesignSystem/` (`PitColor.swift`, `PitTypography.swift`, `DesignTokens.swift`, `GlyphDisc.swift`; compiled into the app and the widget extension), `DesignSystem/Components/` (`StageSurface`, `StatusChip`, `StatusGlyph`, `EmptyState` with its `EmptyStateContent` value, `GlassPill`, `StepStrip`, `RemainingShareTrack`, `PitGlass`, `ChipFlowLayout`) | `DesignRulesTests`, `PitColorTests`, `StatusGlyphTests`, `RemainingShareTrackTests`, `ChipFlowLayoutTests`, `SparseStateTests` | Unit tests; components previewed only, screens adopt them in RD-001…RD-012 |
| Car context | One provisional car created on first launch; name and mileage editable; hero shows the newest observed mileage and its age from the observation's own date (today, days, weeks, months) | 0007, 0009 | `Domain/Vehicle/`, `Features/CarBoard/CarEditorView.swift`, `CarBoardViewModel.swift`, `MileageRecency.swift` | `ProvisionalCarContextTests`, `CarBoardViewModelTests`, `MileageRecencyTests` | Unit tests |
| Car Board | Hero on the tinted stage with a glass pencil ("Name your car" while provisional) plus Road, Notes, Service, History tiles in fixed order; each tile has a title row with a chevron, a primary line, a status chip only where a state exists and a secondary line; the Road tile draws its initial slots as state-glyph markers; utility layer with Settings and Pit on every screen; every other sheet covers the layer, Settings included, and keeps Pit alone at the same bottom-trailing spot, in a bottom safe-area inset so rows scroll clear of him and he rides above the keyboard (REQ-UTILITY-012); board refreshes on return; a first-launch board shows no placeholder metric: "Mileage unknown" as a label and every tile in its sparse headline and sentence (REQ-GRAMMAR-004) | 0009, 0038 | `Features/CarBoard/`, `DesignSystem/Components/UtilityLayer.swift`, `App/RootView.swift`, `Features/Pit/PitInSheet.swift` | `CarBoardTileDescriptorTests`, `CarBoardTileContentTests`, `CarBoardViewModelTests`, `PitInSheetTests` | Unit tests; light, dark, AX-XXXL and first launch checked on the simulator (RD-001), first launch again in light, dark and AX-XXXL (RD-008); the layer at the same spot on Car Board and Service, and the Pit sheet at the medium detent floating inset over the layer so that neither Settings nor Pit shows beside it, over Car Board (light, dark) and Service (dark), and at the large detent at AX-XXXL, checked on the simulator (RD-010); Pit inside a feature sheet or Settings, above the keyboard and disabled while saving not seen on screen (reaching a sheet needs taps); VoiceOver order, Reduce Transparency and ru/uk screens not verified |
| Persistence | Data survives relaunch; a failed on-disk store falls back to memory and says so; schemas V1 to V3 frozen, V2 adds question state, V3 adds planned dates, V4 adds dashboard readings; V1, V2 and V3 stores migrate to V4 | 0007, 0016, 0032, 0035 | `Infrastructure/Persistence/`, `App/AppEnvironment.swift` | `PersistenceSchemaTests`, `SchemaV3MigrationTests`, `SchemaV4MigrationTests`, `SwiftDataCarMemoryStoreTests`, `SwiftDataPitQuestionStoreTests`, `SwiftDataPlannedEventTests` | Unit tests |
| Notes | Add a note (raw capture), list active or archived, filter by context, correct, archive and restore; no AI. The notes of the scope and filter are rows of one grouped list without a heading: the raw text in body weight and a meta line with recency and the note's contexts in catalog order, joined with a middle dot; context chips wrap at every size ("All" first and the main list with unclassified notes; the selected chip filled with the accent, the others on the surface fill with a hairline) and are hidden while no note in the scope has a context; archive or restore is one path (`NoteArchiveToggle`) reached by the row's accent glyph (under the text at accessibility sizes), a trailing swipe (iOS 27 `swipeActions` with `swipeActionsContainer()` on the scroll view), the context menu and the VoiceOver named action on the row's text button; an empty scope is the design-system `EmptyState` under the scope control, "New note" in Active and the headline alone in Archived (`NotesViewState.sparseState`, REQ-GRAMMAR-004) | 0006, 0011, 0038 | `Features/Notes/`, `Domain/Notes/`, `DesignSystem/Components/GroupedSection.swift`, `ChipFlowLayout.swift`, `EmptyState.swift` | `NotesTests` (including `NotesPresentationTests`), `FeatureAnalyticsTests`, `SparseStateTests` | Unit tests; populated light and dark, wrapped chips at AX-XXXL and the empty Notes checked on the simulator (RD-006), the empty Active scope in light, dark and AX-XXXL (RD-008), the empty Archived scope not on screen; the swipe, the editor, archive and restore on screen, VoiceOver and ru/uk screens not verified on screen |
| History | Record and correct events with optional mileage and amount; timeline of events and confirmed completions, one grouped list per calendar month (month and year heading, newest month first, the timeline's order inside a month; calendar and time zone injected from the environment) with a decorative rail through the row dots, hidden from VoiceOver; recorded events open their editor (accent dot, chevron except at accessibility sizes); confirmed completions are not editable here (up-to-date dot, no chevron, seal line "Confirmed done · corrected on Service"); the facts line writes a missing mileage out and joins mileage and amount with a middle dot; an empty History is the design-system `EmptyState` with "Add event" (`HistoryViewState.sparseState`, REQ-GRAMMAR-004) | 0007, 0038 | `Features/History/`, `Domain/History/HistoryTimeline.swift`, `DesignSystem/Components/GlyphColumnRow.swift` (rail), `EmptyState.swift` | `HistoryTests`, `HistoryMonthTests`, `SparseStateTests` | Unit tests; populated light and dark, a completion beside a recorded event on one rail, AX-XXXL and the empty History checked on the simulator (RD-005), the empty History again in light, dark and AX-XXXL (RD-008); the event editor, add and correct, VoiceOver and ru/uk screens not verified on screen |
| Service | One "Track" toolbar menu ("Track an operation", disabled when nothing is untracked; "Track several", disabled until Service has loaded, after a failed load and when nothing is untracked; the menu disabled only when both are); "Next visit" as a grouped list with the status glyph and its footer; "Tracked" as one grouped list whose rows show a status chip (word, glyph, colour), the neutral fact line, the dashboard reading line, a remaining-share track, a visible "Mark as done" and the more menu; the track is drawn only with a last completion, mileage newer than 90 days, a known status and a policy interval in the deciding dimension, full past 100 %, hidden from VoiceOver; the empty state waits for the first successful load and is the design-system `EmptyState` with "Track an operation" above "Track several" (`ServiceViewState.sparseState`, REQ-GRAMMAR-004). Track an operation with a distance and/or time interval, or several at once ("Track several": a step strip names Choose, Intervals, Confirm and Result; pick operations, enter each interval with optional quick picks drawn as wrapping tinted chips, a chip selected only while its field holds exactly that number; confirm one summary with a full-width "Track: N" above a secondary Back; per-item Saved / Not saved chips with retry of failed items; optional gearbox and drive answers only reorder), mark done (a completion of the operation recorded while the sheet is open, by Pit over it, is not recorded again; the operation's completions from before the sheet opened, same day included, do not count; REQ-PIT-026), change interval, undo the newest completion, stop tracking (owner policy removed behind a confirmation; completions and History stay); enter the car's dashboard reading (distance with an explicit km / mi unit, days, odometer) shown as "Car says …" with its date, "old" after 180 days, the earlier anchor winning per dimension, and delete it behind a confirmation; status with reasons; suggested visit scope | 0001, 0010, 0020, 0031, 0033, 0035, 0038 | `Features/Service/`, `Domain/Maintenance/`, `DesignSystem/Components/GroupedSection.swift`, `ChipFlowLayout.swift` | `MaintenanceEngineTests`, `ServicePlannerTests`, `ServiceViewModelTests`, `ServiceTrackMenuTests`, `ServiceShareTrackTests`, `StopTrackingTests`, `SwiftDataStopTrackingTests`, `TrackSeveralTests`, `SwiftDataTrackSeveralTests`, `VehicleServiceReportTests`, `SparseStateTests`, `MarkDoneAfterCaptureTests` | Unit tests; light, dark, AX-XXXL, the Track menu, the row more menu, the "Mark as done" and dashboard reading sheets, a saved reading line, stale mileage without tracks and the empty Service checked on the simulator (RD-003), the empty Service again in light, dark and AX-XXXL (RD-008); the four "Track several" steps in light, Intervals in dark, Intervals and Confirm at AX-XXXL, a chip following its field and the validation line checked on the simulator (RD-004); the "Track several" failure and retry state, the old-reading line, VoiceOver and ru/uk screens not verified on screen |
| Road | Lane on the tinted stage: the car and one roadside sign per slot (a plate with the state glyph on a post) standing on one road line, labels under it, clusters as one sign with a count; "Back to now" glass pill only once the lane has left the car, without animation under Reduce Motion; the same milestones as one grouped list under "Ahead" in lane order, then "Waiting for mileage"; state word coloured, fact line neutral, estimate tertiary; one-line past summary; add a date (insurance expiry, or another date with an optional name), edit, and delete behind a confirmation; a distance milestone also carries a labelled date estimate derived from the reading history (annotation only, never stored); a milestone decided by the car's dashboard reading reads "from dashboard"; a road with nothing known is the design-system `EmptyState` with "Add a date" (`RoadProjection.sparseState`, REQ-GRAMMAR-004) | 0008, 0032, 0034, 0035, 0038 | `Features/Road/`, `Domain/Road/`, `DesignSystem/Components/EmptyState.swift` | `RoadProjectorTests`, `RoadViewModelTests`, `RoadLaneTests`, `RoadMilestoneListTests`, `PlannedDatedEventTests`, `PlannedEventViewModelTests`, `MileageRateEstimateTests`, `RoadEstimateProjectionTests`, `VehicleServiceReportTests`, `SparseStateTests` | Unit tests; light, dark, AX-XXXL, lane scrolling with back to now, waiting for mileage, the empty road and the planned date editor checked on the simulator (RD-002), the empty road again in light, dark and AX-XXXL (RD-008); clusters, Reduce Motion, the estimate line, the dashboard suffix, VoiceOver and ru/uk screens not verified on screen |
| Remember in Pit | Type a thought; raw or interpreted mode; confirm, keep words only, answer one missing field, or "I don't know"; told where it was saved. The sheet shows one moment at a time (`PitSheetMoment`): Pit's eyes beside a title that names it ("Remember" while composing or working, "Is this right?", "One thing", "Saved."), never a transcript; while composing, Pit's pending question sits on a card above the composer and the capture's own clarification is then the only question; the filled capsule "Remember" is pinned to the sheet bottom above the keyboard; with Pit's question pending the question's Save is the one prominent action and Remember is a quiet capsule at every text size, under the composer, or pinned above the keyboard at accessibility sizes; the confirmation quotes the raw words first, then the meaning and every fact to be written; a clarification quotes the words and offers plain choices as one grouped list plus "I don't know"; the saved state names the destination in words with one link and "Remember something else"; the sheet opens at the medium detent, at the large one at accessibility text sizes, both kept available. It opens from Pit in the utility layer or from Pit inside any other sheet, over that sheet (`PitCaptureEntry`: one capture at a time; closing cancels an unsent capture wherever it opened); over a sheet the saved moment names the destination without a link, so the sheet returns with its input intact; Pit in a sheet is disabled while that sheet saves; an "Open Pit" request with capture already open is met without presenting it again (REQ-PIT-026) | 0006, 0011, 0015, 0017, 0038 | `Domain/Capture/`, `Features/Pit/PitCaptureViewModel.swift`, `PitCaptureView.swift`, `PitSheetMoment.swift`, `PitSheetParts.swift`, `PitCaptureDetents.swift`, `PitCaptureEntry.swift`, `PitInSheet.swift` | `InterpretedRememberTests`, `RawFallbackTests`, `ConfirmationPolicyTests`, `ProposalValidatorTests`, `DomainCommandTests`, `RuleBasedInterpreterTests`, `CaptureInputTests`, `CaptureStageTests`, `RememberEndToEndTests`, `VehicleServiceReportCaptureTests`, `PitCaptureViewModelTests`, `PitSheetMomentTests`, `PitCaptureDetentsTests`, `PitInSheetTests`, `PitSavingGuardTests` | Unit tests; composing, confirming, clarifying, saved and the pending question in light, confirming in dark, composing, confirming and the question at AX-XXXL checked on the simulator (RD-007); the working spinner, the answered-reading line, the stacked decline pair at accessibility sizes, VoiceOver and ru/uk screens not verified on screen |
| Foundation Models interpreter | DEBUG builds launched with `-pitstop-foundation-models` ask the model after the rules; Release never does | 0027 | `Infrastructure/Interpretation/FoundationModelsInterpreter.swift`, `Domain/Capture/ModelDraft.swift`, `App/InterpreterComposition.swift` | `FoundationModelsInterpreterTests`, `InterpreterEvaluationTests` (golden set) | Unit tests with a fake model; device evaluation pending (DEV-FM) |
| Pit presence and motion | Eyes rest, blink and look around irregularly, yield to any activity, startle and knock to ask, think and glance in the sheet, close on leaving; Reduce Motion mapping | 0012, 0019, 0028 | `Domain/Pit/PitPresence.swift`, `Features/Pit/PitPresenceModel.swift`, `PitCaptureEyes.swift`, `PitActivityReporting.swift`, `DesignSystem/Components/PitEyesGlyph.swift` | `PitPresenceTests`, `PitCaptureEyesTests`, `PitEyesGlyphTests`, `PitLeavingTests`, `PitActivityReportingTests` | Unit tests; motion on screen not recorded here |
| Pit current-mileage question | On Service, when mileage is unknown or stale and a distance rule is tracked, Pit knocks once; answer, defer (14 d) or dismiss (never again); 12 h and 7 d cooldowns | 0016, 0017, 0018 | `Domain/Pit/`, `Features/Pit/PitQuestionViewModel.swift`, `PitQuestionCard.swift`, `PitAskTrigger.swift` | `PitQuestionRegistryTests`, `CurrentMileageQuestionTests`, `PitQuestionReturnTests`, `MileageQuestionReturnTests`, `MileageQuestionEndToEndTests` | Unit tests; returns that need days of clock time not verified on screen |
| Siri Remember | "Remember in PitStop": Siri asks for the words, confirms or asks one detail by voice, answers with where it saved; unlocked phone only; refused with temporary storage | 0023, 0026 | `App/Intents/RememberInPitStopIntent.swift`, `Features/SystemCapture/` | `RememberIntentHandlerTests`, `RememberSpeechTests` | Unit tests; device check pending (DEV-SIRI) |
| App Shortcuts | Remember and Open Pit shortcuts with en phrases in code and ru, uk phrases in the catalog | 0024 | `App/Intents/PitStopShortcuts.swift`, `Shared/OpenPitIntent.swift` | `AppShortcutsTests` | Unit tests; Shortcuts listing device check pending (DEV-WIDGET); ru and uk phrases await owner review |
| Widget and control | Data-free small and circular widget and an Open Pit control that open the Pit sheet; deferred while an editor is open; the small widget draws the shared glyph disc (accentable in the tinted Home Screen mode) with the "Remember" headline and hint in PitColor and PitTypography roles on `surfaceSecondary` (RD-009) | 0025, 0038 | `PitstopWidgets/`, `Shared/`, `Shared/DesignSystem/GlyphDisc.swift` | `WidgetEntryTests` (with `CaptureWidgetSourceTests`: no data read, link, words, disc), `DesignRulesTests` | Unit tests; a replica of the small layout rendered in light, dark and AX sizes (RD-009); the real widget in the gallery, its tinted and dark appearances, Control Center, Lock Screen and Action button device check pending (DEV-WIDGET) |
| Next-service widget | Small, Lock Screen rectangular and inline widget showing Service's first operation (name, status word, one fact) or a calm empty state; tap opens Service; reloads after saved commands and at the next time-based change; store moved once into the App Group container | 0036 | `PitstopWidgets/NextServiceWidget.swift`, `Shared/NextServiceContent.swift`, `Shared/AppLink.swift`, `Infrastructure/Persistence/StoreRelocation.swift`, `NextServiceStoreReader.swift`, `Infrastructure/Widgets/` | `StoreRelocationTests`, `NextServiceWidgetTests`, `WidgetEntryTests` | Unit tests; gallery, rendering and TestFlight upgrade device checks pending (DEV-WIDGET) |
| Analytics | Off by default; Settings opt-in; closed event values without user text; PostHog adapter active only with a key and host in the build (none shipped) | 0002, 0021, 0022 | `Infrastructure/Analytics/`, `Features/Pit/CaptureAnalytics.swift`, `Features/Notes/NotesAnalytics.swift`, `Features/Settings/SettingsView.swift` | `AnalyticsBoundaryTests`, `CaptureAnalyticsTests`, `FeatureAnalyticsTests`, `PostHogAnalyticsClientTests` | Unit tests; no PostHog project exists, so delivery is untested end to end |
| Logging | OSLog categories; capture stages logged without content | 0003 | `Infrastructure/Logging/` | `CaptureStageTests` | Unit tests |
| App icon | Pit's round head at rest as a Liquid Glass icon with six appearances | 0029, 0037 | `Pitstop/AppIcon.icon` | none (asset) | Not covered by tests |
| Delivery | Tests on every push to `main`; TestFlight only from a `tf-` tag through Xcode Cloud | 0013, 0014 | `.github/workflows/`, `Tooling/scripts/`, `ci_scripts/` | Runtime contract tests in the toolchain, not in this repository | Rounds `tf-1.0.0-1`, `tf-1.1.0-1` and `tf-1.1.0-2` exist on the remote |

## Mismatches found while writing this page

Recorded here instead of silently corrected; each needs a code or document
change by its owner.

- **Features name other features' types.** No feature depends on App or on
  another feature's view model since ARCH-001, but these references would still
  need a shared home before a package split: Pit's `PitAskTrigger` holds
  CarBoard's `CarBoardRoute`; Pit's `CaptureAnalytics` sends Notes'
  `NotesAnalyticsEvent` and `NoteInputSource`; SystemCapture's
  `RememberIntentHandler` replies with Pit's `PitDestination`; CarBoard's tile
  embeds Road's `RoadLaneView`. Resolved by PREP-011: `Features/Shared/FeatureScaffold`
  no longer takes CarBoard's `CarBoardTileKind`, because the unreachable pending
  surface that needed it was removed. Resolved by PREP-009 and PREP-010: Road no
  longer reads Service's `service.progress.*` keys and the Car Board tile no
  longer calls a History extension for recency; both go through `Features/Shared`
  (`ProgressText`, `FeatureFormat`).
