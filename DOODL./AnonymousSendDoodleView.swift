//
//  AnonymousSendDoodleView.swift
//  DOODL.
//
//  Created by Anthony Verruijt on 17/12/2025.
//

import SwiftUI

struct AnonymousSendDoodleView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("selectedLanguage") private var storedLanguageRaw: String = AppLanguage.english.rawValue

    let shortCode: String
    @State private var didSend = false

    private var language: AppLanguage {
        AppLanguage(rawValue: storedLanguageRaw) ?? .english
    }

    private var isValid: Bool {
        let c = shortCode.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return (10...24).contains(c.count) && c.unicodeScalars.allSatisfy { CharacterSet(charactersIn: "0123456789abcdef").contains($0) }
    }

    var body: some View {
        ZStack {
            ThemedBackground()

            VStack(spacing: 16) {
                header
                    .padding(.horizontal, 16)
                    .padding(.top, 14)

                VStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.92))
                        .multilineTextAlignment(.center)

                    Text(subtitle)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary.opacity(0.85))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 28)

	                if isValid {
	                    DoodleCanvasView(language: language) { image in
	                        _ = try await SupabaseService.shared.submitAnonymousDoodle(image: image, shortCode: shortCode)
	                        await MainActor.run { didSend = true }
	                    }
	                    .padding(.horizontal, 16)
                } else {
                    Text(invalidMessage)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.88))
                        .padding(.horizontal, 22)
                        .padding(.vertical, 12)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(.black.opacity(0.10), lineWidth: 1)
                        )
                        .padding(.horizontal, 16)

                    Spacer()
                }
            }
        }
        .onChange(of: didSend) { _, newValue in
            guard newValue else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                dismiss()
            }
        }
    }
}

private extension AnonymousSendDoodleView {
    var header: some View {
        HStack {
            Button {
                Haptics.tap()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.black.opacity(0.78))
                    .padding(10)
                    .background(.thinMaterial, in: Circle())
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }

    var title: String {
        switch language {
        case .english: "anonymous doodl"
        case .dutch: "anonieme doodl"
        case .german: "anonymes doodl"
        case .spanish: "doodl anónimo"
        }
    }

    var subtitle: String {
        switch language {
        case .english: "draw something — it lands in their anonymous inbox."
        case .dutch: "teken iets — het komt in hun anonieme inbox."
        case .german: "zeichne etwas — es landet in ihrem anonymen postfach."
        case .spanish: "dibuja algo — llega a su bandeja anónima."
        }
    }

    var invalidMessage: String {
        switch language {
        case .english: "this link looks invalid. ask them for a fresh anonymous link in settings."
        case .dutch: "deze link klopt niet. vraag om een nieuwe anonieme link in settings."
        case .german: "dieser link ist ungültig. bitte um einen neuen anonym-link in den einstellungen."
        case .spanish: "este enlace no es válido. pide un enlace anónimo nuevo en ajustes."
        }
    }
}
