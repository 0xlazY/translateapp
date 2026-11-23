import Foundation

public enum Level: String, Codable, CaseIterable, Sendable, Comparable {
    case a1 = "A1", a2 = "A2", b1 = "B1"

    public static func < (l: Level, r: Level) -> Bool {
        allCases.firstIndex(of: l)! < allCases.firstIndex(of: r)!
    }
}

/// A graded reading text with a French translation for every sentence.
public struct Story: Codable, Identifiable, Hashable, Sendable {
    public struct Line: Codable, Hashable, Sendable {
        public var ru: String
        public var fr: String
        /// Starts a new paragraph.
        public var paragraph: Bool?
        public init(ru: String, fr: String, paragraph: Bool? = nil) {
            self.ru = ru; self.fr = fr; self.paragraph = paragraph
        }
    }

    public struct Question: Codable, Hashable, Sendable {
        /// Asked in Russian, with a French gloss.
        public var ru: String
        public var fr: String
        public var options: [String]
        public var answer: Int
    }

    public struct Gloss: Codable, Hashable, Sendable {
        /// Key words introduced by the story, shown before reading.
        public var ru: String
        public var fr: String
    }

    public var id: String
    public var level: Level
    public var order: Int
    public var title: String
    public var titleFr: String
    public var emoji: String
    public var theme: String
    public var summary: String
    public var lines: [Line]
    public var keywords: [Gloss]
    public var questions: [Question]

    /// Distinct lookup keys of the words in the story.
    public var wordKeys: Set<String> {
        var keys = Set<String>()
        for line in lines {
            for t in Tokenizer.tokenize(line.ru) where t.isWord { keys.insert(RussianText.key(t.text)) }
        }
        return keys
    }

    public var wordCount: Int {
        lines.reduce(0) { $0 + Tokenizer.tokenize($1.ru).filter(\.isWord).count }
    }
}

public struct StoryCollection: Codable, Sendable {
    public var stories: [Story]
}
