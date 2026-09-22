import Darwin
import Foundation
import SwiftData

/// Size and modification date of one file: enough to tell whether a file is still the one the move copied.
struct StoreFileIdentity: Codable, Hashable, Sendable {
    let size: Int64
    let modified: Double
}

/// The file operations the store move needs, so a test can make one of them fail part way.
protocol StoreFileOperations: Sendable {
    func fileExists(at url: URL) -> Bool
    func identity(of url: URL) -> StoreFileIdentity?
    func createDirectory(at url: URL) throws
    func copyItem(at source: URL, to destination: URL) throws
    /// Renames, replacing an existing destination in one step (POSIX `rename`).
    func moveReplacing(at source: URL, to destination: URL) throws
    /// Renames; fails when the destination exists.
    func moveItem(at source: URL, to destination: URL) throws
    func removeItem(at url: URL) throws
    func write(_ data: Data, to url: URL) throws
    func contents(of url: URL) -> Data?
}

struct FileManagerStoreFiles: StoreFileOperations {
    func fileExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    func identity(of url: URL) -> StoreFileIdentity? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = (attributes[.size] as? NSNumber)?.int64Value,
              let modified = attributes[.modificationDate] as? Date
        else { return nil }
        return StoreFileIdentity(size: size, modified: modified.timeIntervalSinceReferenceDate)
    }

    func createDirectory(at url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    func copyItem(at source: URL, to destination: URL) throws {
        try FileManager.default.copyItem(at: source, to: destination)
    }

    func moveReplacing(at source: URL, to destination: URL) throws {
        guard Darwin.rename(source.path, destination.path) == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
    }

    func moveItem(at source: URL, to destination: URL) throws {
        try FileManager.default.moveItem(at: source, to: destination)
    }

    func removeItem(at url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }

    func write(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
    }

    func contents(of url: URL) -> Data? {
        try? Data(contentsOf: url)
    }
}

/// Moves the car memory from the app's container into the App Group container, once, before anything
/// opens it (ADR 0036). TestFlight testers hold real stores of schema V2 to V4 there, so the move never
/// destroys: it copies, proves the copy opens, marks the group store as the one to use, and only then
/// removes the old files. Any failure before the mark keeps the old store, and the next launch tries again.
///
/// The group marker is the single source of truth. With it, the group store is the car memory. It also
/// records the size and date of every old file it copied: a file still at the old location is deleted only
/// when it is exactly what was copied, and anything else (a downgraded build may have written there) is
/// renamed to a dated backup beside it, never deleted and never merged.
struct StoreRelocation {
    enum Outcome: Hashable, Sendable {
        /// No old store: the car memory starts in the group container.
        case freshInstall
        case alreadyMoved
        case moved
        /// Old files that were exactly the copied store were deleted.
        case leftoverRemoved
        /// Old files that differ from the copied store were renamed to this dated backup and kept.
        case leftoverBackedUp(URL)
        /// Old files that differ could not be renamed; they stay untouched and the next launch retries.
        case leftoverKept
        /// No App Group container and no earlier move: the old location stays in use.
        case groupUnavailable
        /// No App Group container although the car memory was moved there: the old location is not the
        /// car memory, so nothing durable is opened.
        case groupUnavailableAfterMove
        /// A step failed; the old store is untouched and stays in use until the next launch retries.
        case keptLegacy(Failure)
    }

    enum Failure: Hashable, Sendable {
        case copy
        case verify
        case marker
    }

    /// The group marker's content.
    struct MoveRecord: Codable, Hashable, Sendable {
        /// Identity of each old file that was copied, keyed by its SQLite suffix ("", "-wal", "-shm").
        var legacyFiles: [String: StoreFileIdentity]
    }

    let legacyStore: URL
    let groupStore: URL?
    var files: any StoreFileOperations = FileManagerStoreFiles()
    /// Opens the copy under the current schema and migration plan and reads from it.
    var verify: (URL) throws -> Void = Self.openAndRead
    var now: () -> Date = Date.init

    /// Returns the store the app should open, or `nil` when no durable store may be opened, and what
    /// happened. Never throws: every failure keeps a store that exists.
    func prepare() -> (store: URL?, outcome: Outcome) {
        guard let groupStore else {
            if files.fileExists(at: StoreLocation.inGroupMarkerURL(forLegacy: legacyStore)) {
                return (nil, .groupUnavailableAfterMove)
            }
            return (legacyStore, .groupUnavailable)
        }
        let marker = StoreLocation.movedMarkerURL(for: groupStore)
        if files.fileExists(at: marker) {
            markInGroup()
            return (groupStore, settleLeftover(marker: marker))
        }
        guard legacyFiles.contains(where: files.fileExists) else {
            do {
                try files.createDirectory(at: groupStore.deletingLastPathComponent())
                try write(MoveRecord(legacyFiles: [:]), to: marker)
            } catch {
                // The old location works too, and the next launch moves whatever was saved there.
                return (legacyStore, .keptLegacy(.marker))
            }
            markInGroup()
            return (groupStore, .freshInstall)
        }
        let record = MoveRecord(legacyFiles: identities())
        if let failure = copyAndMark(to: groupStore, marker: marker, record: record) {
            removeUnmarkedGroupFiles(of: groupStore)
            return (legacyStore, .keptLegacy(failure))
        }
        // Without the in-group mark the old files stay as the fallback; the next launch writes it and
        // then deletes them, because they still match the record.
        if markInGroup() {
            for file in legacyFiles where files.fileExists(at: file) {
                try? files.removeItem(at: file)
            }
        }
        return (groupStore, .moved)
    }

    private var legacyFiles: [URL] {
        StoreLocation.files(of: legacyStore)
    }

    private func identities() -> [String: StoreFileIdentity] {
        var result: [String: StoreFileIdentity] = [:]
        for (suffix, file) in zip(StoreLocation.sidecarSuffixes, legacyFiles) {
            result[suffix] = files.identity(of: file)
        }
        return result
    }

    private func copyAndMark(to groupStore: URL, marker: URL, record: MoveRecord) -> Failure? {
        do {
            try files.createDirectory(at: groupStore.deletingLastPathComponent())
            try copyIntoPlace(groupStore)
        } catch {
            return .copy
        }
        do {
            try verify(groupStore)
        } catch {
            return .verify
        }
        do {
            try write(record, to: marker)
        } catch {
            return .marker
        }
        return nil
    }

    /// Copies under names no earlier attempt used, then renames each over its final name. A rename
    /// replaces a stale file from an interrupted attempt even when that file cannot be deleted, so a stale
    /// copy never blocks the move. A sidecar the old store lacks is written empty, which SQLite reads as
    /// no pending log, so a stale `-wal` can never be replayed into the new copy.
    private func copyIntoPlace(_ groupStore: URL) throws {
        let token = UUID().uuidString
        let staged = StoreLocation.files(of: groupStore).map { URL(fileURLWithPath: "\($0.path).incoming-\(token)") }
        do {
            for (source, stage) in zip(legacyFiles, staged) {
                if files.fileExists(at: source) {
                    try files.copyItem(at: source, to: stage)
                } else {
                    try files.write(Data(), to: stage)
                }
            }
            for (stage, destination) in zip(staged, StoreLocation.files(of: groupStore)) {
                try files.moveReplacing(at: stage, to: destination)
            }
        } catch {
            for stage in staged where files.fileExists(at: stage) {
                try? files.removeItem(at: stage)
            }
            throw error
        }
    }

    /// Best effort: without a group marker these files are never read, and the next copy replaces them.
    private func removeUnmarkedGroupFiles(of groupStore: URL) {
        for file in StoreLocation.files(of: groupStore) where files.fileExists(at: file) {
            try? files.removeItem(at: file)
        }
    }

    @discardableResult
    private func markInGroup() -> Bool {
        let marker = StoreLocation.inGroupMarkerURL(forLegacy: legacyStore)
        if files.fileExists(at: marker) {
            return true
        }
        do {
            try files.createDirectory(at: marker.deletingLastPathComponent())
            try files.write(Data(), to: marker)
            return true
        } catch {
            return false
        }
    }

    private func settleLeftover(marker: URL) -> Outcome {
        let present = zip(StoreLocation.sidecarSuffixes, legacyFiles).filter { files.fileExists(at: $0.1) }
        guard !present.isEmpty else { return .alreadyMoved }
        let record = files.contents(of: marker).flatMap { try? JSONDecoder().decode(MoveRecord.self, from: $0) }
        let isCopiedStore = present.allSatisfy { suffix, file in
            record?.legacyFiles[suffix].map { $0 == files.identity(of: file) } ?? false
        }
        if isCopiedStore {
            for (_, file) in present {
                try? files.removeItem(at: file)
            }
            return .leftoverRemoved
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let backup = URL(fileURLWithPath: "\(legacyStore.path).leftover-\(formatter.string(from: now()))")
        var moved: [(from: URL, to: URL)] = []
        do {
            for (suffix, file) in present {
                let destination = URL(fileURLWithPath: backup.path + suffix)
                try files.moveItem(at: file, to: destination)
                moved.append((file, destination))
            }
        } catch {
            // Put back what was renamed, so a store is never split between the old name and a backup.
            for (from, to) in moved.reversed() {
                try? files.moveItem(at: to, to: from)
            }
            return .leftoverKept
        }
        return .leftoverBackedUp(backup)
    }

    private func write(_ record: MoveRecord, to marker: URL) throws {
        try files.write(JSONEncoder().encode(record), to: marker)
    }

    /// Migrates the copy if it is older and proves the car record table can be read. The container is
    /// released before the app opens the same file for use.
    static func openAndRead(_ store: URL) throws {
        let container = try PersistenceContainer.make(storeURL: store)
        _ = try ModelContext(container).fetchCount(FetchDescriptor<PitstopSchemaV1.VehicleRecord>())
    }
}
