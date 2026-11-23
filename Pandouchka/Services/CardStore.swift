import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import PandouchkaCore

/// Card operations shared by the reader, the dictionary and the card list.
@MainActor
enum CardStore {
    @discardableResult
    static func add(_ record: CardRecord, in context: ModelContext) -> Card {
        let card = Card(russian: record.russian, french: record.french, notes: record.notes, example: record.example,
                        exampleTranslation: record.exampleTranslation, tags: record.tags, createdAt: record.createdAt)
        context.insert(card)
        for d in Direction.allCases {
            let s = CardSchedule(direction: d, value: record.schedules?[d.rawValue] ?? .fresh())
            context.insert(s)
            s.card = card
        }
        try? context.save()
        return card
    }

    static func cards(key: String, in context: ModelContext) -> [Card] {
        let k = key
        return (try? context.fetch(FetchDescriptor<Card>(predicate: #Predicate { $0.key == k }))) ?? []
    }

    static func allCards(in context: ModelContext) -> [Card] {
        (try? context.fetch(FetchDescriptor<Card>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))) ?? []
    }

    static func delete(_ card: Card, in context: ModelContext) {
        context.delete(card)
        try? context.save()
    }

    /// Records an answer and returns the new state.
    static func answer(_ schedule: CardSchedule, rating: Rating, in context: ModelContext, now: Date = Date()) {
        let wasNew = schedule.phase == .new
        schedule.value = Prefs.fsrs.answer(schedule.value, rating: rating, now: now)
        if let card = schedule.card {
            context.insert(ReviewLog(date: now, rating: rating, direction: Direction(rawValue: schedule.direction) ?? .ruFr,
                                     wasNew: wasNew, cardID: card.id))
        }
        try? context.save()
    }

    static func newIntroducedToday(in context: ModelContext) -> Int {
        let start = Calendar.current.startOfDay(for: Date())
        let d = FetchDescriptor<ReviewLog>(predicate: #Predicate { $0.date >= start && $0.wasNew == true })
        return (try? context.fetchCount(d)) ?? 0
    }

    /// What to study now: due learning/review cards, then new ones up to the daily limit.
    static func queue(in context: ModelContext, directions: [Direction], newLimit: Int, now: Date = Date()) -> [CardSchedule] {
        let raw = Set(directions.map(\.rawValue))
        let newRaw = CardPhase.new.rawValue
        let dueDescriptor = FetchDescriptor<CardSchedule>(
            predicate: #Predicate { $0.due <= now && $0.phaseRaw != newRaw },
            sortBy: [SortDescriptor(\.due)])
        let due = ((try? context.fetch(dueDescriptor)) ?? []).filter { raw.contains($0.direction) && $0.card != nil }

        let remaining = max(newLimit - newIntroducedToday(in: context), 0)
        var fresh: [CardSchedule] = []
        if remaining > 0 {
            let newDescriptor = FetchDescriptor<CardSchedule>(predicate: #Predicate { $0.phaseRaw == newRaw })
            let all = ((try? context.fetch(newDescriptor)) ?? []).filter { raw.contains($0.direction) && $0.card != nil }
            // Oldest cards first; Russian -> French before French -> Russian for the same card.
            fresh = all.sorted {
                let a = $0.card!.createdAt, b = $1.card!.createdAt
                return a != b ? a < b : $0.direction > $1.direction
            }
            // A new card counts once even if both directions are on.
            var cardsTaken = Set<UUID>()
            fresh = fresh.filter { s in
                let id = s.card!.id
                if cardsTaken.contains(id) { return true }
                guard cardsTaken.count < remaining else { return false }
                cardsTaken.insert(id)
                return true
            }
        }
        // Spread the two directions of a card apart.
        var out = due
        var later: [CardSchedule] = []
        var seen = Set<UUID>(due.compactMap { $0.card?.id })
        for s in fresh {
            if let id = s.card?.id, seen.contains(id) { later.append(s) } else {
                out.append(s)
                if let id = s.card?.id { seen.insert(id) }
            }
        }
        return out + later
    }

    static func dueCount(in context: ModelContext, directions: [Direction], newLimit: Int) -> Int {
        queue(in: context, directions: directions, newLimit: newLimit).count
    }

    // MARK: Import / export

    struct ImportResult {
        var added = 0
        var skipped = 0
    }

    static func importRecords(_ records: [CardRecord], in context: ModelContext) -> ImportResult {
        var existing = Set(allCards(in: context).map { $0.record.dedupeKey })
        var result = ImportResult()
        for r in records {
            if existing.contains(r.dedupeKey) {
                result.skipped += 1
                continue
            }
            existing.insert(r.dedupeKey)
            add(r, in: context)
            result.added += 1
        }
        return result
    }

    static func importFile(_ url: URL, in context: ModelContext) throws -> ImportResult {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        if url.pathExtension.lowercased() == "json" {
            return importRecords(try Backup.decode(data).cards, in: context)
        }
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
        return importRecords(CardCSV.import(text), in: context)
    }
}

/// File wrapper for exports through the system file picker.
struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText, .json] }
    var data: Data
    var contentType: UTType

    init(data: Data, contentType: UTType) {
        self.data = data
        self.contentType = contentType
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
        contentType = configuration.contentType
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
