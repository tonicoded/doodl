import Foundation
import StoreKit
import UIKit

@MainActor
enum ReviewPrompter {
    private enum Keys {
        static let openCount = "review.openCount.v1"
        static let lastPromptedOpenCount = "review.lastPromptedOpenCount.v1"
        static let didRate = "review.didRate.v1"
    }

    // Tune these numbers without risking spam.
    private static let promptEveryOpens = 5

    static func registerAppOpen() {
        let current = UserDefaults.standard.integer(forKey: Keys.openCount)
        UserDefaults.standard.set(current + 1, forKey: Keys.openCount)
    }

    static func shouldShowPrePrompt() -> Bool {
        if UserDefaults.standard.bool(forKey: Keys.didRate) {
            return false
        }

        let opens = UserDefaults.standard.integer(forKey: Keys.openCount)
        guard opens >= promptEveryOpens else { return false }
        let lastPromptedAt = UserDefaults.standard.integer(forKey: Keys.lastPromptedOpenCount)
        guard (opens - lastPromptedAt) >= promptEveryOpens else { return false }

        return true
    }

    static func markPromptShown() {
        let opens = UserDefaults.standard.integer(forKey: Keys.openCount)
        UserDefaults.standard.set(opens, forKey: Keys.lastPromptedOpenCount)
    }

    static func requestReview() {
        UserDefaults.standard.set(true, forKey: Keys.didRate)
        markPromptShown()

        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {
#if DEBUG
            print("review prompt warning: no active UIWindowScene found; skipping requestReview(in:).")
#endif
            return
        }
        SKStoreReviewController.requestReview(in: scene)
    }

    static func openWriteReviewPage() {
        // Optional fallback if the system sheet doesn't appear (Apple may ignore requestReview).
        if let url = URL(string: "https://apps.apple.com/app/id6756630419?action=write-review") {
            UIApplication.shared.open(url)
        }
    }
}
