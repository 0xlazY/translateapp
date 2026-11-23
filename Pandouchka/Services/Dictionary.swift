import Foundation
import SQLite3
import PandouchkaCore

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

struct DictEntry: Identifiable, Hashable {
    let id: Int
    /// Stress-marked dictionary form.
    let word: String
    let key: String
    let pos: String
    let rank: Int
    let french: [String]
    let english: [String]
    let examples: [[String]]
    let gender: String?
    let animacy: String?
    let aspect: String?
    let pairs: [String]
    let ipa: String?
    let audio: URL?

    var hasFrench: Bool { !french.isEmpty }

    /// Short French meaning for a card or a list row.
    var shortFrench: String {
        let g = french.prefix(2).map(DictEntry.clean)
        return g.isEmpty ? (english.first ?? "") : g.joined(separator: " ; ")
    }

    var grammarLine: String {
        var parts = [Grammar.partOfSpeech(pos)]
        if let gender { parts.append(gender) }
        if let aspect { parts.append(aspect) }
        if pos == "noun", let animacy { parts.append(animacy) }
        return parts.joined(separator: " · ")
    }

    static func clean(_ gloss: String) -> String {
        var g = gloss.trimmingCharacters(in: .whitespaces)
        while g.hasSuffix(".") { g.removeLast() }
        guard let first = g.first else { return g }
        // Lowercase a leading capital unless the next letter is too (acronyms).
        let rest = g.dropFirst()
        if first.isUppercase, !(rest.first?.isUppercase ?? false) {
            return first.lowercased() + rest
        }
        return g
    }
}

/// A dictionary entry that a spelling belongs to, with the grammatical reading(s).
struct DictMatch: Identifiable, Hashable {
    let entry: DictEntry
    /// The spelling as an inflected form, stress marked.
    let form: String
    let readings: [String]
    var id: Int { entry.id }
}

struct DictForm: Hashable {
    let word: String
    let tags: String
}

/// Read-only Russian dictionary built from Wiktionary (see tools/build_dictionary.py).
final class RussianDictionary: @unchecked Sendable {
    static let shared = RussianDictionary()

    private var db: OpaquePointer?
    private let lock = NSLock()
    private var tagsets: [Int: String] = [:]
    private var stressCache: [String: String] = [:]
    private var lookupCache: [String: [DictMatch]] = [:]

    private init() {
        guard let url = Bundle.main.url(forResource: "dictionary", withExtension: "sqlite") else { return }
        if sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil) != SQLITE_OK {
            db = nil
            return
        }
        query("SELECT id, tags FROM tagset", []) { s in
            self.tagsets[Int(sqlite3_column_int(s, 0))] = self.text(s, 1) ?? ""
        }
    }

    var isAvailable: Bool { db != nil }

    // MARK: SQLite helpers

    private func text(_ s: OpaquePointer?, _ i: Int32) -> String? {
        guard let c = sqlite3_column_text(s, i) else { return nil }
        return String(cString: c)
    }

    private func json<T: Decodable>(_ s: OpaquePointer?, _ i: Int32, as: T.Type) -> T? {
        guard let t = text(s, i), let d = t.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(T.self, from: d)
    }

    private func query(_ sql: String, _ args: [Any], row: (OpaquePointer?) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        guard let db else { return }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        for (i, a) in args.enumerated() {
            let idx = Int32(i + 1)
            if let s = a as? String {
                sqlite3_bind_text(stmt, idx, s, -1, SQLITE_TRANSIENT)
            } else if let n = a as? Int {
                sqlite3_bind_int64(stmt, idx, Int64(n))
            }
        }
        while sqlite3_step(stmt) == SQLITE_ROW { row(stmt) }
    }

    private static let entryColumns = "e.id, e.word, e.key, e.pos, e.rank, e.fr, e.en, e.examples, e.gender, e.animacy, e.aspect, e.pairs, e.ipa, e.audio"

    private func entry(_ s: OpaquePointer?) -> DictEntry {
        DictEntry(
            id: Int(sqlite3_column_int(s, 0)), word: text(s, 1) ?? "", key: text(s, 2) ?? "", pos: text(s, 3) ?? "",
            rank: Int(sqlite3_column_int(s, 4)), french: json(s, 5, as: [String].self) ?? [],
            english: json(s, 6, as: [String].self) ?? [], examples: json(s, 7, as: [[String]].self) ?? [],
            gender: text(s, 8), animacy: text(s, 9), aspect: text(s, 10), pairs: json(s, 11, as: [String].self) ?? [],
            ipa: text(s, 12), audio: text(s, 13).flatMap(URL.init(string:)))
    }

    /// Rebuilds the stress-marked spelling stored as (stress index, spelling).
    private func formWord(key: String, stress: Int, word: String?) -> String {
        RussianText.applyStress(word ?? key, index: stress)
    }

    // MARK: Lookups

    /// All entries a spelling can belong to, most common first.
    func lookup(_ token: String) -> [DictMatch] {
        let k = RussianText.key(token)
        guard !k.isEmpty else { return [] }
        lock.lock()
        if let cached = lookupCache[k] { lock.unlock(); return cached }
        lock.unlock()

        var order: [Int] = []
        var entries: [Int: DictEntry] = [:]
        var forms: [Int: String] = [:]
        var readings: [Int: [String]] = [:]
        let sql = """
            SELECT \(Self.entryColumns), f.stress, f.word, f.tagset
            FROM form f JOIN entry e ON e.id = f.entry
            WHERE f.key = ? ORDER BY e.rank, e.id, f.ord LIMIT 60
            """
        query(sql, [k]) { s in
            let e = self.entry(s)
            if entries[e.id] == nil {
                entries[e.id] = e
                order.append(e.id)
                forms[e.id] = self.formWord(key: k, stress: Int(sqlite3_column_int(s, 14)), word: self.text(s, 15))
            }
            let tags = self.tagsets[Int(sqlite3_column_int(s, 16))] ?? ""
            let reading = Grammar.describe(tags)
            if !reading.isEmpty, !(readings[e.id] ?? []).contains(reading) {
                readings[e.id, default: []].append(reading)
            }
        }
        // A capitalised word mid-text is more likely a name; plain words otherwise rank first.
        var result = order.map { DictMatch(entry: entries[$0]!, form: forms[$0]!, readings: readings[$0] ?? []) }
        let capitalised = token.first?.isUppercase ?? false
        result.sort { a, b in
            if capitalised && a.entry.pos == "name" && b.entry.pos != "name" { return true }
            if capitalised && b.entry.pos == "name" && a.entry.pos != "name" { return false }
            if a.entry.hasFrench != b.entry.hasFrench { return a.entry.hasFrench }
            return a.entry.rank < b.entry.rank
        }
        lock.lock()
        lookupCache[k] = result
        lock.unlock()
        return result
    }

    /// The spelling with its stress marked, when the most likely entry agrees on it.
    func stressed(_ token: String) -> String {
        let k = RussianText.key(token)
        lock.lock()
        if let c = stressCache[k] { lock.unlock(); return apply(c, to: token) }
        lock.unlock()
        var marks = Set<Int>()
        var spelled: String?
        if let best = lookup(token).first {
            query("SELECT stress, word FROM form WHERE key = ? AND entry = ?", [k, best.entry.id]) { s in
                let st = Int(sqlite3_column_int(s, 0))
                if st >= 0 { marks.insert(st) }
                if spelled == nil { spelled = self.text(s, 1) }
            }
        }
        let base = RussianText.restoreYo(k, from: spelled ?? k)
        let result = marks.count == 1 ? RussianText.applyStress(base, index: marks.first!) : base
        lock.lock()
        stressCache[k] = result
        lock.unlock()
        return apply(result, to: token)
    }

    /// Copies the capitalisation of `token` onto a stress-marked lowercase spelling.
    private func apply(_ lower: String, to token: String) -> String {
        if token.unicodeScalars.contains("\u{301}") { return token }
        let marked = Array(lower)
        let original = Array(RussianText.stripStress(token))
        guard marked.count == original.count else { return token }
        return String(zip(marked, original).map { m, o in
            o.isUppercase ? Character(String(m).uppercased()) : m
        })
    }

    func entry(id: Int) -> DictEntry? {
        var out: DictEntry?
        query("SELECT \(Self.entryColumns) FROM entry e WHERE e.id = ?", [id]) { out = self.entry($0) }
        return out
    }

    /// Exact spelling of a dictionary form, e.g. an aspect partner.
    func entry(word: String) -> DictEntry? {
        lookup(word).first { $0.entry.key == RussianText.key(word) }?.entry ?? lookup(word).first?.entry
    }

    func forms(of entryID: Int) -> [DictForm] {
        var out: [DictForm] = []
        query("SELECT key, stress, word, tagset FROM form WHERE entry = ? AND ord > 0 AND ord < 900 ORDER BY ord", [entryID]) { s in
            let k = self.text(s, 0) ?? ""
            out.append(DictForm(word: self.formWord(key: k, stress: Int(sqlite3_column_int(s, 1)), word: self.text(s, 2)),
                                tags: self.tagsets[Int(sqlite3_column_int(s, 3))] ?? ""))
        }
        return out
    }

    /// Russian words starting with the query.
    func searchRussian(_ text: String, limit: Int = 40) -> [DictEntry] {
        let k = RussianText.key(text.trimmingCharacters(in: .whitespaces))
        guard !k.isEmpty else { return [] }
        var out: [DictEntry] = []
        var seen = Set<Int>()
        for m in lookup(k) where seen.insert(m.entry.id).inserted { out.append(m.entry) }
        query("SELECT \(Self.entryColumns) FROM entry e WHERE e.key >= ? AND e.key < ? ORDER BY e.rank LIMIT ?",
              [k, k + "\u{FFFF}", limit]) { s in
            let e = self.entry(s)
            if seen.insert(e.id).inserted { out.append(e) }
        }
        return out
    }

    /// Russian entries whose French meaning matches a French word.
    func searchFrench(_ text: String, limit: Int = 40) -> [DictEntry] {
        let words = text.lowercased().folding(options: .diacriticInsensitive, locale: Locale(identifier: "fr"))
            .split(whereSeparator: { !$0.isLetter && $0 != "'" && $0 != "-" }).map(String.init)
        guard let term = words.max(by: { $0.count < $1.count }), term.count > 1 else { return [] }
        var out: [DictEntry] = []
        var seen = Set<Int>()
        let sql = """
            SELECT \(Self.entryColumns) FROM fr_index i JOIN entry e ON e.id = i.entry
            WHERE i.term = ? ORDER BY i.primary_hit DESC, e.rank LIMIT ?
            """
        query(sql, [term, limit]) { s in
            let e = self.entry(s)
            if seen.insert(e.id).inserted { out.append(e) }
        }
        if out.count < 10 {
            query("""
                SELECT \(Self.entryColumns) FROM fr_index i JOIN entry e ON e.id = i.entry
                WHERE i.term > ? AND i.term < ? AND i.primary_hit = 1 ORDER BY e.rank LIMIT 20
                """, [term, term + "\u{FFFF}"]) { s in
                let e = self.entry(s)
                if seen.insert(e.id).inserted { out.append(e) }
            }
        }
        return out
    }

    /// A common word with a French meaning, the same for everyone on a given day.
    func wordOfTheDay(_ date: Date = Date()) -> DictEntry? {
        let day = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        var candidates: [Int] = []
        query("SELECT id FROM entry WHERE rank BETWEEN 150 AND 4000 AND fr IS NOT NULL AND pos IN ('noun','verb','adj','adv') ORDER BY id", []) {
            candidates.append(Int(sqlite3_column_int($0, 0)))
        }
        guard !candidates.isEmpty else { return nil }
        // Spread consecutive days across the list.
        let index = (day &* 2_654_435_761) % candidates.count
        return entry(id: candidates[abs(index)])
    }
}
