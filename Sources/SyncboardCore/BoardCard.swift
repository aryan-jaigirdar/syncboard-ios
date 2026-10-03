public struct BoardCard: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var columnId: String
    public var title: String
    public var description: String
    public var order: Int
    public var label: String?

    public init(id: String, columnId: String, title: String, description: String = "", order: Int, label: String? = nil) {
        self.id = id
        self.columnId = columnId
        self.title = title
        self.description = description
        self.order = order
        self.label = label
    }
}
