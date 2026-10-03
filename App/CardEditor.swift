import SwiftUI
import SyncboardCore

struct CardEditor: View {
    let card: BoardCard
    let board: Board
    let save: (String, String, String) -> Bool
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var description: String
    @State private var column: String
    @State private var saveFailed = false

    init(card: BoardCard, board: Board, save: @escaping (String, String, String) -> Bool) {
        self.card = card
        self.board = board
        self.save = save
        _title = State(initialValue: card.title)
        _description = State(initialValue: card.description)
        _column = State(initialValue: card.columnId)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Card") {
                    TextField("Title", text: $title, axis: .vertical).accessibilityIdentifier("card-title")
                    TextField("Description", text: $description, axis: .vertical).lineLimit(4...12)
                }
                if saveFailed { Text("The draft could not be saved. It is kept in this editor.").foregroundStyle(.red) }
                Section("Move to column") {
                    Picker("Column", selection: $column) {
                        ForEach(board.sortedColumns) { Text($0.title).tag($0.id) }
                    }
                }
                Section {
                    Label("Saved locally first. Synced when connected.", systemImage: "internaldrive")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(card.title.isEmpty ? "New card" : "Edit card")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if save(title, description, column) { dismiss() } else { saveFailed = true }
                    }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || title.utf16.count > 300 || description.utf16.count > 5000 || column.isEmpty)
                }
            }
        }
    }
}
