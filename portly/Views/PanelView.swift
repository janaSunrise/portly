import SwiftUI

struct PanelView: View {
    let store: PortStore

    @State private var selection: PortProcess.ID?
    @State private var query = ""
    @State private var confirmingKill: (process: PortProcess, force: Bool)?
    @State private var failure: (process: PortProcess, error: Error)?

    @AppStorage("showServices") private var showServices = false

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                PanelHeader(projectCount: listed.count { $0.kind == .project }, portCount: portCount)
                SearchField(text: $query, prompt: "Port, name or folder")
            }
            .padding([.horizontal, .top], 12)
            .padding(.bottom, 6)
            .background {
                LinearGradient(colors: [.accent.opacity(0.12), .clear], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            }

            if listed.isEmpty {
                ContentUnavailableView(
                    "Nothing's listening",
                    systemImage: "moon.zzz",
                    description: Text("Start a server and it'll show up here.")
                )
                .frame(maxHeight: .infinity)
            } else if results.isEmpty {
                ContentUnavailableView.search(text: query)
                    .frame(maxHeight: .infinity)
            } else {
                let groups = Dictionary(grouping: results, by: \.kind)

                List(selection: $selection) {
                    if let projects = groups[.project] {
                        Section { rows(projects) } header: { header("Projects", count: projects.count) }
                    }
                    if let apps = groups[.app] {
                        Section { rows(apps) } header: { header("Apps", count: apps.count) }
                    }
                    if let services = groups[.service] {
                        // searching opens it, otherwise it's up to you
                        Section(isExpanded: Binding { showServices || !query.isEmpty } set: { showServices = $0 }) {
                            rows(services)
                        } header: {
                            header("Services", count: services.count)
                        }
                    }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
                .animation(.default, value: results.map(\.id))
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

    private var results: [PortProcess] {
        let query = query.trimmingCharacters(in: .whitespaces)
        return query.isEmpty ? listed : listed.filter { $0.matches(query) }
    }

    private var portCount: Int {
        listed.reduce(0) { $0 + $1.portNumbers.count }
    }

    private func header(_ title: LocalizedStringKey, count: Int) -> some View {
        Text("\(Text(title)) \(Text("\(count)").foregroundStyle(.tertiary))")
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
