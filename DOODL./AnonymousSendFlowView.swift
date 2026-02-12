import SwiftUI

struct AnonymousSendFlowView: View {
    let language: AppLanguage
    let senderProfileId: String
    let senderPairingCode: String

    @State private var query: String = ""
    @State private var results: [AnonymousReceiver] = []
    @State private var isSearching = false
    @State private var errorText: String?
    @State private var searchTask: Task<Void, Never>?

    @State private var selectedRecipient: AnonymousReceiver?
    @State private var isSending = false
    @State private var toastText: String?
    @FocusState private var isSearchFocused: Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                ThemedBackground()
                VStack(spacing: 12) {
                    searchField
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 12) {
                            if let recipient = selectedRecipient {
                                recipientCard(recipient)
                                DoodleCanvasView(language: language) { image in
                                    await send(image: image, to: recipient)
                                }
                            } else {
                                resultsSection
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 26)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(colorScheme, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(closeTitle) {
                        Haptics.tap()
                        dismiss()
                    }
                    .foregroundStyle(Color.primary.opacity(0.82))
                }
            }
        }
        .onChange(of: query) { _, newValue in
            scheduleSearch(for: newValue)
        }
        .onChange(of: selectedRecipient) { _, newValue in
            if newValue != nil {
                isSearchFocused = false
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
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(.white.opacity(0.14), lineWidth: 1)
                    )
                    .padding(.top, 10)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.primary.opacity(0.55))

            TextField(searchPlaceholder, text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .keyboardType(.asciiCapable)
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(.primary.opacity(0.92))
                .focused($isSearchFocused)

            if isSearching {
                ProgressView().tint(Color.primary.opacity(0.65))
            } else if !query.isEmpty {
                Button {
                    Haptics.tap(.light)
                    query = ""
                    results = []
                    errorText = nil
                    isSearchFocused = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.primary.opacity(0.35))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(GlassStyle.stroke, lineWidth: 1)
        )
    }

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(subtitle)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary.opacity(0.85))

            if let errorText, !errorText.isEmpty {
                Text(errorText)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.primary.opacity(0.92))
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.red.opacity(0.16), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else if query.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 {
                Text(hintTitle)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(.secondary.opacity(0.85))
                    .padding(.vertical, 14)
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(GlassStyle.stroke, lineWidth: 1)
                    )
            } else if results.isEmpty && !isSearching {
                Text(noResultsTitle)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(.secondary.opacity(0.85))
                    .padding(.vertical, 14)
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(GlassStyle.stroke, lineWidth: 1)
                    )
            } else {
                VStack(spacing: 10) {
                    ForEach(results, id: \.id) { receiver in
                        Button {
                            Haptics.selectionChanged()
                            selectedRecipient = receiver
                            isSearchFocused = false
                        } label: {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(.black.opacity(0.05))
                                    .frame(width: 34, height: 34)
                                    .overlay(Circle().stroke(.black.opacity(0.10), lineWidth: 1))
                                    .overlay {
                                        Text(String(receiver.username.prefix(1)).uppercased())
                                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                                            .foregroundStyle(.black.opacity(0.72))
                                    }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("@\(receiver.username)")
                                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                                        .foregroundStyle(.primary.opacity(0.92))
                                        .lineLimit(1)
                                    Text(sendHintTitle)
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.secondary.opacity(0.75))
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .bold))
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
            }
        }
        .padding(.top, 6)
    }

    private func recipientCard(_ recipient: AnonymousReceiver) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(.black.opacity(0.72))
                .padding(10)
                .background(.black.opacity(0.04), in: Circle())
                .overlay(Circle().stroke(.black.opacity(0.10), lineWidth: 1))

            VStack(alignment: .leading, spacing: 2) {
                Text(toTitle)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary.opacity(0.75))
                Text("@\(recipient.username)")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.92))
                    .lineLimit(1)
            }

            Spacer()

            Button {
                Haptics.tap(.light)
                selectedRecipient = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.black.opacity(0.35))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(changeTitle))
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.black.opacity(0.10), lineWidth: 1)
        )
    }

    private func scheduleSearch(for raw: String) {
        searchTask?.cancel()
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        errorText = nil

        guard trimmed.count >= 2 else {
            results = []
            isSearching = false
            return
        }

        isSearching = true
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            do {
                let found = try await SupabaseService.shared.searchAnonymousReceivers(
                    requesterProfileId: senderProfileId,
                    requesterPairingCode: senderPairingCode,
                    query: trimmed,
                    limit: 12
                )
                await MainActor.run {
                    results = found
                    isSearching = false
                }
            } catch {
                await MainActor.run {
                    results = []
                    isSearching = false
                    errorText = UserFacingError.message(for: error, language: language)
                }
            }
        }
    }

    @MainActor
    private func send(image: UIImage, to recipient: AnonymousReceiver) async {
        if isSending { return }
        isSending = true
        toastText = sendingTitle
        do {
            _ = try await SupabaseService.shared.submitAnonymousDoodleToProfile(
                image: image,
                senderProfileId: senderProfileId,
                senderPairingCode: senderPairingCode,
                recipientProfileId: recipient.id
            )
            Haptics.success()
            toastText = sentTitle
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) {
                withAnimation(.easeOut(duration: 0.2)) {
                    toastText = nil
                }
                dismiss()
            }
        } catch {
            Haptics.error()
            if let message = UserFacingError.message(for: error, language: language) {
                toastText = "\(failedTitle): \(message)"
            } else {
                toastText = nil
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.easeOut(duration: 0.2)) {
                    toastText = nil
                }
            }
        }
        isSending = false
    }

    private var title: String {
        switch language {
        case .english: "anonymous send"
        case .dutch: "anoniem sturen"
        case .german: "anonym senden"
        case .spanish: "enviar anónimo"
        }
    }

    private var subtitle: String {
        switch language {
        case .english: "pick a user with anonymous inbox enabled"
        case .dutch: "kies een gebruiker met anonieme inbox aan"
        case .german: "wähle einen nutzer mit aktivierter anonymer inbox"
        case .spanish: "elige un usuario con bandeja anónima activada"
        }
    }

    private var hintTitle: String {
        switch language {
        case .english: "type at least 2 letters"
        case .dutch: "typ minstens 2 letters"
        case .german: "mindestens 2 buchstaben eingeben"
        case .spanish: "escribe al menos 2 letras"
        }
    }

    private var noResultsTitle: String {
        switch language {
        case .english: "no matches"
        case .dutch: "geen matches"
        case .german: "keine treffer"
        case .spanish: "sin resultados"
        }
    }

    private var sendHintTitle: String {
        switch language {
        case .english: "tap to send a doodl"
        case .dutch: "tik om een doodl te sturen"
        case .german: "tippe um einen doodl zu senden"
        case .spanish: "toca para enviar un doodl"
        }
    }

    private var toTitle: String {
        switch language {
        case .english: "to"
        case .dutch: "naar"
        case .german: "an"
        case .spanish: "a"
        }
    }

    private var changeTitle: String {
        switch language {
        case .english: "change"
        case .dutch: "wijzigen"
        case .german: "ändern"
        case .spanish: "cambiar"
        }
    }

    private var searchPlaceholder: String {
        switch language {
        case .english: "search username"
        case .dutch: "zoek username"
        case .german: "username suchen"
        case .spanish: "buscar usuario"
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

    private var sendingTitle: String {
        switch language {
        case .english: "sending…"
        case .dutch: "versturen…"
        case .german: "senden…"
        case .spanish: "enviando…"
        }
    }

    private var sentTitle: String {
        switch language {
        case .english: "sent"
        case .dutch: "verstuurd"
        case .german: "gesendet"
        case .spanish: "enviado"
        }
    }

    private var failedTitle: String {
        switch language {
        case .english: "failed"
        case .dutch: "mislukt"
        case .german: "fehlgeschlagen"
        case .spanish: "falló"
        }
    }
}
