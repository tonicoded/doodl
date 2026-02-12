import SwiftUI

enum DashboardTutorialAnchor: Hashable {
    case groupSwitcherPill
    case headerTabs
    case inboxModeTabs
    case addFriendButton
    case refreshButton
    case toolsButton
    case sendButton
    case membersButton
    case settingsButton
}

struct DashboardTutorialStep: Equatable {
    let anchor: DashboardTutorialAnchor
    let title: String
    let message: String
}

struct DashboardTutorialOverlay: View {
    let language: AppLanguage
    let anchors: [DashboardTutorialAnchor: Anchor<CGRect>]
    @Binding var stepIndex: Int
    let onSkip: () -> Void
    let onFinish: () -> Void

    private var steps: [DashboardTutorialStep] {
        switch language {
        case .english:
            return [
                DashboardTutorialStep(
                    anchor: .headerTabs,
                    title: "inbox / doodle / pro",
                    message: "use these tabs to switch between your inbox, drawing, and pro."
                ),
                DashboardTutorialStep(
                    anchor: .inboxModeTabs,
                    title: "friends / groups",
                    message: "switch between friends and groups here."
                ),
                DashboardTutorialStep(
                    anchor: .addFriendButton,
                    title: "add friends",
                    message: "search @usernames and add friends to start doodling."
                ),
                DashboardTutorialStep(
                    anchor: .toolsButton,
                    title: "tools",
                    message: "change pen type, color, and size."
                ),
                DashboardTutorialStep(
                    anchor: .sendButton,
                    title: "send",
                    message: "draw something and tap send. choose who to send it to."
                ),
                DashboardTutorialStep(
                    anchor: .settingsButton,
                    title: "settings",
                    message: "change profile, language, and more."
                )
            ]
        case .dutch:
            return [
                DashboardTutorialStep(
                    anchor: .headerTabs,
                    title: "inbox / doodle / pro",
                    message: "gebruik deze tabs om te switchen tussen inbox, tekenen en pro."
                ),
                DashboardTutorialStep(
                    anchor: .inboxModeTabs,
                    title: "friends / groups",
                    message: "wissel hier tussen vrienden en groepen."
                ),
                DashboardTutorialStep(
                    anchor: .addFriendButton,
                    title: "vrienden toevoegen",
                    message: "zoek op @username en voeg vrienden toe om te starten."
                ),
                DashboardTutorialStep(
                    anchor: .toolsButton,
                    title: "tools",
                    message: "verander pen type, kleur en grootte."
                ),
                DashboardTutorialStep(
                    anchor: .sendButton,
                    title: "versturen",
                    message: "teken iets en tik op versturen. kies wie het krijgt."
                ),
                DashboardTutorialStep(
                    anchor: .settingsButton,
                    title: "instellingen",
                    message: "pas je profiel, taal en meer aan."
                )
            ]
        case .german:
            return [
                DashboardTutorialStep(
                    anchor: .headerTabs,
                    title: "inbox / doodle / pro",
                    message: "nutze diese tabs für inbox, zeichnen und pro."
                ),
                DashboardTutorialStep(
                    anchor: .inboxModeTabs,
                    title: "freunde / gruppen",
                    message: "wechsle hier zwischen freunden und gruppen."
                ),
                DashboardTutorialStep(
                    anchor: .addFriendButton,
                    title: "freunde hinzufügen",
                    message: "suche nach @usernames und füge freunde hinzu."
                ),
                DashboardTutorialStep(
                    anchor: .toolsButton,
                    title: "tools",
                    message: "stiftart, farbe und größe ändern."
                ),
                DashboardTutorialStep(
                    anchor: .sendButton,
                    title: "senden",
                    message: "zeichne etwas und tippe senden. wähle empfänger."
                ),
                DashboardTutorialStep(
                    anchor: .settingsButton,
                    title: "einstellungen",
                    message: "profil, sprache und mehr anpassen."
                )
            ]
        case .spanish:
            return [
                DashboardTutorialStep(
                    anchor: .headerTabs,
                    title: "inbox / doodle / pro",
                    message: "usa estas pestañas para inbox, dibujar y pro."
                ),
                DashboardTutorialStep(
                    anchor: .inboxModeTabs,
                    title: "amigos / grupos",
                    message: "cambia entre amigos y grupos aquí."
                ),
                DashboardTutorialStep(
                    anchor: .addFriendButton,
                    title: "añadir amigos",
                    message: "busca @usernames y añade amigos para empezar."
                ),
                DashboardTutorialStep(
                    anchor: .toolsButton,
                    title: "tools",
                    message: "cambia el tipo de pincel, color y tamaño."
                ),
                DashboardTutorialStep(
                    anchor: .sendButton,
                    title: "enviar",
                    message: "dibuja algo y toca enviar. elige destinatarios."
                ),
                DashboardTutorialStep(
                    anchor: .settingsButton,
                    title: "ajustes",
                    message: "actualiza perfil, idioma y más."
                )
            ]
        }
    }

    private var skipTitle: String {
        switch language {
        case .english: "skip"
        case .dutch: "overslaan"
        case .german: "überspringen"
        case .spanish: "omitir"
        }
    }

    private var nextTitle: String {
        switch language {
        case .english: "next"
        case .dutch: "volgende"
        case .german: "weiter"
        case .spanish: "siguiente"
        }
    }

    private var backTitle: String {
        switch language {
        case .english: "back"
        case .dutch: "terug"
        case .german: "zurück"
        case .spanish: "atrás"
        }
    }

    private var doneTitle: String {
        switch language {
        case .english: "done"
        case .dutch: "klaar"
        case .german: "fertig"
        case .spanish: "listo"
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let safeSteps = steps
            if stepIndex >= 0, stepIndex < safeSteps.count {
                let step = safeSteps[stepIndex]
                let rect = anchors[step.anchor].map { proxy[$0] }

                ZStack {
                    Color.black.opacity(0.55)
                        .ignoresSafeArea()
                        .onTapGesture {
                            advance()
                        }

                    if let rect {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(.white.opacity(0.90), lineWidth: 2)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(.white.opacity(0.08))
                            )
                            .frame(width: rect.width + 16, height: rect.height + 16)
                            .position(x: rect.midX, y: rect.midY)
                            .allowsHitTesting(false)

                        tutorialCard(step: step, highlightRect: rect, proxy: proxy)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else {
                        let fallbackRect = CGRect(
                            x: (proxy.size.width - 180) / 2,
                            y: (proxy.size.height - 44) / 2,
                            width: 180,
                            height: 44
                        )
                        tutorialCard(step: step, highlightRect: fallbackRect, proxy: proxy)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.86), value: stepIndex)
            } else {
                EmptyView()
            }
        }
    }

    private func tutorialCard(step: DashboardTutorialStep, highlightRect: CGRect, proxy: GeometryProxy) -> some View {
        let screen = proxy.size
        let prefersAbove = highlightRect.midY > screen.height * 0.55
        let maxWidth: CGFloat = min(360, screen.width - 32)

        return VStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text(step.title)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text(step.message)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 10) {
                Button(skipTitle) { onSkip() }
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(.white.opacity(0.10), in: Capsule(style: .continuous))

                Spacer()

                Button(backTitle) {
                    if stepIndex > 0 { stepIndex -= 1 }
                }
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(.white.opacity(0.10), in: Capsule(style: .continuous))
                .disabled(stepIndex == 0)
                .opacity(stepIndex == 0 ? 0.35 : 1)

                Button(stepIndex == steps.count - 1 ? doneTitle : nextTitle) {
                    advance()
                }
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(.black)
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(.white.opacity(0.92), in: Capsule(style: .continuous))
            }
        }
        .padding(16)
        .frame(width: maxWidth)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
        .position(
            x: screen.width / 2,
            y: prefersAbove
                ? max(70, highlightRect.minY - 14 - 110)
                : min(screen.height - 70, highlightRect.maxY + 14 + 110)
        )
    }

    private func advance() {
        if stepIndex >= steps.count - 1 {
            onFinish()
        } else {
            stepIndex += 1
        }
    }
}

struct DashboardTutorialAnchorsKey: PreferenceKey {
    static var defaultValue: [DashboardTutorialAnchor: Anchor<CGRect>] = [:]
    static func reduce(value: inout [DashboardTutorialAnchor: Anchor<CGRect>], nextValue: () -> [DashboardTutorialAnchor: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

extension View {
    func dashboardTutorialAnchor(_ key: DashboardTutorialAnchor) -> some View {
        anchorPreference(key: DashboardTutorialAnchorsKey.self, value: .bounds) { [key: $0] }
    }
}
