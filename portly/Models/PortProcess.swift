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

nonisolated extension PortProcess {
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

    // what was actually run: "next-server (v16.4.6)", "vite --port 5173", "uvicorn app:app"
    var command: String {
        guard let first = arguments.first else { return name }
        // servers that retitle themselves say more in the title than the binary does
        if first.contains(" "), !FileManager.default.fileExists(atPath: first) { return first }

        let isPath = { (arg: String) in arg.contains("/") && !arg.hasPrefix("-") }
        var words = arguments.map { isPath($0) ? ($0 as NSString).lastPathComponent : $0 }
        // `node path/to/vite` or `python -m uvicorn`: the tool matters, not the interpreter
        if arguments.count > 1, isPath(arguments[1]) || arguments[1] == "-m" {
            words.removeFirst(arguments[1] == "-m" ? 2 : 1)
        }
        return words.joined(separator: " ")
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

// one row in the list: a single process, or all the helpers of one app
nonisolated struct PortGroup: Identifiable, Hashable, Sendable {
    var processes: [PortProcess]

    var lead: PortProcess { processes[0] }
    var id: String { kind == .app ? lead.appPath ?? "\(lead.pid)" : "\(lead.pid)" }
    var kind: PortProcess.Kind { lead.kind }
    var displayName: String { lead.displayName }

    var portNumbers: [UInt16] {
        Set(processes.flatMap(\.portNumbers)).sorted()
    }

    var isExposed: Bool {
        processes.contains(where: \.isExposed)
    }

    var startedAt: Date? {
        processes.compactMap(\.startedAt).min()
    }

    func matches(_ query: String) -> Bool {
        processes.contains { $0.matches(query) }
    }
}

extension [PortProcess] {
    // VS Code runs a few helpers, each on its own port. one row is plenty
    var grouped: [PortGroup] {
        var groups: [PortGroup] = []
        var appIndex: [String: Int] = [:]

        for process in self {
            if process.kind == .app, let app = process.appPath {
                if let index = appIndex[app] {
                    groups[index].processes.append(process)
                    continue
                }
                appIndex[app] = groups.count
            }
            groups.append(PortGroup(processes: [process]))
        }
        return groups
    }
}
