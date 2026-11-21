import SwiftUI

// the app's face: header, About, and later the app icon
struct AppMark: View {
    var size: CGFloat = 30

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
            .fill(Color.accent.gradient)
            .overlay {
                Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                    .font(.system(size: size * 0.5, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: size, height: size)
            .shadow(color: .accent.opacity(0.35), radius: size * 0.15, y: size * 0.05)
    }
}
