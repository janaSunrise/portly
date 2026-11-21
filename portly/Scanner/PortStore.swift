import Observation

@Observable
final class PortStore {
    private(set) var processes: [PortProcess] = []

    init() {
        Task { await watch() }
    }

    func refresh() async {
        processes = await Task.detached(priority: .userInitiated) {
            PortScanner.scan()
        }.value
    }

    private func watch() async {
        while !Task.isCancelled {
            await refresh()
            try? await Task.sleep(for: .seconds(2))
        }
    }
}
