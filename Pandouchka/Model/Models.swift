import Foundation
import SwiftData
import PandouchkaCore

enum Direction: String, CaseIterable, Identifiable {
    case ruFr = "ru-fr"
    case frRu = "fr-ru"
    var id: String { rawValue }
    var label: String { self == .ruFr ? "Russian → French" : "French → Russian" }
}

@Model
final class Card {
    var id: UUID = UUID()
    /// Russian side, stress marked.
    var russian: String = ""
    var french: String = ""
    var notes: String = ""
    var example: String = ""
    var exampleTranslation: String = ""
    var tagsRaw: String = ""
    /// Lookup key of the Russian side, used to recognise the word in texts.
    var key: String = ""
    var createdAt: Date = Date()
    @Relationship(deleteRule: .cascade, inverse: \CardSchedule.card)
    var schedules: [CardSchedule] = []

    init(russian: String, french: String, notes: String = "", example: String = "", exampleTranslation: String = "",
         tags: [String] = [], createdAt: Date = Date()) {
        self.id = UUID()
        self.russian = russian
        self.french = french
        self.notes = notes
        self.example = example
        self.exampleTranslation = exampleTranslation
        self.tagsRaw = tags.joined(separator: " ")
        self.key = Card.key(for: russian)
        self.createdAt = createdAt
    }

    var tags: [String] { tagsRaw.split(separator: " ").map(String.init) }

    static func key(for russian: String) -> String {
        RussianText.key(russian.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func schedule(_ d: Direction) -> CardSchedule? { schedules.first { $0.direction == d.rawValue } }

    /// Predicted recall right now, using the Russian -> French direction (or the other one).
    var retrievability: Double? {
        let s = schedule(.ruFr) ?? schedules.first
        guard let s, s.phase != .new, let last = s.lastReview else { return nil }
        return FSRS.retrievability(days: Date().timeIntervalSince(last) / 86_400, stability: s.stability)
    }

    var record: CardRecord {
        var sched: [String: Schedule] = [:]
        for s in schedules { sched[s.direction] = s.value }
        return CardRecord(russian: russian, french: french, notes: notes, example: example,
                          exampleTranslation: exampleTranslation, tags: tags, createdAt: createdAt, schedules: sched)
    }
}

@Model
final class CardSchedule {
    var direction: String = Direction.ruFr.rawValue
    var phaseRaw: String = CardPhase.new.rawValue
    var due: Date = Date()
    var stability: Double = 0
    var difficulty: Double = 0
    var reps: Int = 0
    var lapses: Int = 0
    var lastReview: Date?
    var card: Card?

    init(direction: Direction, value: Schedule = .fresh()) {
        self.direction = direction.rawValue
        self.phaseRaw = value.phase.rawValue
        self.due = value.due
        self.stability = value.stability
        self.difficulty = value.difficulty
        self.reps = value.reps
        self.lapses = value.lapses
        self.lastReview = value.lastReview
    }

    var phase: CardPhase { CardPhase(rawValue: phaseRaw) ?? .new }

    var value: Schedule {
        get {
            Schedule(phase: phase, due: due, stability: stability, difficulty: difficulty, reps: reps,
                     lapses: lapses, lastReview: lastReview)
        }
        set {
            phaseRaw = newValue.phase.rawValue
            due = newValue.due
            stability = newValue.stability
            difficulty = newValue.difficulty
            reps = newValue.reps
            lapses = newValue.lapses
            lastReview = newValue.lastReview
        }
    }
}

@Model
final class ReviewLog {
    var date: Date = Date()
    var rating: Int = 3
    var direction: String = ""
    var wasNew: Bool = false
    var cardID: UUID = UUID()

    init(date: Date, rating: Rating, direction: Direction, wasNew: Bool, cardID: UUID) {
        self.date = date
        self.rating = rating.rawValue
        self.direction = direction.rawValue
        self.wasNew = wasNew
        self.cardID = cardID
    }
}

@Model
final class StoryProgress {
    @Attribute(.unique) var storyID: String = ""
    var openedAt: Date = Date()
    var completedAt: Date?
    var quizScore: Int?
    var furthestLine: Int = 0

    init(storyID: String) {
        self.storyID = storyID
    }
}

/// Words marked as already known: no card needed, not highlighted as new.
@Model
final class KnownWord {
    @Attribute(.unique) var key: String = ""
    var addedAt: Date = Date()

    init(key: String) {
        self.key = key
    }
}

enum Persistence {
    static let schema = Schema([Card.self, CardSchedule.self, ReviewLog.self, StoryProgress.self, KnownWord.self])

    static func container() -> ModelContainer {
        do {
            return try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema))
        } catch {
            fatalError("Could not open the database: \(error)")
        }
    }
}
