import SwiftUI

@main
struct PortlyApp: App {
    @State private var store = PortStore()

    var body: some Scene {
        MenuBarExtra("Portly", systemImage: "point.3.filled.connected.trianglepath.dotted") {
            PanelView(store: store)
        }
        .menuBarExtraStyle(.window)

        Window("About Portly", id: "about") {
            AboutView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .restorationBehavior(.disabled)
    }
}
