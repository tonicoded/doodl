import SwiftUI

struct CrownBadge: View {
    var size: CGFloat = 13

    var body: some View {
        Image(systemName: "crown.fill")
            .font(.system(size: size, weight: .heavy))
            .symbolRenderingMode(.palette)
            .foregroundStyle(Color(hex: "FFD60A"), Color(hex: "FF9F0A"))
            .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 4)
            .accessibilityLabel("pro")
    }
}

