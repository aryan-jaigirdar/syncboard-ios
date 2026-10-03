public struct PendingChange: Codable, Equatable, Identifiable, Sendable {
    public var opId: String
    public var op: BoardOperation
    public var id: String { opId }

    public init(opId: String = BoardOperation.newID(), op: BoardOperation) {
        self.opId = opId
        self.op = op
    }
}
