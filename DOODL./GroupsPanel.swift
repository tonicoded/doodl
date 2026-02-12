import SwiftUI

struct GroupsPanel: View {
    let language: AppLanguage
    let profileId: String
    let pairingCode: String
    let username: String
    let refreshToken: UUID
    let searchQuery: String
    @Binding var badgeCount: Int

    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Environment(\.colorScheme) private var colorScheme

    @State private var groups: [GroupSummary] = []
    @State private var invites: [GroupInvite] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var pendingRefresh = false

    @State private var showingCreateGroup = false
    @State private var newGroupName: String = ""
    @State private var isCreating = false

    @State private var selectedGroup: GroupSummary?
    @State private var composeGroup: GroupSummary?
    @State private var replyGroup: GroupSummary?
    @State private var activeSnapSequence: SnapSequence?
    @State private var isOpeningSnap = false
    @State private var unreadGroupCodes: Set<String> = []
    @State private var latestGroupDoodleAt: [String: Date] = [:]
    @State private var toast: String?
    @State private var pendingGroupAction: GroupAction?

    private let maxFreeGroups = 1

    private var panelFill: Color {
        colorScheme == .dark ? Color.black.opacity(0.26) : Color(.systemBackground)
    }

    private var panelStroke: Color {
        colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.08)
    }

    private var panelShadowColor: Color {
        colorScheme == .dark ? .black.opacity(0.16) : .black.opacity(0.00)
    }

    private var canAddAnotherGroup: Bool {
        purchaseManager.isPro || groups.count < maxFreeGroups
    }

    private var filteredGroups: [GroupSummary] {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return groups }
        return groups.filter { group in
            groupDisplayName(group).lowercased().contains(q)
        }
    }

    private struct SnapSequence: Identifiable {
        let id = UUID()
        let snaps: [SnapDoodleViewer.Snap]
        let onFinished: (_ seenAt: Date, _ finishedAll: Bool) -> Void
        let onReply: (() -> Void)?
    }

	private enum GroupAction: Identifiable {
		case leave(GroupSummary)

		var id: String {
			switch self {
			case .leave(let g): "leave:\(g.code)"
			}
		}
	}

    var body: some View {
        VStack(spacing: 12) {
            if let errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.primary.opacity(0.92))
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.primary.opacity(0.10), lineWidth: 1)
                    )
            }

            if isLoading {
                ProgressView().tint(Color.primary.opacity(0.65))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)
            } else {
                if !pendingInvites.isEmpty {
                    invitesCard
                }
                groupsCard
            }
        }
        .onAppear { Task { await refresh(force: false) } }
        .onChange(of: refreshToken) { _, _ in Task { await refresh(force: true) } }
        .sheet(isPresented: $showingCreateGroup) {
            createGroupSheet
        }
        .sheet(item: $selectedGroup) { group in
            GroupDetailView(
                language: language,
                group: group,
                profileId: profileId,
                pairingCode: pairingCode
            )
        }
        .fullScreenCover(item: $activeSnapSequence) { sequence in
            SnapDoodleSequenceViewer(
                snaps: sequence.snaps,
                language: language,
                autoAdvanceSeconds: 10,
                onReply: sequence.onReply,
                onFinished: sequence.onFinished
            )
        }
        .fullScreenCover(item: $composeGroup) { group in
            GroupReplyComposerView(
                language: language,
                group: group,
                profileId: profileId,
                pairingCode: pairingCode,
                onSent: {
                    Task { await refresh(force: true) }
                }
            )
            .environmentObject(purchaseManager)
        }
        .overlay(alignment: .bottom) {
            if let toast, !toast.isEmpty {
                Text(toast)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(.black.opacity(0.9), in: Capsule(style: .continuous))
                    .padding(.bottom, 14)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
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
				case .leave(let group):
					Button(leaveShortTitle, role: .destructive) {
						Task { await leaveGroup(group) }
					}
				}
			}
			Button(cancelTitle, role: .cancel) {}
		} message: {
			if let action = pendingGroupAction {
				switch action {
				case .leave:
					Text(leaveMessage)
				}
			}
		}
	}

    private var pendingInvites: [GroupInvite] {
        invites.filter { ($0.status.lowercased() == "pending") }
    }

    private func syncTabBadgeCount() {
        badgeCount = max(0, unreadGroupCodes.count + pendingInvites.count)
    }

    private var invitesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(invitesTitle)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.primary.opacity(0.92))

            VStack(spacing: 10) {
                ForEach(pendingInvites) { invite in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(inviteGroupTitle(invite.groupCode))
                                .font(.system(size: 15, weight: .heavy, design: .rounded))
                                .foregroundStyle(Color.primary.opacity(0.92))
                            Text(inviteFromTitle(invite.inviterUsername))
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.secondary.opacity(0.85))
                        }

                        Spacer(minLength: 0)

                        Button {
                            Haptics.tap(.light)
                            Task { await respondInvite(invite, accept: false) }
	                        } label: {
	                            Image(systemName: "xmark")
	                                .font(.system(size: 14, weight: .heavy))
	                                .foregroundStyle(Color.primary.opacity(0.72))
	                                .frame(width: 34, height: 34)
	                                .background(panelFill, in: Circle())
	                                .overlay(Circle().stroke(panelStroke, lineWidth: 1))
	                                .shadow(color: panelShadowColor, radius: 10, x: 0, y: 8)
	                        }
	                        .buttonStyle(PremiumPlainButtonStyle(scale: 0.94, pressedOpacity: 0.93))

                        Button {
                            Haptics.tap(.medium)
                            Task { await respondInvite(invite, accept: true) }
	                        } label: {
	                            Image(systemName: "checkmark")
	                                .font(.system(size: 14, weight: .heavy))
	                                .foregroundStyle(.white)
	                                .frame(width: 34, height: 34)
	                                .background(.black.opacity(0.90), in: Circle())
	                                .overlay(Circle().stroke(.white.opacity(0.14), lineWidth: 1))
	                                .shadow(color: .black.opacity(0.16), radius: 10, x: 0, y: 8)
	                        }
	                        .buttonStyle(PremiumPlainButtonStyle(scale: 0.94, pressedOpacity: 0.93))
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(Color.primary.opacity(0.02), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.primary.opacity(0.10), lineWidth: 1)
                    )
                }
            }
        }
        .padding(14)
        .background(panelFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(panelStroke, lineWidth: 1))
        .shadow(color: panelShadowColor, radius: 14, x: 0, y: 10)
    }

    private var groupsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(groupsTitle)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.primary.opacity(0.92))
                Spacer()
                Button {
                    Haptics.tap(.medium)
                    newGroupName = ""
                    guard canAddAnotherGroup else {
                        showToast(proRequiredForGroupsTitle)
                        NotificationCenter.default.post(name: .doodlShowPro, object: nil)
                        return
                    }
                    showingCreateGroup = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(.black.opacity(0.90), in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.14), lineWidth: 1))
                        .shadow(color: .black.opacity(0.16), radius: 10, x: 0, y: 8)
                }
                .buttonStyle(.plain)
            }

            if filteredGroups.isEmpty {
                Text(noGroupsTitle)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.secondary.opacity(0.85))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
            } else {
                LazyVStack(spacing: 0) {
                    let items = filteredGroups
                    ForEach(items.indices, id: \.self) { idx in
                        let group = items[idx]
                        groupRow(group)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)

                        if idx != items.count - 1 {
                            Divider()
                                .opacity(0.65)
                                .padding(.leading, 74)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(panelFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(panelStroke, lineWidth: 1))
        .shadow(color: panelShadowColor, radius: 14, x: 0, y: 10)
    }

    private func groupRow(_ group: GroupSummary) -> some View {
        let unreadAccent = Color(hex: colorScheme == .dark ? "0A84FF" : "007AFF")
        let code = group.code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let time = latestGroupDoodleAt[code].map(timeAgo)
        let subtitle: String = unreadGroupCodes.contains(code) ? newDoodleSubtitle : membersSubtitle(group.memberCount)

        return HStack(spacing: 12) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.primary.opacity(0.06))
                    .frame(width: 52, height: 52)
                    .overlay(
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundStyle(Color.primary.opacity(0.70))
                    )
                    .overlay(
                        Circle()
                            .stroke(unreadGroupCodes.contains(code) ? unreadAccent.opacity(0.95) : .clear, lineWidth: 2)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(groupDisplayName(group))
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.primary.opacity(0.92))
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(unreadGroupCodes.contains(code) ? unreadAccent.opacity(0.92) : Color.secondary.opacity(0.85))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 6) {
                    if let time, !time.isEmpty {
                        HStack(spacing: 6) {
                            if unreadGroupCodes.contains(code) {
                                Circle()
                                    .fill(unreadAccent)
                                    .frame(width: 7, height: 7)
                            }
                            Text(time)
                                .font(.system(size: 12, weight: .heavy, design: .rounded))
                                .foregroundStyle(Color.secondary.opacity(0.70))
                        }
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                Haptics.tap(.light)
                Task { await openLatestGroupSnap(group) }
            }

            HStack(spacing: 8) {
                Button {
                    Haptics.tap(.medium)
                    composeGroup = group
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(.black.opacity(0.90))
                        .frame(width: 38, height: 38)
                        .background(Color(hex: "FFFC00").opacity(0.96), in: Circle())
                        .overlay(Circle().stroke(Color.primary.opacity(0.12), lineWidth: 1))
                        .shadow(color: .black.opacity(0.10), radius: 10, x: 0, y: 6)
                }
                .buttonStyle(.plain)

                Button {
                    Haptics.tap(.light)
                    selectedGroup = group
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(Color.primary.opacity(0.82))
                        .frame(width: 38, height: 38)
                        .background(Color.primary.opacity(0.06), in: Circle())
                        .overlay(Circle().stroke(Color.primary.opacity(0.10), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
			.contextMenu {
				Button {
					Haptics.tap(.light)
					selectedGroup = group
            } label: {
                Label(membersTitle, systemImage: "person.2.fill")
            }

			Button(role: .destructive) {
				Haptics.tap(.light)
				pendingGroupAction = .leave(group)
			} label: {
                Label(leaveShortTitle, systemImage: "rectangle.portrait.and.arrow.right")
            }
        }
    }

    @MainActor
    private func openLatestGroupSnap(_ group: GroupSummary) async {
        if isOpeningSnap { return }
        isOpeningSnap = true
        defer { isOpeningSnap = false }

        do {
            let code = group.code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let lastSeen = InboxSeenStore.lastSeenAt(groupCode: code)

            // Keep aligned with server-side retention cap.
            let metas = try await SupabaseService.shared.fetchInboxDoodleMetas(
                groupCode: code,
                requesterProfileId: profileId,
                limit: 18
            )

            let unseen = metas
                .filter { $0.senderProfileId != profileId }
                .filter { ($0.createdAt ?? .distantPast) > lastSeen }
                .sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }

            guard !unseen.isEmpty else {
                composeGroup = group
                return
            }

            let ids = unseen.map(\.id)
            let contents = try await SupabaseService.shared.fetchDoodleContents(
                groupCode: code,
                requesterProfileId: profileId,
                doodleIds: ids
            )

            let snaps: [SnapDoodleViewer.Snap] = unseen.compactMap { doodle in
                guard let content = contents[doodle.id], let image = decode(content) else { return nil }
                return SnapDoodleViewer.Snap(
                    id: doodle.id,
                    senderUsername: doodle.senderUsername,
                    senderIsPro: doodle.senderIsPro,
                    image: image,
                    createdAt: doodle.createdAt
                )
            }

            guard !snaps.isEmpty else {
                composeGroup = group
                return
            }

            let newestSeenAt = snaps.compactMap(\.createdAt).max() ?? Date()
            activeSnapSequence = SnapSequence(
                snaps: snaps,
                onFinished: { [code] seenAt, finishedAll in
                    let clamped = min(seenAt, newestSeenAt)
                    InboxSeenStore.markSeen(groupCode: code, at: clamped)
                    Task { @MainActor in
                        if finishedAll {
                            unreadGroupCodes.remove(code)
                        }
                    }
                },
                onReply: {
                    composeGroup = group
                }
            )
        } catch {
            if let message = UserFacingError.message(for: error, language: language) {
                showToast(message)
            }
        }
    }

    private func decode(_ content: String) -> UIImage? {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let base64: String
        if let commaIndex = trimmed.firstIndex(of: ",") {
            base64 = String(trimmed[trimmed.index(after: commaIndex)...])
        } else {
            base64 = trimmed
        }
        guard let data = Data(base64Encoded: base64, options: [.ignoreUnknownCharacters]) else { return nil }
        return UIImage(data: data)?.withRenderingMode(.alwaysOriginal)
    }

    private var createGroupSheet: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                VStack(spacing: 14) {
	                    VStack(alignment: .leading, spacing: 8) {
	                        Text(createTitle)
	                            .font(.system(size: 20, weight: .heavy, design: .rounded))
	                            .foregroundStyle(Color.primary.opacity(0.92))
	                        Text(createSubtitle)
	                            .font(.system(size: 13, weight: .semibold, design: .rounded))
	                            .foregroundStyle(Color.secondary.opacity(0.85))
	                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

	                    TextField("", text: $newGroupName, prompt: Text(groupNamePlaceholder).foregroundStyle(Color.secondary.opacity(0.7)))
	                        .textInputAutocapitalization(.words)
	                        .autocorrectionDisabled(false)
		                        .font(.system(size: 15, weight: .heavy, design: .rounded))
		                        .foregroundStyle(Color.primary.opacity(0.92))
		                        .padding(.vertical, 12)
		                        .padding(.horizontal, 12)
		                        .background(panelFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
		                        .overlay(
		                            RoundedRectangle(cornerRadius: 14, style: .continuous)
		                                .stroke(panelStroke, lineWidth: 1)
		                        )

                    Button {
                        Haptics.tap(.medium)
                        Task { await createGroup() }
                    } label: {
                        HStack(spacing: 10) {
                            if isCreating {
                                ProgressView().tint(.white.opacity(0.96))
                            } else {
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .heavy))
                            }
                            Text(createButtonTitle)
                                .font(.system(size: 16, weight: .heavy, design: .rounded))
                        }
                        .foregroundStyle(.white.opacity(0.96))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.black.opacity(0.90), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isCreating || newGroupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(isCreating || newGroupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.7 : 1)

                    Spacer(minLength: 0)
                }
                .padding(16)
            }
            .navigationTitle(createNavTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
	                ToolbarItem(placement: .cancellationAction) {
	                    Button(cancelTitle) {
	                        Haptics.tap(.light)
	                        showingCreateGroup = false
	                    }
	                    .foregroundStyle(Color.primary.opacity(0.82))
	                }
	            }
        }
        .presentationDetents([.large])
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
            async let g = SupabaseService.shared.listGroupsV2(profileId: profileId, profilePairingCode: pairingCode, limit: 50)
            async let i = SupabaseService.shared.listInvites(profileId: profileId)
            let (groups, invites) = try await (g, i)
            self.groups = groups
            self.invites = invites

            // Keep a best-effort list of widget sources for "all sources" mode.
            let existing = SharedWidgetStore.loadWidgetSources()
            let codes = groups.map(\.code) + [pairingCode]
            SharedWidgetStore.saveWidgetSources(existing + codes)

            await refreshGroupBadges(for: groups)
            syncTabBadgeCount()
        } catch {
            errorMessage = UserFacingError.message(for: error, language: language)
        }
    }

    @MainActor
    private func refreshGroupBadges(for groups: [GroupSummary]) async {
        let codes = Array(
            Set(
                groups
                    .map { $0.code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                    .filter { !$0.isEmpty }
            )
        )
        if codes.isEmpty {
            unreadGroupCodes = []
            latestGroupDoodleAt = [:]
            syncTabBadgeCount()
            return
        }

        var latest: [String: Date] = latestGroupDoodleAt
        var unread = unreadGroupCodes

        let chunkSize = 6
        var i = 0
        while i < codes.count {
            let end = min(codes.count, i + chunkSize)
            let slice = Array(codes[i..<end])

            await withTaskGroup(of: (String, Date?).self) { group in
                for code in slice {
                    group.addTask {
                        do {
                            let metas = try await SupabaseService.shared.fetchInboxDoodleMetas(
                                groupCode: code,
                                requesterProfileId: profileId,
                                limit: 1
                            )
                            return (code, metas.first?.createdAt)
                        } catch {
                            return (code, nil)
                        }
                    }
                }

                for await (code, createdAt) in group {
                    guard let createdAt else {
                        latest.removeValue(forKey: code)
                        unread.remove(code)
                        continue
                    }

                    latest[code] = createdAt
                    let lastSeen = InboxSeenStore.lastSeenAt(groupCode: code)
                    if createdAt > lastSeen {
                        unread.insert(code)
                    } else {
                        unread.remove(code)
                    }
                }
            }

            i = end
        }

        latestGroupDoodleAt = latest
        unreadGroupCodes = unread
        syncTabBadgeCount()
    }

    @MainActor
    private func createGroup() async {
        if isCreating { return }
        guard canAddAnotherGroup else {
            showToast(proRequiredForGroupsTitle)
            NotificationCenter.default.post(name: .doodlShowPro, object: nil)
            return
        }
        isCreating = true
        errorMessage = nil
        do {
            let group = try await SupabaseService.shared.createGroupV2(
                profileId: profileId,
                profilePairingCode: pairingCode,
                displayName: newGroupName
            )
            showingCreateGroup = false
            groups.insert(group, at: 0)
            showToast(createdToast)
        } catch {
            errorMessage = UserFacingError.message(for: error, language: language)
        }
        isCreating = false
    }

    private func groupSubtitle(group: GroupSummary, code: String) -> String {
        let base = membersSubtitle(group.memberCount)
        guard let latestAt = latestGroupDoodleAt[code] else { return base }
        let time = timeAgo(latestAt)
        if unreadGroupCodes.contains(code) {
            return "\(newDoodleSubtitle) • \(time)"
        }
        return "\(base) • \(time)"
    }

    private func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.locale = Locale(identifier: language.rawValue)
        return formatter.localizedString(for: date, relativeTo: Date()).lowercased()
    }

    private var newBadgeTitle: String {
        switch language {
        case .english: "new"
        case .dutch: "nieuw"
        case .german: "neu"
        case .spanish: "nuevo"
        }
    }

    private var newDoodleSubtitle: String {
        switch language {
        case .english: "new doodl"
        case .dutch: "nieuwe doodl"
        case .german: "neues doodl"
        case .spanish: "nuevo doodl"
        }
    }

    @MainActor
    private func invite(group: GroupSummary, username: String) async {
        do {
            try await SupabaseService.shared.inviteToGroup(groupCode: group.code, inviterProfileId: profileId, invitedUsername: username)
            showToast(invitedToast(username))
        } catch {
            if let message = UserFacingError.message(for: error, language: language) {
                showToast(message)
            }
        }
    }

    @MainActor
    private func respondInvite(_ invite: GroupInvite, accept: Bool) async {
        if accept, !canAddAnotherGroup {
            showToast(proRequiredForGroupsTitle)
            NotificationCenter.default.post(name: .doodlShowPro, object: nil)
            return
        }
        do {
            _ = try await SupabaseService.shared.respondInvite(
                inviteId: invite.id,
                profileId: profileId,
                profilePairingCode: pairingCode,
                accept: accept
            )
            invites.removeAll { $0.id == invite.id }
            syncTabBadgeCount()
            if accept {
                await refresh(force: true)
                showToast(joinedToast)
            } else {
                showToast(declinedToast)
            }
        } catch {
            if let message = UserFacingError.message(for: error, language: language) {
                showToast(message)
            }
        }
    }

    @MainActor
    private func showToast(_ message: String) {
        withAnimation(.easeOut(duration: 0.18)) {
            toast = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.easeOut(duration: 0.2)) {
                toast = nil
            }
        }
    }

    private func groupDisplayName(_ group: GroupSummary) -> String {
        if let name = group.displayName, !name.isEmpty { return name }
        switch language {
        case .english: return "group"
        case .dutch: return "groep"
        case .german: return "gruppe"
        case .spanish: return "grupo"
        }
    }

    private func membersSubtitle(_ count: Int) -> String {
        switch language {
        case .english: return "\(count) members"
        case .dutch: return "\(count) leden"
        case .german: return "\(count) mitglieder"
        case .spanish: return "\(count) miembros"
        }
    }

	@MainActor
	private func leaveGroup(_ group: GroupSummary) async {
		do {
			try await SupabaseService.shared.leaveGroup(pairingCode: group.code, profileId: profileId, profilePairingCode: pairingCode)
			showToast(leftToast)
			await refresh(force: true)
		} catch {
			if let message = UserFacingError.message(for: error, language: language) {
				showToast(message)
			}
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

    private var proRequiredForGroupsTitle: String {
        switch language {
        case .english: "pro required for multiple groups"
        case .dutch: "pro nodig voor meerdere groepen"
        case .german: "pro für mehrere gruppen nötig"
        case .spanish: "pro necesario para varios grupos"
        }
    }


    private var leaveShortTitle: String {
        switch language {
        case .english: "leave group"
        case .dutch: "verlaat groep"
        case .german: "gruppe verlassen"
        case .spanish: "salir del grupo"
        }
    }

    private var leaveMessage: String {
        switch language {
        case .english: "you can rejoin later with an invite."
        case .dutch: "je kunt later weer joinen met een invite."
        case .german: "du kannst später mit einer einladung wieder beitreten."
        case .spanish: "puedes volver a unirte con una invitación."
        }
    }

    private var leftToast: String {
        switch language {
        case .english: "left group"
        case .dutch: "groep verlaten"
        case .german: "gruppe verlassen"
        case .spanish: "saliste del grupo"
        }
    }

    private var createdToast: String {
        switch language {
        case .english: "group created"
        case .dutch: "groep aangemaakt"
        case .german: "gruppe erstellt"
        case .spanish: "grupo creado"
        }
    }

    private func invitedToast(_ invited: String) -> String {
        switch language {
        case .english: return "invited @\(invited)"
        case .dutch: return "@\(invited) uitgenodigd"
        case .german: return "@\(invited) eingeladen"
        case .spanish: return "invitaste a @\(invited)"
        }
    }

    private var joinedToast: String {
        switch language {
        case .english: "joined"
        case .dutch: "gejoined"
        case .german: "beigetreten"
        case .spanish: "unido"
        }
    }

    private var declinedToast: String {
        switch language {
        case .english: "declined"
        case .dutch: "geweigerd"
        case .german: "abgelehnt"
        case .spanish: "rechazado"
        }
    }

    private var invitesTitle: String {
        switch language {
        case .english: "invites"
        case .dutch: "uitnodigingen"
        case .german: "einladungen"
        case .spanish: "invitaciones"
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

    private var noGroupsTitle: String {
        switch language {
        case .english: "no groups yet. create one and invite friends."
        case .dutch: "nog geen groepen. maak er één en nodig vrienden uit."
        case .german: "noch keine gruppen. erstelle eine und lade freunde ein."
        case .spanish: "aún no hay grupos. crea uno e invita amigos."
        }
    }

    private var createTitle: String {
        switch language {
        case .english: "new group"
        case .dutch: "nieuwe groep"
        case .german: "neue gruppe"
        case .spanish: "nuevo grupo"
        }
    }

    private var createSubtitle: String {
        switch language {
        case .english: "pick a name and invite people by @username."
        case .dutch: "kies een naam en nodig mensen uit via @username."
        case .german: "wähle einen namen und lade per @username ein."
        case .spanish: "elige un nombre e invita con @username."
        }
    }

    private var groupNamePlaceholder: String {
        switch language {
        case .english: "group name"
        case .dutch: "groepnaam"
        case .german: "gruppenname"
        case .spanish: "nombre del grupo"
        }
    }

    private var createButtonTitle: String {
        switch language {
        case .english: "create"
        case .dutch: "maak aan"
        case .german: "erstellen"
        case .spanish: "crear"
        }
    }

    private var createNavTitle: String {
        switch language {
        case .english: "create group"
        case .dutch: "groep maken"
        case .german: "gruppe erstellen"
        case .spanish: "crear grupo"
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

    private func inviteGroupTitle(_ code: String) -> String {
        switch language {
        case .english: return "group invite"
        case .dutch: return "groepsuitnodiging"
        case .german: return "gruppeneinladung"
        case .spanish: return "invitación de grupo"
        }
    }

    private func inviteFromTitle(_ inviter: String) -> String {
        switch language {
        case .english: return "from @\(inviter)"
        case .dutch: return "van @\(inviter)"
        case .german: return "von @\(inviter)"
        case .spanish: return "de @\(inviter)"
        }
    }
}
