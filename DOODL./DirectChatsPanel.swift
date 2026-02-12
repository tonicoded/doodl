import SwiftUI

struct DirectChatsPanel: View {
    let language: AppLanguage
    let profileId: String
    let pairingCode: String
    let username: String
    let refreshToken: UUID
    @Binding var unreadThreadsCount: Int
    
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Namespace private var modeTabNamespace

    @State private var chats: [DirectChatThread] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var incomingRequests: [FriendRequest] = []
    @State private var isLoadingRequests = false
    @State private var showingRequests = false
    @State private var showingAddFriend = false

	    @State private var activeSnapSequence: SnapSequence?
	    @State private var replyThread: DirectChatThread?
	    @State private var profileSheetThread: DirectChatThread?
	    @State private var toast: String?
	    @State private var isOpening = false
	    @State private var mode: InboxMode = .friends
	    @State private var searchQuery: String = ""
    @State private var groupsRefreshToken = UUID()
    @State private var pendingChatAction: ChatAction?
    @State private var lastAutoRefreshAt = Date.distantPast
    @State private var groupsTabBadgeCount = 0
    @State private var pendingRefresh = false

	    private var panelFill: Color {
	        colorScheme == .dark ? Color.black.opacity(0.26) : Color(.systemBackground)
	    }

    private var panelStroke: Color {
        colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.08)
    }

    private var panelShadowColor: Color {
        colorScheme == .dark ? .black.opacity(0.16) : .black.opacity(0.00)
    }

    private struct SnapSequence: Identifiable {
        let id = UUID()
        let snaps: [SnapDoodleViewer.Snap]
        let onFinished: (_ seenAt: Date, _ finishedAll: Bool) -> Void
    }

    private enum ChatAction: Identifiable {
        case block(DirectChatThread)
        case unblock(DirectChatThread)
        case remove(DirectChatThread)

        var id: String {
            switch self {
            case .block(let t): "block:\(t.code)"
            case .unblock(let t): "unblock:\(t.code)"
            case .remove(let t): "remove:\(t.code)"
            }
        }

        var thread: DirectChatThread {
            switch self {
            case .block(let t), .unblock(let t), .remove(let t):
                return t
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

            headerRow

            switch mode {
            case .friends:
                friendsPanel
            case .groups:
                VStack(spacing: 12) {
                    searchBar
                    GroupsPanel(
                        language: language,
                        profileId: profileId,
                        pairingCode: pairingCode,
                        username: username,
                        refreshToken: groupsRefreshToken,
                        searchQuery: searchQuery,
                        badgeCount: $groupsTabBadgeCount
                    )
                    .padding(.vertical, 6)
                    .padding(.horizontal, 6)
                    .background(panelFill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(panelStroke, lineWidth: 1))
                    .shadow(color: panelShadowColor, radius: 14, x: 0, y: 10)
                }
            case .anon:
                AnonymousPanel(
                    language: language,
                    profileId: profileId,
                    pairingCode: pairingCode,
                    onRequestPro: {
                        NotificationCenter.default.post(name: .doodlShowPro, object: nil)
                    }
                )
                .padding(.vertical, 6)
                .padding(.horizontal, 6)
                .background(panelFill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(panelStroke, lineWidth: 1))
                .shadow(color: panelShadowColor, radius: 14, x: 0, y: 10)
            }
        }
        .confirmationDialog(
            "",
            isPresented: Binding(
                get: { pendingChatAction != nil },
                set: { if !$0 { pendingChatAction = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let action = pendingChatAction {
                switch action {
                case .block(let thread):
                    Button(blockTitle(thread), role: .destructive) {
                        Task { await performBlock(thread) }
                    }
                case .unblock(let thread):
                    Button(unblockTitle(thread)) {
                        Task { await performUnblock(thread) }
                    }
                case .remove(let thread):
                    Button(removeTitle(thread), role: .destructive) {
                        Task { await performRemoveFriend(thread) }
                    }
                }
            }
            Button(cancelTitle, role: .cancel) {}
        } message: {
            if let action = pendingChatAction {
                switch action {
                case .block(let thread):
                    Text(blockMessage(thread))
                case .unblock(let thread):
                    Text(unblockMessage(thread))
                case .remove(let thread):
                    Text(removeMessage(thread))
                }
            }
        }
        .onAppear {
            Task { await refresh(force: false) }
        }
        .onChange(of: refreshToken) { _, _ in
            Task { await refresh(force: true) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .doodlInboxShouldRefresh)) { _ in
            // When a push arrives, reorder the inbox by refreshing the lightweight chat list.
            // Throttle to avoid spam-refresh during bursts.
            let now = Date()
            if now.timeIntervalSince(lastAutoRefreshAt) < 1.5 { return }
            lastAutoRefreshAt = now

            if mode == .groups {
                groupsRefreshToken = UUID()
                return
            }

            Task { await refresh(force: true) }
        }
        .onChange(of: mode) { _, newValue in
            searchQuery = ""
            if newValue == .friends {
                Task { await refresh(force: true) }
            }
        }
        .fullScreenCover(item: $activeSnapSequence) { sequence in
            SnapDoodleSequenceViewer(
                snaps: sequence.snaps,
                language: language,
                autoAdvanceSeconds: 10,
                onReply: {
                    guard let first = sequence.snaps.first else { return }
                    guard let latest = chats.first(where: { $0.otherUsername == first.senderUsername }) else { return }
                    replyThread = latest
                },
                onFinished: sequence.onFinished
            )
        }
        .fullScreenCover(item: $replyThread) { thread in
            DirectReplyComposerView(
                language: language,
                thread: thread,
                profileId: profileId,
                pairingCode: pairingCode,
                onSent: {
                    Task { await refresh(force: true) }
                }
            )
            .environmentObject(purchaseManager)
        }
        .sheet(isPresented: $showingAddFriend) {
            AddFriendSheet(
                language: language,
                profileId: profileId,
                pairingCode: pairingCode,
                onDone: {
                    showingAddFriend = false
                    Task { await refresh(force: true) }
                }
            )
        }
	        .sheet(isPresented: $showingRequests) {
	            FriendRequestsSheet(
	                language: language,
	                profileId: profileId,
	                pairingCode: pairingCode,
	                requests: incomingRequests,
	                onChanged: {
	                    Task { await refresh(force: true) }
	                }
	            )
	        }
	        .sheet(item: $profileSheetThread) { thread in
	            FriendProfileSheet(language: language, thread: thread)
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
    }

    private var headerRow: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    Haptics.tap(.light)
                    switch mode {
                    case .friends:
                        Task {
                            guard await ActionRateLimiter.shared.allow(
                                key: "directChats.refresh.friends.\(profileId)",
                                cooldownSeconds: 1.5
                            ) else { return }
                            await refresh(force: true)
                        }
                    case .groups:
                        Task {
                            guard await ActionRateLimiter.shared.allow(
                                key: "directChats.refresh.groups.\(profileId)",
                                cooldownSeconds: 1.5
                            ) else { return }
                            await MainActor.run { groupsRefreshToken = UUID() }
                        }
                    case .anon:
                        break
                    }
	                } label: {
	                    Image(systemName: "arrow.clockwise")
	                        .font(.system(size: 16, weight: .heavy))
	                        .foregroundStyle(Color.primary.opacity(0.82))
	                        .padding(10)
	                        .background(panelFill, in: Circle())
	                        .overlay(Circle().stroke(panelStroke, lineWidth: 1))
	                        .shadow(color: panelShadowColor, radius: 8, x: 0, y: 4)
	                }
	                .buttonStyle(PremiumPlainButtonStyle(scale: 0.95, pressedOpacity: 0.94))
	                .disabled(mode == .friends && isLoading)
	                .dashboardTutorialAnchor(.refreshButton)

                Spacer(minLength: 0)

                if mode == .friends {
                    HStack(spacing: 10) {
	                        ShareLink(item: appInviteText) {
	                            Image(systemName: "square.and.arrow.up")
	                                .font(.system(size: 15, weight: .heavy))
	                                .foregroundStyle(.white)
	                                .frame(width: 36, height: 36)
	                                .background(.black.opacity(0.90), in: Circle())
	                                .overlay(Circle().stroke(.white.opacity(0.14), lineWidth: 1))
	                        }
	                        .buttonStyle(PremiumPlainButtonStyle(scale: 0.95, pressedOpacity: 0.94))
	                        .simultaneousGesture(TapGesture().onEnded { Haptics.tap(.light) })

                        if !incomingRequests.isEmpty {
                            Button {
                                Haptics.tap(.light)
                                showingRequests = true
                            } label: {
                                ZStack(alignment: .topTrailing) {
	                                    Image(systemName: "person.crop.circle.badge.plus")
	                                        .font(.system(size: 15, weight: .heavy))
	                                        .foregroundStyle(Color.primary.opacity(0.82))
	                                        .frame(width: 36, height: 36)
	                                        .background(panelFill, in: Circle())
	                                        .overlay(Circle().stroke(panelStroke, lineWidth: 1))
	                                        .shadow(color: panelShadowColor, radius: 8, x: 0, y: 4)

                                    Text("\(incomingRequests.count)")
                                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                                        .foregroundStyle(.white)
                                        .padding(5)
                                        .background(.black.opacity(0.90), in: Circle())
                                        .overlay(Circle().stroke(.white.opacity(0.20), lineWidth: 1))
                                        .offset(x: 10, y: -10)
                                }
	                            }
	                            .buttonStyle(PremiumPlainButtonStyle(scale: 0.95, pressedOpacity: 0.94))
	                        }

                        Button {
                            Haptics.tap(.medium)
                            showingAddFriend = true
	                        } label: {
	                            Image(systemName: "person.badge.plus")
	                                .font(.system(size: 15, weight: .heavy))
	                                .foregroundStyle(.white)
	                                .frame(width: 36, height: 36)
	                                .background(.black.opacity(0.90), in: Circle())
	                                .overlay(Circle().stroke(.white.opacity(0.14), lineWidth: 1))
	                        }
	                        .buttonStyle(PremiumPlainButtonStyle(scale: 0.95, pressedOpacity: 0.94))
	                        .dashboardTutorialAnchor(.addFriendButton)
	                    }
	                }
            }

            modeTabs
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var modeTabs: some View {
        let friendsBadgeCount = max(0, unreadThreadsCount + incomingRequests.count)
        return HStack(spacing: 6) {
            modeTabButton(title: friendsTitle, isActive: mode == .friends, badgeCount: friendsBadgeCount) { mode = .friends }
            modeTabButton(title: groupsTitle, isActive: mode == .groups, badgeCount: groupsTabBadgeCount) { mode = .groups }
            modeTabButton(title: anonTitle, isActive: mode == .anon, badgeCount: 0) { mode = .anon }
        }
        .padding(6)
        .background(panelFill, in: Capsule(style: .continuous))
        .overlay(Capsule(style: .continuous).stroke(panelStroke, lineWidth: 1))
        .shadow(color: panelShadowColor, radius: 10, x: 0, y: 6)
        .dashboardTutorialAnchor(.inboxModeTabs)
    }

    private var filteredChats: [DirectChatThread] {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return chats }
        return chats.filter { $0.otherUsername.lowercased().contains(q) }
    }

    private var searchBar: some View {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        return HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.secondary.opacity(0.75))

            TextField(searchPlaceholder, text: $searchQuery)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.primary.opacity(0.92))

            if !q.isEmpty {
                Button {
                    Haptics.tap(.light)
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.secondary.opacity(0.70))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(panelFill, in: Capsule(style: .continuous))
        .overlay(Capsule(style: .continuous).stroke(panelStroke, lineWidth: 1))
        .shadow(color: panelShadowColor, radius: 8, x: 0, y: 4)
        .opacity(mode == .friends ? 1 : 1) // keep for both friends/groups
        .animation(.easeInOut(duration: 0.15), value: mode)
    }

    private var friendsPanel: some View {
        VStack(spacing: 12) {
            searchBar

            Group {
                if isLoading {
                    ProgressView().tint(Color.primary.opacity(0.65))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 18)
                } else if chats.isEmpty {
                    emptyState
                        .padding(.vertical, 6)
                } else {
                    LazyVStack(spacing: 0) {
                        let items = filteredChats
                        ForEach(items.indices, id: \.self) { idx in
                            let thread = items[idx]
                            chatRow(thread)
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
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.vertical, 6)
            .background(panelFill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(panelStroke, lineWidth: 1))
            .shadow(color: panelShadowColor, radius: 14, x: 0, y: 10)
        }
    }

    private var searchPlaceholder: String {
        switch language {
        case .english: return mode == .friends ? "search friends…" : "search groups…"
        case .dutch: return mode == .friends ? "zoek vrienden…" : "zoek groepen…"
        case .german: return mode == .friends ? "freunde suchen…" : "gruppen suchen…"
        case .spanish: return mode == .friends ? "buscar amigos…" : "buscar grupos…"
        }
    }

    private func modeTabButton(title: String, isActive: Bool, badgeCount: Int, action: @escaping () -> Void) -> some View {
        let activeForeground = colorScheme == .dark ? Color.black.opacity(0.92) : Color.white.opacity(0.96)
        let inactiveForeground = Color.primary.opacity(0.72)
        let inactiveBadgeBackground = Color.primary.opacity(colorScheme == .dark ? 0.22 : 0.16)
        return Button {
            Haptics.selectionChanged()
            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                action()
            }
        } label: {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(isActive ? activeForeground : inactiveForeground)

                if badgeCount > 0 {
                    let display = badgeCount > 99 ? "99+" : "\(badgeCount)"
                    Text(display)
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(isActive ? .black.opacity(0.90) : Color.primary.opacity(0.86))
                        .padding(.vertical, 3)
                        .padding(.horizontal, 6)
                        .background(isActive ? Color(hex: "FFFC00").opacity(0.96) : inactiveBadgeBackground, in: Capsule(style: .continuous))
                        .overlay(Capsule(style: .continuous).stroke(Color.primary.opacity(0.10), lineWidth: 1))
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
	            .background {
	                if isActive {
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    colorScheme == .dark ? .white.opacity(0.96) : .black.opacity(0.92),
                                    colorScheme == .dark ? .white.opacity(0.88) : .black.opacity(0.82),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .matchedGeometryEffect(id: "modeTab.activeBackground", in: modeTabNamespace)
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(Color.primary.opacity(0.10), lineWidth: 1)
                        )
                }
            }
	        }
	        .buttonStyle(PremiumPlainButtonStyle(scale: 0.98, pressedOpacity: 0.97))
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

    private var anonTitle: String {
        switch language {
        case .english: "anon"
        case .dutch: "anon"
        case .german: "anon"
        case .spanish: "anón"
        }
    }

    private enum InboxMode {
        case friends
        case groups
        case anon
    }

    private var appInviteText: String {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let handle: String? = {
            guard !trimmed.isEmpty else { return nil }
            return trimmed.hasPrefix("@") ? trimmed : "@\(trimmed)"
        }()
        let url = "https://www.doodl-me.com"
        switch language {
        case .english:
            return handle == nil ? "Download DOODL. via \(url)" : "Download DOODL. via \(url) and add me: \(handle!)"
        case .dutch:
            return handle == nil ? "Download DOODL. via \(url)" : "Download DOODL. via \(url) en voeg me toe: \(handle!)"
        case .german:
            return handle == nil ? "Lade DOODL. über \(url) herunter" : "Lade DOODL. über \(url) herunter und füge mich hinzu: \(handle!)"
        case .spanish:
            return handle == nil ? "Descarga DOODL. desde \(url)" : "Descarga DOODL. desde \(url) y agrégame: \(handle!)"
        }
    }

    private func streakBadge(_ count: Int) -> some View {
        let value = max(0, count)
        return HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(Color(hex: "FF9F0A"), Color(hex: "FF3B30"))
                .font(.system(size: 11, weight: .heavy))

            Text("\(value)")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.primary.opacity(0.82))
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 7)
        .background(Color.primary.opacity(0.06), in: Capsule(style: .continuous))
        .overlay(Capsule(style: .continuous).stroke(Color.primary.opacity(0.10), lineWidth: 1))
        .fixedSize(horizontal: true, vertical: false)
    }

	    private func chatRow(_ thread: DirectChatThread) -> some View {
	        let unreadAccent = Color(hex: colorScheme == .dark ? "0A84FF" : "007AFF")
	        let time = timeAgo(thread.lastCreatedAt)
	        let subtitle: String = {
	            if thread.lastCreatedAt == nil { return noMessagesSubtitle }
	            return thread.hasUnread ? newDoodleSubtitle : openedSubtitle
	        }()

			        return HStack(spacing: 12) {
                Button {
                    Haptics.tap(.light)
                    profileSheetThread = thread
                } label: {
                    AvatarCircle(url: thread.otherAvatarURL, fallbackText: initials(from: thread.otherUsername))
                        .frame(width: 52, height: 52)
                        .overlay(
                            Circle()
                                .stroke(thread.hasUnread ? unreadAccent.opacity(0.95) : .clear, lineWidth: 2)
                        )
                }
                .buttonStyle(.plain)

	            HStack(spacing: 12) {
	                VStack(alignment: .leading, spacing: 2) {
	                    HStack(spacing: 6) {
	                        Text("@\(thread.otherUsername)")
	                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundStyle(.primary.opacity(0.92))
                        if thread.otherIsPro {
                            CrownBadge(size: 13)
                        }
                    }

                    HStack(spacing: 8) {
                        Text(subtitle)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(thread.hasUnread ? unreadAccent.opacity(0.92) : .secondary.opacity(0.85))
                            .lineLimit(1)

	                        if thread.streakCount > 0 {
	                            streakBadge(thread.streakCount)
	                        }
	                    }
	                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 6) {
                    if let time, !time.isEmpty {
                        HStack(spacing: 6) {
                            if thread.hasUnread {
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
	                Task { await openLatestSnap(thread) }
	            }

	            Button {
	                Haptics.tap(.medium)
	                replyThread = thread
	            } label: {
	                Image(systemName: "paperplane.fill")
	                    .font(.system(size: 14, weight: .heavy))
	                    .foregroundStyle(.black.opacity(0.90))
	                    .frame(width: 38, height: 38)
	                    .background(Color(hex: "FFFC00").opacity(0.96), in: Circle())
	                    .overlay(Circle().stroke(Color.primary.opacity(0.12), lineWidth: 1))
	                    .shadow(color: .black.opacity(0.10), radius: 10, x: 0, y: 6)
	            }
	            .buttonStyle(PremiumPlainButtonStyle(scale: 0.94, pressedOpacity: 0.93))
	        }
        .contextMenu {
            Button {
                Haptics.tap(.medium)
                replyThread = thread
            } label: {
                Label(sendDoodlTitle, systemImage: "paperplane.fill")
            }

            Button(role: .destructive) {
                Haptics.tap(.light)
                pendingChatAction = .block(thread)
            } label: {
                Label(blockShortTitle, systemImage: "hand.raised.fill")
            }

            Button {
                Haptics.tap(.light)
                pendingChatAction = .unblock(thread)
            } label: {
                Label(unblockShortTitle, systemImage: "hand.raised.slash.fill")
            }

            Button(role: .destructive) {
                Haptics.tap(.light)
                pendingChatAction = .remove(thread)
            } label: {
                Label(removeShortTitle, systemImage: "person.fill.xmark")
            }
        }
    }

    @MainActor
    private func performBlock(_ thread: DirectChatThread) async {
        do {
            try await SupabaseService.shared.blockProfile(
                profileId: profileId,
                profilePairingCode: pairingCode,
                blockedProfileId: thread.otherProfileId
            )
            showToast(blockedToast(thread))
            await refresh(force: true)
        } catch {
            if let message = UserFacingError.message(for: error, language: language) {
                showToast(message)
            }
        }
    }

    @MainActor
    private func performUnblock(_ thread: DirectChatThread) async {
        do {
            try await SupabaseService.shared.unblockProfile(
                profileId: profileId,
                profilePairingCode: pairingCode,
                blockedProfileId: thread.otherProfileId
            )
            showToast(unblockedToast(thread))
            await refresh(force: true)
        } catch {
            if let message = UserFacingError.message(for: error, language: language) {
                showToast(message)
            }
        }
    }

    @MainActor
    private func performRemoveFriend(_ thread: DirectChatThread) async {
        do {
            try await SupabaseService.shared.removeFriend(
                profileId: profileId,
                profilePairingCode: pairingCode,
                friendProfileId: thread.otherProfileId
            )
            showToast(removedToast(thread))
            await refresh(force: true)
        } catch {
            // Back-compat: if remove-friend isn't deployed yet, fall back to blocking locally.
            if error.localizedDescription.localizedCaseInsensitiveContains("not available yet") {
                await performBlock(thread)
                chats.removeAll { $0.code == thread.code }
                unreadThreadsCount = chats.filter { $0.hasUnread }.count
                showToast(removedFallbackToast(thread))
                return
            }
            if let message = UserFacingError.message(for: error, language: language) {
                showToast(message)
            }
        }
    }

    private var sendDoodlTitle: String {
        switch language {
        case .english: "send doodl"
        case .dutch: "stuur doodl"
        case .german: "doodl senden"
        case .spanish: "enviar doodl"
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

    private var removeShortTitle: String {
        switch language {
        case .english: "remove friend"
        case .dutch: "vriend verwijderen"
        case .german: "freund entfernen"
        case .spanish: "eliminar amigo"
        }
    }

    private func blockTitle(_ thread: DirectChatThread) -> String { "\(blockShortTitle) @\(thread.otherUsername)?" }
    private func unblockTitle(_ thread: DirectChatThread) -> String { "\(unblockShortTitle) @\(thread.otherUsername)?" }
    private func removeTitle(_ thread: DirectChatThread) -> String { "\(removeShortTitle) @\(thread.otherUsername)?" }

    private func blockMessage(_ thread: DirectChatThread) -> String {
        switch language {
        case .english: "they won’t be able to send you doodls anymore."
        case .dutch: "ze kunnen je geen doodls meer sturen."
        case .german: "sie können dir keine doodls mehr senden."
        case .spanish: "ya no podrán enviarte doodls."
        }
    }

    private func unblockMessage(_ thread: DirectChatThread) -> String {
        switch language {
        case .english: "they can send you doodls again."
        case .dutch: "ze kunnen je weer doodls sturen."
        case .german: "sie können dir wieder doodls senden."
        case .spanish: "podrán enviarte doodls otra vez."
        }
    }

    private func removeMessage(_ thread: DirectChatThread) -> String {
        switch language {
        case .english: "this removes the friend + hides your chat."
        case .dutch: "dit verwijdert de vriend + verbergt jullie chat."
        case .german: "das entfernt den freund + verbirgt euren chat."
        case .spanish: "esto elimina al amigo y oculta el chat."
        }
    }

    private func blockedToast(_ thread: DirectChatThread) -> String {
        switch language {
        case .english: "blocked @\(thread.otherUsername)"
        case .dutch: "@\(thread.otherUsername) geblokkeerd"
        case .german: "@\(thread.otherUsername) blockiert"
        case .spanish: "@\(thread.otherUsername) bloqueado"
        }
    }

    private func unblockedToast(_ thread: DirectChatThread) -> String {
        switch language {
        case .english: "unblocked @\(thread.otherUsername)"
        case .dutch: "@\(thread.otherUsername) gedeblokkeerd"
        case .german: "@\(thread.otherUsername) entsperrt"
        case .spanish: "@\(thread.otherUsername) desbloqueado"
        }
    }

    private func removedToast(_ thread: DirectChatThread) -> String {
        switch language {
        case .english: "removed @\(thread.otherUsername)"
        case .dutch: "@\(thread.otherUsername) verwijderd"
        case .german: "@\(thread.otherUsername) entfernt"
        case .spanish: "@\(thread.otherUsername) eliminado"
        }
    }

    private func removedFallbackToast(_ thread: DirectChatThread) -> String {
        switch language {
        case .english: "removed (fallback: blocked) @\(thread.otherUsername)"
        case .dutch: "verwijderd (fallback: geblokkeerd) @\(thread.otherUsername)"
        case .german: "entfernt (fallback: blockiert) @\(thread.otherUsername)"
        case .spanish: "eliminado (fallback: bloqueado) @\(thread.otherUsername)"
        }
    }

    private func chatSubtitle(_ thread: DirectChatThread) -> String {
        let time = timeAgo(thread.lastCreatedAt) ?? noMessagesSubtitle
        guard thread.hasUnread else { return time }
        return "\(newDoodleSubtitle) • \(time)"
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

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text(emptyTitle)
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(.primary.opacity(0.92))
            Text(emptySubtitle)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary.opacity(0.85))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
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
            isLoadingRequests = false
            if pendingRefresh {
                pendingRefresh = false
                Task { await refresh(force: true) }
            }
        }
        errorMessage = nil
        do {
            let threads = try await SupabaseService.shared.listDirectChats(
                profileId: profileId,
                profilePairingCode: pairingCode,
                limit: 60
            )
            chats = threads
            unreadThreadsCount = threads.filter { $0.hasUnread }.count

            // Keep a best-effort list of widget sources for "all sources" mode.
            // This helps resolve pushes that don't include `group_code` yet.
            let existing = SharedWidgetStore.loadWidgetSources()
            let codes = threads.map(\.code) + [pairingCode]
            SharedWidgetStore.saveWidgetSources(existing + codes)
        } catch {
            errorMessage = UserFacingError.message(for: error, language: language)
        }

        do {
            isLoadingRequests = true
            incomingRequests = try await SupabaseService.shared.listFriendRequests(
                profileId: profileId,
                profilePairingCode: pairingCode,
                limit: 50
            )
        } catch {
            // Best-effort; don't block chats.
        }
    }

    @MainActor
    private func openLatestSnap(_ thread: DirectChatThread) async {
        if isOpening { return }
        isOpening = true
        defer { isOpening = false }
        do {
            let code = thread.code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let lastSeen = InboxSeenStore.lastSeenAt(groupCode: code)

            let metas = try await SupabaseService.shared.fetchInboxDoodleMetas(
                groupCode: code,
                requesterProfileId: profileId,
                limit: 18
            )

            let unseen = metas
                .filter { $0.senderProfileId == thread.otherProfileId }
                .filter { ($0.createdAt ?? .distantPast) > lastSeen }
                .sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }

            guard !unseen.isEmpty else {
                replyThread = thread
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
                    senderUsername: thread.otherUsername,
                    senderIsPro: thread.otherIsPro,
                    image: image,
                    createdAt: doodle.createdAt
                )
            }

            guard !snaps.isEmpty else {
                replyThread = thread
                return
            }

            let newestSeenAt = snaps.compactMap(\.createdAt).max() ?? Date()
            activeSnapSequence = SnapSequence(
                snaps: snaps,
                onFinished: { [code] seenAt, finishedAll in
                    let clamped = min(seenAt, newestSeenAt)
                    InboxSeenStore.markSeen(groupCode: code, at: clamped)
                    Task { @MainActor in
                        // Only mark server-side as viewed when the user actually finishes the whole sequence.
                        if finishedAll {
                            _ = try? await SupabaseService.shared.fetchThreadDoodles(
                                groupCode: code,
                                requesterProfileId: profileId,
                                requesterPairingCode: pairingCode,
                                senderProfileId: thread.otherProfileId,
                                limit: 1
                            )
                        }
                        await refresh(force: true)
                    }
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

    @MainActor
    private func showToast(_ message: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            toast = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.easeOut(duration: 0.2)) {
                toast = nil
            }
        }
    }

    private var noSnapToast: String {
        switch language {
        case .english: "no doodl yet"
        case .dutch: "nog geen doodl"
        case .german: "noch kein doodl"
        case .spanish: "aún no hay doodl"
        }
    }

    private func timeAgo(_ date: Date?) -> String? {
        guard let date else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.locale = Locale(identifier: language.rawValue)
        return formatter.localizedString(for: date, relativeTo: Date()).lowercased()
    }

    private func initials(from username: String) -> String {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "?" }
        let parts = trimmed.split(separator: "_").flatMap { $0.split(separator: ".") }
        let first = parts.first?.first.map(String.init) ?? String(trimmed.prefix(1))
        let second = (parts.dropFirst().first?.first).map(String.init) ?? String(trimmed.dropFirst().prefix(1))
        return (first + second).uppercased()
    }

    private var requestsTitle: String {
        switch language {
        case .english: "requests"
        case .dutch: "verzoeken"
        case .german: "anfragen"
        case .spanish: "solicitudes"
        }
    }

    private var emptyTitle: String {
        switch language {
        case .english: "add friends to start"
        case .dutch: "voeg vrienden toe"
        case .german: "füge freunde hinzu"
        case .spanish: "añade amigos"
        }
    }

    private var emptySubtitle: String {
        switch language {
        case .english: "add someone by @username, then send them a doodl."
        case .dutch: "voeg iemand toe via @username en stuur een doodl."
        case .german: "füge jemanden per @username hinzu und sende ein doodl."
        case .spanish: "añade a alguien con @usuario y envía un doodl."
        }
    }

    private var noMessagesSubtitle: String {
        switch language {
        case .english: "no doodls yet"
        case .dutch: "nog geen doodls"
        case .german: "noch keine doodls"
        case .spanish: "aún no hay doodls"
        }
    }

    private var openedSubtitle: String {
        switch language {
        case .english: "opened"
        case .dutch: "geopend"
        case .german: "geöffnet"
        case .spanish: "abierto"
        }
    }
}

private struct AddFriendSheet: View {
    let language: AppLanguage
    let profileId: String
    let pairingCode: String
    let onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var isSearching = false
    @State private var results: [ProfileSearchResult] = []
    @State private var toast: String?

    var body: some View {
        NavigationStack {
            ZStack {
                ThemedBackground()

                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.secondary.opacity(0.85))

                        TextField(searchPlaceholder, text: $query)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .keyboardType(.asciiCapable)
                            .tint(Color.primary)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .background(.thinMaterial, in: Capsule(style: .continuous))
                    .overlay(Capsule().stroke(Color.primary.opacity(0.10), lineWidth: 1))

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 10) {
                            if isSearching {
                                ProgressView().tint(Color.primary.opacity(0.65))
                                    .padding(.top, 12)
                            } else if results.isEmpty, query.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 {
                                Text(noResultsTitle)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.secondary.opacity(0.85))
                                    .padding(.top, 10)
                            } else {
                                ForEach(results) { profile in
                                    Button {
                                        Task { await sendRequest(profile) }
                                    } label: {
                                        HStack(spacing: 12) {
                                            AvatarCircle(url: profile.avatarURL, fallbackText: initials(from: profile.username))
                                                .frame(width: 42, height: 42)

                                            Text("@\(profile.username)")
                                                .font(.system(size: 15, weight: .heavy, design: .rounded))
                                                .foregroundStyle(.primary.opacity(0.92))
                                            Spacer()
                                            Image(systemName: "paperplane.fill")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundStyle(Color.secondary.opacity(0.85))
                                        }
                                        .padding(.vertical, 12)
                                        .padding(.horizontal, 14)
                                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                .stroke(Color.primary.opacity(0.10), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.top, 4)
                        .padding(.bottom, 24)
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
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
            }
            .navigationTitle(addFriendTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(closeTitle) {
                        Haptics.tap()
                        dismiss()
                    }
                    .foregroundStyle(.primary.opacity(0.92))
                }
            }
            .onChange(of: query) { _, _ in
                Task { await search() }
            }
        }
    }

    @MainActor
    private func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            results = []
            return
        }
        isSearching = true
        do {
            results = try await SupabaseService.shared.searchProfiles(
                query: trimmed,
                excludeProfileId: profileId,
                limit: 12
            )
        } catch {
            results = []
        }
        isSearching = false
    }

    @MainActor
    private func sendRequest(_ profile: ProfileSearchResult) async {
        do {
            _ = try await SupabaseService.shared.sendFriendRequest(
                profileId: profileId,
                profilePairingCode: pairingCode,
                targetUsername: profile.username
            )
            showToast(sentTitle)
            onDone()
        } catch {
            if let message = UserFacingError.message(for: error, language: language) {
                showToast(message)
            }
        }
    }

    @MainActor
    private func showToast(_ text: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            toast = text
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.easeOut(duration: 0.2)) {
                toast = nil
            }
        }
    }

    private func initials(from username: String) -> String {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "?" }
        let parts = trimmed.split(separator: "_").flatMap { $0.split(separator: ".") }
        let first = parts.first?.first.map(String.init) ?? String(trimmed.prefix(1))
        let second = (parts.dropFirst().first?.first).map(String.init) ?? String(trimmed.dropFirst().prefix(1))
        return (first + second).uppercased()
    }

    private var searchPlaceholder: String {
        switch language {
        case .english: "search @username"
        case .dutch: "zoek @username"
        case .german: "suche @username"
        case .spanish: "buscar @usuario"
        }
    }

    private var addFriendTitle: String {
        switch language {
        case .english: "add friend"
        case .dutch: "vriend toevoegen"
        case .german: "freund hinzufügen"
        case .spanish: "añadir amigo"
        }
    }

    private var noResultsTitle: String {
        switch language {
        case .english: "no users found"
        case .dutch: "geen users gevonden"
        case .german: "keine nutzer gefunden"
        case .spanish: "no se encontraron usuarios"
        }
    }

    private var sentTitle: String {
        switch language {
        case .english: "request sent"
        case .dutch: "verzoek verstuurd"
        case .german: "anfrage gesendet"
        case .spanish: "solicitud enviada"
        }
    }

    private var closeTitle: String {
        switch language {
        case .english: "close"
        case .dutch: "sluiten"
        case .german: "schließen"
        case .spanish: "cerrar"
        }
    }
}

private struct FriendRequestsSheet: View {
    let language: AppLanguage
    let profileId: String
    let pairingCode: String
    let requests: [FriendRequest]
    let onChanged: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var busyIds: Set<String> = []
    @State private var toast: String?

    var body: some View {
        NavigationStack {
            ZStack {
                ThemedBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        if requests.isEmpty {
                            Text(emptyTitle)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary.opacity(0.85))
                                .padding(.top, 14)
                        } else {
                            ForEach(requests) { req in
                                requestRow(req)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
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
            }
            .navigationTitle(requestsTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(closeTitle) {
                        Haptics.tap()
                        dismiss()
                    }
                    .foregroundStyle(.primary.opacity(0.92))
                }
            }
        }
    }

    private func requestRow(_ req: FriendRequest) -> some View {
        HStack(spacing: 12) {
            AvatarCircle(url: req.requesterAvatarURL, fallbackText: initials(from: req.requesterUsername))
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text("@\(req.requesterUsername)")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.92))
                Text(timeAgo(req.createdAt) ?? "")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary.opacity(0.85))
            }

            Spacer()

            Button {
                Task { await respond(req, accept: false) }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Color.primary.opacity(0.82))
                    .padding(10)
                    .background(.thinMaterial, in: Circle())
                    .overlay(Circle().stroke(Color.primary.opacity(0.10), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(busyIds.contains(req.id))

            Button {
                Task { await respond(req, accept: true) }
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.black.opacity(0.9), in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(busyIds.contains(req.id))
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.10), lineWidth: 1)
        )
    }

    @MainActor
    private func respond(_ req: FriendRequest, accept: Bool) async {
        if busyIds.contains(req.id) { return }
        busyIds.insert(req.id)
        do {
            let result = try await SupabaseService.shared.respondFriendRequest(
                requestId: req.id,
                profileId: profileId,
                profilePairingCode: pairingCode,
                accept: accept
            )
            showToast(result.status.isEmpty ? doneTitle : result.status)
            onChanged()
        } catch {
            if let message = UserFacingError.message(for: error, language: language) {
                showToast(message)
            }
        }
        busyIds.remove(req.id)
    }

    @MainActor
    private func showToast(_ text: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            toast = text
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.easeOut(duration: 0.2)) {
                toast = nil
            }
        }
    }

    private func initials(from username: String) -> String {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "?" }
        let parts = trimmed.split(separator: "_").flatMap { $0.split(separator: ".") }
        let first = parts.first?.first.map(String.init) ?? String(trimmed.prefix(1))
        let second = (parts.dropFirst().first?.first).map(String.init) ?? String(trimmed.dropFirst().prefix(1))
        return (first + second).uppercased()
    }

    private func timeAgo(_ date: Date?) -> String? {
        guard let date else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.locale = Locale(identifier: language.rawValue)
        return formatter.localizedString(for: date, relativeTo: Date()).lowercased()
    }

    private var requestsTitle: String {
        switch language {
        case .english: "friend requests"
        case .dutch: "vriendverzoeken"
        case .german: "freundschaftsanfragen"
        case .spanish: "solicitudes de amistad"
        }
    }

    private var emptyTitle: String {
        switch language {
        case .english: "no requests"
        case .dutch: "geen verzoeken"
        case .german: "keine anfragen"
        case .spanish: "sin solicitudes"
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

    private var closeTitle: String {
        switch language {
        case .english: "close"
        case .dutch: "sluiten"
        case .german: "schließen"
        case .spanish: "cerrar"
        }
    }
}
