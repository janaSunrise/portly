import SwiftUI

struct PanelView: View {
    let store: PortStore

    var body: some View {
        VStack(spacing: 0) {
            if store.processes.isEmpty {
                Text("Nothing's listening")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(store.processes) { ProcessRow(process: $0) }
                    }
                    .padding(6)
                }
                // hug the rows, scroll once it gets tall
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxHeight: 420)
            }

            Divider()

            HStack {
                Text(summary)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .buttonStyle(.borderless)
                    .font(.system(size: 11))
                    .keyboardShortcut("q")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
        }
        .frame(width: 340)
    }

    private var summary: String {
        let processes = store.processes.count
        let ports = store.processes.reduce(0) { $0 + $1.portNumbers.count }
        return "\(processes) \(processes == 1 ? "process" : "processes") · \(ports) \(ports == 1 ? "port" : "ports")"
    }
}
