struct BoardPeer: Decodable, Identifiable, Sendable {
    let clientId: String
    let name: String
    let color: String
    var id: String { clientId }
}
