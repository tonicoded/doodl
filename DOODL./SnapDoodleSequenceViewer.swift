import SwiftUI

struct SnapDoodleSequenceViewer: View {
    let snaps: [SnapDoodleViewer.Snap]
    let language: AppLanguage
    var autoAdvanceSeconds: Int = 10
    var onReply: (() -> Void)? = nil
    /// Called when the viewer closes (either naturally or via user dismiss).
    /// - Parameters:
    ///   - seenAt: The `createdAt` of the last snap the user actually reached (falls back to `Date()`).
    ///   - finishedAll: True only when the user reached the end of the sequence.
    var onFinished: ((_ seenAt: Date, _ finishedAll: Bool) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var index = 0
    @State private var didFinish = false
    @State private var timerTask: Task<Void, Never>?
    @State private var startedAt = Date()
    @State private var accumulatedPaused: TimeInterval = 0
    @State private var pauseStartedAt: Date?
    @GestureState private var isPressing = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let snap = currentSnap {
                Image(uiImage: snap.image)
                    .resizable()
                    .scaledToFit()
                    .ignoresSafeArea()
            }

            // Readability / Snapchat-like top fade.
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
            // Tap left/right to go back/forward. Hold to pause.
            GeometryReader { geo in
                HStack(spacing: 0) {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            Haptics.tap(.light)
                            goBack()
                        }
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            Haptics.tap(.light)
                            advance()
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
                        finishAndDismiss(finishedAll: index >= snaps.count - 1)
                    }
                }
        )
        .onAppear {
            startTimer()
        }
        .onChange(of: index) { _, _ in
            startTimer()
        }
        .onDisappear {
            timerTask?.cancel()
            timerTask = nil
        }
    }

    private var currentSnap: SnapDoodleViewer.Snap? {
        guard !snaps.isEmpty else { return nil }
        return snaps[min(max(0, index), snaps.count - 1)]
    }

    private func startTimer() {
        timerTask?.cancel()
        startedAt = Date()
        accumulatedPaused = 0
        pauseStartedAt = nil
        let seconds = max(1, autoAdvanceSeconds)
        timerTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(seconds) * 1_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                advance()
            }
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
        let duration = Double(max(1, autoAdvanceSeconds))
        let now = Date()
        let elapsed = now.timeIntervalSince(startedAt) - accumulatedPaused
        let remaining = max(0.05, duration - elapsed)
        timerTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                advance()
            }
        }
    }

    private func advance() {
        guard !snaps.isEmpty else {
            finishAndDismiss(finishedAll: true)
            return
        }
        let next = index + 1
        if next >= snaps.count {
            finishAndDismiss(finishedAll: true)
        } else {
            index = next
        }
    }

    private func goBack() {
        guard !snaps.isEmpty else { return }
        let prev = max(0, index - 1)
        guard prev != index else { return }
        index = prev
    }

    private func finishAndDismiss(finishedAll: Bool) {
        guard !didFinish else { return }
        didFinish = true
        timerTask?.cancel()
        timerTask = nil
        let seenAt = currentSnap?.createdAt ?? Date()
        onFinished?(seenAt, finishedAll)
        dismiss()
    }

    private var progressBar: some View {
        let duration = Double(max(1, autoAdvanceSeconds))
        return TimelineView(.animation) { timeline in
            let now = pauseStartedAt ?? timeline.date
            let currentProgress = progressValue(now: now, duration: duration)
            HStack(spacing: 4) {
                ForEach(Array(snaps.indices), id: \.self) { i in
                    let segmentProgress = segmentProgressValue(i: i, currentProgress: currentProgress)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule(style: .continuous)
                                .fill(.white.opacity(0.20))
                            Capsule(style: .continuous)
                                .fill(.white.opacity(0.92))
                                .frame(width: geo.size.width * segmentProgress)
                        }
                    }
                    .frame(height: 3)
                }
            }
            .opacity(snaps.isEmpty ? 0 : 1)
        }
        .frame(height: 3)
    }

    private func segmentProgressValue(i: Int, currentProgress: Double) -> Double {
        if i < index { return 1 }
        if i == index { return currentProgress }
        return 0
    }

    private func progressValue(now: Date, duration: Double) -> Double {
        guard duration > 0 else { return 0 }
        let elapsed = now.timeIntervalSince(startedAt) - accumulatedPaused
        return min(1, max(0, elapsed / duration))
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Button {
                Haptics.tap(.light)
                finishAndDismiss(finishedAll: index >= snaps.count - 1)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(.white.opacity(0.95))
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(.black.opacity(0.45), in: Capsule(style: .continuous))
                    .overlay(Capsule().stroke(.white.opacity(0.14), lineWidth: 1))
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            if let snap = currentSnap {
                HStack(spacing: 10) {
                    HStack(spacing: 6) {
                        Text("@\(snap.senderUsername)")
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white.opacity(0.96))
                        if snap.senderIsPro {
                            CrownBadge(size: 13)
                        }
                    }

                    if let createdAt = snap.createdAt {
                        Text(timeAgo(createdAt))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.75))
                    }

                    Text("\(min(index + 1, snaps.count))/\(snaps.count)")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white.opacity(0.80))
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(.white.opacity(0.12), in: Capsule(style: .continuous))
                        .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 1))
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(.black.opacity(0.45), in: Capsule(style: .continuous))
                .overlay(Capsule().stroke(.white.opacity(0.14), lineWidth: 1))
            }
        }
    }

    private var replyBar: some View {
        HStack {
            Spacer(minLength: 0)
            Button {
                Haptics.tap(.medium)
                finishAndDismiss(finishedAll: index >= snaps.count - 1)
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
                .overlay(Capsule().stroke(.white.opacity(0.14), lineWidth: 1))
                .shadow(color: .black.opacity(0.35), radius: 14, x: 0, y: 10)
            }
            .buttonStyle(.plain)
        }
    }

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
