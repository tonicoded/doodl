import Foundation

struct OnboardingStorage {
    private static let defaults = UserDefaults.standard
    private enum Keys {
        static let profileId = "onboarding_profile_id"
        static let username = "onboarding_username"
        static let avatarURL = "onboarding_avatar_url"
        static let pairingCode = "onboarding_pairing_code"
        static let joinedCode = "onboarding_joined_code"
        static let joinedCodes = "onboarding_joined_codes"
    }

    static func save(profileId: String, username: String, avatarURL: URL?, pairingCode: String, joinedCode: String? = nil) {
        defaults.set(profileId, forKey: Keys.profileId)
        defaults.set(username, forKey: Keys.username)
        defaults.set(avatarURL?.absoluteString, forKey: Keys.avatarURL)
        defaults.set(pairingCode, forKey: Keys.pairingCode)
        if let joinedCode {
            defaults.set(joinedCode, forKey: Keys.joinedCode)
        } else {
            defaults.removeObject(forKey: Keys.joinedCode)
        }
    }

    static func load() -> (profileId: String, username: String, avatarURL: URL?, pairingCode: String, joinedCode: String?)? {
        guard
            let profileId = defaults.string(forKey: Keys.profileId),
            let username = defaults.string(forKey: Keys.username),
            let pairingCode = defaults.string(forKey: Keys.pairingCode)
        else {
            return nil
        }
        let avatarURLString = defaults.string(forKey: Keys.avatarURL)
        let avatarURL = avatarURLString.flatMap { URL(string: $0) }
        let joinedCode = defaults.string(forKey: Keys.joinedCode)
        return (profileId, username, avatarURL, pairingCode, joinedCode)
    }

    static func saveJoinedCode(_ code: String) {
        defaults.set(code, forKey: Keys.joinedCode)
    }

    static func saveJoinedCodes(_ codes: [String]) {
        let cleaned = Array(Set(codes.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }))
            .filter { !$0.isEmpty }
            .sorted()
        if let data = try? JSONEncoder().encode(cleaned) {
            defaults.set(data, forKey: Keys.joinedCodes)
        }
    }

    static func loadJoinedCodes() -> [String] {
        if let data = defaults.data(forKey: Keys.joinedCodes),
           let decoded = (try? JSONDecoder().decode([String].self, from: data)) {
            return Array(Set(decoded.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }))
                .filter { !$0.isEmpty }
                .sorted()
        }
        // Backward-compatible fallback: if old installs only stored a single joined code, return it.
        if let single = defaults.string(forKey: Keys.joinedCode)?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
           !single.isEmpty {
            return [single]
        }
        return []
    }

    static func saveProfileId(_ id: String) {
        defaults.set(id, forKey: Keys.profileId)
    }

    static func clearJoinedCode() {
        defaults.removeObject(forKey: Keys.joinedCode)
    }

    static func clearJoinedCodes() {
        defaults.removeObject(forKey: Keys.joinedCodes)
    }

    static func clear() {
        defaults.removeObject(forKey: Keys.profileId)
        defaults.removeObject(forKey: Keys.username)
        defaults.removeObject(forKey: Keys.avatarURL)
        defaults.removeObject(forKey: Keys.pairingCode)
        defaults.removeObject(forKey: Keys.joinedCode)
        defaults.removeObject(forKey: Keys.joinedCodes)
    }
}
