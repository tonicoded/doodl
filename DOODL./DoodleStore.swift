import Foundation
import UIKit

enum DoodleStore {
    private static let fileName = "latest_doodl.png"

    static var latestURL: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent(fileName)
    }

    static func saveLatest(_ image: UIImage) {
        guard let url = latestURL else { return }
        guard let data = image.pngData() else { return }
        try? data.write(to: url, options: [.atomic])
    }

    static func loadLatest() -> UIImage? {
        guard let url = latestURL else { return nil }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    static func clear() {
        guard let url = latestURL else { return }
        try? FileManager.default.removeItem(at: url)
    }
}

