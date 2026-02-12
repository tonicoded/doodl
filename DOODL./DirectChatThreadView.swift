import SwiftUI

struct DirectChatThreadView: View {
    let language: AppLanguage
    let thread: DirectChatThread
    let profileId: String
    let pairingCode: String

    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var doodles: [InboxDoodle] = []
    @State private var selectedDoodle: InboxDoodle?
    @State private var viewerImage: UIImage?
    @State private var showComposer = false
    @State private var pendingRefresh = false

    private var title: String { "@\(thread.otherUsername)" }

    var body: some View {
        NavigationStack {
            ZStack {
                ThemedBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
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
                                .padding(.top, 10)
                        } else if doodles.isEmpty {
                            emptyState
                        } else {
                            doodleGrid
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
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
                            .padding(10)
                            .background(.thinMaterial, in: Circle())
                            .overlay(Circle().stroke(Color.primary.opacity(0.10), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 10) {
                        Button {
                            Haptics.tap(.light)
                            Task {
                                let code = thread.code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                                guard await ActionRateLimiter.shared.allow(
                                    key: "directChatThread.refresh.\(code)",
                                    cooldownSeconds: 1.5
                                ) else { return }
                                await refresh(force: true)
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 14, weight: .heavy))
                                .foregroundStyle(Color.primary.opacity(0.82))
                                .padding(10)
                                .background(.thinMaterial, in: Circle())
                                .overlay(Circle().stroke(Color.primary.opacity(0.10), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .disabled(isLoading)

                        Button {
                            Haptics.tap(.medium)
                            showComposer = true
                        } label: {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 14, weight: .heavy))
                                .foregroundStyle(.white)
                                .padding(.vertical, 9)
                                .padding(.horizontal, 12)
                                .background(.black.opacity(0.9), in: Capsule(style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .task {
                await refresh(force: false)
            }
            .sheet(item: $selectedDoodle) { doodle in
                DoodleLightboxView(
                    image: viewerImage,
                    senderTitle: doodle.senderUsername.isEmpty ? title : "@\(doodle.senderUsername)",
                    createdAt: doodle.createdAt,
                    language: language
                )
            }
            .sheet(isPresented: $showComposer) {
                NavigationStack {
                    ZStack {
                        ThemedBackground()
                        VStack(spacing: 14) {
                            Text(sendTitle)
                                .font(.system(size: 16, weight: .heavy, design: .rounded))
                                .foregroundStyle(.primary.opacity(0.92))

                            DoodleCanvasView(language: language) { image in
                                let _ = try await SupabaseService.shared.sendDoodle(
                                    image: image,
                                    groupCode: thread.code,
                                    senderProfileId: profileId,
                                    senderPairingCode: pairingCode
                                )
                                await refresh(force: true)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        .padding(.bottom, 18)
                    }
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button(closeTitle) {
                                Haptics.tap()
                                showComposer = false
                            }
                            .foregroundStyle(.primary.opacity(0.92))
                        }
                    }
                }
            }
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
        .padding(.vertical, 16)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.10), lineWidth: 1)
        )
    }

    private var doodleGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
            ForEach(doodles) { doodle in
                DirectChatDoodleCell(doodle: doodle) { image in
                    viewerImage = image
                    selectedDoodle = doodle
                }
            }
        }
        .padding(.top, 4)
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
            // Keep aligned with server-side retention cap.
            let metas = try await SupabaseService.shared.fetchInboxDoodleMetas(
                groupCode: thread.code,
                requesterProfileId: profileId,
                limit: 18
            )
            var hydrated = metas
            let ids = metas.map(\.id)
            let contents = try await SupabaseService.shared.fetchDoodleContents(
                groupCode: thread.code,
                requesterProfileId: profileId,
                doodleIds: ids
            )
            hydrated = hydrated.map { m in
                InboxDoodle(
                    id: m.id,
                    senderProfileId: m.senderProfileId,
                    contentBase64: contents[m.id],
                    senderUsername: m.senderUsername,
                    createdAt: m.createdAt
                )
            }
            doodles = hydrated
        } catch {
            errorMessage = UserFacingError.message(for: error, language: language)
        }
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
        return UIImage(data: data)?.withRenderingMode(.alwaysOriginal)
    }

    private var sendTitle: String {
        switch language {
        case .english: "send a doodl"
        case .dutch: "stuur een doodl"
        case .german: "sende ein doodl"
        case .spanish: "envía un doodl"
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

    private var emptyTitle: String {
        switch language {
        case .english: "no doodls yet"
        case .dutch: "nog geen doodls"
        case .german: "noch keine doodls"
        case .spanish: "aún no hay doodls"
        }
    }

    private var emptySubtitle: String {
        switch language {
        case .english: "send your first one to start this chat."
        case .dutch: "stuur je eerste om deze chat te starten."
        case .german: "sende dein erstes, um den chat zu starten."
        case .spanish: "envía el primero para empezar este chat."
        }
    }
}

private struct DirectChatDoodleCell: View {
    let doodle: InboxDoodle
    let onOpen: (UIImage?) -> Void

    var body: some View {
        Button {
            Haptics.tap()
            onOpen(decode(doodle.contentBase64))
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.primary.opacity(0.10), lineWidth: 1)
                    )

                if let image = decode(doodle.contentBase64) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                } else {
                    Image(systemName: "scribble.variable")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(Color.secondary.opacity(0.85))
                }
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(.plain)
    }

    private func decode(_ content: String?) -> UIImage? {
        guard let content, !content.isEmpty else { return nil }
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
}

private struct DoodleLightboxView: View {
    let image: UIImage?
    let senderTitle: String
    let createdAt: Date?
    let language: AppLanguage

    @Environment(\.dismiss) private var dismiss
    @State private var zoom: CGFloat = 1
    @State private var lastZoom: CGFloat = 1

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(zoom)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                zoom = max(1, min(5, lastZoom * value))
                            }
                            .onEnded { _ in
                                lastZoom = zoom
                            }
                    )
                    .padding(.horizontal, 12)
            } else {
                ProgressView().tint(.white.opacity(0.9))
            }

            VStack {
                HStack {
                    Button {
                        Haptics.tap()
                        dismiss()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "xmark")
                            Text(closeTitle)
                        }
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(.black.opacity(0.55), in: Capsule(style: .continuous))
                        .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(senderTitle)
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white.opacity(0.96))
                        if let createdAt {
                            Text(timeAgo(createdAt))
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.75))
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 16)

                Spacer()
            }
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.locale = Locale(identifier: language.rawValue)
        return formatter.localizedString(for: date, relativeTo: Date()).lowercased()
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
