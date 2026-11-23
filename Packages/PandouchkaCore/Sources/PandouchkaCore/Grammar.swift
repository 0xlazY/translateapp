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

/// Short example phrases showing a noun form in each case, with the preposition
/// variants Russian requires (о / об, к / ко, с / со).
public enum CaseExamples {
    public struct Example: Equatable, Sendable {
        public let russian: String
        public let french: String
    }

    /// The question a Russian schoolchild asks to find the case.
    public static func question(_ c: String) -> String {
        switch c {
        case "nominative": return "кто? что?"
        case "genitive": return "кого? чего?"
        case "dative": return "кому? чему?"
        case "accusative": return "кого? что?"
        case "instrumental": return "кем? чем?"
        case "prepositional": return "о ком? о чём?"
        default: return ""
        }
    }

    static let consonants: Set<Character> = Set("бвгджзйклмнпрстфхцчшщ")

    static func plain(_ w: String) -> [Character] { Array(RussianText.stripStress(w).lowercased()) }

    /// о before consonants, об before а о у э и.
    static func o(_ w: String) -> String {
        guard let f = plain(w).first else { return "о" }
        return "аоуэи".contains(f) ? "об" : "о"
    }

    /// ко before мн-, вс-, вт-, and a few short nouns; к otherwise.
    static func k(_ w: String) -> String {
        let p = plain(w)
        guard p.count >= 2 else { return "к" }
        let word = String(p)
        // Fleeting-vowel nouns: ко дню, ко сну, ко рту, ко льду, ко дну.
        if ["дню", "дням", "сну", "рту", "льду", "дну", "мне"].contains(word) { return "ко" }
        if ["мн", "вс", "вт"].contains(where: { word.hasPrefix($0) }) { return "ко" }
        return "к"
    }

    /// со before с/з/ш/ж followed by a consonant, and before мн-; с otherwise.
    static func s(_ w: String) -> String {
        let p = plain(w)
        guard p.count >= 2 else { return "с" }
        if "сзшж".contains(p[0]) && consonants.contains(p[1]) { return "со" }
        if String(p).hasPrefix("мн") { return "со" }
        return "с"
    }

    /// Example for one case and number; `form` is the (stress-marked) inflected noun.
    public static func noun(_ c: String, plural: Bool, form: String) -> Example? {
        guard !form.isEmpty, form != "—" else { return nil }
        switch c {
        case "nominative":
            return Example(russian: "Это \(form).", french: plural ? "Ce sont des …" : "C'est …")
        case "genitive":
            return plural ? Example(russian: "много \(form)", french: "beaucoup de …")
                : Example(russian: "без \(form)", french: "sans …")
        case "dative":
            return Example(russian: "\(k(form)) \(form)", french: "vers …")
        case "accusative":
            return Example(russian: "Я ви́жу \(form).", french: "Je vois …")
        case "instrumental":
            return Example(russian: "\(s(form)) \(form)", french: "avec …")
        case "prepositional":
            return Example(russian: "\(o(form)) \(form)", french: "à propos de …")
        default:
            return nil
        }
    }
}
