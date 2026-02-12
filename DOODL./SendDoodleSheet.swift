import SwiftUI
import UIKit

struct SendDoodleSheet: View {
    let language: AppLanguage
    let profileId: String
    let pairingCode: String
    let image: UIImage

    let onComplete: (Result<Void, Error>) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var friends: [FriendProfile] = []
    @State private var selectedFriendIds: Set<String> = []
    @State private var groups: [GroupSummary] = []
    @State private var selectedGroupCodes: Set<String> = []
    @State private var isLoading = false
    @State private var isSending = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        previewCard

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

                        recipientsCard

                        sendButton
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(cancelTitle) {
                        Haptics.tap(.light)
                        onComplete(.failure(CancellationError()))
                        dismiss()
                    }
                    .foregroundStyle(Color.primary.opacity(0.82))
                }
            }
            .task {
                await loadRecipients()
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(previewTitle)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.primary.opacity(0.92))

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.primary.opacity(0.10), lineWidth: 1)
                )
        }
        .padding(14)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.10), lineWidth: 1)
        )
    }

    private var recipientsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(recipientsTitle)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.primary.opacity(0.92))

            groupsSection

            if isLoading {
                ProgressView().tint(Color.primary.opacity(0.65))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 10)
            } else if friends.isEmpty {
                Text(noFriendsTitle)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.secondary.opacity(0.85))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
            } else {
                VStack(spacing: 8) {
                    ForEach(friends) { friend in
                        friendRow(friend)
                    }
                }
            }
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.10), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var groupsSection: some View {
        if !groups.isEmpty {
            VStack(spacing: 8) {
                ForEach(groups) { group in
                    let code = group.code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    if !code.isEmpty {
                        recipientToggleRow(
                            title: groupDisplayName(group),
                            subtitle: groupMembersSubtitle(group.memberCount),
                            isSelected: selectedGroupCodes.contains(code)
                        ) {
                            toggleGroupCode(code)
                        }
                    }
                }
            }
            .padding(.bottom, 6)
        }
    }

    private func friendRow(_ friend: FriendProfile) -> some View {
        let isSelected = selectedFriendIds.contains(friend.id)
        return Button {
            Haptics.selectionChanged()
            if isSelected {
                selectedFriendIds.remove(friend.id)
            } else {
                selectedFriendIds.insert(friend.id)
            }
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.primary.opacity(0.06))
                    .frame(width: 42, height: 42)
                    .overlay(
                        Text(initials(from: friend.username))
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color.primary.opacity(0.82))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("@\(friend.username)")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.primary.opacity(0.92))
                    Text(friendSubtitle)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.secondary.opacity(0.85))
                }

                Spacer(minLength: 0)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(isSelected ? Color.primary.opacity(0.88) : Color.secondary.opacity(0.35))
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(Color.primary.opacity(isSelected ? 0.06 : 0.02), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.primary.opacity(0.10), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func recipientToggleRow(title: String, subtitle: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.primary.opacity(0.06))
                    .frame(width: 42, height: 42)
                    .overlay(
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundStyle(Color.primary.opacity(0.70))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.primary.opacity(0.92))
                    Text(subtitle)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.secondary.opacity(0.85))
                }

                Spacer(minLength: 0)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(isSelected ? Color.primary.opacity(0.88) : Color.secondary.opacity(0.35))
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(Color.primary.opacity(isSelected ? 0.06 : 0.02), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.primary.opacity(0.10), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var sendButton: some View {
        Button {
            Haptics.tap(.medium)
            Task { await send() }
        } label: {
            HStack(spacing: 10) {
                if isSending {
                    ProgressView().tint(.white.opacity(0.96))
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 15, weight: .heavy))
                }
                Text(sendTitle)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(.white.opacity(0.96))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(.black.opacity(0.90), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.14), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isSending || !hasAnyRecipient)
        .opacity(isSending || !hasAnyRecipient ? 0.75 : 1)
    }

    private var hasAnyRecipient: Bool {
        !selectedGroupCodes.isEmpty || !selectedFriendIds.isEmpty
    }

    @MainActor
    private func loadRecipients() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            async let f = SupabaseService.shared.listFriends(profileId: profileId, profilePairingCode: pairingCode)
            async let g = SupabaseService.shared.listGroupsV2(profileId: profileId, profilePairingCode: pairingCode, limit: 50)
            let (friendsValue, groupsValue) = try await (f, g)
            friends = friendsValue
            groups = groupsValue
        } catch {
            friends = []
            groups = []
        }
        isLoading = false
    }

    @MainActor
    private func send() async {
        if isSending { return }
        errorMessage = nil

        guard hasAnyRecipient else {
            errorMessage = pickSomeoneError
            return
        }

        isSending = true
        do {
            for code in selectedGroupCodes {
                _ = try await SupabaseService.shared.sendDoodle(
                    image: image,
                    groupCode: code,
                    senderProfileId: profileId,
                    senderPairingCode: pairingCode
                )
            }

            for friendId in selectedFriendIds {
                let chat = try await SupabaseService.shared.ensureDirectChat(
                    profileId: profileId,
                    profilePairingCode: pairingCode,
                    friendProfileId: friendId
                )
                _ = try await SupabaseService.shared.sendDoodle(
                    image: image,
                    groupCode: chat.code,
                    senderProfileId: profileId,
                    senderPairingCode: pairingCode
                )
            }

            onComplete(.success(()))
            dismiss()
        } catch {
            errorMessage = UserFacingError.message(for: error, language: language)
        }
        isSending = false
    }

    private func toggleGroupCode(_ code: String) {
        Haptics.selectionChanged()
        if selectedGroupCodes.contains(code) {
            selectedGroupCodes.remove(code)
        } else {
            selectedGroupCodes.insert(code)
        }
    }

    private func groupDisplayName(_ group: GroupSummary) -> String {
        let cleaned = (group.displayName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleaned.isEmpty { return cleaned }
        switch language {
        case .english: return "group"
        case .dutch: return "groep"
        case .german: return "gruppe"
        case .spanish: return "grupo"
        }
    }

    private func groupMembersSubtitle(_ count: Int) -> String {
        let value = max(1, count)
        switch language {
        case .english: return "\(value) members"
        case .dutch: return "\(value) leden"
        case .german: return "\(value) mitglieder"
        case .spanish: return "\(value) miembros"
        }
    }

    private func initials(from username: String) -> String {
        let cleaned = username
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "@", with: "")
        if cleaned.isEmpty { return "?" }
        let parts = cleaned
            .split(whereSeparator: { $0 == "." || $0 == "_" || $0 == "-" || $0 == " " })
            .map(String.init)
        if let first = parts.first, parts.count > 1, let second = parts.dropFirst().first {
            let a = first.prefix(1)
            let b = second.prefix(1)
            return "\(a)\(b)".uppercased()
        }
        return String(cleaned.prefix(2)).uppercased()
    }

    private var title: String {
        switch language {
        case .english: "send doodl."
        case .dutch: "stuur doodl."
        case .german: "doodl senden"
        case .spanish: "enviar doodl."
        }
    }

    private var cancelTitle: String {
        switch language {
        case .english: "cancel"
        case .dutch: "annuleer"
        case .german: "abbrechen"
        case .spanish: "cancelar"
        }
    }

    private var previewTitle: String {
        switch language {
        case .english: "preview"
        case .dutch: "voorbeeld"
        case .german: "vorschau"
        case .spanish: "vista previa"
        }
    }

    private var recipientsTitle: String {
        switch language {
        case .english: "send to"
        case .dutch: "verstuur naar"
        case .german: "senden an"
        case .spanish: "enviar a"
        }
    }

    private var noFriendsTitle: String {
        switch language {
        case .english: "no friends yet — add one from your inbox."
        case .dutch: "nog geen vrienden — voeg iemand toe in je inbox."
        case .german: "noch keine freunde — füge jemanden im inbox hinzu."
        case .spanish: "sin amigos aún — añade a alguien en tu bandeja."
        }
    }

    private var friendSubtitle: String {
        switch language {
        case .english: "tap to select"
        case .dutch: "tik om te selecteren"
        case .german: "tippen zum auswählen"
        case .spanish: "toca para seleccionar"
        }
    }

    private var pickSomeoneError: String {
        switch language {
        case .english: "pick at least one recipient."
        case .dutch: "kies minstens 1 ontvanger."
        case .german: "wähle mindestens 1 empfänger."
        case .spanish: "elige al menos 1 destinatario."
        }
    }

    private var sendTitle: String {
        switch language {
        case .english: "send"
        case .dutch: "stuur"
        case .german: "senden"
        case .spanish: "enviar"
        }
    }
}
