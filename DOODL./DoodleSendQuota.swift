import Foundation

enum DoodleSendQuota {
    private static let dayStartKey = "doodleSendQuota.dayStart"
    private static let countKey = "doodleSendQuota.count"

    static var freeDailyLimit: Int {
        if let number = Bundle.main.object(forInfoDictionaryKey: "FreeDailyDoodleSendLimit") as? NSNumber {
            return max(0, number.intValue)
        }
        if let string = Bundle.main.object(forInfoDictionaryKey: "FreeDailyDoodleSendLimit") as? String, let parsed = Int(string) {
            return max(0, parsed)
        }
        return 10
    }

    static func canSend(isPro: Bool, defaults: UserDefaults = .standard) -> Bool {
        if isPro { return true }
        let limit = freeDailyLimit
        guard limit > 0 else { return true }
        normalizeDay(defaults: defaults)
        return defaults.integer(forKey: countKey) < limit
    }

    static func remainingFreeSendsToday(defaults: UserDefaults = .standard) -> Int {
        let limit = freeDailyLimit
        guard limit > 0 else { return Int.max }
        normalizeDay(defaults: defaults)
        return max(0, limit - defaults.integer(forKey: countKey))
    }

    @discardableResult
    static func recordSuccessfulSendIfNeeded(isPro: Bool, defaults: UserDefaults = .standard) -> Int? {
        if isPro { return nil }
        let limit = freeDailyLimit
        guard limit > 0 else { return nil }
        normalizeDay(defaults: defaults)
        let next = defaults.integer(forKey: countKey) + 1
        defaults.set(next, forKey: countKey)
        return max(0, limit - next)
    }

    private static func normalizeDay(defaults: UserDefaults) {
        let current = currentDayStartUnix()
        let stored = defaults.integer(forKey: dayStartKey)
        if stored != current {
            defaults.set(current, forKey: dayStartKey)
            defaults.set(0, forKey: countKey)
        }
    }

    private static func currentDayStartUnix() -> Int {
        Int(Calendar.current.startOfDay(for: Date()).timeIntervalSince1970)
    }
}
