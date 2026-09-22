import Foundation
@testable import Pitstop

/// Feature view models over the in-memory store. Each suite passes its own fixed clock.
@MainActor
enum TestViewModels {
    static func service(_ store: FakeCarMemoryStore, now: Date) -> ServiceViewModel {
        ServiceViewModel(store: store, now: { now })
    }

    static func notes(_ store: FakeCarMemoryStore, now: Date) -> NotesViewModel {
        NotesViewModel(store: store, now: { now })
    }

    static func history(_ store: FakeCarMemoryStore, now: Date) -> HistoryViewModel {
        HistoryViewModel(store: store, now: { now })
    }

    static func carBoard(
        _ store: FakeCarMemoryStore,
        persistence: PersistenceMode = .durable,
        now: Date
    ) -> CarBoardViewModel {
        CarBoardViewModel(store: store, persistence: persistence, now: { now })
    }

    /// Typed capture through the rule-based interpreter, as the Pit sheet runs it without runtime AI.
    static func pitCapture(_ store: FakeCarMemoryStore, now: Date) -> PitCaptureViewModel {
        PitCaptureViewModel(
            pipeline: RememberPipeline(store: store, interpreter: RuleBasedInterpreter(), now: { now }),
            now: { now }
        )
    }
}
