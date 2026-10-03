import Foundation

public enum BoardError: String, Error, Sendable {
    case invalidOperation, cardNotFound, columnNotFound, duplicateID, limitExceeded, versionGap
}

/// A native port of the authoritative reducer, including remove-then-insert ordering.
public enum BoardReducer {
    public static func apply(_ op: BoardOperation, to original: Board) throws -> Board {
        var board = original
        let cardIndex = board.cards.firstIndex { $0.id == op.cardId }
        let columnIndex = board.columns.firstIndex { $0.id == op.columnId }
        switch op.type {
        case "createCard":
            guard let id = op.cardId, let column = op.columnId, let title = op.title else { throw BoardError.invalidOperation }
            try validate(title: title, description: op.description)
            guard board.columns.contains(where: { $0.id == column }) else { throw BoardError.columnNotFound }
            guard !board.cards.contains(where: { $0.id == id }) else { throw BoardError.duplicateID }
            guard board.cards.count < 2000 else { throw BoardError.limitExceeded }
            var ids = board.cards(in: column).map(\.id)
            ids.insert(id, at: clamped(op.index ?? ids.count, count: ids.count))
            board.cards.append(BoardCard(id: id, columnId: column, title: title, description: op.description ?? "", order: 0))
            normalize(&board, column: column, ids: ids)
        case "editCard":
            guard let cardIndex else { throw BoardError.cardNotFound }
            guard op.title != nil || op.description != nil else { throw BoardError.invalidOperation }
            if let title = op.title { try validate(title: title, description: nil); board.cards[cardIndex].title = title }
            if let description = op.description {
                guard description.utf16.count <= 5000 else { throw BoardError.invalidOperation }
                board.cards[cardIndex].description = description
            }
        case "moveCard":
            guard let cardIndex else { throw BoardError.cardNotFound }
            guard let destination = op.toColumnId, let index = op.toIndex else { throw BoardError.invalidOperation }
            guard board.columns.contains(where: { $0.id == destination }) else { throw BoardError.columnNotFound }
            let source = board.cards[cardIndex].columnId
            let id = board.cards[cardIndex].id
            var ids = board.cards(in: destination).filter { $0.id != id }.map(\.id)
            ids.insert(id, at: clamped(index, count: ids.count))
            board.cards[cardIndex].columnId = destination
            normalize(&board, column: destination, ids: ids)
            if source != destination { normalize(&board, column: source, ids: board.cards(in: source).map(\.id)) }
        case "deleteCard":
            guard let cardIndex else { throw BoardError.cardNotFound }
            let source = board.cards[cardIndex].columnId
            board.cards.remove(at: cardIndex)
            normalize(&board, column: source, ids: board.cards(in: source).map(\.id))
        case "duplicateCard":
            guard let cardIndex else { throw BoardError.cardNotFound }
            guard let id = op.newCardId else { throw BoardError.invalidOperation }
            guard !board.cards.contains(where: { $0.id == id }) else { throw BoardError.duplicateID }
            guard board.cards.count < 2000 else { throw BoardError.limitExceeded }
            var card = board.cards[cardIndex]
            var ids = board.cards(in: card.columnId).map(\.id)
            let insertion = (ids.firstIndex(of: card.id) ?? 0) + 1
            card.id = id
            ids.insert(id, at: insertion)
            board.cards.append(card)
            normalize(&board, column: card.columnId, ids: ids)
        case "setCardLabel":
            guard let cardIndex else { throw BoardError.cardNotFound }
            guard let label = op.label, ["none", "red", "orange", "yellow", "green", "blue", "purple"].contains(label) else { throw BoardError.invalidOperation }
            board.cards[cardIndex].label = label == "none" ? nil : label
        case "createColumn":
            guard let id = op.columnId, let title = op.title else { throw BoardError.invalidOperation }
            try validate(title: title, description: nil)
            guard !board.columns.contains(where: { $0.id == id }) else { throw BoardError.duplicateID }
            guard board.columns.count < 100 else { throw BoardError.limitExceeded }
            var columns = board.sortedColumns
            columns.insert(BoardColumn(id: id, title: title, order: 0), at: clamped(op.index ?? columns.count, count: columns.count))
            board.columns.append(BoardColumn(id: id, title: title, order: 0))
            normalizeColumns(&board, ids: columns.map(\.id))
        case "renameColumn":
            guard let columnIndex else { throw BoardError.columnNotFound }
            guard let title = op.title else { throw BoardError.invalidOperation }
            try validate(title: title, description: nil)
            board.columns[columnIndex].title = title
        case "deleteColumn":
            guard let columnIndex else { throw BoardError.columnNotFound }
            let id = board.columns.remove(at: columnIndex).id
            board.cards.removeAll { $0.columnId == id }
            normalizeColumns(&board, ids: board.sortedColumns.map(\.id))
        case "reorderColumn":
            guard let columnIndex else { throw BoardError.columnNotFound }
            guard let index = op.toIndex else { throw BoardError.invalidOperation }
            let column = board.columns[columnIndex]
            var columns = board.sortedColumns.filter { $0.id != column.id }
            columns.insert(column, at: clamped(index, count: columns.count))
            normalizeColumns(&board, ids: columns.map(\.id))
        default: throw BoardError.invalidOperation
        }
        return board
    }

    private static func validate(title: String, description: String?) throws {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, title.utf16.count <= 300,
              (description?.utf16.count ?? 0) <= 5000 else { throw BoardError.invalidOperation }
    }
    private static func clamped(_ index: Int, count: Int) -> Int { max(0, min(index, count)) }
    private static func normalizeColumns(_ board: inout Board, ids: [String]) {
        for index in board.columns.indices { board.columns[index].order = ids.firstIndex(of: board.columns[index].id) ?? board.columns[index].order }
    }
    private static func normalize(_ board: inout Board, column: String, ids: [String]) {
        for index in board.cards.indices where board.cards[index].columnId == column {
            board.cards[index].order = ids.firstIndex(of: board.cards[index].id) ?? board.cards[index].order
        }
    }
}
