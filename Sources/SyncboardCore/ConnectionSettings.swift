import Foundation

public struct ConnectionSettings: Equatable, Sendable {
    public let server: URL
    public let boardID: String

    public init(server: String, boardID: String) throws {
        guard let url = URL(string: server.trimmingCharacters(in: .whitespacesAndNewlines)),
              let host = url.host, url.user == nil, url.password == nil, url.query == nil, url.fragment == nil,
              url.path.isEmpty || url.path == "/",
              url.scheme == "https" || (url.scheme == "http" && ["localhost", "127.0.0.1", "::1"].contains(host)),
              boardID.range(of: "^[A-Za-z0-9]{4,32}$", options: .regularExpression) != nil else {
            throw BoardError.invalidOperation
        }
        self.server = url
        self.boardID = boardID
    }

    public var webURL: URL { server.appending(path: "b/\(boardID)") }
    public var socketURL: URL {
        var components = URLComponents(url: server.appending(path: "ws"), resolvingAgainstBaseURL: false)!
        components.scheme = server.scheme == "https" ? "wss" : "ws"
        return components.url!
    }
}
