import SwiftUI

struct ProcessMenu: View {
    let group: PortGroup
    let stop: (_ force: Bool) -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        ForEach(group.portNumbers, id: \.self) { port in
            Button("Open localhost:\(String(port))") { openURL(group.lead.url(for: port)) }
        }
        if let port = group.portNumbers.first {
            Button("Copy URL") { copy(group.lead.url(for: port).absoluteString) }
        }

        Divider()

        if let folder {
            Button("Show in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([URL(filePath: folder)])
            }
        }
        if group.processes.count == 1 {
            if !group.lead.arguments.isEmpty {
                Button("Copy Command") { copy(group.lead.arguments.joined(separator: " ")) }
            }
            Button("Copy PID") { copy(String(group.lead.pid)) }
        }

        Divider()

        Button(group.kind == .app ? "Quit" : "Kill", role: .destructive) { stop(false) }
        Button(group.kind == .app ? "Force Quit" : "Force Kill", role: .destructive) { stop(true) }
    }

    // the app itself for apps, the project folder for everything else
    private var folder: String? {
        if group.kind == .app { return group.lead.appPath }
        guard let cwd = group.lead.cwd, cwd != "/" else { return nil }
        return cwd
    }

    private func copy(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }
}
