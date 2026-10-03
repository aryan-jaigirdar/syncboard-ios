import Foundation
import Testing
@testable import SyncboardCore

private func fixture() -> Board {
    Board(id: "board123", columns: [BoardColumn(id: "todo1234", title: "To do", order: 0), BoardColumn(id: "done1234", title: "Done", order: 1)],
          cards: [BoardCard(id: "card1234", columnId: "todo1234", title: "Ship", order: 0), BoardCard(id: "card5678", columnId: "todo1234", title: "Test", order: 1)])
}

@Test func offlineEditsSurviveRelaunchWithStableIDs() throws {
    let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let store = JournalStore(file: folder.appending(path: "journal.json"))
    var journal = SyncJournal(confirmed: fixture())
    try journal.enqueue(BoardOperation(type: "editCard", cardId: "card1234", title: "Ship native app"))
    try store.save(journal)
    let reopened = try store.load()
    #expect(reopened == journal)
    #expect(reopened.confirmed?.cards[0].title == "Ship")
    #expect(reopened.visible?.cards[0].title == "Ship native app")
}

@Test func receiptAckAfterFullSnapshotDoesNotOverwriteLaterEdit() throws {
    var journal = SyncJournal(clientID: "client123", confirmed: fixture())
    try journal.enqueue(BoardOperation(type: "editCard", cardId: "card1234", title: "My old change"))
    let opID = try #require(journal.pending.first?.opId)
    var newer = fixture()
    newer.version = 4
    newer.cards[0].title = "Collaborator's newer change"
    try journal.snapshot(newer)
    journal.acknowledge(opID)
    #expect(journal.pending.isEmpty)
    #expect(journal.visible?.cards[0].title == "Collaborator's newer change")
}

@Test func acceptedChangeDropsOnlyMatchingActorPendingEdit() throws {
    var journal = SyncJournal(clientID: "client123", confirmed: fixture())
    let op = BoardOperation(type: "editCard", cardId: "card1234", title: "Ready")
    try journal.enqueue(op)
    let opID = try #require(journal.pending.first?.opId)
    try journal.accept(AppliedChange(version: 1, op: op, actorId: "client123", opId: opID))
    try journal.accept(AppliedChange(version: 1, op: op, actorId: "client123", opId: opID))
    #expect(journal.pending.isEmpty)
    #expect(journal.confirmed?.version == 1)
}

@Test func rejectedDraftRemainsRecoverableWhenCardWasDeleted() throws {
    var journal = SyncJournal(confirmed: fixture())
    try journal.enqueue(BoardOperation(type: "editCard", cardId: "card1234", description: "Keep this draft"))
    let id = try #require(journal.pending.first?.opId)
    var remote = fixture()
    remote.cards.removeFirst()
    try journal.snapshot(remote)
    #expect(journal.pending.count == 1)
    journal.reject(id, reason: "card_not_found")
    #expect(journal.pending.isEmpty)
    #expect(journal.rejected.first?.change.op.description == "Keep this draft")
}

@Test(arguments: [
    BoardOperation(type: "moveCard", cardId: "card1234", toColumnId: "done1234", toIndex: 2),
    BoardOperation(type: "setCardLabel", cardId: "card1234", label: "purple"),
    BoardOperation(type: "createCard", cardId: "new12345", columnId: "todo1234", title: "Keep this draft", description: "A note\nwith another line")
])
func exportedRejectedDraftKeepsCompleteIntent(operation: BoardOperation) throws {
    let original = RejectedChange(change: PendingChange(opId: "intent1234", op: operation), reason: "column_not_found")
    let exported = try original.exportJSON()
    let recovered = try JSONDecoder().decode(RejectedChange.self, from: Data(exported.utf8))
    #expect(recovered == original)
}

@Test func outOfOrderVersionNeedsSnapshotInsteadOfApplyingWrongState() throws {
    var journal = SyncJournal(confirmed: fixture())
    #expect(throws: BoardError.versionGap) {
        try journal.accept(AppliedChange(version: 3, op: BoardOperation(type: "deleteCard", cardId: "card1234"), actorId: "other123", opId: "op123456"))
    }
    #expect(journal.confirmed == fixture())
}

@Test func cardMoveUsesRemoveThenInsertAndNormalizesBothColumns() throws {
    let moved = try BoardReducer.apply(BoardOperation(type: "moveCard", cardId: "card1234", toColumnId: "done1234", toIndex: 999), to: fixture())
    #expect(moved.cards(in: "todo1234").map(\.order) == [0])
    #expect(moved.cards(in: "done1234").map(\.id) == ["card1234"])
    let reordered = try BoardReducer.apply(BoardOperation(type: "moveCard", cardId: "card1234", toColumnId: "todo1234", toIndex: 1), to: fixture())
    #expect(reordered.cards(in: "todo1234").map(\.id) == ["card5678", "card1234"])
}

@Test func limitsMatchJavaScriptUTF16AndValidation() throws {
    #expect(throws: BoardError.invalidOperation) {
        try BoardReducer.apply(BoardOperation(type: "editCard", cardId: "card1234", title: String(repeating: "🙂", count: 151)), to: fixture())
    }
    #expect(throws: BoardError.invalidOperation) {
        try BoardReducer.apply(BoardOperation(type: "createCard", cardId: "new12345", columnId: "todo1234", title: "  "), to: fixture())
    }
}

@Test func remotePlaintextAndCredentialURLsAreRejected() throws {
    #expect(throws: BoardError.invalidOperation) { try ConnectionSettings(server: "http://example.com", boardID: "board123") }
    #expect(throws: BoardError.invalidOperation) { try ConnectionSettings(server: "https://user:password@example.com", boardID: "board123") }
    let local = try ConnectionSettings(server: "http://127.0.0.1:3090", boardID: "board123")
    #expect(local.socketURL.absoluteString == "ws://127.0.0.1:3090/ws")
    #expect(local.webURL.absoluteString == "http://127.0.0.1:3090/b/board123")
}

@Test func everyWireOperationMatchesAuthoritativeServerContract() throws {
    struct Contract: Decodable {
        let initialState: Board
        let ops: [AppliedChange]
        let expectedState: Board
    }
    let url = try #require(Bundle.module.url(forResource: "sync-contract", withExtension: "json"))
    let contract = try JSONDecoder().decode(Contract.self, from: Data(contentsOf: url))
    var journal = SyncJournal(confirmed: contract.initialState)
    for op in contract.ops { try journal.accept(op) }
    #expect(journal.confirmed == contract.expectedState)
}
