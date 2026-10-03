import Foundation

public struct RejectedChange: Codable, Equatable, Identifiable, Sendable {
    public var change: PendingChange
    public var reason: String
    public var id: String { change.id }

    public init(change: PendingChange, reason: String) {
        self.change = change
        self.reason = reason
    }

    /// Preserve every field needed to recover a rejected card or column intent.
    public func exportJSON() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return String(decoding: try encoder.encode(self), as: UTF8.self)
    }
}
