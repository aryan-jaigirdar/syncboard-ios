public struct AppliedChange: Codable, Equatable, Sendable {
    public var version: Int
    public var op: BoardOperation
    public var actorId: String
    public var opId: String

    public init(version: Int, op: BoardOperation, actorId: String, opId: String) {
        self.version = version
        self.op = op
        self.actorId = actorId
        self.opId = opId
    }
}
