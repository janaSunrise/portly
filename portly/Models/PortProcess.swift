import Foundation

nonisolated struct ListeningPort: Hashable, Sendable {
    let port: UInt16
    let address: String
}

nonisolated struct PortProcess: Identifiable, Hashable, Sendable {
    let pid: pid_t
    let name: String
    let path: String?
    let cwd: String?
    let arguments: [String]
    let startedAt: Date?
    let ports: [ListeningPort]

    var id: pid_t { pid }
}
