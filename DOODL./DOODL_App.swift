//
//  DOODL_App.swift
//  DOODL.
//
//  Created by Anthony Verruijt on 15/12/2025.
//

import SwiftUI

@main
struct DOODL_App: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var deepLinkRouter = DeepLinkRouter()
    @StateObject private var purchaseManager = PurchaseManager()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light)
                .environmentObject(deepLinkRouter)
                .environmentObject(purchaseManager)
                .onOpenURL { url in
                    deepLinkRouter.handle(url: url)
                }
                .task {
                    let key = RevenueCatConfig.apiKey
                    if !key.isEmpty {
                        purchaseManager.configureIfNeeded(apiKey: key)
                        await purchaseManager.refresh()
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .active else { return }
                    Task {
                        let key = RevenueCatConfig.apiKey
                        if !key.isEmpty {
                            purchaseManager.configureIfNeeded(apiKey: key)
                            await purchaseManager.refresh()
                        }
                    }
                }
        }
    }
}
