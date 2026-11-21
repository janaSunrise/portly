import Foundation

nonisolated struct ListeningPort: Hashable, Sendable {
    let port: UInt16
    let address: String

    var isLoopback: Bool {
        address == "::1" || address.hasPrefix("127.")
    }
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

extension PortProcess {
    // 3000 on IPv4 and IPv6 is still just 3000
    var portNumbers: [UInt16] {
        Set(ports.map(\.port)).sorted()
    }

    var appPath: String? {
        guard let path, let range = path.range(of: ".app/") else { return nil }
        return String(path[..<range.lowerBound]) + ".app"
    }

    var appName: String? {
        appPath.map { FileManager.default.displayName(atPath: $0) }
    }

    // a node running in ~/dev/my-blog is really "my-blog"
    var projectName: String? {
        guard let cwd, cwd.hasPrefix(NSHomeDirectory() + "/"), !cwd.contains("/.") else { return nil }
        return (cwd as NSString).lastPathComponent
    }

    enum Kind {
        case project, service, app, system
    }

    // first match wins: Control Center is an app, but it's macOS's app
    var kind: Kind {
        if projectName != nil { return .project }
        if let path, ["/System/", "/usr/libexec/", "/usr/sbin/", "/usr/bin/"].contains(where: path.hasPrefix) {
            return .system
        }
        if appPath != nil { return .app }
        return .service
    }

    var displayName: String {
        appName ?? projectName ?? name
    }

    // bound to 0.0.0.0 or ::, so anyone on your network can reach it
    var isExposed: Bool {
        ports.contains { !$0.isLoopback }
    }

    func url(for port: UInt16) -> URL {
        URL(string: "http://localhost:\(port)")!
    }

    // "30" finds 3000 and 3001, anything else matches name or folder
    func matches(_ query: String) -> Bool {
        let digits = query.trimmingPrefix(":")
        if !digits.isEmpty, digits.allSatisfy(\.isNumber) {
            return portNumbers.contains { String($0).hasPrefix(digits) }
        }
        return [displayName, name, cwd ?? ""].contains { $0.localizedStandardContains(query) }
    }
}
