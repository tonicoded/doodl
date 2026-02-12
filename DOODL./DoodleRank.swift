import Foundation

struct DoodleRank: Hashable {
    let index: Int
    let title: String
    let symbol: String
}

enum DoodleRanks {
    static let maxRank: Int = 20

    static func rank(forLevel level: Int, language: AppLanguage) -> DoodleRank {
        let clampedLevel = max(1, level)
        let idx = min(maxRank, clampedLevel)

        let titles: [String] = {
            switch language {
            case .dutch:
                return [
                    "rookie",
                    "krabbelaar",
                    "schetser",
                    "inker",
                    "colorist",
                    "lijnmeester",
                    "illustrator",
                    "stylist",
                    "creatieveling",
                    "virtuoos",
                    "meester",
                    "elite",
                    "legende",
                    "icoon",
                    "titaan",
                    "mythisch",
                    "apex",
                    "kosmisch",
                    "onsterfelijk",
                    "ultimate"
                ]
            case .english, .german, .spanish:
                return [
                    "rookie",
                    "scribbler",
                    "sketcher",
                    "inker",
                    "colorist",
                    "line master",
                    "illustrator",
                    "stylist",
                    "creator",
                    "virtuoso",
                    "master",
                    "elite",
                    "legend",
                    "icon",
                    "titan",
                    "mythic",
                    "apex",
                    "cosmic",
                    "immortal",
                    "ultimate"
                ]
            }
        }()

        let symbols: [String] = [
            "sparkle",
            "pencil",
            "pencil.and.outline",
            "scribble",
            "paintbrush.pointed",
            "scope",
            "photo.artframe",
            "wand.and.stars",
            "star",
            "sparkles",
            "crown",
            "crown.fill",
            "laurel.leading",
            "seal.fill",
            "bolt.fill",
            "flame.fill",
            "arrow.up.right",
            "globe.europe.africa.fill",
            "infinity",
            "diamond.fill"
        ]

        let title = titles[idx - 1]
        let symbol = symbols[min(symbols.count - 1, idx - 1)]
        return DoodleRank(index: idx, title: title, symbol: symbol)
    }

    static func rankLabel(language: AppLanguage) -> String {
        switch language {
        case .english: return "rank"
        case .dutch: return "rank"
        case .german: return "rang"
        case .spanish: return "rango"
        }
    }
}

