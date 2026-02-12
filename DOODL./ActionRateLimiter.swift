import Foundation

actor ActionRateLimiter {
    static let shared = ActionRateLimiter()

    private var lastAllowedAt: [String: Date] = [:]

    func allow(key: String, cooldownSeconds: TimeInterval) -> Bool {
        guard cooldownSeconds > 0 else { return true }
        let now = Date()
        if let last = lastAllowedAt[key], now.timeIntervalSince(last) < cooldownSeconds {
            return false
        }
        lastAllowedAt[key] = now
        return true
    }
}

