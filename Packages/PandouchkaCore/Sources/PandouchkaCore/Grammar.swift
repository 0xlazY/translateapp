import Foundation

/// Readable labels for Wiktionary grammatical tags.
public enum Grammar {
    static let order: [String] = [
        "lemma", "infinitive", "first-person", "second-person", "third-person", "masculine", "feminine", "neuter",
        "singular", "plural", "present", "past", "future", "imperative", "active", "passive", "adverbial",
        "participle", "short-form", "comparative", "superlative", "nominative", "genitive", "dative", "accusative",
        "instrumental", "prepositional", "locative", "partitive", "vocative", "animate", "inanimate",
        "after-preposition",
    ]
    static let labels: [String: String] = [
        "lemma": "dictionary form", "first-person": "1st person", "second-person": "2nd person",
        "third-person": "3rd person", "short-form": "short form", "adverbial": "adverbial",
        "after-preposition": "after a preposition", "nominative": "nominative", "genitive": "genitive",
        "dative": "dative", "accusative": "accusative", "instrumental": "instrumental",
        "prepositional": "prepositional", "locative": "locative", "partitive": "partitive",
    ]
    static let hidden: Set<String> = ["personal", "pronoun", "form", "form-of", "indicative", "perfective", "imperfective"]

    /// "genitive singular" -> "singular genitive" in a stable, readable order.
    public static func describe(_ tags: String) -> String {
        let parts = tags.split(separator: " ").map(String.init).filter { !hidden.contains($0) }
        guard !parts.isEmpty else { return "" }
        let sorted = parts.sorted { (order.firstIndex(of: $0) ?? 999) < (order.firstIndex(of: $1) ?? 999) }
        var seen = Set<String>()
        return sorted.filter { seen.insert($0).inserted }.map { labels[$0] ?? $0 }.joined(separator: " ")
    }

    public static func partOfSpeech(_ pos: String) -> String {
        switch pos {
        case "noun": return "noun"
        case "verb": return "verb"
        case "adj": return "adjective"
        case "adv": return "adverb"
        case "pron": return "pronoun"
        case "prep": return "preposition"
        case "conj": return "conjunction"
        case "intj": return "interjection"
        case "num": return "numeral"
        case "particle": return "particle"
        case "phrase": return "phrase"
        case "name": return "proper noun"
        case "det": return "determiner"
        default: return pos
        }
    }

    /// Grid of case forms for a noun/adjective table, rows = cases.
    public static let cases = ["nominative", "genitive", "dative", "accusative", "instrumental", "prepositional"]
}

/// Consecutive days with at least one review, ending today or yesterday.
public enum Streak {
    public static func days(activeDays: Set<DateComponents>, today: Date, calendar: Calendar = .current) -> Int {
        func comps(_ d: Date) -> DateComponents { calendar.dateComponents([.year, .month, .day], from: d) }
        var day = today
        if !activeDays.contains(comps(day)) {
            guard let y = calendar.date(byAdding: .day, value: -1, to: day), activeDays.contains(comps(y)) else { return 0 }
            day = y
        }
        var count = 0
        while activeDays.contains(comps(day)) {
            count += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return count
    }
}
