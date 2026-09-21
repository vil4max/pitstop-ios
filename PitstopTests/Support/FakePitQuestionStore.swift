import Foundation
@testable import Pitstop

/// In-memory double. It applies commands exactly as the real store does and validates them against its
/// registry; SwiftData behaviour itself is covered by `SwiftDataPitQuestionStoreTests`.
actor FakePitQuestionStore: PitQuestionStateStore {
    private(set) var states: [String: PitQuestionState] = [:]
    private(set) var executed: [PitQuestionCommand] = []
    private let registry: PitQuestionRegistry
    private var fails = false
    private var failsCommands = false

    init(registry: PitQuestionRegistry) {
        self.registry = registry
    }

    func failEverything() {
        fails = true
    }

    /// Reads still succeed; only writes fail.
    func failCommands() {
        failsCommands = true
    }

    func questionStates() throws(PitQuestionStoreError) -> [PitQuestionState] {
        guard !fails else { throw .storageFailure }
        return states.values.sorted { $0.questionID < $1.questionID }
    }

    @discardableResult
    func execute(_ command: PitQuestionCommand, now: Date) throws(PitQuestionStoreError) -> PitQuestionState {
        guard !fails, !failsCommands else { throw .storageFailure }
        guard registry.definition(for: command.questionID) != nil else { throw .unknownQuestion }
        let next = try command.applied(to: states[command.questionID], now: now)
        states[command.questionID] = next
        executed.append(command)
        return next
    }
}

extension PitQuestionViewModel {
    /// For tests whose activity does not change while the question is evaluated.
    func evaluate(context: VisibleFeature, activity: PitActivity) async -> Bool {
        await evaluate(context: context) { activity }
    }
}
