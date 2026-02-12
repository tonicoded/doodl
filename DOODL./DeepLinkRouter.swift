//
//  DeepLinkRouter.swift
//  DOODL.
//
//  Created by Anthony Verruijt on 17/12/2025.
//

import Foundation
import Combine

@MainActor
final class DeepLinkRouter: ObservableObject {
    struct AnonymousLink: Identifiable, Hashable {
        let code: String
        var id: String { code }
    }

    @Published var anonymousLink: AnonymousLink?

    func handle(url: URL) {
        guard let code = Self.anonymousCode(from: url) else { return }
        anonymousLink = AnonymousLink(code: code.lowercased())
    }

    static func anonymousCode(from url: URL) -> String? {
        let scheme = url.scheme?.lowercased()

        if scheme == "doodl" {
            let host = url.host?.lowercased()
            if host == "h" || host == "anonymous" {
                let pathCode = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                if isValidShortCode(pathCode) { return pathCode }

                if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                   let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
                   isValidShortCode(code) {
                    return code
                }
            }
        }

        if scheme == "https" || scheme == "http" {
            let host = url.host?.lowercased()
            if host == "doodl-me.com" || host == "www.doodl-me.com" {
                // https://doodl-me.com/h/<code>
                let parts = url.path.split(separator: "/").map(String.init)
                if parts.count >= 2, parts[0].lowercased() == "h" {
                    let code = parts[1]
                    if isValidShortCode(code) { return code }
                }
            }
        }

        return nil
    }

    private static func isValidShortCode(_ code: String) -> Bool {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard (10...24).contains(trimmed.count) else { return false }
        let allowed = CharacterSet(charactersIn: "0123456789abcdef")
        return trimmed.unicodeScalars.allSatisfy { allowed.contains($0) }
    }
}
