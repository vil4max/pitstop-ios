import Foundation
import SwiftData

enum PitstopMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [PitstopSchemaV1.self, PitstopSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        // V2 only adds an entity, so no V1 row is transformed (ADR 0016).
        [.lightweight(fromVersion: PitstopSchemaV1.self, toVersion: PitstopSchemaV2.self)]
    }
}

enum PersistenceContainer {
    /// `storeURL == nil` builds an in-memory container for tests and previews.
    static func make(storeURL: URL?) throws -> ModelContainer {
        let schema = Schema(versionedSchema: PitstopSchemaV2.self)
        let configuration = if let storeURL {
            ModelConfiguration(schema: schema, url: storeURL)
        } else {
            ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        }
        return try ModelContainer(for: schema, migrationPlan: PitstopMigrationPlan.self, configurations: configuration)
    }

    static var defaultStoreURL: URL {
        URL.applicationSupportDirectory.appending(path: "Pitstop.store")
    }
}
