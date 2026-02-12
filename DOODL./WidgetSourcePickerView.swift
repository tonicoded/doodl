import SwiftUI
import WidgetKit

struct WidgetSourcePickerView: View {
    let language: AppLanguage
    let profileId: String
    let pairingCode: String
    let username: String

    @Environment(\.dismiss) private var dismiss

    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var friends: [FriendProfile] = []
    @State private var groups: [GroupSummary] = []

    @State private var directChatCodesByFriendId: [String: String] = [:]
    @State private var selectedGroupCode: String = SharedWidgetStore.effectiveWidgetSourceCode()
    @State private var isSeedingAllSources = false

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    headerCard

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

                    sourceSection
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
                Button(doneTitle) {
                    Haptics.tap()
                    dismiss()
                }
                .foregroundStyle(Color.primary.opacity(0.82))
            }
        }
        .task {
            await refresh()
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(subtitleTitle)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.primary.opacity(0.92))
            Text(subtitleBody)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.secondary.opacity(0.85))
        }
        .padding(14)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.10), lineWidth: 1)
        )
    }

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isLoading {
                ProgressView().tint(Color.primary.opacity(0.65))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 10)
            } else {
                sourceRow(
                    title: allSourcesTitle,
                    subtitle: allSourcesSubtitle,
                    isSelected: SharedWidgetStore.isAllSources(selectedGroupCode)
                ) {
                    Task { await selectAllSources() }
                }

                if !friends.isEmpty {
                    Text(friendsTitle)
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.secondary.opacity(0.85))
                        .padding(.top, 2)

                    VStack(spacing: 10) {
                        ForEach(friends) { friend in
                            let code = directChatCodesByFriendId[friend.id]
                            sourceRow(
                                title: "@\(friend.username)",
                                subtitle: friendSubtitle,
                                isSelected: !SharedWidgetStore.isAllSources(selectedGroupCode) && code != nil && code == selectedGroupCode
                            ) {
                                Task { await selectFriend(friend) }
                            }
                        }
                    }
                }

                if !groups.isEmpty {
                    Text(groupsTitle)
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.secondary.opacity(0.85))
                        .padding(.top, friends.isEmpty ? 2 : 10)

                    VStack(spacing: 10) {
                        ForEach(groups) { group in
                            sourceRow(
                                title: groupDisplayName(group),
                                subtitle: groupSubtitle(group),
                                isSelected: !SharedWidgetStore.isAllSources(selectedGroupCode) && group.code == selectedGroupCode
                            ) {
                                setWidgetSource(groupCode: group.code)
                            }
                        }
                    }
                }

                if friends.isEmpty && groups.isEmpty {
                    Text(emptyTitle)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.secondary.opacity(0.85))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 10)
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

    private func sourceRow(title: String, subtitle: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.primary.opacity(0.06))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "rectangle.grid.2x2.fill")
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundStyle(Color.primary.opacity(0.70))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.primary.opacity(0.92))
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.secondary.opacity(0.85))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(isSelected ? Color.primary.opacity(0.88) : Color.secondary.opacity(0.35))
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(Color.primary.opacity(isSelected ? 0.06 : 0.02), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.primary.opacity(0.10), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    @MainActor
    private func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            async let f = SupabaseService.shared.listFriends(profileId: profileId, profilePairingCode: pairingCode)
            async let g = SupabaseService.shared.listGroupsV2(profileId: profileId, profilePairingCode: pairingCode, limit: 50)
            async let dc = SupabaseService.shared.listDirectChats(profileId: profileId, profilePairingCode: pairingCode, limit: 50)

            let (friendsValue, groupsValue, directChats) = try await (f, g, dc)
            friends = friendsValue
            groups = groupsValue
            directChatCodesByFriendId = Dictionary(
                uniqueKeysWithValues: directChats.map { ($0.otherProfileId, $0.code) }
            )
        } catch {
            errorMessage = UserFacingError.message(for: error, language: language)
        }
        isLoading = false
    }

    @MainActor
    private func selectAllSources() async {
        setWidgetSource(groupCode: SharedWidgetStore.allSourcesCode)
        await seedAllSourcesWidgetSnapshot()
    }

    @MainActor
    private func seedAllSourcesWidgetSnapshot() async {
        guard !isSeedingAllSources else { return }
        isSeedingAllSources = true
        defer { isSeedingAllSources = false }

        // Best-effort: pick the newest doodl across known chats + groups so the widget isn't empty.
        // After that, ongoing updates are push-driven.
        var codes: [String] = []
        codes.append(contentsOf: directChatCodesByFriendId.values)
        codes.append(contentsOf: groups.map(\.code))
        // Include the user's own group code as a last-resort source (hidden from UI).
        codes.append(pairingCode)
        codes = Array(
            Set(
                codes
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                    .filter { !$0.isEmpty }
            )
        )
        // Safety cap for settings screen.
        if codes.count > 30 {
            codes = Array(codes.prefix(30))
        }

        SharedWidgetStore.saveWidgetSources(codes)

        var bestCode: String?
        var bestMeta: InboxDoodle?

        await withTaskGroup(of: (String, InboxDoodle?).self) { group in
            for code in codes {
                group.addTask {
                    do {
                        let metas = try await SupabaseService.shared.fetchInboxDoodleMetas(
                            groupCode: code,
                            requesterProfileId: profileId,
                            limit: 1
                        )
                        let candidate = metas.first(where: { $0.senderUsername.lowercased() != username.lowercased() })
                        return (code, candidate)
                    } catch {
                        return (code, nil)
                    }
                }
            }

            for await (code, meta) in group {
                guard let meta else { continue }
                let created = meta.createdAt ?? .distantPast
                let current = bestMeta?.createdAt ?? .distantPast
                if created > current {
                    bestMeta = meta
                    bestCode = code
                }
            }
        }

        guard let bestCode, let bestMeta else { return }
        do {
            let fetched = try await SupabaseService.shared.fetchDoodleContents(
                groupCode: bestCode,
                requesterProfileId: profileId,
                doodleIds: [bestMeta.id]
            )
            guard let content = fetched[bestMeta.id] else { return }

            SharedWidgetStore.saveLatestDoodle(
                SharedWidgetDoodle(
                    doodleId: bestMeta.id,
                    senderUsername: bestMeta.senderUsername,
                    contentBase64: content,
                    createdAt: bestMeta.createdAt ?? Date()
                )
            )
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            // no-op
        }
    }

    @MainActor
    private func selectFriend(_ friend: FriendProfile) async {
        do {
            let chat = try await SupabaseService.shared.ensureDirectChat(
                profileId: profileId,
                profilePairingCode: pairingCode,
                friendProfileId: friend.id
            )
            directChatCodesByFriendId[friend.id] = chat.code
            setWidgetSource(groupCode: chat.code)
        } catch {
            errorMessage = UserFacingError.message(for: error, language: language)
        }
    }

    private func setWidgetSource(groupCode: String) {
        let normalized = groupCode.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return }
        Haptics.selectionChanged()
        selectedGroupCode = normalized
        SharedWidgetStore.saveWidgetConfig(groupCode: normalized, profileId: profileId, username: username)
        WidgetCenter.shared.reloadAllTimelines()
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

    private func groupSubtitle(_ group: GroupSummary) -> String {
        let count = max(1, group.memberCount)
        switch language {
        case .english: return "\(count) members"
        case .dutch: return "\(count) leden"
        case .german: return "\(count) mitglieder"
        case .spanish: return "\(count) miembros"
        }
    }

    private var title: String {
        switch language {
        case .english: "widget"
        case .dutch: "widget"
        case .german: "widget"
        case .spanish: "widget"
        }
    }

    private var doneTitle: String {
        switch language {
        case .english: "done"
        case .dutch: "klaar"
        case .german: "fertig"
        case .spanish: "listo"
        }
    }

    private var subtitleTitle: String {
        switch language {
        case .english: "choose what shows up"
        case .dutch: "kies wat je ziet"
        case .german: "wähle, was angezeigt wird"
        case .spanish: "elige qué aparece"
        }
    }

    private var subtitleBody: String {
        switch language {
        case .english: "default is all chats + groups. pick one only if you want to lock the widget to a single chat."
        case .dutch: "standaard staan alle chats + groepen aan. kies er 1 als je de widget wil vastzetten op één chat."
        case .german: "standard ist alle chats + gruppen. wähle nur 1, wenn du das widget auf einen chat festsetzen willst."
        case .spanish: "por defecto son todos los chats + grupos. elige 1 solo si quieres fijar el widget a un chat."
        }
    }

    private var allSourcesTitle: String {
        switch language {
        case .english: "all chats + groups"
        case .dutch: "alle chats + groepen"
        case .german: "alle chats + gruppen"
        case .spanish: "todos los chats + grupos"
        }
    }

    private var allSourcesSubtitle: String {
        switch language {
        case .english: "recommended • latest doodl you receive"
        case .dutch: "aanrader • nieuwste doodl die je ontvangt"
        case .german: "empfohlen • neuestes doodl das du erhältst"
        case .spanish: "recomendado • último doodl que recibes"
        }
    }

    private var friendsTitle: String {
        switch language {
        case .english: "friends"
        case .dutch: "vrienden"
        case .german: "freunde"
        case .spanish: "amigos"
        }
    }

    private var groupsTitle: String {
        switch language {
        case .english: "groups"
        case .dutch: "groepen"
        case .german: "gruppen"
        case .spanish: "grupos"
        }
    }

    private var friendSubtitle: String {
        switch language {
        case .english: "show this chat"
        case .dutch: "toon deze chat"
        case .german: "diesen chat anzeigen"
        case .spanish: "mostrar este chat"
        }
    }

    private var emptyTitle: String {
        switch language {
        case .english: "no friends or groups yet."
        case .dutch: "nog geen vrienden of groepen."
        case .german: "noch keine freunde oder gruppen."
        case .spanish: "aún no hay amigos ni grupos."
        }
    }
}
