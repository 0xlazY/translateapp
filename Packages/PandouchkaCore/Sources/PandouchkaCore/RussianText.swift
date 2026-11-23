import Foundation

/// Spelling rules for looking Russian words up and displaying them.
public enum RussianText {
    public static let acute: Character = "\u{0301}"
    static let vowels: Set<Character> = ["а", "е", "ё", "и", "о", "у", "ы", "э", "ю", "я"]

    /// Dictionary lookup key: lowercase, no stress marks, ё folded to е.
    /// Must match `key()` in tools/build_dictionary.py.
    public static func key(_ word: String) -> String {
        var out = ""
        for scalar in word.lowercased().unicodeScalars {
            switch scalar {
            case "\u{0301}", "\u{0300}": continue
            case "ё": out.unicodeScalars.append("е")
            default: out.unicodeScalars.append(scalar)
            }
        }
        return out
    }

    /// Removes stress marks but keeps ё.
    public static func stripStress(_ word: String) -> String {
        String(String.UnicodeScalarView(word.unicodeScalars.filter { $0 != "\u{0301}" && $0 != "\u{0300}" }))
    }

    public static func isCyrillic(_ scalar: Unicode.Scalar) -> Bool {
        (0x0400...0x04FF).contains(scalar.value)
    }

    /// True when the text contains at least one Cyrillic letter.
    public static func containsCyrillic(_ text: String) -> Bool {
        text.unicodeScalars.contains(where: isCyrillic)
    }

    public static func vowelCount(_ word: String) -> Int {
        stripStress(word).lowercased().filter { vowels.contains($0) }.count
    }

    /// Marks the stressed vowel of `word`. `index` counts letters of the unaccented spelling.
    /// Words with one vowel or with ё need no mark and are returned unchanged.
    public static func applyStress(_ word: String, index: Int) -> String {
        let plain = stripStress(word)
        if index < 0 || vowelCount(plain) < 2 || plain.lowercased().contains("ё") {
            return plain
        }
        var chars = Array(plain)
        guard index < chars.count, vowels.contains(Character(chars[index].lowercased())) else { return plain }
        chars[index] = Character(String(chars[index]) + "\u{0301}")
        return String(chars)
    }

    /// Restores ё from a dictionary spelling when the text wrote е ("все" stays as-is,
    /// "елка" + "ёлка" -> "ёлка"). Keeps the capitalisation of `word`.
    public static func restoreYo(_ word: String, from dictionary: String) -> String {
        let plain = Array(stripStress(word))
        let dict = Array(stripStress(dictionary).lowercased())
        guard plain.count == dict.count else { return String(plain) }
        var out = plain
        for i in plain.indices where dict[i] == "ё" && plain[i].lowercased() == "е" {
            out[i] = plain[i].isUppercase ? "Ё" : "ё"
        }
        return String(out)
    }
}

/// A piece of a sentence: a word or the text between words.
public struct Token: Equatable, Hashable, Sendable {
    public let text: String
    public let isWord: Bool
    /// Position in UTF-16 code units, which is what speech synthesis reports.
    public let utf16Offset: Int
    public let utf16Length: Int

    public init(text: String, isWord: Bool, utf16Offset: Int, utf16Length: Int) {
        self.text = text
        self.isWord = isWord
        self.utf16Offset = utf16Offset
        self.utf16Length = utf16Length
    }
}

public enum Tokenizer {
    static func isWordChar(_ c: Character) -> Bool {
        c.isLetter || c.unicodeScalars.allSatisfy { $0 == "\u{0301}" || $0 == "\u{0300}" }
    }

    /// Splits text into words and separators. Hyphenated words ("что-то", "по-русски")
    /// stay whole; a hyphen with spaces around it is a separator.
    public static func tokenize(_ text: String) -> [Token] {
        let chars = Array(text)
        var tokens: [Token] = []
        var i = 0
        var offset = 0
        while i < chars.count {
            let start = i
            let word = isWordChar(chars[i])
            if word {
                while i < chars.count {
                    if isWordChar(chars[i]) {
                        i += 1
                    } else if chars[i] == "-", i + 1 < chars.count, isWordChar(chars[i + 1]), i > start {
                        i += 1
                    } else {
                        break
                    }
                }
            } else {
                while i < chars.count, !isWordChar(chars[i]) { i += 1 }
            }
            let piece = String(chars[start..<i])
            let length = piece.utf16.count
            tokens.append(Token(text: piece, isWord: word, utf16Offset: offset, utf16Length: length))
            offset += length
        }
        return tokens
    }

    /// Index of the token covering a UTF-16 offset, preferring words.
    public static func tokenIndex(in tokens: [Token], utf16Offset: Int) -> Int? {
        tokens.firstIndex { $0.isWord && utf16Offset >= $0.utf16Offset && utf16Offset < $0.utf16Offset + $0.utf16Length }
    }
}

/// Latin to Cyrillic for typing Russian without a Russian keyboard ("privet" -> "привет").
/// Follows common informal transliteration.
public enum Transliteration {
    static let multi: [(String, String)] = [
        ("shch", "щ"), ("sch", "щ"), ("zh", "ж"), ("kh", "х"), ("ts", "ц"), ("ch", "ч"), ("sh", "ш"),
        ("yu", "ю"), ("ju", "ю"), ("ya", "я"), ("ja", "я"), ("yo", "ё"), ("jo", "ё"), ("ye", "е"), ("e'", "э"),
        ("''", "ъ"), ("y'", "ы"),
    ]
    static let single: [Character: String] = [
        "a": "а", "b": "б", "v": "в", "g": "г", "d": "д", "e": "е", "z": "з", "i": "и", "j": "й",
        "k": "к", "l": "л", "m": "м", "n": "н", "o": "о", "p": "п", "r": "р", "s": "с", "t": "т",
        "u": "у", "f": "ф", "h": "х", "c": "ц", "y": "ы", "w": "в", "x": "кс", "q": "к", "'": "ь",
    ]

    public static func toCyrillic(_ latin: String) -> String {
        let lower = Array(latin.lowercased())
        var out = ""
        var i = 0
        outer: while i < lower.count {
            for (pattern, cyr) in multi {
                let p = Array(pattern)
                if i + p.count <= lower.count, Array(lower[i..<(i + p.count)]) == p {
                    // "y" before a vowel at a word start or after a vowel is й ("moy" handled below).
                    out += cyr
                    i += p.count
                    continue outer
                }
            }
            let c = lower[i]
            if c == "y" {
                // "y" after a vowel ("moy", "dobryy") or at the end after a vowel is й.
                let prevVowel = i > 0 && "aeiouy".contains(lower[i - 1])
                out += prevVowel ? "й" : "ы"
            } else if let cyr = single[c] {
                out += cyr
            } else {
                out.append(c)
            }
            i += 1
        }
        return out
    }

    /// True when text looks like transliterated Russian rather than French: Latin only.
    public static func isLatinOnly(_ text: String) -> Bool {
        !text.isEmpty && text.unicodeScalars.allSatisfy { $0.isASCII }
    }
}
