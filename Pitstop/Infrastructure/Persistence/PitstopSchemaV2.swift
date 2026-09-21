import Foundation
import SwiftData

/// V1 plus persisted Pit question state (DISC-001). The V1 record classes are reused unchanged, so
/// code that reads car memory keeps naming `PitstopSchemaV1` types.
///
/// Frozen since V3 reuses these classes: a change to a record needs a new schema version with its own
/// copy of the class (ADR 0016, ADR 0032, `PersistenceSchemaTests`).
enum PitstopSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        PitstopSchemaV1.models + [PitQuestionStateRecord.self]
    }

    /// One row per registered question that has been asked or resolved; no row means unresolved.
    @Model
    final class PitQuestionStateRecord {
        @Attribute(.unique) var questionID: String
        var resolution: String
        var lastAskedAt: Date?
        var lastDismissedAt: Date?
        var resolvedAt: Date?

        init(questionID: String, resolution: String, lastAskedAt: Date?, lastDismissedAt: Date?, resolvedAt: Date?) {
            self.questionID = questionID
            self.resolution = resolution
            self.lastAskedAt = lastAskedAt
            self.lastDismissedAt = lastDismissedAt
            self.resolvedAt = resolvedAt
        }
    }
}
