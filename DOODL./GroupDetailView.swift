import SwiftUI

struct GroupDetailView: View {
    let language: AppLanguage
    let group: GroupSummary
    let profileId: String
    let pairingCode: String

    @Environment(\.dismiss) private var dismiss

    @State private var members: [GroupMemberProfile] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var pendingRefresh = false

    @State private var showingInvite = false
    @State private var pendingMemberAction: MemberAction?
    @State private var pendingGroupAction: GroupAction?

    private enum MemberAction: Identifiable {
        case remove(GroupMemberProfile)
        case block(GroupMemberProfile)
        case unblock(GroupMemberProfile)

        var id: String {
            switch self {
            case .remove(let m): "remove:\(m.id)"
            case .block(let m): "block:\(m.id)"
            case .unblock(let m): "unblock:\(m.id)"
            }
        }
    }

	private enum GroupAction: Identifiable {
		case leave

		var id: String {
			switch self {
			case .leave: "leave"
			}
		}
	}

    var body: some View {
        NavigationStack {
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

                        membersCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Haptics.tap()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(Color.primary.opacity(0.82))
                            .frame(width: 36, height: 36)
                            .background(.thinMaterial, in: Circle())
                            .overlay(Circle().stroke(Color.primary.opacity(0.10), lineWidth: 1))
                    }
                    .accessibilityLabel(closeTitle)
                    .buttonStyle(.plain)
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        Haptics.tap(.light)
                        Task {
                            let code = group.code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                            guard await ActionRateLimiter.shared.allow(
                                key: "groupDetail.refresh.\(code)",
                                cooldownSeconds: 1.5
                            ) else { return }
                            await refresh(force: true)
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(Color.primary.opacity(0.82))
                            .frame(width: 36, height: 36)
                            .background(.thinMaterial, in: Circle())
                            .overlay(Circle().stroke(Color.primary.opacity(0.10), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoading)

                    Button {
                        Haptics.tap(.medium)
                        showingInvite = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(.black.opacity(0.90), in: Circle())
                            .overlay(Circle().stroke(.white.opacity(0.14), lineWidth: 1))
                    }
                    .buttonStyle(.plain)

					Menu {
						Button(role: .destructive) {
							Haptics.tap(.light)
							pendingGroupAction = .leave
						} label: {
                            Label(leaveGroupTitle, systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(Color.primary.opacity(0.82))
                            .frame(width: 36, height: 36)
                            .background(.thinMaterial, in: Circle())
                            .overlay(Circle().stroke(Color.primary.opacity(0.10), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .confirmationDialog(
                "",
                isPresented: Binding(
                    get: { pendingMemberAction != nil },
                    set: { if !$0 { pendingMemberAction = nil } }
                ),
                titleVisibility: .visible
            ) {
                if let action = pendingMemberAction {
                    switch action {
                    case .remove(let member):
                        Button(removeMemberTitle(member), role: .destructive) {
                            Task { await removeMember(member) }
                        }
                    case .block(let member):
                        Button(blockMemberTitle(member), role: .destructive) {
                            Task { await blockMember(member) }
                        }
                    case .unblock(let member):
                        Button(unblockMemberTitle(member)) {
                            Task { await unblockMember(member) }
                        }
                    }
                }
                Button(cancelTitle, role: .cancel) {}
            } message: {
                if let action = pendingMemberAction {
                    switch action {
                    case .remove:
                        Text(removeMemberMessage)
                    case .block:
                        Text(blockMemberMessage)
                    case .unblock:
                        Text(unblockMemberMessage)
                    }
                }
            }
            .confirmationDialog(
                "",
                isPresented: Binding(
                    get: { pendingGroupAction != nil },
                    set: { if !$0 { pendingGroupAction = nil } }
                ),
                titleVisibility: .visible
            ) {
				if let action = pendingGroupAction {
					switch action {
					case .leave:
						Button(leaveGroupTitle, role: .destructive) {
							Task { await leaveGroup() }
						}
                    }
                }
                Button(cancelTitle, role: .cancel) {}
            } message: {
				if let action = pendingGroupAction {
					switch action {
					case .leave:
						Text(leaveGroupMessage)
					}
				}
			}
            .task {
                await refresh(force: false)
            }
            .sheet(isPresented: $showingInvite) {
                InviteUserSheet(
                    language: language,
                    excludeProfileId: profileId,
                    onInvite: { invitedUsername in
                        Task { await invite(invitedUsername) }
                    }
                )
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(groupDisplayName)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.primary.opacity(0.92))
                .lineLimit(2)

            Text(membersSubtitle)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.secondary.opacity(0.85))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.10), lineWidth: 1)
        )
    }

    private var membersCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(membersTitle)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.primary.opacity(0.92))
                Spacer()
                if isLoading {
                    ProgressView().tint(Color.primary.opacity(0.65))
                }
            }

            if members.isEmpty && !isLoading {
                Text(noMembersTitle)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.secondary.opacity(0.85))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
            } else {
                VStack(spacing: 10) {
                    ForEach(members) { member in
                        memberRow(member)
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

    private func memberRow(_ member: GroupMemberProfile) -> some View {
        HStack(spacing: 12) {
            AvatarCircle(url: member.avatarURL, fallbackText: initials(from: member.username))
                .frame(width: 44, height: 44)

			VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("@\(member.username)")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.primary.opacity(0.92))
                    if member.isPro {
                        CrownBadge(size: 13)
                    }
                }
				streakFlame(member.streakCount)
			}

            Spacer(minLength: 0)

            if member.isOnline {
                Circle()
                    .fill(.green.opacity(0.9))
                    .frame(width: 10, height: 10)
                    .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 4)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(Color.primary.opacity(0.02), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.10), lineWidth: 1)
        )
        .contextMenu {
            if canManageMembers, member.id != profileId {
                Button(role: .destructive) {
                    Haptics.tap(.light)
                    pendingMemberAction = .remove(member)
                } label: {
                    Label(removeShortTitle, systemImage: "person.fill.xmark")
                }
            }

            if member.id != profileId {
                Button(role: .destructive) {
                    Haptics.tap(.light)
                    pendingMemberAction = .block(member)
                } label: {
                    Label(blockShortTitle, systemImage: "hand.raised.fill")
                }

                Button {
                    Haptics.tap(.light)
                    pendingMemberAction = .unblock(member)
                } label: {
                    Label(unblockShortTitle, systemImage: "hand.raised.slash.fill")
                }
            }
        }
    }

    private var canManageMembers: Bool {
        guard let owner = group.ownerProfileId?.trimmingCharacters(in: .whitespacesAndNewlines),
              !owner.isEmpty
        else { return false }
        return owner == profileId
    }

    @MainActor
    private func removeMember(_ member: GroupMemberProfile) async {
        do {
            try await SupabaseService.shared.removeMember(
                pairingCode: group.code,
                requesterProfileId: profileId,
                requesterPairingCode: pairingCode,
                memberProfileId: member.id
            )
            members.removeAll { $0.id == member.id }
        } catch {
            errorMessage = UserFacingError.message(for: error, language: language)
        }
    }

    @MainActor
    private func blockMember(_ member: GroupMemberProfile) async {
        do {
            try await SupabaseService.shared.blockProfile(
                profileId: profileId,
                profilePairingCode: pairingCode,
                blockedProfileId: member.id
            )
        } catch {
            errorMessage = UserFacingError.message(for: error, language: language)
        }
    }

    @MainActor
    private func unblockMember(_ member: GroupMemberProfile) async {
        do {
            try await SupabaseService.shared.unblockProfile(
                profileId: profileId,
                profilePairingCode: pairingCode,
                blockedProfileId: member.id
            )
        } catch {
            errorMessage = UserFacingError.message(for: error, language: language)
        }
    }

	@MainActor
	private func leaveGroup() async {
		do {
			try await SupabaseService.shared.leaveGroup(pairingCode: group.code, profileId: profileId, profilePairingCode: pairingCode)
			dismiss()
        } catch {
            errorMessage = UserFacingError.message(for: error, language: language)
        }
    }

    private var cancelTitle: String {
        switch language {
        case .english: "cancel"
        case .dutch: "annuleren"
        case .german: "abbrechen"
        case .spanish: "cancelar"
        }
    }

	private var leaveGroupTitle: String {
		switch language {
		case .english: "leave group"
		case .dutch: "verlaat groep"
        case .german: "gruppe verlassen"
        case .spanish: "salir del grupo"
        }
    }

    private var leaveGroupMessage: String {
        switch language {
        case .english: "you can rejoin later with an invite."
        case .dutch: "je kunt later weer joinen met een invite."
        case .german: "du kannst später mit einer einladung wieder beitreten."
        case .spanish: "puedes volver a unirte con una invitación."
        }
    }

    private var removeShortTitle: String {
        switch language {
        case .english: "remove"
        case .dutch: "verwijderen"
        case .german: "entfernen"
        case .spanish: "eliminar"
        }
    }

    private var blockShortTitle: String {
        switch language {
        case .english: "block"
        case .dutch: "blokkeren"
        case .german: "blockieren"
        case .spanish: "bloquear"
        }
    }

    private var unblockShortTitle: String {
        switch language {
        case .english: "unblock"
        case .dutch: "deblokkeren"
        case .german: "entsperren"
        case .spanish: "desbloquear"
        }
    }

    private func removeMemberTitle(_ member: GroupMemberProfile) -> String { "\(removeShortTitle) @\(member.username)?" }
    private func blockMemberTitle(_ member: GroupMemberProfile) -> String { "\(blockShortTitle) @\(member.username)?" }
    private func unblockMemberTitle(_ member: GroupMemberProfile) -> String { "\(unblockShortTitle) @\(member.username)?" }

    private var removeMemberMessage: String {
        switch language {
        case .english: "they will be removed from this group."
        case .dutch: "ze worden uit deze groep verwijderd."
        case .german: "sie werden aus dieser gruppe entfernt."
        case .spanish: "se eliminarán de este grupo."
        }
    }

    private var blockMemberMessage: String {
        switch language {
        case .english: "you won’t see their doodls anymore."
        case .dutch: "je ziet hun doodls niet meer."
        case .german: "du siehst ihre doodls nicht mehr."
        case .spanish: "ya no verás sus doodls."
        }
    }

    private var unblockMemberMessage: String {
        switch language {
        case .english: "you will see their doodls again."
        case .dutch: "je ziet hun doodls weer."
        case .german: "du siehst ihre doodls wieder."
        case .spanish: "volverás a ver sus doodls."
        }
    }

    private var groupDisplayName: String {
        let cleaned = (group.displayName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleaned.isEmpty { return cleaned }
        switch language {
        case .english: return "group"
        case .dutch: return "groep"
        case .german: return "gruppe"
        case .spanish: return "grupo"
        }
    }

    private var membersSubtitle: String {
        let count = max(1, group.memberCount)
        switch language {
        case .english: return "\(count) members"
        case .dutch: return "\(count) leden"
        case .german: return "\(count) mitglieder"
        case .spanish: return "\(count) miembros"
        }
    }

    private var title: String {
        groupDisplayName
    }

    private var closeTitle: String {
        switch language {
        case .english: "close"
        case .dutch: "sluiten"
        case .german: "schließen"
        case .spanish: "cerrar"
        }
    }

    private var membersTitle: String {
        switch language {
        case .english: "members"
        case .dutch: "leden"
        case .german: "mitglieder"
        case .spanish: "miembros"
        }
    }

    private var noMembersTitle: String {
        switch language {
        case .english: "no members found."
        case .dutch: "geen leden gevonden."
        case .german: "keine mitglieder gefunden."
        case .spanish: "no se encontraron miembros."
        }
    }

    private func streakFlame(_ count: Int) -> some View {
        let value = max(0, count)
        let isActive = value > 0

        return HStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(Color(hex: "FF9F0A"), Color(hex: "FF3B30"))
                .opacity(isActive ? 1 : 0.35)
                .shadow(color: Color(hex: "FF9F0A").opacity(isActive ? 0.22 : 0.10), radius: 6, x: 0, y: 4)

            Text("\(value)")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(isActive ? Color.primary.opacity(0.82) : Color.secondary.opacity(0.65))
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color.primary.opacity(isActive ? 0.06 : 0.03), in: Capsule(style: .continuous))
        .overlay(Capsule(style: .continuous).stroke(Color.primary.opacity(0.10), lineWidth: 1))
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

    @MainActor
    private func refresh(force: Bool) async {
        if isLoading {
            pendingRefresh = pendingRefresh || force
            return
        }
        isLoading = true
        defer {
            isLoading = false
            if pendingRefresh {
                pendingRefresh = false
                Task { await refresh(force: true) }
            }
        }
        errorMessage = nil
        do {
            members = try await SupabaseService.shared.fetchGroupMembers(pairingCode: group.code, requesterProfileId: profileId)
        } catch {
            errorMessage = UserFacingError.message(for: error, language: language)
        }
    }

    @MainActor
    private func invite(_ invitedUsername: String) async {
        do {
            try await SupabaseService.shared.inviteToGroup(
                groupCode: group.code,
                inviterProfileId: profileId,
                invitedUsername: invitedUsername
            )
            showingInvite = false
            await refresh(force: true)
        } catch {
            errorMessage = UserFacingError.message(for: error, language: language)
        }
    }
}
