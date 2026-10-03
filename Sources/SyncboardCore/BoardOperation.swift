import Foundation

/// Names and optional fields match syncboard's public JSON intent protocol.
public struct BoardOperation: Codable, Equatable, Sendable {
    public var type: String
    public var cardId: String?
    public var columnId: String?
    public var title: String?
    public var description: String?
    public var index: Int?
    public var toColumnId: String?
    public var toIndex: Int?
    public var newCardId: String?
    public var label: String?

    public init(type: String, cardId: String? = nil, columnId: String? = nil, title: String? = nil,
                description: String? = nil, index: Int? = nil, toColumnId: String? = nil,
                toIndex: Int? = nil, newCardId: String? = nil, label: String? = nil) {
        self.type = type
        self.cardId = cardId
        self.columnId = columnId
        self.title = title
        self.description = description
        self.index = index
        self.toColumnId = toColumnId
        self.toIndex = toIndex
        self.newCardId = newCardId
        self.label = label
    }

    public static func newID() -> String { UUID().uuidString.replacingOccurrences(of: "-", with: "") }
}
