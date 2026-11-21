import SwiftUI

@main
struct PortlyApp: App {
    @State private var store = PortStore()

    var body: some Scene {
        MenuBarExtra("Portly", systemImage: "network") {
            // Placeholder
            ForEach(store.processes) { process in
                let ports = process.ports.map { String($0.port) }
                Text("\(process.name) - \(Set(ports).sorted().joined(separator: ", "))")
            }
            Divider()
            Button("Quit Portly") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}
