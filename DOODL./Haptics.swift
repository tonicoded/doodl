import Foundation

#if canImport(UIKit)
import UIKit

@MainActor
enum Haptics {
    enum Impact {
        case light
        case medium
        case heavy
        case soft
        case rigid
    }

    private static let selection = UISelectionFeedbackGenerator()
    private static let notification = UINotificationFeedbackGenerator()

    static func prepare() {
        selection.prepare()
        notification.prepare()
    }

    static func tap(_ style: Impact = .light) {
        let generatorStyle: UIImpactFeedbackGenerator.FeedbackStyle
        switch style {
        case .light: generatorStyle = .light
        case .medium: generatorStyle = .medium
        case .heavy: generatorStyle = .heavy
        case .soft:
            if #available(iOS 13.0, *) {
                generatorStyle = .soft
            } else {
                generatorStyle = .light
            }
        case .rigid:
            if #available(iOS 13.0, *) {
                generatorStyle = .rigid
            } else {
                generatorStyle = .heavy
            }
        }
        UIImpactFeedbackGenerator(style: generatorStyle).impactOccurred()
    }

    static func selectionChanged() {
        selection.selectionChanged()
        selection.prepare()
    }

    static func success() {
        notification.notificationOccurred(.success)
        notification.prepare()
    }

    static func warning() {
        notification.notificationOccurred(.warning)
        notification.prepare()
    }

    static func error() {
        notification.notificationOccurred(.error)
        notification.prepare()
    }
}
#else
@MainActor
enum Haptics {
    static func prepare() {}
    enum Impact { case light, medium, heavy, soft, rigid }
    static func tap(_ style: Impact = .light) {}
    static func selectionChanged() {}
    static func success() {}
    static func warning() {}
    static func error() {}
}
#endif
