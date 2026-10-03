import Foundation

public struct Board: Codable, Equatable, Sendable {
    public var id: String
    public var version: Int
    public var columns: [BoardColumn]
    public var cards: [BoardCard]

    public init(id: String, version: Int = 0, columns: [BoardColumn], cards: [BoardCard] = []) {
        self.id = id
        self.version = version
        self.columns = columns
        self.cards = cards
    }

    public var sortedColumns: [BoardColumn] { columns.sorted { $0.order < $1.order } }
    public func cards(in columnID: String) -> [BoardCard] {
        cards.filter { $0.columnId == columnID }.sorted { $0.order < $1.order }
    }
}
