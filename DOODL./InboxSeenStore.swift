import Foundation

enum InboxSeenStore {
    private static func key(for groupCode: String) -> String {
        "inbox.lastSeenAt.\(groupCode.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
    }

    static func lastSeenAt(groupCode: String) -> Date {
        let k = key(for: groupCode)
        if let date = UserDefaults.standard.object(forKey: k) as? Date {
            return date
        }
        return .distantPast
    }

    static func markSeen(groupCode: String, at date: Date = Date()) {
        let k = key(for: groupCode)
        UserDefaults.standard.set(date, forKey: k)
    }
}

