import SwiftUI

struct AppThemePalette: Hashable {
    let backgroundColors: [Color]
    let accentColors: [Color]
    let snowColor: Color
    let overlayDarkness: Double

    static let clean = AppThemePalette(
        backgroundColors: [
            Color(hex: "FFFFFF"),
            Color(hex: "F4F5F9")
        ],
        accentColors: [
            Color(hex: "0D0E14"),
            Color(hex: "FFD24A")
        ],
        snowColor: Color.white.opacity(0.9),
        overlayDarkness: 0.0
    )
}

enum AppTheme {
    enum ThemeId: String, CaseIterable, Identifiable {
        case clean

        var id: String { rawValue }

        var title: String {
            switch self {
            case .clean: "clean"
            }
        }

        var palette: AppThemePalette {
            switch self {
            case .clean: .clean
            }
        }
    }

    static let freeTheme: ThemeId = .clean

    static func currentThemeId() -> ThemeId {
        freeTheme
    }

    static func currentPalette() -> AppThemePalette {
        currentThemeId().palette
    }
}

struct ThemedBackground: View {
    var showsSnow: Bool = false

    var body: some View {
        let palette = AppTheme.freeTheme.palette
        ZStack {
            LinearGradient(
                colors: palette.backgroundColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            if palette.overlayDarkness > 0 {
                Color.black.opacity(palette.overlayDarkness)
                    .ignoresSafeArea()
            }

            if showsSnow {
                SnowfallView(color: palette.snowColor)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
    }
}

struct ThemedAccentGradient {
    static func linear(for colorScheme: ColorScheme) -> LinearGradient {
        let palette = AppTheme.currentPalette()
        return LinearGradient(
            colors: palette.accentColors,
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static func angular(for colorScheme: ColorScheme) -> AngularGradient {
        let palette = AppTheme.currentPalette()
        return AngularGradient(
            gradient: Gradient(colors: palette.accentColors),
            center: .center
        )
    }
}
