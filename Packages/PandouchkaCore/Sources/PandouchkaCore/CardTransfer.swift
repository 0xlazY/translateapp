import Foundation

/// A flashcard as it travels in and out of the app.
public struct CardRecord: Codable, Equatable, Sendable {
    public var russian: String
    public var french: String
    public var notes: String
    public var example: String
    public var exampleTranslation: String
    public var tags: [String]
    public var createdAt: Date
    /// Scheduling, keyed by direction ("ru-fr", "fr-ru"). Only in JSON backups.
    public var schedules: [String: Schedule]?

    public init(russian: String, french: String, notes: String = "", example: String = "",
                exampleTranslation: String = "", tags: [String] = [], createdAt: Date = Date(),
                schedules: [String: Schedule]? = nil) {
        self.russian = russian
        self.french = french
        self.notes = notes
        self.example = example
        self.exampleTranslation = exampleTranslation
        self.tags = tags
        self.createdAt = createdAt
        self.schedules = schedules
    }

    /// Identity used to skip duplicates on import.
    public var dedupeKey: String {
        RussianText.key(russian.trimmingCharacters(in: .whitespacesAndNewlines)) + "|" +
            french.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

/// Full backup: cards with their scheduling.
public struct Backup: Codable, Sendable {
    public var format: String = "pandouchka-backup"
    public var version: Int = 1
    public var exportedAt: Date
    public var cards: [CardRecord]

    public init(exportedAt: Date = Date(), cards: [CardRecord]) {
        self.exportedAt = exportedAt
        self.cards = cards
    }

    public func encoded() throws -> Data {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        e.dateEncodingStrategy = .iso8601
        return try e.encode(self)
    }

    public static func decode(_ data: Data) throws -> Backup {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return try d.decode(Backup.self, from: data)
    }
}

public enum CSV {
    /// Parses CSV/TSV (RFC 4180 quoting). The delimiter is guessed from the first line.
    public static func parse(_ text: String, delimiter: Character? = nil) -> [[String]] {
        var body = text
        if body.hasPrefix("\u{FEFF}") { body.removeFirst() }
        let d = delimiter ?? guessDelimiter(body)
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var quoted = false
        var chars = Array(body)
        chars.append("\n")
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if quoted {
                if c == "\"" {
                    if i + 1 < chars.count, chars[i + 1] == "\"" { field.append("\""); i += 1 } else { quoted = false }
                } else {
                    field.append(c)
                }
            } else if c == "\"" && field.isEmpty {
                quoted = true
            } else if c == d {
                row.append(field); field = ""
            } else if c == "\n" || c == "\r\n" || c == "\r" {
                row.append(field); field = ""
                if !(row.count == 1 && row[0].isEmpty) { rows.append(row) }
                row = []
            } else {
                field.append(c)
            }
            i += 1
        }
        return rows
    }

    static func guessDelimiter(_ text: String) -> Character {
        let first = text.split(whereSeparator: { $0 == "\n" || $0 == "\r\n" }).first.map(String.init) ?? ""
        let candidates: [Character] = ["\t", ";", ","]
        return candidates.max { a, b in first.filter { $0 == a }.count < first.filter { $0 == b }.count } ?? ","
    }

    public static func escape(_ s: String) -> String {
        if s.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) {
            return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return s
    }

    public static func write(_ rows: [[String]]) -> String {
        rows.map { $0.map(escape).joined(separator: ",") }.joined(separator: "\r\n") + "\r\n"
    }
}

/// Spreadsheet-friendly card lists, importable into Anki as well.
public enum CardCSV {
    public static let header = ["russian", "french", "notes", "example", "example_translation", "tags"]

    public static func export(_ cards: [CardRecord]) -> String {
        CSV.write([header] + cards.map {
            [$0.russian, $0.french, $0.notes, $0.example, $0.exampleTranslation, $0.tags.joined(separator: " ")]
        })
    }

    static let aliases: [String: String] = [
        "russian": "russian", "russe": "russian", "ru": "russian", "front": "russian", "word": "russian", "русский": "russian",
        "french": "french", "français": "french", "francais": "french", "fr": "french", "back": "french",
        "translation": "french", "traduction": "french",
        "notes": "notes", "note": "notes",
        "example": "example", "exemple": "example", "context": "example", "sentence": "example",
        "example_translation": "exampleTranslation", "example translation": "exampleTranslation",
        "traduction exemple": "exampleTranslation",
        "tags": "tags", "tag": "tags", "deck": "tags",
    ]

    /// Reads cards from CSV/TSV. With a recognised header, columns are matched by name;
    /// otherwise the column containing Cyrillic is Russian and the next one French.
    public static func `import`(_ text: String) -> [CardRecord] {
        var rows = CSV.parse(text)
        guard let first = rows.first else { return [] }
        var columns: [String: Int] = [:]
        for (i, name) in first.enumerated() {
            if let field = aliases[name.trimmingCharacters(in: .whitespaces).lowercased()], columns[field] == nil {
                columns[field] = i
            }
        }
        if columns["russian"] != nil, columns["french"] != nil {
            rows.removeFirst()
        } else {
            let ruCol = first.firstIndex(where: RussianText.containsCyrillic) ?? 0
            columns = ["russian": ruCol, "french": ruCol == 0 ? 1 : 0]
        }
        func value(_ row: [String], _ field: String) -> String {
            guard let i = columns[field], i < row.count else { return "" }
            return row[i].trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return rows.compactMap { row in
            let ru = value(row, "russian"), fr = value(row, "french")
            guard !ru.isEmpty, !fr.isEmpty else { return nil }
            let tags = value(row, "tags").split(whereSeparator: { $0 == " " || $0 == "," }).map(String.init)
            return CardRecord(russian: ru, french: fr, notes: value(row, "notes"), example: value(row, "example"),
                              exampleTranslation: value(row, "exampleTranslation"), tags: tags)
        }
    }
}
