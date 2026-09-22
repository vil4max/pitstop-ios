import Foundation
@testable import Pitstop

/// On-disk SwiftData stores for relaunch and migration tests: a fresh path per test, removed afterwards
/// together with its SQLite sidecar files.
enum TestStore {
    static func temporaryURL() -> URL {
        URL.temporaryDirectory.appending(path: "pitstop-\(UUID().uuidString).store")
    }

    static func remove(at url: URL) {
        for suffix in ["", "-shm", "-wal"] {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + suffix))
        }
    }

    /// The production car memory store, on disk at `url` or in memory without one.
    static func carMemory(url: URL? = nil) throws -> SwiftDataCarMemoryStore {
        try SwiftDataCarMemoryStore(modelContainer: PersistenceContainer.make(storeURL: url))
    }
}
