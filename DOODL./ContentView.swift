//
//  ContentView.swift
//  DOODL.
//
//  Created by Anthony Verruijt on 15/12/2025.
//

import SwiftUI
import PhotosUI
import Security

private struct LanguagePickerButton: View {
    @Binding var selectedLanguage: AppLanguage
    @State private var showing = false

    var body: some View {
        Button {
            Haptics.tap()
            showing = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "globe.europe.africa.fill")
                    .font(.system(size: 14, weight: .semibold))
                Text(selectedLanguage.shortCode.lowercased())
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .foregroundStyle(Color.primary.opacity(0.9))
            .glassCapsule()
        }
        .buttonStyle(.plain)
        .confirmationDialog("language", isPresented: $showing, titleVisibility: .visible) {
            ForEach(AppLanguage.allCases) { language in
                Button(language.displayName) {
                    Haptics.selectionChanged()
                    selectedLanguage = language
                }
            }
        }
    }
}

	struct ContentView: View {
        @EnvironmentObject private var deepLinkRouter: DeepLinkRouter
        @EnvironmentObject private var purchaseManager: PurchaseManager
		    @State private var path: [OnboardingRoute] = []
		    @AppStorage("selectedLanguage") private var storedLanguageRaw: String = AppLanguage.english.rawValue
		    @State private var selectedLanguage: AppLanguage = .english
    @State private var onboardingUsername: String = ""
    @State private var onboardingAvatarImage: UIImage?
    @State private var onboardingAvatarURL: URL?
    @State private var pairingCode: String = PairingCodeGenerator.generate()
	    @State private var profileId: String?
	    @State private var joinedCode: String?
	    @State private var hasRestoredSession = false
	    @State private var isBootstrapping = true

	    private var copy: LocalizedStrings {
	        LocalizedStrings.map[selectedLanguage] ?? .english
	    }

	    var body: some View {
	        ZStack {
	            NavigationStack(path: $path) {
	                ZStack {
                    backgroundGradient
                        .ignoresSafeArea()
                    Color.white.opacity(0.01)
                        .ignoresSafeArea()

	                    VStack(spacing: 0) {
	                        topBar
	                            .padding(.top, 32)
	                            .padding(.horizontal, 20)

	                        Spacer()

	                        VStack(spacing: 20) {
	                            doodlWordmark
	                            Text(copy.subline)
	                                .font(.system(size: 18, weight: .medium, design: .rounded))
	                                .foregroundStyle(Color.secondary)
	                                .multilineTextAlignment(.center)
	                        }
	                        .padding(.horizontal, 28)

	                        Spacer()

	                        VStack(spacing: 16) {
	                            primaryButton
	                            disclaimerText
	                        }
	                        .padding(.horizontal, 24)
	                        .padding(.bottom, 32)
	                    }
	                }
	                .navigationDestination(for: OnboardingRoute.self) { route in
	                    switch route {
	                    case .username:
	                        UsernameView(
	                            selectedLanguage: $selectedLanguage,
	                            path: $path,
	                            username: $onboardingUsername
	                        )
	                    case .avatar:
	                        AvatarView(
	                            selectedLanguage: $selectedLanguage,
	                            path: $path,
	                            username: $onboardingUsername,
	                            avatarImage: $onboardingAvatarImage,
	                            avatarURL: $onboardingAvatarURL,
	                            pairingCode: $pairingCode,
	                            profileId: $profileId
	                        )
	                    case .group:
	                        GroupView(
	                            selectedLanguage: $selectedLanguage,
	                            path: $path,
	                            username: $onboardingUsername,
	                            profileId: $profileId,
	                            pairingCode: $pairingCode,
	                            joinedCode: $joinedCode
	                        )
	                    case .dashboard:
	                        DashboardView(
	                            path: $path,
	                            selectedLanguage: $selectedLanguage,
	                            pairingCode: $pairingCode,
	                            username: $onboardingUsername,
	                            avatarURL: $onboardingAvatarURL,
	                            profileId: $profileId,
	                            joinedCode: $joinedCode,
	                            resetOnboarding: resetOnboarding
	                        )
	                    }
	                }
	            }

	            if isBootstrapping {
	                bootSplash
	                    .transition(.opacity)
	            }
	        }
	        .onAppear {
	            Haptics.prepare()
	            if let lang = AppLanguage(rawValue: storedLanguageRaw) {
	                selectedLanguage = lang
            }
            restoreSessionIfNeeded()
            PushNotifications.requestAuthorizationIfNeeded()
        }
                .onChange(of: selectedLanguage) { _, newValue in
                    storedLanguageRaw = newValue.rawValue
                }
                .onChange(of: profileId) { _, newValue in
                    guard let newValue, !newValue.isEmpty else { return }
                    Task {
                        await purchaseManager.identify(appUserId: newValue)
                    }
                }
	        .sheet(item: $deepLinkRouter.anonymousLink) { link in
	            AnonymousSendDoodleView(shortCode: link.code)
                    .environmentObject(purchaseManager)
	        }
	    }
	}

struct GroupView: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isJoinFocused: Bool
    @Binding var selectedLanguage: AppLanguage
    @Binding var path: [OnboardingRoute]
    @Binding var username: String
    @Binding var profileId: String?
    @Binding var pairingCode: String
    @Binding var joinedCode: String?
    @State private var joinCode: String = ""
    @State private var isJoining = false
    @State private var errorMessage: String?
    @State private var copied = false

    private var copy: LocalizedStrings {
        LocalizedStrings.map[selectedLanguage] ?? .english
    }

	    var body: some View {
	        ZStack {
	            ThemedBackground()

	            VStack(spacing: 0) {
	                HStack {
	                    Button {
                        Haptics.tap()
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.primary.opacity(0.9))
                            .padding(10)
                            .glassCircle()
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    languagePicker
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        VStack(spacing: 10) {
                            Text(copy.groupTitle)
                                .font(.system(size: 30, weight: .heavy, design: .rounded))
                                .foregroundStyle(Color.primary)
                                .multilineTextAlignment(.center)

                            Text(copy.groupSubtitle)
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 18)
                }

                continueButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 26)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}

private extension GroupView {
    var languagePicker: some View {
        LanguagePickerButton(selectedLanguage: $selectedLanguage)
    }

    var codeCard: some View {
        VStack(spacing: 10) {
            Text(copy.yourCodeLabel)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Color.secondary)

            Text(copy.codeHint)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .glassCard(cornerRadius: 22)
    }

    var joinCard: some View {
        EmptyView()
    }

    var continueButton: some View {
        Button {
            Haptics.tap(.medium)
            if !path.contains(.dashboard) {
                path.append(.dashboard)
            }
        } label: {
            VStack(spacing: 2) {
                HStack {
                    Text(continueTitle)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .opacity(0.75)
                }

                Text(continueHint)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary.opacity(0.85))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .foregroundStyle(.primary)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(
                Capsule(style: .continuous)
                    .fill(.thinMaterial)
                    .shadow(color: .black.opacity(0.14), radius: 8, x: 0, y: 8)
            )
        }
        .buttonStyle(.plain)
        .disabled(isJoining)
        .opacity(isJoining ? 0.7 : 1)
    }

    var continueTitle: String {
        switch selectedLanguage {
        case .english: "continue"
        case .dutch: "doorgaan"
        case .german: "weiter"
        case .spanish: "continuar"
        }
    }

    var continueHint: String {
        switch selectedLanguage {
        case .english: "no code? you can join later."
        case .dutch: "geen code? je kan later joinen."
        case .german: "kein code? du kannst später beitreten."
        case .spanish: "¿sin código? puedes unirte más tarde."
        }
    }

    var joinSectionTitle: String {
        switch selectedLanguage {
        case .english: "join a group"
        case .dutch: "join een groep"
        case .german: "einer gruppe beitreten"
        case .spanish: "unirse a un grupo"
        }
    }

    var joinSectionHint: String {
        switch selectedLanguage {
        case .english: "only join if someone shared a code with you."
        case .dutch: "join alleen als iemand je een code heeft gestuurd."
        case .german: "nur beitreten, wenn dir jemand einen code geschickt hat."
        case .spanish: "únete solo si alguien te compartió un código."
        }
    }

    func handleJoin() async {
        if isJoining { return }
        guard let profileId = profileId else {
            Haptics.warning()
            errorMessage = joinProfileNotReadyMessage
            return
        }
        let entered = joinCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .lowercased()
        if entered == pairingCode.lowercased() {
            Haptics.warning()
            errorMessage = joinOwnCodeMessage
            return
        }
	        isJoining = true
	        errorMessage = nil
	        do {
	            try await SupabaseService.shared.joinGroup(pairingCode: entered, profileId: profileId, profilePairingCode: pairingCode)
		            await MainActor.run {
		                Haptics.success()
		                OnboardingStorage.saveJoinedCode(entered)
		                OnboardingStorage.saveJoinedCodes([entered])
		                joinedCode = entered
		                // Widget always shows the latest doodl across all chats/groups.
		                SharedWidgetStore.saveWidgetConfig(
		                    groupCode: SharedWidgetStore.allSourcesCode,
		                    profileId: profileId,
		                    username: username
		                )
	                isJoinFocused = false
	                path = [.dashboard]
	            }
        } catch {
            await MainActor.run {
                Haptics.error()
                if let supaError = error as? SupabaseServiceError {
                    switch supaError {
                    case .invalidCode:
                        errorMessage = joinInvalidCodeMessage
                    case .badStatus(let code) where code == 409:
                        errorMessage = joinFullGroupMessage
                    default:
                        errorMessage = joinGenericErrorMessage(supaError)
                    }
                } else {
                    errorMessage = joinGenericErrorMessage(error)
                }
            }
        }
        await MainActor.run {
            isJoining = false
        }
    }

    var joinProfileNotReadyMessage: String {
        switch selectedLanguage {
        case .english: "almost there — finishing your profile. try again in a second."
        case .dutch: "bijna klaar — je profiel wordt nog afgerond. probeer zo nog eens."
        case .german: "fast fertig — dein profil wird noch abgeschlossen. gleich nochmal versuchen."
        case .spanish: "casi listo — terminando tu perfil. inténtalo de nuevo en un segundo."
        }
    }

    var joinOwnCodeMessage: String {
        switch selectedLanguage {
        case .english: "that’s your own code — share it with friends instead."
        case .dutch: "dat is je eigen code — deel ’m met vrienden."
        case .german: "das ist dein eigener code — teile ihn mit freunden."
        case .spanish: "ese es tu propio código — compártelo con amigos."
        }
    }

    var joinInvalidCodeMessage: String {
        switch selectedLanguage {
        case .english: "we couldn’t find that code. double-check it and try again."
        case .dutch: "die code bestaat niet. check ’m even en probeer opnieuw."
        case .german: "diesen code gibt es nicht. bitte prüfen und erneut versuchen."
        case .spanish: "no encontramos ese código. revísalo e inténtalo de nuevo."
        }
    }

    var joinFullGroupMessage: String {
        switch selectedLanguage {
        case .english: "that group is full (max 15). ask them for a different code."
        case .dutch: "die groep zit vol (max 15). vraag om een andere code."
        case .german: "die gruppe ist voll (max. 15). bitte nach einem anderen code fragen."
        case .spanish: "ese grupo está lleno (máx. 15). pide otro código."
        }
    }

    func joinGenericErrorMessage(_ error: Error) -> String {
        switch selectedLanguage {
        case .english: "couldn’t join right now. try again."
        case .dutch: "joinen lukt nu even niet. probeer opnieuw."
        case .german: "beitreten geht gerade nicht. bitte erneut versuchen."
        case .spanish: "no se pudo unir ahora. inténtalo de nuevo."
        }
    }
}
	private extension ContentView {
	    var backgroundGradient: LinearGradient {
            let palette = AppTheme.currentPalette()
	        return LinearGradient(
	            colors: palette.backgroundColors,
	            startPoint: .topLeading,
	            endPoint: .bottomTrailing
	        )
	    }

		    var bootSplash: some View {
		        return ZStack {
		            backgroundGradient.ignoresSafeArea()
		            VStack(spacing: 18) {
		                Image("logo")
		                    .resizable()
		                    .scaledToFit()
	                    .frame(maxWidth: 220)
	                    .shadow(color: .black.opacity(0.22), radius: 12, x: 0, y: 10)

	                ProgressView()
	                    .tint(.black.opacity(0.7))
	            }
	            .padding(.top, 10)
	        }
	        .allowsHitTesting(true)
	    }

	    var topBar: some View {
	        HStack(alignment: .center) {
	            Text(copy.tagline)
	                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            Spacer(minLength: 16)

            languagePicker
        }
        .frame(maxWidth: .infinity)
    }

    var languagePicker: some View {
        LanguagePickerButton(selectedLanguage: $selectedLanguage)
    }

    var doodlWordmark: some View {
        Image("logo")
            .resizable()
            .scaledToFit()
            .frame(maxWidth: 450)
            .shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 12)
            .padding(.top, 12)
    }

    var primaryButton: some View {
        Button {
            Haptics.tap(.medium)
            path.append(.username)
        } label: {
            Text(copy.cta)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .fill(.black)
                        .shadow(color: .black.opacity(0.16), radius: 10, x: 0, y: 10)
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("primary_cta")
    }

    var disclaimerText: some View {
        Text(.init(copy.termsMarkdown))
            .font(.system(size: 13, weight: .regular, design: .rounded))
            .foregroundStyle(Color.secondary)
            .multilineTextAlignment(.center)
            .lineSpacing(2)
            .tint(.blue)
    }
}

enum OnboardingRoute: Hashable {
    case username
    case avatar
    case group
    case dashboard
}

	private extension ContentView {
	    func resetOnboarding() {
	        onboardingUsername = ""
	        onboardingAvatarImage = nil
	        onboardingAvatarURL = nil
        pairingCode = PairingCodeGenerator.generate()
        profileId = nil
        joinedCode = nil
        path = []
        OnboardingStorage.clear()
	        DoodleStore.clear()
	    }

	    func restoreSessionIfNeeded() {
	        guard !hasRestoredSession else {
	            isBootstrapping = false
	            return
	        }
	        hasRestoredSession = true
	        if let saved = OnboardingStorage.load() {
	            isBootstrapping = true
	            onboardingUsername = saved.username
	            onboardingAvatarURL = saved.avatarURL
	            pairingCode = saved.pairingCode
            profileId = saved.profileId
            joinedCode = (saved.joinedCode == saved.pairingCode) ? nil : saved.joinedCode
	            // Widget always shows the latest doodl across all chats/groups.
	            SharedWidgetStore.saveWidgetConfig(
	                groupCode: SharedWidgetStore.allSourcesCode,
	                profileId: profileId,
	                username: onboardingUsername
	            )
            Task {
                let exists = await SupabaseService.shared.profileExists(profileId: saved.profileId)
                await MainActor.run {
                    if exists {
                        path = [.dashboard]
	                    } else {
	                        resetOnboarding()
	                    }
	                    isBootstrapping = false
	                }
	            }
	        } else {
	            isBootstrapping = false
	        }
	    }
	}

struct UsernameView: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    @Binding var selectedLanguage: AppLanguage
    @Binding var path: [OnboardingRoute]
    @Binding var username: String
    @State private var isChecking = false
    @State private var errorMessage: String?

    private var copy: LocalizedStrings {
        LocalizedStrings.map[selectedLanguage] ?? .english
    }

    private var isValid: Bool {
        let sanitized = UsernameRules.sanitize(username)
        return sanitized.count >= UsernameRules.minLength
    }

	    var body: some View {
	        ZStack {
		            ThemedBackground()

	            VStack(spacing: 28) {
	                HStack {
	                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.primary.opacity(0.9))
                            .padding(10)
                            .glassCircle()
                    }

                    Spacer()

                    languagePicker
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Spacer()

                VStack(spacing: 20) {
                    Text(copy.usernameTitle)
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    usernameField
                        .padding(.horizontal, 24)

                    Text(usernameHint)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    primaryButton
                        .padding(.horizontal, 24)
                        .padding(.top, 8)

                    if let errorMessage, !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.primary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                }

                Spacer()
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                isFocused = true
            }
        }
        .onChange(of: username) { _, newValue in
            let sanitized = UsernameRules.sanitize(newValue)
            if sanitized != newValue {
                username = sanitized
            }
            errorMessage = nil
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}

private extension UsernameView {
    var languagePicker: some View {
        LanguagePickerButton(selectedLanguage: $selectedLanguage)
    }

    var usernameField: some View {
        HStack(spacing: 12) {
            Text("@")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Color.secondary)

            TextField(copy.usernamePlaceholder, text: $username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .keyboardType(.asciiCapable)
                .foregroundStyle(Color.primary)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .tint(Color.primary)
                .focused($isFocused)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
        .overlay(Capsule(style: .continuous).stroke(GlassStyle.stroke, lineWidth: 1))
    }

    var primaryButton: some View {
        Button {
            guard isValid else { return }
            Haptics.tap(.medium)
            Task { await validateAndContinue() }
        } label: {
            Text(copy.usernameCTA)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Capsule(style: .continuous)
                        .fill(isValid ? Color.black : Color.black.opacity(0.35))
                        .shadow(color: .black.opacity(0.16), radius: 10, x: 0, y: 10)
                )
        }
        .buttonStyle(.plain)
        .disabled(!isValid || isChecking)
        .opacity((isValid && !isChecking) ? 1 : 0.7)
    }
}

private extension UsernameView {
    var usernameHint: String {
        switch selectedLanguage {
        case .english: "max 12 chars • a–z, 0–9, underscore • no spaces"
        case .dutch: "max 12 tekens • a–z, 0–9, underscore • geen spaties"
        case .german: "max 12 zeichen • a–z, 0–9, underscore • keine leerzeichen"
        case .spanish: "máx 12 • a–z, 0–9, guion bajo • sin espacios"
        }
    }

    func validateAndContinue() async {
        let normalized = UsernameRules.sanitize(username)
        guard UsernameRules.isValid(normalized) else {
            await MainActor.run {
                Haptics.warning()
                errorMessage = usernameHint.lowercased()
            }
            return
        }
        await MainActor.run {
            isChecking = true
            errorMessage = nil
        }
        do {
            let available = try await SupabaseService.shared.isUsernameAvailable(normalized)
            if available {
                await MainActor.run { Haptics.success() }
                await MainActor.run {
                    username = normalized
                    path.append(.avatar)
                }
            } else {
                await MainActor.run { Haptics.warning() }
                await MainActor.run {
                    errorMessage = "username already in use"
                }
            }
        } catch {
            await MainActor.run { Haptics.error() }
            await MainActor.run {
                errorMessage = UserFacingError.message(for: error, language: selectedLanguage)
            }
        }
        await MainActor.run {
            isChecking = false
        }
    }
}


struct AvatarView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedLanguage: AppLanguage
    @Binding var path: [OnboardingRoute]
    @Binding var username: String
    @Binding var avatarImage: UIImage?
    @Binding var avatarURL: URL?
    @Binding var pairingCode: String
    @Binding var profileId: String?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showPhotoPicker = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var forceSkipAvatar = false

    private var copy: LocalizedStrings {
        LocalizedStrings.map[selectedLanguage] ?? .english
    }

	    var body: some View {
	        ZStack {
		            ThemedBackground()

	            VStack(spacing: 28) {
	                HStack(spacing: 12) {
	                    Button {
                        Haptics.tap()
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.primary.opacity(0.9))
                            .padding(10)
                            .glassCircle()
                    }

                    Spacer()

                    Button {
                        Haptics.tap()
                        forceSkipAvatar = true
                        Task { await saveProfile() }
                    } label: {
                        Text(copy.avatarSkip)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.primary.opacity(0.9))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .glassCapsule()
                    }

                    languagePicker
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                Spacer()

                VStack(spacing: 24) {
                    Text(copy.avatarTitle)
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    avatarPlaceholder

                    primaryButton
                        .padding(.horizontal, 24)
                        .padding(.top, 8)

                    if let errorMessage, !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.primary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                }

                Spacer()
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}

private extension AvatarView {
    var languagePicker: some View {
        LanguagePickerButton(selectedLanguage: $selectedLanguage)
    }

    var avatarPlaceholder: some View {
        ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 200, height: 200)
                .overlay(
                    Circle()
                        .stroke(GlassStyle.stroke, lineWidth: 2)
                )
                .overlay {
                    if let image = avatarImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 200, height: 200)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(.white.opacity(0.3), lineWidth: 2)
                            )
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(Color.secondary.opacity(0.8))
                            .padding(28)
                    }
                }

            Button {
                Haptics.tap()
                showPhotoPicker = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 52, height: 52)
                    .background(
                        Circle()
                            .fill(.white)
                            .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 8)
                    )
            }
            .offset(x: 8, y: 8)
        }
    }

    var primaryButton: some View {
        Button {
            Haptics.tap(.medium)
            handlePrimaryAction()
        } label: {
            Text(avatarImage == nil ? copy.avatarCTA : copy.avatarSave)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.black)
                        .shadow(color: .black.opacity(0.16), radius: 10, x: 0, y: 10)
                )
        }
        .buttonStyle(.plain)
        .disabled(isSaving)
        .opacity(isSaving ? 0.7 : 1)
        .overlay {
            if isSaving {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.black.opacity(0.8))
            }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        Haptics.selectionChanged()
                        avatarImage = image
                    }
                }
            }
        }
    }
}

private extension AvatarView {
    func handlePrimaryAction() {
        if avatarImage == nil {
            forceSkipAvatar = false
            Haptics.tap()
            showPhotoPicker = true
        } else {
            forceSkipAvatar = false
            Task { await saveProfile() }
        }
    }

    func saveProfile() async {
        isSaving = true
        errorMessage = nil
        do {
            let shouldUseAvatar = !forceSkipAvatar
            var uploadedURL: URL? = shouldUseAvatar ? avatarURL : nil
            if shouldUseAvatar, let avatarImage {
                let newURL = try await SupabaseService.shared.uploadAvatar(image: avatarImage)
                if let previous = avatarURL {
                    try? await SupabaseService.shared.deleteAvatar(fileURL: previous)
                }
                uploadedURL = newURL
            }

            var attempts = 0
            var createdProfile: ProfileResponse?

            while attempts < 3 && createdProfile == nil {
                attempts += 1
                let code = pairingCode
                do {
                    let profile = try await SupabaseService.shared.createProfile(
                        username: username,
                        avatarURL: uploadedURL,
                        pairingCode: code
                    )
	                    createdProfile = profile
	                    profileId = profile.id
	                    try await SupabaseService.shared.ensureGroup(pairingCode: code, profileId: profile.id, profilePairingCode: code)
	                    OnboardingStorage.save(
	                        profileId: profile.id,
	                        username: username,
                        avatarURL: uploadedURL,
                        pairingCode: code,
                        joinedCode: nil
                    )
                    SharedWidgetStore.saveWidgetConfig(groupCode: SharedWidgetStore.allSourcesCode, profileId: profile.id, username: username)
                } catch SupabaseServiceError.conflict {
                    let available = try? await SupabaseService.shared.isUsernameAvailable(username)
                    if available == false {
                        throw SupabaseServiceError.unavailableUsername
                    }
                    pairingCode = PairingCodeGenerator.generate()
                }
            }

            guard createdProfile != nil else {
                throw SupabaseServiceError.conflict
            }

            await MainActor.run {
                Haptics.success()
                if !path.contains(.dashboard) {
                    path.append(.dashboard)
                }
            }
        } catch {
            await MainActor.run {
                Haptics.error()
                if let supaError = error as? SupabaseServiceError {
                    switch supaError {
                    case .unavailableUsername:
                        errorMessage = "username already in use"
                    case .badStatus(let code) where code == 409:
                        errorMessage = "code or username already exists. try again."
                    default:
                        errorMessage = UserFacingError.message(for: supaError, language: selectedLanguage) ?? supaError.localizedDescription
                    }
                } else {
                    errorMessage = UserFacingError.message(for: error, language: selectedLanguage) ?? error.localizedDescription
                }
            }
        }
        await MainActor.run {
            isSaving = false
            forceSkipAvatar = false
        }
    }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case dutch = "nl"
    case german = "de"
    case spanish = "es"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: "english"
        case .dutch: "nederlands"
        case .german: "deutsch"
        case .spanish: "español"
        }
    }

    var flagEmoji: String {
        switch self {
        case .english: "🇬🇧"
        case .dutch: "🇳🇱"
        case .german: "🇩🇪"
        case .spanish: "🇪🇸"
        }
    }

    var shortCode: String { rawValue }
}

struct LocalizedStrings {
    let tagline: String
    let subline: String
    let cta: String
    let terms: String
    let termsMarkdown: String
    let usernameTitle: String
    let usernamePlaceholder: String
    let usernameCTA: String
    let avatarTitle: String
    let avatarCTA: String
    let avatarSave: String
    let avatarSkip: String
    let groupTitle: String
    let groupSubtitle: String
    let yourCodeLabel: String
    let codeHint: String
    let joinPlaceholder: String
    let joinCTA: String
    let joinSuccess: String
    let continueCTA: String

    static let english = LocalizedStrings(
        tagline: "a small presence on their screen.",
        subline: "send a quick doodl. they see you without opening the app.",
        cta: "begin",
        terms: "by continuing, you agree to our terms of use and acknowledge our privacy policy.",
        termsMarkdown: "by continuing, you agree to our [terms of service](https://doodl-me.com/terms/) and acknowledge our [privacy policy](https://doodl-me.com/privacy/).",
        usernameTitle: "choose a username",
        usernamePlaceholder: "@yourname",
        usernameCTA: "continue",
        avatarTitle: "choose a profile picture",
        avatarCTA: "choose photo",
        avatarSave: "save & continue",
        avatarSkip: "skip",
        groupTitle: "share your doodl code",
        groupSubtitle: "invite up to 15 people or join a friend's code.",
        yourCodeLabel: "your code",
        codeHint: "share this with family or friends. max 15 people per group.",
        joinPlaceholder: "enter a doodl code",
        joinCTA: "join group",
        joinSuccess: "joined the group.",
        continueCTA: "continue"
    )

    static let dutch = LocalizedStrings(
        tagline: "een kleine aanwezigheid op hun scherm.",
        subline: "stuur een snelle doodl. ze zien je zonder de app te openen.",
        cta: "begin",
        terms: "door verder te gaan ga je akkoord met onze gebruiksvoorwaarden en ons privacybeleid.",
        termsMarkdown: "door verder te gaan ga je akkoord met onze [gebruiksvoorwaarden](https://doodl-me.com/terms/) en ons [privacybeleid](https://doodl-me.com/privacy/).",
        usernameTitle: "kies een gebruikersnaam",
        usernamePlaceholder: "@jouwnaam",
        usernameCTA: "doorgaan",
        avatarTitle: "kies een profielfoto",
        avatarCTA: "foto kiezen",
        avatarSave: "opslaan en doorgaan",
        avatarSkip: "overslaan",
        groupTitle: "deel je doodl-code",
        groupSubtitle: "nodig tot 15 mensen uit of join de code van een vriend.",
        yourCodeLabel: "jouw code",
        codeHint: "deel deze met familie of vrienden. max 15 mensen per groep.",
        joinPlaceholder: "vul een doodl-code in",
        joinCTA: "join groep",
        joinSuccess: "gejoined.",
        continueCTA: "doorgaan"
    )

    static let german = LocalizedStrings(
        tagline: "eine kleine präsenz auf ihrem bildschirm.",
        subline: "schick einen schnellen doodl. sie sehen dich, ohne die app zu öffnen.",
        cta: "start",
        terms: "wenn du fortfährst, stimmst du unseren nutzungsbedingungen und der datenschutzerklärung zu.",
        termsMarkdown: "wenn du fortfährst, stimmst du unseren [nutzungsbedingungen](https://doodl-me.com/terms/) und der [datenschutzerklärung](https://doodl-me.com/privacy/) zu.",
        usernameTitle: "wähle einen nutzernamen",
        usernamePlaceholder: "@deinname",
        usernameCTA: "weiter",
        avatarTitle: "wähle ein profilbild",
        avatarCTA: "foto wählen",
        avatarSave: "speichern und weiter",
        avatarSkip: "überspringen",
        groupTitle: "teile deinen doodl-code",
        groupSubtitle: "lade bis zu 15 personen ein oder tritt einem code bei.",
        yourCodeLabel: "dein code",
        codeHint: "teile das mit familie oder freunden. max 15 personen pro gruppe.",
        joinPlaceholder: "doodl-code eingeben",
        joinCTA: "gruppe beitreten",
        joinSuccess: "beigetreten.",
        continueCTA: "weiter"
    )

    static let spanish = LocalizedStrings(
        tagline: "una pequeña presencia en su pantalla.",
        subline: "envía un doodl rápido. te ven sin abrir la app.",
        cta: "empezar",
        terms: "al continuar, aceptas nuestros términos de uso y la política de privacidad.",
        termsMarkdown: "al continuar, aceptas nuestros [términos de uso](https://doodl-me.com/terms/) y la [política de privacidad](https://doodl-me.com/privacy/).",
        usernameTitle: "elige un nombre de usuario",
        usernamePlaceholder: "@tunombre",
        usernameCTA: "continuar",
        avatarTitle: "elige una foto de perfil",
        avatarCTA: "elegir foto",
        avatarSave: "guardar y continuar",
        avatarSkip: "omitir",
        groupTitle: "comparte tu código doodl",
        groupSubtitle: "invita hasta 15 personas o únete al código de un amigo.",
        yourCodeLabel: "tu código",
        codeHint: "compártelo con familia o amigos. máximo 15 personas por grupo.",
        joinPlaceholder: "ingresa un código doodl",
        joinCTA: "unirse al grupo",
        joinSuccess: "te uniste al grupo.",
        continueCTA: "continuar"
    )

    static let map: [AppLanguage: LocalizedStrings] = [
        .english: .english,
        .dutch: .dutch,
        .german: .german,
        .spanish: .spanish
    ]
}

extension Color {
    /// Single-brand background color used across the app.
    static let doodlBackground = Color(hex: "0D0E14")

    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch cleaned.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct PairingCodeGenerator {
    static func generate(length: Int = 8) -> String {
        guard length > 0 else { return "" }
        let chars = Array("abcdefghijklmnopqrstuvwxyz0123456789")
        var bytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            // Fallback (should be very rare)
            let code = (0..<length).compactMap { _ in chars.randomElement() }
            return String(code)
        }

        var out = [Character]()
        out.reserveCapacity(length)
        for b in bytes {
            out.append(chars[Int(b) % chars.count])
        }
        return String(out)
    }
}

#if canImport(PreviewsMacros)
#Preview {
    ContentView()
}
#endif
