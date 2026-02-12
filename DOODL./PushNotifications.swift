import Foundation
import UIKit
import UserNotifications
import WidgetKit

extension Notification.Name {
    static let apnsTokenDidUpdate = Notification.Name("apnsTokenDidUpdate")
    static let apnsRegistrationFailed = Notification.Name("apnsRegistrationFailed")
    static let doodlInboxShouldRefresh = Notification.Name("doodlInboxShouldRefresh")
    static let doodlAnonymousInboxShouldRefresh = Notification.Name("doodlAnonymousInboxShouldRefresh")
    static let doodlShowPro = Notification.Name("doodlShowPro")
}

enum PushEnvironment: String {
    case sandbox
    case production

    static var current: PushEnvironment {
#if DEBUG
        return .sandbox
#else
        return .production
#endif
    }
}

final class PushNotifications {
    private static let tokenKey = "push.lastToken"

    static var cachedToken: String? {
        UserDefaults.standard.string(forKey: tokenKey)
    }

    static func cacheToken(_ token: String) {
        UserDefaults.standard.set(token, forKey: tokenKey)
    }

    static func requestAuthorizationIfNeeded() {
        let hasRequested = UserDefaults.standard.bool(forKey: "push.hasRequested")
        if hasRequested {
            ensureRegisteredIfAuthorized()
            return
        }
        UserDefaults.standard.set(true, forKey: "push.hasRequested")

        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error {
                NotificationCenter.default.post(name: .apnsRegistrationFailed, object: error)
                return
            }
            guard granted else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    static func ensureRegisteredIfAuthorized() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        AdMobBootstrap.startIfConfigured()
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        PushNotifications.cacheToken(token)
        NotificationCenter.default.post(name: .apnsTokenDidUpdate, object: token)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        NotificationCenter.default.post(name: .apnsRegistrationFailed, object: error)
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        Task {
            let result = await Self.refreshInboxAndWidgetFromPush(userInfo: userInfo)
            completionHandler(result)
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // When the app is in the foreground, iOS often calls `willPresent` without invoking the
        // background fetch delegate. Kick off the same refresh so the widget updates instantly.
        Task {
            _ = await Self.refreshInboxAndWidgetFromPush(userInfo: notification.request.content.userInfo)
        }
        if #available(iOS 14.0, *) {
            return [UNNotificationPresentationOptions.banner, UNNotificationPresentationOptions.sound]
        } else {
            return [UNNotificationPresentationOptions.alert, UNNotificationPresentationOptions.sound]
        }
    }

    private static func refreshInboxAndWidgetFromPush(userInfo: [AnyHashable: Any]) async -> UIBackgroundFetchResult {
        if let kind = (userInfo["kind"] as? String)?.lowercased(), kind == "anonymous" {
            return await refreshAnonymousInboxFromPush()
        }
        guard let onboarding = OnboardingStorage.load() else {
            return .noData
        }

        // The widget always shows the latest doodl across all chats/groups ("all sources").
        let isAllSources = true

        // Prefer the group/chat code from the push payload (works for both groups + DMs).
        // If it's missing, fall back to the joined group (if any); otherwise use the user’s own code.
        let pushedDoodleId = (userInfo["doodle_id"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let pushGroupCode = (userInfo["group_code"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        var groupCode =
            (pushGroupCode?.isEmpty == false ? pushGroupCode : nil)
            ?? (onboarding.joinedCode ?? onboarding.pairingCode).lowercased()

        // Transition/back-compat: if the push didn't include `group_code` and we're in "all sources"
        // mode, try to resolve the correct group code using the doodle id against known sources.
        if pushGroupCode?.isEmpty != false, isAllSources, let pushedDoodleId {
            let candidates = SharedWidgetStore.loadWidgetSources()
            if !candidates.isEmpty {
                for code in candidates.prefix(30) {
                    let fetched = try? await SupabaseService.shared.fetchDoodleContents(
                        groupCode: code,
                        requesterProfileId: onboarding.profileId,
                        doodleIds: [pushedDoodleId]
                    )
                    if fetched?[pushedDoodleId] != nil {
                        groupCode = code
                        break
                    }
                }
            }
        }
        let requesterProfileId = onboarding.profileId
        let myUsername = onboarding.username.lowercased()

        // If this push didn't include enough info to identify a doodl, skip any DB work.
        if pushGroupCode?.isEmpty != false, pushedDoodleId == nil {
            return .noData
        }

        do {
            // Avoid the heavy `inbox_doodles_secure` RPC (base64 payloads can hit statement timeouts).
            // Fetch lightweight metas first, then fetch a single doodle content if needed.
        let metas = try await SupabaseService.shared.fetchInboxDoodleMetas(
            groupCode: groupCode,
            requesterProfileId: requesterProfileId,
            limit: 18
        )

            NotificationCenter.default.post(name: .doodlInboxShouldRefresh, object: groupCode)

            let metaToShow =
                pushedDoodleId.flatMap { id in metas.first(where: { $0.id == id }) }
                ?? metas.first(where: { $0.senderUsername.lowercased() != myUsername })

            guard let metaToShow else {
                return .noData
            }

            let fetched = try? await SupabaseService.shared.fetchDoodleContents(
                groupCode: groupCode,
                requesterProfileId: requesterProfileId,
                doodleIds: [metaToShow.id]
            )
            let content = fetched?[metaToShow.id]

            if let content {
                SharedWidgetStore.upsertLatestDoodle(
                    SharedWidgetDoodle(
                        doodleId: metaToShow.id,
                        senderUsername: metaToShow.senderUsername,
                        contentBase64: content,
                        createdAt: metaToShow.createdAt ?? Date()
                    )
                )
            }
            return .newData
        } catch {
            return .failed
        }
    }

    private static func refreshAnonymousInboxFromPush() async -> UIBackgroundFetchResult {
        guard let onboarding = OnboardingStorage.load() else {
            return .noData
        }
        let profileId = onboarding.profileId
        let pairingCode = onboarding.pairingCode

        do {
            let doodles = try await SupabaseService.shared.fetchAnonymousInboxDoodles(
                profileId: profileId,
                profilePairingCode: pairingCode,
                limit: 50
            )
            NotificationCenter.default.post(name: .doodlAnonymousInboxShouldRefresh, object: nil)
            return doodles.isEmpty ? .noData : .newData
        } catch {
            return .failed
        }
    }
}
