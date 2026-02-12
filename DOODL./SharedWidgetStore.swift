import Foundation
#if canImport(UIKit)
import UIKit
#endif
#if canImport(WidgetKit)
import WidgetKit
#endif

struct SharedWidgetDoodle: Codable, Hashable {
    let doodleId: String?
    let senderUsername: String
    let contentBase64: String
    let createdAt: Date
}

struct SharedWidgetConfig: Codable, Hashable {
    let groupCode: String
    let profileId: String
    let username: String
}

enum SharedWidgetStore {
    // Special sentinel code meaning: show the latest doodl from ANY chat/group.
    // (We avoid empty string because we want to persist a valid config for the widget.)
    static let allSourcesCode = "__all__"

    private enum Keys {
        static let latestDoodle = "widget.latestDoodle.v1"
        static let widgetConfig = "widget.config.v1"
        static let widgetSources = "widget.sources.v1"
    }

    private static var defaults: UserDefaults {
        if let suite = UserDefaults(suiteName: AppGroup.identifier) {
            return suite
        }
#if DEBUG
        print("widget store warning: app group not available (\(AppGroup.identifier)). enable app groups for app + widget target.")
#endif
        return .standard
    }

    static func saveLatestDoodle(_ doodle: SharedWidgetDoodle?) {
        if let doodle {
            let normalized = SharedWidgetDoodle(
                doodleId: doodle.doodleId,
                senderUsername: doodle.senderUsername,
                contentBase64: normalizeDataURLForWidget(doodle.contentBase64) ?? doodle.contentBase64,
                createdAt: doodle.createdAt
            )
            if let data = try? JSONEncoder().encode(normalized) {
                defaults.set(data, forKey: Keys.latestDoodle)
            }
        } else {
            defaults.removeObject(forKey: Keys.latestDoodle)
        }
    }

    static func upsertLatestDoodle(_ doodle: SharedWidgetDoodle, reloadTimelines: Bool = true) {
        let existing = loadLatestDoodle()
        if let existing {
            if doodle.createdAt < existing.createdAt { return }
            if doodle.createdAt == existing.createdAt, doodle.doodleId == existing.doodleId { return }
        }
        saveLatestDoodle(doodle)
#if canImport(WidgetKit)
        if reloadTimelines {
            WidgetCenter.shared.reloadAllTimelines()
        }
#endif
    }

    static func saveWidgetConfig(groupCode: String?, profileId: String?, username: String?) {
        guard
            let groupCode = groupCode?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            let profileId = profileId?.trimmingCharacters(in: .whitespacesAndNewlines),
            let username = username?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            !groupCode.isEmpty,
            !profileId.isEmpty,
            !username.isEmpty
        else {
            defaults.removeObject(forKey: Keys.widgetConfig)
            return
        }

        let config = SharedWidgetConfig(groupCode: groupCode, profileId: profileId, username: username)
        if let data = try? JSONEncoder().encode(config) {
            defaults.set(data, forKey: Keys.widgetConfig)
        }
    }

    static func loadWidgetConfig() -> SharedWidgetConfig? {
        guard let data = defaults.data(forKey: Keys.widgetConfig) else { return nil }
        return try? JSONDecoder().decode(SharedWidgetConfig.self, from: data)
    }

    static func loadLatestDoodle() -> SharedWidgetDoodle? {
        guard let data = defaults.data(forKey: Keys.latestDoodle) else { return nil }
        return try? JSONDecoder().decode(SharedWidgetDoodle.self, from: data)
    }

    static func effectiveWidgetSourceCode() -> String {
        let code = (loadWidgetConfig()?.groupCode ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return code.isEmpty ? allSourcesCode : code
    }

    static func isAllSources(_ code: String) -> Bool {
        code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == allSourcesCode
    }

    static func saveWidgetSources(_ codes: [String]) {
        let normalized = Array(
            Set(
                codes
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                    .filter { !$0.isEmpty }
            )
        ).sorted()
        if let data = try? JSONEncoder().encode(normalized) {
            defaults.set(data, forKey: Keys.widgetSources)
        }
    }

    static func loadWidgetSources() -> [String] {
        guard let data = defaults.data(forKey: Keys.widgetSources) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }

    // Widget snapshots can fail if the embedded image is too large. Downscale aggressively.
#if canImport(UIKit)
    private static func normalizeDataURLForWidget(_ dataURL: String) -> String? {
        let base64: String
        if let commaIndex = dataURL.firstIndex(of: ",") {
            base64 = String(dataURL[dataURL.index(after: commaIndex)...])
        } else {
            base64 = dataURL
        }

        guard let data = Data(base64Encoded: base64, options: [.ignoreUnknownCharacters]),
              let image = UIImage(data: data) else { return nil }

        // Keep the widget snapshot safely under WidgetKit's max pixel area.
        let maxPixels: CGFloat = 512
        let width = image.size.width
        let height = image.size.height
        guard width > 0, height > 0 else { return nil }

        let scale = min(maxPixels / width, maxPixels / height, 1)
        let targetSize = CGSize(width: floor(width * scale), height: floor(height * scale))
        guard targetSize.width >= 1, targetSize.height >= 1 else { return nil }

        // Match the approach from lovablee: resize at scale=1 and flatten onto white.
        UIGraphicsBeginImageContextWithOptions(targetSize, true, 1.0)
        UIColor.white.setFill()
        UIRectFill(CGRect(origin: .zero, size: targetSize))
        image.draw(in: CGRect(origin: .zero, size: targetSize))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        guard let png = resized?.pngData() else { return nil }
        return "data:image/png;base64,\(png.base64EncodedString())"
    }
#else
    private static func normalizeDataURLForWidget(_ dataURL: String) -> String? {
        nil
    }
#endif
}
