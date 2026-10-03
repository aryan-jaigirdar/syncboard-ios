import Foundation

/// Atomic replacement means a process exit cannot leave a partly written outbox.
/// Each server and board gets a distinct file; board links are never sent elsewhere.
public struct JournalStore: Sendable {
    public let file: URL
    public init(file: URL) { self.file = file }

    public func load() throws -> SyncJournal {
        guard FileManager.default.fileExists(atPath: file.path) else { return SyncJournal() }
        return try JSONDecoder().decode(SyncJournal.self, from: Data(contentsOf: file))
    }

    public func save(_ journal: SyncJournal) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(journal).write(to: file, options: .atomic)
    }
}
