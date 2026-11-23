import Foundation
import XCTest
@testable import PandouchkaCore

final class RussianTextTests: XCTestCase {
    func testKey() {
        XCTAssertEqual(RussianText.key("Ёлка"), "елка")
        XCTAssertEqual(RussianText.key("чита́ю"), "читаю")
        XCTAssertEqual(RussianText.key("ПРИВЕТ"), "привет")
    }

    func testStress() {
        XCTAssertEqual(RussianText.applyStress("книга", index: 2), "кни\u{301}га".replacingOccurrences(of: "и\u{301}", with: "и\u{301}"))
        XCTAssertEqual(RussianText.stripStress(RussianText.applyStress("Москва", index: 5)), "Москва")
        XCTAssertTrue(RussianText.applyStress("Москва", index: 5).unicodeScalars.contains("\u{301}"))
        // One vowel or ё: no mark.
        XCTAssertEqual(RussianText.applyStress("дом", index: 1), "дом")
        XCTAssertEqual(RussianText.applyStress("ёлка", index: 0), "ёлка")
        // Index on a consonant is ignored.
        XCTAssertEqual(RussianText.applyStress("книга", index: 0), "книга")
    }

    func testRestoreYo() {
        XCTAssertEqual(RussianText.restoreYo("Елка", from: "ёлка"), "Ёлка")
        XCTAssertEqual(RussianText.restoreYo("шел", from: "шёл"), "шёл")
        XCTAssertEqual(RussianText.restoreYo("дом", from: "дома"), "дом")
    }

    func testTokenize() {
        let t = Tokenizer.tokenize("Привет, что-то — по-русски!")
        XCTAssertEqual(t.filter(\.isWord).map(\.text), ["Привет", "что-то", "по-русски"])
        XCTAssertEqual(t.map(\.text).joined(), "Привет, что-то — по-русски!")
        XCTAssertEqual(t[0].utf16Offset, 0)
        XCTAssertEqual(t[1].utf16Offset, 6)
        XCTAssertEqual(Tokenizer.tokenIndex(in: t, utf16Offset: 9), 2)
    }

    func testTokenizeStressMarks() {
        let t = Tokenizer.tokenize("Я чита\u{301}ю.")
        XCTAssertEqual(t.filter(\.isWord).map { RussianText.key($0.text) }, ["я", "читаю"])
    }

    func testTransliteration() {
        XCTAssertEqual(Transliteration.toCyrillic("privet"), "привет")
        XCTAssertEqual(Transliteration.toCyrillic("khorosho"), "хорошо")
        XCTAssertEqual(Transliteration.toCyrillic("shchi"), "щи")
        XCTAssertEqual(Transliteration.toCyrillic("moy"), "мой")
        XCTAssertEqual(Transliteration.toCyrillic("ty"), "ты")
        XCTAssertEqual(Transliteration.toCyrillic("zhurnal"), "журнал")
        XCTAssertEqual(Transliteration.toCyrillic("yabloko"), "яблоко")
    }
}

final class FSRSTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let day = 86_400.0

    func testNewCardLearningSteps() {
        let f = FSRS()
        let c = Schedule.fresh(now: now)
        let again = f.review(c, rating: .again, now: now)
        XCTAssertEqual(again.phase, .learning)
        XCTAssertEqual(again.due.timeIntervalSince(now), 60, accuracy: 1)
        let easy = f.review(c, rating: .easy, now: now)
        XCTAssertEqual(easy.phase, .review)
        XCTAssertGreaterThanOrEqual(easy.due.timeIntervalSince(now), 10 * day)
    }

    func testGraduationAndGrowth() {
        let f = FSRS()
        var c = f.review(.fresh(now: now), rating: .good, now: now)
        var t = c.due
        c = f.review(c, rating: .good, now: t)
        XCTAssertEqual(c.phase, .review)
        var last = c.due.timeIntervalSince(t)
        XCTAssertGreaterThanOrEqual(last, day)
        for _ in 0..<4 {
            t = c.due
            c = f.answer(c, rating: .good, now: t)
            let next = c.due.timeIntervalSince(t)
            XCTAssertGreaterThan(next, last)
            last = next
        }
    }

    func testLapse() {
        let f = FSRS()
        var c = f.review(.fresh(now: now), rating: .easy, now: now)
        let s = c.stability
        c = f.review(c, rating: .again, now: c.due)
        XCTAssertEqual(c.phase, .relearning)
        XCTAssertEqual(c.lapses, 1)
        XCTAssertLessThan(c.stability, s)
    }

    func testPreviewOrdering() {
        let f = FSRS()
        var c = f.review(.fresh(now: now), rating: .easy, now: now)
        c = f.answer(c, rating: .good, now: c.due)
        let p = f.preview(c, now: c.due)
        XCTAssertLessThan(p[.again]!, p[.hard]!)
        XCTAssertLessThan(p[.hard]!, p[.good]!)
        XCTAssertLessThan(p[.good]!, p[.easy]!)
        XCTAssertEqual(f.answer(c, rating: .good, now: c.due).due, p[.good]!)
    }

    func testRetrievability() {
        XCTAssertEqual(FSRS.retrievability(days: 0, stability: 5), 1, accuracy: 1e-9)
        XCTAssertEqual(FSRS.retrievability(days: 5, stability: 5), 0.9, accuracy: 1e-3)
    }

    func testIntervalFormat() {
        XCTAssertEqual(IntervalFormat.short(from: now, to: now.addingTimeInterval(600)), "10 min")
        XCTAssertEqual(IntervalFormat.short(from: now, to: now.addingTimeInterval(3 * day)), "3 d")
        XCTAssertEqual(IntervalFormat.short(from: now, to: now.addingTimeInterval(61 * day)), "2 mo")
    }
}

final class TransferTests: XCTestCase {
    func testCSVRoundTrip() {
        let cards = [
            CardRecord(russian: "кни\u{301}га", french: "livre", notes: "f., \"важно\"", example: "Это книга, да.",
                       exampleTranslation: "C'est un livre, oui.", tags: ["a1", "story"]),
            CardRecord(russian: "читать", french: "lire\nréciter"),
        ]
        let back = CardCSV.import(CardCSV.export(cards))
        XCTAssertEqual(back.count, 2)
        XCTAssertEqual(back[0].russian, cards[0].russian)
        XCTAssertEqual(back[0].notes, cards[0].notes)
        XCTAssertEqual(back[0].tags, ["a1", "story"])
        XCTAssertEqual(back[1].french, "lire\nréciter")
    }

    func testHeaderlessTSVAnyColumnOrder() {
        let cards = CardCSV.import("maison\tдом\nchat\tкот\n")
        XCTAssertEqual(cards.map(\.russian), ["дом", "кот"])
        XCTAssertEqual(cards.map(\.french), ["maison", "chat"])
    }

    func testFrenchHeaderSemicolon() {
        let cards = CardCSV.import("Russe;Français\nвода;eau\n")
        XCTAssertEqual(cards, [CardRecord(russian: "вода", french: "eau", createdAt: cards[0].createdAt)])
    }

    func testBackupRoundTrip() throws {
        let s = Schedule(phase: .review, due: Date(timeIntervalSince1970: 1_700_000_000), stability: 4, difficulty: 5, reps: 3)
        let b = Backup(exportedAt: Date(timeIntervalSince1970: 1_700_000_000),
                       cards: [CardRecord(russian: "да", french: "oui", createdAt: Date(timeIntervalSince1970: 1_600_000_000), schedules: ["ru-fr": s])])
        let back = try Backup.decode(b.encoded())
        XCTAssertEqual(back.cards, b.cards)
    }

    func testDedupeKey() {
        XCTAssertEqual(CardRecord(russian: "Ёлка ", french: "Sapin").dedupeKey, CardRecord(russian: "елка", french: "sapin").dedupeKey)
    }
}

final class GrammarTests: XCTestCase {
    func testDescribe() {
        XCTAssertEqual(Grammar.describe("genitive singular"), "singular genitive")
        XCTAssertEqual(Grammar.describe("first-person present singular"), "1st person singular present")
        XCTAssertEqual(Grammar.describe("lemma"), "dictionary form")
    }

    func testStreak() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let today = Date(timeIntervalSince1970: 1_700_000_000)
        func c(_ offset: Int) -> DateComponents {
            cal.dateComponents([.year, .month, .day], from: cal.date(byAdding: .day, value: offset, to: today)!)
        }
        XCTAssertEqual(Streak.days(activeDays: [c(0), c(-1), c(-2), c(-4)], today: today, calendar: cal), 3)
        XCTAssertEqual(Streak.days(activeDays: [c(-1), c(-2)], today: today, calendar: cal), 2)
        XCTAssertEqual(Streak.days(activeDays: [c(-2)], today: today, calendar: cal), 0)
    }
}

final class StoryDataTests: XCTestCase {
    /// The bundled stories decode with the app's types and are well formed.
    func testBundledStories() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Pandouchka/Stories/stories.json")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("stories.json not reachable from the package (run from the repository)")
        }
        let stories = try JSONDecoder().decode(StoryCollection.self, from: Data(contentsOf: url)).stories
        XCTAssertGreaterThanOrEqual(stories.count, 16)
        XCTAssertEqual(Set(stories.map(\.id)).count, stories.count)
        for s in stories {
            XCTAssertFalse(s.lines.isEmpty, s.id)
            XCTAssertTrue(s.lines.allSatisfy { RussianText.containsCyrillic($0.ru) && !$0.fr.isEmpty }, s.id)
            for q in s.questions {
                XCTAssertTrue(q.options.indices.contains(q.answer), "\(s.id): \(q.ru)")
            }
        }
    }
}
