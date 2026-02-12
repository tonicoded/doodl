import SwiftUI

struct BlockedUsersView: View {
    let language: AppLanguage
    let profileId: String
    let pairingCode: String

    @Environment(\.dismiss) private var dismiss

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var blocked: [BlockedUser] = []
    @State private var busyIds: Set<String> = []

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    if let errorMessage, !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.primary.opacity(0.92))
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.red.opacity(0.16), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.primary.opacity(0.10), lineWidth: 1)
                            )
                    }

                    if isLoading {
                        ProgressView().tint(Color.primary.opacity(0.65))
                            .frame(maxWidth: .infinity)
                            .padding(.top, 18)
                    } else if blocked.isEmpty {
                        emptyState
                    } else {
                        VStack(spacing: 10) {
                            ForEach(blocked) { user in
                                row(user)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Haptics.tap(.light)
                    Task { await refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.primary.opacity(0.75))
                }
                .buttonStyle(.plain)
            }
        }
        .task {
            await refresh()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text(emptyTitle)
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.primary.opacity(0.92))
            Text(emptySubtitle)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.secondary.opacity(0.85))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
        .glassCard(cornerRadius: 20)
    }

    private func row(_ user: BlockedUser) -> some View {
        HStack(spacing: 12) {
            AvatarCircle(url: user.avatarURL, fallbackText: initials(user.username))
                .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 2) {
                Text("@\(user.username)")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.primary.opacity(0.92))
                    .lineLimit(1)

                if let createdAt = user.createdAt {
                    Text(timeAgo(createdAt))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.secondary.opacity(0.75))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            Button {
                Haptics.tap(.medium)
                Task { await unblock(user) }
            } label: {
                if busyIds.contains(user.id) {
                    ProgressView().tint(Color.primary.opacity(0.75))
                        .frame(width: 72, height: 34)
                } else {
                    Text(unblockTitle)
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.primary.opacity(0.90))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.primary.opacity(0.06), in: Capsule(style: .continuous))
                        .overlay(Capsule(style: .continuous).stroke(Color.primary.opacity(0.10), lineWidth: 1))
                }
            }
            .buttonStyle(.plain)
            .disabled(busyIds.contains(user.id))
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .glassCard(cornerRadius: 20)
    }

    @MainActor
    private func refresh() async {
        if isLoading { return }
        isLoading = true
        errorMessage = nil
        do {
            blocked = try await SupabaseService.shared.listBlockedUsers(profileId: profileId, profilePairingCode: pairingCode)
        } catch {
            errorMessage = UserFacingError.message(for: error, language: language)
        }
        isLoading = false
    }

    @MainActor
    private func unblock(_ user: BlockedUser) async {
        if busyIds.contains(user.id) { return }
        busyIds.insert(user.id)
        defer { busyIds.remove(user.id) }
        do {
            try await SupabaseService.shared.unblockProfile(profileId: profileId, profilePairingCode: pairingCode, blockedProfileId: user.id)
            blocked.removeAll { $0.id == user.id }
        } catch {
            errorMessage = UserFacingError.message(for: error, language: language)
        }
    }

    private func initials(_ username: String) -> String {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = trimmed.hasPrefix("@") ? String(trimmed.dropFirst()) : trimmed
        if cleaned.isEmpty { return "?" }
        let parts = cleaned
            .split(whereSeparator: { $0 == "." || $0 == "_" || $0 == "-" || $0 == " " })
            .map(String.init)
        if let first = parts.first, parts.count > 1, let second = parts.dropFirst().first {
            return "\(first.prefix(1))\(second.prefix(1))".uppercased()
        }
        return String(cleaned.prefix(2)).uppercased()
    }

    private func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.locale = Locale(identifier: language.rawValue)
        return formatter.localizedString(for: date, relativeTo: Date()).lowercased()
    }

    private var title: String {
        switch language {
        case .english: "blocked"
        case .dutch: "geblokkeerd"
        case .german: "blockiert"
        case .spanish: "bloqueados"
        }
    }

    private var emptyTitle: String {
        switch language {
        case .english: "no blocked users"
        case .dutch: "geen geblokkeerde users"
        case .german: "keine blockierten nutzer"
        case .spanish: "sin usuarios bloqueados"
        }
    }

    private var emptySubtitle: String {
        switch language {
        case .english: "people you block will show up here."
        case .dutch: "mensen die je blokkeert komen hier te staan."
        case .german: "personen, die du blockierst, erscheinen hier."
        case .spanish: "las personas que bloqueas aparecerán aquí."
        }
    }

    private var unblockTitle: String {
        switch language {
        case .english: "unblock"
        case .dutch: "deblok"
        case .german: "entblocken"
        case .spanish: "desbloquear"
        }
    }
}

