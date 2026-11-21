import SwiftUI

struct ProcessRow: View {
    let group: PortGroup
    let webPorts: [UInt16]
    let stop: (_ force: Bool) -> Void

    @ScaledMetric(relativeTo: .body) private var iconSize = 20
    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(spacing: 8) {
            icon
                .frame(width: iconSize, height: iconSize)

            VStack(alignment: .leading, spacing: 0) {
                Text(group.displayName)
                    .lineLimit(1)
                TimelineView(.everyMinute) { context in
                    Text(subtitle(now: context.date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            ports

            Menu {
                ProcessMenu(group: group, stop: stop)
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(.secondary)
                    .contentShape(.rect)
            }
            // plain, so SwiftUI draws the label and it follows the theme
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Actions")
        }
        .help(group.processes.count == 1 ? group.lead.arguments.joined(separator: " ") : "")
    }

    // apps get their own icon, everything else a symbol. projects are yours, so they get the accent
    @ViewBuilder
    private var icon: some View {
        if let app = group.lead.appPath {
            Image(nsImage: NSWorkspace.shared.icon(forFile: app))
                .resizable()
        } else if group.kind == .project {
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .foregroundStyle(.tint)
        } else {
            Image(systemName: "server.rack")
                .foregroundStyle(.secondary)
        }
    }

    // ports that answer HTTP are links, the rest are just numbers. "+2" keeps the name roomy
    private var ports: some View {
        HStack(spacing: 6) {
            if group.isExposed {
                Image(systemName: "network")
                    .foregroundStyle(.secondary)
                    .help("Reachable from your network")
            }
            ForEach(group.portNumbers.prefix(2), id: \.self) { port in
                if webPorts.contains(port) {
                    Button(String(port)) { openURL(group.lead.url(for: port)) }
                        .buttonStyle(.link)
                        .help("Open localhost:\(String(port))")
                } else {
                    Text(String(port))
                        .foregroundStyle(.secondary)
                }
            }
            if group.portNumbers.count > 2 {
                Text("+\(group.portNumbers.count - 2)")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.callout)
        .monospacedDigit()
        .lineLimit(1)
        .fixedSize()
    }

    // "next-server (v16.4.6) · 4h", "3 processes · 10h", or "up 14h"
    private func subtitle(now: Date) -> String {
        let uptime = group.startedAt.map {
            Duration.seconds(now.timeIntervalSince($0))
                .formatted(.units(allowed: [.days, .hours, .minutes, .seconds], width: .narrow, maximumUnitCount: 1))
        }
        let detail: String? = switch true {
        case group.processes.count > 1: "\(group.processes.count) processes"
        case group.kind == .project: group.lead.command
        default: nil
        }

        switch (detail, uptime) {
        case let (detail?, uptime?): return "\(detail) · \(uptime)"
        case let (detail?, nil): return detail
        case let (nil, uptime?): return "up \(uptime)"
        case (nil, nil): return "PID \(group.lead.pid)"
        }
    }
}
