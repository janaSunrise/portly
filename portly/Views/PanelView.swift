import SwiftUI

struct PanelView: View {
    let store: PortStore

    @State private var selection: PortProcess.ID?

    var body: some View {
        VStack(spacing: 0) {
            if store.processes.isEmpty {
                ContentUnavailableView(
                    "Nothing's listening",
                    systemImage: "moon.zzz",
                    description: Text("Start a server and it'll show up here.")
                )
                .frame(maxHeight: .infinity)
            } else {
                List(store.processes, selection: $selection) { process in
                    ProcessRow(process: process)
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
                .animation(.default, value: store.processes.map(\.id))
            }

            Divider()

            HStack {
                Text("^[\(store.processes.count) process](inflect: true) · ^[\(portCount) port](inflect: true)")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .buttonStyle(.borderless)
                    .keyboardShortcut("q")
            }
            .font(.callout)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .frame(width: 360, height: 440)
    }

    private var portCount: Int {
        store.processes.reduce(0) { $0 + $1.portNumbers.count }
    }
}
