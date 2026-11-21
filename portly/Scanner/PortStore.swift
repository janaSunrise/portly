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

    // runs for as long as the caller's task does
    func watch() async {
        while !Task.isCancelled {
            await refresh()
            try? await Task.sleep(for: .seconds(2))
        }
    }
}
