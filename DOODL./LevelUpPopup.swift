import SwiftUI

struct LevelUpPopup: View {
    let language: AppLanguage
    let level: Int
    let onDismiss: () -> Void

    @State private var animateIn = false
    @State private var sparklePulse = false
    @State private var confettiTrigger = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture {
                    Haptics.tap(.light)
                    onDismiss()
                }

            ZStack {
                ConfettiBurstView(trigger: confettiTrigger)
                    .ignoresSafeArea()

                sparkleLayer

                VStack(spacing: 10) {
                    Text(title)
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))

                    HStack(spacing: 8) {
                        let rank = DoodleRanks.rank(forLevel: level, language: language)
                        Image(systemName: rank.symbol)
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(.white.opacity(0.92))

                        Text("\(DoodleRanks.rankLabel(language: language)) • \(rank.title)")
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white.opacity(0.86))
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(.black.opacity(0.22), in: Capsule(style: .continuous))
                    .overlay(Capsule(style: .continuous).stroke(.white.opacity(0.14), lineWidth: 1))

                    Text("\(level)")
                        .font(.system(size: 46, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white.opacity(0.98))
                        .monospacedDigit()
                        .shadow(color: .black.opacity(0.22), radius: 14, x: 0, y: 10)

                    Text(subtitle)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.72))

                    Button {
                        Haptics.tap()
                        onDismiss()
                    } label: {
                        Text(ctaTitle)
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(.black.opacity(0.85))
                            .padding(.vertical, 10)
                            .padding(.horizontal, 14)
                            .background(.white.opacity(0.92), in: Capsule(style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .padding(.vertical, 18)
                .padding(.horizontal, 18)
                .frame(maxWidth: 280)
                .glassCard(cornerRadius: 26)
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(.white.opacity(0.18), lineWidth: 1)
                )
            }
            .scaleEffect(animateIn ? 1.0 : 0.92)
            .opacity(animateIn ? 1.0 : 0.0)
        }
        .onAppear {
            Haptics.success()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                animateIn = true
            }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                sparklePulse = true
            }
            confettiTrigger = level
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.3) {
                onDismiss()
            }
        }
    }

    private var sparkleLayer: some View {
        ZStack {
            sparkle(x: -92, y: -58, size: 18, rotation: 10)
            sparkle(x: 92, y: -50, size: 16, rotation: -14)
            sparkle(x: -110, y: 18, size: 14, rotation: -6)
            sparkle(x: 114, y: 14, size: 20, rotation: 16)
            sparkle(x: -70, y: 96, size: 16, rotation: 12)
            sparkle(x: 78, y: 102, size: 14, rotation: -10)
        }
        .opacity(animateIn ? 1 : 0)
    }

		    private func sparkle(x: CGFloat, y: CGFloat, size: CGFloat, rotation: Double) -> some View {
        let palette = AppTheme.currentPalette()
		        return Image(systemName: "sparkles")
		            .font(.system(size: size, weight: .heavy))
		            .foregroundStyle(
		                LinearGradient(
		                    colors: [palette.accentColors[0].opacity(0.95), palette.accentColors[1].opacity(0.95)],
		                    startPoint: .topLeading,
		                    endPoint: .bottomTrailing
		                )
		            )
		            .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 8)
		            .rotationEffect(.degrees(rotation + (sparklePulse ? 8 : -8)))
		            .scaleEffect(sparklePulse ? 1.05 : 0.92)
		            .offset(x: x, y: y)
	    }

    private var title: String {
        switch language {
        case .english: "level up"
        case .dutch: "level up"
        case .german: "level up"
        case .spanish: "level up"
        }
    }

    private var subtitle: String {
        switch language {
        case .english: "keep doodling"
        case .dutch: "ga door met doodlen"
        case .german: "weiter doodlen"
        case .spanish: "sigue doodleando"
        }
    }

    private var ctaTitle: String {
        switch language {
        case .english: "nice"
        case .dutch: "nice"
        case .german: "nice"
        case .spanish: "nice"
        }
    }
}
