import AppKit
import Observation

@Observable
final class PortStore {
    // first scan is ~3ms, do it up front so the panel never opens empty
    private(set) var processes = PortScanner.scan()
    // "pid:port" for project ports that answered HTTP
    private(set) var webPorts: Set<String> = []

    @ObservationIgnored private var probed: Set<String> = []

    func refresh() async {
        let latest = await Task.detached(priority: .userInitiated) {
            PortScanner.scan()
        }.value

        // skip no-op updates so the UI doesn't redraw every tick
        if latest != processes { processes = latest }
        // on the side, a slow dev server shouldn't hold up the list
        Task { await probe() }
    }

    func webPorts(in group: PortGroup) -> [UInt16] {
        group.processes.flatMap { process in
            process.portNumbers.filter { webPorts.contains("\(process.pid):\($0)") }
        }
    }

    // one HEAD request per new project port, so Open only shows where a browser makes sense.
    // services and apps are left alone: redis logs a security warning when it gets HTTP
    private func probe() async {
        let current = Set(processes.flatMap { p in p.portNumbers.map { "\(p.pid):\($0)" } })
        probed.formIntersection(current)
        webPorts.formIntersection(current)

        let fresh = processes
            .filter { $0.kind == .project }
            .flatMap { p in p.portNumbers.map { (key: "\(p.pid):\($0)", port: $0) } }
            .filter { !probed.contains($0.key) }
        guard !fresh.isEmpty else { return }
        probed.formUnion(fresh.map(\.key))

        let found = await withTaskGroup(of: String?.self) { tasks in
            for item in fresh {
                tasks.addTask { await Self.speaksHTTP(item.port) ? item.key : nil }
            }
            var found = Set<String>()
            for await key in tasks {
                if let key { found.insert(key) }
            }
            return found
        }
        webPorts.formUnion(found)
    }

    // dev servers can be slow on the first request, so be patient
    nonisolated private static func speaksHTTP(_ port: UInt16) async -> Bool {
        var request = URLRequest(url: URL(string: "http://localhost:\(port)")!, timeoutInterval: 5)
        request.httpMethod = "HEAD"
        return (try? await URLSession.shared.data(for: request).1) is HTTPURLResponse
    }

    // apps get quit properly so they can ask to save, everything else gets signals
    func stop(_ group: PortGroup, force: Bool = false) async throws {
        if group.kind == .app, let app = runningApp(at: group.lead.appPath) {
            if force { app.forceTerminate() } else { app.terminate() }
            try? await Task.sleep(for: .seconds(1)) // let it wind down
        } else {
            for process in group.processes {
                try await kill(process, force: force)
            }
        }
        await refresh()
    }

    private func runningApp(at path: String?) -> NSRunningApplication? {
        guard let path else { return nil }
        let url = URL(filePath: path, directoryHint: .isDirectory).standardizedFileURL
        return NSWorkspace.shared.runningApplications.first { $0.bundleURL?.standardizedFileURL == url }
    }

    // SIGTERM first, SIGKILL if it's still around after 3s
    private func kill(_ process: PortProcess, force: Bool) async throws {
        try send(force ? SIGKILL : SIGTERM, to: process.pid)
        guard !force else { return }

        let deadline = ContinuousClock.now + .seconds(3)
        while isRunning(process.pid), ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(100))
        }
        if isRunning(process.pid) { try send(SIGKILL, to: process.pid) }
    }

    private func send(_ signal: Int32, to pid: pid_t) throws {
        // ESRCH means it's already gone, which is what we wanted anyway
        guard Darwin.kill(pid, signal) == 0 || errno == ESRCH else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EPERM)
        }
    }

    private func isRunning(_ pid: pid_t) -> Bool {
        Darwin.kill(pid, 0) == 0
    }

    // runs for as long as the caller's task does
    func watch() async {
        while !Task.isCancelled {
            await refresh()
            try? await Task.sleep(for: .seconds(2))
        }
    }
}
