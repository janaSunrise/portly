import Observation

@Observable
final class PortStore {
    private(set) var processes: [PortProcess] = []

    init() {
        Task { await watch() }
    }

    func refresh() async {
        let latest = await Task.detached(priority: .userInitiated) {
            PortScanner.scan()
        }.value

        // skip no-op updates so the UI doesn't redraw every tick
        if latest != processes { processes = latest }
    }

    private func watch() async {
        while !Task.isCancelled {
            await refresh()
            try? await Task.sleep(for: .seconds(2))
        }
    }
}
