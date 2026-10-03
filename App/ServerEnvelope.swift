import Foundation
import SyncboardCore

struct ServerEnvelope: Decodable, Sendable {
    let type: String
    let state: Board?
    let ops: [AppliedChange]?
    let opId: String?
    let reason: String?
    let message: String?
    let peers: [BoardPeer]?
}
