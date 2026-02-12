//
//  AdMobBootstrap.swift
//  DOODL.
//
//  Created by Anthony Verruijt on 12/02/2026.
//

import Foundation

#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

enum AdMobBootstrap {
    static func startIfConfigured() {
#if canImport(GoogleMobileAds)
        guard !AdMobConfig.appId.isEmpty else { return }

#if DEBUG
        let testDeviceIds = AdMobConfig.testDeviceIds
        if !testDeviceIds.isEmpty {
            GADMobileAds.sharedInstance().requestConfiguration.testDeviceIdentifiers = testDeviceIds
        }
#endif

        GADMobileAds.sharedInstance().start(completionHandler: nil)
#endif
    }
}
