import Foundation
import SwiftData

enum PitstopMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [PitstopSchemaV1.self, PitstopSchemaV2.self, PitstopSchemaV3.self, PitstopSchemaV4.self]
    }

    static var stages: [MigrationStage] {
        // Each version only adds an entity, so no earlier row is transformed (ADR 0016, ADR 0032,
        // ADR 0035). A V1 store passes through every stage in turn.
        [
            .lightweight(fromVersion: PitstopSchemaV1.self, toVersion: PitstopSchemaV2.self),
            .lightweight(fromVersion: PitstopSchemaV2.self, toVersion: PitstopSchemaV3.self),
            .lightweight(fromVersion: PitstopSchemaV3.self, toVersion: PitstopSchemaV4.self),
        ]
    }
}

enum PersistenceContainer {
    /// `storeURL == nil` builds an in-memory container for tests and previews.
    static func make(storeURL: URL?) throws -> ModelContainer {
        let schema = Schema(versionedSchema: PitstopSchemaV4.self)
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
