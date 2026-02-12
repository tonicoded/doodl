import SwiftUI

struct FriendProfileSheet: View {
    let language: AppLanguage
    let thread: DirectChatThread

    @Environment(\.dismiss) private var dismiss

    private var title: String {
        switch language {
        case .english: return "profile"
        case .dutch: return "profiel"
        case .german: return "profil"
        case .spanish: return "perfil"
        }
    }

    private var doneTitle: String {
        switch language {
        case .english: return "done"
        case .dutch: return "klaar"
        case .german: return "fertig"
        case .spanish: return "listo"
        }
    }

    private var copyTitle: String {
        switch language {
        case .english: return "copy username"
        case .dutch: return "kopieer username"
        case .german: return "username kopieren"
        case .spanish: return "copiar usuario"
        }
    }

    private var statsTitle: String {
        switch language {
        case .english: return "stats"
        case .dutch: return "stats"
        case .german: return "stats"
        case .spanish: return "stats"
        }
    }

    private var levelLabel: String {
        switch language {
        case .english: return "level"
        case .dutch: return "level"
        case .german: return "level"
        case .spanish: return "nivel"
        }
    }

    private var rankLabel: String { DoodleRanks.rankLabel(language: language) }

    private var streakLabel: String {
        switch language {
        case .english: return "streak"
        case .dutch: return "streak"
        case .german: return "streak"
        case .spanish: return "racha"
        }
    }

    private var proLabel: String {
        switch language {
        case .english: return "pro"
        case .dutch: return "pro"
        case .german: return "pro"
        case .spanish: return "pro"
        }
    }

    private var avatarSize: CGFloat { 92 }

    private var levelValue: Int? {
        if let v = thread.otherLevel, v > 0 { return v }
        if let v = thread.otherRank, v > 0 { return v }
        return nil
    }

    private var rankIndexValue: Int? {
        if let lvl = thread.otherLevel, lvl > 0 { return DoodleRanks.rank(forLevel: lvl, language: language).index }
        if let r = thread.otherRank, r > 0 { return r }
        return nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        VStack(spacing: 10) {
                            AvatarCircle(url: thread.otherAvatarURL, fallbackText: initials(from: thread.otherUsername))
                                .frame(width: avatarSize, height: avatarSize)
                                .overlay(Circle().stroke(Color.primary.opacity(0.10), lineWidth: 1))

                            HStack(spacing: 8) {
                                Text("@\(thread.otherUsername)")
                                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.primary.opacity(0.92))
                                if thread.otherIsPro {
                                    CrownBadge(size: 16)
                                }
                            }

                            if let level = levelValue {
                                let rank = DoodleRanks.rank(forLevel: level, language: language)
                                HStack(spacing: 8) {
                                    Image(systemName: rank.symbol)
                                        .font(.system(size: 13, weight: .heavy))
                                        .foregroundStyle(Color.primary.opacity(0.82))
                                    Text("\(rankLabel) \(rank.index)/\(DoodleRanks.maxRank) • \(rank.title)")
                                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                                        .foregroundStyle(Color.primary.opacity(0.82))
                                        .lineLimit(1)
                                }
                                .padding(.vertical, 7)
                                .padding(.horizontal, 12)
                                .background(Color.primary.opacity(0.06), in: Capsule(style: .continuous))
                                .overlay(Capsule(style: .continuous).stroke(Color.primary.opacity(0.10), lineWidth: 1))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)

                        VStack(alignment: .leading, spacing: 10) {
                            Text(statsTitle)
                                .font(.system(size: 13, weight: .heavy, design: .rounded))
                                .foregroundStyle(Color.primary.opacity(0.82))

                            statsRow(title: levelLabel, value: levelValue.map(String.init) ?? "—", icon: "chart.bar.fill")
                            statsRow(
                                title: rankLabel,
                                value: rankIndexValue.map { "\($0)/\(DoodleRanks.maxRank)" } ?? "—",
                                icon: "sparkles"
                            )
                            statsRow(title: streakLabel, value: "\(max(0, thread.streakCount))", icon: "flame.fill")
                            statsRow(title: proLabel, value: thread.otherIsPro ? "yes" : "no", icon: "crown.fill")
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 14)
                        .background(Color.primary.opacity(0.02), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.primary.opacity(0.08), lineWidth: 1))

                        Button {
                            Haptics.tap(.light)
                            #if canImport(UIKit)
                            UIPasteboard.general.string = "@\(thread.otherUsername)"
                            #endif
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 14, weight: .heavy))
                                Text(copyTitle)
                                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                                Spacer()
                            }
                            .foregroundStyle(.white.opacity(0.96))
                            .padding(.vertical, 14)
                            .padding(.horizontal, 14)
                            .background(.black.opacity(0.90), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(doneTitle) {
                        Haptics.tap(.light)
                        dismiss()
                    }
                    .foregroundStyle(Color.primary.opacity(0.82))
                }
            }
        }
    }

    private func statsRow(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(Color.primary.opacity(0.06))
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Color.primary.opacity(0.80))
            }
            .frame(width: 28, height: 28)

            Text(title)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.primary.opacity(0.82))

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.primary.opacity(0.92))
                .monospacedDigit()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color.primary.opacity(0.02), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.primary.opacity(0.08), lineWidth: 1))
    }

    private func initials(from username: String) -> String {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "?" }
        let parts = trimmed.split(separator: "_").flatMap { $0.split(separator: ".") }
        let first = parts.first?.first.map(String.init) ?? String(trimmed.prefix(1))
        let second = (parts.dropFirst().first?.first).map(String.init) ?? String(trimmed.dropFirst().prefix(1))
        return (first + second).uppercased()
    }
}
