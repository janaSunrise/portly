import SwiftUI

@main
struct PortlyApp: App {
    @State private var store = PortStore()

    var body: some Scene {
        MenuBarExtra("Portly", systemImage: "network") {
            PanelView(store: store)
        }
        .menuBarExtraStyle(.window)
    }
}
