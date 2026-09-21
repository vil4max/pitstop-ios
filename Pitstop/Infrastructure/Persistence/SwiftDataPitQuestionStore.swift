import Foundation
import SwiftData

private typealias Record = PitstopSchemaV2.PitQuestionStateRecord

/// Shares the car memory's container and file, so one migration plan covers both; it is a separate
/// actor because question state has its own protocol and write path (ADR 0016).
actor SwiftDataPitQuestionStore: PitQuestionStateStore, ModelActor {
    nonisolated let modelContainer: ModelContainer
    nonisolated let modelExecutor: any ModelExecutor
    private let registry: PitQuestionRegistry

    init(modelContainer: ModelContainer, registry: PitQuestionRegistry) {
        self.modelContainer = modelContainer
        modelExecutor = DefaultSerialModelExecutor(modelContext: ModelContext(modelContainer))
        self.registry = registry
    }

    func questionStates() throws(PitQuestionStoreError) -> [PitQuestionState] {
        do {
            let sort = SortDescriptor(\Record.questionID)
            return try modelContext.fetch(FetchDescriptor(sortBy: [sort])).map(\.domain)
        } catch {
            throw .storageFailure
        }
    }

    @discardableResult
    func execute(_ command: PitQuestionCommand, now: Date) throws(PitQuestionStoreError) -> PitQuestionState {
        guard registry.definition(for: command.questionID) != nil else { throw .unknownQuestion }
        do {
            let record = try existingRecord(for: command.questionID)
            let next = try command.applied(to: record?.domain, now: now)
            if let record {
                record.update(from: next)
            } else {
                modelContext.insert(Record(next))
            }
            try modelContext.save()
            return next
        } catch {
            modelContext.rollback()
            throw (error as? PitQuestionStoreError) ?? .storageFailure
        }
    }

    private func existingRecord(for questionID: String) throws -> Record? {
        try modelContext.fetch(FetchDescriptor<Record>(predicate: #Predicate { $0.questionID == questionID })).first
    }
}

extension PitstopSchemaV2.PitQuestionStateRecord {
    convenience init(_ state: PitQuestionState) {
        self.init(
            questionID: state.questionID,
            resolution: state.resolution.rawValue,
            lastAskedAt: state.lastAskedAt,
            lastDismissedAt: state.lastDismissedAt,
            resolvedAt: state.resolvedAt
        )
    }

    var domain: PitQuestionState {
        PitQuestionState(
            questionID: questionID,
            // An unreadable resolution must not make Pit ask again, so it reads as deferred (core C3).
            resolution: PitQuestion.Resolution(rawValue: resolution) ?? .deferred,
            lastAskedAt: lastAskedAt,
            lastDismissedAt: lastDismissedAt,
            resolvedAt: resolvedAt
        )
    }

    func update(from state: PitQuestionState) {
        resolution = state.resolution.rawValue
        lastAskedAt = state.lastAskedAt
        lastDismissedAt = state.lastDismissedAt
        resolvedAt = state.resolvedAt
    }
}
