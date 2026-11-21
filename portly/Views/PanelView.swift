import SwiftUI

struct PanelView: View {
    let store: PortStore

    @State private var selection: PortGroup.ID?
    @State private var query = ""
    @State private var confirming: (group: PortGroup, force: Bool)?
    @State private var failure: (group: PortGroup, error: Error)?

    @AppStorage("showApps") private var showApps = false
    @AppStorage("showServices") private var showServices = false

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                PanelHeader(projectCount: listed.count { $0.kind == .project }, portCount: portCount)
                SearchField(text: $query, prompt: "Port, name or folder", onMove: move) {
                    if let group = selected { open(group) }
                } onDelete: {
                    guard let group = selected else { return false }
                    requestStop(group)
                    return true
                }
            }
            .padding([.horizontal, .top], 12)
            .padding(.bottom, 6)

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
                let sections = sections

                ScrollViewReader { proxy in
                    List(selection: $selection) {
                        if let projects = sections[.project] {
                            Section { rows(projects) } header: { header("Projects", count: projects.count) }
                        }
                        if let apps = sections[.app] {
                            Section(isExpanded: expanded($showApps)) { rows(apps) } header: {
                                header("Apps", count: apps.count)
                            }
                        }
                        if let services = sections[.service] {
                            Section(isExpanded: expanded($showServices)) { rows(services) } header: {
                                header("Services", count: services.count)
                            }
                        }
                    }
                    .listStyle(.sidebar)
                    .scrollContentBackground(.hidden)
                    .animation(.default, value: results.map(\.id))
                    .contextMenu(forSelectionType: PortGroup.ID.self) { ids in
                        if let group = group(ids) {
                            ProcessMenu(group: group) { requestStop(group, force: $0) }
                        }
                    } primaryAction: { ids in
                        // double-click or return
                        if let group = group(ids) { open(group) }
                    }
                    .onKeyPress(.delete, phases: .down) { press in
                        guard press.modifiers == .command, let group = selected else { return .ignored }
                        requestStop(group)
                        return .handled
                    }
                    .onChange(of: selection) { _, id in
                        if let id { withAnimation { proxy.scrollTo(id) } }
                    }
                }
            }
        }
        .frame(width: 360, height: 440)
        .task { await store.watch() }
        // like Spotlight: typing picks the first match, so Return just works
        .onChange(of: query) {
            selection = query.isEmpty ? nil : visible.first?.id
        }
        .confirmationDialog(
            confirming?.group.kind == .app
                ? "Quit \(confirming?.group.displayName ?? "")?"
                : "Kill \(confirming?.group.displayName ?? "")?",
            isPresented: Binding { confirming != nil } set: { if !$0 { confirming = nil } },
            presenting: confirming
        ) { pending in
            Button(verb(pending.group, force: pending.force), role: .destructive) {
                stop(pending.group, force: pending.force)
            }
        } message: { pending in
            Text(pending.group.kind == .app
                 ? "Its ports close along with it."
                 : "It's not one of your projects, so something else might rely on it.")
        }
        .alert(
            "Couldn't stop \(failure?.group.displayName ?? "")",
            isPresented: Binding { failure != nil } set: { if !$0 { failure = nil } },
            presenting: failure
        ) { _ in
        } message: { failure in
            Text(failure.error.localizedDescription)
        }
    }

    // macOS's own stuff isn't yours to kill, so it never shows up
    private var listed: [PortGroup] {
        store.processes.filter { $0.kind != .system }.grouped
    }

    private var results: [PortGroup] {
        let query = query.trimmingCharacters(in: .whitespaces)
        return query.isEmpty ? listed : listed.filter { $0.matches(query) }
    }

    private var sections: [PortProcess.Kind: [PortGroup]] {
        Dictionary(grouping: results, by: \.kind)
    }

    // what's on screen, top to bottom, for the arrow keys
    private var visible: [PortGroup] {
        let sections = sections
        let searching = !query.isEmpty
        return (sections[.project] ?? [])
            + (showApps || searching ? sections[.app] ?? [] : [])
            + (showServices || searching ? sections[.service] ?? [] : [])
    }

    private var selected: PortGroup? {
        group([selection].compactMap { $0 })
    }

    private var portCount: Int {
        listed.reduce(0) { $0 + $1.portNumbers.count }
    }

    private func header(_ title: LocalizedStringKey, count: Int) -> some View {
        Text("\(Text(title)) \(Text("\(count)").foregroundStyle(.tertiary))")
    }

    // searching opens every section, otherwise it's up to you
    private func expanded(_ isOn: Binding<Bool>) -> Binding<Bool> {
        Binding { isOn.wrappedValue || !query.isEmpty } set: { isOn.wrappedValue = $0 }
    }

    // scanner already sorts by port, grouping keeps that order
    private func rows(_ groups: [PortGroup]) -> some View {
        ForEach(groups) { group in
            ProcessRow(group: group, webPorts: store.webPorts(in: group)) { requestStop(group, force: $0) }
        }
    }

    private func group(_ ids: some Collection<PortGroup.ID>) -> PortGroup? {
        guard let id = ids.first else { return nil }
        return listed.first { $0.id == id }
    }

    private func move(_ offset: Int) {
        let ids = visible.map(\.id)
        guard !ids.isEmpty else { return }
        let index = selection.flatMap { ids.firstIndex(of: $0) }.map { $0 + offset } ?? (offset > 0 ? 0 : ids.count - 1)
        selection = ids[min(max(index, 0), ids.count - 1)]
    }

    // only ports that answered HTTP open in a browser
    private func open(_ group: PortGroup) {
        guard let port = store.webPorts(in: group).first else { return NSSound.beep() }
        openURL(group.lead.url(for: port))
    }

    private func verb(_ group: PortGroup, force: Bool) -> LocalizedStringKey {
        switch (group.kind == .app, force) {
        case (true, false): "Quit"
        case (true, true): "Force Quit"
        case (false, false): "Kill"
        case (false, true): "Force Kill"
        }
    }

    // projects go right away, anything else asks first
    private func requestStop(_ group: PortGroup, force: Bool = false) {
        if group.kind == .project {
            stop(group, force: force)
        } else {
            confirming = (group, force)
        }
    }

    private func stop(_ group: PortGroup, force: Bool = false) {
        Task {
            do {
                try await store.stop(group, force: force)
            } catch {
                failure = (group, error)
            }
        }
    }
}
