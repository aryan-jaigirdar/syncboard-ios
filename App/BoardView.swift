import SwiftUI
import SyncboardCore

struct BoardView: View {
    @Bindable var session: BoardSession
    let close: () -> Void
    @State private var selectedColumn = ""
    @State private var editingCard: BoardCard?
    @State private var creatingCard = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading) {
                    Text("SHARED WORKSPACE").font(.subheadline.bold()).foregroundStyle(.teal)
                    Text("Move work forward.").font(.largeTitle.bold())
                    Text("One board across your phone and browser.").foregroundStyle(.secondary)
                }.padding(.vertical)
                HStack {
                    Label(session.status, systemImage: session.status == "Live" ? "antenna.radiowaves.left.and.right" : "wifi.slash")
                    Spacer()
                    Text("v\(session.journal.confirmed?.version ?? 0)").monospacedDigit().foregroundStyle(.secondary)
                }.accessibilityElement(children: .combine)
                if !session.journal.pending.isEmpty {
                    Label("\(session.journal.pending.count) \(session.journal.pending.count == 1 ? "change" : "changes") saved on this device", systemImage: "internaldrive")
                        .foregroundStyle(.secondary)
                }
                if !session.peers.isEmpty {
                    Label("\(session.peers.count) connected · \(session.peers.map(\.name).joined(separator: ", "))", systemImage: "person.2")
                        .foregroundStyle(.secondary)
                }
            }
            if let board = session.board {
                Section {
                    Picker("Column", selection: $selectedColumn) {
                        ForEach(board.sortedColumns) { column in
                            Text("\(column.title) (\(board.cards(in: column.id).count))").tag(column.id)
                        }
                    }
                }
                let cards = board.cards(in: selectedColumn)
                Section {
                    if cards.isEmpty {
                        ContentUnavailableView("Room for your next idea", systemImage: "rectangle.stack.badge.plus", description: Text("Add a card to start this column."))
                    }
                    ForEach(cards) { card in
                        Button { editingCard = card } label: {
                            CardRow(card: card)
                        }.buttonStyle(.plain)
                        .accessibilityHint("Opens the card editor and move controls")
                        .contextMenu {
                            Button("Edit card", systemImage: "pencil") { editingCard = card }
                            Menu("Move to", systemImage: "arrow.right") {
                                ForEach(board.sortedColumns.filter { $0.id != card.columnId }) { column in
                                    Button(column.title) {
                                        session.queue(BoardOperation(type: "moveCard", cardId: card.id, toColumnId: column.id, toIndex: board.cards(in: column.id).count))
                                    }
                                }
                            }
                        }
                    }
                    Button("Add card", systemImage: "plus") { creatingCard = true }
                        .disabled(selectedColumn.isEmpty || session.storageFailed)
                } header: { Text(board.columns.first { $0.id == selectedColumn }?.title ?? "Cards") }
            } else {
                Section {
                    ContentUnavailableView("Connect to load this board", systemImage: "network", description: Text("After the first connection, the board and pending edits are available offline."))
                }
            }
            if !session.journal.rejected.isEmpty {
                Section("Drafts that need attention") {
                    ForEach(session.journal.rejected) { rejected in
                        VStack(alignment: .leading) {
                            Label(rejected.reason.replacingOccurrences(of: "_", with: " "), systemImage: "exclamationmark.bubble")
                            Text(rejected.change.op.title ?? rejected.change.op.description ?? "Card or column change").foregroundStyle(.secondary)
                            ShareLink(item: draftText(rejected)) { Label("Export draft", systemImage: "square.and.arrow.up") }
                            Button("Dismiss saved draft", role: .destructive) { session.discardRejected(rejected.id) }
                        }
                    }
                }
            }
            Section {
                Toggle("Work offline", isOn: $session.workOffline).accessibilityIdentifier("offline-toggle")
                ShareLink(item: session.settings.webURL) { Label("Share board link", systemImage: "square.and.arrow.up") }
            } footer: {
                Text("Anyone with the board link can edit. When people edit the same field, the last change the server receives wins.")
            }
        }
        .navigationTitle("Syncboard")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { Button("Boards", systemImage: "chevron.left", action: close) }
            ToolbarItem(placement: .topBarTrailing) {
                Button("New card", systemImage: "plus") { creatingCard = true }
                    .disabled(session.board == nil || selectedColumn.isEmpty || session.storageFailed)
            }
        }
        .sheet(item: $editingCard) { card in
            if let board = session.board {
                CardEditor(card: card, board: board) { title, description, column in
                    var operations = [BoardOperation(type: "editCard", cardId: card.id, title: title, description: description)]
                    if column != card.columnId {
                        operations.append(BoardOperation(type: "moveCard", cardId: card.id, toColumnId: column, toIndex: board.cards(in: column).count))
                    }
                    return session.queue(operations)
                }
            }
        }
        .sheet(isPresented: $creatingCard) {
            if let board = session.board {
                CardEditor(card: BoardCard(id: BoardOperation.newID(), columnId: selectedColumn, title: "", order: 0), board: board) { title, description, column in
                    session.queue(BoardOperation(type: "createCard", cardId: BoardOperation.newID(), columnId: column, title: title, description: description))
                }
            }
        }
        .alert("Syncboard", isPresented: Binding(get: { session.errorMessage != nil }, set: { if !$0 { session.dismissError() } })) {
            Button("OK") { session.dismissError() }
        } message: { Text(session.errorMessage ?? "") }
        .task(id: session.workOffline) { await session.run() }
        .task(id: session.journal.pending.map(\.opId)) { await session.flush() }
        .onChange(of: session.board?.columns, initial: true) { _, columns in
            if !(columns ?? []).contains(where: { $0.id == selectedColumn }) { selectedColumn = columns?.sorted { $0.order < $1.order }.first?.id ?? "" }
        }
    }

    private func draftText(_ rejected: RejectedChange) -> String {
        (try? rejected.exportJSON()) ?? "Draft export failed. The original draft remains saved on this device."
    }
}
