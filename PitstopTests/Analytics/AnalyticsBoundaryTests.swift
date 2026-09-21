import Foundation
@testable import Pitstop
import Testing

/// One instance of every typed event case, so the catalog checks below cannot skip a case silently:
/// `catalogCoversEveryEventName` fails when a new event name has no sample here.
private let catalog: [any AnalyticsEncodable] = [
    CaptureAnalyticsEvent.inputInterpretationCompleted(
        intent: .odometerReading, availability: .available, result: .draft, latency: .under1s,
        interpreter: .ruleBasedV1
    ),
    CaptureAnalyticsEvent.inputInterpretationCompleted(
        intent: .noMeaning, availability: .unavailable, result: .fallback, latency: nil,
        interpreter: .noInterpreter
    ),
    CaptureAnalyticsEvent.draftSaved(intent: .maintenanceCompletion, edited: true),
    CaptureAnalyticsEvent.draftCancelled(intent: .vehicleEvent, stage: .preview),
    NotesAnalyticsEvent.noteCreated(inputSource: .voice, contextCount: .one, hasCanonicalContext: true),
    NotesAnalyticsEvent.noteCreated(inputSource: .text, contextCount: nil, hasCanonicalContext: true),
    NotesAnalyticsEvent.noteContextOpened(context: .carWash, activeNoteCount: .twoToThree),
    NotesAnalyticsEvent.noteArchived(sourceContext: .all, age: .underOneWeek),
    OdometerAnalyticsEvent.odometerUpdated(source: .natural, anomalyConfirmation: .accepted),
]

/// Parameters per event, copied from `docs/operations/analytics.md`. An event may omit a parameter
/// it cannot know, but it may never send one the taxonomy does not list.
private let taxonomy: [AnalyticsEventName: Set<String>] = [
    .inputInterpretationCompleted: ["intent", "availability", "result", "latency_bucket", "interpreter_version"],
    .draftSaved: ["intent", "edited"],
    .draftCancelled: ["intent", "stage"],
    .noteCreated: ["input_source", "context_count_bucket", "has_canonical_context"],
    .noteContextOpened: ["context", "active_note_count_bucket"],
    .noteArchived: ["source_context", "age_bucket"],
    .odometerUpdated: ["source", "anomaly_confirmation"],
]

@Suite("Analytics boundary")
struct AnalyticsBoundaryTests {
    @Test("ADR-0021: every typed event carries only closed categories and booleans")
    func typedEventsHoldNoRawContentTypes() {
        for event in catalog {
            // An enum case's payload reflects as one child holding the associated values.
            for payload in Mirror(reflecting: event).children {
                let fields = Mirror(reflecting: payload.value).children.map(\.value)
                for field in fields.isEmpty ? [payload.value] : fields {
                    // An omitted optional parameter is allowed; a present one must still be closed.
                    let optional = Mirror(reflecting: field)
                    guard optional.displayStyle != .optional || !optional.children.isEmpty else { continue }
                    let value: Any = optional
                        .displayStyle == .optional ? (optional.children.first?.value ?? field) : field
                    let isAllowed = value is Bool || value is any AnalyticsCategory
                    #expect(isAllowed, "\(type(of: event)) carries \(type(of: field))")
                }
            }
        }
    }

    @Test("ADR-0021: every encoded value is a declared case or a boolean, never free text")
    func encodedValuesAreDeclaredCases() {
        let categories: [any AnalyticsCategory.Type] = [
            CountBucket.self, LatencyBucket.self, AgeBucket.self, CaptureIntent.self,
            InterpreterAvailability.self, InterpretationResult.self, InterpreterVersion.self, DraftStage.self,
            NoteInputSource.self, AnalyticsNoteContext.self, NoteSourceContext.self, OdometerSource.self,
            AnomalyConfirmation.self,
        ]
        var declared: Set = ["true", "false"]
        for category in categories {
            declared.formUnion(category.allRawValues)
        }
        for event in catalog {
            for value in event.analyticsEvent.properties.values {
                #expect(declared.contains(value.encoded), "undeclared value \(value.encoded)")
            }
        }
    }

    @Test("ADR-0002: event and parameter names are the taxonomy's, in snake_case")
    func namesMatchTaxonomy() {
        for event in catalog.map(\.analyticsEvent) {
            let allowed = taxonomy[event.name] ?? []
            let sent = Set(event.properties.keys.map(\.rawValue))
            #expect(sent.isSubset(of: allowed), "\(event.name.rawValue) sends \(sent.subtracting(allowed))")
        }
        let names = AnalyticsEventName.allCases.map(\.rawValue) + AnalyticsProperty.allCases.map(\.rawValue)
        for name in names {
            #expect(name.allSatisfy { $0.isLowercase || $0 == "_" }, "\(name) is not snake_case")
        }
    }

    @Test("ADR-0021: the catalog samples every event name")
    func catalogCoversEveryEventName() {
        #expect(Set(catalog.map(\.analyticsEvent.name)) == Set(AnalyticsEventName.allCases))
        #expect(Set(taxonomy.keys) == Set(AnalyticsEventName.allCases))
    }

    @Test(
        "ADR-0021: without an explicit opt-in nothing reaches the client",
        arguments: [AnalyticsConsent.notAsked, .declined]
    )
    func noConsentRecordsNothing(consent: AnalyticsConsent) {
        let spy = RecordingAnalyticsClient()
        let tracker = AnalyticsTracker<NotesAnalyticsEvent>(
            client: ConsentGatedAnalyticsClient(client: spy, consent: FixedAnalyticsConsent(consent: consent))
        )

        tracker.track(.noteArchived(sourceContext: .service, age: .underOneDay))

        #expect(spy.events.isEmpty)
    }

    @Test("ADR-0021: an opt-in passes the encoded event through unchanged")
    func grantedConsentForwards() {
        let spy = RecordingAnalyticsClient()
        let tracker = AnalyticsTracker<NotesAnalyticsEvent>(
            client: ConsentGatedAnalyticsClient(client: spy, consent: FixedAnalyticsConsent(consent: .granted))
        )

        tracker.track(.noteArchived(sourceContext: .service, age: .underOneDay))

        #expect(spy.names == [.noteArchived])
        #expect(spy.last(.noteArchived) == [.sourceContext: "service", .ageBucket: "lt_1d"])
    }

    @Test("ADR-0021: bucket edges")
    func bucketEdges() {
        #expect([0, 1, 2, 3, 4, 9, 10].map(CountBucket.init) == [
            .zero, .one, .twoToThree, .twoToThree, .fourToNine, .fourToNine, .tenOrMore,
        ])
        #expect([Duration.milliseconds(249), .milliseconds(250), .seconds(3), .seconds(10)].map(LatencyBucket.init) == [
            .under250ms, .under1s, .under10s, .tenSecondsOrMore,
        ])
        #expect([0, 86400, 90 * 86400].map { AgeBucket(TimeInterval($0)) } == [
            .underOneDay, .underOneWeek, .threeMonthsOrMore,
        ])
    }
}

private extension AnalyticsCategory {
    static var allRawValues: [String] {
        allCases.map(\.rawValue)
    }
}
