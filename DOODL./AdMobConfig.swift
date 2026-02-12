//
//  AdMobConfig.swift
//  DOODL.
//
//  Created by Anthony Verruijt on 12/02/2026.
//

import Foundation

enum AdMobConfig {
    static var appId: String {
        (Bundle.main.object(forInfoDictionaryKey: "GADApplicationIdentifier") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    static var bannerUnitId: String {
        (Bundle.main.object(forInfoDictionaryKey: "AdMobBannerUnitId") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    static var testDeviceIds: [String] {
        let raw = (Bundle.main.object(forInfoDictionaryKey: "AdMobTestDeviceIds") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !raw.isEmpty else { return [] }
        return raw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
