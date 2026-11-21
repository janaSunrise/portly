import SwiftUI

struct ProcessMenu: View {
    let process: PortProcess
    let kill: (_ force: Bool) -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        ForEach(process.portNumbers, id: \.self) { port in
            Button("Open localhost:\(String(port))") { openURL(process.url(for: port)) }
        }
        if let port = process.portNumbers.first {
            Button("Copy URL") { copy(process.url(for: port).absoluteString) }
        }

        Divider()

        if let cwd = process.cwd, cwd != "/" {
            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([URL(filePath: cwd)])
            }
        }
        if !process.arguments.isEmpty {
            Button("Copy Command") { copy(process.arguments.joined(separator: " ")) }
        }
        Button("Copy PID") { copy(String(process.pid)) }

        Divider()

        Button("Kill", role: .destructive) { kill(false) }
        Button("Force Kill", role: .destructive) { kill(true) }
    }

    private func copy(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }
}
