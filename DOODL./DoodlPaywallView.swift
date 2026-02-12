import SwiftUI

struct DoodlPaywallView: View {
    let language: AppLanguage
    let showsClose: Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var purchaseManager: PurchaseManager

    @State private var selectedProductId: String?
    @State private var ambientPulse = false

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                header
                    .padding(.top, 10)
                    .padding(.horizontal, 14)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        heroCard
                        plansCard

                        if purchaseManager.isPro {
                            proActiveCard
                        }

                        unlockCard

                        if let error = purchaseManager.errorMessage, !error.isEmpty {
                            infoCard(title: localized.errorTitle, message: error)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                    .padding(.bottom, 18)
                }

                ctaBar
            }
        }
        .preferredColorScheme(.light)
        .task {
            if purchaseManager.products.isEmpty {
                await purchaseManager.refresh()
            }
            ensureDefaultSelection()
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                    ambientPulse = true
                }
            }
        }
        .onChange(of: purchaseManager.products.map(\.id)) { _, _ in
            ensureDefaultSelection()
        }
        .onChange(of: purchaseManager.isPro) { _, pro in
            if pro, showsClose {
                dismiss()
            }
        }
    }
}

private extension DoodlPaywallView {
    var localized: PaywallCopy {
        PaywallCopy.map[language] ?? .english
    }

    var background: some View {
        LinearGradient(
            colors: [Color.white, PaywallPalette.bgFade],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    var header: some View {
        HStack {
            if showsClose {
                Button {
                    Haptics.tap(.soft)
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(PaywallPalette.text.opacity(0.85))
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.white))
                        .overlay(Circle().stroke(PaywallPalette.border, lineWidth: 1))
                        .shadow(color: Color.black.opacity(0.06), radius: 14, x: 0, y: 10)
                }
                .buttonStyle(PremiumPlainButtonStyle(scale: 0.94, pressedOpacity: 0.92, animation: reduceMotion ? .linear(duration: 0.001) : .spring(response: 0.22, dampingFraction: 0.84)))
            }

            Spacer()
        }
    }

    var heroCard: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                PaywallPalette.yellow.opacity(ambientPulse ? 0.55 : 0.38),
                                PaywallPalette.yellow.opacity(0.0)
                            ],
                            center: .center,
                            startRadius: 8,
                            endRadius: 74
                        )
                    )
                    .frame(width: 150, height: 150)
                    .scaleEffect(ambientPulse ? 1.06 : 0.96)

                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 92, height: 92)
                    .shadow(color: Color.black.opacity(0.10), radius: 18, x: 0, y: 12)
                    .offset(y: reduceMotion ? 0 : (ambientPulse ? -2 : 2))
            }

            Text(localized.title)
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(PaywallPalette.text)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 12) {
                BenefitRow(text: localized.benefit1)
                BenefitRow(text: localized.benefit2)
                BenefitRow(text: localized.benefit3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 2)
        }
        .padding(18)
        .paywallCard()
    }

    var unlockCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localized.unlockTitle)
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(PaywallPalette.text)

            Text(localized.unlockSubtitle)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(PaywallPalette.text.opacity(0.70))
                .fixedSize(horizontal: false, vertical: true)

            Text(localized.disclosure)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(PaywallPalette.text.opacity(0.60))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .paywallCard()
    }

    var plansCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(localized.choosePlan)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(PaywallPalette.text)

                Spacer()

                if purchaseManager.isLoading {
                    ProgressView()
                        .tint(PaywallPalette.text.opacity(0.55))
                }
            }

            if !PurchaseManager.isRevenueCatAvailable {
                infoCard(title: localized.setupTitle, message: localized.setupRevenueCatMissing)
            } else if RevenueCatConfig.apiKey.isEmpty {
                infoCard(title: localized.setupTitle, message: localized.setupMissingApiKey)
            } else if purchaseManager.products.isEmpty {
                VStack(spacing: 10) {
                    PlanSkeleton()
                    PlanSkeleton()
                }
            } else {
                VStack(spacing: 12) {
                    ForEach(purchaseManager.products) { product in
                        let planDetails = planDetail(for: product)
                        PlanCard(
                            product: product,
                            isSelected: product.id == selectedProductId,
                            topDetail: planDetails.top,
                            bottomDetail: planDetails.bottom
                        )
                        .onTapGesture {
                            Haptics.selectionChanged()
                            selectedProductId = product.id
                        }
                    }
                }
            }
        }
        .padding(16)
        .paywallCard()
    }

    var proActiveCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.green.opacity(0.95))

            VStack(alignment: .leading, spacing: 2) {
                Text(localized.proActiveTitle)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(PaywallPalette.text)
                Text(localized.proActiveSubtitle)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(PaywallPalette.text.opacity(0.64))
            }

            Spacer(minLength: 0)

            Button(localized.manage) {
                Haptics.tap(.soft)
                openURL(URL(string: "https://apps.apple.com/account/subscriptions")!)
            }
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(PaywallPalette.text.opacity(0.78))
            .buttonStyle(PremiumPlainButtonStyle(scale: 0.96, pressedOpacity: 0.92))
        }
        .padding(14)
        .background(Color.green.opacity(0.07), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.green.opacity(0.20), lineWidth: 1)
        )
    }

    var ctaBar: some View {
        let selected = selectedProduct
        let ctaTitle = ctaText(for: selected)

        return VStack(spacing: 10) {
            Button {
                guard let selected else { return }
                Haptics.tap(.medium)
                Task { await purchaseManager.purchase(selected) }
            } label: {
                HStack {
                    Spacer(minLength: 0)
                    if purchaseManager.isLoading {
                        ProgressView().tint(.black.opacity(0.85))
                    }
                    Text(ctaTitle)
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(.black.opacity(0.88))
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(PaywallPalette.yellow)
                        .shadow(color: Color.black.opacity(0.14), radius: 18, x: 0, y: 12)
                )
            }
            .buttonStyle(PremiumPlainButtonStyle(scale: 0.98, pressedOpacity: 0.94, animation: reduceMotion ? .linear(duration: 0.001) : .spring(response: 0.20, dampingFraction: 0.86)))
            .disabled(selected == nil || purchaseManager.isLoading || purchaseManager.isPro)
            .opacity((selected == nil || purchaseManager.isPro) ? 0.60 : 1.0)

            if let selected, !purchaseManager.isPro {
                Text(disclosureText(for: selected))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(PaywallPalette.text.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
            }

            HStack(spacing: 18) {
                Button(localized.restore) {
                    Haptics.tap(.soft)
                    Task { await purchaseManager.restorePurchases() }
                }
                .disabled(purchaseManager.isLoading)

                Spacer()

                Button(localized.terms) {
                    Haptics.tap(.soft)
                    openURL(URL(string: "https://doodl-me.com/terms/")!)
                }
                Button(localized.privacy) {
                    Haptics.tap(.soft)
                    openURL(URL(string: "https://doodl-me.com/privacy/")!)
                }
            }
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(PaywallPalette.text.opacity(0.62))
            .buttonStyle(PremiumPlainButtonStyle(scale: 0.98, pressedOpacity: 0.90))
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .background(Color.white.opacity(0.92))
        .overlay(Divider().opacity(0.10), alignment: .top)
    }

    func ctaText(for product: ProProduct?) -> String {
        return localized.continueCTA
    }

    func disclosureText(for product: ProProduct) -> String {
        if product.isLifetime {
            return localized.lifetimeDisclosure
        }
        if let trial = product.trialText {
            return "\(trial). \(localized.trialThenPrefix) \(product.price) \(localized.perMonth). \(localized.renewsDisclosure)"
        }
        return "\(product.price) \(localized.perMonth). \(localized.renewsDisclosure)"
    }

    func planDetail(for product: ProProduct) -> (top: String?, bottom: String?) {
        if product.isLifetime {
            return (nil, localized.oneTimePurchase)
        }
        if product.isMonthly {
            if let trial = product.trialText {
                return (trial, "\(localized.trialThenPrefix) \(product.price) \(localized.perMonth)")
            }
            return (nil, "\(product.price) \(localized.perMonth)")
        }
        return (nil, product.subtitle)
    }

    func infoCard(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(PaywallPalette.text)
            Text(message)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(PaywallPalette.text.opacity(0.70))
        }
        .padding(14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(PaywallPalette.border, lineWidth: 1)
        )
    }

    var selectedProduct: ProProduct? {
        guard let selectedProductId else { return nil }
        return purchaseManager.products.first(where: { $0.id == selectedProductId })
    }

    func ensureDefaultSelection() {
        guard selectedProductId == nil else { return }
        guard !purchaseManager.products.isEmpty else { return }
        if let monthly = purchaseManager.products.first(where: { $0.isMonthly }) {
            selectedProductId = monthly.id
        } else {
            selectedProductId = purchaseManager.products.first?.id
        }
    }
}

private enum PaywallPalette {
    static let yellow = Color(hex: "FFFC00")
    static let bgFade = Color(hex: "F4F5F9")
    static let border = Color.black.opacity(0.08)
    static let text = Color.black.opacity(0.92)
}

private struct BenefitRow: View {
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(PaywallPalette.yellow.opacity(0.95))
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(.black.opacity(0.78))
            }
            .frame(width: 22, height: 22)

            Text(text)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(PaywallPalette.text.opacity(0.88))

            Spacer(minLength: 0)
        }
    }
}

private struct PlanCard: View {
    let product: ProProduct
    let isSelected: Bool
    let topDetail: String?
    let bottomDetail: String?

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .strokeBorder(isSelected ? PaywallPalette.text.opacity(0.70) : PaywallPalette.border, lineWidth: 1.5)
                    .background(Circle().fill(isSelected ? PaywallPalette.yellow.opacity(0.95) : Color.white))

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(.black.opacity(0.78))
                }
            }
            .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(product.title)
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(PaywallPalette.text)
                        .lineLimit(1)

                    if product.isLifetime {
                        Text("best value")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundStyle(.black.opacity(0.70))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule(style: .continuous).fill(PaywallPalette.yellow.opacity(0.70)))
                    }

                    Spacer(minLength: 0)
                }

                if let topDetail {
                    Text(topDetail)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(PaywallPalette.text.opacity(0.70))
                }

                if let bottomDetail {
                    Text(bottomDetail)
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(PaywallPalette.text.opacity(0.78))
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                } else {
                    Text(product.subtitle)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(PaywallPalette.text.opacity(0.55))
                }
            }

            Spacer(minLength: 0)

            Text(product.price)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(PaywallPalette.text.opacity(0.88))
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isSelected ? Color(hex: "FFFDE5") : Color.white)
        )
        .overlay(border)
        .shadow(color: Color.black.opacity(isSelected ? 0.08 : 0.04), radius: 16, x: 0, y: 10)
        .contentShape(Rectangle())
        .animation(.spring(response: 0.22, dampingFraction: 0.86), value: isSelected)
    }

    private var border: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(isSelected ? PaywallPalette.text.opacity(0.25) : PaywallPalette.border, lineWidth: isSelected ? 1.5 : 1)
    }
}

private struct PlanSkeleton: View {
    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Color.black.opacity(0.06))
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.black.opacity(0.06))
                    .frame(width: 120, height: 14)
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.black.opacity(0.05))
                    .frame(width: 160, height: 12)
            }

            Spacer()

            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.black.opacity(0.06))
                .frame(width: 60, height: 14)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(PaywallPalette.border, lineWidth: 1)
        )
        .redacted(reason: .placeholder)
    }
}

private extension View {
    func paywallCard() -> some View {
        self
            .background(Color.white, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(PaywallPalette.border, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 24, x: 0, y: 14)
    }
}

private extension ProProduct {
    var isMonthly: Bool {
        productIdentifier == "com.anthony.DOODL.monthly" || title.lowercased().contains("month")
    }

    var isLifetime: Bool {
        productIdentifier == "com.anthony.DOODL.lifetime" || title.lowercased().contains("life")
    }
}

private struct PaywallCopy {
    let title: String
    let unlockTitle: String
    let unlockSubtitle: String
    let benefit1: String
    let benefit2: String
    let benefit3: String
    let choosePlan: String
    let startTrialCTA: String
    let continueCTA: String
    let restore: String
    let terms: String
    let privacy: String
    let manage: String
    let proActiveTitle: String
    let proActiveSubtitle: String
    let oneTimePurchase: String
    let disclosure: String
    let errorTitle: String
    let setupTitle: String
    let setupRevenueCatMissing: String
    let setupMissingApiKey: String
    let perMonth: String
    let trialThenPrefix: String
    let renewsDisclosure: String
    let lifetimeDisclosure: String

    static let english = PaywallCopy(
        title: "Pick your plan",
        unlockTitle: "Unlock DOODL Pro",
        unlockSubtitle: "Monthly renews each month. Lifetime is one-time.",
        benefit1: "Create and join unlimited groups",
        benefit2: "Send unlimited doodles to everyone",
        benefit3: "Premium access to all new features",
        choosePlan: "Choose a plan",
        startTrialCTA: "Start free trial",
        continueCTA: "Continue",
        restore: "Restore Purchases",
        terms: "Terms",
        privacy: "Privacy",
        manage: "Manage",
        proActiveTitle: "Pro active",
        proActiveSubtitle: "Thanks for supporting DOODL.",
        oneTimePurchase: "One-time purchase",
        disclosure: "Subscription renews unless canceled at least 24 hours before the end of the period.",
        errorTitle: "Purchase issue",
        setupTitle: "Setup needed",
        setupRevenueCatMissing: "RevenueCat SDK isn’t linked yet.",
        setupMissingApiKey: "Add your RevenueCat Public SDK key in Info.plist (RevenueCatApiKey).",
        perMonth: "per month",
        trialThenPrefix: "Then",
        renewsDisclosure: "Renews until canceled.",
        lifetimeDisclosure: "One-time purchase. No subscription."
    )

    static let dutch = PaywallCopy(
        title: "Kies je plan",
        unlockTitle: "Ontgrendel DOODL Pro",
        unlockSubtitle: "Monthly verlengt elke maand. Lifetime is eenmalig.",
        benefit1: "Maak en join onbeperkt groepen",
        benefit2: "Stuur onbeperkt doodles naar iedereen",
        benefit3: "Premium toegang tot alle nieuwe features",
        choosePlan: "Kies een plan",
        startTrialCTA: "Start gratis proefperiode",
        continueCTA: "Doorgaan",
        restore: "Herstel aankopen",
        terms: "Terms",
        privacy: "Privacy",
        manage: "Beheer",
        proActiveTitle: "Pro actief",
        proActiveSubtitle: "Thanks voor je support.",
        oneTimePurchase: "Eenmalige aankoop",
        disclosure: "Abonnement verlengt automatisch tenzij je op tijd opzegt.",
        errorTitle: "Aankoop probleem",
        setupTitle: "Setup nodig",
        setupRevenueCatMissing: "RevenueCat SDK is nog niet gelinkt.",
        setupMissingApiKey: "Voeg je RevenueCat Public SDK key toe in Info.plist (RevenueCatApiKey).",
        perMonth: "per maand",
        trialThenPrefix: "Daarna",
        renewsDisclosure: "Verlengt automatisch tot je opzegt.",
        lifetimeDisclosure: "Eenmalige aankoop. Geen abonnement."
    )

    static let german = PaywallCopy(
        title: "Wähle deinen Plan",
        unlockTitle: "Schalte DOODL Pro frei",
        unlockSubtitle: "Monatlich verlängert sich. Lifetime ist einmalig.",
        benefit1: "Unbegrenzte Gruppen erstellen und beitreten",
        benefit2: "Unbegrenzte Doodles an alle senden",
        benefit3: "Premium Zugriff auf alle neuen Features",
        choosePlan: "Plan auswählen",
        startTrialCTA: "Gratis testen",
        continueCTA: "Weiter",
        restore: "Käufe wiederherstellen",
        terms: "AGB",
        privacy: "Datenschutz",
        manage: "Verwalten",
        proActiveTitle: "Pro aktiv",
        proActiveSubtitle: "Danke für deine Unterstützung.",
        oneTimePurchase: "Einmaliger Kauf",
        disclosure: "Abonnement verlängert sich automatisch, sofern nicht rechtzeitig gekündigt wird.",
        errorTitle: "Kaufproblem",
        setupTitle: "Setup nötig",
        setupRevenueCatMissing: "RevenueCat SDK ist nicht verknüpft.",
        setupMissingApiKey: "Füge deinen RevenueCat Public SDK key in Info.plist hinzu (RevenueCatApiKey).",
        perMonth: "pro Monat",
        trialThenPrefix: "Dann",
        renewsDisclosure: "Verlängert sich automatisch bis zur Kündigung.",
        lifetimeDisclosure: "Einmaliger Kauf. Kein Abo."
    )

    static let spanish = PaywallCopy(
        title: "Elige tu plan",
        unlockTitle: "Desbloquea DOODL Pro",
        unlockSubtitle: "Mensual se renueva cada mes. Lifetime es pago único.",
        benefit1: "Crea y únete a grupos ilimitados",
        benefit2: "Envía doodles ilimitados a todos",
        benefit3: "Acceso premium a nuevas funciones",
        choosePlan: "Elige un plan",
        startTrialCTA: "Prueba gratis",
        continueCTA: "Continuar",
        restore: "Restaurar compras",
        terms: "Términos",
        privacy: "Privacidad",
        manage: "Gestionar",
        proActiveTitle: "Pro activo",
        proActiveSubtitle: "Gracias por apoyar DOODL.",
        oneTimePurchase: "Pago único",
        disclosure: "La suscripción se renueva automáticamente a menos que se cancele a tiempo.",
        errorTitle: "Problema de compra",
        setupTitle: "Configuración necesaria",
        setupRevenueCatMissing: "RevenueCat SDK no está vinculado.",
        setupMissingApiKey: "Agrega tu clave pública de RevenueCat en Info.plist (RevenueCatApiKey).",
        perMonth: "por mes",
        trialThenPrefix: "Luego",
        renewsDisclosure: "Se renueva hasta cancelar.",
        lifetimeDisclosure: "Pago único. Sin suscripción."
    )

    static let map: [AppLanguage: PaywallCopy] = [
        .english: .english,
        .dutch: .dutch,
        .german: .german,
        .spanish: .spanish
    ]
}
