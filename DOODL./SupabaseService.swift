//
//  SupabaseService.swift
//  DOODL.
//
//  Lightweight Supabase REST helper for creating profiles and uploading avatars.
//

import Foundation
import UIKit

struct SupabaseConfig {
    let url: URL
    let anonKey: String
    let bucket: String

    // TODO: Move keys into a secrets file or environment config for production.
    static let `default` = SupabaseConfig(
        url: URL(string: "https://jgunrdhmipqltddbnnyb.supabase.co")!,
        anonKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpndW5yZGhtaXBxbHRkZGJubnliIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU3MjQzMzQsImV4cCI6MjA4MTMwMDMzNH0.AGUY1vCSojY15_8EN5kvdJ2ApX6RDieSQOC90iaTPq8",
        bucket: "avatars"
    )

    var restURL: URL { url.appendingPathComponent("rest/v1") }
    var storageURL: URL { url.appendingPathComponent("storage/v1") }

    func publicFileURL(path: String) -> URL {
        url
            .appendingPathComponent("storage/v1/object/public")
            .appendingPathComponent(bucket)
            .appendingPathComponent(path)
    }
}

struct ProfileResponse: Codable, Hashable {
    let id: String
    let username: String
    let avatar_url: String?
    let pairing_code: String?
}

struct ProfileSearchResult: Identifiable, Hashable {
    let id: String
    let username: String
    let avatarURL: URL?
}

struct GroupMemberProfile: Identifiable, Hashable {
    let id: String
    let username: String
    let avatarURL: URL?
    let streakCount: Int
    let isOnline: Bool
    let isPro: Bool

    init(
        id: String,
        username: String,
        avatarURL: URL?,
        streakCount: Int,
        isOnline: Bool,
        isPro: Bool = false
    ) {
        self.id = id
        self.username = username
        self.avatarURL = avatarURL
        self.streakCount = streakCount
        self.isOnline = isOnline
        self.isPro = isPro
    }
}

enum SupabaseServiceError: LocalizedError {
    case badStatus(Int)
    case invalidImage
    case invalidURL
    case conflict
    case unavailableUsername
    case cooldown
    case invalidCode
    case notMember
    case userNotFound
    case alreadyMember
    case selfInvite
    case alreadyFriends
    case notFriends
    case requestNotFound
    case invalidDoodle
    case imageTooLarge
    case invalidDeviceToken
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .badStatus(let code): return "supabase error (status \(code))"
        case .invalidImage: return "invalid image data"
        case .invalidURL: return "invalid url"
        case .conflict: return "already exists"
        case .unavailableUsername: return "username already in use"
        case .cooldown: return "wait 1 minute before sending another doodl"
        case .invalidCode: return "invalid code"
        case .notMember: return "not in group"
        case .userNotFound: return "user not found"
        case .alreadyMember: return "already in group"
        case .selfInvite: return "you can’t invite yourself"
        case .alreadyFriends: return "already friends"
        case .notFriends: return "add them first"
        case .requestNotFound: return "request not found"
        case .invalidDoodle: return "invalid doodl"
        case .imageTooLarge: return "doodle is too large"
        case .invalidDeviceToken: return "invalid device token"
        case .apiError(let message): return message
        }
    }
}

struct GroupInvite: Identifiable, Hashable {
    let id: String
    let groupCode: String
    let inviterUsername: String
    let status: String
    let createdAt: Date?
}

struct InboxDoodle: Identifiable {
    let id: String
    let senderProfileId: String
    let contentBase64: String?
    let senderUsername: String
    let createdAt: Date?
    let senderIsPro: Bool

    init(
        id: String,
        senderProfileId: String,
        contentBase64: String?,
        senderUsername: String,
        createdAt: Date?,
        senderIsPro: Bool = false
    ) {
        self.id = id
        self.senderProfileId = senderProfileId
        self.contentBase64 = contentBase64
        self.senderUsername = senderUsername
        self.createdAt = createdAt
        self.senderIsPro = senderIsPro
    }
}

struct AnonymousInboxDoodle: Identifiable {
    let id: String
    let contentBase64: String
    let senderFingerprint: String?
    let createdAt: Date?
}

struct AnonymousReceiver: Identifiable, Hashable {
    let id: String
    let username: String
    let avatarURL: URL?
}

struct InboxSender: Identifiable, Hashable {
    let id: String
    let username: String
    let avatarURL: URL?
    let unreadCount: Int
    let lastCreatedAt: Date?
}

struct FriendRequest: Identifiable, Hashable {
    let id: String
    let requesterProfileId: String
    let requesterUsername: String
    let requesterAvatarURL: URL?
    let createdAt: Date?
}

struct DirectChatThread: Identifiable, Hashable {
    var id: String { code }
    let code: String
    let otherProfileId: String
    let otherUsername: String
    let otherAvatarURL: URL?
    let lastCreatedAt: Date?
    let hasUnread: Bool
    let streakCount: Int
    let otherIsPro: Bool
    let otherLevel: Int?
    let otherRank: Int?

    init(
        code: String,
        otherProfileId: String,
        otherUsername: String,
        otherAvatarURL: URL?,
        lastCreatedAt: Date?,
        hasUnread: Bool,
        streakCount: Int,
        otherIsPro: Bool = false,
        otherLevel: Int? = nil,
        otherRank: Int? = nil
    ) {
        self.code = code
        self.otherProfileId = otherProfileId
        self.otherUsername = otherUsername
        self.otherAvatarURL = otherAvatarURL
        self.lastCreatedAt = lastCreatedAt
        self.hasUnread = hasUnread
        self.streakCount = streakCount
        self.otherIsPro = otherIsPro
        self.otherLevel = otherLevel
        self.otherRank = otherRank
    }
}

struct DirectChatInfo: Hashable {
    let code: String
    let groupId: String
}

struct FriendProfile: Identifiable, Hashable {
    let id: String
    let username: String
    let avatarURL: URL?
    let createdAt: Date?
}

struct BlockedUser: Identifiable, Hashable {
    let id: String
    let username: String
    let avatarURL: URL?
    let createdAt: Date?
}

struct GroupSummary: Identifiable, Hashable {
    let id: String
    let code: String
    let displayName: String?
    let ownerProfileId: String?
    let memberCount: Int
    let createdAt: Date?
}


struct ProfileXPState: Decodable, Hashable {
    let xpTotal: Int
    let level: Int
    let levelXP: Int
    let nextLevelXP: Int

    private enum CodingKeys: String, CodingKey {
        case xpTotal = "xp_total"
        case level
        case levelXP = "level_xp"
        case nextLevelXP = "next_level_xp"
    }
}

private struct GroupMemberCountRow: Codable {
    let code: String
    let member_count: Int?
    let max_members: Int?
}

private struct AnonymousLinkStatusRow: Codable {
    let short_code: String?
    let is_enabled: Bool?
}

private struct AnonymousInboxRow: Codable {
    let id: String
    let content_base64: String?
    let sender_fingerprint: String?
    let created_at: String?
}

private struct BlockedUserRow: Codable {
    let blocked_profile_id: String?
    let username: String?
    let avatar_url: String?
    let created_at: String?
}

final class SupabaseService {
    static let shared = SupabaseService()

    private let config: SupabaseConfig
    private let session: URLSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(config: SupabaseConfig = .default, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    func isUsernameAvailable(_ username: String) async throws -> Bool {
        let url = config.restURL.appendingPathComponent("rpc/username_available_secure")
        let body: [String: Any] = ["p_username": username.lowercased()]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addAuthHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SupabaseServiceError.badStatus(-1) }
        guard 200...299 ~= http.statusCode else {
            let message = String(data: data, encoding: .utf8) ?? ""
            throw SupabaseServiceError.apiError(message.isEmpty ? "username check failed" : message)
        }
        return (try? decoder.decode(Bool.self, from: data)) ?? false
    }

    func uploadAvatar(image: UIImage) async throws -> URL {
        guard let data = image.jpegData(compressionQuality: 0.9) ?? image.pngData() else {
            throw SupabaseServiceError.invalidImage
        }

        let fileName = "\(UUID().uuidString).jpg"
        let uploadURL = config.storageURL
            .appendingPathComponent("object")
            .appendingPathComponent(config.bucket)
            .appendingPathComponent(fileName)

        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        addAuthHeaders(to: &request)
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")

        let (_, response) = try await session.upload(for: request, from: data)
        guard let http = response as? HTTPURLResponse, 200...299 ~= http.statusCode else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw SupabaseServiceError.badStatus(status)
        }

        return config.publicFileURL(path: fileName)
    }

    func createProfile(username: String, avatarURL: URL?, pairingCode: String) async throws -> ProfileResponse {
        let url = config.restURL.appendingPathComponent("rpc/create_profile_secure")
        let body: [String: Any?] = [
            "p_username": username.lowercased(),
            "p_pairing_code": pairingCode.lowercased(),
            "p_avatar_url": avatarURL?.absoluteString
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body.compactMapValues { $0 })

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addAuthHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SupabaseServiceError.badStatus(-1) }
        if !(200...299 ~= http.statusCode) {
            let message = extractPostgrestErrorMessage(from: data)
            let lower = message.lowercased()
            if lower.contains("username_taken") { throw SupabaseServiceError.unavailableUsername }
            if lower.contains("pairing_code_taken") { throw SupabaseServiceError.conflict }
            if lower.contains("invalid_username") { throw SupabaseServiceError.apiError("invalid username") }
            if lower.contains("invalid_pairing_code") { throw SupabaseServiceError.apiError("invalid pairing code") }
            if lower.contains("conflict") { throw SupabaseServiceError.conflict }
            throw SupabaseServiceError.apiError(message.isEmpty ? "profile create failed" : message)
        }

        struct Row: Decodable {
            let id: String
            let username: String
            let avatar_url: String?
            let pairing_code: String?
        }

        let rows = (try? decoder.decode([Row].self, from: data)) ?? []
        guard let first = rows.first else { throw SupabaseServiceError.apiError("profile create failed") }
        return ProfileResponse(id: first.id, username: first.username, avatar_url: first.avatar_url, pairing_code: first.pairing_code)
    }

    func searchProfiles(query: String, excludeProfileId: String?, limit: Int = 8) async throws -> [ProfileSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard trimmed.count >= 2 else { return [] }

        let url = config.restURL.appendingPathComponent("rpc/search_profiles_secure")
        var body: [String: Any] = [
            "p_query": trimmed,
            "p_limit": max(1, min(limit, 20))
        ]
        if let excludeProfileId, !excludeProfileId.isEmpty {
            body["p_exclude_profile_id"] = excludeProfileId
        }
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addAuthHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SupabaseServiceError.badStatus(-1) }
        guard 200...299 ~= http.statusCode else {
            let message = String(data: data, encoding: .utf8) ?? ""
            throw SupabaseServiceError.apiError(message.isEmpty ? "search failed" : message)
        }

        struct Row: Codable {
            let id: String
            let username: String
            let avatar_url: String?
        }

        let rows = (try? decoder.decode([Row].self, from: data)) ?? []
        return rows.map {
            ProfileSearchResult(
                id: $0.id,
                username: $0.username,
                avatarURL: $0.avatar_url.flatMap(URL.init(string:))
            )
        }
    }

    func sendFriendRequest(profileId: String, profilePairingCode: String, targetUsername: String) async throws -> String {
        let url = config.restURL.appendingPathComponent("rpc/send_friend_request_secure")
        let trimmed = targetUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        let username = trimmed.hasPrefix("@") ? String(trimmed.dropFirst()) : trimmed
        let body: [String: Any] = [
            "p_profile_id": profileId,
            "p_profile_pairing_code": profilePairingCode.lowercased(),
            "p_target_username": username.lowercased()
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addAuthHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SupabaseServiceError.badStatus(-1) }
        if !(200...299 ~= http.statusCode) {
            let message = extractPostgrestErrorMessage(from: data)
            let lower = message.lowercased()
            if lower.contains("user_not_found") { throw SupabaseServiceError.userNotFound }
            if lower.contains("already_friends") { throw SupabaseServiceError.alreadyFriends }
            if lower.contains("invalid_target") { throw SupabaseServiceError.apiError("invalid user") }
            throw SupabaseServiceError.apiError(message.isEmpty ? "request failed" : message)
        }

        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"")) ?? ""
    }

    func listFriendRequests(profileId: String, profilePairingCode: String, limit: Int = 50) async throws -> [FriendRequest] {
        let url = config.restURL.appendingPathComponent("rpc/list_friend_requests_secure")
        let body: [String: Any] = [
            "p_profile_id": profileId,
            "p_profile_pairing_code": profilePairingCode.lowercased(),
            "p_limit": max(1, min(limit, 200))
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addAuthHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SupabaseServiceError.badStatus(-1) }
        if !(200...299 ~= http.statusCode) {
            let message = extractPostgrestErrorMessage(from: data)
            // Backward-compatible: if the RPC is missing, just show none.
            if http.statusCode == 404 || message.localizedCaseInsensitiveContains("does not exist") {
                return []
            }
            throw SupabaseServiceError.apiError(message.isEmpty ? "requests failed" : message)
        }

        struct Row: Decodable {
            let request_id: String
            let requester_profile_id: String
            let requester_username: String
            let requester_avatar_url: String?
            let created_at: String?
        }

        let rows = (try? decoder.decode([Row].self, from: data)) ?? []
        return rows.map { row in
            FriendRequest(
                id: row.request_id,
                requesterProfileId: row.requester_profile_id,
                requesterUsername: row.requester_username,
                requesterAvatarURL: row.requester_avatar_url.flatMap(URL.init(string:)),
                createdAt: row.created_at.flatMap(isoDate)
            )
        }
    }

    func respondFriendRequest(requestId: String, profileId: String, profilePairingCode: String, accept: Bool) async throws -> (status: String, directGroupCode: String?) {
        let url = config.restURL.appendingPathComponent("rpc/respond_friend_request_secure")
        let body: [String: Any] = [
            "p_request_id": requestId,
            "p_profile_id": profileId,
            "p_profile_pairing_code": profilePairingCode.lowercased(),
            "p_accept": accept
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addAuthHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SupabaseServiceError.badStatus(-1) }
        if !(200...299 ~= http.statusCode) {
            let message = extractPostgrestErrorMessage(from: data)
            let lower = message.lowercased()
            if lower.contains("not_found") { throw SupabaseServiceError.requestNotFound }
            throw SupabaseServiceError.apiError(message.isEmpty ? "request failed" : message)
        }

        struct Row: Decodable {
            let status: String?
            let direct_group_code: String?
        }

        let rows = (try? decoder.decode([Row].self, from: data)) ?? []
        let first = rows.first
        return (first?.status ?? "", first?.direct_group_code)
    }

    func ensureDirectChat(profileId: String, profilePairingCode: String, friendProfileId: String) async throws -> DirectChatInfo {
        let url = config.restURL.appendingPathComponent("rpc/ensure_direct_chat_secure")
        let body: [String: Any] = [
            "p_profile_id": profileId,
            "p_profile_pairing_code": profilePairingCode.lowercased(),
            "p_friend_profile_id": friendProfileId
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addAuthHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SupabaseServiceError.badStatus(-1) }
        if !(200...299 ~= http.statusCode) {
            let message = extractPostgrestErrorMessage(from: data)
            let lower = message.lowercased()
            if lower.contains("not_friends") { throw SupabaseServiceError.notFriends }
            if lower.contains("invalid_target") { throw SupabaseServiceError.apiError("invalid user") }
            throw SupabaseServiceError.apiError(message.isEmpty ? "chat failed" : message)
        }

        struct Row: Decodable {
            let code: String
            let group_id: String
        }
        let rows = (try? decoder.decode([Row].self, from: data)) ?? []
        guard let first = rows.first else { throw SupabaseServiceError.apiError("chat failed") }
        return DirectChatInfo(code: first.code, groupId: first.group_id)
    }

    func listDirectChats(profileId: String, profilePairingCode: String, limit: Int = 50) async throws -> [DirectChatThread] {
        let v3 = try? await listDirectChatsV3(profileId: profileId, profilePairingCode: profilePairingCode, limit: limit)
        if let v3 { return v3 }

        let v2 = try? await listDirectChatsV2(profileId: profileId, profilePairingCode: profilePairingCode, limit: limit)
        if let v2 { return v2 }

        let url = config.restURL.appendingPathComponent("rpc/list_direct_chats_secure")
        let body: [String: Any] = [
            "p_profile_id": profileId,
            "p_profile_pairing_code": profilePairingCode.lowercased(),
            "p_limit": max(1, min(limit, 200))
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addAuthHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SupabaseServiceError.badStatus(-1) }
        if !(200...299 ~= http.statusCode) {
            let message = extractPostgrestErrorMessage(from: data)
            // Backward-compatible: if not deployed yet, don't break the app.
            if http.statusCode == 404 || message.localizedCaseInsensitiveContains("does not exist") {
                return []
            }
            throw SupabaseServiceError.apiError(message.isEmpty ? "chats failed" : message)
        }

        struct Row: Decodable {
            let code: String
            let other_profile_id: String
            let other_username: String
            let other_avatar_url: String?
            let last_created_at: String?
            let has_unread: Bool?
            let other_is_pro: Bool?
            let other_level: Int?
            let other_rank: Int?
        }

        let rows = (try? decoder.decode([Row].self, from: data)) ?? []
        return rows.map { row in
            DirectChatThread(
                code: row.code,
                otherProfileId: row.other_profile_id,
                otherUsername: row.other_username,
                otherAvatarURL: row.other_avatar_url.flatMap(URL.init(string:)),
                lastCreatedAt: row.last_created_at.flatMap(isoDate),
                hasUnread: row.has_unread ?? false,
                streakCount: 0,
                otherIsPro: row.other_is_pro ?? false,
                otherLevel: row.other_level,
                otherRank: row.other_rank
            )
        }
    }

    private func listDirectChatsV3(profileId: String, profilePairingCode: String, limit: Int) async throws -> [DirectChatThread] {
        let url = config.restURL.appendingPathComponent("rpc/list_direct_chats_secure_v3")
        let body: [String: Any] = [
            "p_profile_id": profileId,
            "p_profile_pairing_code": profilePairingCode.lowercased(),
            "p_limit": max(1, min(limit, 200))
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addAuthHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SupabaseServiceError.badStatus(-1) }
        if !(200...299 ~= http.statusCode) {
            let message = extractPostgrestErrorMessage(from: data)
            if http.statusCode == 404 || message.localizedCaseInsensitiveContains("does not exist") {
                throw SupabaseServiceError.apiError("missing_v3")
            }
            throw SupabaseServiceError.apiError(message.isEmpty ? "chats failed" : message)
        }

        struct Row: Decodable {
            let code: String
            let other_profile_id: String
            let other_username: String
            let other_avatar_url: String?
            let last_created_at: String?
            let has_unread: Bool?
            let streak_count: Int?
            let other_is_pro: Bool?
            let other_level: Int?
            let other_rank: Int?
        }

        let rows = (try? decoder.decode([Row].self, from: data)) ?? []
        return rows.map { row in
            DirectChatThread(
                code: row.code,
                otherProfileId: row.other_profile_id,
                otherUsername: row.other_username,
                otherAvatarURL: row.other_avatar_url.flatMap(URL.init(string:)),
                lastCreatedAt: row.last_created_at.flatMap(isoDate),
                hasUnread: row.has_unread ?? false,
                streakCount: max(0, row.streak_count ?? 0),
                otherIsPro: row.other_is_pro ?? false,
                otherLevel: row.other_level,
                otherRank: row.other_rank
            )
        }
    }

    private func listDirectChatsV2(profileId: String, profilePairingCode: String, limit: Int) async throws -> [DirectChatThread] {
        let url = config.restURL.appendingPathComponent("rpc/list_direct_chats_secure_v2")
        let body: [String: Any] = [
            "p_profile_id": profileId,
            "p_profile_pairing_code": profilePairingCode.lowercased(),
            "p_limit": max(1, min(limit, 200))
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addAuthHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SupabaseServiceError.badStatus(-1) }
        if !(200...299 ~= http.statusCode) {
            let message = extractPostgrestErrorMessage(from: data)
            if http.statusCode == 404 || message.localizedCaseInsensitiveContains("does not exist") {
                throw SupabaseServiceError.apiError("missing_v2")
            }
            throw SupabaseServiceError.apiError(message.isEmpty ? "chats failed" : message)
        }

        struct Row: Decodable {
            let code: String
            let other_profile_id: String
            let other_username: String
            let other_avatar_url: String?
            let last_created_at: String?
            let has_unread: Bool?
            let streak_count: Int?
            let other_is_pro: Bool?
            let other_level: Int?
            let other_rank: Int?
        }

        let rows = (try? decoder.decode([Row].self, from: data)) ?? []
        return rows.map { row in
            DirectChatThread(
                code: row.code,
                otherProfileId: row.other_profile_id,
                otherUsername: row.other_username,
                otherAvatarURL: row.other_avatar_url.flatMap(URL.init(string:)),
                lastCreatedAt: row.last_created_at.flatMap(isoDate),
                hasUnread: row.has_unread ?? false,
                streakCount: max(0, row.streak_count ?? 0),
                otherIsPro: row.other_is_pro ?? false,
                otherLevel: row.other_level,
                otherRank: row.other_rank
            )
        }
    }

    func createGroupV2(profileId: String, profilePairingCode: String, displayName: String?) async throws -> GroupSummary {
        let url = config.restURL.appendingPathComponent("rpc/create_group_v2_secure")
        let body: [String: Any] = [
            "p_profile_id": profileId,
            "p_profile_pairing_code": profilePairingCode.lowercased(),
            "p_display_name": displayName ?? NSNull()
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addAuthHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SupabaseServiceError.badStatus(-1) }
        if !(200...299 ~= http.statusCode) {
            let message = extractPostgrestErrorMessage(from: data)
            if http.statusCode == 404 || message.localizedCaseInsensitiveContains("does not exist") {
                throw SupabaseServiceError.apiError("groups not available yet")
            }
            throw SupabaseServiceError.apiError(message.isEmpty ? "create group failed" : message)
        }

        struct Row: Decodable {
            let code: String
            let display_name: String?
            let group_id: String
        }

        let rows = (try? decoder.decode([Row].self, from: data)) ?? []
        guard let first = rows.first else { throw SupabaseServiceError.apiError("create group failed") }
        return GroupSummary(
            id: first.group_id,
            code: first.code,
            displayName: first.display_name,
            ownerProfileId: profileId,
            memberCount: 1,
            createdAt: Date()
        )
    }

    func listGroupsV2(profileId: String, profilePairingCode: String, limit: Int = 50) async throws -> [GroupSummary] {
        let url = config.restURL.appendingPathComponent("rpc/list_groups_v2_secure")
        let body: [String: Any] = [
            "p_profile_id": profileId,
            "p_profile_pairing_code": profilePairingCode.lowercased(),
            "p_limit": max(1, min(limit, 200))
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addAuthHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SupabaseServiceError.badStatus(-1) }
        if !(200...299 ~= http.statusCode) {
            let message = extractPostgrestErrorMessage(from: data)
            // Backward-compatible: if not deployed yet, don't break the app.
            if http.statusCode == 404 || message.localizedCaseInsensitiveContains("does not exist") {
                return []
            }
            throw SupabaseServiceError.apiError(message.isEmpty ? "groups failed" : message)
        }

        struct Row: Decodable {
            let code: String
            let display_name: String?
            let owner_profile_id: String?
            let member_count: Int?
            let created_at: String?
        }

        let rows = (try? decoder.decode([Row].self, from: data)) ?? []
        let hiddenDefaultCode = profilePairingCode.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return rows
            .filter { row in
                let code = row.code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                return !code.isEmpty && code != hiddenDefaultCode
            }
            .map { row in
            GroupSummary(
                id: row.code,
                code: row.code,
                displayName: row.display_name,
                ownerProfileId: row.owner_profile_id,
                memberCount: row.member_count ?? 0,
                createdAt: row.created_at.flatMap(isoDate)
            )
        }
    }

    func listFriends(profileId: String, profilePairingCode: String, limit: Int = 200) async throws -> [FriendProfile] {
        let url = config.restURL.appendingPathComponent("rpc/list_friends_secure")
        let body: [String: Any] = [
            "p_profile_id": profileId,
            "p_profile_pairing_code": profilePairingCode.lowercased(),
            "p_limit": max(1, min(limit, 500))
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addAuthHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SupabaseServiceError.badStatus(-1) }
        if !(200...299 ~= http.statusCode) {
            let message = extractPostgrestErrorMessage(from: data)
            if http.statusCode == 404 || message.localizedCaseInsensitiveContains("does not exist") {
                return []
            }
            throw SupabaseServiceError.apiError(message.isEmpty ? "friends failed" : message)
        }

        struct Row: Decodable {
            let profile_id: String
            let username: String
            let avatar_url: String?
            let created_at: String?
        }

        let rows = (try? decoder.decode([Row].self, from: data)) ?? []
        return rows.map { row in
            FriendProfile(
                id: row.profile_id,
                username: row.username,
                avatarURL: row.avatar_url.flatMap(URL.init(string:)),
                createdAt: row.created_at.flatMap(isoDate)
            )
        }
    }

    func fetchProfileId(username: String, pairingCode: String) async throws -> String? {
        let url = config.restURL.appendingPathComponent("rpc/fetch_profile_id_secure")
        let body: [String: Any] = [
            "p_username": username.lowercased(),
            "p_pairing_code": pairingCode.lowercased()
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addAuthHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SupabaseServiceError.badStatus(-1) }
        guard 200...299 ~= http.statusCode else {
            let message = String(data: data, encoding: .utf8) ?? ""
            throw SupabaseServiceError.apiError(message.isEmpty ? "profile lookup failed" : message)
        }

        let raw = try? decoder.decode(String?.self, from: data)
        let id = raw?.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        return (id?.isEmpty == false) ? id : nil
    }

    func profileExists(profileId: String) async -> Bool {
        do {
            let url = config.restURL.appendingPathComponent("rpc/profile_exists_secure")
            let body: [String: Any] = ["p_profile_id": profileId]
            let bodyData = try JSONSerialization.data(withJSONObject: body)

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            addAuthHeaders(to: &request)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = bodyData

            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, 200...299 ~= http.statusCode else { return true }
            return (try? decoder.decode(Bool.self, from: data)) ?? true
        } catch {
            // Offline / transient errors: don't force logout.
            return true
        }
    }

    func deleteProfile(profileId: String, profilePairingCode: String) async throws {
        let url = config.restURL.appendingPathComponent("rpc/delete_profile_secure")
        let body: [String: Any] = [
            "p_profile_id": profileId,
            "p_profile_pairing_code": profilePairingCode.lowercased()
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addAuthHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SupabaseServiceError.badStatus(-1) }
        if !(200...299 ~= http.statusCode) {
            let message = String(data: data, encoding: .utf8) ?? ""
            throw SupabaseServiceError.apiError(message.isEmpty ? "delete failed" : message)
        }
    }

    func ensureGroup(pairingCode: String, profileId: String, profilePairingCode: String) async throws {
        let url = config.restURL.appendingPathComponent("rpc/ensure_group_secure")
        let body: [String: Any] = [
            "p_code": pairingCode.lowercased(),
            "p_profile_id": profileId,
            "p_profile_pairing_code": profilePairingCode.lowercased()
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addAuthHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SupabaseServiceError.badStatus(-1) }
        if !(200...299 ~= http.statusCode) {
            let message = String(data: data, encoding: .utf8) ?? ""
            throw SupabaseServiceError.apiError(message.isEmpty ? "group ensure failed" : message)
        }
    }

    func joinGroup(pairingCode: String, profileId: String, profilePairingCode: String) async throws {
        let url = config.restURL.appendingPathComponent("rpc/join_group_secure")
        let body: [String: Any] = [
            "p_code": pairingCode.lowercased(),
            "p_profile_id": profileId,
            "p_profile_pairing_code": profilePairingCode.lowercased()
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addAuthHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SupabaseServiceError.badStatus(-1) }
        if !(200...299 ~= http.statusCode) {
            let message = String(data: data, encoding: .utf8) ?? ""
            if message.contains("invalid_code") { throw SupabaseServiceError.invalidCode }
            if message.contains("group_full") { throw SupabaseServiceError.badStatus(409) }
            throw SupabaseServiceError.apiError(message.isEmpty ? "join failed" : message)
        }
    }

    func fetchGroupMembers(pairingCode: String, requesterProfileId: String) async throws -> [GroupMemberProfile] {
        let url = config.restURL.appendingPathComponent("rpc/group_members_secure")
        let body: [String: Any] = [
            "p_code": pairingCode.lowercased(),
            "requester_profile_id": requesterProfileId
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addAuthHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SupabaseServiceError.badStatus(-1) }
        if !(200...299 ~= http.statusCode) {
            let message = String(data: data, encoding: .utf8) ?? ""
            if message.contains("not_member") {
                throw SupabaseServiceError.notMember
            }
            if message.contains("invalid_code") {
                throw SupabaseServiceError.invalidCode
            }
            if http.statusCode == 404 {
                throw SupabaseServiceError.invalidCode
            }
            throw SupabaseServiceError.apiError(message.isEmpty ? "unknown supabase error" : message)
        }

        struct MemberRow: Decodable {
            let profile_id: String
            let username: String
            let avatar_url: String?
            let streak_count: Int?
            let is_online: Bool?
            let is_pro: Bool?
        }

        let rows = (try? decoder.decode([MemberRow].self, from: data)) ?? []
        let members = rows.map { row in
            GroupMemberProfile(
                id: row.profile_id,
                username: row.username,
                avatarURL: row.avatar_url.flatMap(URL.init(string:)),
                streakCount: row.streak_count ?? 0,
                isOnline: row.is_online ?? false,
                isPro: row.is_pro ?? false
            )
        }
        return members.sorted { $0.username.lowercased() < $1.username.lowercased() }
    }

    func fetchGroupMemberCounts(groupCodes: [String], requesterProfileId: String) async throws -> [String: (count: Int, max: Int)] {
        let url = config.restURL.appendingPathComponent("rpc/group_member_counts_secure")
        let codes = groupCodes
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        let body: [String: Any] = [
            "p_codes": codes,
            "p_requester_profile_id": requesterProfileId
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addAuthHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SupabaseServiceError.badStatus(-1) }
        if !(200...299 ~= http.statusCode) {
            let message = String(data: data, encoding: .utf8) ?? ""
            throw SupabaseServiceError.apiError(message.isEmpty ? "group count failed" : message)
        }

        let rows = (try? decoder.decode([GroupMemberCountRow].self, from: data)) ?? []
        var result: [String: (count: Int, max: Int)] = [:]
        for row in rows {
            let key = row.code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let count = row.member_count ?? 0
            let max = row.max_members ?? 15
            if !key.isEmpty {
                result[key] = (count, max)
            }
        }
        return result
    }

    func updatePresence(profileId: String, profilePairingCode: String) async throws {
        let url = config.restURL.appendingPathComponent("rpc/update_presence_secure")
        let body: [String: Any] = [
            "p_profile_id": profileId,
            "p_profile_pairing_code": profilePairingCode.lowercased()
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addAuthHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SupabaseServiceError.badStatus(-1) }
        if !(200...299 ~= http.statusCode) {
            let message = String(data: data, encoding: .utf8) ?? ""
            throw SupabaseServiceError.apiError(message.isEmpty ? "presence update failed" : message)
        }
    }

    func fetchGroupOwnerProfileId(pairingCode: String) async throws -> String? {
        let url = config.restURL.appendingPathComponent("rpc/fetch_group_owner_secure")
        let body: [String: Any] = ["p_code": pairingCode.lowercased()]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addAuthHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SupabaseServiceError.badStatus(-1) }
        guard 200...299 ~= http.statusCode else {
            let message = String(data: data, encoding: .utf8) ?? ""
            throw SupabaseServiceError.apiError(message.isEmpty ? "owner lookup failed" : message)
        }

        let raw = try? decoder.decode(String?.self, from: data)
        let id = raw?.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        return (id?.isEmpty == false) ? id : nil
    }

    func removeMember(pairingCode: String, requesterProfileId: String, requesterPairingCode: String, memberProfileId: String) async throws {
        let url = config.restURL.appendingPathComponent("rpc/remove_member_secure")
        let body: [String: Any] = [
            "p_code": pairingCode.lowercased(),
            "p_requester_profile_id": requesterProfileId,
            "p_requester_pairing_code": requesterPairingCode.lowercased(),
            "p_member_profile_id": memberProfileId
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addAuthHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SupabaseServiceError.badStatus(-1) }
        if !(200...299 ~= http.statusCode) {
            let message = String(data: data, encoding: .utf8) ?? ""
            if message.contains("invalid_code") { throw SupabaseServiceError.invalidCode }
            throw SupabaseServiceError.apiError(message.isEmpty ? "remove failed" : message)
        }
    }

    func leaveGroup(pairingCode: String, profileId: String, profilePairingCode: String) async throws {
        let url = config.restURL.appendingPathComponent("rpc/leave_group_secure")
        let body: [String: Any] = [
            "p_code": pairingCode.lowercased(),
            "p_profile_id": profileId,
            "p_profile_pairing_code": profilePairingCode.lowercased()
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addAuthHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SupabaseServiceError.badStatus(-1) }
        if !(200...299 ~= http.statusCode) {
            let message = String(data: data, encoding: .utf8) ?? ""
            if message.contains("invalid_code") { throw SupabaseServiceError.invalidCode }
            throw SupabaseServiceError.apiError(message.isEmpty ? "leave failed" : message)
        }
    }

    func deleteAvatar(fileURL: URL) async throws {
        guard let path = extractPath(from: fileURL) else {
            throw SupabaseServiceError.invalidURL
        }

        let deleteURL = config.storageURL
            .appendingPathComponent("object")
            .appendingPathComponent(config.bucket)
            .appendingPathComponent(path)

        var request = URLRequest(url: deleteURL)
        request.httpMethod = "DELETE"
        addAuthHeaders(to: &request)

        // Best-effort: storage deletes are disabled in production policies (old avatar files can remain).
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { return }
        guard 200...299 ~= http.statusCode else { return }
    }

    func updateProfileAvatar(profileId: String, profilePairingCode: String, avatarURL: URL?) async throws {
        let url = config.restURL.appendingPathComponent("rpc/update_avatar_secure")
        let body: [String: Any] = [
            "p_profile_id": profileId,
            "p_profile_pairing_code": profilePairingCode.lowercased(),
            "p_avatar_url": avatarURL?.absoluteString ?? ""
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addAuthHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SupabaseServiceError.badStatus(-1) }
        if !(200...299 ~= http.statusCode) {
            let message = String(data: data, encoding: .utf8) ?? ""
            throw SupabaseServiceError.apiError(message.isEmpty ? "avatar update failed" : message)
        }
    }

    func updateUsername(profileId: String, profilePairingCode: String, username: String) async throws {
        let normalized = UsernameRules.sanitize(username)
        guard UsernameRules.isValid(normalized) else { throw SupabaseServiceError.apiError("invalid username") }

        let url = config.restURL.appendingPathComponent("rpc/update_username_secure")
        let body: [String: Any] = [
            "p_profile_id": profileId,
            "p_profile_pairing_code": profilePairingCode.lowercased(),
            "p_new_username": normalized
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addAuthHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SupabaseServiceError.badStatus(-1) }
        if !(200...299 ~= http.statusCode) {
            let message = String(data: data, encoding: .utf8) ?? ""
            if message.contains("username_taken") { throw SupabaseServiceError.unavailableUsername }
            throw SupabaseServiceError.apiError(message.isEmpty ? "username update failed" : message)
        }
    }

    func upsertApnsDeviceToken(profileId: String, profilePairingCode: String, token: String, environment: PushEnvironment) async throws {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard trimmed.count >= 32 else { throw SupabaseServiceError.invalidDeviceToken }

        let url = config.restURL.appendingPathComponent("rpc/upsert_profile_device_secure")
        let body: [String: Any] = [
            "p_profile_id": profileId,
            "p_profile_pairing_code": profilePairingCode.lowercased(),
            "p_apns_token": trimmed,
            "p_environment": environment.rawValue
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addAuthHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SupabaseServiceError.badStatus(-1) }
        if !(200...299 ~= http.statusCode) {
            let message = String(data: data, encoding: .utf8) ?? ""
            if message.contains("invalid_token") { throw SupabaseServiceError.invalidDeviceToken }
            throw SupabaseServiceError.apiError(message.isEmpty ? "token upsert failed" : message)
        }
    }

    private func extractPath(from url: URL) -> String? {
        // Expecting .../storage/v1/object/public/{bucket}/{path}
        let components = url.pathComponents
        guard let bucketIndex = components.firstIndex(of: config.bucket) else {
            return url.lastPathComponent.isEmpty ? nil : url.lastPathComponent
        }
        let pathComponents = components[(bucketIndex + 1)...]
        return pathComponents.joined(separator: "/")
    }

    func inviteToGroup(groupCode: String, inviterProfileId: String, invitedUsername: String) async throws {
        let url = config.restURL.appendingPathComponent("rpc/invite_to_group_secure")
        let body: [String: Any] = [
            "p_group_code": groupCode.lowercased(),
            "p_inviter_profile_id": inviterProfileId,
            "p_invited_username": invitedUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addAuthHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SupabaseServiceError.badStatus(-1) }
        if !(200...299 ~= http.statusCode) {
            let message = String(data: data, encoding: .utf8) ?? ""
            if message.contains("user_not_found") { throw SupabaseServiceError.userNotFound }
            if message.contains("already_member") { throw SupabaseServiceError.alreadyMember }
            if message.contains("self_invite") { throw SupabaseServiceError.selfInvite }
            if message.contains("not_member") { throw SupabaseServiceError.notMember }
            if message.contains("invalid_code") { throw SupabaseServiceError.invalidCode }
            throw SupabaseServiceError.apiError(message.isEmpty ? "unknown supabase error" : message)
        }
    }

    func listInvites(profileId: String) async throws -> [GroupInvite] {
        let url = config.restURL.appendingPathComponent("rpc/list_invites_secure")
        let body: [String: Any] = ["p_profile_id": profileId]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addAuthHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, 200...299 ~= http.statusCode else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw SupabaseServiceError.badStatus(status)
        }

        struct InviteRow: Decodable {
            let invite_id: String
            let group_code: String
            let inviter_username: String
            let status: String
            let created_at: String?
        }

        let rows = (try? decoder.decode([InviteRow].self, from: data)) ?? []
        return rows.map { row in
            GroupInvite(
                id: row.invite_id,
                groupCode: row.group_code,
                inviterUsername: row.inviter_username,
                status: row.status,
                createdAt: row.created_at.flatMap(isoDate)
            )
        }
    }

    func respondInvite(inviteId: String, profileId: String, profilePairingCode: String, accept: Bool) async throws -> String {
        let url = config.restURL.appendingPathComponent("rpc/respond_invite_secure")
        let body: [String: Any] = [
            "p_invite_id": inviteId,
            "p_profile_id": profileId,
            "p_profile_pairing_code": profilePairingCode.lowercased(),
            "p_accept": accept
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addAuthHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SupabaseServiceError.badStatus(-1) }
        if !(200...299 ~= http.statusCode) {
            let message = String(data: data, encoding: .utf8) ?? ""
            throw SupabaseServiceError.apiError(message.isEmpty ? "unknown supabase error" : message)
        }
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "\"")) ?? ""
    }

    func sendDoodle(image: UIImage, groupCode: String, senderProfileId: String, senderPairingCode: String) async throws -> String {
        let content = try makeDoodleDataURL(from: image)
        return try await createDoodleRecord(groupCode: groupCode, senderProfileId: senderProfileId, senderPairingCode: senderPairingCode, contentBase64: content)
    }

    func fetchProfileXP(profileId: String, pairingCode: String) async throws -> ProfileXPState {
        let url = config.restURL.appendingPathComponent("rpc/profile_xp_secure")
        let body: [String: Any] = [
            "p_profile_id": profileId,
            "p_profile_pairing_code": pairingCode.lowercased()
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addAuthHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (data, response) = try await dataWithTimeoutRetry(for: request)
        guard let http = response as? HTTPURLResponse else { throw SupabaseServiceError.badStatus(-1) }
        if !(200...299 ~= http.statusCode) {
            let message = String(data: data, encoding: .utf8) ?? ""
            throw SupabaseServiceError.apiError(message.isEmpty ? "unknown supabase error" : message)
        }

        // PostgREST returns SETOF/table responses as arrays.
        if let rows = try? decoder.decode([ProfileXPState].self, from: data), let first = rows.first {
            return first
        }

        // Fallback for unexpected formats.
        return ProfileXPState(xpTotal: 0, level: 1, levelXP: 0, nextLevelXP: 60)
    }

    func submitAnonymousDoodle(image: UIImage, shortCode: String) async throws -> String {
        let url = config.restURL.appendingPathComponent("rpc/submit_anonymous_doodle")
        let content = try makeDoodleDataURL(from: image)
        let fingerprint = anonymousSenderFingerprint()
        let body: [String: Any] = [
            "p_short_code": shortCode.lowercased(),
            "p_content_base64": content,
            "p_sender_fingerprint": fingerprint
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addAuthHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SupabaseServiceError.badStatus(-1) }
        if !(200...299 ~= http.statusCode) {
            let message = String(data: data, encoding: .utf8) ?? ""
            if message.contains("invalid_code") { throw SupabaseServiceError.invalidCode }
            if message.contains("not_found") { throw SupabaseServiceError.invalidCode }
            if message.contains("invalid_content") { throw SupabaseServiceError.invalidDoodle }
            if message.contains("image_too_large") { throw SupabaseServiceError.imageTooLarge }
            if message.contains("blocked") { throw SupabaseServiceError.apiError("you can’t send to this user") }
            throw SupabaseServiceError.apiError(message.isEmpty ? "unknown supabase error" : message)
        }
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"")) ?? ""
    }

    func searchAnonymousReceivers(requesterProfileId: String, requesterPairingCode: String, query: String, limit: Int = 12) async throws -> [AnonymousReceiver] {
        let url = config.restURL.appendingPathComponent("rpc/search_anonymous_receivers_secure")
        let body: [String: Any] = [
            "p_requester_profile_id": requesterProfileId,
            "p_requester_pairing_code": requesterPairingCode.lowercased(),
            "p_query": query,
            "p_limit": limit
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addAuthHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (data, response) = try await dataWithTimeoutRetry(for: request)
        guard let http = response as? HTTPURLResponse else { throw SupabaseServiceError.badStatus(-1) }
        if !(200...299 ~= http.statusCode) {
            let message = String(data: data, encoding: .utf8) ?? ""
            throw SupabaseServiceError.apiError(message.isEmpty ? "unknown supabase error" : message)
        }

        struct Row: Decodable {
            let profile_id: String
            let username: String
            let avatar_url: String?
        }

        let rows = (try? decoder.decode([Row].self, from: data)) ?? []
        return rows.map { row in
            AnonymousReceiver(
                id: row.profile_id,
                username: row.username,
                avatarURL: row.avatar_url.flatMap(URL.init(string:))
            )
        }
    }

    func submitAnonymousDoodleToProfile(
        image: UIImage,
        senderProfileId: String,
        senderPairingCode: String,
        recipientProfileId: String
    ) async throws -> String {
        let url = config.restURL.appendingPathComponent("rpc/submit_anonymous_doodle_to_profile_secure")
        let content = try makeDoodleDataURL(from: image)
        let fingerprint = anonymousSenderFingerprint()
        let body: [String: Any] = [
            "p_sender_profile_id": senderProfileId,
            "p_sender_pairing_code": senderPairingCode.lowercased(),
            "p_recipient_profile_id": recipientProfileId,
            "p_content_base64": content,
            "p_sender_fingerprint": fingerprint
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addAuthHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (data, response) = try await dataWithTimeoutRetry(for: request)
        guard let http = response as? HTTPURLResponse else { throw SupabaseServiceError.badStatus(-1) }
        if !(200...299 ~= http.statusCode) {
            let message = String(data: data, encoding: .utf8) ?? ""
            if message.contains("blocked") { throw SupabaseServiceError.apiError("you can’t send to this user") }
            throw SupabaseServiceError.apiError(message.isEmpty ? "unknown supabase error" : message)
        }

        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"")) ?? ""
    }

    func fetchInboxDoodles(groupCode: String, requesterProfileId: String, limit: Int = 18) async throws -> [InboxDoodle] {
        let url = config.restURL.appendingPathComponent("rpc/inbox_doodles_secure")
        let body: [String: Any] = [
            "p_code": groupCode.lowercased(),
            "p_requester_profile_id": requesterProfileId,
            "p_limit": max(1, min(limit, 18))
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addAuthHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (data, response) = try await dataWithTimeoutRetry(for: request)
        guard let http = response as? HTTPURLResponse else { throw SupabaseServiceError.badStatus(-1) }
        if !(200...299 ~= http.statusCode) {
            let message = String(data: data, encoding: .utf8) ?? ""
            if message.contains("not_member") { throw SupabaseServiceError.notMember }
            if message.contains("invalid_code") { throw SupabaseServiceError.invalidCode }
            throw SupabaseServiceError.apiError(message.isEmpty ? "unknown supabase error" : message)
        }

        struct Row: Decodable {
            let doodle_id: String
            let sender_profile_id: String
            let content_base64: String?
            let sender_username: String
            let created_at: String?
            let sender_is_pro: Bool?
        }

        let rows = (try? decoder.decode([Row].self, from: data)) ?? []
        return rows.map { row in
            InboxDoodle(
                id: row.doodle_id,
                senderProfileId: row.sender_profile_id,
                contentBase64: row.content_base64,
                senderUsername: row.sender_username,
                createdAt: row.created_at.flatMap(isoDate),
                senderIsPro: row.sender_is_pro ?? false
            )
        }
    }

    func fetchInboxDoodleMetas(groupCode: String, requesterProfileId: String, limit: Int = 18) async throws -> [InboxDoodle] {
        let url = config.restURL.appendingPathComponent("rpc/inbox_doodle_metas_secure")
        let body: [String: Any] = [
            "p_code": groupCode.lowercased(),
            "p_requester_profile_id": requesterProfileId,
            "p_limit": max(1, min(limit, 18))
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addAuthHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (data, response) = try await dataWithTimeoutRetry(for: request)
        guard let http = response as? HTTPURLResponse else { throw SupabaseServiceError.badStatus(-1) }
        if !(200...299 ~= http.statusCode) {
            let message = String(data: data, encoding: .utf8) ?? ""
            if message.contains("not_member") { throw SupabaseServiceError.notMember }
            if message.contains("invalid_code") { throw SupabaseServiceError.invalidCode }
            throw SupabaseServiceError.apiError(message.isEmpty ? "unknown supabase error" : message)
        }

        struct Row: Decodable {
            let doodle_id: String
            let sender_profile_id: String
            let sender_username: String
            let created_at: String?
            let sender_is_pro: Bool?
        }

        let rows = (try? decoder.decode([Row].self, from: data)) ?? []
        return rows.map { row in
            InboxDoodle(
                id: row.doodle_id,
                senderProfileId: row.sender_profile_id,
                contentBase64: nil,
                senderUsername: row.sender_username,
                createdAt: row.created_at.flatMap(isoDate),
                senderIsPro: row.sender_is_pro ?? false
            )
        }
    }

    func fetchDoodleContents(groupCode: String, requesterProfileId: String, doodleIds: [String]) async throws -> [String: String] {
        let ids = doodleIds.compactMap(UUID.init(uuidString:))
        if ids.isEmpty { return [:] }
        var result: [String: String] = [:]
        result.reserveCapacity(min(ids.count, 200))

        // Keep payloads small to avoid PostgREST/DB statement timeouts on large base64 rows.
        let chunkSize = 6
        var i = 0
        while i < ids.count {
            let end = min(ids.count, i + chunkSize)
            let slice = Array(ids[i..<end])
            let chunk = try await fetchDoodleContentsChunk(groupCode: groupCode, requesterProfileId: requesterProfileId, doodleIds: slice)
            for (k, v) in chunk {
                result[k] = v
            }
            i = end
        }

        return result
	    }

    private func fetchDoodleContentsChunk(groupCode: String, requesterProfileId: String, doodleIds: [UUID]) async throws -> [String: String] {
        if doodleIds.isEmpty { return [:] }
        let url = config.restURL.appendingPathComponent("rpc/doodle_contents_secure")
        let body: [String: Any] = [
            "p_code": groupCode.lowercased(),
            "p_requester_profile_id": requesterProfileId,
            "p_doodle_ids": doodleIds.map { $0.uuidString }
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addAuthHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (data, response) = try await dataWithTimeoutRetry(for: request)
        guard let http = response as? HTTPURLResponse else { throw SupabaseServiceError.badStatus(-1) }
        if !(200...299 ~= http.statusCode) {
            let message = extractPostgrestErrorMessage(from: data)
            let lower = message.lowercased()
            if lower.contains("not_member") { throw SupabaseServiceError.notMember }
            if lower.contains("invalid_code") { throw SupabaseServiceError.invalidCode }
            throw SupabaseServiceError.apiError(message.isEmpty ? "unknown supabase error" : message)
        }

        struct Row: Decodable {
            let doodle_id: String
            let content_base64: String?
        }

        let rows = (try? decoder.decode([Row].self, from: data)) ?? []
        var chunk: [String: String] = [:]
        chunk.reserveCapacity(rows.count)
        for row in rows {
            guard let content = row.content_base64, !content.isEmpty else { continue }
            chunk[row.doodle_id] = content
        }
        return chunk
    }

	    private func dataWithTimeoutRetry(for request: URLRequest) async throws -> (Data, URLResponse) {
            var attempt = 0
            var delayNs: UInt64 = 350_000_000

            while true {
                attempt += 1
                let (data, response) = try await session.data(for: request)

                if let http = response as? HTTPURLResponse, !(200...299 ~= http.statusCode) {
                    let message = String(data: data, encoding: .utf8) ?? ""
                    let isTimeout =
                        message.localizedCaseInsensitiveContains("statement timeout")
                        || message.localizedCaseInsensitiveContains("canceling statement")
                        || message.contains("\"code\":\"57014\"")
                        || message.contains("57014")

                    if isTimeout, attempt < 3 {
                        try await Task.sleep(nanoseconds: delayNs)
                        delayNs = min(delayNs * 2, 1_400_000_000)
                        continue
                    }
                }

                return (data, response)
            }
    }

    func getAnonymousLinkStatus(profileId: String, profilePairingCode: String) async throws -> (shortCode: String?, isEnabled: Bool) {
        let url = config.restURL.appendingPathComponent("rpc/get_anonymous_link_secure")
        let body: [String: Any] = [
            "p_profile_id": profileId,
            "p_profile_pairing_code": profilePairingCode.lowercased()
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addAuthHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SupabaseServiceError.badStatus(-1) }
        if !(200...299 ~= http.statusCode) {
            let message = String(data: data, encoding: .utf8) ?? ""
            if message.contains("unauthorized") { throw SupabaseServiceError.apiError("unauthorized") }
            throw SupabaseServiceError.apiError(message.isEmpty ? "unknown supabase error" : message)
        }

        let decoded = try decoder.decode([AnonymousLinkStatusRow].self, from: data)
        let row = decoded.first
        return (row?.short_code, row?.is_enabled ?? false)
    }

    func setAnonymousLinkEnabled(profileId: String, profilePairingCode: String, enabled: Bool) async throws -> (shortCode: String?, isEnabled: Bool) {
        let url = config.restURL.appendingPathComponent("rpc/set_anonymous_link_enabled_secure")
        let body: [String: Any] = [
            "p_profile_id": profileId,
            "p_profile_pairing_code": profilePairingCode.lowercased(),
            "p_enabled": enabled
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addAuthHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SupabaseServiceError.badStatus(-1) }
        if !(200...299 ~= http.statusCode) {
            let message = String(data: data, encoding: .utf8) ?? ""
            if message.contains("unauthorized") { throw SupabaseServiceError.apiError("unauthorized") }
            throw SupabaseServiceError.apiError(message.isEmpty ? "unknown supabase error" : message)
        }

        let decoded = try decoder.decode([AnonymousLinkStatusRow].self, from: data)
        let row = decoded.first
        return (row?.short_code, row?.is_enabled ?? false)
    }

    func fetchAnonymousInboxDoodles(profileId: String, profilePairingCode: String, limit: Int = 50) async throws -> [AnonymousInboxDoodle] {
        let url = config.restURL.appendingPathComponent("rpc/anonymous_inbox_doodles_secure")
        let body: [String: Any] = [
            "p_profile_id": profileId,
            "p_profile_pairing_code": profilePairingCode.lowercased(),
            "p_limit": limit
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addAuthHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SupabaseServiceError.badStatus(-1) }
        if !(200...299 ~= http.statusCode) {
            let message = String(data: data, encoding: .utf8) ?? ""
            if message.contains("unauthorized") { throw SupabaseServiceError.apiError("unauthorized") }
            throw SupabaseServiceError.apiError(message.isEmpty ? "unknown supabase error" : message)
        }

        let rows = try decoder.decode([AnonymousInboxRow].self, from: data)
        return rows.compactMap { row in
            guard let content = row.content_base64, !content.isEmpty else { return nil }
            return AnonymousInboxDoodle(
                id: row.id,
                contentBase64: content,
                senderFingerprint: row.sender_fingerprint,
                createdAt: isoDate(row.created_at ?? "")
            )
        }
    }

    func fetchInboxSenders(groupCode: String, requesterProfileId: String) async throws -> [InboxSender] {
        let url = config.restURL.appendingPathComponent("rpc/inbox_senders_secure")
        let body: [String: Any] = [
            "p_code": groupCode.lowercased(),
            "p_requester_profile_id": requesterProfileId
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addAuthHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SupabaseServiceError.badStatus(-1) }
        if !(200...299 ~= http.statusCode) {
            let message = String(data: data, encoding: .utf8) ?? ""
            if message.contains("not_member") { throw SupabaseServiceError.notMember }
            if message.contains("invalid_code") { throw SupabaseServiceError.invalidCode }
            throw SupabaseServiceError.apiError(message.isEmpty ? "unknown supabase error" : message)
        }

        struct Row: Decodable {
            let sender_profile_id: String
            let sender_username: String
            let sender_avatar_url: String?
            let unread_count: Int?
            let last_created_at: String?
        }

        let rows = (try? decoder.decode([Row].self, from: data)) ?? []
        return rows.map { row in
            InboxSender(
                id: row.sender_profile_id,
                username: row.sender_username,
                avatarURL: row.sender_avatar_url.flatMap(URL.init(string:)),
                unreadCount: row.unread_count ?? 0,
                lastCreatedAt: row.last_created_at.flatMap(isoDate)
            )
        }
    }

    func fetchThreadDoodles(groupCode: String, requesterProfileId: String, requesterPairingCode: String, senderProfileId: String, limit: Int = 200) async throws -> [InboxDoodle] {
        let url = config.restURL.appendingPathComponent("rpc/thread_doodles_secure")
        let body: [String: Any] = [
            "p_code": groupCode.lowercased(),
            "p_requester_profile_id": requesterProfileId,
            "p_requester_pairing_code": requesterPairingCode.lowercased(),
            "p_sender_profile_id": senderProfileId,
            "p_limit": limit
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addAuthHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SupabaseServiceError.badStatus(-1) }
        if !(200...299 ~= http.statusCode) {
            let message = String(data: data, encoding: .utf8) ?? ""
            if message.contains("not_member") { throw SupabaseServiceError.notMember }
            if message.contains("invalid_code") { throw SupabaseServiceError.invalidCode }
            throw SupabaseServiceError.apiError(message.isEmpty ? "unknown supabase error" : message)
        }

        struct Row: Decodable {
            let doodle_id: String
            let content_base64: String?
            let sender_username: String
            let created_at: String?
        }

        let rows = (try? decoder.decode([Row].self, from: data)) ?? []
        return rows.compactMap { row in
            guard let content = row.content_base64, !content.isEmpty else { return nil }
            return InboxDoodle(
                id: row.doodle_id,
                senderProfileId: senderProfileId,
                contentBase64: content,
                senderUsername: row.sender_username,
                createdAt: row.created_at.flatMap(isoDate)
            )
        }
    }

    func blockProfile(profileId: String, profilePairingCode: String, blockedProfileId: String) async throws {
        let url = config.restURL.appendingPathComponent("rpc/block_profile_secure")
        let body: [String: Any] = [
            "p_profile_id": profileId,
            "p_profile_pairing_code": profilePairingCode.lowercased(),
            "p_blocked_profile_id": blockedProfileId
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addAuthHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SupabaseServiceError.badStatus(-1) }
        if !(200...299 ~= http.statusCode) {
            let message = String(data: data, encoding: .utf8) ?? ""
            throw SupabaseServiceError.apiError(message.isEmpty ? "block failed" : message)
        }
    }

    func unblockProfile(profileId: String, profilePairingCode: String, blockedProfileId: String) async throws {
        let url = config.restURL.appendingPathComponent("rpc/unblock_profile_secure")
        let body: [String: Any] = [
            "p_profile_id": profileId,
            "p_profile_pairing_code": profilePairingCode.lowercased(),
            "p_blocked_profile_id": blockedProfileId
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addAuthHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SupabaseServiceError.badStatus(-1) }
        if !(200...299 ~= http.statusCode) {
            let message = String(data: data, encoding: .utf8) ?? ""
            throw SupabaseServiceError.apiError(message.isEmpty ? "unblock failed" : message)
        }
    }

    func removeFriend(profileId: String, profilePairingCode: String, friendProfileId: String) async throws {
        let url = config.restURL.appendingPathComponent("rpc/remove_friend_secure")
        let body: [String: Any] = [
            "p_profile_id": profileId,
            "p_profile_pairing_code": profilePairingCode.lowercased(),
            "p_friend_profile_id": friendProfileId
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addAuthHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SupabaseServiceError.badStatus(-1) }
        if !(200...299 ~= http.statusCode) {
            let message = extractPostgrestErrorMessage(from: data)
            if http.statusCode == 404 || message.localizedCaseInsensitiveContains("does not exist") {
                throw SupabaseServiceError.apiError("remove friend not available yet")
            }
            throw SupabaseServiceError.apiError(message.isEmpty ? "remove friend failed" : message)
        }
    }

    func listBlockedUsers(profileId: String, profilePairingCode: String) async throws -> [BlockedUser] {
        let url = config.restURL.appendingPathComponent("rpc/list_blocked_users_secure")
        let body: [String: Any] = [
            "p_profile_id": profileId,
            "p_profile_pairing_code": profilePairingCode.lowercased()
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addAuthHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SupabaseServiceError.badStatus(-1) }
        if !(200...299 ~= http.statusCode) {
            let message = extractPostgrestErrorMessage(from: data)
            if http.statusCode == 404 || message.localizedCaseInsensitiveContains("does not exist") {
                throw SupabaseServiceError.apiError("blocked list not available yet")
            }
            throw SupabaseServiceError.apiError(message.isEmpty ? "failed to load blocked users" : message)
        }

        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            return self.isoDate(value) ?? Date()
        }
        let rows = (try? decoder.decode([BlockedUserRow].self, from: data)) ?? []
        return rows.compactMap { row in
            guard let blockedId = row.blocked_profile_id?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !blockedId.isEmpty else { return nil }
            let username = (row.username ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let avatarURL = (row.avatar_url.flatMap(URL.init(string:)))
            let createdAt = row.created_at.flatMap(isoDate)
            return BlockedUser(id: blockedId, username: username.isEmpty ? "unknown" : username, avatarURL: avatarURL, createdAt: createdAt)
        }
    }

    func blockAnonymousSender(profileId: String, profilePairingCode: String, senderFingerprint: String) async throws {
        let url = config.restURL.appendingPathComponent("rpc/block_anonymous_sender_secure")
        let body: [String: Any] = [
            "p_profile_id": profileId,
            "p_profile_pairing_code": profilePairingCode.lowercased(),
            "p_sender_fingerprint": senderFingerprint
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addAuthHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SupabaseServiceError.badStatus(-1) }
        if !(200...299 ~= http.statusCode) {
            let message = String(data: data, encoding: .utf8) ?? ""
            throw SupabaseServiceError.apiError(message.isEmpty ? "block failed" : message)
        }
    }

    func reportContent(profileId: String, profilePairingCode: String, kind: String, contentId: String, reason: String?) async throws -> String {
        let url = config.restURL.appendingPathComponent("rpc/report_content_secure")
        let body: [String: Any] = [
            "p_profile_id": profileId,
            "p_profile_pairing_code": profilePairingCode.lowercased(),
            "p_content_kind": kind,
            "p_content_id": contentId,
            "p_reason": reason ?? ""
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addAuthHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SupabaseServiceError.badStatus(-1) }
        if !(200...299 ~= http.statusCode) {
            let message = String(data: data, encoding: .utf8) ?? ""
            throw SupabaseServiceError.apiError(message.isEmpty ? "report failed" : message)
        }

        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"")) ?? ""
    }

    private func createDoodleRecord(groupCode: String, senderProfileId: String, senderPairingCode: String, contentBase64: String) async throws -> String {
        let url = config.restURL.appendingPathComponent("rpc/create_doodle_secure")
        let body: [String: Any] = [
            "p_code": groupCode.lowercased(),
            "p_sender_profile_id": senderProfileId,
            "p_content_base64": contentBase64,
            "p_sender_pairing_code": senderPairingCode.lowercased()
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addAuthHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SupabaseServiceError.badStatus(-1) }
        if !(200...299 ~= http.statusCode) {
            let message = extractPostgrestErrorMessage(from: data)
            let lower = message.lowercased()
            if lower.contains("not_member") { throw SupabaseServiceError.notMember }
            if lower.contains("invalid_code") { throw SupabaseServiceError.invalidCode }
            if lower.contains("invalid_content") { throw SupabaseServiceError.invalidDoodle }
            if lower.contains("image_too_large") { throw SupabaseServiceError.imageTooLarge }
            if lower.contains("cooldown") || lower.contains("wait 60") || lower.contains("wacht 60") {
                throw SupabaseServiceError.cooldown
            }
            if lower.contains("unauthorized") { throw SupabaseServiceError.apiError("unauthorized") }
            throw SupabaseServiceError.apiError(message.isEmpty ? "unknown supabase error" : message)
        }
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"")) ?? ""
    }

    private func addAuthHeaders(to request: inout URLRequest) {
        request.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
    }

    private func anonymousSenderFingerprint() -> String {
        let key = "anonymous.senderFingerprint"
        if let existing = UserDefaults.standard.string(forKey: key), !existing.isEmpty {
            return existing
        }
        let created = UUID().uuidString.lowercased()
        UserDefaults.standard.set(created, forKey: key)
        return created
    }

    private func isoDate(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: string) ?? ISO8601DateFormatter().date(from: string)
    }

    private func extractPostgrestErrorMessage(from data: Data) -> String {
        if let obj = try? JSONSerialization.jsonObject(with: data, options: []),
           let dict = obj as? [String: Any] {
            if let message = dict["message"] as? String { return message }
            if let error = dict["error"] as? String { return error }
            if let hint = dict["hint"] as? String { return hint }
        }
        return String(data: data, encoding: .utf8) ?? ""
    }

}

private extension UIImage {
    func resizedToMaxDimension(_ maxDimension: CGFloat) -> UIImage {
        guard size.width > 0, size.height > 0 else { return self }
        let currentMax = max(size.width, size.height)
        guard currentMax > maxDimension else { return self }

        let scale = maxDimension / currentMax
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        // Use a standard sRGB-style bitmap context (matches the working approach in lovablee).
        UIGraphicsBeginImageContextWithOptions(newSize, true, 1.0)
        UIColor.white.setFill()
        UIRectFill(CGRect(origin: .zero, size: newSize))
        draw(in: CGRect(origin: .zero, size: newSize))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resized ?? self
    }
}

private extension SupabaseService {
    func makeDoodleDataURL(from image: UIImage) throws -> String {
        let maxDimensions: [CGFloat] = [420, 360, 320, 280, 256]
        let qualities: [CGFloat] = [0.72, 0.62, 0.52]

        for maxDim in maxDimensions {
            let candidate = image.resizedToMaxDimension(maxDim)
            for quality in qualities {
                if let data = candidate.jpegData(compressionQuality: quality) {
                    let base64 = data.base64EncodedString()
                    let dataURL = "data:image/jpeg;base64,\(base64)"
                    if dataURL.count <= 450_000 {
                        return dataURL
                    }
                }
            }
        }

        throw SupabaseServiceError.invalidDoodle
    }
}
