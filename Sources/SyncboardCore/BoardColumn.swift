public struct BoardColumn: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var order: Int

    public init(id: String, title: String, order: Int) {
        self.id = id
        self.title = title
        self.order = order
    }
}
