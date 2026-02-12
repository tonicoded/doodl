import Foundation
import UIKit

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
    static let allSourcesCode = "__all__"

    private enum Keys {
        static let latestDoodle = "widget.latestDoodle.v1"
        static let widgetConfig = "widget.config.v1"
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

    static func loadLatestDoodle() -> SharedWidgetDoodle? {
        guard let data = defaults.data(forKey: Keys.latestDoodle) else { return nil }
        return try? JSONDecoder().decode(SharedWidgetDoodle.self, from: data)
    }

    static func loadWidgetConfig() -> SharedWidgetConfig? {
        guard let data = defaults.data(forKey: Keys.widgetConfig) else { return nil }
        return try? JSONDecoder().decode(SharedWidgetConfig.self, from: data)
    }

    static func isAllSources(_ code: String) -> Bool {
        code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == allSourcesCode
    }

    // Widget snapshots can fail if the embedded image is too large. Downscale aggressively.
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

        UIGraphicsBeginImageContextWithOptions(targetSize, true, 1.0)
        UIColor.white.setFill()
        UIRectFill(CGRect(origin: .zero, size: targetSize))
        image.draw(in: CGRect(origin: .zero, size: targetSize))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        guard let png = resized?.pngData() else { return nil }
        return "data:image/png;base64,\(png.base64EncodedString())"
    }
}
