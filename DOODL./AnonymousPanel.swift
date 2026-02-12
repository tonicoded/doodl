import SwiftUI

struct AnonymousPanel: View {
    let language: AppLanguage
    let profileId: String
    let pairingCode: String
    let onRequestPro: () -> Void

    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Environment(\.colorScheme) private var colorScheme

    @State private var isEnabled = false
    @State private var shortCode: String?
    @State private var isLoadingLink = false

    @State private var inbox: [AnonymousInboxDoodle] = []
    @State private var isLoadingInbox = false
    @State private var errorText: String?
    @State private var toastText: String?

    @State private var showingSendFlow = false
    @State private var activeSnap: SnapDoodleViewer.Snap?
    @State private var lastRefreshAt = Date.distantPast

    private var panelFill: Color {
        colorScheme == .dark ? Color.black.opacity(0.26) : Color(.systemBackground)
    }

    private var panelStroke: Color {
        colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.08)
    }

    private var panelShadowColor: Color {
        colorScheme == .dark ? .black.opacity(0.16) : .black.opacity(0.00)
    }

    var body: some View {
        VStack(spacing: 12) {
            if let errorText, !errorText.isEmpty {
                Text(errorText)
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

            sendCard
            linkCard

            if isEnabled {
                inboxCard
            } else {
                disabledCard
            }
        }
        .onAppear {
            Task { await loadStatusAndMaybeRefresh() }
        }
        .onChange(of: purchaseManager.isPro) { _, _ in
            // Keep the panel stable if a purchase happens mid-session.
            Task { await loadStatusAndMaybeRefresh(force: true) }
        }
        .sheet(isPresented: $showingSendFlow) {
            AnonymousSendFlowView(
                language: language,
                senderProfileId: profileId,
                senderPairingCode: pairingCode
            )
            .environmentObject(purchaseManager)
        }
        .fullScreenCover(item: $activeSnap) { snap in
            SnapDoodleViewer(snap: snap, language: language, autoDismissSeconds: 10)
        }
        .overlay(alignment: .top) {
            if let toastText, !toastText.isEmpty {
                Text(toastText)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(.black.opacity(0.35), in: Capsule(style: .continuous))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(.white.opacity(0.14), lineWidth: 1)
                    )
                    .padding(.top, 6)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var sendCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.primary.opacity(0.82))
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 3) {
                    Text(sendTitle)
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.92))
                    Text(sendSubtitle)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            Button {
                Haptics.tap(.medium)
                guard purchaseManager.isPro else {
                    showToast(proRequiredTitle)
                    onRequestPro()
                    return
                }
                showingSendFlow = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 15, weight: .bold))
                    Text(sendButtonTitle)
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(.black)
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background(panelFill, in: Capsule(style: .continuous))
                .overlay(Capsule(style: .continuous).stroke(panelStroke, lineWidth: 1))
            }
            .buttonStyle(PremiumPlainButtonStyle(scale: 0.98, pressedOpacity: 0.97))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(panelFill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(panelStroke, lineWidth: 1))
        .shadow(color: panelShadowColor, radius: 14, x: 0, y: 10)
    }

    private var linkCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "link")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.primary.opacity(0.82))
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 3) {
                    Text(linkTitle)
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.92))
                    Text(linkSubtitle)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                if isLoadingLink {
                    ProgressView().tint(Color.primary.opacity(0.65))
                }
            }

            Toggle(isOn: Binding(
                get: { isEnabled },
                set: { newValue in
                    Haptics.selectionChanged()
                    Task { await setEnabled(newValue) }
                }
            )) {
                Text(receiveToggleTitle)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.92))
            }
            .tint(.black.opacity(0.88))
            .disabled(isLoadingLink)

            if isEnabled, let url = linkURL {
                HStack(spacing: 10) {
                    Button {
                        Haptics.selectionChanged()
                        UIPasteboard.general.url = url
                        showToast(copiedTitle)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 14, weight: .bold))
                            Text(copyTitle)
                                .font(.system(size: 14, weight: .heavy, design: .rounded))
                        }
                        .foregroundStyle(.black)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(panelFill, in: Capsule(style: .continuous))
                        .overlay(Capsule(style: .continuous).stroke(panelStroke, lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    ShareLink(item: url) {
                        HStack(spacing: 10) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .bold))
                            Text(shareTitle)
                                .font(.system(size: 14, weight: .heavy, design: .rounded))
                        }
                        .foregroundStyle(.black)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(panelFill, in: Capsule(style: .continuous))
                        .overlay(Capsule(style: .continuous).stroke(panelStroke, lineWidth: 1))
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(panelFill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(panelStroke, lineWidth: 1))
        .shadow(color: panelShadowColor, radius: 14, x: 0, y: 10)
    }

    private var inboxCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(inboxTitle)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.92))
                Spacer(minLength: 0)
                Button {
                    Haptics.tap(.light)
                    Task { await refreshInbox(force: true) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(Color.primary.opacity(0.82))
                        .padding(10)
                        .background(panelFill, in: Circle())
                        .overlay(Circle().stroke(panelStroke, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(isLoadingInbox)
            }

            if isLoadingInbox {
                ProgressView().tint(Color.primary.opacity(0.65))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else if inbox.isEmpty {
                Text(emptyInboxTitle)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary.opacity(0.85))
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(inbox) { doodle in
                        anonCell(doodle)
                    }
                }
                .padding(.top, 6)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(panelFill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(panelStroke, lineWidth: 1))
        .shadow(color: panelShadowColor, radius: 14, x: 0, y: 10)
    }

    private var disabledCard: some View {
        Text(disabledTitle)
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(.secondary.opacity(0.85))
            .padding(.vertical, 14)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(panelFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(panelStroke, lineWidth: 1))
            .shadow(color: panelShadowColor, radius: 12, x: 0, y: 8)
    }

    private func anonCell(_ doodle: AnonymousInboxDoodle) -> some View {
        Button {
            Haptics.tap(.light)
            guard let image = decodeBase64Image(doodle.contentBase64) else { return }
            activeSnap = SnapDoodleViewer.Snap(
                id: doodle.id,
                senderUsername: anonymousTitle,
                senderIsPro: false,
                image: image,
                createdAt: doodle.createdAt
            )
        } label: {
            ZStack {
                if let image = decodeBase64Image(doodle.contentBase64) {
                    Image(uiImage: image)
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFill()
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
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.primary.opacity(0.10), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func loadStatusAndMaybeRefresh(force: Bool = false) async {
        await loadStatus(force: force)
        if isEnabled {
            await refreshInbox(force: force)
        }
    }

    private func loadStatus(force: Bool) async {
        if isLoadingLink { return }
        isLoadingLink = true
        errorText = nil
        do {
            let status = try await SupabaseService.shared.getAnonymousLinkStatus(profileId: profileId, profilePairingCode: pairingCode)
            shortCode = status.shortCode
            isEnabled = status.isEnabled
        } catch {
            errorText = UserFacingError.message(for: error, language: language)
        }
        isLoadingLink = false
    }

    private func setEnabled(_ enabled: Bool) async {
        if isLoadingLink { return }
        isLoadingLink = true
        errorText = nil
        do {
            let status = try await SupabaseService.shared.setAnonymousLinkEnabled(
                profileId: profileId,
                profilePairingCode: pairingCode,
                enabled: enabled
            )
            shortCode = status.shortCode
            isEnabled = status.isEnabled
            if isEnabled {
                await refreshInbox(force: true)
            } else {
                inbox = []
            }
        } catch {
            errorText = UserFacingError.message(for: error, language: language)
            isEnabled.toggle()
        }
        isLoadingLink = false
    }

    private func refreshInbox(force: Bool) async {
        let now = Date()
        if !force, now.timeIntervalSince(lastRefreshAt) < 15 { return }
        lastRefreshAt = now
        if isLoadingInbox, !force { return }
        isLoadingInbox = true
        errorText = nil
        do {
            let rows = try await SupabaseService.shared.fetchAnonymousInboxDoodles(profileId: profileId, profilePairingCode: pairingCode, limit: 18)
            inbox = rows
        } catch {
            errorText = UserFacingError.message(for: error, language: language)
        }
        isLoadingInbox = false
    }

    private var linkURL: URL? {
        guard isEnabled else { return nil }
        guard let code = shortCode?.trimmingCharacters(in: .whitespacesAndNewlines), !code.isEmpty else { return nil }
        return URL(string: "https://doodl-me.com/h/\(code)")
    }

    private func decodeBase64Image(_ content: String) -> UIImage? {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let base64: String
        if let commaIndex = trimmed.firstIndex(of: ",") {
            base64 = String(trimmed[trimmed.index(after: commaIndex)...])
        } else {
            base64 = trimmed
        }
        guard let data = Data(base64Encoded: base64, options: [.ignoreUnknownCharacters]) else { return nil }
        // Always flatten so transparent strokes/widgets render predictably.
        return UIImage(data: data)?.withRenderingMode(.alwaysOriginal).flattenedOnWhite(scale: 1.0)
    }

    private func showToast(_ message: String) {
        withAnimation(.easeOut(duration: 0.15)) {
            toastText = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeIn(duration: 0.15)) {
                if toastText == message {
                    toastText = nil
                }
            }
        }
    }

    private var proRequiredTitle: String {
        switch language {
        case .english: "pro required"
        case .dutch: "pro nodig"
        case .german: "pro benötigt"
        case .spanish: "requiere pro"
        }
    }

    private var sendTitle: String {
        switch language {
        case .english: "send anonymous"
        case .dutch: "stuur anoniem"
        case .german: "anonym senden"
        case .spanish: "enviar anónimo"
        }
    }

    private var sendSubtitle: String {
        switch language {
        case .english: "send a doodl without your username."
        case .dutch: "stuur een doodl zonder je username."
        case .german: "sende eine doodl ohne deinen namen."
        case .spanish: "envía un doodl sin tu usuario."
        }
    }

    private var sendButtonTitle: String {
        switch language {
        case .english: "send doodl"
        case .dutch: "stuur doodl"
        case .german: "doodl senden"
        case .spanish: "enviar doodl"
        }
    }

    private var linkTitle: String {
        switch language {
        case .english: "anonymous link"
        case .dutch: "anonieme link"
        case .german: "anonymer link"
        case .spanish: "enlace anónimo"
        }
    }

    private var linkSubtitle: String {
        switch language {
        case .english: "enable it, share it, and receive doodls here."
        case .dutch: "zet aan, deel, en ontvang hier doodls."
        case .german: "aktivieren, teilen und doodls hier empfangen."
        case .spanish: "actívalo, compártelo y recibe doodls aquí."
        }
    }

    private var receiveToggleTitle: String {
        switch language {
        case .english: "receive anonymous doodls"
        case .dutch: "ontvang anonieme doodls"
        case .german: "anonyme doodls empfangen"
        case .spanish: "recibir doodls anónimos"
        }
    }

    private var inboxTitle: String {
        switch language {
        case .english: "anonymous inbox"
        case .dutch: "anonieme inbox"
        case .german: "anonymer posteingang"
        case .spanish: "bandeja anónima"
        }
    }

    private var emptyInboxTitle: String {
        switch language {
        case .english: "no anonymous doodls yet."
        case .dutch: "nog geen anonieme doodls."
        case .german: "noch keine anonymen doodls."
        case .spanish: "todavía no hay doodls anónimos."
        }
    }

    private var disabledTitle: String {
        switch language {
        case .english: "turn on your anonymous link to receive doodls."
        case .dutch: "zet je anonieme link aan om doodls te ontvangen."
        case .german: "aktiviere deinen anonymen link, um doodls zu empfangen."
        case .spanish: "activa tu enlace anónimo para recibir doodls."
        }
    }

    private var anonymousTitle: String {
        switch language {
        case .english: "anonymous"
        case .dutch: "anoniem"
        case .german: "anonym"
        case .spanish: "anónimo"
        }
    }

    private var copiedTitle: String {
        switch language {
        case .english: "copied"
        case .dutch: "gekopieerd"
        case .german: "kopiert"
        case .spanish: "copiado"
        }
    }

    private var copyTitle: String {
        switch language {
        case .english: "copy link"
        case .dutch: "kopieer link"
        case .german: "link kopieren"
        case .spanish: "copiar enlace"
        }
    }

    private var shareTitle: String {
        switch language {
        case .english: "share"
        case .dutch: "delen"
        case .german: "teilen"
        case .spanish: "compartir"
        }
    }

    private var loadFailedTitle: String {
        switch language {
        case .english: "failed"
        case .dutch: "mislukt"
        case .german: "fehlgeschlagen"
        case .spanish: "falló"
        }
    }
}

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
