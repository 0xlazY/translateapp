import SwiftData
import SwiftUI
import PandouchkaCore

/// Plays the best pronunciation available: a native Wiktionary recording when online,
/// otherwise the system voice.
@MainActor
enum Pronounce {
    static func word(_ entry: DictEntry) {
        if let url = entry.audio { Speech.shared.play(url: url) } else { Speech.shared.say(entry.word, slow: true) }
    }
}

/// Opened from a tapped word: what it is in this sentence, then the dictionary entry.
struct WordSheet: View {
    let selection: WordSelection
    @State private var matches: [DictMatch] = []
    @State private var chosen = 0
    @State private var fallback: String?
    @State private var loading = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if loading {
                        ProgressView().frame(maxWidth: .infinity).padding(40)
                    } else if matches.isEmpty {
                        notFound
                    } else {
                        if matches.count > 1 { candidatePicker }
                        let m = matches[min(chosen, matches.count - 1)]
                        formLine(m)
                        WordDetailContent(entry: m.entry, context: selection)
                            .id(m.entry.id)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 18)
            }
            .background(Palette.paper.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: DictEntry.self) { WordDetailView(entry: $0) }
        }
        .task {
            matches = RussianDictionary.shared.lookup(selection.word)
            loading = false
            if matches.isEmpty {
                fallback = try? await Translator.shared.translate(selection.word, from: .russian, to: .french)
            }
        }
    }

    private var candidatePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 18) {
                ForEach(Array(matches.prefix(6).enumerated()), id: \.offset) { i, m in
                    Button { withAnimation(.snappy) { chosen = i } } label: {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(m.entry.word).font(Fonts.reading(17))
                            Text(Grammar.partOfSpeech(m.entry.pos)).font(Fonts.italic(12))
                        }
                        .foregroundStyle(chosen == i ? Palette.pen : Palette.muted)
                        .padding(.bottom, 4)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(chosen == i ? Palette.pen : .clear).frame(height: 1.5)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func formLine(_ m: DictMatch) -> some View {
        let readings = m.readings.filter { $0 != "dictionary form" }
        if RussianText.key(m.entry.word) != RussianText.key(selection.word) || !readings.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(RussianDictionary.shared.stressed(selection.word)).font(Fonts.reading(20)).foregroundStyle(Palette.ink)
                    Text("←").foregroundStyle(Palette.muted)
                    Text(m.entry.word).font(Fonts.reading(20)).foregroundStyle(Palette.pen)
                }
                if !readings.isEmpty {
                    Text(readings.prefix(4).joined(separator: " · ")).font(Fonts.italic(14)).foregroundStyle(Palette.muted)
                }
            }
            .padding(.leading, 12)
            .overlay(alignment: .leading) { Rectangle().fill(Palette.margin).frame(width: 2) }
        }
    }

    private var notFound: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(selection.word).font(Fonts.display(34)).foregroundStyle(Palette.ink)
            Text("Not in the offline dictionary.").font(Fonts.italic(15)).foregroundStyle(Palette.muted)
            if let fallback {
                Text(fallback).font(Fonts.reading(20)).foregroundStyle(Palette.pen)
                Eyebrow("Machine translation, on device")
            }
            AddCardButton(record: CardRecord(russian: selection.word, french: fallback ?? "", example: selection.sentence,
                                             exampleTranslation: selection.translation, tags: [selection.source]))
        }
    }
}

/// A dictionary entry as its own screen.
struct WordDetailView: View {
    let entry: DictEntry
    var body: some View {
        ScrollView {
            WordDetailContent(entry: entry, context: nil)
                .padding(.horizontal, 22)
                .padding(.vertical, 18)
        }
        .background(Palette.paper.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: DictEntry.self) { WordDetailView(entry: $0) }
    }
}

struct WordDetailContent: View {
    let entry: DictEntry
    let context: WordSelection?

    @Environment(\.modelContext) private var modelContext
    @Query private var known: [KnownWord]
    @State private var chosenGlosses: Set<Int> = []
    @State private var showEnglish = false
    @State private var showForms = false
    @State private var hasForms = false

    private var isKnown: Bool { known.contains { $0.key == entry.key } }
    private var glosses: [String] { entry.french.map(DictEntry.clean) }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            headword
            if !glosses.isEmpty { frenchSection }
            if !entry.english.isEmpty { englishSection }
            if !entry.pairs.isEmpty { pairsSection }
            if let ctx = context, !ctx.sentence.isEmpty { contextSection(ctx) }
            if !entry.examples.isEmpty { examplesSection }
            if hasForms {
                Button { showForms = true } label: {
                    HStack {
                        Text(entry.pos == "verb" ? "Conjugation" : "Declension")
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
                }
                .buttonStyle(OutlineButtonStyle(color: Palette.ink))
            }
            actions
            Text("Wiktionary · CC BY-SA 4.0").font(.system(size: 10)).foregroundStyle(Palette.muted.opacity(0.7))
        }
        .sheet(isPresented: $showForms) {
            NavigationStack { FormsTable(entry: entry) }
        }
        .onAppear {
            if chosenGlosses.isEmpty { chosenGlosses = Set(0..<min(2, glosses.count)) }
            hasForms = !RussianDictionary.shared.forms(of: entry.id).isEmpty
        }
    }

    private var headword: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.word).font(Fonts.display(40)).foregroundStyle(Palette.ink)
                    .textSelection(.enabled)
                HStack(spacing: 8) {
                    Text(entry.grammarLine).font(Fonts.italic(15)).foregroundStyle(Palette.muted)
                    if let ipa = entry.ipa { Text("[\(ipa)]").font(.system(size: 13)).foregroundStyle(Palette.muted) }
                }
            }
            Spacer()
            Button { Pronounce.word(entry) } label: {
                Image(systemName: "speaker.wave.2")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Palette.pen)
                    .frame(width: 46, height: 46)
                    .overlay(Circle().stroke(Palette.pen.opacity(0.5), lineWidth: 1))
            }
            .accessibilityLabel("Pronounce")
        }
    }

    private var frenchSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(context == nil ? "Meaning" : "Meaning · tick what goes on the card")
            ForEach(Array(glosses.enumerated()), id: \.offset) { i, g in
                Button {
                    if chosenGlosses.contains(i) { chosenGlosses.remove(i) } else { chosenGlosses.insert(i) }
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(chosenGlosses.contains(i) ? "☑" : "☐")
                            .font(.system(size: 17))
                            .foregroundStyle(chosenGlosses.contains(i) ? Palette.pen : Palette.muted)
                        Text(g).font(Fonts.reading(18)).foregroundStyle(Palette.ink).multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var englishSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button { withAnimation(.snappy) { showEnglish.toggle() } } label: {
                HStack {
                    Eyebrow(glosses.isEmpty ? "Meaning (English)" : "In English")
                    if !glosses.isEmpty {
                        Image(systemName: showEnglish ? "minus" : "plus").font(.caption2).foregroundStyle(Palette.muted)
                    }
                }
            }
            .buttonStyle(.plain)
            if showEnglish || glosses.isEmpty {
                ForEach(entry.english, id: \.self) { g in
                    Text("– " + g).font(Fonts.reading(16)).foregroundStyle(Palette.ink.opacity(0.85))
                }
            }
        }
    }

    private var pairsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(entry.aspect == "perfective" ? "Imperfective partner" : "Perfective partner")
            HStack(spacing: 16) {
                ForEach(entry.pairs, id: \.self) { p in
                    if let e = RussianDictionary.shared.entry(word: p) {
                        NavigationLink(value: e) {
                            Text(p).font(Fonts.reading(19)).foregroundStyle(Palette.pen).underline()
                        }
                    } else {
                        Text(p).font(Fonts.reading(19))
                    }
                }
            }
        }
    }

    private var examplesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow("Examples")
            ForEach(entry.examples, id: \.self) { ex in
                VStack(alignment: .leading, spacing: 2) {
                    Text(ex.first ?? "").font(Fonts.reading(17)).foregroundStyle(Palette.ink)
                    if ex.count > 1 { Text(ex[1]).font(Fonts.italic(15)).foregroundStyle(Palette.pen) }
                }
            }
        }
    }

    private func contextSection(_ ctx: WordSelection) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow("In the story")
            Text(ctx.sentence).font(Fonts.reading(18)).foregroundStyle(Palette.ink)
            if !ctx.translation.isEmpty {
                Text(ctx.translation).font(Fonts.italic(15)).foregroundStyle(Palette.pen)
            }
            if let line = ctx.line, StoryPlayer.shared.storyID == ctx.source, StoryPlayer.shared.isLoaded {
                Button {
                    StoryPlayer.shared.play(line: line)
                } label: {
                    Label("Play this sentence", systemImage: "play.fill")
                        .font(.system(.subheadline).weight(.semibold))
                }
                .foregroundStyle(Palette.pen)
                .padding(.top, 2)
            }
        }
        .padding(.leading, 12)
        .overlay(alignment: .leading) { Rectangle().fill(Palette.highlighter).frame(width: 3) }
    }

    private var cardRecord: CardRecord {
        let picked = chosenGlosses.sorted().compactMap { glosses.indices.contains($0) ? glosses[$0] : nil }
        let french = picked.isEmpty ? (glosses.first ?? entry.english.prefix(2).joined(separator: "; ")) : picked.joined(separator: " ; ")
        return CardRecord(russian: entry.word, french: french, notes: entry.grammarLine,
                          example: context?.sentence ?? entry.examples.first?.first ?? "",
                          exampleTranslation: context?.translation ?? (entry.examples.first.flatMap { $0.count > 1 ? $0[1] : nil } ?? ""),
                          tags: context.map { [$0.source] } ?? [])
    }

    private var actions: some View {
        VStack(spacing: 10) {
            AddCardButton(record: cardRecord)
            Button {
                toggleKnown()
            } label: {
                Text(isKnown ? "✓ Marked as known" : "I already know this word")
                    .font(Fonts.italic(16))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .foregroundStyle(isKnown ? Palette.pen : Palette.muted)
        }
    }

    private func toggleKnown() {
        if let k = known.first(where: { $0.key == entry.key }) {
            modelContext.delete(k)
        } else {
            modelContext.insert(KnownWord(key: entry.key))
        }
        try? modelContext.save()
    }
}

/// "Add to cards", or a note that the word is already there.
struct AddCardButton: View {
    let record: CardRecord
    @Environment(\.modelContext) private var context
    @Query private var cards: [Card]
    @State private var editing: Card?

    private var existing: Card? {
        let k = Card.key(for: record.russian)
        return cards.first { $0.key == k }
    }

    var body: some View {
        if let card = existing {
            HStack {
                Text("✓ In your cards").font(Fonts.italic(17)).foregroundStyle(Palette.pen)
                Spacer()
                Button("Edit") { editing = card }
                    .buttonStyle(OutlineButtonStyle())
            }
            .sheet(item: $editing) { CardEditor(card: $0) }
        } else {
            Button("Add to my cards") {
                CardStore.add(record, in: context)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            .buttonStyle(InkButtonStyle(color: Palette.margin))
            .disabled(record.french.isEmpty && record.russian.isEmpty)
        }
    }
}

/// Declension or conjugation, full width, with an example for every case.
struct FormsTable: View {
    let entry: DictEntry
    @Environment(\.dismiss) private var dismiss
    @State private var forms: [DictForm] = []

    private func cell(_ required: [String], excluding: [String] = []) -> String {
        var seen: [String] = []
        for f in forms {
            let tags = Set(f.tags.split(separator: " ").map(String.init))
            if required.allSatisfy(tags.contains), excluding.allSatisfy({ !tags.contains($0) }), !seen.contains(f.word) {
                seen.append(f.word)
            }
        }
        return seen.isEmpty ? "—" : seen.joined(separator: ", ")
    }

    /// First spelling only, for example phrases.
    private func first(_ s: String) -> String { s.components(separatedBy: ", ").first ?? s }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text(entry.word).font(Fonts.display(32)).foregroundStyle(Palette.ink)
                    Spacer()
                    Text(entry.grammarLine).font(Fonts.italic(14)).foregroundStyle(Palette.muted)
                }
                .padding(.bottom, 12)
                switch entry.pos {
                case "verb": verbTable
                case "adj", "pron", "det", "num": adjectiveTable
                default: nounTable
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(Palette.paper.ignoresSafeArea())
        .navigationTitle(entry.pos == "verb" ? "Conjugation" : "Declension")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        .onAppear { forms = RussianDictionary.shared.forms(of: entry.id) }
    }

    private static let caseNames = ["Nominative", "Genitive", "Dative", "Accusative", "Instrumental", "Prepositional"]

    private func speakable(_ text: String, font: Font, color: Color = Palette.ink) -> some View {
        Text(text).font(font).foregroundStyle(color)
            .onTapGesture { if text != "—" { Speech.shared.say(text, slow: true) } }
    }

    // Nouns: one block per case, singular and plural side by side, each with an example.
    private var nounTable: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer().frame(maxWidth: .infinity)
                Eyebrow("singular").frame(maxWidth: .infinity, alignment: .leading)
                Eyebrow("plural").frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.bottom, 6)
            Rule()
            ForEach(Array(Grammar.cases.enumerated()), id: \.offset) { i, c in
                let sg = cell([c, "singular"])
                let pl = cell([c, "plural"])
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(Self.caseNames[i]).font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.ink)
                            Text(CaseExamples.question(c)).font(Fonts.italic(13)).foregroundStyle(Palette.margin)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        speakable(sg, font: Fonts.reading(20)).frame(maxWidth: .infinity, alignment: .leading)
                        speakable(pl, font: Fonts.reading(20)).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    HStack(alignment: .top) {
                        Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
                        example(c, plural: false, form: first(sg)).frame(maxWidth: .infinity, alignment: .leading)
                        example(c, plural: true, form: first(pl)).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.vertical, 12)
                Rule()
            }
        }
    }

    @ViewBuilder
    private func example(_ c: String, plural: Bool, form: String) -> some View {
        if let ex = CaseExamples.noun(c, plural: plural, form: form) {
            VStack(alignment: .leading, spacing: 1) {
                speakable(ex.russian, font: Fonts.reading(15), color: Palette.ink.opacity(0.85))
                Text(ex.french).font(Fonts.italic(12)).foregroundStyle(Palette.pen)
            }
        } else {
            Color.clear.frame(height: 1)
        }
    }

    private var adjectiveTable: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer().frame(maxWidth: .infinity)
                ForEach(["masc.", "neut.", "fem.", "plural"], id: \.self) {
                    Eyebrow($0).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.bottom, 6)
            Rule()
            ForEach(Array(Grammar.cases.enumerated()), id: \.offset) { i, c in
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(Self.caseNames[i].prefix(4)) + ".").font(.system(size: 13, weight: .semibold))
                        Text(CaseExamples.question(c)).font(Fonts.italic(11)).foregroundStyle(Palette.margin)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    ForEach([["masculine"], ["neuter"], ["feminine"], ["plural"]], id: \.self) { g in
                        speakable(cell([c] + g, excluding: g == ["plural"] ? [] : ["plural"]), font: Fonts.reading(16))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.vertical, 10)
                Rule()
            }
            let short = cell(["short-form"])
            if short != "—" { labelled("Short forms", short) }
            let comp = cell(["comparative"])
            if comp != "—" { labelled("Comparative", comp) }
        }
    }

    private var verbTable: some View {
        let tense = entry.aspect == "perfective" ? "future" : "present"
        let persons = [("я", ["first-person", "singular"]), ("ты", ["second-person", "singular"]),
                       ("он, она́", ["third-person", "singular"]), ("мы", ["first-person", "plural"]),
                       ("вы", ["second-person", "plural"]), ("они́", ["third-person", "plural"])]
        let past = [("он", "masculine"), ("она́", "feminine"), ("оно́", "neuter"), ("они́", "plural")]
        return VStack(alignment: .leading, spacing: 0) {
            Eyebrow(tense == "future" ? "Future (perfective)" : "Present", color: Palette.margin).padding(.vertical, 8)
            Rule()
            ForEach(Array(persons.enumerated()), id: \.offset) { _, item in
                verbRow(item.0, cell([tense] + item.1, excluding: ["participle"]))
            }
            Eyebrow("Past", color: Palette.margin).padding(.top, 20).padding(.bottom, 8)
            Rule()
            ForEach(Array(past.enumerated()), id: \.offset) { _, item in
                verbRow(item.0, cell(["past", item.1], excluding: ["participle"]))
            }
            Eyebrow("Imperative", color: Palette.margin).padding(.top, 20).padding(.bottom, 8)
            Rule()
            verbRow("(ты)", cell(["imperative", "singular"]))
            verbRow("(вы)", cell(["imperative", "plural"]))
            let participles = forms.filter { $0.tags.contains("participle") }
            if !participles.isEmpty {
                Eyebrow("Participles", color: Palette.margin).padding(.top, 20).padding(.bottom, 8)
                Rule()
                ForEach(participles, id: \.self) { f in
                    HStack(alignment: .firstTextBaseline) {
                        speakable(f.word, font: Fonts.reading(18))
                        Spacer()
                        Text(Grammar.describe(f.tags)).font(Fonts.italic(13)).foregroundStyle(Palette.muted)
                    }
                    .padding(.vertical, 8)
                    Rule()
                }
            }
        }
    }

    /// "я чита́ю" on one line, the pronoun quiet and the form in ink.
    private func verbRow(_ pronoun: String, _ form: String) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(pronoun).font(Fonts.italic(17)).foregroundStyle(Palette.muted).frame(width: 80, alignment: .leading)
                Text(form).font(Fonts.reading(20)).foregroundStyle(Palette.ink)
                Spacer()
            }
            .padding(.vertical, 9)
            .contentShape(Rectangle())
            .onTapGesture { if form != "—" { Speech.shared.say("\(RussianText.stripStress(pronoun)) \(first(form))", slow: true) } }
            Rule()
        }
    }

    private func labelled(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Eyebrow(title, color: Palette.margin)
            speakable(value, font: Fonts.reading(18))
        }
        .padding(.top, 18)
    }
}
