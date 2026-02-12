import SwiftUI

struct SnapDoodleViewer: View {
    struct Snap: Identifiable, Hashable {
        let id: String
        let senderUsername: String
        let senderIsPro: Bool
        let image: UIImage
        let createdAt: Date?
    }

    let snap: Snap
    let language: AppLanguage
    var autoDismissSeconds: Int = 10
    var onReply: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var startedAt = Date()
    @State private var timerTask: Task<Void, Never>?
    @State private var accumulatedPaused: TimeInterval = 0
    @State private var pauseStartedAt: Date?
    @GestureState private var isPressing = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Image(uiImage: snap.image)
                .resizable()
                .scaledToFit()
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    .black.opacity(0.70),
                    .black.opacity(0.35),
                    .clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 220)
            .frame(maxHeight: .infinity, alignment: .top)
            .allowsHitTesting(false)
        }
        .safeAreaInset(edge: .top) {
            VStack(spacing: 10) {
                progressBar
                    .padding(.horizontal, 14)
                topBar
                    .padding(.horizontal, 14)
            }
            .padding(.top, 10)
        }
        .safeAreaInset(edge: .bottom) {
            if onReply != nil {
                replyBar
                    .padding(.bottom, 14)
                    .padding(.horizontal, 14)
            }
        }
        .contentShape(Rectangle())
        .overlay {
            GeometryReader { geo in
                HStack(spacing: 0) {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            Haptics.tap(.light)
                            dismiss()
                        }
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            Haptics.tap(.light)
                            dismiss()
                        }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .updating($isPressing) { _, state, _ in
                    state = true
                }
        )
        .onChange(of: isPressing) { _, newValue in
            if newValue {
                pause()
            } else {
                resume()
            }
        }
        .gesture(
            DragGesture(minimumDistance: 16)
                .onEnded { value in
                    if value.translation.height > 120 {
                        Haptics.tap(.light)
                        dismiss()
                    }
                }
        )
        .onAppear {
            startTimer()
        }
        .onDisappear {
            timerTask?.cancel()
            timerTask = nil
        }
    }

    private func startTimer() {
        timerTask?.cancel()
        startedAt = Date()
        accumulatedPaused = 0
        pauseStartedAt = nil
        let seconds = max(1, autoDismissSeconds)
        timerTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(seconds) * 1_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { dismiss() }
        }
    }

    private func pause() {
        guard pauseStartedAt == nil else { return }
        pauseStartedAt = Date()
        timerTask?.cancel()
        timerTask = nil
    }

    private func resume() {
        guard let pausedAt = pauseStartedAt else { return }
        let now = Date()
        accumulatedPaused += now.timeIntervalSince(pausedAt)
        pauseStartedAt = nil
        scheduleRemainingTimer()
    }

    private func scheduleRemainingTimer() {
        timerTask?.cancel()
        timerTask = nil
        let duration = Double(max(1, autoDismissSeconds))
        let now = Date()
        let elapsed = now.timeIntervalSince(startedAt) - accumulatedPaused
        let remaining = max(0.05, duration - elapsed)
        timerTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run { dismiss() }
        }
    }

    private var progressBar: some View {
        let duration = Double(max(1, autoDismissSeconds))
        return TimelineView(.animation) { timeline in
            let now = pauseStartedAt ?? timeline.date
            let progress = progressValue(now: now, duration: duration)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(.white.opacity(0.20))
                    Capsule(style: .continuous)
                        .fill(.white.opacity(0.92))
                        .frame(width: geo.size.width * progress)
                }
            }
        }
        .frame(height: 3)
    }

    private func progressValue(now: Date, duration: Double) -> Double {
        guard duration > 0 else { return 0 }
        let elapsed = now.timeIntervalSince(startedAt) - accumulatedPaused
        return min(1, max(0, elapsed / duration))
    }

    private var topBar: some View {
        HStack(alignment: .center) {
            HStack(spacing: 6) {
                Text("@\(snap.senderUsername)")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.96))
                if snap.senderIsPro {
                    CrownBadge(size: 13)
                }
            }

            Spacer(minLength: 10)

            if let createdAt {
                Text(timeAgo(createdAt))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(.black.opacity(0.45), in: Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
    }

    private var replyBar: some View {
        HStack {
            Spacer(minLength: 0)
            Button {
                Haptics.tap(.medium)
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    onReply?()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 14, weight: .heavy))
                    Text(replyTitle)
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                }
                .foregroundStyle(.black.opacity(0.90))
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(Color(hex: "FFFC00").opacity(0.96), in: Capsule(style: .continuous))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(.white.opacity(0.14), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.35), radius: 14, x: 0, y: 10)
            }
            .buttonStyle(.plain)
        }
    }

    private var createdAt: Date? { snap.createdAt }

    private var replyTitle: String {
        switch language {
        case .english: "reply"
        case .dutch: "antwoord"
        case .german: "antworten"
        case .spanish: "responder"
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.locale = Locale(identifier: language.rawValue)
        return formatter.localizedString(for: date, relativeTo: Date()).lowercased()
    }
}
