import Foundation
import SwiftUI
import SyncboardCore

struct ConnectionView: View {
    @AppStorage("server") private var server = "http://127.0.0.1:3090"
    @AppStorage("boardID") private var boardID = ""
    @State private var session: BoardSession?
    @State private var error: String?
    @State private var creating = false

    var body: some View {
        NavigationStack {
            if let session {
                BoardView(session: session) { self.session = nil }
            } else {
                Form {
                    Section {
                        VStack(alignment: .leading) {
                            Image(systemName: "square.stack.3d.up.fill")
                                .font(.largeTitle).foregroundStyle(.teal).accessibilityHidden(true)
                            Text("A shared board.\nA native workspace.").font(.largeTitle.bold())
                            Text("Plan together across web and iOS. Keep editing when your connection drops.")
                                .foregroundStyle(.secondary)
                        }.padding(.vertical)
                    }
                    Section {
                        TextField("Server URL", text: $server)
                            .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                        TextField("Board ID", text: $boardID)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                        Button("Open board", systemImage: "arrow.right") { openBoard() }
                            .disabled(boardID.isEmpty || creating)
                        Button("Create a board", systemImage: "plus") { creating = true }
                            .disabled(creating)
                    } header: { Text("Connect to your server") } footer: {
                        Text("Use HTTPS for remote servers. HTTP is supported only for localhost development. Anyone with the board link can edit it.")
                    }
                    if let error {
                        Section { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red) }
                    }
                    if creating { ProgressView("Creating your board") }
                    Section("How sync works") {
                        Label("Changes are saved on this device before sending.", systemImage: "internaldrive")
                        Label("Pending edits survive an app restart.", systemImage: "arrow.trianglehead.2.clockwise.rotate.90")
                        Label("Rejected drafts stay available to recover.", systemImage: "doc.text")
                    }
                }
                .navigationTitle("Syncboard")
                .task(id: creating) {
                    guard creating else { return }
                    await createBoard()
                }
            }
        }
        .task {
            let args = ProcessInfo.processInfo.arguments
            if let index = args.firstIndex(of: "--server"), args.indices.contains(index + 1) { server = args[index + 1] }
            if let index = args.firstIndex(of: "--board"), args.indices.contains(index + 1) { boardID = args[index + 1]; openBoard() }
        }
    }

    private func openBoard() {
        do {
            let settings = try ConnectionSettings(server: server, boardID: boardID.trimmingCharacters(in: .whitespacesAndNewlines))
            session = try BoardSession(settings: settings)
            error = nil
        } catch { self.error = "Check the server URL and board ID. Existing cache files are kept if they cannot be read." }
    }

    private func createBoard() async {
        defer { creating = false }
        do {
            let settings = try ConnectionSettings(server: server, boardID: "validate")
            var request = URLRequest(url: settings.server.appending(path: "api/boards"))
            request.httpMethod = "POST"
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 201 else { throw URLError(.badServerResponse) }
            struct Created: Decodable { let id: String }
            boardID = try JSONDecoder().decode(Created.self, from: data).id
            openBoard()
        } catch is CancellationError { }
        catch { self.error = "The server could not create a board. Check its address and connection." }
    }
}
