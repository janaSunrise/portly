import ServiceManagement
import SwiftUI

struct PanelHeader: View {
    let projectCount: Int
    let portCount: Int

    @AppStorage("showApps") private var showApps = false
    @AppStorage("showServices") private var showServices = false
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text("Portly")
                    .font(.headline)

                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }

            Spacer()

            Menu {
                Toggle("Launch at Login", isOn: launchAtLogin)
                Toggle("Show Apps", isOn: $showApps)
                Toggle("Show Services", isOn: $showServices)
                Divider()
                Button("About Portly") {
                    openWindow(id: "about")
                    NSApp.activate()
                }
                Button("Quit Portly") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
            } label: {
                Image(systemName: "gearshape")
            }
            .menuStyle(.button)
            .buttonStyle(.borderless)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }

    private var status: LocalizedStringKey {
        projectCount > 0
            ? "^[\(projectCount) project](inflect: true) running · ^[\(portCount) port](inflect: true)"
            : "No projects running · ^[\(portCount) port](inflect: true)"
    }

    // read straight from the system, so it stays right if you change it in System Settings
    private var launchAtLogin: Binding<Bool> {
        Binding {
            SMAppService.mainApp.status == .enabled
        } set: { enabled in
            try? enabled ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
        }
    }
}
