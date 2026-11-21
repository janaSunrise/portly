import SwiftUI
import UniformTypeIdentifiers

struct ProcessRow: View {
    let process: PortProcess

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: icon)
                .resizable()
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(process.displayName)
                    .lineLimit(1)
                TimelineView(.everyMinute) { context in
                    Text(subtitle(now: context.date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
        .padding(.vertical, 2)
        .badge(Text(process.portNumbers.map(String.init).joined(separator: ", ")).monospacedDigit())
        .help(process.arguments.joined(separator: " "))
    }

    // ask by type, not by file: Finder thinks a binary named "2.1.330" is a document
    private var icon: NSImage {
        if let app = process.appPath { return NSWorkspace.shared.icon(forFile: app) }
        return NSWorkspace.shared.icon(for: .unixExecutable)
    }

    // "node · ~/dev/portfolio · 16m", or just "up 3d" when there's nothing else to say
    private func subtitle(now: Date) -> String {
        var parts: [String] = []
        // skip "ControlCenter" under "Control Center"
        if process.name != process.displayName.replacingOccurrences(of: " ", with: "") { parts.append(process.name) }
        if process.projectName == process.displayName, let cwd = process.cwd {
            parts.append((cwd as NSString).abbreviatingWithTildeInPath)
        }
        guard let started = process.startedAt else {
            return parts.isEmpty ? "PID \(process.pid)" : parts.joined(separator: " · ")
        }
        let uptime = Duration.seconds(now.timeIntervalSince(started))
            .formatted(.units(allowed: [.days, .hours, .minutes, .seconds], width: .narrow, maximumUnitCount: 1))
        return parts.isEmpty ? "up \(uptime)" : (parts + [uptime]).joined(separator: " · ")
    }
}
