import Foundation
import Observation

@Observable
final class PortStore {
    // first scan is ~3ms, do it up front so the panel never opens empty
    private(set) var processes = PortScanner.scan()

    func refresh() async {
        let latest = await Task.detached(priority: .userInitiated) {
            PortScanner.scan()
        }.value

        // skip no-op updates so the UI doesn't redraw every tick
        if latest != processes { processes = latest }
    }

    // SIGTERM first, SIGKILL if it's still around after 3s
    func kill(_ process: PortProcess, force: Bool = false) async throws {
        try send(force ? SIGKILL : SIGTERM, to: process.pid)

        if !force {
            let deadline = ContinuousClock.now + .seconds(3)
            while isRunning(process.pid), ContinuousClock.now < deadline {
                try? await Task.sleep(for: .milliseconds(100))
            }
            if isRunning(process.pid) { try send(SIGKILL, to: process.pid) }
        }

        await refresh()
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
