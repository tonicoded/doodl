//
//  UserFacingError.swift
//  DOODL.
//
//  Centralized mapping from internal errors (Supabase, networking, cancellation)
//  to short, readable messages for the UI.
//

import Foundation

enum UserFacingError {
    static func message(for error: Error, language: AppLanguage? = nil) -> String? {
        let language = language ?? currentLanguage()

        if isCancellation(error) { return nil }

        if let supabaseError = error as? SupabaseServiceError {
            return message(for: supabaseError, language: language)
        }

        if let urlError = error as? URLError {
            return message(for: urlError, language: language)
        }

        let ns = error as NSError
        if ns.domain == NSURLErrorDomain, ns.code == NSURLErrorCancelled {
            return nil
        }

        let raw = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        let cleaned = extractLikelyMessage(from: raw).trimmingCharacters(in: .whitespacesAndNewlines)

        if cleaned.isEmpty {
            return generic(language)
        }

        let lower = cleaned.lowercased()
        if lower.contains("pgrst002") || lower.contains("schema cache") {
            return language == .dutch
                ? "server is even druk. probeer het zo nog eens."
                : "the server is busy. try again in a moment."
        }
        if lower.contains("statement timeout") || lower.contains("canceling statement due to statement timeout") {
            return language == .dutch
                ? "dit duurt te lang op de server. probeer het opnieuw."
                : "the server took too long. please try again."
        }
        if lower.contains("connection timeout") || lower.contains("connection to client lost") || lower.contains("server closed the connection") {
            return language == .dutch
                ? "verbinding verloren. probeer opnieuw."
                : "connection lost. please try again."
        }

        return generic(language)
    }

    private static func currentLanguage() -> AppLanguage {
        if let raw = UserDefaults.standard.string(forKey: "selectedLanguage"),
           let parsed = AppLanguage(rawValue: raw) {
            return parsed
        }
        return .english
    }

    private static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let urlError = error as? URLError, urlError.code == .cancelled { return true }
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain, ns.code == NSURLErrorCancelled { return true }
        return false
    }

    private static func message(for error: SupabaseServiceError, language: AppLanguage) -> String? {
        switch error {
        case .cooldown:
            return language == .dutch
                ? "wacht 60 seconden voordat je opnieuw stuurt."
                : "wait 60 seconds before sending again."
        case .imageTooLarge:
            return language == .dutch
                ? "doodle te groot. probeer opnieuw."
                : "doodle is too large. try again."
        case .invalidDoodle:
            return language == .dutch
                ? "deze doodle kan niet verstuurd worden. probeer opnieuw."
                : "that doodle can’t be sent. try again."
        case .invalidCode:
            return language == .dutch ? "ongeldige code." : "invalid code."
        case .notMember:
            return language == .dutch ? "je zit niet in deze groep." : "you’re not in this group."
        case .userNotFound:
            return language == .dutch ? "gebruiker niet gevonden." : "user not found."
        case .alreadyMember:
            return language == .dutch ? "je zit al in deze groep." : "already in that group."
        case .selfInvite:
            return language == .dutch ? "je kunt jezelf niet uitnodigen." : "you can’t invite yourself."
        case .alreadyFriends:
            return language == .dutch ? "jullie zijn al vrienden." : "you’re already friends."
        case .notFriends:
            return language == .dutch ? "voeg deze persoon eerst toe." : "add them first."
        case .requestNotFound:
            return language == .dutch ? "verzoek niet gevonden." : "request not found."
        case .unavailableUsername:
            return language == .dutch ? "username is al bezet." : "username is already taken."
        case .invalidDeviceToken:
            return language == .dutch ? "push token ongeldig. probeer opnieuw." : "invalid push token. try again."
        case .conflict:
            return language == .dutch ? "bestaat al." : "already exists."
        case .badStatus(let status) where status == 429:
            return language == .dutch
                ? "je doet dit te snel. wacht even en probeer opnieuw."
                : "you’re doing that too fast. please try again."
        case .badStatus(let status) where status == 500 || status == 503:
            return language == .dutch
                ? "server is even druk. probeer het zo nog eens."
                : "the server is busy. try again in a moment."
        case .badStatus:
            return generic(language)
        case .invalidImage:
            return language == .dutch ? "ongeldige afbeelding." : "invalid image."
        case .invalidURL:
            return generic(language)
        case .apiError(let message):
            let cleaned = extractLikelyMessage(from: message)
            let lower = cleaned.lowercased()
            if lower.contains("cooldown") || lower.contains("wait 60") || lower.contains("wacht 60") || lower.contains("wacht 60 seconden") {
                return language == .dutch
                    ? "wacht 60 seconden voordat je opnieuw stuurt."
                    : "wait 60 seconds before sending again."
            }
            if lower.contains("image_too_large") || lower.contains("doodle te groot") {
                return language == .dutch
                    ? "doodle te groot. probeer opnieuw."
                    : "doodle is too large. try again."
            }
            if lower.contains("unauthorized") {
                return language == .dutch
                    ? "sessie verlopen. herstart de app."
                    : "session expired. restart the app."
            }
            if lower.contains("pgrst002") || lower.contains("schema cache") {
                return language == .dutch
                    ? "server is even druk. probeer het zo nog eens."
                    : "the server is busy. try again in a moment."
            }
            if cleaned.isEmpty { return generic(language) }
            return cleaned
        }
    }

    private static func message(for error: URLError, language: AppLanguage) -> String? {
        switch error.code {
        case .cancelled:
            return nil
        case .notConnectedToInternet:
            return language == .dutch
                ? "geen internetverbinding."
                : "no internet connection."
        case .timedOut:
            return language == .dutch
                ? "duurde te lang. probeer opnieuw."
                : "timed out. please try again."
        case .networkConnectionLost:
            return language == .dutch
                ? "verbinding verloren. probeer opnieuw."
                : "connection lost. please try again."
        case .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
            return language == .dutch
                ? "kan geen verbinding maken. probeer opnieuw."
                : "can’t connect right now. please try again."
        default:
            return generic(language)
        }
    }

    private static func generic(_ language: AppLanguage) -> String {
        switch language {
        case .dutch:
            return "er ging iets mis. probeer opnieuw."
        case .german:
            return "etwas ist schiefgelaufen. bitte versuche es erneut."
        case .spanish:
            return "algo salió mal. inténtalo de nuevo."
        case .english:
            return "something went wrong. please try again."
        }
    }

    private static func extractLikelyMessage(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.first == "{", let data = trimmed.data(using: .utf8) else {
            return trimmed
        }
        guard let obj = try? JSONSerialization.jsonObject(with: data, options: []),
              let dict = obj as? [String: Any] else {
            return trimmed
        }
        if let message = dict["message"] as? String, !message.isEmpty { return message }
        if let error = dict["error"] as? String, !error.isEmpty { return error }
        if let details = dict["details"] as? String, !details.isEmpty { return details }
        if let hint = dict["hint"] as? String, !hint.isEmpty { return hint }
        return trimmed
    }
}

