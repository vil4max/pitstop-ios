import Foundation
@testable import Pitstop
import Testing

private typealias Fix = MaintenanceFixture

/// The parts of a sparse state a test can compare: keys rather than resources, whose bundle depends on the
/// module that built them.
private struct Composition<Action: Hashable>: Equatable {
    let glyph: String
    let headline: String
    let sentence: String?
    let actions: [Action]

    init(glyph: String, headline: String, sentence: String? = nil, actions: [Action] = []) {
        self.glyph = glyph
        self.headline = headline
        self.sentence = sentence
        self.actions = actions
    }

    init(_ content: EmptyStateContent<Action>) {
        self.init(
            glyph: content.systemImage,
            headline: content.headline.key,
            sentence: content.sentence?.key,
            actions: content.actions
        )
    }
}

private func road(_ states: [MaintenanceOperationState] = [], day: Double = 0) -> RoadProjection {
    RoadProjector().project(RoadContext(now: Fix.date(day), maintenanceStates: states, plannedEvents: []))
}

@Suite("Sparse states")
struct SparseStateTests {
    private static let locales = ["en", "ru", "uk"]

    @Test("REQ-GRAMMAR-004: an empty Road shows its glyph, headline, one sentence and the one Add a date action")
    func emptyRoad() throws {
        let sparse = try #require(road().sparseState)

        #expect(Composition(sparse) == Composition(
            glyph: "road.lanes",
            headline: "tile.road.empty.headline",
            sentence: "tile.road.empty.detail",
            actions: [.addDate]
        ))
    }

    @Test("REQ-GRAMMAR-004: an empty Road draws no summary, milestone or past marker beside the sparse state")
    func emptyRoadShowsNoMetric() throws {
        let projection = road()
        _ = try #require(projection.sparseState)
        let list = RoadMilestoneList(projection)

        #expect(projection.slots.isEmpty)
        #expect(list.ahead.isEmpty && list.waiting.isEmpty)
        #expect(projection.past == nil)
    }

    @Test("REQ-GRAMMAR-004: a Road with something tracked is not sparse; its sentence says why nothing is placed")
    func trackedRoadIsNotSparse() {
        let states = Fix.states([Fix.oil10k], [], currentKm: 50000, day: 10)

        #expect(road(states, day: 10).sparseState == nil)
    }

    @Test("REQ-GRAMMAR-004: an empty Service offers two entrances, Track an operation first, then Track several")
    func emptyService() throws {
        let sparse = try #require(ServiceViewState(hasLoaded: true).sparseState)

        #expect(Composition(sparse) == Composition(
            glyph: "wrench.and.screwdriver",
            headline: "tile.service.empty.headline",
            sentence: "service.empty.detail",
            actions: [.track, .trackSeveral]
        ))
    }

    @Test("REQ-GRAMMAR-004: Service is not sparse before its first load or once something is tracked")
    func serviceSparseOnlyWhenKnownEmpty() {
        let tracked = Fix.states([Fix.oil10k], [], currentKm: 50000, day: 10)

        #expect(ServiceViewState().sparseState == nil, "before the first load nothing is known (core C2)")
        #expect(ServiceViewState(operations: tracked, hasLoaded: true).sparseState == nil)
    }

    @Test("REQ-GRAMMAR-004: an empty History shows its glyph, headline, one sentence and the one Add event action")
    func emptyHistory() throws {
        let sparse = try #require(HistoryViewState().sparseState)

        #expect(Composition(sparse) == Composition(
            glyph: "clock.arrow.circlepath",
            headline: "tile.history.empty.headline",
            sentence: "tile.history.empty.detail",
            actions: [.add]
        ))
    }

    @Test("REQ-GRAMMAR-004: History with one event is not sparse")
    func historyWithEventIsNotSparse() {
        let wash = HistoryEvent(vehicleID: Fix.vehicleID, kind: .carWash, date: Fix.date(2))
        let state = HistoryViewState(timeline: HistoryTimeline(events: [wash], completions: []))

        #expect(state.sparseState == nil)
    }

    @Test("REQ-GRAMMAR-004: empty active Notes show the glyph, headline, one sentence and the one New note action")
    func emptyNotes() throws {
        let sparse = try #require(NotesViewState().sparseState)

        #expect(Composition(sparse) == Composition(
            glyph: "note.text",
            headline: "tile.notes.empty.headline",
            sentence: "tile.notes.empty.detail",
            actions: [.add]
        ))
    }

    @Test("REQ-GRAMMAR-004: an empty archive keeps today's headline alone; notes in the other scope do not count")
    func emptyArchive() throws {
        let state = NotesViewState(notes: [DomainFixtures.Notes.rawThought], scope: .archived)
        let sparse = try #require(state.sparseState)

        #expect(Composition(sparse) == Composition<NotesEmptyAction>(
            glyph: "note.text",
            headline: "notes.archived.empty"
        ))
        #expect(NotesViewState(notes: [DomainFixtures.Notes.rawThought]).sparseState == nil)
    }

    @Test("REQ-GRAMMAR-004: no sparse state offers more than two actions")
    func atMostTwoActions() throws {
        let counts = try [
            #require(road().sparseState).actions.count,
            #require(ServiceViewState(hasLoaded: true).sparseState).actions.count,
            #require(HistoryViewState().sparseState).actions.count,
            #require(NotesViewState().sparseState).actions.count,
            #require(NotesViewState(scope: .archived).sparseState).actions.count,
        ]

        #expect(counts.allSatisfy { $0 <= EmptyStateContent<Int>.actionLimit })
    }

    /// A metric needs a value in its text; every sparse line is a fixed sentence in every language.
    @Test("REQ-GRAMMAR-004: no sparse headline or sentence carries a value placeholder", arguments: locales)
    func noPlaceholderMetric(locale: String) throws {
        let url = try #require(Bundle.main.url(forResource: locale, withExtension: "lproj"))
        let bundle = try #require(Bundle(url: url))
        let lines = try [
            Self.lines(#require(road().sparseState)),
            Self.lines(#require(ServiceViewState(hasLoaded: true).sparseState)),
            Self.lines(#require(HistoryViewState().sparseState)),
            Self.lines(#require(NotesViewState().sparseState)),
            Self.lines(#require(NotesViewState(scope: .archived).sparseState)),
        ].flatMap(\.self)

        for key in lines {
            let format = bundle.localizedString(forKey: key, value: nil, table: nil)
            #expect(format != key, "\(key) missing in \(locale)")
            #expect(!format.contains("%"), "\(key) in \(locale) interpolates a value")
        }
    }

    private static func lines(_ content: EmptyStateContent<some Hashable>) -> [String] {
        [content.headline.key] + (content.sentence.map { [$0.key] } ?? [])
    }
}
