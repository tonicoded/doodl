import SwiftUI
import UIKit
import PhotosUI
import Photos
import WidgetKit
import Combine

private extension UIImage {
    func flattenedOnWhite(scale: CGFloat = 1.0) -> UIImage {
        guard size.width > 0, size.height > 0 else { return self }
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

		struct DashboardView: View {
		    @Binding var path: [OnboardingRoute]
		    @Binding var selectedLanguage: AppLanguage
		    @Binding var pairingCode: String
		    @Binding var username: String
		    @Binding var avatarURL: URL?
		    @Binding var profileId: String?
		    @Binding var joinedCode: String?
		    let resetOnboarding: () -> Void

		    @State private var joinedGroups: [String] = []
		    @State private var showingGroupPicker = false
		    @State private var groupPickerJoinCode: String = ""
		    @State private var groupPickerError: String?
		    @State private var groupPickerSuccess: String?
		    @State private var isMutatingGroups = false
		    @State private var groupMemberCounts: [String: (count: Int, max: Int)] = [:]
		    @State private var isLoadingGroupCounts = false
    @State private var isDeleting = false
		    @State private var errorMessage: String?
		    @State private var selectedTab: DashboardTab = .share
		    @State private var showingMembers = false
		    @State private var members: [GroupMemberProfile] = []
		    @State private var isLoadingMembers = false
		    @State private var membersError: String?
		    @State private var groupOwnerProfileId: String?
    @State private var isMutatingMembers = false
    @State private var membersRequestId = UUID()
    @State private var showingSettings = false
			    @State private var showingWidgetHelp = false
			    @State private var showingWidgetNudge = false
			    @State private var showingAnonymousSendFlow = false
			    @State private var invites: [GroupInvite] = []
			    @State private var isLoadingInvites = false
			    @State private var invitesError: String?
			    @State private var xpState: ProfileXPState?
				    @State private var isLoadingXP = false
				    @State private var lastKnownLevel: Int?
				    @State private var showingLevelUp = false
				    @State private var levelUpLevel: Int = 1
				    @State private var showingRankDetails = false
				    @State private var inboxDoodles: [InboxDoodle] = []
				    @State private var isLoadingInbox = false
				    @State private var inboxError: String?
                    @State private var inboxNotice: String?
				    @State private var inboxPageIndex: Int = 0
				    @State private var selectedInboxDoodle: InboxDoodle?
				    @State private var inboxSource: InboxSource = .chats
				    @State private var chatsRefreshToken = UUID()
				    @State private var directUnreadThreadsCount = 0
				    @State private var pendingDoodleSend: PendingDoodleSend?
				    @State private var pendingDoodleSendContinuation: CheckedContinuation<Void, Error>?
				    @State private var anonymousInboxDoodles: [AnonymousInboxDoodle] = []
			    @State private var isLoadingAnonymousInbox = false
			    @State private var anonymousInboxError: String?
                    @State private var anonymousInboxNotice: String?
				    @State private var anonymousInboxPageIndex: Int = 0
		    @State private var selectedAnonymousInboxDoodle: AnonymousInboxDoodle?
			    @State private var anonymousLinkCode: String?
			    @State private var isAnonymousEnabled = false
			    @State private var isLoadingAnonymousLink = false
			    @State private var showDeleteConfirm = false
				    @State private var showUsernameEditor = false
				    @State private var usernameEditError: String?
				    @State private var showingProPaywall = false
			    @State private var pendingProPaywall = false
			    @State private var showingDashboardTutorial = false
			    @State private var dashboardTutorialStepIndex = 0
			    @State private var showingReviewPrompt = false
    @State private var avatarPickerItem: PhotosPickerItem?
    @State private var isUpdatingAvatar = false
    @State private var lastPushedApnsToken: String?
    @State private var showingAnonymousShareSheet: Bool = false
    @State private var anonymousShareURL: URL?
	        @Environment(\.scenePhase) private var scenePhase
	        @EnvironmentObject private var purchaseManager: PurchaseManager
	        @Environment(\.colorScheme) private var colorScheme
	        private let presenceTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
		        @State private var lastInboxRefreshAt: Date = .distantPast
		        @State private var inboxRefreshTask: Task<Void, Never>?
	        @State private var inboxRequestedLimit: Int = 0
	        @State private var inboxReachedEnd: Bool = false
	        @State private var lastInboxCode: String = ""
		        @State private var lastAnonymousInboxRefreshAt: Date = .distantPast
		        @State private var anonymousInboxRefreshTask: Task<Void, Never>?
                @State private var lastWidgetRefreshAt: Date = .distantPast
			        @State private var anonymousInboxRequestedLimit: Int = 0
			        @State private var anonymousInboxReachedEnd: Bool = false
			        @State private var lastMembersRefreshAt: Date = .distantPast
	                    @State private var manualRefreshCooldowns: [String: Date] = [:]
			        
		                    private var pillActiveBackground: Color {
		                        colorScheme == .dark ? .white.opacity(0.92) : .black.opacity(0.88)
		                    }
		                    private var pillActiveForeground: Color {
		                        colorScheme == .dark ? .black.opacity(0.92) : .white.opacity(0.96)
		                    }
	                    private var pillInactiveForeground: Color { Color.primary.opacity(0.72) }
	                    private var iconMuted: Color { Color.primary.opacity(0.72) }
		                    private var iconSubtle: Color { Color.primary.opacity(0.55) }
		                    private var uiStroke: Color { GlassStyle.stroke }
		                    private var uiDividerFill: Color { Color.primary.opacity(0.06) }

		                    private struct PendingDoodleSend: Identifiable {
		                        let id = UUID()
		                        let image: UIImage
		                    }

				    var body: some View {
	            ZStack {
	                dashboardBackground
	                dashboardContent
	            }
	            .overlay {
	                if showingLevelUp {
	                    LevelUpPopup(language: selectedLanguage, level: levelUpLevel) {
	                        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
	                            showingLevelUp = false
	                        }
	                    }
	                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
	                    .zIndex(999)
	                }
	            }
	            .overlayPreferenceValue(DashboardTutorialAnchorsKey.self) { anchors in
	                if showingDashboardTutorial {
	                    DashboardTutorialOverlay(
	                        language: selectedLanguage,
                        anchors: anchors,
                        stepIndex: $dashboardTutorialStepIndex,
                        onSkip: { finishDashboardTutorial() },
                        onFinish: { finishDashboardTutorial() }
                    )
                }
            }
            .alert(reviewTitle, isPresented: $showingReviewPrompt) {
                Button(reviewYesTitle) {
                    ReviewPrompter.requestReview()
                }
                Button(reviewNoTitle, role: .cancel) {
                    ReviewPrompter.markPromptShown()
                }
            } message: {
                Text(reviewMessage)
            }
	        .navigationBarBackButtonHidden(true)
	        .toolbar(.hidden, for: .navigationBar)
		        .onAppear {
		            Haptics.prepare()
		                Task {
		                    await refreshXP()
		                    await pingPresence()
		                    await refreshInbox(force: false)
                            await refreshWidgetLatestFromDirectChats(force: false)
		                }
	                maybeShowDashboardTutorial()
	                ReviewPrompter.registerAppOpen()
	                if ReviewPrompter.shouldShowPrePrompt() {
	                    showingReviewPrompt = true
	                }
		        }
		        .onChange(of: profileId) { _, _ in
		            Task { await refreshXP() }
		        }
            .onChange(of: dashboardTutorialStepIndex) { _, _ in
                guard showingDashboardTutorial else { return }
                applyTutorialTabForStep()
            }
		        .onChange(of: scenePhase) { _, newValue in
		            guard newValue == .active else { return }
			            Task {
			                await purchaseManager.refresh()
			                await refreshXP()
			                await pingPresence()
			                await refreshInbox(force: false)
                            await refreshWidgetLatestFromDirectChats(force: false)
			        }
            ReviewPrompter.registerAppOpen()
            if ReviewPrompter.shouldShowPrePrompt() {
                showingReviewPrompt = true
            }
        }
	            .onReceive(presenceTimer) { _ in
	                guard scenePhase == .active else { return }
	                Task { await pingPresence() }
	            }
                .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
                    guard scenePhase == .active else { return }
                    guard showingMembers else { return }
                    let now = Date()
                    if now.timeIntervalSince(lastMembersRefreshAt) < 30 { return }
                    lastMembersRefreshAt = now
                    Task { await refreshMembers(force: false) }
                }
	            .onReceive(NotificationCenter.default.publisher(for: .doodlInboxShouldRefresh)) { notification in
	                guard scenePhase == .active else { return }
	                let groupCode = (notification.object as? String)?.lowercased()
	                if let groupCode, groupCode != activeGroupCode.lowercased() { return }
                Task { await refreshInbox(force: true) }
            }
		        .onReceive(NotificationCenter.default.publisher(for: .doodlShowPro)) { _ in
		            guard !purchaseManager.isPro else { return }
		            selectTab(.pro)
		        }
			        .onChange(of: selectedTab) { _, newValue in
			            if newValue == .inbox {
			                Haptics.selectionChanged()
			                markInboxAsSeen(groupCode: activeGroupCode)
		                Task { await refreshInbox(force: false) }
		            } else if newValue == .share {
		                Haptics.selectionChanged()
		            } else if newValue == .pro {
		                Haptics.selectionChanged()
		            }
		        }
        .sheet(isPresented: $showingMembers) {
            GroupMembersView(
                language: selectedLanguage,
                ownCode: pairingCode,
                activeCode: activeGroupCode,
                isUsingJoinedGroup: canLeaveGroup,
	                members: members,
	                isLoading: isLoadingMembers,
	                errorMessage: membersError,
                    onRefreshMembers: {
                        runManualRefreshCooldown(
                            key: "members.refresh",
                            onBlocked: { remaining in membersError = refreshCooldownMessage(seconds: remaining) }
                        ) {
                            await refreshMembers(force: true)
                        }
                    },
	                canManageMembers: canManageMembers,
	                canLeaveGroup: canLeaveGroup,
	                currentProfileId: profileId,
                anonymousLinkURL: anonymousLinkCode.flatMap { code in
                    let c = code.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !c.isEmpty else { return nil }
                    return anonymousLinkURL(c)
                },
                isAnonymousEnabled: isAnonymousEnabled,
                isLoadingAnonymousLink: isLoadingAnonymousLink,
                onToggleAnonymousLink: { enabled in
                    Task { await updateAnonymousLinkEnabled(enabled) }
                },
                onRemoveMember: { memberId in
                    Task { await removeMember(memberId) }
                },
                onLeaveGroup: {
                    Task { await leaveCurrentGroup() }
                },
                onJoinGroup: { code in
                    Task { await joinAnotherGroup(code) }
                },
                onInviteUsername: { raw in
                    Task { await inviteUsername(raw) }
                },
                canInvite: canManageMembers,
                invites: invites,
	                isLoadingInvites: isLoadingInvites,
	                invitesError: invitesError,
	                onRefreshInvites: {
                        runManualRefreshCooldown(
                            key: "invites.refresh",
                            onBlocked: { remaining in invitesError = refreshCooldownMessage(seconds: remaining) }
                        ) {
                            await refreshInvites()
                        }
	                },
	                onRespondInvite: { inviteId, accept in
	                    Task {
	                        if let invite = invites.first(where: { $0.id == inviteId }) {
	                            await respondToInvite(invite, accept: accept)
                        }
                    }
                }
            )
            .task {
                await refreshMembers()
                await refreshInvites()
            }
        }
		        .sheet(isPresented: $showingSettings) {
			            NavigationStack {
			                        let _ = Haptics.prepare()
		                ZStack {
			                    ThemedBackground()

			                    ScrollView(showsIndicators: false) {
			                        settingsTabContent
		                            .frame(maxWidth: .infinity, alignment: .center)
	                            .padding(.horizontal, 16)
	                            .padding(.top, 16)
	                            .padding(.bottom, 32)
	                    }
		                }
				                .navigationTitle(tabSettings)
				                .navigationBarTitleDisplayMode(.inline)
				                .toolbarBackground(.hidden, for: .navigationBar)
				                .toolbarColorScheme(colorScheme, for: .navigationBar)
		                        .toolbar {
		                            ToolbarItem(placement: .topBarTrailing) {
		                                Button {
		                                    Haptics.tap()
		                                    showingSettings = false
		                                } label: {
		                                    Image(systemName: "xmark.circle.fill")
		                                        .font(.system(size: 18, weight: .bold))
		                                        .foregroundStyle(iconMuted)
		                                }
		                                .buttonStyle(.plain)
		                                .accessibilityLabel(Text(cancelTitle))
		                            }
		                        }
                        .task {
                            await loadAnonymousLinkStatus()
		                }
			    }
	        }
	        .sheet(isPresented: $showingAnonymousSendFlow, onDismiss: {
	            Task { await refreshXP() }
	        }) {
	            if let pid = profileId {
	                AnonymousSendFlowView(
	                    language: selectedLanguage,
	                    senderProfileId: pid,
	                    senderPairingCode: pairingCode
	                )
                    .environmentObject(purchaseManager)
	            } else {
		                NavigationStack {
			                    ZStack {
			                        ThemedBackground()
			                        ProgressView().tint(Color.primary.opacity(0.65))
			                    }
			                }
			            }
		        }
		        .sheet(isPresented: $showingProPaywall) {
		            ProPaywallView(language: selectedLanguage)
                        .environmentObject(purchaseManager)
		        }
			        .sheet(item: $pendingDoodleSend, onDismiss: { cancelPendingDoodleSendIfNeeded() }) { pending in
			            if let pid = profileId {
			                SendDoodleSheet(
			                    language: selectedLanguage,
			                    profileId: pid,
			                    pairingCode: pairingCode,
			                    image: pending.image,
			                    onComplete: resolvePendingDoodleSend
			                )
			            } else {
			                SendDoodleSheet(
			                    language: selectedLanguage,
			                    profileId: "",
			                    pairingCode: "",
			                    image: pending.image,
			                    onComplete: resolvePendingDoodleSend
			                )
			            }
			        }
	        .sheet(isPresented: $showingAnonymousShareSheet) {
	            if let anonymousShareURL {
	                ActivityView(items: [anonymousShareURL])
		    } else {
	                ActivityView(items: [])
		    }
	        }
	        .sheet(isPresented: $showingRankDetails) {
	            RankDetailsSheet(
	                language: selectedLanguage,
	                xpState: xpState,
	                isLoading: isLoadingXP,
	                onRefresh: { Task { await refreshXP() } }
	            )
	        }
	        .sheet(isPresented: $showingWidgetHelp) {
	            NavigationStack {
	                WidgetHelpView(language: selectedLanguage)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                Haptics.tap()
                                showingWidgetHelp = false
			                        } label: {
			                            Image(systemName: "xmark.circle.fill")
			                                .font(.system(size: 18, weight: .bold))
			                                .foregroundStyle(iconMuted)
			                        }
		                        .buttonStyle(.plain)
		                        .accessibilityLabel(Text(cancelTitle))
		                    }
                    }
            }
        }
	        .onChange(of: avatarPickerItem) { _, newItem in
	            guard let newItem else { return }
	            Task { await updateAvatar(from: newItem) }
	        }
	        .sheet(item: $selectedInboxDoodle) { doodle in
	            InboxDoodleViewer(
	                doodleId: doodle.id,
	                image: cachedDoodleImage(for: doodle),
	                senderUsername: doodle.senderUsername,
	                senderProfileId: doodle.senderProfileId,
	                anonymousSenderFingerprint: nil,
	                language: selectedLanguage,
	                createdAt: doodle.createdAt,
	                onReport: { reasonCode in
	                    Task { await reportGroupDoodle(doodleId: doodle.id, reasonCode: reasonCode) }
	                },
	                onBlock: {
                    Task { await blockGroupSender(senderProfileId: doodle.senderProfileId, lastSeenDoodleId: doodle.id) }
                }
            )
        }
	        .sheet(item: $selectedAnonymousInboxDoodle) { doodle in
	            InboxDoodleViewer(
	                doodleId: doodle.id,
	                image: cachedDoodleImage(for: doodle),
	                senderUsername: anonymousSenderTitle,
	                senderProfileId: nil,
	                anonymousSenderFingerprint: doodle.senderFingerprint,
	                language: selectedLanguage,
	                createdAt: doodle.createdAt,
	                onReport: { reasonCode in
	                    Task { await reportAnonymousDoodle(doodleId: doodle.id, reasonCode: reasonCode) }
	                },
	                onBlock: {
                    guard let fp = doodle.senderFingerprint, !fp.isEmpty else { return }
                    Task { await blockAnonymousSender(senderFingerprint: fp, lastSeenDoodleId: doodle.id) }
                }
            )
        }
        .alert(widgetNudgeTitle, isPresented: $showingWidgetNudge) {
            Button(widgetNudgeShowMe) {
                Haptics.selectionChanged()
                showingWidgetHelp = true
            }
            Button(cancelTitle, role: .cancel) {}
        } message: {
            Text(widgetNudgeMessage)
        }
        .task {
            // One-time nudge so users discover how to add the widget.
            let key = "widget.help.nudgeShown"
            if !UserDefaults.standard.bool(forKey: key) {
                UserDefaults.standard.set(true, forKey: key)
                showingWidgetNudge = true
            }
        }
	        .onReceive(NotificationCenter.default.publisher(for: .apnsTokenDidUpdate)) { notification in
	            guard let token = notification.object as? String else { return }
	            Task { await syncApnsTokenIfPossible(tokenOverride: token) }
	        }
	        .onChange(of: profileId) { _, _ in
	            Task { await syncApnsTokenIfPossible(tokenOverride: nil) }
	        }
		        .onAppear {
		            if path.last != .dashboard {
		                path = [.dashboard]
		            }
		            loadJoinedGroupsFromStorage()
		            Task { await syncApnsTokenIfPossible(tokenOverride: nil) }
		        }
			    }

	    private var dashboardBackground: some View {
	            ThemedBackground()
	        }

	        private var dashboardContent: some View {
		            VStack(spacing: 0) {
		                header
		                    .padding(.top, 4)
		                    .padding(.horizontal, 16)
		                    .padding(.bottom, 6)

	                tabContent
	                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
	                    .padding(.horizontal, 16)
	                    .padding(.top, 8)
	            }
	            .safeAreaInset(edge: .bottom) {
	                VStack(spacing: 8) {
	                    if !purchaseManager.isPro, !AdMobConfig.bannerUnitId.isEmpty {
	                        AdMobBannerView(adUnitId: AdMobConfig.bannerUnitId)
	                            .frame(maxWidth: .infinity)
	                    }
	                    snapTabBar
	                }
	                .padding(.horizontal, 16)
	                .padding(.bottom, 8)
	            }
	            .ignoresSafeArea(.keyboard, edges: .bottom)
	        }

		    @MainActor
			    private func syncApnsTokenIfPossible(tokenOverride: String?) async {
			        guard let pid = profileId else { return }
			        let token = (tokenOverride ?? PushNotifications.cachedToken)?.trimmingCharacters(in: .whitespacesAndNewlines)
			        guard let token, !token.isEmpty else { return }
		        if lastPushedApnsToken == token { return }
		        do {
		            try await SupabaseService.shared.upsertApnsDeviceToken(
		                profileId: pid,
		                profilePairingCode: pairingCode,
		                token: token,
		                environment: PushEnvironment.current
		            )
		            lastPushedApnsToken = token
		        } catch {
	            errorMessage = UserFacingError.message(for: error, language: selectedLanguage)
	        }
	    }

						    private var header: some View {
						        ZStack {
						            HStack(spacing: 10) {
						                settingsButton
						                Spacer()
						                xpBadge
						            }
						            .frame(height: 44)

							            Image("logo")
							                .resizable()
							                .scaledToFit()
							                .frame(height: 90)
							                .shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 12)
							                .offset(y: -8)
							                .allowsHitTesting(false)
						        }
						    }

		    private var headerTitle: String {
		        switch selectedTab {
		        case .share:
		            switch selectedLanguage {
		            case .english: "doodle"
		            case .dutch: "doodle"
		            case .german: "doodle"
		            case .spanish: "doodle"
		            }
		        case .inbox:
		            switch selectedLanguage {
		            case .english: "chat"
		            case .dutch: "chat"
		            case .german: "chat"
		            case .spanish: "chat"
		            }
		        case .pro:
		            switch selectedLanguage {
		            case .english: "pro"
		            case .dutch: "pro"
		            case .german: "pro"
		            case .spanish: "pro"
		            }
		        }
		    }

					        private var snapTabBar: some View {
					            let inboxAccent = Color(hex: colorScheme == .dark ? "0A84FF" : "007AFF")
					            let proAccent = Color(hex: "D4AF37")

				            let barHeight: CGFloat = 58
				            let centerSize: CGFloat = 64
				            let centerLift: CGFloat = 18

					            return ZStack {
					                Capsule(style: .continuous)
					                    .fill(.ultraThinMaterial)
				                    .overlay(
				                        Capsule(style: .continuous)
				                            .fill(
				                                LinearGradient(
				                                    colors: [
				                                        .white.opacity(0.55),
				                                        .white.opacity(0.10),
				                                        .white.opacity(0.02)
				                                    ],
				                                    startPoint: .top,
				                                    endPoint: .bottom
				                                )
				                            )
				                            .blendMode(.overlay)
				                            .opacity(0.9)
				                    )
					                    .overlay(
					                        Capsule(style: .continuous)
					                            .stroke(Color.primary.opacity(0.12), lineWidth: 1)
					                    )
					                    .shadow(color: .black.opacity(0.10), radius: 18, x: 0, y: 12)

				                HStack(spacing: 0) {
				                    snapIconTab(
				                        symbol: "tray.fill",
				                        isActive: selectedTab == .inbox,
				                        accent: inboxAccent,
				                        badgeText: inboxBadgeText,
				                        accessibility: tabInbox
				                    ) {
				                        selectTab(.inbox)
				                    }

				                    Spacer(minLength: 0)

				                    Color.clear
				                        .frame(width: centerSize, height: centerSize)

				                    Spacer(minLength: 0)

				                    snapIconTab(
				                        symbol: "crown.fill",
				                        isActive: selectedTab == .pro,
				                        accent: proAccent,
				                        badgeText: nil,
				                        accessibility: tabPro
				                    ) {
				                        selectTab(.pro)
				                    }
				                }
				                .padding(.horizontal, 18)

					                Button {
					                    selectTab(.share)
					                } label: {
					                    ZStack {
					                        Circle()
					                            .fill(selectedTab == .share ? Color(hex: "FFFC00").opacity(0.98) : Color(.systemBackground).opacity(0.96))
					                            .shadow(color: .black.opacity(0.16), radius: 18, x: 0, y: 14)
					                        Circle()
					                            .stroke(Color.primary.opacity(selectedTab == .share ? 0.18 : 0.12), lineWidth: selectedTab == .share ? 2 : 1)
					                        Image(systemName: "pencil.tip")
					                            .font(.system(size: 19, weight: .heavy))
					                            .foregroundStyle(selectedTab == .share ? .black.opacity(0.92) : Color.primary.opacity(0.85))
					                    }
					                    .frame(width: centerSize, height: centerSize)
					                    .scaleEffect(selectedTab == .share ? 1.02 : 1)
				                    .animation(.spring(response: 0.32, dampingFraction: 0.85), value: selectedTab == .share)
				                }
				                .buttonStyle(.plain)
				                .accessibilityLabel(Text(tabShare))
				                .offset(y: -centerLift)
				            }
				            .frame(height: barHeight)
				            .dashboardTutorialAnchor(.headerTabs)
				        }

				        private func snapIconTab(
				            symbol: String,
				            isActive: Bool,
				            accent: Color,
		            badgeText: String?,
		            accessibility: String,
					            action: @escaping () -> Void
					        ) -> some View {
					            Button(action: action) {
					                let inactiveFill = Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.04)
					                let inactiveStroke = Color.primary.opacity(colorScheme == .dark ? 0.20 : 0.10)
					                ZStack {
					                    Circle()
					                        .fill(isActive ? accent.opacity(0.14) : inactiveFill)
					                        .overlay(
					                            Circle().stroke(isActive ? accent.opacity(0.32) : inactiveStroke, lineWidth: isActive ? 1.5 : 1)
					                        )
					                        .frame(width: 44, height: 44)

				                    Image(systemName: symbol)
				                        .font(.system(size: 16, weight: .bold))
				                        .foregroundStyle(isActive ? accent : pillInactiveForeground)
				                        .frame(width: 44, height: 44, alignment: .center)
				                }
				                .scaleEffect(isActive ? 1.03 : 1)
				                .animation(.spring(response: 0.32, dampingFraction: 0.90), value: isActive)
				                .overlay(alignment: .topTrailing) {
				                    if let badgeText, !badgeText.isEmpty {
				                        Text(badgeText)
		                            .font(.system(size: 10, weight: .heavy, design: .rounded))
		                            .foregroundStyle(.white)
		                            .padding(.vertical, 2)
	                            .padding(.horizontal, 5)
	                            .background(Color.red, in: Capsule(style: .continuous))
	                            .overlay(
	                                Capsule(style: .continuous)
	                                    .stroke(.white.opacity(0.65), lineWidth: 1)
	                            )
	                            .offset(x: 10, y: -10)
	                    }
	                }
	            }
	            .buttonStyle(.plain)
	            .accessibilityLabel(Text(accessibility))
	        }

	        private func selectTab(_ tab: DashboardTab) {
	            Haptics.selectionChanged()
	            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
	                selectedTab = tab
	            }
	        }

	        private func sendDoodleFromCanvas(_ image: UIImage) async throws {
	            guard profileId != nil else { throw SupabaseServiceError.apiError("profile not ready") }
	            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
	                Task { @MainActor in
	                    pendingDoodleSendContinuation = continuation
	                    pendingDoodleSend = PendingDoodleSend(image: image)
	                }
	            }
	        }

	        @MainActor
	        private func resolvePendingDoodleSend(_ result: Result<Void, Error>) {
	            guard let continuation = pendingDoodleSendContinuation else { return }
	            pendingDoodleSendContinuation = nil
	            pendingDoodleSend = nil
	            switch result {
	            case .success:
	                continuation.resume()
	            case .failure(let error):
	                continuation.resume(throwing: error)
	            }
	        }

	        @MainActor
	        private func cancelPendingDoodleSendIfNeeded() {
	            if pendingDoodleSendContinuation != nil {
	                resolvePendingDoodleSend(.failure(CancellationError()))
	            }
	        }

	    private var groupSwitcherPill: some View {
		        Button {
		            Haptics.tap(.light)
	            groupPickerError = nil
	            groupPickerSuccess = nil
	            groupPickerJoinCode = ""
	            showingGroupPicker = true
			        } label: {
			            HStack(spacing: 10) {
			                Image(systemName: "person.3.fill")
			                    .font(.system(size: 12, weight: .bold))
			                    .foregroundStyle(iconMuted)
			                Text(activeGroupCode.uppercased())
			                    .font(.system(size: 13, weight: .heavy, design: .rounded))
			                    .foregroundStyle(Color.primary.opacity(0.92))
			                    .lineLimit(1)
			                Image(systemName: "chevron.down")
			                    .font(.system(size: 12, weight: .bold))
			                    .foregroundStyle(iconSubtle)
			            }
				            .padding(.vertical, 9)
				            .padding(.horizontal, 12)
				            .glassCapsule()
			        }
		        .buttonStyle(.plain)
            .dashboardTutorialAnchor(.groupSwitcherPill)
		        .sheet(isPresented: $showingGroupPicker) {
			            NavigationStack {
			                ZStack {
			                    ThemedBackground()

			                    ScrollView(showsIndicators: false) {
				                        VStack(alignment: .leading, spacing: 14) {
				                        VStack(alignment: .leading, spacing: 8) {
			                            Text(groupPickerTitle)
			                                .font(.system(size: 20, weight: .heavy, design: .rounded))
			                                .foregroundStyle(.primary.opacity(0.92))
			                            Text(groupPickerSubtitle)
			                                .font(.system(size: 13, weight: .semibold, design: .rounded))
			                                .foregroundStyle(.secondary.opacity(0.85))
			                        }

		                        VStack(alignment: .leading, spacing: 10) {
			                            Text(groupsSectionTitle)
			                                .font(.system(size: 13, weight: .heavy, design: .rounded))
			                                .foregroundStyle(.secondary.opacity(0.85))

		                        groupPickerRow(
		                            title: yourGroupTitle,
		                            subtitle: yourGroupSubtitle,
		                            code: pairingCode,
		                            isSelected: activeGroupCode == pairingCode.lowercased(),
		                            canLeave: false
		                        ) {
		                            Task { await switchActiveGroup(to: pairingCode) }
		                        }

		                        ForEach(joinedGroups, id: \.self) { code in
		                            groupPickerRow(
		                                title: otherGroupTitle,
		                                subtitle: otherGroupSubtitle,
		                                code: code,
		                                isSelected: activeGroupCode == code.lowercased(),
		                                canLeave: true
		                            ) {
		                                Task { await switchActiveGroup(to: code) }
		                            } onLeave: {
		                                Task { await leaveGroupFromPicker(code) }
		                            }
		                        }
		                    }

		                        VStack(alignment: .leading, spacing: 10) {
			                            Text(addGroupSectionTitle)
			                                .font(.system(size: 13, weight: .heavy, design: .rounded))
			                                .foregroundStyle(.secondary.opacity(0.85))

		                            HStack(spacing: 10) {
				                                TextField(
				                                    "",
				                                    text: $groupPickerJoinCode,
				                                    prompt: Text(groupPickerJoinPlaceholder).foregroundStyle(.secondary.opacity(0.65))
				                                )
		                                    .textInputAutocapitalization(.never)
		                                    .autocorrectionDisabled(true)
		                                    .keyboardType(.asciiCapable)
				                                    .font(.system(size: 15, weight: .heavy, design: .rounded))
				                                    .foregroundStyle(.primary.opacity(0.92))
				                                    .tint(Color.primary.opacity(0.9))
				                                    .padding(.vertical, 12)
				                                    .padding(.horizontal, 12)
				                                    .background(uiDividerFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
				                                    .overlay(
				                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
				                                            .stroke(uiStroke, lineWidth: 1)
				                                    )

			                                Button(groupPickerJoinButtonTitle) {
			                                    Task { await joinGroupFromPicker() }
			                                }
				                                .buttonStyle(.borderedProminent)
				                                .tint(pillActiveBackground)
				                                .foregroundStyle(pillActiveForeground)
				                                .disabled(isMutatingGroups)
		                            }

	                            Button {
	                                Task { await createNewGroupFromPicker() }
				                            } label: {
				                                HStack(spacing: 10) {
				                                    Image(systemName: "plus.circle.fill")
				                                    Text(groupPickerCreateButtonTitle)
				                                        .font(.system(size: 15, weight: .heavy, design: .rounded))
				                                    Spacer()
				                                }
				                                .padding(.vertical, 2)
				                            }
				                            .buttonStyle(.bordered)
				                            .tint(Color.primary.opacity(0.12))
				                            .foregroundStyle(Color.primary.opacity(0.92))
				                            .disabled(isMutatingGroups)

			                            if let groupPickerSuccess, !groupPickerSuccess.isEmpty {
			                                Text(groupPickerSuccess)
			                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
			                                    .foregroundStyle(Color.primary.opacity(0.92))
		                                    .padding(.vertical, 10)
		                                    .padding(.horizontal, 12)
		                                    .frame(maxWidth: .infinity, alignment: .leading)
			                                    .background(.green.opacity(0.18), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
			                            }

			                            if let groupPickerError, !groupPickerError.isEmpty {
			                                Text(groupPickerError)
			                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
			                                    .foregroundStyle(Color.primary.opacity(0.92))
		                                    .padding(.vertical, 10)
		                                    .padding(.horizontal, 12)
		                                    .frame(maxWidth: .infinity, alignment: .leading)
			                                    .background(.red.opacity(0.16), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
			                            }
	                        }

		                        Spacer(minLength: 0)
		                    }
		                    .padding(16)
		                    }
		                }
				                .navigationTitle(groupPickerNavTitle)
				                .navigationBarTitleDisplayMode(.inline)
				                .toolbarBackground(.hidden, for: .navigationBar)
				                .toolbarColorScheme(colorScheme, for: .navigationBar)
			                .task {
			                    await refreshGroupCountsIfPossible()
			                }
				                .toolbar {
				                    ToolbarItem(placement: .cancellationAction) {
				                        Button(cancelTitle) {
				                            Haptics.tap()
				                            showingGroupPicker = false
				                        }
				                        .foregroundStyle(Color.primary.opacity(0.82))
				                    }
				                }
		            }
		        }
		    }

		    private var membersButton: some View {
		        Button {
		            Haptics.tap()
		            showingMembers = true
		        } label: {
		            Image(systemName: "person.2.fill")
		                .font(.system(size: 16, weight: .heavy))
		                .foregroundStyle(Color.primary.opacity(0.88))
		                .padding(10)
		                .glassCircle()
		        }
	        .buttonStyle(.plain)
		        .dashboardTutorialAnchor(.membersButton)
		        .accessibilityLabel(membersTitle)
		    }

			    private var settingsButton: some View {
			        Button {
			            Haptics.tap()
			            showingSettings = true
			        } label: {
			            Image(systemName: "gearshape.fill")
			                .font(.system(size: 16, weight: .heavy))
			                .foregroundStyle(Color.primary.opacity(0.88))
			                .padding(10)
			                .glassCircle()
			        }
		        .buttonStyle(.plain)
			        .dashboardTutorialAnchor(.settingsButton)
			        .accessibilityLabel(tabSettings)
			    }

			    private var xpBadge: some View {
			        Button {
			            Haptics.tap(.light)
			            showingRankDetails = true
			        } label: {
			            let displayedLevel: Int? = {
			                guard profileId != nil else { return nil }
			                return xpState?.level ?? 1
			            }()
			            XPBadgeView(
			                level: displayedLevel,
			                progress: xpProgress
			            )
			        }
			        .buttonStyle(.plain)
			        .opacity(isLoadingXP ? 0.75 : 1)
			        .accessibilityLabel(Text(xpAccessibilityTitle))
			    }

		    private var xpProgress: Double {
		        guard let xpState else { return 0 }
		        guard xpState.nextLevelXP > 0 else { return 0 }
		        return Double(xpState.levelXP) / Double(xpState.nextLevelXP)
		    }

		    private var xpAccessibilityTitle: String {
		        guard let xpState else { return "level" }
		        return "level \(xpState.level), \(xpState.levelXP) of \(xpState.nextLevelXP) xp"
		    }

		    private var activeGroupCode: String {
	        let code = (joinedCode?.isEmpty == false ? joinedCode : pairingCode) ?? pairingCode
	        return code.lowercased()
	    }

	    private var canLeaveGroup: Bool {
	        guard let joined = joinedCode, !joined.isEmpty else { return false }
	        return joined.lowercased() != pairingCode.lowercased()
	    }

	    private var canAddAnotherJoinedGroup: Bool {
	        purchaseManager.isPro || joinedGroups.isEmpty
	    }

	    private func normalizeGroupCode(_ raw: String) -> String {
	        raw.trimmingCharacters(in: .whitespacesAndNewlines)
	            .replacingOccurrences(of: " ", with: "")
	            .lowercased()
	    }

	    @MainActor
	    private func loadJoinedGroupsFromStorage() {
	        let stored = OnboardingStorage.loadJoinedCodes()
	        let cleaned = stored
	            .map(normalizeGroupCode)
	            .filter { !$0.isEmpty && $0 != pairingCode.lowercased() }
	        joinedGroups = Array(Set(cleaned)).sorted()
	    }

        @MainActor
        private func removeJoinedGroupLocally(_ code: String) {
            let normalized = normalizeGroupCode(code)
            guard !normalized.isEmpty else { return }
            joinedGroups.removeAll { normalizeGroupCode($0) == normalized }
            persistJoinedGroups()
            if joinedCode?.lowercased() == normalized {
                joinedCode = nil
                OnboardingStorage.clearJoinedCode()
            }
        }

        @MainActor
        private func maybeShowDashboardTutorial() {
            let key = "tutorial.dashboard.v2"
            guard UserDefaults.standard.bool(forKey: key) == false else { return }
            dashboardTutorialStepIndex = 0
            selectedTab = .share
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                    showingDashboardTutorial = true
                }
            }
        }

        @MainActor
        private func finishDashboardTutorial() {
            let key = "tutorial.dashboard.v2"
            UserDefaults.standard.set(true, forKey: key)
            withAnimation(.easeOut(duration: 0.2)) {
                showingDashboardTutorial = false
            }
        }

        @MainActor
        private func applyTutorialTabForStep() {
            // Steps in DashboardTutorialOverlay.swift:
            // 0: bottom tabs (any)
            // 1-2: inbox (friends/groups + add friend)
            // 3-4: share (tools + send)
            // 5: settings (global, but keep in share)
            switch dashboardTutorialStepIndex {
            case 1, 2:
                if selectedTab != .inbox { selectedTab = .inbox }
            case 3, 4, 5:
                if selectedTab != .share { selectedTab = .share }
            default:
                break
            }
        }

	    @MainActor
	    private func persistJoinedGroups() {
	        OnboardingStorage.saveJoinedCodes(joinedGroups)
	    }

	    @MainActor
	    private func switchActiveGroup(to code: String) async {
	        let normalized = normalizeGroupCode(code)
	        if normalized.isEmpty { return }

		        if normalized == pairingCode.lowercased() {
		            joinedCode = nil
		            OnboardingStorage.clearJoinedCode()
		        } else {
		            joinedCode = normalized
		            OnboardingStorage.saveJoinedCode(normalized)
		        }

		        await refreshMembers(force: true)
		        await refreshInbox(force: true)
		    }

	    @MainActor
	    private func joinGroupFromPicker() async {
	        let profileId: String
	        do {
	            profileId = try await resolveProfileId()
	        } catch {
	            groupPickerError = UserFacingError.message(for: error, language: selectedLanguage)
	            return
	        }

	        let entered = normalizeGroupCode(groupPickerJoinCode)
	        guard !entered.isEmpty else { return }
	        if entered == pairingCode.lowercased() {
	            groupPickerError = alreadyInThisGroupTitle
	            return
	        }
	        if joinedGroups.contains(entered) {
	            await switchActiveGroup(to: entered)
	            showingGroupPicker = false
	            return
	        }

		        if !canAddAnotherJoinedGroup {
		            Haptics.warning()
		            requestProPaywall()
		            groupPickerError = proRequiredForGroupsTitle
		            return
		        }

	        if isMutatingGroups { return }
	        isMutatingGroups = true
	        groupPickerError = nil
	        groupPickerSuccess = nil
	        do {
	            try await SupabaseService.shared.joinGroup(pairingCode: entered, profileId: profileId, profilePairingCode: pairingCode)
	            joinedGroups.append(entered)
	            joinedGroups = Array(Set(joinedGroups)).sorted()
	            persistJoinedGroups()
	            await switchActiveGroup(to: entered)
	            groupPickerSuccess = joinedSuccessTitle(entered)
	            await refreshGroupCountsIfPossible()
	        } catch {
	            groupPickerError = UserFacingError.message(for: error, language: selectedLanguage)
	        }
	        isMutatingGroups = false
	    }

	    @MainActor
		    private func createNewGroupFromPicker() async {
		        guard purchaseManager.isPro else {
		            Haptics.warning()
		            requestProPaywall()
		            groupPickerError = proRequiredForGroupsTitle
		            return
		        }

	        let profileId: String
	        do {
	            profileId = try await resolveProfileId()
	        } catch {
	            groupPickerError = UserFacingError.message(for: error, language: selectedLanguage)
	            return
	        }

	        if isMutatingGroups { return }
	        isMutatingGroups = true
	        groupPickerError = nil
	        groupPickerSuccess = nil
	        do {
	            var newCode: String?
	            for _ in 0..<8 {
	                let candidate = normalizeGroupCode(PairingCodeGenerator.generate())
	                if candidate.isEmpty { continue }
	                if candidate == pairingCode.lowercased() { continue }
	                if joinedGroups.contains(candidate) { continue }
	                newCode = candidate
	                break
	            }
	            guard let code = newCode else {
	                groupPickerError = "failed to generate code"
	                isMutatingGroups = false
	                return
	            }

	            try await SupabaseService.shared.ensureGroup(pairingCode: code, profileId: profileId, profilePairingCode: pairingCode)
	            joinedGroups.append(code)
	            joinedGroups = Array(Set(joinedGroups)).sorted()
	            persistJoinedGroups()
	            await switchActiveGroup(to: code)
	            groupPickerSuccess = createdSuccessTitle(code)
	            await refreshGroupCountsIfPossible()
	        } catch {
	            groupPickerError = UserFacingError.message(for: error, language: selectedLanguage)
	        }
	        isMutatingGroups = false
	    }

	    @MainActor
	    private func leaveGroupFromPicker(_ code: String) async {
	        let profileId: String
	        do {
	            profileId = try await resolveProfileId()
	        } catch {
	            groupPickerError = UserFacingError.message(for: error, language: selectedLanguage)
	            return
	        }

	        let leaving = normalizeGroupCode(code)
	        guard !leaving.isEmpty else { return }

	        if isMutatingGroups { return }
	        isMutatingGroups = true
	        groupPickerError = nil
	        groupPickerSuccess = nil
	        do {
	            try await SupabaseService.shared.leaveGroup(pairingCode: leaving, profileId: profileId, profilePairingCode: pairingCode)
	            removeJoinedGroupLocally(leaving)

	            if activeGroupCode.lowercased() == leaving {
	                await switchActiveGroup(to: pairingCode)
	            } else {
	                await refreshMembers(force: true)
	                await refreshInbox(force: true)
	            }

	            groupPickerSuccess = leftSuccessTitle(leaving)
	            await refreshGroupCountsIfPossible()
	        } catch {
                if let supa = error as? SupabaseServiceError, case .invalidCode = supa {
                    // Orphaned group (e.g. owner deleted). Remove locally so the user isn't stuck.
                    removeJoinedGroupLocally(leaving)
                    if activeGroupCode.lowercased() == leaving {
                        await switchActiveGroup(to: pairingCode)
                    }
                    groupPickerSuccess = leftSuccessTitle(leaving)
                    await refreshGroupCountsIfPossible()
                } else {
                    groupPickerError = UserFacingError.message(for: error, language: selectedLanguage)
                }
	        }
	        isMutatingGroups = false
	    }

	    @MainActor
	    private func refreshGroupCountsIfPossible() async {
	        guard let profileId, !profileId.isEmpty else { return }
	        if isLoadingGroupCounts { return }
	        isLoadingGroupCounts = true
	        defer { isLoadingGroupCounts = false }

	        let codes = [pairingCode] + joinedGroups
	        do {
	            groupMemberCounts = try await SupabaseService.shared.fetchGroupMemberCounts(
	                groupCodes: codes,
	                requesterProfileId: profileId
	            )
	        } catch {
	            // Non-blocking; the picker still works without counts.
	        }
	    }

	    @MainActor
	    private func resolveProfileId() async throws -> String {
	        if let existing = profileId, !existing.isEmpty {
	            return existing
	        }
	        if let recovered = try await SupabaseService.shared.fetchProfileId(username: username, pairingCode: pairingCode) {
	            profileId = recovered
	            OnboardingStorage.saveProfileId(recovered)
	            return recovered
	        }
	        throw SupabaseServiceError.apiError("profile not found")
	    }

		    private var canManageMembers: Bool {
		        guard let profileId else { return false }
		        return groupOwnerProfileId == profileId && !activeGroupCode.isEmpty
		    }

	    @MainActor
    private func refreshMembers(force: Bool = false, codeOverride: String? = nil) async {
        if isLoadingMembers, !force { return }
        let requestId = UUID()
        membersRequestId = requestId

        isLoadingMembers = true
        membersError = nil

	        let code = ((codeOverride?.isEmpty == false ? codeOverride : activeGroupCode) ?? activeGroupCode).lowercased()
	        do {
                let ownerId: String?
                if let cached = groupOwnerProfileId, !cached.isEmpty, code == activeGroupCode.lowercased() {
                    ownerId = cached
                } else {
                    ownerId = try await SupabaseService.shared.fetchGroupOwnerProfileId(pairingCode: code)
                }
	            let requesterId: String
	            if let existing = profileId {
	                requesterId = existing
	            } else if let recovered = try await SupabaseService.shared.fetchProfileId(username: username, pairingCode: pairingCode) {
	                profileId = recovered
	                OnboardingStorage.saveProfileId(recovered)
	                requesterId = recovered
	            } else {
	                throw SupabaseServiceError.apiError("profile not found")
	            }

	            let fetched = try await SupabaseService.shared.fetchGroupMembers(pairingCode: code, requesterProfileId: requesterId)
	                guard membersRequestId == requestId else { return }
	                groupOwnerProfileId = ownerId
	                members = fetched
	            guard membersRequestId == requestId else { return }
	        } catch {
	            guard membersRequestId == requestId else { return }
	            if let supa = error as? SupabaseServiceError, canLeaveGroup, code == activeGroupCode, case .notMember = supa {
                    removeJoinedGroupLocally(code)
	                await refreshMembers(force: true, codeOverride: pairingCode)
	                return
	            }
	            if let supa = error as? SupabaseServiceError, canLeaveGroup, code == activeGroupCode, case .invalidCode = supa {
                    removeJoinedGroupLocally(code)
	                await refreshMembers(force: true, codeOverride: pairingCode)
	                return
	            }
	            membersError = UserFacingError.message(for: error, language: selectedLanguage)
	        }

	        guard membersRequestId == requestId else { return }
	        isLoadingMembers = false
	    }

		    @MainActor
		    private func refreshXP() async {
		        guard let profileId, !profileId.isEmpty else { return }
		        if isLoadingXP { return }
		        isLoadingXP = true
		        defer { isLoadingXP = false }
		        do {
		            let previousLevel = xpState?.level ?? lastKnownLevel
		            let updated = try await SupabaseService.shared.fetchProfileXP(profileId: profileId, pairingCode: pairingCode)
		            xpState = updated
		            lastKnownLevel = updated.level
		            if let previousLevel, updated.level > previousLevel {
		                presentLevelUp(level: updated.level)
		            }
		        } catch {
		            // XP is best-effort; ignore.
		        }
		    }

			    private func presentLevelUp(level: Int) {
			        levelUpLevel = level
			        if showingLevelUp { return }
			        Haptics.success()
			        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
			            showingLevelUp = true
			        }
			    }

			    @MainActor
			    private func requestProPaywall() {
			        if showingProPaywall || pendingProPaywall { return }

				        let hasBlockingModal =
				            showingSettings ||
				            showingMembers ||
				            showingGroupPicker ||
				            showingWidgetHelp ||
				            showingAnonymousSendFlow ||
			            showingAnonymousShareSheet ||
			            selectedInboxDoodle != nil ||
			            selectedAnonymousInboxDoodle != nil

				        if hasBlockingModal {
				            pendingProPaywall = true
				            showingSettings = false
				            showingMembers = false
				            showingGroupPicker = false
				            showingWidgetHelp = false
				            showingAnonymousSendFlow = false
			            showingAnonymousShareSheet = false
			            selectedInboxDoodle = nil
			            selectedAnonymousInboxDoodle = nil

			            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
			                showingProPaywall = true
			                pendingProPaywall = false
			            }
			            return
			        }

			        showingProPaywall = true
			    }

			    @MainActor
				    private func pingPresence() async {
				        guard let profileId, !profileId.isEmpty else { return }
				        do {
				            try await SupabaseService.shared.updatePresence(profileId: profileId, profilePairingCode: pairingCode)
			        } catch {
			            // Presence is best-effort; ignore.
			        }
			    }

		    @MainActor
					    private func refreshInbox(force: Bool, codeOverride: String? = nil, desiredLimit: Int? = nil) async {
	                    let now = Date()
	                    if !force, now.timeIntervalSince(lastInboxRefreshAt) < 60 {
	                        return
	                    }
	                    lastInboxRefreshAt = now
                    inboxRefreshTask?.cancel()
                    inboxRefreshTask = Task { await refreshInboxImpl(force: force, codeOverride: codeOverride, desiredLimit: desiredLimit) }
                    await inboxRefreshTask?.value
                }

	        @MainActor
        private func refreshInboxImpl(force: Bool, codeOverride: String? = nil, desiredLimit: Int? = nil) async {
            if isLoadingInbox, !force { return }
			        let requesterId: String
			        do {
			            requesterId = try await resolveProfileId()
			        } catch {
			            inboxError = UserFacingError.message(for: error, language: selectedLanguage)
			            return
			        }
			        isLoadingInbox = true
			        inboxError = nil
			        let code = ((codeOverride?.isEmpty == false ? codeOverride : activeGroupCode) ?? activeGroupCode).lowercased()
			        do {
                    if inboxRequestedLimit <= 0 { inboxRequestedLimit = inboxItemsPerPage }
                    if lastInboxCode != code {
                        lastInboxCode = code
                        inboxRequestedLimit = inboxItemsPerPage
                        inboxReachedEnd = false
                        inboxPageIndex = 0
                    }

                    let requiredForPage = inboxItemsPerPage * max(1, (inboxPageIndex + 1))
                    let requested = max(inboxRequestedLimit, desiredLimit ?? requiredForPage)
                    // Server-side retention is capped; keep client aligned to avoid extra load.
                    let limit = min(18, max(inboxItemsPerPage, requested))

                    // Fetch metadata first to avoid statement timeouts on large base64 payloads.
                    do {
                        inboxDoodles = try await SupabaseService.shared.fetchInboxDoodleMetas(groupCode: code, requesterProfileId: requesterId, limit: limit)
                    } catch let error as SupabaseServiceError {
                        if case .apiError(let message) = error,
                           message.localizedCaseInsensitiveContains("inbox_doodle_metas_secure")
                            && (message.localizedCaseInsensitiveContains("does not exist") || message.localizedCaseInsensitiveContains("not found")) {
                            // Backward-compatible fallback only if the RPC is missing.
                            inboxDoodles = try await SupabaseService.shared.fetchInboxDoodles(groupCode: code, requesterProfileId: requesterId, limit: limit)
                        } else {
                            throw error
                        }
                    }
                    inboxRequestedLimit = limit
                    // If the backend returns fewer than requested, we reached the end.
                    inboxReachedEnd = inboxDoodles.count < limit

                    // Hydrate base64 only for the currently visible page (keeps payload small).
                    await hydrateInboxContentsIfNeeded(groupCode: code, requesterProfileId: requesterId, pageIndex: inboxPageIndex)
                    clampInboxPageIndex()
                    if selectedTab == .inbox {
                        markInboxAsSeen(groupCode: code)
                    }
		            if let latest = inboxDoodles.first(where: { $0.senderUsername.lowercased() != username.lowercased() }) {
                        var content = latest.contentBase64
                        if content == nil {
                            content = try? await fetchSingleInboxContent(
                                groupCode: code,
                                requesterProfileId: requesterId,
                                doodleId: latest.id
                            )
                        }
                        if let content {
			                SharedWidgetStore.upsertLatestDoodle(
			                    SharedWidgetDoodle(
			                        doodleId: latest.id,
			                        senderUsername: latest.senderUsername,
			                        contentBase64: content,
			                        createdAt: latest.createdAt ?? Date()
			                    )
			                )
                        }
		            }
				        } catch {
		                    if let supa = error as? SupabaseServiceError, canLeaveGroup, code == activeGroupCode {
		                        switch supa {
		                        case .invalidCode, .notMember:
                                    removeJoinedGroupLocally(code)
		                            await refreshInbox(force: true, codeOverride: pairingCode)
		                            await refreshMembers(force: true, codeOverride: pairingCode)
		                            isLoadingInbox = false
		                            return
	                        default:
	                            break
	                        }
	                    }
			            inboxError = UserFacingError.message(for: error, language: selectedLanguage)
			        }
		        isLoadingInbox = false
		    }

        @MainActor
        private func refreshWidgetLatestFromDirectChats(force: Bool) async {
            guard let profileId, !profileId.isEmpty else { return }
            guard SharedWidgetStore.isAllSources(SharedWidgetStore.effectiveWidgetSourceCode()) else { return }

            let now = Date()
            if !force, now.timeIntervalSince(lastWidgetRefreshAt) < 12 {
                return
            }
            lastWidgetRefreshAt = now

            let threads: [DirectChatThread]
            do {
                threads = try await SupabaseService.shared.listDirectChats(
                    profileId: profileId,
                    profilePairingCode: pairingCode,
                    limit: 40
                )
            } catch {
                return
            }

            // Keep a best-effort list of widget sources for "all sources" push resolution.
            let existing = SharedWidgetStore.loadWidgetSources()
            let codes = threads.map(\.code) + [pairingCode]
            SharedWidgetStore.saveWidgetSources(existing + codes)

            let bestThread = threads
                .filter { $0.lastCreatedAt != nil }
                .max { ($0.lastCreatedAt ?? .distantPast) < ($1.lastCreatedAt ?? .distantPast) }
            guard let bestThread else { return }

            let widgetAt = SharedWidgetStore.loadLatestDoodle()?.createdAt ?? .distantPast
            if let lastAt = bestThread.lastCreatedAt, lastAt <= widgetAt {
                return
            }

            let code = bestThread.code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let metas: [InboxDoodle]
            do {
                metas = try await SupabaseService.shared.fetchInboxDoodleMetas(
                    groupCode: code,
                    requesterProfileId: profileId,
                    limit: 6
                )
            } catch {
                return
            }

            let my = username.lowercased()
            guard let meta = metas.first(where: { $0.senderUsername.lowercased() != my }) else { return }

            let fetched = try? await SupabaseService.shared.fetchDoodleContents(
                groupCode: code,
                requesterProfileId: profileId,
                doodleIds: [meta.id]
            )
            guard let content = fetched?[meta.id] else { return }

            SharedWidgetStore.upsertLatestDoodle(
                SharedWidgetDoodle(
                    doodleId: meta.id,
                    senderUsername: meta.senderUsername,
                    contentBase64: content,
                    createdAt: meta.createdAt ?? Date()
                )
            )
        }

    @MainActor
	    private func loadAnonymousLinkStatus() async {
	        guard let profileId, !profileId.isEmpty else { return }
	        if isLoadingAnonymousLink { return }
	        isLoadingAnonymousLink = true
	        do {
	            let status = try await SupabaseService.shared.getAnonymousLinkStatus(profileId: profileId, profilePairingCode: pairingCode)
	            if status.shortCode == nil {
	                // Self-heal on older DBs: create & enable link so every user can receive anonymously.
	                let created = try await SupabaseService.shared.setAnonymousLinkEnabled(
	                    profileId: profileId,
	                    profilePairingCode: pairingCode,
	                    enabled: true
	                )
	                anonymousLinkCode = created.shortCode
	                isAnonymousEnabled = created.isEnabled
	            } else {
	                anonymousLinkCode = status.shortCode
	                isAnonymousEnabled = status.isEnabled
	            }
	        } catch {
	            // Best-effort; keep UI usable even if this fails.
	        }
	        isLoadingAnonymousLink = false
	    }

	    @MainActor
    private func updateAnonymousLinkEnabled(_ enabled: Bool) async {
	        guard let profileId, !profileId.isEmpty else { return }
	        if isLoadingAnonymousLink { return }
	        isLoadingAnonymousLink = true
	        let previous = isAnonymousEnabled
	        isAnonymousEnabled = enabled
	        do {
	            let status = try await SupabaseService.shared.setAnonymousLinkEnabled(
	                profileId: profileId,
	                profilePairingCode: pairingCode,
	                enabled: enabled
	            )
            anonymousLinkCode = status.shortCode
            isAnonymousEnabled = status.isEnabled
            if status.isEnabled {
                if let code = status.shortCode?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !code.isEmpty,
                   let url = URL(string: anonymousLinkURL(code)) {
                    anonymousShareURL = url
                    showingAnonymousShareSheet = true
                }
                await refreshAnonymousInbox(force: true)
            } else {
                anonymousInboxDoodles = []
            }
	        } catch {
	            errorMessage = UserFacingError.message(for: error, language: selectedLanguage)
	            isAnonymousEnabled = previous
	            // Re-sync UI state from backend.
	            await loadAnonymousLinkStatus()
	        }
	        isLoadingAnonymousLink = false
	    }

	    @MainActor
		    private func refreshAnonymousInbox(force: Bool, desiredLimit: Int? = nil) async {
		        guard isAnonymousEnabled else { return }
		        guard let profileId, !profileId.isEmpty else { return }
	            let now = Date()
	            if !force, now.timeIntervalSince(lastAnonymousInboxRefreshAt) < 60 {
	                return
	            }
	            lastAnonymousInboxRefreshAt = now
	            anonymousInboxRefreshTask?.cancel()
	            anonymousInboxRefreshTask = Task { await refreshAnonymousInboxImpl(force: force, desiredLimit: desiredLimit) }
	            await anonymousInboxRefreshTask?.value
		    }

    @MainActor
	    private func refreshAnonymousInboxImpl(force: Bool, desiredLimit: Int? = nil) async {
	        guard isAnonymousEnabled else { return }
	        guard let profileId, !profileId.isEmpty else { return }
	        if isLoadingAnonymousInbox, !force { return }
	        isLoadingAnonymousInbox = true
        anonymousInboxError = nil
        do {
            if anonymousInboxRequestedLimit <= 0 { anonymousInboxRequestedLimit = inboxItemsPerPage }
            let requiredForPage = inboxItemsPerPage * max(1, (anonymousInboxPageIndex + 1))
            let requested = max(anonymousInboxRequestedLimit, desiredLimit ?? requiredForPage)
            let limit = min(120, max(inboxItemsPerPage, requested))
            anonymousInboxDoodles = try await SupabaseService.shared.fetchAnonymousInboxDoodles(
                profileId: profileId,
                profilePairingCode: pairingCode,
                limit: limit
            )
            anonymousInboxRequestedLimit = limit
            anonymousInboxReachedEnd = anonymousInboxDoodles.count < limit
            clampAnonymousInboxPageIndex()
        } catch {
            anonymousInboxError = UserFacingError.message(for: error, language: selectedLanguage)
        }
	        isLoadingAnonymousInbox = false
	    }

    @MainActor
    private func runManualRefreshCooldown(
        key: String,
        seconds: TimeInterval = 60,
        onBlocked: @escaping (Int) -> Void,
        action: @escaping () async -> Void
    ) {
        let now = Date()
        if let until = manualRefreshCooldowns[key], until > now {
            let remaining = Int(ceil(until.timeIntervalSince(now)))
            onBlocked(max(1, remaining))
            Haptics.warning()
            return
        }

        manualRefreshCooldowns[key] = now.addingTimeInterval(seconds)
        Task { await action() }
    }

	    private func refreshCooldownMessage(seconds: Int) -> String {
	        let s = max(1, seconds)
            return switch selectedLanguage {
            case .english: "wait \(s)s before refreshing again"
            case .dutch: "wacht \(s)s voordat je weer ververst"
            case .german: "warte \(s)s bevor du erneut aktualisierst"
            case .spanish: "espera \(s)s antes de actualizar de nuevo"
            }
	    }

    @MainActor
    private func showInboxNotice(_ message: String) {
        inboxNotice = message
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            if inboxNotice == message { inboxNotice = nil }
        }
    }

    @MainActor
    private func showAnonymousInboxNotice(_ message: String) {
        anonymousInboxNotice = message
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            if anonymousInboxNotice == message { anonymousInboxNotice = nil }
        }
    }

    private func anonymousLinkURL(_ code: String) -> String {
        "https://doodl-me.com/h/\(code.lowercased())"
    }

    @MainActor
	    private func removeMember(_ memberId: String) async {
	        guard canManageMembers else { return }
	        if isMutatingMembers { return }
	        isMutatingMembers = true
	        membersError = nil
	        do {
	            guard let requesterId = profileId else { return }
	            try await SupabaseService.shared.removeMember(
	                pairingCode: activeGroupCode,
	                requesterProfileId: requesterId,
	                requesterPairingCode: pairingCode,
	                memberProfileId: memberId
	            )
	            await refreshMembers(force: true)
	        } catch {
	            membersError = UserFacingError.message(for: error, language: selectedLanguage)
	        }
	        isMutatingMembers = false
	    }

		    @MainActor
			    private func leaveCurrentGroup() async {
			        guard canLeaveGroup else { return }
			        if isMutatingMembers { return }
			        isMutatingMembers = true
			        membersError = nil
			        let leavingCode = activeGroupCode
			        do {
			            let requesterId = try await resolveProfileId()
			            try await SupabaseService.shared.leaveGroup(pairingCode: leavingCode, profileId: requesterId, profilePairingCode: pairingCode)
			            joinedGroups.removeAll { normalizeGroupCode($0) == leavingCode.lowercased() }
			            persistJoinedGroups()
			            joinedCode = nil
			            OnboardingStorage.clearJoinedCode()
			            groupPickerJoinCode = ""
			            await refreshMembers(force: true, codeOverride: pairingCode)
			            await refreshInbox(force: true, codeOverride: pairingCode)
		        } catch {
	            if let supa = error as? SupabaseServiceError, case .invalidCode = supa {
	                joinedGroups.removeAll { normalizeGroupCode($0) == leavingCode.lowercased() }
	                persistJoinedGroups()
	                joinedCode = nil
	                OnboardingStorage.clearJoinedCode()
	                await refreshMembers(force: true, codeOverride: pairingCode)
	                await refreshInbox(force: true, codeOverride: pairingCode)
	            } else {
	                membersError = UserFacingError.message(for: error, language: selectedLanguage)
	            }
	        }
	        isMutatingMembers = false
	    }

		    @MainActor
			    private func joinAnotherGroup(_ code: String) async {
		        let profileId: String
		        do {
		            profileId = try await resolveProfileId()
		        } catch {
		            membersError = UserFacingError.message(for: error, language: selectedLanguage)
		            return
		        }
		        let entered = normalizeGroupCode(code)
		        guard !entered.isEmpty else { return }
		        if entered == pairingCode.lowercased() {
		            membersError = alreadyInThisGroupTitle
	            return
	        }
		        if joinedGroups.contains(entered) {
		            await switchActiveGroup(to: entered)
		            return
		        }
			        if !canAddAnotherJoinedGroup {
			            Haptics.warning()
			            requestProPaywall()
			            membersError = proRequiredForGroupsTitle
			            return
			        }
	        if isMutatingMembers { return }
	        isMutatingMembers = true
	        membersError = nil
		        do {
		            try await SupabaseService.shared.joinGroup(pairingCode: entered, profileId: profileId, profilePairingCode: pairingCode)
		            joinedGroups.append(entered)
		            joinedGroups = Array(Set(joinedGroups)).sorted()
		            persistJoinedGroups()
		            joinedCode = entered
		            OnboardingStorage.saveJoinedCode(entered)
		            await refreshMembers(force: true, codeOverride: entered)
		            await refreshInbox(force: true, codeOverride: entered)
	        } catch {
	            membersError = UserFacingError.message(for: error, language: selectedLanguage)
	        }
	        isMutatingMembers = false
	    }

    @MainActor
    private func inviteUsername(_ raw: String) async {
        guard let profileId else { return }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let username = trimmed.hasPrefix("@") ? String(trimmed.dropFirst()) : trimmed
        guard !username.isEmpty else { return }
        membersError = nil
        do {
            try await SupabaseService.shared.inviteToGroup(
                groupCode: activeGroupCode,
                inviterProfileId: profileId,
                invitedUsername: username.lowercased()
            )
        } catch {
            membersError = UserFacingError.message(for: error, language: selectedLanguage)
        }
    }

	    @ViewBuilder
	    private var tabContent: some View {
	        switch selectedTab {
	        case .share:
	            VStack(spacing: 14) {
	                Text(dashboardSubtitle)
	                    .font(.system(size: 18, weight: .semibold, design: .rounded))
	                    .foregroundStyle(.primary.opacity(0.92))
	                    .multilineTextAlignment(.center)

			                DoodleCanvasView(language: selectedLanguage) { image in
			                    try await sendDoodleFromCanvas(image)
			                    DoodleStore.saveLatest(image)
			                    // Best-effort refreshes; the send already succeeded.
			                    await refreshXP()
			                    await MainActor.run {
			                        chatsRefreshToken = UUID()
			                    }
				                }
		            }
	        case .inbox:
	            inboxView
	        case .pro:
	            proBenefitsView
	        }
	    }

	    private var proBenefitsView: some View {
	        ScrollView(showsIndicators: false) {
	            VStack(spacing: 14) {
	                proHeroCard
	                proBenefitsCard
	                proCTA
	            }
	            .padding(.horizontal, 16)
	            .padding(.top, 10)
	            .padding(.bottom, 24)
	        }
	    }

		    private var proHeroCard: some View {
		        VStack(alignment: .leading, spacing: 12) {
			            HStack(spacing: 12) {
			                ZStack {
			                    Circle().fill(Color.primary.opacity(0.06))
			                    Image(systemName: "crown.fill")
			                        .font(.system(size: 18, weight: .heavy))
			                        .foregroundStyle(Color(hex: "D4AF37").opacity(0.95))
			                }
		                .frame(width: 44, height: 44)

		                VStack(alignment: .leading, spacing: 3) {
		                    Text(proTitle)
		                        .font(.system(size: 20, weight: .heavy, design: .rounded))
		                        .foregroundStyle(.primary.opacity(0.92))
		                    Text(purchaseManager.isPro ? proActiveSubtitle : proSubtitle)
		                        .font(.system(size: 13, weight: .semibold, design: .rounded))
		                        .foregroundStyle(.secondary.opacity(0.85))
		                }

	                Spacer()

		                if purchaseManager.isPro {
		                    Text(proActivePill)
		                        .font(.system(size: 12, weight: .heavy, design: .rounded))
		                        .foregroundStyle(.white)
		                        .padding(.vertical, 7)
		                        .padding(.horizontal, 10)
		                        .background(.black.opacity(0.88), in: Capsule(style: .continuous))
		                }
		            }

		            Text(proPitch)
		                .font(.system(size: 14, weight: .semibold, design: .rounded))
		                .foregroundStyle(.secondary.opacity(0.85))
		                .multilineTextAlignment(.leading)
		        }
		        .padding(.vertical, 14)
		        .padding(.horizontal, 14)
		        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
		        .overlay(
		            RoundedRectangle(cornerRadius: 18, style: .continuous)
		                .stroke(Color.primary.opacity(0.10), lineWidth: 1)
		        )
		    }

		    private var proBenefitsCard: some View {
		        VStack(alignment: .leading, spacing: 12) {
		            Text(proBenefitsTitle)
		                .font(.system(size: 14, weight: .heavy, design: .rounded))
		                .foregroundStyle(.secondary.opacity(0.85))

		            VStack(spacing: 10) {
		                ForEach(proBenefits, id: \.title) { benefit in
		                    HStack(alignment: .top, spacing: 12) {
		                        Image(systemName: benefit.symbol)
		                            .font(.system(size: 14, weight: .bold))
		                            .foregroundStyle(Color.primary.opacity(0.82))
		                            .frame(width: 22)

		                        VStack(alignment: .leading, spacing: 2) {
		                            Text(benefit.title)
		                                .font(.system(size: 15, weight: .heavy, design: .rounded))
		                                .foregroundStyle(.primary.opacity(0.92))
		                            Text(benefit.subtitle)
		                                .font(.system(size: 12, weight: .semibold, design: .rounded))
		                                .foregroundStyle(.secondary.opacity(0.75))
		                        }

	                        Spacer(minLength: 0)
		                    }
		                    .padding(.vertical, 10)
		                    .padding(.horizontal, 12)
		                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
		                    .overlay(
		                        RoundedRectangle(cornerRadius: 16, style: .continuous)
		                            .stroke(Color.primary.opacity(0.10), lineWidth: 1)
		                    )
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

		    private var proCTA: some View {
		        VStack(spacing: 10) {
		            if purchaseManager.isPro {
		                Text(proThanks)
		                    .font(.system(size: 14, weight: .heavy, design: .rounded))
		                    .foregroundStyle(.secondary.opacity(0.85))
		                    .frame(maxWidth: .infinity, alignment: .leading)
		            } else {
	                Button {
	                    Haptics.tap(.medium)
	                    requestProPaywall()
	                } label: {
	                    let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
		                    HStack(spacing: 10) {
		                        Image(systemName: "crown.fill")
		                            .font(.system(size: 15, weight: .heavy))
		                        Text(proUpgradeCTA)
		                            .font(.system(size: 16, weight: .heavy, design: .rounded))
		                            .lineLimit(1)
		                    }
		                    .foregroundStyle(.white.opacity(0.95))
		                    .padding(.vertical, 14)
			                    .padding(.horizontal, 16)
			                    .frame(maxWidth: .infinity)
			                    .background(shape.fill(.black.opacity(0.88)))
			                    .overlay(shape.stroke(.white.opacity(0.14), lineWidth: 1))
			                }
		                .buttonStyle(.plain)
		            }
		        }
		    }

	    private struct ProBenefitRow {
	        let symbol: String
	        let title: String
	        let subtitle: String
	    }

		    private var proBenefits: [ProBenefitRow] {
		        [
                    ProBenefitRow(symbol: "paperplane.fill", title: proUnlimitedTitle, subtitle: proUnlimitedSubtitle),
		            ProBenefitRow(symbol: "sparkles", title: proGlowTitle, subtitle: proGlowSubtitle),
		            ProBenefitRow(symbol: "square.grid.3x3.fill", title: proTemplatesTitle, subtitle: proTemplatesSubtitle),
		            ProBenefitRow(symbol: "person.2.fill", title: proGroupsTitle, subtitle: proGroupsSubtitle),
		            ProBenefitRow(symbol: "heart.fill", title: proSupportTitle, subtitle: proSupportSubtitle)
		        ]
		    }

	    private var proTitle: String {
	        "DOODL. Pro"
	    }

	    private var proSubtitle: String {
	        switch selectedLanguage {
	        case .english: "unlimited doodls + the best doodling tools"
	        case .dutch: "onbeperkt doodls + de beste doodle tools"
	        case .german: "unbegrenzt doodls + die besten doodle-tools"
	        case .spanish: "doodls ilimitados + las mejores herramientas"
	        }
	    }

	    private var proActiveSubtitle: String {
	        switch selectedLanguage {
	        case .english: "you’re pro — enjoy"
	        case .dutch: "je bent pro — enjoy"
	        case .german: "du bist pro — viel spaß"
	        case .spanish: "eres pro — disfruta"
	        }
	    }

	    private var proActivePill: String {
	        switch selectedLanguage {
	        case .english: "active"
	        case .dutch: "actief"
	        case .german: "aktiv"
	        case .spanish: "activo"
	        }
	    }

	    private var proPitch: String {
	        switch selectedLanguage {
	        case .english: "send unlimited doodls (no daily limit), unlock extra tools, and support DOODL. so it stays fast for everyone."
	        case .dutch: "stuur onbeperkt doodls (geen daglimiet), unlock extra tools en steun DOODL. zodat alles snel blijft voor iedereen."
	        case .german: "sende unbegrenzt doodls (kein tageslimit), schalte extras frei und unterstütze DOODL., damit alles schnell bleibt."
	        case .spanish: "envía doodls ilimitados (sin límite diario), desbloquea extras y apoya DOODL. para que siga siendo rápido."
	        }
	    }

        private var proUnlimitedTitle: String {
            switch selectedLanguage {
            case .english: "unlimited doodls"
            case .dutch: "onbeperkt doodls"
            case .german: "unbegrenzt doodls"
            case .spanish: "doodls ilimitados"
            }
        }

        private var proUnlimitedSubtitle: String {
            let freeLimit = DoodleSendQuota.freeDailyLimit
            switch selectedLanguage {
            case .english: return "no daily limit (free: \(freeLimit)/day)"
            case .dutch: return "geen daglimiet (gratis: \(freeLimit)/dag)"
            case .german: return "kein tageslimit (gratis: \(freeLimit)/tag)"
            case .spanish: return "sin límite diario (gratis: \(freeLimit)/día)"
            }
        }

	    private var proBenefitsTitle: String {
	        switch selectedLanguage {
	        case .english: "what you get"
	        case .dutch: "wat je krijgt"
	        case .german: "was du bekommst"
	        case .spanish: "lo que obtienes"
	        }
	    }

	    private var proUpgradeCTA: String {
	        switch selectedLanguage {
	        case .english: "unlock pro"
	        case .dutch: "ontgrendel pro"
	        case .german: "pro freischalten"
	        case .spanish: "desbloquear pro"
	        }
	    }

	    private var proThanks: String {
	        switch selectedLanguage {
	        case .english: "thanks for supporting DOODL."
	        case .dutch: "thanks voor het steunen van DOODL."
	        case .german: "danke fürs unterstützen von DOODL."
	        case .spanish: "gracias por apoyar DOODL."
	        }
	    }

	    private var proGlowTitle: String {
	        switch selectedLanguage {
	        case .english: "glow mode"
	        case .dutch: "glow modus"
	        case .german: "glow-modus"
	        case .spanish: "modo brillo"
	        }
	    }

	    private var proGlowSubtitle: String {
	        switch selectedLanguage {
	        case .english: "neon canvas + glow brush + sliders"
	        case .dutch: "neon canvas + glow brush + sliders"
	        case .german: "neon-leinwand + glow + regler"
	        case .spanish: "lienzo neón + brillo + control"
	        }
	    }

	    private var proThemesTitle: String {
	        switch selectedLanguage {
	        case .english: "themes"
	        case .dutch: "thema’s"
	        case .german: "themes"
	        case .spanish: "temas"
	        }
	    }

	    private var proThemesSubtitle: String {
	        switch selectedLanguage {
	        case .english: "unlock pro palettes in settings"
	        case .dutch: "ontgrendel pro kleuren in settings"
	        case .german: "pro-paletten in den einstellungen"
	        case .spanish: "paletas pro en ajustes"
	        }
	    }

	    private var proTemplatesTitle: String {
	        switch selectedLanguage {
	        case .english: "templates"
	        case .dutch: "templates"
	        case .german: "vorlagen"
	        case .spanish: "plantillas"
	        }
	    }

	    private var proTemplatesSubtitle: String {
	        switch selectedLanguage {
	        case .english: "draw over curated pro guides"
	        case .dutch: "teken over pro gidsen"
	        case .german: "zeichne über pro-vorlagen"
	        case .spanish: "dibuja sobre guías pro"
	        }
	    }

	    private var proGroupsTitle: String {
	        switch selectedLanguage {
	        case .english: "more groups"
	        case .dutch: "meer groepen"
	        case .german: "mehr gruppen"
	        case .spanish: "más grupos"
	        }
	    }

	    private var proGroupsSubtitle: String {
	        switch selectedLanguage {
	        case .english: "join multiple groups"
	        case .dutch: "join meerdere groepen"
	        case .german: "tritt mehreren gruppen bei"
	        case .spanish: "únete a varios grupos"
	        }
	    }

	    private var proSupportTitle: String {
	        switch selectedLanguage {
	        case .english: "support DOODL."
	        case .dutch: "steun DOODL."
	        case .german: "unterstütze DOODL."
	        case .spanish: "apoya DOODL."
	        }
	    }

	    private var proSupportSubtitle: String {
	        switch selectedLanguage {
	        case .english: "helps keep everything fast"
	        case .dutch: "helpt alles snel te houden"
	        case .german: "hilft, alles schnell zu halten"
	        case .spanish: "ayuda a que todo sea rápido"
	        }
	    }

						    private var inboxView: some View {
						        ZStack {
						            Color(.systemBackground).ignoresSafeArea()
						            ScrollView(showsIndicators: false) {
						                VStack(spacing: 14) {
						                    if let pid = profileId, !pid.isEmpty {
						                        DirectChatsPanel(
						                            language: selectedLanguage,
						                            profileId: pid,
						                            pairingCode: pairingCode,
						                            username: username,
						                            refreshToken: chatsRefreshToken,
						                            unreadThreadsCount: $directUnreadThreadsCount
						                        )
						                    } else {
						                        ProgressView().tint(Color.primary.opacity(0.65))
						                    }
						                }
						                .padding(.top, 2)
						                .padding(.bottom, 24)
						            }
						        }
						    }

		                private var anonymousSendCard: some View {
		                    VStack(alignment: .leading, spacing: 10) {
		                        HStack(spacing: 10) {
		                            Image(systemName: "paperplane.fill")
		                                .font(.system(size: 16, weight: .bold))
		                                .foregroundStyle(Color.primary.opacity(0.82))
		                                .frame(width: 22)

	                            VStack(alignment: .leading, spacing: 3) {
		                                Text(anonymousSendTitle)
		                                    .font(.system(size: 14, weight: .heavy, design: .rounded))
		                                    .foregroundStyle(.primary.opacity(0.92))
		                                Text(anonymousSendSubtitle)
		                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
		                                    .foregroundStyle(.secondary.opacity(0.85))
		                                    .fixedSize(horizontal: false, vertical: true)
		                            }

	                            Spacer()
	                        }

	                        Button {
	                            Haptics.tap(.medium)
	                            Task {
	                                do {
	                                    if profileId == nil {
	                                        profileId = try await resolveProfileId()
	                                    }
	                                    showingAnonymousSendFlow = true
	                                } catch {
	                                    errorMessage = UserFacingError.message(for: error, language: selectedLanguage)
	                                }
	                            }
	                        } label: {
	                            HStack(spacing: 10) {
	                                Image(systemName: "sparkles")
	                                    .font(.system(size: 15, weight: .bold))
	                                Text(anonymousSendButtonTitle)
	                                    .font(.system(size: 15, weight: .heavy, design: .rounded))
	                                Spacer()
	                                Image(systemName: "chevron.right")
	                                    .font(.system(size: 13, weight: .bold))
	                            }
		                            .foregroundStyle(.black)
		                            .padding(.vertical, 12)
		                            .padding(.horizontal, 14)
		                            .background(.thinMaterial, in: Capsule(style: .continuous))
		                            .overlay(Capsule(style: .continuous).stroke(.black.opacity(0.10), lineWidth: 1))
		                        }
		                        .buttonStyle(.plain)
		                    }
		                    .padding(14)
		                    .frame(maxWidth: .infinity, alignment: .leading)
		                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
		                    .overlay(
		                        RoundedRectangle(cornerRadius: 22, style: .continuous)
		                            .stroke(Color.primary.opacity(0.10), lineWidth: 1)
		                    )
		                }

		                private var anonymousInboxSetupCard: some View {
		                    VStack(alignment: .leading, spacing: 10) {
		                        HStack(spacing: 10) {
		                            Image(systemName: "sparkles")
		                                .font(.system(size: 16, weight: .bold))
	                                .foregroundStyle(Color.primary.opacity(0.82))
	                                .frame(width: 22)

	                            VStack(alignment: .leading, spacing: 3) {
	                                Text(anonymousIntroTitle)
	                                    .font(.system(size: 14, weight: .heavy, design: .rounded))
	                                    .foregroundStyle(.primary.opacity(0.92))
	                                Text(anonymousIntroSubtitle)
	                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
	                                    .foregroundStyle(.secondary.opacity(0.85))
	                                    .fixedSize(horizontal: false, vertical: true)
	                            }

                            Spacer()
                        }

                        Button {
                            Haptics.tap(.medium)
                            Task { await updateAnonymousLinkEnabled(true) }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "link.badge.plus")
                                    .font(.system(size: 15, weight: .bold))
                                Text(anonymousEnableButtonTitle)
                                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                                Spacer()
                                if isLoadingAnonymousLink {
                                    ProgressView().tint(.black)
                                } else {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .bold))
                                }
                            }
                            .foregroundStyle(.black)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 14)
                            .background(.white.opacity(0.92), in: Capsule(style: .continuous))
                            .shadow(color: .black.opacity(0.14), radius: 10, x: 0, y: 8)
                        }
                        .buttonStyle(.plain)
                        .disabled(isLoadingAnonymousLink)
	                    }
	                    .padding(14)
	                    .frame(maxWidth: .infinity, alignment: .leading)
	                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
	                    .overlay(
	                        RoundedRectangle(cornerRadius: 22, style: .continuous)
	                            .stroke(Color.primary.opacity(0.10), lineWidth: 1)
		                    )
		                }

                private var anonymousInboxEmptyCard: some View {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            Image(systemName: "tray")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Color.primary.opacity(0.82))
                                .frame(width: 22)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(anonymousEmptyTitle)
                                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.primary.opacity(0.92))
                                Text(anonymousEmptySubtitle)
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.secondary.opacity(0.85))
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer()
                        }

                if let code = anonymousLinkCode?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !code.isEmpty {
                    let urlString = anonymousLinkURL(code)
                    Button {
                        Haptics.selectionChanged()
                        UIPasteboard.general.string = urlString
                    } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 15, weight: .bold))
                                    Text(anonymousCopyLinkTitle)
                                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                                    Spacer()
                                    Text(urlString)
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.black.opacity(0.65))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                }
                                .foregroundStyle(.black)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 14)
                                .background(.white.opacity(0.92), in: Capsule(style: .continuous))
                            }
                            .buttonStyle(.plain)

                            Button {
                                Haptics.tap(.medium)
                                if let url = URL(string: urlString) {
                                    anonymousShareURL = url
                                    showingAnonymousShareSheet = true
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 15, weight: .bold))
                                    Text(anonymousShareLinkTitle)
                                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .bold))
                                }
                                .foregroundStyle(.black)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 14)
                                .background(.white.opacity(0.92), in: Capsule(style: .continuous))
                                .shadow(color: .black.opacity(0.14), radius: 10, x: 0, y: 8)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button {
                                Haptics.tap(.medium)
                                Task { await loadAnonymousLinkStatus() }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 15, weight: .bold))
                                    Text(anonymousRefreshLinkTitle)
                                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                                    Spacer()
                                    if isLoadingAnonymousLink {
                                        ProgressView().tint(.black)
                                    } else {
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 13, weight: .bold))
                                    }
                                }
                                .foregroundStyle(.black)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 14)
                                .background(.white.opacity(0.92), in: Capsule(style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .disabled(isLoadingAnonymousLink)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
	                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
	                    .overlay(
	                        RoundedRectangle(cornerRadius: 22, style: .continuous)
	                            .stroke(Color.primary.opacity(0.10), lineWidth: 1)
	                    )
	                }

            private var inboxSourceTabs: some View {
                HStack(spacing: 10) {
                    inboxSourceButton(title: tabInboxChatsTitle, isActive: inboxSource == .chats) {
                        inboxSource = .chats
                    }
                    inboxSourceButton(title: tabInboxGroupTitle, isActive: inboxSource == .group) {
                        inboxSource = .group
                    }
                    inboxSourceButton(title: tabInboxAnonymousTitle, isActive: inboxSource == .anonymous) {
                        inboxSource = .anonymous
                        if isAnonymousEnabled {
                            Task { await refreshAnonymousInbox(force: false) }
                        }
                    }
                }
                .padding(6)
                .background(.thinMaterial, in: Capsule(style: .continuous))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(uiStroke, lineWidth: 1)
                )
            }

    private func inboxSourceButton(title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(isActive ? pillActiveForeground : pillInactiveForeground)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .background(
                        Group {
                            if isActive {
                                Capsule(style: .continuous).fill(pillActiveBackground)
                            } else {
                                Capsule(style: .continuous).fill(.clear)
                            }
                        }
                    )
                }
                .buttonStyle(.plain)
            }

		    private var inboxPagedGrid: some View {
		        let pageSize = inboxItemsPerPage
		        let pages = chunked(inboxDoodles, by: pageSize)
                let pageCount = max(1, pages.count)
                let currentPage = pages[safe: inboxPageIndex] ?? []

		        return VStack(spacing: 12) {
		            LazyVGrid(columns: inboxColumns, spacing: inboxGridSpacing) {
		                ForEach(currentPage) { doodle in
		                    inboxCell(doodle)
		                }
		            }
		            .padding(.top, 10)
		            .id(inboxPageIndex)
		            .gesture(
		                DragGesture(minimumDistance: 14)
		                    .onEnded { value in
		                        let dx = value.translation.width
		                        if dx <= -70 {
                                    if inboxPageIndex >= pageCount - 1 {
                                        Task { await tryAdvanceInboxToNextPage() }
                                    } else {
		                                withAnimation(.easeInOut(duration: 0.22)) {
		                                    inboxPageIndex = min(pageCount - 1, inboxPageIndex + 1)
		                                }
                                    }
		                        } else if dx >= 70 {
		                            withAnimation(.easeInOut(duration: 0.22)) {
		                                inboxPageIndex = max(0, inboxPageIndex - 1)
		                            }
		                        }
		                    }
		            )
		            .animation(.easeInOut(duration: 0.22), value: inboxPageIndex)

		            if pages.count > 1 {
		                pager(
                            pageCount: pages.count,
                            pageIndex: $inboxPageIndex,
                            canLoadMore: !inboxReachedEnd,
                            onLoadMore: { Task { await tryAdvanceInboxToNextPage() } }
                        )
		            }
		        }
		        .onChange(of: inboxDoodles.count) { _, _ in
		            clampInboxPageIndex()
		        }
		    }

		    private var anonymousInboxPagedGrid: some View {
		        let pageSize = inboxItemsPerPage
		        let pages = chunked(anonymousInboxDoodles, by: pageSize)
                let pageCount = max(1, pages.count)
                let currentPage = pages[safe: anonymousInboxPageIndex] ?? []

		        return VStack(spacing: 12) {
		            LazyVGrid(columns: inboxColumns, spacing: inboxGridSpacing) {
		                ForEach(currentPage) { doodle in
		                    anonymousInboxCell(doodle)
		                }
		            }
		            .padding(.top, 10)
		            .id(anonymousInboxPageIndex)
		            .gesture(
		                DragGesture(minimumDistance: 14)
		                    .onEnded { value in
		                        let dx = value.translation.width
		                        if dx <= -70 {
                                    if anonymousInboxPageIndex >= pageCount - 1 {
                                        Task { await tryAdvanceAnonymousInboxToNextPage() }
                                    } else {
		                                withAnimation(.easeInOut(duration: 0.22)) {
		                                    anonymousInboxPageIndex = min(pageCount - 1, anonymousInboxPageIndex + 1)
		                                }
                                    }
		                        } else if dx >= 70 {
		                            withAnimation(.easeInOut(duration: 0.22)) {
		                                anonymousInboxPageIndex = max(0, anonymousInboxPageIndex - 1)
		                            }
		                        }
		                    }
		            )
		            .animation(.easeInOut(duration: 0.22), value: anonymousInboxPageIndex)

		            if pages.count > 1 {
		                pager(
                            pageCount: pages.count,
                            pageIndex: $anonymousInboxPageIndex,
                            canLoadMore: !anonymousInboxReachedEnd,
                            onLoadMore: { Task { await tryAdvanceAnonymousInboxToNextPage() } }
                        )
		            }
		        }
		        .onChange(of: anonymousInboxDoodles.count) { _, _ in
		            clampAnonymousInboxPageIndex()
		        }
		    }

        @MainActor
        private func tryAdvanceInboxToNextPage() async {
            guard !inboxReachedEnd else { return }
            let nextPage = inboxPageIndex + 1
            let desired = inboxItemsPerPage * (nextPage + 1)
            let oldCount = inboxDoodles.count
            await refreshInbox(force: true, desiredLimit: desired)
            if inboxDoodles.count > oldCount {
                withAnimation(.easeInOut(duration: 0.22)) {
                    inboxPageIndex = nextPage
                }
                if let requesterId = try? await resolveProfileId() {
                    await hydrateInboxContentsIfNeeded(groupCode: activeGroupCode.lowercased(), requesterProfileId: requesterId, pageIndex: nextPage)
                }
            } else {
                inboxReachedEnd = true
            }
        }

        @MainActor
        private func tryAdvanceAnonymousInboxToNextPage() async {
            guard !anonymousInboxReachedEnd else { return }
            let nextPage = anonymousInboxPageIndex + 1
            let desired = inboxItemsPerPage * (nextPage + 1)
            let oldCount = anonymousInboxDoodles.count
            await refreshAnonymousInbox(force: true, desiredLimit: desired)
            if anonymousInboxDoodles.count > oldCount {
                withAnimation(.easeInOut(duration: 0.22)) {
                    anonymousInboxPageIndex = nextPage
                }
            } else {
                anonymousInboxReachedEnd = true
            }
        }

			    private func anonymousInboxCell(_ doodle: AnonymousInboxDoodle) -> some View {
			        Button {
                    Haptics.tap(.light)
			            selectedAnonymousInboxDoodle = doodle
			        } label: {
                    GeometryReader { proxy in
                        let side = proxy.size.width
                        ZStack(alignment: .bottomLeading) {
                            if let image = cachedDoodleImage(for: doodle) {
                                Image(uiImage: image)
                                    .renderingMode(.original)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: side, height: side)
                                    .clipped()
		                            } else {
		                                RoundedRectangle(cornerRadius: 18, style: .continuous)
		                                    .fill(Color.primary.opacity(0.06))
		                                    .overlay(
		                                        Text(loadFailedTitle)
		                                            .font(.system(size: 12, weight: .bold, design: .rounded))
		                                            .foregroundStyle(Color.secondary.opacity(0.85))
		                                            .padding(.horizontal, 10)
		                                    )
		                            }

                            LinearGradient(
                                colors: [.black.opacity(0.0), .black.opacity(0.50)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .allowsHitTesting(false)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(anonymousSenderTitle)
                                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.95))
                                    .lineLimit(1)
                                if let time = timeAgoText(doodle.createdAt) {
                                    Text(time)
                                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.80))
                                        .lineLimit(1)
                                }
                            }
                            .padding(10)
                            .allowsHitTesting(false)
                        }
                        .frame(width: side, height: side)
                    }
                    .aspectRatio(1, contentMode: .fit)
                    .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
		                    .overlay(
		                        RoundedRectangle(cornerRadius: 18, style: .continuous)
		                            .stroke(.black.opacity(0.10), lineWidth: 1)
		                    )
		                    .shadow(color: .black.opacity(0.14), radius: 10, x: 0, y: 6)
			        }
			        .buttonStyle(.plain)
			    }

		    private func pager(pageCount: Int, pageIndex: Binding<Int>, canLoadMore: Bool = false, onLoadMore: (() -> Void)? = nil) -> some View {
		        HStack(spacing: 12) {
		            Button {
                        Haptics.selectionChanged()
		                withAnimation(.easeInOut(duration: 0.22)) {
		                    pageIndex.wrappedValue = max(0, pageIndex.wrappedValue - 1)
		                }
		            } label: {
		                Image(systemName: "chevron.left")
		                    .font(.system(size: 14, weight: .heavy))
		                    .foregroundStyle(.white.opacity(0.95))
		                    .frame(width: 28, height: 28)
		                    .background(.white.opacity(0.10), in: Circle())
		            }
		            .buttonStyle(.plain)
		            .disabled(pageIndex.wrappedValue == 0)
		            .opacity(pageIndex.wrappedValue == 0 ? 0.35 : 1)

		            HStack(spacing: 6) {
		                ForEach(0..<pageCount, id: \.self) { idx in
		                    Button {
                                Haptics.selectionChanged()
		                        withAnimation(.easeInOut(duration: 0.22)) {
		                            pageIndex.wrappedValue = idx
		                        }
		                    } label: {
		                        Circle()
		                            .fill(idx == pageIndex.wrappedValue ? Color.white.opacity(0.95) : Color.white.opacity(0.25))
		                            .frame(width: idx == pageIndex.wrappedValue ? 8 : 6, height: idx == pageIndex.wrappedValue ? 8 : 6)
		                    }
		                    .buttonStyle(.plain)
		                }
		            }
		            .padding(.horizontal, 2)

		            Button {
                        Haptics.selectionChanged()
                        if pageIndex.wrappedValue >= pageCount - 1 {
                            onLoadMore?()
                        } else {
		                    withAnimation(.easeInOut(duration: 0.22)) {
		                        pageIndex.wrappedValue = min(pageCount - 1, pageIndex.wrappedValue + 1)
		                    }
                        }
		            } label: {
		                Image(systemName: "chevron.right")
		                    .font(.system(size: 14, weight: .heavy))
		                    .foregroundStyle(.white.opacity(0.95))
		                    .frame(width: 28, height: 28)
		                    .background(.white.opacity(0.10), in: Circle())
		            }
		            .buttonStyle(.plain)
		            .disabled(pageIndex.wrappedValue >= pageCount - 1 && !canLoadMore)
		            .opacity(pageIndex.wrappedValue >= pageCount - 1 && !canLoadMore ? 0.35 : 1)
		        }
		        .padding(.vertical, 8)
		        .padding(.horizontal, 12)
		        .background(.white.opacity(0.10), in: Capsule(style: .continuous))
		        .overlay(
		            Capsule(style: .continuous)
		                .stroke(.white.opacity(0.12), lineWidth: 1)
		        )
		    }

			    private var inboxPlaceholderGrid: some View {
			        return LazyVGrid(columns: inboxColumns, spacing: inboxGridSpacing) {
			            ForEach(0..<inboxItemsPerPage, id: \.self) { _ in
			                RoundedRectangle(cornerRadius: 18, style: .continuous)
			                    .fill(Color.primary.opacity(0.06))
			                    .overlay(
			                        RoundedRectangle(cornerRadius: 18, style: .continuous)
			                            .stroke(Color.primary.opacity(0.10), lineWidth: 1)
			                    )
			                    .aspectRatio(1, contentMode: .fit)
			                    .redacted(reason: .placeholder)
			            }
			        }
		        .padding(.top, 10)
		    }

			    private func inboxCell(_ doodle: InboxDoodle) -> some View {
			        Button {
                    Haptics.tap(.light)
			            selectedInboxDoodle = doodle
			        } label: {
                    GeometryReader { proxy in
                        let side = proxy.size.width
                        ZStack(alignment: .bottomLeading) {
                            if let image = cachedDoodleImage(for: doodle) {
                                Image(uiImage: image)
                                    .renderingMode(.original)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: side, height: side)
                                    .clipped()
		                            } else {
		                                RoundedRectangle(cornerRadius: 18, style: .continuous)
		                                    .fill(Color.primary.opacity(0.06))
		                                    .overlay(
		                                        Text(loadFailedTitle)
		                                            .font(.system(size: 12, weight: .bold, design: .rounded))
		                                            .foregroundStyle(Color.secondary.opacity(0.85))
		                                            .padding(.horizontal, 10)
		                                    )
		                            }

                            LinearGradient(
                                colors: [.black.opacity(0.0), .black.opacity(0.50)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .allowsHitTesting(false)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("@\(doodle.senderUsername)")
                                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.95))
                                    .lineLimit(1)
                                if let time = timeAgoText(doodle.createdAt) {
                                    Text(time)
                                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.80))
                                        .lineLimit(1)
                                }
                            }
                            .padding(10)
                            .allowsHitTesting(false)
                        }
                        .frame(width: side, height: side)
                    }
                    .aspectRatio(1, contentMode: .fit)
                    .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
		                    .overlay(
		                        RoundedRectangle(cornerRadius: 18, style: .continuous)
		                            .stroke(.black.opacity(0.10), lineWidth: 1)
		                    )
		                    .shadow(color: .black.opacity(0.14), radius: 10, x: 0, y: 6)
			        }
			        .buttonStyle(.plain)
			    }

    fileprivate static let doodleImageCache = NSCache<NSString, UIImage>()

    private func cachedDoodleImage(for doodle: InboxDoodle) -> UIImage? {
        let key = doodle.id as NSString
        if let cached = Self.doodleImageCache.object(forKey: key) {
            return cached
        }
        guard let content = doodle.contentBase64, let image = decodeDoodleBase64(content) else { return nil }
        Self.doodleImageCache.setObject(image, forKey: key)
        return image
    }

    private func cachedDoodleImage(for doodle: AnonymousInboxDoodle) -> UIImage? {
        let key = doodle.id as NSString
        if let cached = Self.doodleImageCache.object(forKey: key) {
            return cached
        }
        guard let image = decodeDoodleBase64(doodle.contentBase64) else { return nil }
        Self.doodleImageCache.setObject(image, forKey: key)
        return image
    }

    @MainActor
    private func hydrateInboxContentsIfNeeded(groupCode: String, requesterProfileId: String, pageIndex: Int) async {
        let start = pageIndex * inboxItemsPerPage
        guard start < inboxDoodles.count else { return }
        let end = min(inboxDoodles.count, start + inboxItemsPerPage)
        let slice = inboxDoodles[start..<end]
        let missingIds = slice.filter { $0.contentBase64 == nil }.map(\.id)
        guard !missingIds.isEmpty else { return }
        do {
            let contents = try await SupabaseService.shared.fetchDoodleContents(
                groupCode: groupCode,
                requesterProfileId: requesterProfileId,
                doodleIds: missingIds
            )
            if contents.isEmpty { return }
            inboxDoodles = inboxDoodles.map { doodle in
                if let content = contents[doodle.id] {
                    return InboxDoodle(
                        id: doodle.id,
                        senderProfileId: doodle.senderProfileId,
                        contentBase64: content,
                        senderUsername: doodle.senderUsername,
                        createdAt: doodle.createdAt
                    )
                }
                return doodle
            }
        } catch {
            // Best-effort; cells will show placeholders if hydration fails.
        }
    }

    private func fetchSingleInboxContent(groupCode: String, requesterProfileId: String, doodleId: String) async throws -> String? {
        let contents = try await SupabaseService.shared.fetchDoodleContents(
            groupCode: groupCode,
            requesterProfileId: requesterProfileId,
            doodleIds: [doodleId]
        )
        return contents[doodleId]
    }

    private let inboxGridSpacing: CGFloat = 12
    private var inboxColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: inboxGridSpacing), count: 3)
    }

    private var inboxItemsPerPage: Int { 9 } // 3 columns * 3 rows

    private func clampInboxPageIndex() {
        let pages = max(1, Int(ceil(Double(inboxDoodles.count) / Double(inboxItemsPerPage))))
        inboxPageIndex = min(max(0, inboxPageIndex), pages - 1)
    }

    private func clampAnonymousInboxPageIndex() {
        let pages = max(1, Int(ceil(Double(anonymousInboxDoodles.count) / Double(inboxItemsPerPage))))
        anonymousInboxPageIndex = min(max(0, anonymousInboxPageIndex), pages - 1)
    }

    private func chunked<T>(_ items: [T], by size: Int) -> [[T]] {
        guard size > 0 else { return [items] }
        var result: [[T]] = []
        result.reserveCapacity(Int(ceil(Double(items.count) / Double(size))))
        var index = 0
        while index < items.count {
            let end = min(items.count, index + size)
            result.append(Array(items[index..<end]))
            index = end
        }
        return result
    }

	private func decodeDoodleBase64(_ content: String) -> UIImage? {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let base64: String
        if let commaIndex = trimmed.firstIndex(of: ",") {
            base64 = String(trimmed[trimmed.index(after: commaIndex)...])
        } else {
            base64 = trimmed
        }
	        guard let data = Data(base64Encoded: base64, options: [.ignoreUnknownCharacters]) else { return nil }
	        return UIImage(data: data)?
                .withRenderingMode(.alwaysOriginal)
                .flattenedOnWhite(scale: 1.0)
	    }

	    private func timeAgoText(_ date: Date?) -> String? {
	        guard let date else { return nil }
	        let formatter = RelativeDateTimeFormatter()
	        formatter.unitsStyle = .abbreviated
	        formatter.locale = Locale(identifier: selectedLanguage.rawValue)
	        return formatter.localizedString(for: date, relativeTo: Date()).lowercased()
	    }

	    private var settingsTabContent: some View {
			        VStack(alignment: .leading, spacing: 14) {
	                    Text(settingsSubtitle)
	                        .font(.system(size: 14, weight: .semibold, design: .rounded))
	                        .foregroundStyle(.secondary.opacity(0.85))
	                        .frame(maxWidth: .infinity, alignment: .center)
	                        .padding(.bottom, 4)

                    settingsSection(title: settingsProTitle) {
                        proRow
                    }

				    settingsSection(title: settingsLanguageTitle) {
				        languageFlags
				    }

			            settingsSection(title: settingsAccountTitle) {
			                VStack(spacing: 10) {
			                    settingsAvatarRow
			                    settingsUsernameRow
			                }
			            }

			            settingsSection(title: settingsSafetyTitle) {
			                if let pid = profileId {
			                    NavigationLink {
			                        BlockedUsersView(
			                            language: selectedLanguage,
			                            profileId: pid,
			                            pairingCode: pairingCode
			                        )
			                    } label: {
			                        settingsButtonRow(
			                            icon: "hand.raised.fill",
			                            title: settingsBlockedTitle,
			                            subtitle: settingsBlockedSubtitle
			                        )
			                    }
			                } else {
			                    settingsButtonRow(
			                        icon: "hand.raised.fill",
			                        title: settingsBlockedTitle,
			                        subtitle: settingsBlockedSubtitle
			                    )
			                }
			            }

			                    settingsSection(title: settingsWidgetTitle) {
			                        NavigationLink {
			                            WidgetHelpView(language: selectedLanguage)
			                        } label: {
		                            settingsButtonRow(
                                icon: "square.grid.2x2",
                                title: settingsWidgetHowTitle,
                                subtitle: settingsWidgetHowSubtitle
                            )
                        }
                    }

		            settingsSection(title: settingsLegalTitle) {
		                VStack(spacing: 10) {
		                    settingsLinkRow(title: settingsTermsTitle, subtitle: settingsOpen, url: URL(string: "https://doodl-me.com/terms/")!)
		                    settingsLinkRow(title: settingsPrivacyTitle, subtitle: settingsOpen, url: URL(string: "https://doodl-me.com/privacy/")!)
		                    settingsLinkRow(title: settingsSupportTitle, subtitle: settingsOpen, url: URL(string: "https://doodl-me.com/support/")!)
		                }
		            }

			            settingsSection(title: settingsActionsTitle) {
			                VStack(spacing: 10) {
			                    Button(role: .destructive) {
			                        showDeleteConfirm = true
			                    } label: {
			                        settingsActionRow(icon: "trash.fill", text: settingsDeleteTitle, tint: .red)
		                    }
		                    .buttonStyle(.plain)
		                    .disabled(isDeleting)
		                }
		            }

				            if let errorMessage, !errorMessage.isEmpty {
				                Text(errorMessage)
				                    .font(.system(size: 14, weight: .semibold, design: .rounded))
				                    .foregroundStyle(Color.primary.opacity(0.92))
				                    .padding(.vertical, 10)
				                    .padding(.horizontal, 12)
				                    .frame(maxWidth: .infinity)
				                    .background(.red.opacity(0.16), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
				            }
		        }
			        .confirmationDialog(
			            deleteConfirmTitle,
			            isPresented: $showDeleteConfirm,
			            titleVisibility: .visible
		        ) {
		            Button(settingsDeleteTitle, role: .destructive) {
		                Task { await deleteAccount() }
		            }
		            Button(cancelTitle, role: .cancel) {}
		        } message: {
		            Text(deleteConfirmMessage)
		        }
	                .sheet(isPresented: $showUsernameEditor) {
	                    EditUsernameSheet(
	                        language: selectedLanguage,
	                        profileId: profileId,
	                        profilePairingCode: pairingCode,
	                        currentUsername: username,
	                        errorText: $usernameEditError,
	                        onUpdated: { finalUsername in
	                            applyUsernameChange(finalUsername)
	                        }
                    )
                }
			    }

	        private var settingsUsernameRow: some View {
	            Button {
	                Haptics.tap()
	                showUsernameEditor = true
	            } label: {
	                HStack(spacing: 12) {
		                    Image(systemName: "at")
		                        .font(.system(size: 16, weight: .bold))
		                        .foregroundStyle(iconMuted)
		                        .frame(width: 22)

	                    VStack(alignment: .leading, spacing: 4) {
	                        Text(settingsUsernameTitle)
	                            .font(.system(size: 13, weight: .semibold, design: .rounded))
	                            .foregroundStyle(.secondary.opacity(0.85))
	                        Text("@\(username)")
	                            .font(.system(size: 15, weight: .bold, design: .rounded))
	                            .foregroundStyle(.primary.opacity(0.92))
	                            .lineLimit(1)
	                            .minimumScaleFactor(0.8)
	                    }

	                    Spacer()

		                    Image(systemName: "pencil")
		                        .font(.system(size: 14, weight: .bold))
		                        .foregroundStyle(iconSubtle)
		                }
	                .padding(.vertical, 12)
	                .padding(.horizontal, 12)
		                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
		                .overlay(
		                    RoundedRectangle(cornerRadius: 16, style: .continuous)
		                        .stroke(uiStroke, lineWidth: 1)
		                )
	            }
	            .buttonStyle(.plain)
	        }

		        private var proRow: some View {
		            Button {
		                Haptics.tap(.medium)
		                requestProPaywall()
		            } label: {
	                HStack(spacing: 12) {
	                    Image(systemName: "crown.fill")
	                        .font(.system(size: 16, weight: .bold))
	                        .foregroundStyle(.yellow.opacity(0.95))
	                        .frame(width: 22)
	
	                    VStack(alignment: .leading, spacing: 4) {
	                        Text(settingsProRowTitle)
	                            .font(.system(size: 13, weight: .semibold, design: .rounded))
	                            .foregroundStyle(.secondary.opacity(0.85))
	                        Text(purchaseManager.isPro ? settingsProActiveSubtitle : settingsProUpgradeSubtitle)
	                            .font(.system(size: 15, weight: .bold, design: .rounded))
	                            .foregroundStyle(.primary.opacity(0.92))
	                            .lineLimit(1)
	                    }
	
	                    Spacer()
	
	                    if purchaseManager.isLoading {
	                        ProgressView().tint(Color.primary.opacity(0.65))
	                    } else {
	                        Image(systemName: "chevron.right")
	                            .font(.system(size: 13, weight: .bold))
	                            .foregroundStyle(iconSubtle)
	                    }
	                }
	                .padding(.vertical, 12)
	                .padding(.horizontal, 12)
	                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
	                .overlay(
	                    RoundedRectangle(cornerRadius: 16, style: .continuous)
	                        .stroke(uiStroke, lineWidth: 1)
	                )
	            }
	            .buttonStyle(.plain)
	        }

		    private var settingsAvatarRow: some View {
		        PhotosPicker(selection: $avatarPickerItem, matching: .images) {
		            HStack(spacing: 12) {
		                ZStack {
		                    Circle().fill(.thinMaterial)
		                    if let url = avatarURL {
		                        AsyncImage(url: url) { phase in
		                            switch phase {
		                            case .success(let image):
		                                image.resizable().scaledToFill()
		                            default:
		                                Image(systemName: "person.fill")
		                                    .font(.system(size: 18, weight: .bold))
		                                    .foregroundStyle(iconMuted)
		                            }
		                        }
		                    } else {
		                        Image(systemName: "person.fill")
		                            .font(.system(size: 18, weight: .bold))
		                            .foregroundStyle(iconMuted)
		                    }
		                }
		                .frame(width: 44, height: 44)
		                .clipShape(Circle())
		                .overlay(Circle().stroke(uiStroke, lineWidth: 1))
	
		                VStack(alignment: .leading, spacing: 2) {
		                    Text(settingsProfilePhotoTitle)
		                        .font(.system(size: 14, weight: .bold, design: .rounded))
		                        .foregroundStyle(.secondary.opacity(0.85))
		                    Text(settingsChangePhotoTitle)
		                        .font(.system(size: 16, weight: .heavy, design: .rounded))
		                        .foregroundStyle(.primary.opacity(0.92))
		                }
	
		                Spacer()
	
		                if isUpdatingAvatar {
		                    ProgressView().tint(Color.primary.opacity(0.65))
		                } else {
		                    Image(systemName: "chevron.right")
		                        .font(.system(size: 14, weight: .bold))
		                        .foregroundStyle(iconSubtle)
		                }
		            }
		            .padding(.vertical, 12)
		            .padding(.horizontal, 12)
		            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
		            .overlay(
		                RoundedRectangle(cornerRadius: 16, style: .continuous)
		                    .stroke(uiStroke, lineWidth: 1)
		            )
		        }
		        .disabled(isUpdatingAvatar)
		    }

	    @MainActor
		    private func updateAvatar(from item: PhotosPickerItem) async {
		        guard let profileId else { return }
		        if isUpdatingAvatar { return }
		        isUpdatingAvatar = true
		        errorMessage = nil
	        do {
	            guard let data = try await item.loadTransferable(type: Data.self),
	                  let image = UIImage(data: data) else {
	                throw SupabaseServiceError.invalidImage
	            }
		            let newURL = try await SupabaseService.shared.uploadAvatar(image: image)
		            if let previous = avatarURL {
		                try? await SupabaseService.shared.deleteAvatar(fileURL: previous)
		            }
		            try await SupabaseService.shared.updateProfileAvatar(profileId: profileId, profilePairingCode: pairingCode, avatarURL: newURL)
		            avatarURL = newURL
	            OnboardingStorage.save(
	                profileId: profileId,
	                username: username,
	                avatarURL: newURL,
	                pairingCode: pairingCode,
	                joinedCode: joinedCode
	            )
	            await refreshMembers(force: true)
	        } catch {
	            errorMessage = UserFacingError.message(for: error, language: selectedLanguage)
		        }
		        isUpdatingAvatar = false
		    }

	    @MainActor
	    private func refreshInvites() async {
	        guard let profileId else { return }
	        if isLoadingInvites { return }
        isLoadingInvites = true
        invitesError = nil
        do {
            invites = try await SupabaseService.shared.listInvites(profileId: profileId)
        } catch {
            invitesError = UserFacingError.message(for: error, language: selectedLanguage)
        }
        isLoadingInvites = false
    }

	    @MainActor
		    private func respondToInvite(_ invite: GroupInvite, accept: Bool) async {
		        guard let profileId else { return }
		        invitesError = nil
			        if accept {
			            let incoming = invite.groupCode.lowercased()
			            if !purchaseManager.isPro && !joinedGroups.isEmpty && !joinedGroups.contains(incoming) {
			                Haptics.warning()
			                requestProPaywall()
			                invitesError = proRequiredForGroupsTitle
			                return
			            }
			        }
		        do {
		            _ = try await SupabaseService.shared.respondInvite(inviteId: invite.id, profileId: profileId, profilePairingCode: pairingCode, accept: accept)
		            if accept {
		                let incoming = invite.groupCode.lowercased()
		                joinedCode = invite.groupCode.lowercased()
		                OnboardingStorage.saveJoinedCode(invite.groupCode.lowercased())
		                if incoming != pairingCode.lowercased(), !joinedGroups.contains(incoming) {
		                    joinedGroups.append(incoming)
		                    joinedGroups = Array(Set(joinedGroups)).sorted()
		                    persistJoinedGroups()
		                }
		                await refreshMembers(force: true, codeOverride: invite.groupCode.lowercased())
	                await refreshInbox(force: true, codeOverride: invite.groupCode.lowercased())
	            }
	            await refreshInvites()
	        } catch {
            invitesError = UserFacingError.message(for: error, language: selectedLanguage)
        }
    }

    private var languageFlags: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                languageFlag(.english)
                languageFlag(.dutch)
                languageFlag(.german)
                languageFlag(.spanish)
            }
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    languageFlag(.english)
                    languageFlag(.dutch)
                }
                HStack(spacing: 10) {
                    languageFlag(.german)
                    languageFlag(.spanish)
                }
            }
        }
    }

    private func languageFlag(_ language: AppLanguage) -> some View {
        let isSelected = selectedLanguage == language
        return Button {
            Haptics.selectionChanged()
            selectedLanguage = language
        } label: {
            HStack(spacing: 10) {
                Text(language.flagEmoji)
                    .font(.system(size: 22))
                    .frame(width: 34, alignment: .center)

	                VStack(alignment: .leading, spacing: 2) {
	                    Text(language.displayName)
	                        .font(.system(size: 15, weight: .heavy, design: .rounded))
	                        .foregroundStyle(isSelected ? pillActiveForeground : Color.primary.opacity(0.92))
	                        .lineLimit(1)
	                        .minimumScaleFactor(0.85)

	                    Text(language.shortCode.uppercased())
	                        .font(.system(size: 12, weight: .bold, design: .rounded))
	                        .foregroundStyle(isSelected ? pillActiveForeground.opacity(0.75) : Color.secondary.opacity(0.80))
	                }

                Spacer(minLength: 0)

	                if isSelected {
	                    Image(systemName: "checkmark.circle.fill")
	                        .font(.system(size: 16, weight: .bold))
	                        .foregroundStyle(pillActiveForeground.opacity(0.92))
	                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .background {
                let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
                if isSelected {
                    shape.fill(pillActiveBackground)
                } else {
                    shape.fill(.thinMaterial)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(uiStroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(language.displayName))
        .accessibilityValue(Text(isSelected ? "selected" : ""))
    }

    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(.primary.opacity(0.92))
                .padding(.horizontal, 4)

            sectionCard {
                content()
            }
        }
    }

    private func settingsInfoRow(icon: String, title: String, value: String, monospace: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(iconMuted)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary.opacity(0.85))
                Text(value)
                    .font(monospace ? .system(size: 15, weight: .bold, design: .monospaced) : .system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(uiStroke, lineWidth: 1)
        )
    }

    private func settingsCopyRow(icon: String, title: String, value: String, monospace: Bool) -> some View {
        Button {
            Haptics.selectionChanged()
            UIPasteboard.general.string = value
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(iconMuted)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary.opacity(0.85))
                    Text(value)
                        .font(monospace ? .system(size: 15, weight: .bold, design: .monospaced) : .system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.92))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer()

                Image(systemName: "doc.on.doc")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(iconSubtle)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(uiStroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func settingsLinkRow(title: String, subtitle: String, url: URL) -> some View {
        Link(destination: url) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.92))
                    Text(subtitle)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary.opacity(0.75))
                }
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.secondary.opacity(0.65))
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.primary.opacity(0.10), lineWidth: 1)
            )
        }
    }

    private func settingsButtonRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.primary.opacity(0.82))
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.92))
                Text(subtitle)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary.opacity(0.75))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.secondary.opacity(0.65))
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.10), lineWidth: 1)
        )
    }

    private func settingsActionRow(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(tint)
            Text(text)
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(.primary.opacity(0.92))
            Spacer()
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
	        .overlay(
	            RoundedRectangle(cornerRadius: 16, style: .continuous)
	                .stroke(Color.primary.opacity(0.10), lineWidth: 1)
	        )
	    }

    private func deleteAccount() async {
        guard let profileId else { return }
        isDeleting = true
        errorMessage = nil
	        do {
	            try await SupabaseService.shared.deleteProfile(profileId: profileId, profilePairingCode: pairingCode)
	            await MainActor.run {
	                resetOnboarding()
	                path = []
	                OnboardingStorage.clear()
	            }
        } catch {
            await MainActor.run {
                errorMessage = UserFacingError.message(for: error, language: selectedLanguage)
            }
        }
        await MainActor.run {
            isDeleting = false
        }
    }

	    @MainActor
		    private func applyUsernameChange(_ final: String) {
	        guard let profileId else { return }
		        guard !final.isEmpty else { return }

		        username = final
		        SharedWidgetStore.saveWidgetConfig(groupCode: SharedWidgetStore.allSourcesCode, profileId: profileId, username: final)
		        OnboardingStorage.save(
		            profileId: profileId,
		            username: final,
		            avatarURL: avatarURL,
            pairingCode: pairingCode,
            joinedCode: joinedCode
        )
    }

		    private var settingsSubtitle: String {
	        switch selectedLanguage {
	        case .english: "profile • appearance • language • account"
	        case .dutch: "profiel • uiterlijk • taal • account"
	        case .german: "profil • aussehen • sprache • konto"
	        case .spanish: "perfil • apariencia • idioma • cuenta"
	        }
	    }

	    private var settingsAppearanceTitle: String {
	        switch selectedLanguage {
	        case .english: "appearance"
	        case .dutch: "uiterlijk"
	        case .german: "aussehen"
	        case .spanish: "apariencia"
	        }
	    }

	    private var settingsAppearanceSubtitle: String {
	        switch selectedLanguage {
	        case .english: "choose system, light, or dark mode"
	        case .dutch: "kies systeem-, licht- of donkere modus"
	        case .german: "system-, hell- oder dunkelmodus wählen"
	        case .spanish: "elige sistema, claro u oscuro"
	        }
	    }

    private var settingsProTitle: String {
        switch selectedLanguage {
        case .english: "pro"
        case .dutch: "pro"
        case .german: "pro"
        case .spanish: "pro"
        }
    }

    private var settingsProRowTitle: String {
        switch selectedLanguage {
        case .english: "DOODL pro"
        case .dutch: "DOODL pro"
        case .german: "DOODL pro"
        case .spanish: "DOODL pro"
        }
    }

    private var settingsProActiveSubtitle: String {
        switch selectedLanguage {
        case .english: "active"
        case .dutch: "actief"
        case .german: "aktiv"
        case .spanish: "activo"
        }
    }

    private var settingsProUpgradeSubtitle: String {
        switch selectedLanguage {
        case .english: "upgrade for more options"
        case .dutch: "upgrade voor meer opties"
        case .german: "upgrade für mehr optionen"
        case .spanish: "mejora para más opciones"
        }
    }

    private var settingsThemeTitle: String {
        switch selectedLanguage {
        case .english: "theme"
        case .dutch: "thema"
        case .german: "thema"
        case .spanish: "tema"
        }
    }

    private var settingsThemeSubtitle: String {
        switch selectedLanguage {
        case .english: "tap to apply"
        case .dutch: "tik om toe te passen"
        case .german: "tippen zum anwenden"
        case .spanish: "toca para aplicar"
        }
    }

    private var settingsThemeProOnly: String {
        switch selectedLanguage {
        case .english: "pro theme"
        case .dutch: "pro thema"
        case .german: "pro-thema"
        case .spanish: "tema pro"
        }
    }

    private var tabShare: String {
        switch selectedLanguage {
        case .english: "share"
        case .dutch: "delen"
        case .german: "teilen"
        case .spanish: "compartir"
        }
    }

	    private var tabInbox: String {
	        switch selectedLanguage {
	        case .english: "inbox"
	        case .dutch: "berichten"
	        case .german: "nachrichten"
	        case .spanish: "mensajes"
	        }
	    }

	    private var tabPro: String {
	        switch selectedLanguage {
	        case .english: "pro"
	        case .dutch: "pro"
	        case .german: "pro"
	        case .spanish: "pro"
	        }
	    }

    private var tabInboxChatsTitle: String {
        switch selectedLanguage {
        case .english: "chats"
        case .dutch: "chats"
        case .german: "chats"
        case .spanish: "chats"
        }
    }

    private var tabInboxGroupTitle: String {
        switch selectedLanguage {
        case .english: "group"
        case .dutch: "groep"
        case .german: "gruppe"
        case .spanish: "grupo"
        }
    }

    private var tabInboxAnonymousTitle: String {
        switch selectedLanguage {
        case .english: "anon"
        case .dutch: "anon"
        case .german: "anon"
        case .spanish: "anón"
        }
    }

    private var anonymousSenderTitle: String {
        switch selectedLanguage {
        case .english: "anonymous"
        case .dutch: "anoniem"
        case .german: "anonym"
        case .spanish: "anónimo"
        }
    }

    private var tabSettings: String {
        switch selectedLanguage {
        case .english: "settings"
        case .dutch: "instellingen"
        case .german: "einstellungen"
        case .spanish: "ajustes"
        }
    }

    private var membersTitle: String {
        switch selectedLanguage {
        case .english: "group members"
        case .dutch: "groepsleden"
        case .german: "gruppenmitglieder"
        case .spanish: "miembros del grupo"
        }
    }

    private var alreadyInThisGroupTitle: String {
        switch selectedLanguage {
        case .english: "you are already in this group."
        case .dutch: "je zit al in deze groep."
        case .german: "du bist bereits in dieser gruppe."
        case .spanish: "ya estás en este grupo."
        }
    }

	    private var dashboardSubtitle: String {
	        switch selectedLanguage {
	        case .english: "draw a doodl and send it"
	        case .dutch: "maak een doodl en stuur ‘m"
	        case .german: "zeichne ein doodl und sende es"
	        case .spanish: "dibuja un doodl y envíalo"
	        }
	    }

        private var anonymousIntroTitle: String {
            switch selectedLanguage {
            case .english: "anonymous inbox"
            case .dutch: "anonieme inbox"
            case .german: "anonymer posteingang"
            case .spanish: "bandeja anónima"
            }
        }

        private var anonymousIntroSubtitle: String {
            switch selectedLanguage {
            case .english: "turn on your anonymous link, share it, and receive doodls here."
            case .dutch: "zet je anonieme link aan, deel ’m, en ontvang hier doodls."
            case .german: "aktiviere deinen anonymen link, teile ihn und empfange doodls hier."
            case .spanish: "activa tu enlace anónimo, compártelo y recibe doodls aquí."
            }
        }

        private var anonymousEnableButtonTitle: String {
            switch selectedLanguage {
            case .english: "enable anonymous link"
            case .dutch: "anonieme link aanzetten"
            case .german: "anonymen link aktivieren"
            case .spanish: "activar enlace anónimo"
            }
        }

        private var anonymousEmptyTitle: String {
            switch selectedLanguage {
            case .english: "no anonymous doodls yet"
            case .dutch: "nog geen anonieme doodls"
            case .german: "noch keine anonymen doodls"
            case .spanish: "aún no hay doodls anónimos"
            }
        }

        private var anonymousEmptySubtitle: String {
            switch selectedLanguage {
            case .english: "share your link to start receiving."
            case .dutch: "deel je link om te starten."
            case .german: "teile deinen link, um zu starten."
            case .spanish: "comparte tu enlace para empezar."
            }
        }

        private var anonymousCopyLinkTitle: String {
            switch selectedLanguage {
            case .english: "copy anonymous link"
            case .dutch: "kopieer anonieme link"
            case .german: "anonymen link kopieren"
            case .spanish: "copiar enlace anónimo"
            }
        }

        private var anonymousShareLinkTitle: String {
            switch selectedLanguage {
            case .english: "share anonymous link"
            case .dutch: "deel anonieme link"
            case .german: "anonymen link teilen"
            case .spanish: "compartir enlace anónimo"
            }
        }

        private var anonymousRefreshLinkTitle: String {
            switch selectedLanguage {
            case .english: "refresh anonymous link"
            case .dutch: "anonieme link verversen"
            case .german: "anonymen link aktualisieren"
            case .spanish: "actualizar enlace anónimo"
            }
        }

	    private var comingSoon: String {
	        switch selectedLanguage {
	        case .english: "coming soon"
	        case .dutch: "binnenkort"
        case .german: "bald"
        case .spanish: "próximamente"
        }
    }

    private var noDoodlesYetTitle: String {
        switch selectedLanguage {
        case .english: "no doodls yet"
        case .dutch: "nog geen doodls"
        case .german: "noch keine doodls"
        case .spanish: "aún no hay doodls"
        }
    }

    private var loadFailedTitle: String {
        switch selectedLanguage {
        case .english: "failed to load"
        case .dutch: "laden mislukt"
        case .german: "laden fehlgeschlagen"
        case .spanish: "error al cargar"
        }
    }

    private var settingsLanguageTitle: String {
        switch selectedLanguage {
        case .english: "language"
        case .dutch: "taal"
        case .german: "sprache"
        case .spanish: "idioma"
        }
    }

	    private var anonymousInboxDisabledTitle: String {
	        switch selectedLanguage {
	        case .english: "enable your anonymous link in settings to receive doodls."
	        case .dutch: "zet je anonieme link aan in instellingen om doodls te ontvangen."
        case .german: "aktiviere deinen anonymen link in den einstellungen."
        case .spanish: "activa el enlace anónimo en ajustes."
        }
    }

	    private var anonymousInboxProRequiredTitle: String {
	        switch selectedLanguage {
        case .english: "anonymous doodls are a pro feature."
        case .dutch: "anonieme doodls zijn een pro feature."
        case .german: "anonyme doodls sind ein pro-feature."
        case .spanish: "los doodls anónimos son pro."
        }
    }

    private var anonymousNoDoodlesTitle: String {
        switch selectedLanguage {
        case .english: "no anonymous doodls yet"
        case .dutch: "nog geen anonieme doodls"
        case .german: "noch keine anonymen doodls"
        case .spanish: "aún no hay doodls anónimos"
        }
    }

    private var settingsAccountTitle: String {
        switch selectedLanguage {
        case .english: "account"
        case .dutch: "account"
        case .german: "konto"
        case .spanish: "cuenta"
        }
    }

    private var settingsWidgetTitle: String {
        switch selectedLanguage {
        case .english: "widget"
        case .dutch: "widget"
        case .german: "widget"
        case .spanish: "widget"
        }
    }

    private var settingsWidgetHowTitle: String {
        switch selectedLanguage {
        case .english: "add the widget"
        case .dutch: "widget toevoegen"
        case .german: "widget hinzufügen"
        case .spanish: "añadir widget"
        }
    }

    private var settingsWidgetHowSubtitle: String {
        switch selectedLanguage {
        case .english: "show steps for your home screen"
        case .dutch: "stappen voor je beginscherm"
        case .german: "schritte für den homescreen"
        case .spanish: "pasos para tu pantalla"
        }
    }

    private var settingsWidgetSourceTitle: String {
        switch selectedLanguage {
        case .english: "widget source"
        case .dutch: "widget bron"
        case .german: "widget quelle"
        case .spanish: "origen del widget"
        }
    }

    private var settingsWidgetSourceSubtitle: String {
        switch selectedLanguage {
        case .english: "choose a chat or group"
        case .dutch: "kies een chat of groep"
        case .german: "wähle chat oder gruppe"
        case .spanish: "elige chat o grupo"
        }
    }

    private var widgetNudgeTitle: String {
        switch selectedLanguage {
        case .english: "want the widget?"
        case .dutch: "wil je de widget?"
        case .german: "willst du das widget?"
        case .spanish: "¿quieres el widget?"
        }
    }

    private var widgetNudgeMessage: String {
        switch selectedLanguage {
        case .english: "pin the latest doodl on your home screen"
        case .dutch: "zet de nieuwste doodl op je beginscherm"
        case .german: "zeige das neueste doodl auf deinem homescreen"
        case .spanish: "pon el doodl más reciente en tu pantalla"
        }
    }

    private var widgetNudgeShowMe: String {
        switch selectedLanguage {
        case .english: "show me"
        case .dutch: "laat zien"
        case .german: "zeigen"
        case .spanish: "ver"
        }
    }

    private var settingsLegalTitle: String {
        switch selectedLanguage {
        case .english: "legal"
        case .dutch: "juridisch"
        case .german: "rechtliches"
        case .spanish: "legal"
        }
    }

    private var settingsActionsTitle: String {
        switch selectedLanguage {
        case .english: "actions"
        case .dutch: "acties"
        case .german: "aktionen"
        case .spanish: "acciones"
        }
    }

    private var settingsUsernameTitle: String {
        switch selectedLanguage {
        case .english: "username"
        case .dutch: "gebruikersnaam"
        case .german: "benutzername"
        case .spanish: "usuario"
        }
    }

    private var settingsPairingCodeTitle: String {
        switch selectedLanguage {
        case .english: "pairing code"
        case .dutch: "doodl code"
        case .german: "doodl-code"
        case .spanish: "código doodl"
        }
    }

    private var settingsJoinedCodeTitle: String {
        switch selectedLanguage {
        case .english: "joined code"
        case .dutch: "gejoinde code"
        case .german: "beitrittscode"
        case .spanish: "código unido"
        }
    }

    private var settingsTermsTitle: String {
        switch selectedLanguage {
        case .english: "terms of service"
        case .dutch: "gebruiksvoorwaarden"
        case .german: "nutzungsbedingungen"
        case .spanish: "términos de servicio"
        }
    }

    private var settingsPrivacyTitle: String {
        switch selectedLanguage {
        case .english: "privacy policy"
        case .dutch: "privacybeleid"
        case .german: "datenschutz"
        case .spanish: "política de privacidad"
        }
    }

    private var settingsSupportTitle: String {
        switch selectedLanguage {
        case .english: "support"
        case .dutch: "support"
        case .german: "support"
        case .spanish: "soporte"
        }
    }

    private var settingsProfilePhotoTitle: String {
        switch selectedLanguage {
        case .english: "profile photo"
        case .dutch: "profielfoto"
        case .german: "profilbild"
        case .spanish: "foto de perfil"
        }
    }

	    private var settingsChangePhotoTitle: String {
	        switch selectedLanguage {
	        case .english: "change photo"
	        case .dutch: "wijzig foto"
	        case .german: "foto ändern"
	        case .spanish: "cambiar foto"
	        }
	    }

    private var settingsDeleteTitle: String {
        switch selectedLanguage {
        case .english: "delete account"
        case .dutch: "account verwijderen"
        case .german: "konto löschen"
        case .spanish: "eliminar cuenta"
        }
    }

	    private var cancelTitle: String {
	        switch selectedLanguage {
	        case .english: "cancel"
	        case .dutch: "annuleren"
	        case .german: "abbrechen"
	        case .spanish: "cancelar"
	        }
	    }

    private var deleteConfirmTitle: String {
        switch selectedLanguage {
        case .english: "delete account?"
        case .dutch: "account verwijderen?"
        case .german: "konto löschen?"
        case .spanish: "¿eliminar cuenta?"
        }
    }

	    private var deleteConfirmMessage: String {
	        switch selectedLanguage {
	        case .english: "this will permanently delete your account. you can’t recover it (no sign-in)."
	        case .dutch: "dit verwijdert je account permanent. je kunt dit niet herstellen (geen sign-in)."
	        case .german: "dies löscht dein konto dauerhaft. du kannst es nicht wiederherstellen (kein sign-in)."
	        case .spanish: "esto eliminará tu cuenta permanentemente. no podrás recuperarla (sin inicio de sesión)."
	        }
	    }

    private var settingsTba: String {
        switch selectedLanguage {
        case .english: "tba"
        case .dutch: "tba"
        case .german: "tba"
        case .spanish: "tba"
        }
    }

    private var reviewTitle: String {
        switch selectedLanguage {
        case .english: "enjoying DOODL.?"
        case .dutch: "vind je DOODL. leuk?"
        case .german: "gefällt dir DOODL.?"
        case .spanish: "¿te gusta DOODL.?"
        }
    }

    private var reviewMessage: String {
        switch selectedLanguage {
        case .english: "a quick rating helps a lot."
        case .dutch: "een snelle review helpt enorm."
        case .german: "eine kurze bewertung hilft sehr."
        case .spanish: "una reseña rápida ayuda mucho."
        }
    }

    private var reviewYesTitle: String {
        switch selectedLanguage {
        case .english: "rate now"
        case .dutch: "reviewen"
        case .german: "bewerten"
        case .spanish: "calificar"
        }
    }

    private var reviewNoTitle: String {
        switch selectedLanguage {
        case .english: "not now"
        case .dutch: "niet nu"
        case .german: "nicht jetzt"
        case .spanish: "ahora no"
        }
    }

    private var settingsOpen: String {
        switch selectedLanguage {
        case .english: "open"
        case .dutch: "open"
        case .german: "öffnen"
        case .spanish: "abrir"
        }
    }

			    private var headerTabs: some View {
			        HStack(spacing: 10) {
			            tabButton(title: tabShare, symbol: "paperplane.fill", isActive: selectedTab == .share) { selectedTab = .share }
			            tabButton(title: tabInbox, symbol: "tray.fill", isActive: selectedTab == .inbox, badgeText: inboxBadgeText) { selectedTab = .inbox }
			            tabButton(title: tabPro, symbol: "crown.fill", isActive: selectedTab == .pro) { selectedTab = .pro }
			        }
	                .dashboardTutorialAnchor(.headerTabs)
			        .padding(6)
	                .glassCapsule()
	    }

		    private func tabButton(title: String, symbol: String? = nil, isActive: Bool, badgeText: String? = nil, action: @escaping () -> Void) -> some View {
		        Button(action: action) {
		            HStack(spacing: 8) {
		                if let symbol {
		                    Image(systemName: symbol)
		                        .font(.system(size: 13, weight: .bold))
		                }
		                Text(title)
		                    .font(.system(size: 16, weight: .heavy, design: .rounded))
		            }
		            .foregroundStyle(isActive ? pillActiveForeground : pillInactiveForeground)
		            .padding(.vertical, 10)
		            .padding(.horizontal, 14)
	                .overlay(alignment: .topTrailing) {
	                    if let badgeText, !badgeText.isEmpty, !isActive {
	                        Text(badgeText)
	                            .font(.system(size: 11, weight: .heavy, design: .rounded))
	                            .foregroundStyle(.white)
                            .padding(.vertical, 3)
                            .padding(.horizontal, 6)
                            .background(Color.red, in: Capsule(style: .continuous))
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(.white.opacity(0.65), lineWidth: 1)
                            )
                            .offset(x: 10, y: -10)
                    }
                }
		                .background(
		                    Group {
		                        if isActive {
		                            Capsule(style: .continuous).fill(pillActiveBackground)
		                        } else {
		                            Capsule(style: .continuous).fill(.clear)
		                        }
		                    }
		                )
		        }
		        .buttonStyle(.plain)
		    }

		    private var settingsSafetyTitle: String {
		        switch selectedLanguage {
		        case .english: "safety"
		        case .dutch: "veiligheid"
		        case .german: "sicherheit"
		        case .spanish: "seguridad"
		        }
		    }

		    private var settingsBlockedTitle: String {
		        switch selectedLanguage {
		        case .english: "blocked users"
		        case .dutch: "geblokkeerde users"
		        case .german: "blockierte nutzer"
		        case .spanish: "usuarios bloqueados"
		        }
		    }

		    private var settingsBlockedSubtitle: String {
		        switch selectedLanguage {
		        case .english: "manage who you’ve blocked"
		        case .dutch: "beheer wie je geblokkeerd hebt"
		        case .german: "verwalte, wen du blockiert hast"
		        case .spanish: "gestiona a quién bloqueaste"
		        }
		    }

    private var inboxBadgeText: String? {
        let count = max(directUnreadThreadsCount, unreadInboxCount)
        guard count > 0 else { return nil }
        if count >= 99 { return "+99" }
        return "+\(count)"
    }

    private var unreadInboxCount: Int {
        let lastSeen = lastSeenInboxAt(groupCode: activeGroupCode)
        let own = username.lowercased()
        return inboxDoodles.reduce(into: 0) { acc, doodle in
            guard doodle.senderUsername.lowercased() != own else { return }
            let created = doodle.createdAt ?? .distantPast
            if created > lastSeen { acc += 1 }
        }
    }

    private func inboxLastSeenKey(groupCode: String) -> String {
        "inbox.lastSeenAt.\(groupCode.lowercased())"
    }

    private func lastSeenInboxAt(groupCode: String) -> Date {
        let key = inboxLastSeenKey(groupCode: groupCode)
        let t = UserDefaults.standard.double(forKey: key)
        if t <= 0 { return .distantPast }
        return Date(timeIntervalSince1970: t)
    }

    private func markInboxAsSeen(groupCode: String) {
        guard !inboxDoodles.isEmpty else { return }
        let key = inboxLastSeenKey(groupCode: groupCode)
        let latest = inboxDoodles
            .filter { $0.senderUsername.lowercased() != username.lowercased() }
            .compactMap { $0.createdAt }
            .max() ?? Date()
        UserDefaults.standard.set(latest.timeIntervalSince1970, forKey: key)
    }

    @MainActor
    private func reportGroupDoodle(doodleId: String, reasonCode: String) async {
        guard let profileId else { return }
        inboxDoodles.removeAll { $0.id == doodleId }
        do {
            _ = try await SupabaseService.shared.reportContent(
                profileId: profileId,
                profilePairingCode: pairingCode,
                kind: "group_doodle",
                contentId: doodleId,
                reason: reasonCode
            )
            await refreshInbox(force: true)
        } catch {
            errorMessage = UserFacingError.message(for: error, language: selectedLanguage)
        }
    }

    @MainActor
    private func blockGroupSender(senderProfileId: String, lastSeenDoodleId: String) async {
        guard let profileId else { return }
        inboxDoodles.removeAll { $0.senderProfileId == senderProfileId }
        do {
            _ = try? await SupabaseService.shared.reportContent(
                profileId: profileId,
                profilePairingCode: pairingCode,
                kind: "group_doodle",
                contentId: lastSeenDoodleId,
                reason: "blocked_user"
            )
            try await SupabaseService.shared.blockProfile(
                profileId: profileId,
                profilePairingCode: pairingCode,
                blockedProfileId: senderProfileId
            )
            await refreshInbox(force: true)
        } catch {
            errorMessage = UserFacingError.message(for: error, language: selectedLanguage)
        }
    }

    @MainActor
    private func reportAnonymousDoodle(doodleId: String, reasonCode: String) async {
        guard let profileId else { return }
        anonymousInboxDoodles.removeAll { $0.id == doodleId }
        do {
            _ = try await SupabaseService.shared.reportContent(
                profileId: profileId,
                profilePairingCode: pairingCode,
                kind: "anonymous_doodle",
                contentId: doodleId,
                reason: reasonCode
            )
            await refreshAnonymousInbox(force: true)
        } catch {
            errorMessage = UserFacingError.message(for: error, language: selectedLanguage)
        }
    }

    @MainActor
    private func blockAnonymousSender(senderFingerprint: String, lastSeenDoodleId: String) async {
        guard let profileId else { return }
        anonymousInboxDoodles.removeAll { $0.senderFingerprint == senderFingerprint }
        do {
            _ = try? await SupabaseService.shared.reportContent(
                profileId: profileId,
                profilePairingCode: pairingCode,
                kind: "anonymous_doodle",
                contentId: lastSeenDoodleId,
                reason: "blocked_sender"
            )
            try await SupabaseService.shared.blockAnonymousSender(
                profileId: profileId,
                profilePairingCode: pairingCode,
                senderFingerprint: senderFingerprint
            )
            await refreshAnonymousInbox(force: true)
        } catch {
            errorMessage = UserFacingError.message(for: error, language: selectedLanguage)
        }
    }

			    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
			        content()
			            .padding(14)
			            .frame(maxWidth: .infinity, alignment: .leading)
			            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
			            .overlay(
			                RoundedRectangle(cornerRadius: 22, style: .continuous)
			                    .stroke(Color.primary.opacity(0.10), lineWidth: 1)
			            )
			    }

	    private var anonymousSendTitle: String {
	        switch selectedLanguage {
	        case .english: "send anonymous"
	        case .dutch: "stuur anoniem"
	        case .german: "anonym senden"
	        case .spanish: "enviar anónimo"
	        }
	    }

	    private var anonymousSendSubtitle: String {
	        switch selectedLanguage {
	        case .english: "pick a username and send a doodl"
	        case .dutch: "kies een username en stuur een doodl"
	        case .german: "username wählen und doodl senden"
	        case .spanish: "elige un usuario y envía un doodl"
	        }
	    }

	    private var anonymousSendButtonTitle: String {
	        switch selectedLanguage {
	        case .english: "send a doodl"
	        case .dutch: "stuur doodl"
	        case .german: "doodl senden"
	        case .spanish: "enviar doodl"
	        }
	    }

	    private var groupPickerNavTitle: String {
	        switch selectedLanguage {
	        case .english: "groups"
	        case .dutch: "groepen"
	        case .german: "gruppen"
	        case .spanish: "grupos"
	        }
	    }

	    private var groupPickerTitle: String {
	        switch selectedLanguage {
	        case .english: "switch group"
	        case .dutch: "groep wisselen"
	        case .german: "gruppe wechseln"
	        case .spanish: "cambiar grupo"
	        }
	    }

	    private var groupPickerSubtitle: String {
	        switch selectedLanguage {
	        case .english: "your doodls always send to the active group."
	        case .dutch: "je doodls gaan altijd naar de actieve groep."
	        case .german: "deine doodls gehen immer an die aktive gruppe."
	        case .spanish: "tus doodls siempre van al grupo activo."
	        }
	    }

	    private var groupsSectionTitle: String {
	        switch selectedLanguage {
	        case .english: "your groups"
	        case .dutch: "jouw groepen"
	        case .german: "deine gruppen"
	        case .spanish: "tus grupos"
	        }
	    }

	    private var addGroupSectionTitle: String {
	        switch selectedLanguage {
	        case .english: "add a group"
	        case .dutch: "groep toevoegen"
	        case .german: "gruppe hinzufügen"
	        case .spanish: "agregar grupo"
	        }
	    }

	    private var yourGroupTitle: String {
	        switch selectedLanguage {
	        case .english: "your group"
	        case .dutch: "jouw groep"
	        case .german: "deine gruppe"
	        case .spanish: "tu grupo"
	        }
	    }

	    private var yourGroupSubtitle: String {
	        switch selectedLanguage {
	        case .english: "default group (private)"
	        case .dutch: "standaard groep (privé)"
	        case .german: "standardgruppe (privat)"
	        case .spanish: "grupo predeterminado (privado)"
	        }
	    }

	    private var otherGroupTitle: String {
	        switch selectedLanguage {
	        case .english: "group"
	        case .dutch: "groep"
	        case .german: "gruppe"
	        case .spanish: "grupo"
	        }
	    }

	    private var otherGroupSubtitle: String {
	        switch selectedLanguage {
	        case .english: "tap to switch"
	        case .dutch: "tik om te wisselen"
	        case .german: "tippen zum wechseln"
	        case .spanish: "toca para cambiar"
	        }
	    }

	    private var groupPickerJoinPlaceholder: String {
	        switch selectedLanguage {
	        case .english: "enter code"
	        case .dutch: "code invullen"
	        case .german: "code eingeben"
	        case .spanish: "ingresa código"
	        }
	    }

	    private var groupPickerJoinButtonTitle: String {
	        switch selectedLanguage {
	        case .english: "join"
	        case .dutch: "join"
	        case .german: "beitreten"
	        case .spanish: "unirse"
	        }
	    }

	    private var groupPickerCreateButtonTitle: String {
	        switch selectedLanguage {
	        case .english: "create new group (pro)"
	        case .dutch: "nieuwe groep maken (pro)"
	        case .german: "neue gruppe erstellen (pro)"
	        case .spanish: "crear grupo nuevo (pro)"
	        }
	    }

	    private var proRequiredForGroupsTitle: String {
	        switch selectedLanguage {
	        case .english: "pro required for multiple groups"
	        case .dutch: "pro nodig voor meerdere groepen"
	        case .german: "pro für mehrere gruppen nötig"
	        case .spanish: "pro necesario para varios grupos"
	        }
	    }

	    private func createdSuccessTitle(_ code: String) -> String {
	        switch selectedLanguage {
	        case .english: "created \(code.uppercased())"
	        case .dutch: "\(code.uppercased()) gemaakt"
	        case .german: "\(code.uppercased()) erstellt"
	        case .spanish: "\(code.uppercased()) creado"
	        }
	    }

	    private func joinedSuccessTitle(_ code: String) -> String {
	        switch selectedLanguage {
	        case .english: "joined \(code.uppercased())"
	        case .dutch: "\(code.uppercased()) gejoined"
	        case .german: "\(code.uppercased()) beigetreten"
	        case .spanish: "unido a \(code.uppercased())"
	        }
	    }

	    private func leftSuccessTitle(_ code: String) -> String {
	        switch selectedLanguage {
	        case .english: "left \(code.uppercased())"
	        case .dutch: "\(code.uppercased()) verlaten"
	        case .german: "\(code.uppercased()) verlassen"
	        case .spanish: "saliste de \(code.uppercased())"
	        }
	    }

	    private var copyTitle: String {
	        switch selectedLanguage {
	        case .english: "copy"
	        case .dutch: "kopiëren"
	        case .german: "kopieren"
	        case .spanish: "copiar"
	        }
	    }

	    private var leaveTitle: String {
	        switch selectedLanguage {
	        case .english: "leave"
	        case .dutch: "verlaten"
	        case .german: "verlassen"
	        case .spanish: "salir"
	        }
	    }

	    private var copiedTitle: String {
	        switch selectedLanguage {
	        case .english: "copied"
	        case .dutch: "gekopieerd"
	        case .german: "kopiert"
	        case .spanish: "copiado"
	        }
	    }

		    private func groupPickerRow(
	        title: String,
	        subtitle: String,
	        code: String,
	        isSelected: Bool,
	        canLeave: Bool,
	        onTap: @escaping () -> Void,
	        onLeave: (() -> Void)? = nil
	    ) -> some View {
	        let normalized = normalizeGroupCode(code)
	        let count = groupMemberCounts[normalized]?.count
	        let max = groupMemberCounts[normalized]?.max ?? 15

		        return HStack(spacing: 12) {
		            VStack(alignment: .leading, spacing: 2) {
		                Text(title)
		                    .font(.system(size: 12, weight: .semibold, design: .rounded))
		                    .foregroundStyle(.secondary.opacity(0.85))
		                Text(subtitle)
		                    .font(.system(size: 11, weight: .semibold, design: .rounded))
		                    .foregroundStyle(.secondary.opacity(0.70))
		                Text(code.uppercased())
		                    .font(.system(size: 16, weight: .heavy, design: .rounded))
		                    .foregroundStyle(.primary.opacity(0.92))
		                    .lineLimit(1)
		            }
		            Spacer()
		            if let count {
		                Text("\(count)/\(max)")
		                    .font(.system(size: 12, weight: .heavy, design: .rounded))
		                    .foregroundStyle(.primary.opacity(0.88))
		                    .padding(.vertical, 6)
		                    .padding(.horizontal, 10)
		                    .background(Color.primary.opacity(0.06), in: Capsule(style: .continuous))
		                    .overlay(
		                        Capsule(style: .continuous)
		                            .stroke(Color.primary.opacity(0.10), lineWidth: 1)
		                    )
		            }
		            Button {
		                UIPasteboard.general.string = code.uppercased()
		                Haptics.success()
		                groupPickerSuccess = copiedTitle
		            } label: {
		                Image(systemName: "doc.on.doc")
		                    .font(.system(size: 14, weight: .bold))
		                    .foregroundStyle(Color.primary.opacity(0.82))
		                    .padding(10)
		                    .background(Color.primary.opacity(0.06), in: Circle())
		            }
	            .buttonStyle(.plain)
	            .accessibilityLabel(Text(copyTitle))

		            if canLeave, let onLeave {
		                Button {
		                    Haptics.warning()
		                    onLeave()
		                } label: {
		                    Image(systemName: "rectangle.portrait.and.arrow.right")
		                        .font(.system(size: 14, weight: .bold))
		                        .foregroundStyle(Color.primary.opacity(0.82))
		                        .padding(10)
		                        .background(Color.primary.opacity(0.06), in: Circle())
		                }
	                .buttonStyle(.plain)
	                .accessibilityLabel(Text(leaveTitle))
	            }

		            if isSelected {
		                Image(systemName: "checkmark.circle.fill")
		                    .font(.system(size: 18, weight: .bold))
		                    .foregroundStyle(Color.primary.opacity(0.82))
		            } else {
		                Image(systemName: "chevron.right")
		                    .font(.system(size: 14, weight: .bold))
		                    .foregroundStyle(Color.secondary.opacity(0.65))
		            }
		        }
		        .padding(.vertical, 12)
		        .padding(.horizontal, 14)
		        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
		        .overlay(
		            RoundedRectangle(cornerRadius: 18, style: .continuous)
		                .stroke(Color.primary.opacity(0.10), lineWidth: 1)
		        )
	        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
	        .onTapGesture {
	            onTap()
	        }
	    }

	}


			private struct InboxDoodleViewer: View {
			    let doodleId: String
			    let image: UIImage?
			    let senderUsername: String
			    let senderProfileId: String?
			    let anonymousSenderFingerprint: String?
			    let language: AppLanguage
		    let createdAt: Date?
			    let onReport: (String) -> Void
			    let onBlock: () -> Void

		    @Environment(\.dismiss) private var dismiss
            @EnvironmentObject private var purchaseManager: PurchaseManager
		    @State private var zoom: CGFloat = 1
		    @State private var lastZoom: CGFloat = 1
		    @State private var showingActions = false
		    @State private var showingReportReasons = false
		    @State private var showingBlockConfirm = false
            @State private var showingShareSheet = false
            @State private var shareItems: [Any] = []
            @State private var showingProPaywall = false
            @State private var toastText: String?

			    private var canBlock: Bool {
			        if let senderProfileId, !senderProfileId.isEmpty { return true }
			        if let anonymousSenderFingerprint, !anonymousSenderFingerprint.isEmpty { return true }
			        return false
			    }

			private var closeTitle: String {
			    switch language {
			    case .dutch: return "sluiten"
			    case .german: return "schließen"
			    case .spanish: return "cerrar"
		    case .english: return "close"
		    }
		}

		    private var actionsTitle: String {
		        switch language {
		        case .english: return "actions"
		        case .dutch: return "acties"
		        case .german: return "aktionen"
		        case .spanish: return "acciones"
		        }
		    }

	            private var shareTitle: String {
	                switch language {
	                case .english: return "share"
	                case .dutch: return "delen"
	                case .german: return "teilen"
	                case .spanish: return "compartir"
	                }
	            }

            private var saveTitle: String {
                switch language {
                case .english: return "save to photos"
                case .dutch: return "opslaan in foto's"
                case .german: return "in fotos speichern"
                case .spanish: return "guardar en fotos"
                }
            }

            private var proRequiredTitle: String {
                switch language {
                case .english: return "pro required"
                case .dutch: return "pro nodig"
                case .german: return "pro benötigt"
                case .spanish: return "pro requerido"
                }
            }

            private var savedTitle: String {
                switch language {
                case .english: return "saved"
                case .dutch: return "opgeslagen"
                case .german: return "gespeichert"
                case .spanish: return "guardado"
                }
            }

		    private var reportTitle: String {
		        switch language {
		        case .english: return "report"
		        case .dutch: return "rapporteren"
		        case .german: return "melden"
		        case .spanish: return "denunciar"
		        }
		    }

		    private var blockTitle: String {
		        switch language {
		        case .english: return "block"
		        case .dutch: return "blokkeren"
		        case .german: return "blockieren"
		        case .spanish: return "bloquear"
		        }
		    }

		    private var blockConfirmTitle: String {
		        switch language {
		        case .english: return "block this sender?"
		        case .dutch: return "deze afzender blokkeren?"
		        case .german: return "diesen absender blockieren?"
		        case .spanish: return "¿bloquear a este remitente?"
		        }
		    }

		    private var blockConfirmActionTitle: String {
		        switch language {
		        case .english: return "block sender"
		        case .dutch: return "blokkeer afzender"
		        case .german: return "absender blockieren"
		        case .spanish: return "bloquear remitente"
		        }
		    }

		    private var reportReasons: [(code: String, title: String)] {
		        switch language {
		        case .english:
		            return [("spam", "spam"), ("harassment", "harassment"), ("hate", "hate"), ("sexual", "sexual"), ("violence", "violence"), ("other", "other")]
		        case .dutch:
		            return [("spam", "spam"), ("harassment", "pesten"), ("hate", "haat"), ("sexual", "seksueel"), ("violence", "geweld"), ("other", "anders")]
		        case .german:
		            return [("spam", "spam"), ("harassment", "belästigung"), ("hate", "hass"), ("sexual", "sexuell"), ("violence", "gewalt"), ("other", "sonstiges")]
		        case .spanish:
		            return [("spam", "spam"), ("harassment", "acoso"), ("hate", "odio"), ("sexual", "sexual"), ("violence", "violencia"), ("other", "otro")]
		        }
		    }

		    private var failedTitle: String {
			    switch language {
			    case .dutch: return "kon niet laden"
			    case .german: return "konnte nicht laden"
		    case .spanish: return "no se pudo cargar"
			    case .english: return "failed to load"
			    }
			}

		    var body: some View {
		        ZStack {
		            Color.black.opacity(0.92).ignoresSafeArea()

	            VStack(spacing: 12) {
	                HStack {
	                    Button {
	                        dismiss()
	                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                            Text(closeTitle)
                                .font(.system(size: 14, weight: .heavy, design: .rounded))
                        }
                        .foregroundStyle(.white)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(.white.opacity(0.10), in: Capsule(style: .continuous))
                    }
	                    .buttonStyle(.plain)

	                    Spacer()

	                    Button {
	                        Haptics.tap(.light)
	                        showingActions = true
	                    } label: {
	                        Image(systemName: "ellipsis")
	                            .font(.system(size: 16, weight: .bold))
	                            .foregroundStyle(.white.opacity(0.92))
	                            .padding(10)
	                            .background(.white.opacity(0.10), in: Circle())
	                    }
	                    .buttonStyle(.plain)

	                    Text("@\(senderUsername)")
	                        .font(.system(size: 14, weight: .heavy, design: .rounded))
	                        .foregroundStyle(.white.opacity(0.9))
	                }
                .padding(.horizontal, 16)
                .padding(.top, 6)

		                if let createdAt {
		                    Text(timeAgo(createdAt))
		                        .font(.system(size: 12, weight: .semibold, design: .rounded))
		                        .foregroundStyle(.white.opacity(0.75))
		                }

		                Spacer(minLength: 0)

	                Group {
	                    if let image {
	                        Image(uiImage: image)
                            .renderingMode(.original)
                            .resizable()
                            .scaledToFit()
                            .scaleEffect(zoom)
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        zoom = min(4, max(1, lastZoom * value))
                                    }
		                                    .onEnded { _ in
		                                        lastZoom = zoom
		                                    }
		                            )
		                            .padding(16)
	                    } else {
	                        Text(failedTitle)
	                            .font(.system(size: 14, weight: .bold, design: .rounded))
	                            .foregroundStyle(.white.opacity(0.8))
	                            .padding(16)
                    }
                }
                .frame(maxWidth: .infinity)

	                Spacer(minLength: 0)
	            }
	        }
            .overlay(alignment: .top) {
                if let toastText {
                    Text(toastText)
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(.black.opacity(0.35), in: Capsule(style: .continuous))
                        .overlay(Capsule(style: .continuous).stroke(.white.opacity(0.14), lineWidth: 1))
                        .padding(.top, 12)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
		        .confirmationDialog(actionsTitle, isPresented: $showingActions) {
	                if image != nil {
	                    Button(shareTitle) { shareCurrent() }
	                    Button(saveTitle) { saveCurrent() }
	                }
		            Button(reportTitle) { showingReportReasons = true }
		            if canBlock {
	                Button(blockTitle, role: .destructive) { showingBlockConfirm = true }
	            }
	            Button(closeTitle, role: .cancel) {}
	        }
	        .confirmationDialog(reportTitle, isPresented: $showingReportReasons) {
	            ForEach(reportReasons, id: \.code) { reason in
	                Button(reason.title) {
	                    Haptics.tap(.light)
	                    onReport(reason.code)
	                    dismiss()
	                }
	            }
	            Button(closeTitle, role: .cancel) {}
	        }
			        .confirmationDialog(blockConfirmTitle, isPresented: $showingBlockConfirm) {
			            Button(blockConfirmActionTitle, role: .destructive) {
			                Haptics.tap(.heavy)
			                onBlock()
			                dismiss()
			            }
			            Button(closeTitle, role: .cancel) {}
			        }
            .sheet(isPresented: $showingShareSheet) {
                ActivityView(items: shareItems)
            }
            .sheet(isPresented: $showingProPaywall) {
                ProPaywallView(language: language)
                    .environmentObject(purchaseManager)
            }
			    }

	    private func timeAgo(_ date: Date) -> String {
	        let formatter = RelativeDateTimeFormatter()
	        formatter.unitsStyle = .abbreviated
	        formatter.locale = Locale(identifier: language.rawValue)
        return formatter.localizedString(for: date, relativeTo: Date()).lowercased()
    }

            private func showToast(_ text: String) {
                withAnimation(.easeOut(duration: 0.2)) { toastText = text }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    withAnimation(.easeOut(duration: 0.2)) { toastText = nil }
                }
            }

	            private func shareCurrent() {
	                guard let image else { return }
	                Haptics.tap(.light)
	                shareItems = [image]
	                showingShareSheet = true
	            }

	            private func saveCurrent() {
	                guard let image else { return }
	                guard purchaseManager.isPro else {
	                    Haptics.warning()
                    showToast(proRequiredTitle)
                    showingProPaywall = true
                    return
                }

                Haptics.tap(.medium)
                PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                    guard status == .authorized || status == .limited else {
                        DispatchQueue.main.async { showToast("no permission") }
                        return
                    }
                    UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                    DispatchQueue.main.async { showToast(savedTitle) }
                }
            }
		}

	    private struct EditUsernameSheet: View {
	        let language: AppLanguage
	        let profileId: String?
	        let profilePairingCode: String
	        let currentUsername: String
	        @Binding var errorText: String?
	        let onUpdated: (String) -> Void

	        @Environment(\.dismiss) private var dismiss
	        @Environment(\.colorScheme) private var colorScheme
	        @State private var draft: String = ""
	        @State private var isSaving = false

        private var title: String {
            switch language {
            case .english: "change username"
            case .dutch: "gebruikersnaam wijzigen"
            case .german: "benutzernamen ändern"
            case .spanish: "cambiar usuario"
            }
        }

	        private var subtitle: String {
	            switch language {
	            case .english: "max 12 chars • a–z, 0–9, underscore • no spaces"
	            case .dutch: "max 12 tekens • a–z, 0–9, underscore • geen spaties"
	            case .german: "max 12 zeichen • a–z, 0–9, underscore • keine leerzeichen"
	            case .spanish: "máx 12 • a–z, 0–9, guion bajo • sin espacios"
	            }
	        }

        private var saveTitle: String {
            switch language {
            case .english: "save"
            case .dutch: "opslaan"
            case .german: "speichern"
            case .spanish: "guardar"
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

	        private var invalidUsernameError: String {
	            switch language {
	            case .english: "invalid username"
	            case .dutch: "ongeldige gebruikersnaam"
	            case .german: "ungültiger benutzername"
	            case .spanish: "usuario inválido"
	            }
	        }

        private var usernameTakenError: String {
            switch language {
            case .english: "username already in use"
            case .dutch: "gebruikersnaam is al bezet"
            case .german: "benutzername ist schon vergeben"
            case .spanish: "usuario ya está en uso"
            }
        }

	        private var normalized: String { UsernameRules.sanitize(draft) }

	        private var canSave: Bool {
	            guard let profileId, !profileId.isEmpty else { return false }
	            let value = normalized
	            guard UsernameRules.isValid(value) else { return false }
	            return value != currentUsername.lowercased()
	        }

        var body: some View {
            NavigationStack {
                VStack(alignment: .leading, spacing: 14) {
                    Text(subtitle)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        Text("@")
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundStyle(.secondary)

	                        TextField("@\(currentUsername)", text: $draft)
	                            .textInputAutocapitalization(.never)
	                            .autocorrectionDisabled(true)
	                            .keyboardType(.asciiCapable)
	                            .font(.system(size: 18, weight: .heavy, design: .rounded))
	                            .onChange(of: draft) { _, newValue in
	                                let sanitized = UsernameRules.sanitize(newValue)
	                                if sanitized != newValue {
	                                    draft = sanitized
	                                }
	                                errorText = nil
	                            }
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 14)
                    .background(.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(.secondary.opacity(0.18), lineWidth: 1)
                    )

                    if let errorText, !errorText.isEmpty {
                        Text(errorText)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.red.opacity(0.22), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    Spacer(minLength: 0)
                }
	                .padding(16)
		                .navigationTitle(title)
		                .navigationBarTitleDisplayMode(.inline)
		                .toolbarBackground(.hidden, for: .navigationBar)
		                .toolbarColorScheme(colorScheme, for: .navigationBar)
		                .toolbar {
	                    ToolbarItem(placement: .cancellationAction) {
	                        Button(cancelTitle) {
	                            Haptics.tap()
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(saveTitle) {
                            Task { await save() }
                        }
                        .disabled(!canSave || isSaving)
                    }
                }
            }
            .onAppear {
                Haptics.prepare()
                draft = currentUsername
                errorText = nil
            }
        }

        @MainActor
	        private func save() async {
	            guard let profileId, !profileId.isEmpty else { return }
	            if isSaving { return }
	            let value = normalized
	            guard UsernameRules.isValid(value) else {
	                Haptics.warning()
	                errorText = invalidUsernameError
	                return
	            }
	            if value == currentUsername.lowercased() {
	                Haptics.selectionChanged()
	                dismiss()
	                return
	            }

	            isSaving = true
	            Haptics.tap(.medium)
	            do {
	                let available = try await SupabaseService.shared.isUsernameAvailable(value)
	                guard available else {
	                    Haptics.warning()
	                    errorText = usernameTakenError
	                    isSaving = false
	                    return
	                }
	                try await SupabaseService.shared.updateUsername(profileId: profileId, profilePairingCode: profilePairingCode, username: value)
	                Haptics.success()
	                onUpdated(value)
	                dismiss()
		            } catch {
	                Haptics.error()
	                errorText = UserFacingError.message(for: error, language: language)
	            }
	            isSaving = false
	        }
	    }

struct WidgetHelpView: View {
    let language: AppLanguage

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private struct Step: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let subtitle: String
    }

    private var title: String {
        switch language {
        case .english: "add the widget"
        case .dutch: "widget toevoegen"
        case .german: "widget hinzufügen"
        case .spanish: "añadir widget"
        }
    }

    private var subtitle: String {
        switch language {
        case .english: "pin your latest doodl to your home screen"
        case .dutch: "zet je nieuwste doodl op je beginscherm"
        case .german: "pinne dein neuestes doodl auf den homescreen"
        case .spanish: "fija tu doodl más reciente en la pantalla de inicio"
        }
    }

    private var tipTitle: String {
        switch language {
        case .english: "tip"
        case .dutch: "tip"
        case .german: "tipp"
        case .spanish: "consejo"
        }
    }

    private var tipBody: String {
        switch language {
        case .english: "if the widget is empty, open DOODL. once and receive a doodl."
        case .dutch: "als de widget leeg is, open DOODL. één keer en ontvang een doodl."
        case .german: "wenn das widget leer ist, öffne DOODL. einmal und erhalte ein doodl."
        case .spanish: "si el widget está vacío, abre DOODL. una vez y recibe un doodl."
        }
    }

    private var steps: [Step] {
        [
            Step(
                icon: "hand.tap",
                title: step1Title,
                subtitle: step1Body
            ),
            Step(
                icon: "plus.circle.fill",
                title: step2Title,
                subtitle: step2Body
            ),
            Step(
                icon: "magnifyingglass",
                title: step3Title,
                subtitle: step3Body
            ),
            Step(
                icon: "square.grid.2x2.fill",
                title: step4Title,
                subtitle: step4Body
            )
        ]
    }

    private var step1Title: String {
        switch language {
        case .english: "1. long‑press your home screen"
        case .dutch: "1. houd je beginscherm ingedrukt"
        case .german: "1. homescreen gedrückt halten"
        case .spanish: "1. mantén pulsada la pantalla"
        }
    }

    private var step1Body: String {
        switch language {
        case .english: "wait for the icons to wiggle"
        case .dutch: "wacht tot alles gaat wiebelen"
        case .german: "warte, bis die icons wackeln"
        case .spanish: "espera a que los iconos se muevan"
        }
    }

    private var step2Title: String {
        switch language {
        case .english: "2. tap “edit” or the +"
        case .dutch: "2. tik op “wijzig” of +"
        case .german: "2. tippe auf „bearbeiten“ oder +"
        case .spanish: "2. toca “editar” o el +"
        }
    }

    private var step2Body: String {
        switch language {
        case .english: "then choose “add widget”"
        case .dutch: "kies daarna “voeg widget toe”"
        case .german: "dann „widget hinzufügen“"
        case .spanish: "luego elige “añadir widget”"
        }
    }

    private var step3Title: String {
        switch language {
        case .english: "3. search for DOODL."
        case .dutch: "3. zoek op DOODL."
        case .german: "3. suche nach DOODL."
        case .spanish: "3. busca DOODL."
        }
    }

    private var step3Body: String {
        switch language {
        case .english: "select the DOODL. widget"
        case .dutch: "selecteer de DOODL. widget"
        case .german: "wähle das DOODL.-widget"
        case .spanish: "selecciona el widget de DOODL."
        }
    }

    private var step4Title: String {
        switch language {
        case .english: "4. pick a size and add it"
        case .dutch: "4. kies een formaat en voeg toe"
        case .german: "4. größe wählen und hinzufügen"
        case .spanish: "4. elige tamaño y añade"
        }
    }

    private var step4Body: String {
        switch language {
        case .english: "done — it updates automatically"
        case .dutch: "klaar — hij update automatisch"
        case .german: "fertig — es aktualisiert automatisch"
        case .spanish: "listo — se actualiza solo"
        }
    }

		    var body: some View {
		        ZStack {
		            ThemedBackground()

		            ScrollView(showsIndicators: false) {
		                VStack(spacing: 14) {
		                    VStack(spacing: 8) {
	                        Text(title)
	                            .font(.system(size: 26, weight: .heavy, design: .rounded))
	                            .foregroundStyle(.primary.opacity(0.92))
	                        Text(subtitle)
	                            .font(.system(size: 15, weight: .semibold, design: .rounded))
	                            .foregroundStyle(.secondary.opacity(0.85))
	                            .multilineTextAlignment(.center)
	                    }
	                    .padding(.top, 8)

	                    VStack(spacing: 10) {
	                        ForEach(steps) { step in
	                            stepRow(icon: step.icon, title: step.title, subtitle: step.subtitle)
	                        }
	                    }

	                    tipCard

	                    Button {
	                        Haptics.tap()
	                        dismiss()
	                    } label: {
	                        Text(backToAppTitle)
	                            .font(.system(size: 16, weight: .heavy, design: .rounded))
	                            .foregroundStyle(.white.opacity(0.96))
	                            .frame(maxWidth: .infinity)
	                            .padding(.vertical, 14)
		                            .background(.black.opacity(0.88), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
		                            .overlay(
		                                RoundedRectangle(cornerRadius: 18, style: .continuous)
		                                    .stroke(.white.opacity(0.14), lineWidth: 1)
		                            )
	                    }
	                    .buttonStyle(.plain)
	                    .padding(.top, 6)
	                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 28)
            }
	        }
	        .navigationTitle(title)
	        .navigationBarTitleDisplayMode(.inline)
	        .toolbarBackground(.hidden, for: .navigationBar)
	        .toolbarColorScheme(colorScheme, for: .navigationBar)
	        .onAppear { Haptics.prepare() }
	    }

    private var backToAppTitle: String {
        switch language {
        case .english: "back to DOODL."
        case .dutch: "terug naar DOODL."
        case .german: "zurück zu DOODL."
        case .spanish: "volver a DOODL."
        }
    }

		    private func stepRow(icon: String, title: String, subtitle: String) -> some View {
		        HStack(alignment: .top, spacing: 12) {
		            Image(systemName: icon)
		                .font(.system(size: 16, weight: .bold))
		                .foregroundStyle(Color.primary.opacity(0.82))
		                .frame(width: 28, height: 28)
		                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
		                .overlay(
		                    RoundedRectangle(cornerRadius: 10, style: .continuous)
		                        .stroke(Color.primary.opacity(0.10), lineWidth: 1)
		                )

	            VStack(alignment: .leading, spacing: 4) {
	                Text(title)
	                    .font(.system(size: 15, weight: .heavy, design: .rounded))
	                    .foregroundStyle(.primary.opacity(0.92))
	                Text(subtitle)
	                    .font(.system(size: 13, weight: .semibold, design: .rounded))
	                    .foregroundStyle(.secondary.opacity(0.85))
	            }

	            Spacer(minLength: 0)
	        }
	        .padding(.vertical, 12)
	        .padding(.horizontal, 12)
	        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
		        .overlay(
		            RoundedRectangle(cornerRadius: 16, style: .continuous)
		                .stroke(Color.primary.opacity(0.10), lineWidth: 1)
		        )
		    }

	    private var tipCard: some View {
	        VStack(alignment: .leading, spacing: 8) {
	            HStack(spacing: 8) {
	                Image(systemName: "lightbulb.fill")
	                    .font(.system(size: 14, weight: .bold))
	                    .foregroundStyle(.yellow.opacity(0.95))
	                Text(tipTitle)
	                    .font(.system(size: 13, weight: .heavy, design: .rounded))
	                    .foregroundStyle(.primary.opacity(0.92))
	                Spacer()
	            }

	            Text(tipBody)
	                .font(.system(size: 13, weight: .semibold, design: .rounded))
	                .foregroundStyle(.secondary.opacity(0.85))
	        }
	        .padding(.vertical, 12)
	        .padding(.horizontal, 12)
	        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
	        .overlay(
	            RoundedRectangle(cornerRadius: 16, style: .continuous)
	                .stroke(Color.primary.opacity(0.10), lineWidth: 1)
	        )
	    }
}

private struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

enum DashboardTab {
    case share
    case inbox
    case pro
}

enum InboxSource {
    case chats
    case group
    case anonymous
}

#if canImport(PreviewsMacros)
#Preview {
    NavigationStack {
	        DashboardView(
	            path: .constant([.dashboard]),
	            selectedLanguage: .constant(.dutch),
	            pairingCode: .constant("a1b2c3d4"),
	            username: .constant("anthony"),
	            avatarURL: .constant(nil),
	            profileId: .constant("00000000-0000-0000-0000-000000000000"),
	            joinedCode: .constant(nil),
	            resetOnboarding: {}
	        )
    }
    .environmentObject(PurchaseManager())
}
#endif
