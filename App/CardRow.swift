import SwiftUI
import SyncboardCore

struct CardRow: View {
    let card: BoardCard
    var body: some View {
        VStack(alignment: .leading) {
            if let label = card.label {
                Label(label.capitalized, systemImage: "tag.fill").font(.subheadline).foregroundStyle(.teal)
            }
            Text(card.title).font(.headline)
            if !card.description.isEmpty { Text(card.description).font(.body).foregroundStyle(.secondary).lineLimit(3) }
            Label("Edit or move", systemImage: "arrow.up.right").font(.subheadline).foregroundStyle(.secondary)
        }.padding(.vertical)
    }
}
