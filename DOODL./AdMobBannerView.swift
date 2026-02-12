//
//  AdMobBannerView.swift
//  DOODL.
//
//  Created by Anthony Verruijt on 12/02/2026.
//

import SwiftUI
import UIKit

#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

struct AdMobBannerView: View {
    let adUnitId: String

    var body: some View {
#if canImport(GoogleMobileAds)
        GeometryReader { proxy in
            let width = max(0, proxy.size.width)
            AdMobBannerRepresentable(adUnitId: adUnitId, width: width)
                .frame(height: AdMobBannerRepresentable.height(forWidth: width))
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(height: AdMobBannerRepresentable.height(forWidth: UIScreen.main.bounds.width))
#else
        EmptyView()
#endif
    }
}

#if canImport(GoogleMobileAds)
private struct AdMobBannerRepresentable: UIViewRepresentable {
    let adUnitId: String
    let width: CGFloat

    func makeUIView(context: Context) -> GADBannerView {
        let banner = GADBannerView()
        banner.adUnitID = adUnitId
        banner.rootViewController = UIApplication.shared.topMostViewController
        banner.delegate = context.coordinator
        banner.adSize = Self.adSize(forWidth: width)
        banner.load(GADRequest())
        return banner
    }

    func updateUIView(_ uiView: GADBannerView, context: Context) {
        uiView.rootViewController = UIApplication.shared.topMostViewController
        let newSize = Self.adSize(forWidth: width)
        if !GADAdSizeEqualToSize(uiView.adSize, newSize) {
            uiView.adSize = newSize
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    static func adSize(forWidth width: CGFloat) -> GADAdSize {
        guard width > 0 else { return GADAdSizeBanner }
        return GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth(width)
    }

    static func height(forWidth width: CGFloat) -> CGFloat {
        adSize(forWidth: width).size.height
    }

    final class Coordinator: NSObject, GADBannerViewDelegate {}
}

private extension UIApplication {
    var topMostViewController: UIViewController? {
        let scenes = connectedScenes.compactMap { $0 as? UIWindowScene }
        let keyWindow = scenes
            .flatMap(\.windows)
            .first(where: { $0.isKeyWindow })
        var viewController = keyWindow?.rootViewController
        while let presented = viewController?.presentedViewController {
            viewController = presented
        }
        if let nav = viewController as? UINavigationController {
            return nav.visibleViewController ?? nav
        }
        if let tab = viewController as? UITabBarController {
            return tab.selectedViewController ?? tab
        }
        return viewController
    }
}
#endif

