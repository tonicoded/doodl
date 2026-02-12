import SwiftUI

struct InviteUserSheet: View {
    let language: AppLanguage
    let excludeProfileId: String?
    let onInvite: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var query: String = ""
    @State private var results: [ProfileSearchResult] = []
    @State private var isLoading = false
    @State private var errorText: String?
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                searchField

                if let errorText, !errorText.isEmpty {
                    Text(errorText)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.primary.opacity(0.92))
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.red.opacity(0.16), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                } else if isLoading {
                    HStack(spacing: 10) {
                        ProgressView().tint(Color.primary.opacity(0.75))
                        Text(loadingTitle)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary.opacity(0.85))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else if results.isEmpty {
                    Text(emptyTitle)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary.opacity(0.85))
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 10) {
                            ForEach(results) { user in
                                resultRow(user)
                            }
                        }
                        .padding(.top, 2)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(16)
            .background(ThemedBackground())
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(colorScheme, for: .navigationBar)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(cancelTitle) {
                        Haptics.tap()
                        dismiss()
                    }
                    .foregroundStyle(Color.primary.opacity(0.82))
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    isFocused = true
                }
            }
            .onChange(of: query) { _, newValue in
                scheduleSearch(for: newValue)
            }
            .onDisappear {
                searchTask?.cancel()
                searchTask = nil
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.primary.opacity(0.55))

            TextField("", text: $query, prompt: Text(placeholder).foregroundStyle(.secondary.opacity(0.65)))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .keyboardType(.asciiCapable)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(.primary.opacity(0.92))
                .tint(Color.primary.opacity(0.9))
                .focused($isFocused)

            if !query.isEmpty {
                Button {
                    Haptics.selectionChanged()
                    query = ""
                    results = []
                    errorText = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.primary.opacity(0.35))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(GlassStyle.stroke, lineWidth: 1)
        )
    }

    private func resultRow(_ user: ProfileSearchResult) -> some View {
        Button {
            Haptics.tap()
            onInvite(user.username)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                avatarView(url: user.avatarURL, username: user.username)

                VStack(alignment: .leading, spacing: 3) {
                    Text("@\(user.username)")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.92))
                        .lineLimit(1)
                    if !query.isEmpty {
                        Text(matchSubtitle(for: user.username))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary.opacity(0.75))
                            .lineLimit(1)
                    }
                }

                Spacer()

                Image(systemName: "paperplane.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.95))
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .background(.black.opacity(0.88), in: Capsule(style: .continuous))
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.primary.opacity(0.10), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func avatarView(url: URL?, username: String) -> some View {
        ZStack {
            Circle().fill(Color.primary.opacity(0.06))
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView().tint(Color.primary.opacity(0.55))
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
        .frame(width: 42, height: 42)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.primary.opacity(0.10), lineWidth: 1))
    }

    private func initials(_ username: String) -> some View {
        let letters = username.prefix(2).uppercased()
        return Text(letters)
            .font(.system(size: 13, weight: .heavy, design: .rounded))
            .foregroundStyle(Color.primary.opacity(0.82))
    }

    private func matchSubtitle(for username: String) -> String {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard q.count >= 2 else { return "" }
        let u = username.lowercased()
        if u.hasPrefix(q) { return matchStartTitle }
        if u.contains(q) { return matchTitle }
        return ""
    }

    private func scheduleSearch(for raw: String) {
        searchTask?.cancel()

        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            results = []
            errorText = nil
            isLoading = false
            return
        }

        searchTask = Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            if Task.isCancelled { return }
            await MainActor.run {
                isLoading = true
                errorText = nil
            }

            do {
                let found = try await SupabaseService.shared.searchProfiles(
                    query: trimmed,
                    excludeProfileId: excludeProfileId,
                    limit: 10
                )
                await MainActor.run {
                    isLoading = false
                    results = found
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    results = []
                    errorText = UserFacingError.message(for: error, language: language)
                }
            }
        }
    }

    private var title: String {
        switch language {
        case .english: "invite"
        case .dutch: "invite"
        case .german: "einladen"
        case .spanish: "invitar"
        }
    }

    private var placeholder: String {
        switch language {
        case .english: "search username…"
        case .dutch: "zoek username…"
        case .german: "username suchen…"
        case .spanish: "buscar usuario…"
        }
    }

    private var emptyTitle: String {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.count < 2 {
            switch language {
            case .english: return "type at least 2 characters"
            case .dutch: return "typ minimaal 2 tekens"
            case .german: return "mindestens 2 zeichen"
            case .spanish: return "mínimo 2 caracteres"
            }
        } else {
            switch language {
            case .english: return "no users found"
            case .dutch: return "geen users gevonden"
            case .german: return "keine nutzer gefunden"
            case .spanish: return "no se encontraron usuarios"
            }
        }
    }

    private var loadingTitle: String {
        switch language {
        case .english: "searching…"
        case .dutch: "zoeken…"
        case .german: "suche…"
        case .spanish: "buscando…"
        }
    }

    private var matchTitle: String {
        switch language {
        case .english: "matches"
        case .dutch: "match"
        case .german: "treffer"
        case .spanish: "coincide"
        }
    }

    private var matchStartTitle: String {
        switch language {
        case .english: "starts with"
        case .dutch: "begint met"
        case .german: "beginnt mit"
        case .spanish: "empieza con"
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
}
