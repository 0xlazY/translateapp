import Foundation
import PandouchkaCore

/// Stories shipped with the app (Pandouchka/Stories/stories.json).
enum StoryLibrary {
    static let all: [Story] = {
        guard let url = Bundle.main.url(forResource: "stories", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let collection = try? JSONDecoder().decode(StoryCollection.self, from: data)
        else { return [] }
        return collection.stories.sorted { ($0.level, $0.order) < ($1.level, $1.order) }
    }()

    static func story(id: String) -> Story? { all.first { $0.id == id } }
}

enum Prefs {
    static let directions = "directions"          // "ru-fr", "fr-ru" or "both"
    static let newPerDay = "newPerDay"
    static let retention = "retention"
    static let autoPlay = "autoPlay"
    static let showStress = "showStress"
    static let speechRate = "speechRate"
    static let readerSize = "readerSize"
    static let showLineTranslation = "showLineTranslation"

    static func enabledDirections(_ raw: String) -> [Direction] {
        switch raw {
        case "ru-fr": return [.ruFr]
        case "fr-ru": return [.frRu]
        default: return [.ruFr, .frRu]
        }
    }

    static var fsrs: FSRS {
        let r = UserDefaults.standard.double(forKey: retention)
        return FSRS(retention: r == 0 ? 0.9 : r)
    }
}
