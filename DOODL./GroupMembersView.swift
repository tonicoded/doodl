import SwiftUI
import UIKit

private enum GroupMembersTab {
    case group
    case invites
}

struct GroupMembersView: View {
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Environment(\.colorScheme) private var colorScheme
    let language: AppLanguage
    let ownCode: String
    let activeCode: String
    let isUsingJoinedGroup: Bool
    let members: [GroupMemberProfile]
    let isLoading: Bool
    let errorMessage: String?
    let onRefreshMembers: () -> Void
    let canManageMembers: Bool
    let canLeaveGroup: Bool
    let currentProfileId: String?
    let anonymousLinkURL: String?
    let isAnonymousEnabled: Bool
    let isLoadingAnonymousLink: Bool
    let onToggleAnonymousLink: (Bool) -> Void
    let onRemoveMember: (String) -> Void
    let onLeaveGroup: () -> Void
    let onJoinGroup: (String) -> Void
    let onInviteUsername: (String) -> Void
    let canInvite: Bool
    let invites: [GroupInvite]
    let isLoadingInvites: Bool
    let invitesError: String?
    let onRefreshInvites: () -> Void
    let onRespondInvite: (String, Bool) -> Void
    @State private var confirmRemoveId: String? = nil
    @State private var confirmLeave: Bool = false
	    @State private var showingJoinPrompt: Bool = false
	    @State private var joinInput: String = ""
		    @State private var showingInviteSheet: Bool = false
	    @State private var selectedTab: GroupMembersTab = .group
	    @State private var showingProPaywall: Bool = false
        @State private var showingStreakInfo: Bool = false
        @State private var streakInfoCount: Int = 0

    init(
        language: AppLanguage,
        ownCode: String,
        activeCode: String,
        isUsingJoinedGroup: Bool,
        members: [GroupMemberProfile],
        isLoading: Bool,
        errorMessage: String?,
        onRefreshMembers: @escaping () -> Void,
        canManageMembers: Bool,
        canLeaveGroup: Bool,
        currentProfileId: String?,
        anonymousLinkURL: String?,
        isAnonymousEnabled: Bool,
        isLoadingAnonymousLink: Bool,
        onToggleAnonymousLink: @escaping (Bool) -> Void,
        onRemoveMember: @escaping (String) -> Void,
        onLeaveGroup: @escaping () -> Void,
        onJoinGroup: @escaping (String) -> Void,
        onInviteUsername: @escaping (String) -> Void,
        canInvite: Bool,
        invites: [GroupInvite],
        isLoadingInvites: Bool,
        invitesError: String?,
        onRefreshInvites: @escaping () -> Void,
        onRespondInvite: @escaping (String, Bool) -> Void
    ) {
        self.language = language
        self.ownCode = ownCode
        self.activeCode = activeCode
        self.isUsingJoinedGroup = isUsingJoinedGroup
        self.members = members
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self.onRefreshMembers = onRefreshMembers
        self.canManageMembers = canManageMembers
        self.canLeaveGroup = canLeaveGroup
        self.currentProfileId = currentProfileId
        self.anonymousLinkURL = anonymousLinkURL
        self.isAnonymousEnabled = isAnonymousEnabled
        self.isLoadingAnonymousLink = isLoadingAnonymousLink
        self.onToggleAnonymousLink = onToggleAnonymousLink
        self.onRemoveMember = onRemoveMember
        self.onLeaveGroup = onLeaveGroup
        self.onJoinGroup = onJoinGroup
        self.onInviteUsername = onInviteUsername
        self.canInvite = canInvite
        self.invites = invites
        self.isLoadingInvites = isLoadingInvites
        self.invitesError = invitesError
        self.onRefreshInvites = onRefreshInvites
        self.onRespondInvite = onRespondInvite
    }

			    var body: some View {
			        NavigationStack {
			            ZStack {
		                ThemedBackground()

		                ScrollView(showsIndicators: false) {
		                    VStack(alignment: .leading, spacing: 12) {
		                        codeCard
                            capacityCard
                            anonymousCard
	                        tabs

                        switch selectedTab {
                        case .group:
                            groupTab
                        case .invites:
                            invitesTab
                        }
                    }
	                    .padding(.horizontal, 16)
	                    .padding(.vertical, 16)
	                }
		            }
		            .navigationTitle(title)
		            .navigationBarTitleDisplayMode(.inline)
		            .toolbarBackground(.hidden, for: .navigationBar)
		            .toolbarColorScheme(colorScheme, for: .navigationBar)
		        }
	        .alert(removeTitle, isPresented: Binding(get: { confirmRemoveId != nil }, set: { if !$0 { confirmRemoveId = nil } })) {
	            Button(removeConfirmTitle, role: .destructive) {
                if let id = confirmRemoveId {
                    onRemoveMember(id)
                }
                confirmRemoveId = nil
            }
            Button(cancelTitle, role: .cancel) {
                confirmRemoveId = nil
            }
        } message: {
            Text(removeMessage)
        }
        .alert(leaveTitle, isPresented: $confirmLeave) {
            Button(leaveConfirmTitle, role: .destructive) { onLeaveGroup() }
            Button(cancelTitle, role: .cancel) {}
        } message: {
            Text(leaveMessage)
        }
        .alert(joinTitle, isPresented: $showingJoinPrompt) {
            TextField(joinPlaceholder, text: $joinInput)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button(joinConfirmTitle) {
                let code = joinInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                joinInput = ""
                onJoinGroup(code)
            }
            Button(cancelTitle, role: .cancel) {
                joinInput = ""
            }
        } message: {
            Text(joinMessage)
        }
        .alert(streakInfoTitle(count: streakInfoCount), isPresented: $showingStreakInfo) {
            Button(okTitle, role: .cancel) {}
        } message: {
            Text(streakInfoMessage)
        }
	        .sheet(isPresented: $showingInviteSheet) {
	            InviteUserSheet(
	                language: language,
	                excludeProfileId: currentProfileId,
                onInvite: { username in
                    onInviteUsername(username)
                }
            )
        }
        .sheet(isPresented: $showingProPaywall) {
            ProPaywallView(language: language)
                .environmentObject(purchaseManager)
        }
    }

	    private var tabs: some View {
	        HStack(spacing: 10) {
	            tabPill(title: groupTabTitle, isActive: selectedTab == .group) { selectedTab = .group }
	            tabPill(title: invitesTabTitle, isActive: selectedTab == .invites, badge: pendingInviteCount) { 
	                selectedTab = .invites
	                onRefreshInvites()
	            }
	        }
	        .padding(6)
	        .background(.thinMaterial, in: Capsule(style: .continuous))
	        .overlay(
	            Capsule(style: .continuous)
	                .stroke(.black.opacity(0.10), lineWidth: 1)
	        )
	    }

	    private func tabPill(title: String, isActive: Bool, badge: Int? = nil, action: @escaping () -> Void) -> some View {
	        Button(action: action) {
	            HStack(spacing: 8) {
	                Text(title)
	                    .font(.system(size: 15, weight: .heavy, design: .rounded))
	                    .foregroundStyle(isActive ? Color.white : Color.black.opacity(0.62))
	                if let badge, badge > 0 {
	                    Text("\(badge)")
	                        .font(.system(size: 12, weight: .heavy, design: .rounded))
	                        .foregroundStyle(isActive ? Color.white : Color.black.opacity(0.62))
	                        .padding(.vertical, 4)
	                        .padding(.horizontal, 8)
	                        .background(
	                            Capsule(style: .continuous).fill(isActive ? .white.opacity(0.18) : .black.opacity(0.06))
	                        )
	                }
	            }
	            .padding(.vertical, 10)
	            .padding(.horizontal, 14)
	            .background(
	                Group {
	                    if isActive {
	                        Capsule(style: .continuous).fill(.black.opacity(0.88))
	                    } else {
	                        Capsule(style: .continuous).fill(.clear)
	                    }
	                }
	            )
	        }
	        .buttonStyle(.plain)
	    }

	    private var groupTab: some View {
	        VStack(alignment: .leading, spacing: 12) {
		            HStack {
		                Text(membersTitle(count: members.count))
		                    .font(.system(size: 15, weight: .heavy, design: .rounded))
		                    .foregroundStyle(.primary.opacity(0.92))
		                Spacer()
		                Button {
		                    onRefreshMembers()
		                } label: {
		                    Image(systemName: "arrow.clockwise")
		                        .font(.system(size: 14, weight: .heavy))
		                        .foregroundStyle(.black.opacity(0.72))
		                        .padding(10)
		                        .background(.thinMaterial, in: Circle())
		                        .overlay(Circle().stroke(.black.opacity(0.10), lineWidth: 1))
		                }
	                .buttonStyle(.plain)
	                .accessibilityLabel(refreshTitle)
	                .disabled(isLoading)
	                if !isUsingJoinedGroup {
	                    Button {
	                        showingJoinPrompt = true
	                    } label: {
	                        Text(joinTitle)
	                            .font(.system(size: 13, weight: .heavy, design: .rounded))
	                            .foregroundStyle(.white)
	                            .padding(.vertical, 8)
	                            .padding(.horizontal, 12)
	                            .background(.black.opacity(0.88), in: Capsule(style: .continuous))
	                    }
	                    .buttonStyle(.plain)
	                }
	                if canInvite {
	                    Button {
	                        showingInviteSheet = true
	                    } label: {
	                        Image(systemName: "plus")
	                            .font(.system(size: 14, weight: .heavy))
	                            .foregroundStyle(.white)
	                            .padding(10)
	                            .background(.black.opacity(0.88), in: Circle())
	                    }
	                    .buttonStyle(.plain)
	                    .accessibilityLabel(inviteTitle)
	                }
	            }

	            if isLoading {
	                HStack(spacing: 10) {
	                    ProgressView()
	                        .tint(.black.opacity(0.65))
	                    Text(loadingTitle)
	                        .font(.system(size: 15, weight: .bold, design: .rounded))
	                        .foregroundStyle(.secondary.opacity(0.85))
	                }
	                .padding(14)
	                .frame(maxWidth: .infinity, alignment: .leading)
	                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
	                .overlay(
	                    RoundedRectangle(cornerRadius: 18, style: .continuous)
	                        .stroke(.black.opacity(0.10), lineWidth: 1)
	                )
	            } else if let errorMessage, !errorMessage.isEmpty {
	                Text(errorMessage)
	                    .font(.system(size: 14, weight: .semibold, design: .rounded))
	                    .foregroundStyle(.black.opacity(0.88))
	                    .padding(.vertical, 10)
	                    .padding(.horizontal, 12)
	                    .frame(maxWidth: .infinity, alignment: .leading)
	                    .background(.red.opacity(0.16), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
	            } else if members.isEmpty {
	                Text(emptyTitle)
	                    .font(.system(size: 15, weight: .bold, design: .rounded))
	                    .foregroundStyle(.secondary.opacity(0.85))
	                    .padding(14)
	                    .frame(maxWidth: .infinity, alignment: .leading)
	                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
	                    .overlay(
	                        RoundedRectangle(cornerRadius: 18, style: .continuous)
	                            .stroke(.black.opacity(0.10), lineWidth: 1)
	                    )
	                if !isUsingJoinedGroup {
	                    Button {
	                        showingJoinPrompt = true
	                    } label: {
	                        HStack(spacing: 10) {
	                            Image(systemName: "person.2.fill")
	                                .font(.system(size: 16, weight: .bold))
	                            Text(joinCtaTitle)
	                                .font(.system(size: 16, weight: .heavy, design: .rounded))
	                            Spacer()
	                        }
	                        .foregroundStyle(.white.opacity(0.95))
	                        .padding(.vertical, 14)
	                        .padding(.horizontal, 16)
	                        .frame(maxWidth: .infinity)
	                        .background(.black.opacity(0.88), in: Capsule(style: .continuous))
	                        .overlay(
	                            Capsule(style: .continuous)
	                                .stroke(.black.opacity(0.10), lineWidth: 1)
	                        )
	                    }
	                    .buttonStyle(.plain)
	                }
	            } else {
	                ForEach(members) { member in
	                    memberRow(member)
	                }
	            }

	            if canLeaveGroup {
	                Button(role: .destructive) {
	                    confirmLeave = true
	                } label: {
	                    HStack(spacing: 10) {
	                        Image(systemName: "rectangle.portrait.and.arrow.right")
	                            .font(.system(size: 16, weight: .bold))
	                        Text(leaveTitle)
	                            .font(.system(size: 16, weight: .heavy, design: .rounded))
	                        Spacer()
	                    }
	                    .foregroundStyle(.black.opacity(0.88))
	                    .padding(.vertical, 14)
	                    .padding(.horizontal, 16)
	                    .frame(maxWidth: .infinity)
	                    .background(.red.opacity(0.25), in: Capsule(style: .continuous))
	                    .overlay(
	                        Capsule(style: .continuous)
	                            .stroke(.black.opacity(0.10), lineWidth: 1)
	                    )
	                }
	                .buttonStyle(.plain)
	            }

	        }
    }

    private var invitesTab: some View {
	        VStack(alignment: .leading, spacing: 12) {
	            HStack {
	                Text(invitesTitle)
	                    .font(.system(size: 15, weight: .heavy, design: .rounded))
	                    .foregroundStyle(.white.opacity(0.92))
	                Spacer()
	                Button {
	                    onRefreshInvites()
	                } label: {
	                    Image(systemName: "arrow.clockwise")
	                        .font(.system(size: 14, weight: .heavy))
	                        .foregroundStyle(.white.opacity(0.9))
	                        .padding(10)
	                        .background(.white.opacity(0.10), in: Circle())
	                        .overlay(Circle().stroke(.white.opacity(0.12), lineWidth: 1))
	                }
	                .buttonStyle(.plain)
	                .accessibilityLabel(refreshTitle)
	                .disabled(isLoadingInvites)
	            }

	        if isLoadingInvites {
	                HStack(spacing: 10) {
	                    ProgressView().tint(.black.opacity(0.65))
	                    Text(invitesLoadingTitle)
	                        .font(.system(size: 14, weight: .bold, design: .rounded))
	                        .foregroundStyle(.secondary.opacity(0.85))
	                    Spacer()
	                }
	                .padding(14)
	                .frame(maxWidth: .infinity, alignment: .leading)
	                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
	                .overlay(
	                    RoundedRectangle(cornerRadius: 18, style: .continuous)
	                        .stroke(.black.opacity(0.10), lineWidth: 1)
	                )
	            } else if let invitesError, !invitesError.isEmpty {
	                Text(invitesError)
	                    .font(.system(size: 14, weight: .semibold, design: .rounded))
	                    .foregroundStyle(.black.opacity(0.88))
	                    .padding(.vertical, 10)
	                    .padding(.horizontal, 12)
	                    .frame(maxWidth: .infinity, alignment: .leading)
	                    .background(.red.opacity(0.16), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
	            } else if invites.isEmpty {
	                Text(invitesEmptyTitle)
	                    .font(.system(size: 15, weight: .bold, design: .rounded))
	                    .foregroundStyle(.secondary.opacity(0.85))
	                    .padding(14)
	                    .frame(maxWidth: .infinity, alignment: .leading)
	                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
	                    .overlay(
	                        RoundedRectangle(cornerRadius: 18, style: .continuous)
	                            .stroke(.black.opacity(0.10), lineWidth: 1)
	                    )
            } else {
                ForEach(invites) { invite in
                    inviteRow(invite)
                }
            }
        }
    }

	    private func inviteRow(_ invite: GroupInvite) -> some View {
	        VStack(alignment: .leading, spacing: 10) {
	            HStack {
	                Text("@\(invite.inviterUsername)")
	                    .font(.system(size: 15, weight: .heavy, design: .rounded))
	                    .foregroundStyle(.primary.opacity(0.92))
	                Spacer()
	                Text(invite.status.lowercased())
	                    .font(.system(size: 12, weight: .heavy, design: .rounded))
	                    .foregroundStyle(.secondary.opacity(0.75))
	            }

	            Text("\(groupTitle): \(invite.groupCode.lowercased())")
	                .font(.system(size: 13, weight: .semibold, design: .monospaced))
	                .foregroundStyle(.secondary.opacity(0.85))

            if invite.status == "pending" {
                HStack(spacing: 10) {
                    Button {
                        onRespondInvite(invite.id, false)
	                    } label: {
	                        Text(declineTitle)
	                            .font(.system(size: 14, weight: .heavy, design: .rounded))
	                            .foregroundStyle(.black.opacity(0.82))
	                            .frame(maxWidth: .infinity)
	                            .padding(.vertical, 10)
	                            .background(.thinMaterial, in: Capsule(style: .continuous))
	                            .overlay(
	                                Capsule(style: .continuous)
	                                    .stroke(.black.opacity(0.10), lineWidth: 1)
	                            )
	                    }
                    .buttonStyle(.plain)

                    Button {
                        onRespondInvite(invite.id, true)
	                    } label: {
	                        Text(acceptTitle)
	                            .font(.system(size: 14, weight: .heavy, design: .rounded))
	                            .foregroundStyle(.white.opacity(0.95))
	                            .frame(maxWidth: .infinity)
	                            .padding(.vertical, 10)
	                            .background(.black.opacity(0.88), in: Capsule(style: .continuous))
	                    }
                    .buttonStyle(.plain)
                }
            }
	        }
	        .padding(.vertical, 12)
	        .padding(.horizontal, 12)
	        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
	        .overlay(
	            RoundedRectangle(cornerRadius: 18, style: .continuous)
	                .stroke(.black.opacity(0.10), lineWidth: 1)
	        )
	    }

    private var pendingInviteCount: Int {
        invites.filter { $0.status == "pending" }.count
    }

	    private var anonymousCard: some View {
	        VStack(alignment: .leading, spacing: 10) {
	            Text(anonymousTitle)
	                .font(.system(size: 14, weight: .heavy, design: .rounded))
	                .foregroundStyle(.secondary.opacity(0.85))
	                .padding(.horizontal, 4)

            VStack(spacing: 10) {
                Toggle(isOn: Binding(
                    get: { isAnonymousEnabled },
                    set: { newValue in
                        Haptics.selectionChanged()
                        onToggleAnonymousLink(newValue)
                    }
                )) {
                    HStack(spacing: 12) {
	                        Image(systemName: "sparkles")
	                            .font(.system(size: 16, weight: .bold))
	                            .foregroundStyle(.black.opacity(0.70))
	                            .frame(width: 22)

                        VStack(alignment: .leading, spacing: 4) {
	                            Text(anonymousToggleTitle)
	                                .font(.system(size: 13, weight: .semibold, design: .rounded))
	                                .foregroundStyle(.secondary.opacity(0.85))
	                            Text(isAnonymousEnabled ? anonymousToggleOnSubtitle : anonymousToggleOffSubtitle)
	                                .font(.system(size: 15, weight: .bold, design: .rounded))
	                                .foregroundStyle(.primary.opacity(0.92))
	                                .lineLimit(2)
	                                .minimumScaleFactor(0.9)
                        }

                        Spacer()

	                        if isLoadingAnonymousLink {
	                            ProgressView().tint(.black.opacity(0.65))
	                        }
	                    }
	                    .padding(.vertical, 12)
	                    .padding(.horizontal, 12)
	                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
	                    .overlay(
	                        RoundedRectangle(cornerRadius: 16, style: .continuous)
	                            .stroke(.black.opacity(0.10), lineWidth: 1)
	                    )
	                }
	                .tint(.black.opacity(0.65))
	                .disabled(isLoadingAnonymousLink)

                if isAnonymousEnabled, let anonymousLinkURL, !anonymousLinkURL.isEmpty {
                    Button {
                        Haptics.selectionChanged()
                        UIPasteboard.general.string = anonymousLinkURL
                    } label: {
                        HStack(spacing: 12) {
	                            Image(systemName: "link")
	                                .font(.system(size: 16, weight: .bold))
	                                .foregroundStyle(.black.opacity(0.70))
	                                .frame(width: 22)

                            VStack(alignment: .leading, spacing: 4) {
	                                Text(anonymousCopyTitle)
	                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
	                                    .foregroundStyle(.secondary.opacity(0.85))
	                                Text(anonymousLinkURL)
	                                    .font(.system(size: 15, weight: .bold, design: .monospaced))
	                                    .foregroundStyle(.primary.opacity(0.92))
	                                    .lineLimit(1)
	                                    .minimumScaleFactor(0.72)
                            }

                            Spacer()

	                            Image(systemName: "doc.on.doc")
	                                .font(.system(size: 14, weight: .bold))
	                                .foregroundStyle(.black.opacity(0.35))
	                        }
	                        .padding(.vertical, 12)
	                        .padding(.horizontal, 12)
	                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
	                        .overlay(
	                            RoundedRectangle(cornerRadius: 16, style: .continuous)
	                                .stroke(.black.opacity(0.10), lineWidth: 1)
	                        )
	                    }
                    .buttonStyle(.plain)
                }
	            }
	            .padding(14)
	            .frame(maxWidth: .infinity, alignment: .leading)
	            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
	            .overlay(
	                RoundedRectangle(cornerRadius: 22, style: .continuous)
	                    .stroke(.black.opacity(0.10), lineWidth: 1)
	            )
	        }
	    }

	    private var codeCard: some View {
	        VStack(alignment: .leading, spacing: 10) {
	            Text(codeTitle)
	                .font(.system(size: 14, weight: .heavy, design: .rounded))
	                .foregroundStyle(.secondary.opacity(0.85))
	                .padding(.horizontal, 4)

            VStack(spacing: 10) {
                codeRow(
                    title: activeCodeTitle,
                    value: activeCode.lowercased(),
                    isEmphasized: true
                )
                if isUsingJoinedGroup {
                    codeRow(
                        title: ownCodeTitle,
                        value: ownCode.lowercased(),
                        isEmphasized: false
                    )
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(.white.opacity(0.18), lineWidth: 1)
            )
        }
    }

    private func codeRow(title: String, value: String, isEmphasized: Bool) -> some View {
        Button {
            UIPasteboard.general.string = value
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isEmphasized ? "link" : "person.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.black.opacity(0.70))
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary.opacity(0.85))
                    Text(value)
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundStyle(.primary.opacity(0.92))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer()

                Image(systemName: "doc.on.doc")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.black.opacity(0.35))
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.black.opacity(0.10), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

		    private func memberRow(_ member: GroupMemberProfile) -> some View {
		        HStack(spacing: 12) {
		            avatarView(url: member.avatarURL, username: member.username, isOnline: member.isOnline)
		            VStack(alignment: .leading, spacing: 2) {
		                Text("@\(member.username)")
		                    .font(.system(size: 16, weight: .heavy, design: .rounded))
		                    .foregroundStyle(.primary.opacity(0.92))
		            }
		            Spacer()

	            if member.streakCount > 0 {
                    Button {
                        Haptics.selectionChanged()
                        streakInfoCount = member.streakCount
                        showingStreakInfo = true
                    } label: {
                        streakPill(count: member.streakCount)
                    }
                    .buttonStyle(.plain)
	            }

		            if canManageMembers, let me = currentProfileId, member.id != me {
	                    Menu {
	                        Button(role: .destructive) {
	                            Haptics.tap(.rigid)
	                            confirmRemoveId = member.id
	                        } label: {
	                            Label(removeConfirmTitle, systemImage: "person.fill.xmark")
	                        }
	                    } label: {
	                        Image(systemName: "ellipsis")
	                            .font(.system(size: 14, weight: .bold))
	                            .foregroundStyle(.black.opacity(0.55))
	                            .padding(.vertical, 8)
	                            .padding(.horizontal, 10)
	                            .background(.thinMaterial, in: Capsule(style: .continuous))
	                            .overlay(
	                                Capsule(style: .continuous)
	                                    .stroke(.black.opacity(0.10), lineWidth: 1)
	                            )
	                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 4)
	            }
		        }
		        .padding(.vertical, 12)
		        .padding(.horizontal, 12)
		        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
		        .overlay(
		            RoundedRectangle(cornerRadius: 18, style: .continuous)
		                .stroke(.black.opacity(0.10), lineWidth: 1)
		        )
	            .shadow(color: .black.opacity(0.10), radius: 14, x: 0, y: 10)
		    }

	        private func streakPill(count: Int) -> some View {
            let tier = StreakTier.forCount(count)
            let progress = tier.progress(for: count)

            return HStack(spacing: 8) {
                ZStack {
                    // No filled background behind the flame (so it stays crisp on any gradient).
                    Circle()
                        .stroke(.white.opacity(0.18), lineWidth: 1)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            LinearGradient(
                                colors: tier.gradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 2.2, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .opacity(progress > 0 ? 1 : 0)

                    // Snapchat-like flame: outlined + warm gradient + glow.
                    ZStack {
                        Image(systemName: "flame")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(.white.opacity(0.95))
                            .shadow(color: .black.opacity(0.22), radius: 3, x: 0, y: 2)

                        Image(systemName: "flame.fill")
                            .font(.system(size: 12.6, weight: .heavy))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "FFF3A0"), Color(hex: "FFB000"), Color(hex: "FF2E63")],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: tier.glow.opacity(0.55), radius: 8, x: 0, y: 6)
                    }
                    .modifier(PulsingSymbolEffect(isActive: tier.isAnimated))
                }
                .frame(width: 22, height: 22)
                .shadow(color: tier.glow.opacity(0.28), radius: 10, x: 0, y: 8)

	                Text("\(count)")
	                    .font(.system(size: 14, weight: .heavy, design: .rounded))
	                    .foregroundStyle(.primary.opacity(0.92))
	                    .monospacedDigit()
	            }
	            .padding(.vertical, 7)
	            .padding(.horizontal, 10)
	            .background(.thinMaterial, in: Capsule(style: .continuous))
	            .overlay(
	                Capsule(style: .continuous)
	                    .stroke(.black.opacity(0.10), lineWidth: 1)
	            )
            .overlay(
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                tier.glow.opacity(0.10),
                                .clear,
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .accessibilityLabel(Text("streak \(count)"))
        }

        private enum StreakTier: CaseIterable {
            case bronze
            case silver
            case gold
            case diamond

            static func forCount(_ count: Int) -> StreakTier {
                if count >= 30 { return .diamond }
                if count >= 14 { return .gold }
                if count >= 7 { return .silver }
                return .bronze
            }

            var symbol: String {
                switch self {
                case .bronze: "flame.fill"
                case .silver: "flame.fill"
                case .gold: "flame.fill"
                case .diamond: "flame.fill"
                }
            }

            var gradient: [Color] {
                switch self {
                case .bronze: [Color(hex: "FFE66D"), Color(hex: "FFB000"), Color(hex: "FF6A00")]
                case .silver: [Color(hex: "FFF1A8"), Color(hex: "FFB000"), Color(hex: "FF4D00")]
                case .gold: [Color(hex: "FFF3C4"), Color(hex: "FF9A00"), Color(hex: "FF2E63")]
                case .diamond: [Color(hex: "FFFFFF"), Color(hex: "FFB000"), Color(hex: "FF2E63")]
                }
            }

            var glow: Color {
                switch self {
                case .bronze: Color(hex: "FF7A00")
                case .silver: Color(hex: "FF5A00")
                case .gold: Color(hex: "FF2E63")
                case .diamond: Color(hex: "FF2E63")
                }
            }

            var isAnimated: Bool {
                self == .gold || self == .diamond
            }

            func progress(for count: Int) -> CGFloat {
                let goal: Int
                switch self {
                case .bronze: goal = 7
                case .silver: goal = 14
                case .gold: goal = 30
                case .diamond: goal = 60
                }
                guard goal > 0 else { return 0 }
                return min(1, CGFloat(count % goal) / CGFloat(goal))
            }
        }

        private struct PulsingSymbolEffect: ViewModifier {
            let isActive: Bool

            func body(content: Content) -> some View {
                if #available(iOS 17.0, *), isActive {
                    content.symbolEffect(.pulse, options: .repeating.speed(0.65))
                } else {
                    content
                }
            }
        }

        private func streakInfoTitle(count: Int) -> String {
            let value = max(0, count)
            switch language {
            case .english:
                return "streak • \(value)"
            case .dutch:
                return "streak • \(value)"
            case .german:
                return "streak • \(value)"
            case .spanish:
                return "racha • \(value)"
            }
        }

        private var streakInfoMessage: String {
            switch language {
            case .english:
                "streaks grow when you send at least 1 doodl per day (UTC).\n\nsending multiple doodls in one day won’t increase your streak.\n\nif you skip a day, your streak resets to 1 the next day you send.\n\nif you haven’t sent today or yesterday, the streak won’t show."
            case .dutch:
                "streaks groeien als je minimaal 1 doodl per dag stuurt (UTC).\n\nmeer doodls op dezelfde dag verhogen je streak niet.\n\nals je een dag overslaat, reset je streak naar 1 op de dag dat je weer stuurt.\n\nals je vandaag of gisteren niks gestuurd hebt, wordt je streak niet getoond."
            case .german:
                "streaks steigen, wenn du mindestens 1 doodl pro tag sendest (UTC).\n\nmehrere doodls am selben tag erhöhen die streak nicht.\n\nwenn du einen tag auslässt, setzt sich die streak auf 1 zurück, sobald du wieder sendest.\n\nwenn du heute oder gestern nichts gesendet hast, wird die streak nicht angezeigt."
            case .spanish:
                "la racha sube si envías al menos 1 doodl por día (UTC).\n\nenviar varios doodls el mismo día no aumenta la racha.\n\nsi te saltas un día, la racha vuelve a 1 cuando vuelvas a enviar.\n\nsi no has enviado hoy o ayer, la racha no se muestra."
            }
        }

        private var okTitle: String {
            switch language {
            case .english: "ok"
            case .dutch: "ok"
            case .german: "ok"
            case .spanish: "ok"
            }
        }

	    private func avatarView(url: URL?, username: String, isOnline: Bool) -> some View {
	        ZStack {
	            Circle().fill(.thinMaterial)
	            if let url {
	                AsyncImage(url: url) { phase in
	                    switch phase {
	                    case .empty:
	                        ProgressView().tint(Color.primary.opacity(0.65))
	                    case .success(let image):
	                        image.resizable().scaledToFill()
	                    default:
	                        initials(username)
	                    }
	                }
	            } else {
	                initials(username)
	            }
	        }
	        .frame(width: 46, height: 46)
	        .clipShape(Circle())
	        .overlay(Circle().stroke(GlassStyle.stroke, lineWidth: 1))
	        .overlay(alignment: .bottomTrailing) {
	            if isOnline {
	                Circle()
	                    .fill(Color.green)
	                    .frame(width: 12, height: 12)
	                    .overlay(Circle().stroke(.white.opacity(0.95), lineWidth: 2))
	                    .shadow(color: .black.opacity(0.18), radius: 3, x: 0, y: 2)
	                    .offset(x: 3, y: 3)
	            }
	        }
	    }

    private func initials(_ username: String) -> some View {
        let letters = username.prefix(2).uppercased()
        return Text(letters)
            .font(.system(size: 14, weight: .heavy, design: .rounded))
            .foregroundStyle(Color.primary.opacity(0.72))
    }

    private var anonymousTitle: String {
        switch language {
        case .english: "anonymous"
        case .dutch: "anoniem"
        case .german: "anonym"
        case .spanish: "anónimo"
        }
    }

    private var anonymousToggleTitle: String {
        switch language {
        case .english: "anonymous link"
        case .dutch: "anonieme link"
        case .german: "anonymer link"
        case .spanish: "enlace anónimo"
        }
    }

    private var anonymousToggleOnSubtitle: String {
        switch language {
        case .english: "anyone can send you doodls"
        case .dutch: "iedereen kan je doodls sturen"
        case .german: "jeder kann dir doodls senden"
        case .spanish: "cualquiera puede enviarte doodls"
        }
    }

    private var anonymousToggleOffSubtitle: String {
        switch language {
        case .english: "off (groups only)"
        case .dutch: "uit (alleen groepen)"
        case .german: "aus (nur gruppen)"
        case .spanish: "apagado (solo grupos)"
        }
    }

    private var anonymousCopyTitle: String {
        switch language {
        case .english: "copy your link"
        case .dutch: "kopieer je link"
        case .german: "link kopieren"
        case .spanish: "copiar enlace"
        }
    }

		    private var title: String {
	        switch language {
	        case .english: "group"
	        case .dutch: "groep"
	        case .german: "gruppe"
	        case .spanish: "grupo"
	        }
		    }

	        private var capacityCard: some View {
	            let count = members.count
	            let maxCount = 15
	            let ratio = min(1, max(0, Double(count) / Double(maxCount)))
	            let progress = CGFloat(ratio)

            return HStack(spacing: 12) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 6) {
                    Text(capacityTitle)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))

                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule(style: .continuous)
                                .fill(.white.opacity(0.10))
                            Capsule(style: .continuous)
                                .fill(count >= maxCount ? .red.opacity(0.85) : .white.opacity(0.42))
                                .frame(width: proxy.size.width * progress)
                        }
                    }
                    .frame(height: 8)
                }

                Spacer()

                Text("\(count)/\(maxCount)")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.18), lineWidth: 1)
            )
        }

	        private var capacityTitle: String {
	            switch language {
	            case .english: "members"
	            case .dutch: "leden"
	            case .german: "mitglieder"
	            case .spanish: "miembros"
	            }
	        }

    

	    private var groupTabTitle: String {
	        switch language {
	        case .english: "group"
        case .dutch: "groep"
        case .german: "gruppe"
        case .spanish: "grupo"
        }
    }

    private var invitesTabTitle: String {
        switch language {
        case .english: "invites"
        case .dutch: "uitnodigingen"
        case .german: "einladungen"
        case .spanish: "invitaciones"
        }
    }

    private var invitesTitle: String {
        switch language {
        case .english: "your invites"
        case .dutch: "jouw invites"
        case .german: "deine einladungen"
        case .spanish: "tus invitaciones"
        }
    }

    private var invitesLoadingTitle: String {
        switch language {
        case .english: "loading invites…"
        case .dutch: "uitnodigingen laden…"
        case .german: "einladungen laden…"
        case .spanish: "cargando invitaciones…"
        }
    }

    private var invitesEmptyTitle: String {
        switch language {
        case .english: "no invites"
        case .dutch: "geen uitnodigingen"
        case .german: "keine einladungen"
        case .spanish: "sin invitaciones"
        }
    }

    private var refreshTitle: String {
        switch language {
        case .english: "refresh"
        case .dutch: "ververs"
        case .german: "aktualisieren"
        case .spanish: "actualizar"
        }
    }

    private var groupTitle: String {
        switch language {
        case .english: "group"
        case .dutch: "groep"
        case .german: "gruppe"
        case .spanish: "grupo"
        }
    }

    private var acceptTitle: String {
        switch language {
        case .english: "accept"
        case .dutch: "accepteren"
        case .german: "annehmen"
        case .spanish: "aceptar"
        }
    }

    private var declineTitle: String {
        switch language {
        case .english: "decline"
        case .dutch: "weigeren"
        case .german: "ablehnen"
        case .spanish: "rechazar"
        }
    }

    private var codeTitle: String {
        switch language {
        case .english: "codes"
        case .dutch: "codes"
        case .german: "codes"
        case .spanish: "códigos"
        }
    }

    private var activeCodeTitle: String {
        switch language {
        case .english: "active group code"
        case .dutch: "actieve groepscode"
        case .german: "aktiver gruppencode"
        case .spanish: "código de grupo activo"
        }
    }

    private var ownCodeTitle: String {
        switch language {
        case .english: "your code"
        case .dutch: "jouw code"
        case .german: "dein code"
        case .spanish: "tu código"
        }
    }

    private func membersTitle(count: Int) -> String {
        switch language {
        case .english: "\(count) member\(count == 1 ? "" : "s")"
        case .dutch: "\(count) lid\(count == 1 ? "" : "en")"
        case .german: "\(count) mitglied\(count == 1 ? "" : "er")"
        case .spanish: "\(count) miembro\(count == 1 ? "" : "s")"
        }
    }

    private var loadingTitle: String {
        switch language {
        case .english: "loading members…"
        case .dutch: "leden laden…"
        case .german: "mitglieder laden…"
        case .spanish: "cargando miembros…"
        }
    }

    private var emptyTitle: String {
        switch language {
        case .english: "no members yet"
        case .dutch: "nog geen leden"
        case .german: "noch keine mitglieder"
        case .spanish: "aún no hay miembros"
        }
    }

    private var joinTitle: String {
        switch language {
        case .english: "join group"
        case .dutch: "join groep"
        case .german: "gruppe beitreten"
        case .spanish: "unirse al grupo"
        }
    }

    private var joinCtaTitle: String {
        switch language {
        case .english: "join a friend's code"
        case .dutch: "join de code van een vriend"
        case .german: "tritt einem code bei"
        case .spanish: "únete al código de un amigo"
        }
    }

    private var joinPlaceholder: String {
        switch language {
        case .english: "enter code"
        case .dutch: "voer code in"
        case .german: "code eingeben"
        case .spanish: "ingresa el código"
        }
    }

    private var joinMessage: String {
        switch language {
        case .english: "you can join another group anytime."
        case .dutch: "je kan altijd een andere groep joinen."
        case .german: "du kannst jederzeit einer anderen gruppe beitreten."
        case .spanish: "puedes unirte a otro grupo cuando quieras."
        }
    }

    private var joinConfirmTitle: String {
        switch language {
        case .english: "join"
        case .dutch: "join"
        case .german: "beitreten"
        case .spanish: "unirse"
        }
    }

    private var inviteTitle: String {
        switch language {
        case .english: "invite"
        case .dutch: "uitnodigen"
        case .german: "einladen"
        case .spanish: "invitar"
        }
    }

    private var leaveTitle: String {
        switch language {
        case .english: "leave group"
        case .dutch: "verlaat groep"
        case .german: "gruppe verlassen"
        case .spanish: "salir del grupo"
        }
    }

    private var leaveMessage: String {
        switch language {
        case .english: "you’ll go back to your own group."
        case .dutch: "je gaat terug naar je eigen groep."
        case .german: "du gehst zurück zu deiner eigenen gruppe."
        case .spanish: "volverás a tu propio grupo."
        }
    }

    private var leaveConfirmTitle: String {
        switch language {
        case .english: "leave"
        case .dutch: "verlaten"
        case .german: "verlassen"
        case .spanish: "salir"
        }
    }

    private var removeTitle: String {
        switch language {
        case .english: "remove member"
        case .dutch: "lid verwijderen"
        case .german: "mitglied entfernen"
        case .spanish: "eliminar miembro"
        }
    }

    private var removeMessage: String {
        switch language {
        case .english: "this removes them from your group."
        case .dutch: "dit verwijdert die persoon uit je groep."
        case .german: "das entfernt die person aus deiner gruppe."
        case .spanish: "esto elimina a esa persona de tu grupo."
        }
    }

    private var removeConfirmTitle: String {
        switch language {
        case .english: "remove"
        case .dutch: "verwijderen"
        case .german: "entfernen"
        case .spanish: "eliminar"
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
}

#if canImport(PreviewsMacros)
#Preview {
    GroupMembersView(
        language: .dutch,
        ownCode: "a1b2c3d4",
        activeCode: "x9y8z7w6",
        isUsingJoinedGroup: true,
        members: [
            GroupMemberProfile(id: "1", username: "anthony", avatarURL: nil, streakCount: 12, isOnline: true),
            GroupMemberProfile(id: "2", username: "julia", avatarURL: nil, streakCount: 0, isOnline: false)
	        ],
	        isLoading: false,
	        errorMessage: nil,
            onRefreshMembers: {},
	        canManageMembers: true,
	        canLeaveGroup: true,
	        currentProfileId: "1",
	        anonymousLinkURL: "https://doodl-me.com/h/abcdef12345678",
        isAnonymousEnabled: true,
        isLoadingAnonymousLink: false,
        onToggleAnonymousLink: { _ in },
        onRemoveMember: { _ in },
        onLeaveGroup: {},
        onJoinGroup: { _ in },
        onInviteUsername: { _ in },
        canInvite: true,
        invites: [
            GroupInvite(id: "i1", groupCode: "x9y8z7w6", inviterUsername: "mila", status: "pending", createdAt: nil),
            GroupInvite(id: "i2", groupCode: "aaaa1111", inviterUsername: "sam", status: "declined", createdAt: nil)
        ],
        isLoadingInvites: false,
        invitesError: nil,
        onRefreshInvites: {},
        onRespondInvite: { _, _ in }
    )
    .environmentObject(PurchaseManager())
}
#endif
