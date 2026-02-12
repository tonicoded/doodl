import SwiftUI

enum GlassStyle {
    static let stroke = Color.primary.opacity(0.14)
    static let innerGlow = Color.primary.opacity(0.06)
    static let shadow = Color.black.opacity(0.14)
}

extension View {
    func glassCard(cornerRadius: CGFloat = 22) -> some View {
        self
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(GlassStyle.stroke, lineWidth: 1)
            )
            .shadow(color: GlassStyle.shadow, radius: 18, x: 0, y: 14)
    }

    func glassCapsule() -> some View {
        self
            .background(.ultraThinMaterial, in: Capsule(style: .continuous))
            .overlay(
                Capsule(style: .continuous)
                    .stroke(GlassStyle.stroke, lineWidth: 1)
            )
            .shadow(color: GlassStyle.shadow, radius: 16, x: 0, y: 12)
    }

    func glassCircle() -> some View {
        self
            .background(.ultraThinMaterial, in: Circle())
            .overlay(Circle().stroke(GlassStyle.stroke, lineWidth: 1))
            .shadow(color: GlassStyle.shadow, radius: 14, x: 0, y: 10)
    }
}
