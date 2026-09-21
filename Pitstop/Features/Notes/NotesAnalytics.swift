import Foundation

/// Notes events from `docs/operations/analytics.md` (AQ-001, AQ-003). Values are closed categories;
/// the note's text never has a place here.
enum NotesAnalyticsEvent: AnalyticsEncodable, Hashable {
    /// `contextCount` is `nil` when the pipeline cannot know it: a contextual note's context set does
    /// not travel with the capture stage (ADR 0021).
    case noteCreated(inputSource: NoteInputSource, contextCount: CountBucket?, hasCanonicalContext: Bool)
    case noteContextOpened(context: AnalyticsNoteContext, activeNoteCount: CountBucket)
    case noteArchived(sourceContext: NoteSourceContext, age: AgeBucket)

    var analyticsEvent: AnalyticsEvent {
        switch self {
        case let .noteCreated(inputSource, contextCount, hasCanonicalContext):
            var properties: [AnalyticsProperty: AnalyticsValue] = [
                .inputSource: AnalyticsValue(inputSource),
                .hasCanonicalContext: AnalyticsValue(hasCanonicalContext),
            ]
            properties[.contextCountBucket] = contextCount.map(AnalyticsValue.init)
            return AnalyticsEvent(name: .noteCreated, properties: properties)
        case let .noteContextOpened(context, activeNoteCount):
            return AnalyticsEvent(name: .noteContextOpened, properties: [
                .context: AnalyticsValue(context),
                .activeNoteCountBucket: AnalyticsValue(activeNoteCount),
            ])
        case let .noteArchived(sourceContext, age):
            return AnalyticsEvent(name: .noteArchived, properties: [
                .sourceContext: AnalyticsValue(sourceContext),
                .ageBucket: AnalyticsValue(age),
            ])
        }
    }
}

enum NoteInputSource: String, AnalyticsCategory {
    case text
    case voice
    case explicit
    case siri

    init(_ source: CaptureSource) {
        switch source {
        case .pitText, .widget: self = .text
        case .pitVoice: self = .voice
        case .directApp: self = .explicit
        case .siri, .shortcut: self = .siri
        }
    }
}

/// Analytics spelling of `NoteContext`, kept apart so a domain rename cannot change a reported value.
enum AnalyticsNoteContext: String, AnalyticsCategory {
    case carWash = "car_wash"
    case service
    case shopping

    init(_ context: NoteContext) {
        switch context {
        case .carWash: self = .carWash
        case .service: self = .service
        case .shopping: self = .shopping
        }
    }
}

enum NoteSourceContext: String, AnalyticsCategory {
    case all
    case carWash = "car_wash"
    case service
    case shopping

    init(_ filter: NoteContext?) {
        switch filter.map(AnalyticsNoteContext.init) {
        case nil: self = .all
        case .carWash: self = .carWash
        case .service: self = .service
        case .shopping: self = .shopping
        }
    }
}
