import SwiftUI

struct GroupReplyComposerView: View {
    let language: AppLanguage
    let group: GroupSummary
    let profileId: String
    let pairingCode: String
    let onSent: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            DoodleCanvasView(
                language: language,
                onSend: { image in
                    _ = try await SupabaseService.shared.sendDoodle(
                        image: image,
                        groupCode: group.code,
                        senderProfileId: profileId,
                        senderPairingCode: pairingCode
                    )
                },
                onSent: {
                    dismiss()
                    onSent()
                }
            )
        }
        .safeAreaInset(edge: .top) {
            topBar
                .padding(.top, 10)
                .padding(.horizontal, 14)
                .padding(.bottom, 8)
        }
        .overlay(alignment: .top) {
            if let errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.95))
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(.black.opacity(0.75), in: Capsule(style: .continuous))
                    .padding(.top, 64)
                    .transition(.opacity)
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Button {
                Haptics.tap(.light)
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

            Spacer(minLength: 0)

            Text(groupTitle)
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.primary.opacity(0.92))
                .lineLimit(1)

            Spacer(minLength: 0)

            Circle()
                .fill(.clear)
                .frame(width: 44, height: 44)
        }
    }

    private var groupTitle: String {
        let cleaned = (group.displayName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleaned.isEmpty { return cleaned }
        switch language {
        case .english: return "group"
        case .dutch: return "groep"
        case .german: return "gruppe"
        case .spanish: return "grupo"
        }
    }
}
