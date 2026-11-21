import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            AppMark(size: 72)
                .padding(.top, 8)

            VStack(spacing: 3) {
                Text("Portly")
                    .font(.title2.weight(.semibold))
                Text("Version \(info("CFBundleShortVersionString")) (\(info("CFBundleVersion")))")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .textSelection(.enabled)
            }

            Text("See what's listening on your ports, and stop it when it gets in the way.")
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Link("View on GitHub", destination: URL(string: "https://github.com/janaSunrise/portly")!)

            Text(info("NSHumanReadableCopyright"))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 24)
        .frame(width: 320)
    }

    private func info(_ key: String) -> String {
        Bundle.main.object(forInfoDictionaryKey: key) as? String ?? ""
    }
}
