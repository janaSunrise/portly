import SwiftUI

struct PanelView: View {
    let store: PortStore

    @State private var selection: PortProcess.ID?
    @State private var confirmingKill: (process: PortProcess, force: Bool)?
    @State private var failure: (process: PortProcess, error: Error)?

    @AppStorage("showServices") private var showServices = false

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 0) {
            if listed.isEmpty {
                ContentUnavailableView(
                    "Nothing's listening",
                    systemImage: "moon.zzz",
                    description: Text("Start a server and it'll show up here.")
                )
                .frame(maxHeight: .infinity)
            } else {
                let groups = Dictionary(grouping: listed, by: \.kind)

                List(selection: $selection) {
                    if let projects = groups[.project] {
                        Section("Projects") { rows(projects) }
                    }
                    if let apps = groups[.app] {
                        Section("Apps") { rows(apps) }
                    }
                    if let services = groups[.service] {
                        Section("Services", isExpanded: $showServices) { rows(services) }
                    }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
                .animation(.default, value: listed.map(\.id))
                .contextMenu(forSelectionType: PortProcess.ID.self) { ids in
                    if let process = process(ids) {
                        ProcessMenu(process: process) { force in requestKill(process, force: force) }
                    }
                } primaryAction: { ids in
                    // double-click or return
                    if let process = process(ids), let port = process.portNumbers.first {
                        openURL(process.url(for: port))
                    }
                }
                .onKeyPress(.delete, phases: .down) { press in
                    guard press.modifiers == .command, let process = process([selection].compactMap { $0 }) else {
                        return .ignored
                    }
                    requestKill(process)
                    return .handled
                }
            }

            Divider()

            HStack {
                Text("^[\(listed.count) process](inflect: true) · ^[\(portCount) port](inflect: true)")
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
        .task { await store.watch() }
        .confirmationDialog(
            "Kill \(confirmingKill?.process.displayName ?? "")?",
            isPresented: Binding { confirmingKill != nil } set: { if !$0 { confirmingKill = nil } },
            presenting: confirmingKill
        ) { pending in
            Button(pending.force ? "Force Kill" : "Kill", role: .destructive) {
                kill(pending.process, force: pending.force)
            }
        } message: { _ in
            Text("It's not one of your projects, so something else might rely on it.")
        }
        .alert(
            "Couldn't kill \(failure?.process.displayName ?? "")",
            isPresented: Binding { failure != nil } set: { if !$0 { failure = nil } },
            presenting: failure
        ) { _ in
        } message: { failure in
            Text(failure.error.localizedDescription)
        }
    }

    // macOS's own stuff isn't yours to kill, so it never shows up
    private var listed: [PortProcess] {
        store.processes.filter { $0.kind != .system }
    }

    private var portCount: Int {
        listed.reduce(0) { $0 + $1.portNumbers.count }
    }

    // scanner already sorts by port, grouping keeps that order
    private func rows(_ processes: [PortProcess]) -> some View {
        ForEach(processes) { ProcessRow(process: $0) }
    }

    private func process(_ ids: some Collection<PortProcess.ID>) -> PortProcess? {
        guard let id = ids.first else { return nil }
        return store.processes.first { $0.id == id }
    }

    // dev servers go right away, anything else asks first
    private func requestKill(_ process: PortProcess, force: Bool = false) {
        if process.kind == .project {
            kill(process, force: force)
        } else {
            confirmingKill = (process, force)
        }
    }

    private func kill(_ process: PortProcess, force: Bool = false) {
        Task {
            do {
                try await store.kill(process, force: force)
            } catch {
                failure = (process, error)
            }
        }
    }
}
