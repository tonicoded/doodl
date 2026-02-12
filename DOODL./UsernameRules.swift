import Foundation

enum UsernameRules {
    static let maxLength: Int = 12
    static let minLength: Int = 2

    static func sanitize(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutAt = trimmed.hasPrefix("@") ? String(trimmed.dropFirst()) : trimmed
        let lowercased = withoutAt.lowercased()

        var result = ""
        result.reserveCapacity(min(maxLength, lowercased.count))

        for scalar in lowercased.unicodeScalars {
            if result.count >= maxLength { break }
            guard scalar.isASCII else { continue }
            let c = Character(scalar)
            if (c >= "a" && c <= "z") || (c >= "0" && c <= "9") || c == "_" {
                result.append(c)
            }
        }

        return result
    }

    static func isValid(_ username: String) -> Bool {
        let sanitized = sanitize(username)
        return sanitized == username && sanitized.count >= minLength && sanitized.count <= maxLength
    }
}

