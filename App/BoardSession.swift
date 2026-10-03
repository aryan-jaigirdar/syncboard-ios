import CryptoKit
import Foundation
import Observation
import SyncboardCore

@MainActor @Observable
final class BoardSession {
    let settings: ConnectionSettings
    private(set) var journal: SyncJournal
    private(set) var status = "Connecting"
    private(set) var peers: [BoardPeer] = []
    private(set) var errorMessage: String?
    private(set) var storageFailed = false
    var workOffline = false
    private let store: JournalStore
    private var socket: URLSessionWebSocketTask?
    private var ready = false
    private var activeRun: UUID?

    init(settings: ConnectionSettings) throws {
        self.settings = settings
        let folder = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appending(path: "Syncboard")
        let key = SHA256.hash(data: Data(settings.webURL.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined()
        store = JournalStore(file: folder.appending(path: "\(key).json"))
        journal = try store.load()
    }

    var board: Board? { journal.visible }

    @discardableResult
    func queue(_ operation: BoardOperation) -> Bool { queue([operation]) }

    @discardableResult
    func queue(_ operations: [BoardOperation]) -> Bool {
        do {
            var next = journal
            for operation in operations { try next.enqueue(operation) }
            try persist(next)
            return true
        } catch { errorMessage = "Could not save this change: \(error.localizedDescription)"; return false }
    }

    func dismissError() { errorMessage = nil }

    func discardRejected(_ id: String) {
        var next = journal
        next.dismissRejected(id)
        do { try persist(next) } catch { errorMessage = "Could not save the draft change." }
    }

    /// Owned by SwiftUI's .task. Cancellation closes the current socket before returning.
    func run() async {
        let lease = UUID()
        activeRun = lease
        peers = []
        guard !workOffline, !storageFailed else { status = "Offline"; return }
        var attempts = 0
        while !Task.isCancelled && !workOffline && !storageFailed && activeRun == lease {
            status = attempts == 0 ? "Connecting" : "Reconnecting"
            let connection = URLSession.shared.webSocketTask(with: settings.socketURL)
            socket = connection
            ready = false
            connection.resume()
            do {
                try await withTaskCancellationHandler {
                    try await sendJoin(connection)
                    while !Task.isCancelled {
                        let message = try await connection.receive()
                        try Task.checkCancellation()
                        guard activeRun == lease, socket === connection else { throw CancellationError() }
                        let data: Data
                        switch message {
                        case .data(let payload): data = payload
                        case .string(let payload): data = Data(payload.utf8)
                        @unknown default: continue
                        }
                        let envelope = try JSONDecoder().decode(ServerEnvelope.self, from: data)
                        try await receive(envelope, on: connection)
                        attempts = 0
                    }
                } onCancel: { connection.cancel(with: .goingAway, reason: nil) }
            } catch is CancellationError { }
            catch {
                if !Task.isCancelled, activeRun == lease { status = "Offline · edits saved" }
            }
            connection.cancel(with: .goingAway, reason: nil)
            if socket === connection { socket = nil; ready = false; peers = [] }
            guard !Task.isCancelled, !workOffline, !storageFailed, activeRun == lease else { break }
            attempts += 1
            do { try await Task.sleep(for: .seconds(min(15, 1 << min(attempts, 4)))) }
            catch { break }
        }
        if activeRun == lease { status = workOffline ? "Offline · edits saved" : "Disconnected" }
    }

    func flush() async {
        guard ready, !workOffline, !storageFailed, let connection = socket else { return }
        do {
            // Send in order. Stable IDs make repeat sends safe on the paired server.
            for change in journal.pending {
                try Task.checkCancellation()
                try await send(change, on: connection)
            }
        } catch is CancellationError {
            // An outbox update cancels this flush; it does not own the live socket.
        } catch {
            connection.cancel(with: .goingAway, reason: nil)
        }
    }

    private func receive(_ envelope: ServerEnvelope, on connection: URLSessionWebSocketTask) async throws {
        var next = journal
        switch envelope.type {
        case "snapshot":
            guard let state = envelope.state, state.id == settings.boardID else { throw BoardError.invalidOperation }
            try next.snapshot(state)
            try persist(next)
            peers = envelope.peers ?? []
            ready = true
            status = "Live"
            try await resend(on: connection)
        case "ops":
            do {
                for op in envelope.ops ?? [] { try next.accept(op) }
                try persist(next)
            } catch BoardError.versionGap {
                ready = false
                try await sendJoin(connection)
            }
        case "ack":
            if let id = envelope.opId { next.acknowledge(id); try persist(next) }
        case "reject":
            if let id = envelope.opId { next.reject(id, reason: envelope.reason ?? "invalid_op"); try persist(next) }
        case "presence": peers = envelope.peers ?? []
        case "error":
            errorMessage = envelope.message ?? "This board is unavailable."
            throw BoardError.invalidOperation
        default: break
        }
    }

    private func persist(_ next: SyncJournal) throws {
        do { try store.save(next); journal = next }
        catch {
            storageFailed = true
            errorMessage = "Device storage failed. Sync is paused to preserve pending edits."
            socket?.cancel(with: .goingAway, reason: nil)
            throw error
        }
    }

    private func sendJoin(_ connection: URLSessionWebSocketTask) async throws {
        // Request a full snapshot on every connection; never assume the server retained its op log.
        let payload: [String: String] = ["type": "join", "boardId": settings.boardID, "clientId": journal.clientID, "name": "iOS client"]
        let data = try JSONEncoder().encode(payload)
        try await connection.send(.string(String(decoding: data, as: UTF8.self)))
    }

    private func send(_ change: PendingChange, on connection: URLSessionWebSocketTask) async throws {
        struct Intent: Encodable { let type = "op"; let opId: String; let baseVersion: Int; let op: BoardOperation }
        let data = try JSONEncoder().encode(Intent(opId: change.opId, baseVersion: journal.confirmed?.version ?? 0, op: change.op))
        // The Node server accepts text frames only.
        try await connection.send(.string(String(decoding: data, as: UTF8.self)))
    }

    private func resend(on connection: URLSessionWebSocketTask) async throws {
        for change in journal.pending {
            try Task.checkCancellation()
            guard socket === connection else { throw CancellationError() }
            try await send(change, on: connection)
        }
    }
}
