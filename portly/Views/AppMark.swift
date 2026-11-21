import SwiftUI

// the app's face: About, and later the app icon
struct AppMark: View {
    var size: CGFloat = 30

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
            .fill(Color.accentColor.gradient)
            .overlay {
                Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                    .font(.system(size: size * 0.5, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: size, height: size)
    }
}
