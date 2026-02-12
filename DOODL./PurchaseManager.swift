//
//  PurchaseManager.swift
//  DOODL.
//
//  Created by Anthony Verruijt on 17/12/2025.
//

import Foundation
import Combine

#if canImport(RevenueCat)
import RevenueCat
#endif

struct ProProduct: Identifiable {
    let id: String
    let productIdentifier: String
    let title: String
    let subtitle: String
    let price: String
    let trialText: String?
    fileprivate let sortKey: Int
#if canImport(RevenueCat)
    fileprivate let package: Package
#endif
}

@MainActor
final class PurchaseManager: ObservableObject {
    static let proEntitlementId = "pro"
    static let isRevenueCatAvailable: Bool = {
#if canImport(RevenueCat)
        return true
#else
        return false
#endif
    }()

    @Published private(set) var isPro: Bool = false
    @Published private(set) var products: [ProProduct] = []
    @Published private(set) var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published private(set) var isConfigured: Bool = false
    @Published private(set) var currentAppUserId: String?

#if canImport(RevenueCat)
    private var didConfigure = false
    private var isIdentifying = false

    func configureIfNeeded(apiKey: String) {
        guard !didConfigure else { return }
        didConfigure = true
        isConfigured = true
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: apiKey)
    }

    func identify(appUserId: String) async {
        let trimmed = appUserId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard isConfigured else { return }
        guard currentAppUserId != trimmed else { return }
        guard !isIdentifying else { return }
        isIdentifying = true
        defer { isIdentifying = false }

        do {
            let info = try await logIn(appUserId: trimmed)
            currentAppUserId = trimmed
            apply(customerInfo: info)
        } catch {
            // Keep app usable even if identification fails.
        }
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let info = try await customerInfo()
            apply(customerInfo: info)
        } catch {
            errorMessage = UserFacingError.message(for: error)
        }

        do {
            let offerings = try await offerings()
            await apply(offerings: offerings)
        } catch {
            // Keep app usable even if offerings fail.
        }
    }

    func purchase(_ product: ProProduct) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let info = try await purchase(package: product.package)
            apply(customerInfo: info)
        } catch {
            let ns = error as NSError
            if ns.domain == "PurchaseManager", ns.code == -3 {
                return
            }
            errorMessage = UserFacingError.message(for: error)
        }
    }

    func restorePurchases() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let info = try await restore()
            apply(customerInfo: info)
        } catch {
            errorMessage = UserFacingError.message(for: error)
        }
    }

    private func apply(customerInfo: CustomerInfo) {
        isPro = customerInfo.entitlements.active[Self.proEntitlementId] != nil
    }

    private func apply(offerings: Offerings) async {
        guard let current = offerings.current else {
            errorMessage = "no offering configured in revenuecat"
            return
        }
        let packages = current.availablePackages
        let productIds = Array(Set(packages.map { $0.storeProduct.productIdentifier }))
        let eligibility = await trialEligibility(for: productIds)

        var result: [ProProduct] = []
        for package in packages {
            let (title, subtitle, sortKey): (String, String, Int)
            switch package.packageType {
            case .monthly:
                title = "Monthly"
                subtitle = "Billed monthly"
                sortKey = 0
            case .lifetime:
                title = "Lifetime"
                subtitle = "Pay once, keep forever"
                sortKey = 1
            default:
                continue
            }

            result.append(
                ProProduct(
                    id: package.identifier,
                    productIdentifier: package.storeProduct.productIdentifier,
                    title: title,
                    subtitle: subtitle,
                    price: package.storeProduct.localizedPriceString,
                    trialText: trialText(for: package.storeProduct, eligibility: eligibility[package.storeProduct.productIdentifier]),
                    sortKey: sortKey,
                    package: package
                )
            )
        }

        products = result.sorted { $0.sortKey < $1.sortKey }
        if products.isEmpty {
            errorMessage = "no monthly/lifetime packages in current offering"
        }
    }

    private func trialText(for product: StoreProduct, eligibility: IntroEligibility?) -> String? {
        // Only show the free-trial label if this customer is eligible for it.
        if let eligibility, eligibility.status != .eligible {
            return nil
        }

        guard let discount = product.introductoryDiscount else { return nil }
        guard discount.paymentMode == .freeTrial else { return nil }

        let period = discount.subscriptionPeriod
        let count = period.value
        let singularUnit: String
        switch period.unit {
        case .day: singularUnit = "day"
        case .week: singularUnit = "week"
        case .month: singularUnit = "month"
        case .year: singularUnit = "year"
        @unknown default: singularUnit = "period"
        }
        return "\(count)-\(singularUnit) free trial"
    }

    private func trialEligibility(for productIdentifiers: [String]) async -> [String: IntroEligibility] {
        guard !productIdentifiers.isEmpty else { return [:] }
        return await withCheckedContinuation { continuation in
            Purchases.shared.checkTrialOrIntroDiscountEligibility(productIdentifiers: productIdentifiers) { eligibilities in
                continuation.resume(returning: eligibilities)
            }
        }
    }

    private func customerInfo() async throws -> CustomerInfo {
        try await withCheckedThrowingContinuation { continuation in
            Purchases.shared.getCustomerInfo { info, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let info else {
                    continuation.resume(throwing: NSError(domain: "PurchaseManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "missing customer info"]))
                    return
                }
                continuation.resume(returning: info)
            }
        }
    }

    private func offerings() async throws -> Offerings {
        try await withCheckedThrowingContinuation { continuation in
            Purchases.shared.getOfferings { offerings, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let offerings else {
                    continuation.resume(throwing: NSError(domain: "PurchaseManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "missing offerings"]))
                    return
                }
                continuation.resume(returning: offerings)
            }
        }
    }

    private func purchase(package: Package) async throws -> CustomerInfo {
        try await withCheckedThrowingContinuation { continuation in
            Purchases.shared.purchase(package: package) { _, customerInfo, error, userCancelled in
                if userCancelled {
                    continuation.resume(throwing: NSError(domain: "PurchaseManager", code: -3, userInfo: [NSLocalizedDescriptionKey: "cancelled"]))
                    return
                }
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let customerInfo else {
                    continuation.resume(throwing: NSError(domain: "PurchaseManager", code: -4, userInfo: [NSLocalizedDescriptionKey: "missing customer info"]))
                    return
                }
                continuation.resume(returning: customerInfo)
            }
        }
    }

    private func restore() async throws -> CustomerInfo {
        try await withCheckedThrowingContinuation { continuation in
            Purchases.shared.restorePurchases { customerInfo, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let customerInfo else {
                    continuation.resume(throwing: NSError(domain: "PurchaseManager", code: -5, userInfo: [NSLocalizedDescriptionKey: "missing customer info"]))
                    return
                }
                continuation.resume(returning: customerInfo)
            }
        }
    }

    private func logIn(appUserId: String) async throws -> CustomerInfo {
        try await withCheckedThrowingContinuation { continuation in
            Purchases.shared.logIn(appUserId) { customerInfo, _, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let customerInfo else {
                    continuation.resume(throwing: NSError(domain: "PurchaseManager", code: -6, userInfo: [NSLocalizedDescriptionKey: "missing customer info"]))
                    return
                }
                continuation.resume(returning: customerInfo)
            }
        }
    }
#else
    func configureIfNeeded(apiKey: String) {
        // RevenueCat SDK not linked yet.
    }

    func identify(appUserId: String) async {}
    func refresh() async {}
    func purchase(_ product: ProProduct) async {}
    func restorePurchases() async {}
#endif
}
