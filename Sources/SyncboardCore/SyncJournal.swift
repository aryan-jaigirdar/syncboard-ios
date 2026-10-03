public struct SyncJournal: Codable, Equatable, Sendable {
    public var clientID: String
    public private(set) var confirmed: Board?
    public private(set) var pending: [PendingChange]
    public private(set) var rejected: [RejectedChange]

    public init(clientID: String = BoardOperation.newID(), confirmed: Board? = nil) {
        self.clientID = clientID
        self.confirmed = confirmed
        pending = []
        rejected = []
    }

    public var visible: Board? {
        guard var board = confirmed else { return nil }
        for change in pending {
            // The server decides rejects. Never discard a draft while replaying a snapshot.
            if let next = try? BoardReducer.apply(change.op, to: board) { board = next }
        }
        return board
    }

    public mutating func enqueue(_ op: BoardOperation) throws {
        guard let board = visible else { throw BoardError.columnNotFound }
        guard pending.count < 500 else { throw BoardError.limitExceeded }
        _ = try BoardReducer.apply(op, to: board)
        pending.append(PendingChange(op: op))
    }

    public mutating func snapshot(_ board: Board) throws {
        if let confirmed, confirmed.id != board.id { throw BoardError.invalidOperation }
        confirmed = board
    }

    public mutating func accept(_ applied: AppliedChange) throws {
        guard let current = confirmed else { throw BoardError.versionGap }
        if applied.version > current.version {
            guard applied.version == current.version + 1 else { throw BoardError.versionGap }
            var next = try BoardReducer.apply(applied.op, to: current)
            next.version = applied.version
            confirmed = next
        }
        if applied.actorId == clientID { acknowledge(applied.opId) }
    }

    public mutating func acknowledge(_ opID: String) { pending.removeAll { $0.opId == opID } }

    public mutating func reject(_ opID: String, reason: String) {
        guard let change = pending.first(where: { $0.opId == opID }) else { return }
        rejected.append(RejectedChange(change: change, reason: reason))
        pending.removeAll { $0.opId == opID }
    }

    public mutating func dismissRejected(_ opID: String) { rejected.removeAll { $0.id == opID } }
}
