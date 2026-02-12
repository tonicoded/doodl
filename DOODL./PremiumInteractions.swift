import SwiftUI

struct PremiumPlainButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    var pressedOpacity: Double = 0.96
    var animation: Animation = .spring(response: 0.22, dampingFraction: 0.82)

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? pressedOpacity : 1)
            .animation(animation, value: configuration.isPressed)
    }
}
