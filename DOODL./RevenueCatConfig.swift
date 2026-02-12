//
//  RevenueCatConfig.swift
//  DOODL.
//
//  Created by Anthony Verruijt on 17/12/2025.
//

import Foundation

enum RevenueCatConfig {
    static var apiKey: String {
        (Bundle.main.object(forInfoDictionaryKey: "RevenueCatApiKey") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}

