import SwiftUI

struct RankDetailsSheet: View {
    let language: AppLanguage
    let xpState: ProfileXPState?
    let isLoading: Bool
    let onRefresh: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var level: Int { xpState?.level ?? 1 }

    private var progress: Double {
        guard let xpState else { return 0 }
        guard xpState.nextLevelXP > 0 else { return 0 }
        return max(0, min(1, Double(xpState.levelXP) / Double(xpState.nextLevelXP)))
    }

    private var title: String {
        switch language {
        case .english: return "your rank"
        case .dutch: return "jouw rank"
        case .german: return "dein rang"
        case .spanish: return "tu rango"
        }
    }

    private var refreshTitle: String {
        switch language {
        case .english: return "refresh"
        case .dutch: return "refresh"
        case .german: return "aktualisieren"
        case .spanish: return "actualizar"
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

    private var nextTitle: String {
        switch language {
        case .english: return "next"
        case .dutch: return "volgende"
        case .german: return "nächste"
        case .spanish: return "siguiente"
        }
    }

    private var allRanksTitle: String {
        switch language {
        case .english: return "all ranks"
        case .dutch: return "alle ranks"
        case .german: return "alle ränge"
        case .spanish: return "todos los rangos"
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                    let rank = DoodleRanks.rank(forLevel: level, language: language)
                    let nextRank = DoodleRanks.rank(forLevel: level + 1, language: language)

                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(Color.primary.opacity(0.06))
                            Image(systemName: rank.symbol)
                                .font(.system(size: 18, weight: .heavy))
                                .foregroundStyle(Color.primary.opacity(0.88))
                        }
                        .frame(width: 44, height: 44)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(DoodleRanks.rankLabel(language: language)) \(rank.index)/\(DoodleRanks.maxRank)")
                                .font(.system(size: 12, weight: .heavy, design: .rounded))
                                .foregroundStyle(.secondary.opacity(0.85))

                            Text(rank.title)
                                .font(.system(size: 18, weight: .heavy, design: .rounded))
                                .foregroundStyle(.primary.opacity(0.92))
                        }

                        Spacer()

                        Text("lvl \(level)")
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color.primary.opacity(0.72))
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(Color.primary.opacity(0.06), in: Capsule(style: .continuous))
                            .overlay(Capsule(style: .continuous).stroke(Color.primary.opacity(0.10), lineWidth: 1))
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .background(Color.primary.opacity(0.02), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.primary.opacity(0.08), lineWidth: 1))

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("xp")
                                .font(.system(size: 13, weight: .heavy, design: .rounded))
                                .foregroundStyle(Color.primary.opacity(0.82))
                            Spacer()
                            if let xpState {
                                Text("\(xpState.levelXP)/\(xpState.nextLevelXP)")
                                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.secondary.opacity(0.85))
                                    .monospacedDigit()
                            } else {
                                Text("—")
                                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.secondary.opacity(0.85))
                            }
                        }

                        ProgressView(value: progress)
                            .tint(Color(hex: "FFFC00").opacity(0.95))
                            .animation(.spring(response: 0.35, dampingFraction: 0.9), value: progress)

                        HStack {
                            Text("\(nextTitle): \(nextRank.title)")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary.opacity(0.85))
                                .lineLimit(1)
                            Spacer()
                            Button {
                                Haptics.tap(.light)
                                onRefresh()
                            } label: {
                                if isLoading {
                                    ProgressView().tint(Color.primary.opacity(0.72))
                                } else {
                                    Text(refreshTitle)
                                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                                        .foregroundStyle(Color.primary.opacity(0.82))
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(isLoading)
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .background(Color.primary.opacity(0.02), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.primary.opacity(0.08), lineWidth: 1))

                    VStack(alignment: .leading, spacing: 10) {
                        Text(allRanksTitle)
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color.primary.opacity(0.82))

                        let currentIndex = DoodleRanks.rank(forLevel: level, language: language).index
                        LazyVGrid(
                            columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                            spacing: 10
                        ) {
                            ForEach(1...DoodleRanks.maxRank, id: \.self) { idx in
                                let r = DoodleRanks.rank(forLevel: idx, language: language)
                                let isUnlocked = idx <= currentIndex
                                let isCurrent = idx == currentIndex
                                HStack(spacing: 10) {
                                    ZStack {
                                        Circle()
                                            .fill(isCurrent ? Color(hex: "FFFC00").opacity(0.95) : Color.primary.opacity(0.06))
                                        Image(systemName: r.symbol)
                                            .font(.system(size: 13, weight: .heavy))
                                            .foregroundStyle(isCurrent ? .black.opacity(0.88) : Color.primary.opacity(0.82))
                                    }
                                    .frame(width: 30, height: 30)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(r.title)
                                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                                            .foregroundStyle(Color.primary.opacity(0.92))
                                            .lineLimit(1)

                                        Text("lvl \(idx)")
                                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                                            .foregroundStyle(.secondary.opacity(0.85))
                                    }

                                    Spacer(minLength: 0)

                                    if !isUnlocked {
                                        Image(systemName: "lock.fill")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(Color.secondary.opacity(0.75))
                                    }
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    (isCurrent ? Color(hex: "FFFC00").opacity(0.14) : Color.primary.opacity(0.02)),
                                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(isCurrent ? Color(hex: "FFFC00").opacity(0.35) : Color.primary.opacity(0.08), lineWidth: 1)
                                )
                                .opacity(isUnlocked ? 1 : 0.55)
                            }
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .background(Color.primary.opacity(0.02), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.primary.opacity(0.08), lineWidth: 1))

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
}
