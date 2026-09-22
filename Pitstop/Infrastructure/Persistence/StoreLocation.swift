import Foundation

/// Where the car memory lives (ADR 0036). Compiled into the app and the widget extension, so both
/// resolve the same file from the same App Group.
enum StoreLocation {
    static let appGroupIdentifier = "group.dev.vil4max.pitstop"
    static let storeFileName = "Pitstop.store"
    /// SQLite keeps uncheckpointed writes in `-wal` and its index in `-shm`; a store is all three files.
    static let sidecarSuffixes = ["", "-wal", "-shm"]

    /// Before ADR 0036 the store lived in the app's own container, out of the widget's reach.
    static var legacyStoreURL: URL {
        URL.applicationSupportDirectory.appending(path: storeFileName)
    }

    /// `nil` when the App Group entitlement is missing: iOS returns no container for an unknown group.
    static func groupContainerURL(fileManager: FileManager = .default) -> URL? {
        fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }

    /// The store inside a group container. iOS creates only `Library/Caches` there, so the app creates
    /// `Library/Application Support` itself before the first write.
    static func groupStoreURL(in container: URL) -> URL {
        container.appending(path: "Library/Application Support").appending(path: storeFileName)
    }

    /// Written once the group store is the one to use: after a verified move, or on a fresh install.
    /// Readers wait for it, so the widget never opens a store that is still being copied.
    static func movedMarkerURL(for store: URL) -> URL {
        store.deletingLastPathComponent().appending(path: ".\(storeFileName).moved")
    }

    /// Left in the app's own container once the car memory lives in the group, so a build that cannot
    /// reach the group knows the emptied old location is not the car memory (ADR 0036).
    static func inGroupMarkerURL(forLegacy store: URL) -> URL {
        store.deletingLastPathComponent().appending(path: ".\(storeFileName).in-app-group")
    }

    static func files(of store: URL) -> [URL] {
        sidecarSuffixes.map { URL(fileURLWithPath: store.path + $0) }
    }

    /// The group store the widget may read, or `nil` while there is nothing finished to read.
    static func readableGroupStore(fileManager: FileManager = .default) -> URL? {
        guard let container = groupContainerURL(fileManager: fileManager) else { return nil }
        return readableStore(at: groupStoreURL(in: container), fileManager: fileManager)
    }

    static func readableStore(at store: URL, fileManager: FileManager = .default) -> URL? {
        guard fileManager.fileExists(atPath: movedMarkerURL(for: store).path),
              fileManager.fileExists(atPath: store.path)
        else { return nil }
        return store
    }
}
