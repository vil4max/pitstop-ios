import Foundation
@testable import Pitstop

/// Fails one kind of file operation, as a full disk or a locked file would.
struct FailingStoreFiles: StoreFileOperations {
    enum Step: Sendable {
        case copyOf(suffix: String)
        case marker
        /// Deleting anything under this directory fails.
        case removeUnder(URL)
        /// Renaming a file whose name ends with this suffix fails.
        case moveOf(suffix: String)
    }

    let step: Step
    private let base = FileManagerStoreFiles()

    init(failing step: Step) {
        self.step = step
    }

    func fileExists(at url: URL) -> Bool {
        base.fileExists(at: url)
    }

    func identity(of url: URL) -> StoreFileIdentity? {
        base.identity(of: url)
    }

    func createDirectory(at url: URL) throws {
        try base.createDirectory(at: url)
    }

    func copyItem(at source: URL, to destination: URL) throws {
        if case let .copyOf(suffix) = step, source.path.hasSuffix("Pitstop.store\(suffix)") {
            throw CocoaError(.fileWriteOutOfSpace)
        }
        try base.copyItem(at: source, to: destination)
    }

    func moveReplacing(at source: URL, to destination: URL) throws {
        try base.moveReplacing(at: source, to: destination)
    }

    func moveItem(at source: URL, to destination: URL) throws {
        if case let .moveOf(suffix) = step, source.path.hasSuffix(suffix) {
            throw CocoaError(.fileWriteNoPermission)
        }
        try base.moveItem(at: source, to: destination)
    }

    func removeItem(at url: URL) throws {
        if case let .removeUnder(directory) = step, url.path.hasPrefix(directory.path) {
            throw CocoaError(.fileWriteNoPermission)
        }
        try base.removeItem(at: url)
    }

    func write(_ data: Data, to url: URL) throws {
        if case .marker = step, url.lastPathComponent == ".Pitstop.store.moved" {
            throw CocoaError(.fileWriteNoPermission)
        }
        try base.write(data, to: url)
    }

    func contents(of url: URL) -> Data? {
        base.contents(of: url)
    }
}
