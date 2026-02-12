import SwiftUI

struct XPBadgeView: View {
    let level: Int?
    let progress: Double
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let clamped = max(0, min(1, progress))
	        ZStack {
	            Circle()
	                .fill(.ultraThinMaterial)
	                .overlay(Circle().stroke(GlassStyle.stroke, lineWidth: 1))

	            Circle()
	                .stroke(Color.primary.opacity(0.12), lineWidth: 4)
	                .padding(4)

            Circle()
                .trim(from: 0, to: clamped)
                .stroke(
                    ThemedAccentGradient.angular(for: colorScheme),
                    style: StrokeStyle(lineWidth: 4.5, lineCap: .round, lineJoin: .round)
                )
                .rotationEffect(.degrees(-90))
                .padding(4)
                .shadow(color: .black.opacity(0.10), radius: 10, x: 0, y: 8)

	            Text(level.map(String.init) ?? "—")
	                .font(.system(size: 16, weight: .heavy, design: .rounded))
	                .foregroundStyle(Color.primary.opacity(0.88))
	                .monospacedDigit()
	                .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 6)
	        }
        .frame(width: 40, height: 40)
        .shadow(color: .black.opacity(0.14), radius: 14, x: 0, y: 10)
        .animation(.spring(response: 0.35, dampingFraction: 0.9), value: clamped)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(level.map { "level \($0)" } ?? "level"))
    }
}
