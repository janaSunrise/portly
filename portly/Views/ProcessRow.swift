import SwiftUI

struct ProcessRow: View {
    let process: PortProcess

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: process.appPath ?? process.path ?? "/bin/sh"))
                .resizable()
                .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            HStack(spacing: 4) {
                ForEach(process.portNumbers, id: \.self) { port in
                    Text(verbatim: String(port)) // verbatim, or 3000 turns into "3,000"
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    private var title: String {
        process.appName ?? process.projectName ?? process.name
    }

    private var subtitle: String {
        var parts: [String] = []
        if process.name != title { parts.append(process.name) }
        if process.projectName == title, let cwd = process.cwd {
            parts.append((cwd as NSString).abbreviatingWithTildeInPath)
        }
        return parts.isEmpty ? "PID \(process.pid)" : parts.joined(separator: " · ")
    }
}
