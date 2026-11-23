import SwiftData
import SwiftUI
import PandouchkaCore

/// Opened from a tapped word: shows what it is in this sentence, then the dictionary entry.
struct WordSheet: View {
    let selection: WordSelection
    @State private var matches: [DictMatch] = []
    @State private var chosen = 0
    @State private var fallback: String?
    @State private var loading = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
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
                .padding(18)
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
            HStack(spacing: 8) {
                ForEach(Array(matches.prefix(6).enumerated()), id: \.offset) { i, m in
                    Button { withAnimation(.snappy) { chosen = i } } label: {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(m.entry.word).font(Fonts.reading(16))
                            Text(Grammar.partOfSpeech(m.entry.pos)).font(Fonts.ui(.caption2))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .foregroundStyle(chosen == i ? Color.white : Palette.ink)
                        .background(chosen == i ? Palette.ink : Palette.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func formLine(_ m: DictMatch) -> some View {
        if RussianText.key(m.entry.word) != RussianText.key(selection.word) || !m.readings.filter({ $0 != "dictionary form" }).isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(RussianDictionary.shared.stressed(selection.word)).font(Fonts.reading(20)).foregroundStyle(Palette.ink)
                    Image(systemName: "arrow.right").font(.caption).foregroundStyle(Palette.muted)
                    Text(m.entry.word).font(Fonts.reading(20)).foregroundStyle(Palette.blue)
                }
                let readings = m.readings.filter { $0 != "dictionary form" }
                if !readings.isEmpty {
                    Text(readings.prefix(4).joined(separator: " · ")).font(Fonts.ui(.footnote)).foregroundStyle(Palette.muted)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.blue.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var notFound: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(selection.word).font(Fonts.display(34)).foregroundStyle(Palette.ink)
            Text("Not in the offline dictionary.").font(Fonts.ui(.subheadline)).foregroundStyle(Palette.muted)
            if let fallback {
                Text(fallback).font(Fonts.ui(.title3)).foregroundStyle(Palette.ink)
                Text("Machine translation (Apple, on device)").font(Fonts.ui(.caption)).foregroundStyle(Palette.muted)
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
            WordDetailContent(entry: entry, context: nil).padding(18)
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

    private var isKnown: Bool { known.contains { $0.key == entry.key } }

    private var glosses: [String] { entry.french.map(DictEntry.clean) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headword
            if !glosses.isEmpty { frenchSection }
            if !entry.english.isEmpty { englishSection }
            if !entry.pairs.isEmpty { pairsSection }
            if !entry.examples.isEmpty { examplesSection }
            if let ctx = context, !ctx.sentence.isEmpty { contextSection(ctx) }
            actions
            if !RussianDictionary.shared.forms(of: entry.id).isEmpty {
                Button { showForms = true } label: {
                    Label(entry.pos == "verb" ? "Conjugation" : "Declension", systemImage: "tablecells")
                }
                .buttonStyle(SoftButtonStyle(color: Palette.ink))
            }
            Text("Wiktionary · CC BY-SA 4.0").font(Fonts.ui(.caption2)).foregroundStyle(Palette.muted.opacity(0.7))
        }
        .sheet(isPresented: $showForms) {
            NavigationStack { FormsTable(entry: entry) }
        }
        .onAppear {
            if chosenGlosses.isEmpty { chosenGlosses = Set(0..<min(2, glosses.count)) }
        }
    }

    private var headword: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.word).font(Fonts.display(38)).foregroundStyle(Palette.ink)
                    .textSelection(.enabled)
                HStack(spacing: 6) {
                    Text(entry.grammarLine).font(Fonts.ui(.subheadline)).foregroundStyle(Palette.muted)
                    if let ipa = entry.ipa { Text("[\(ipa)]").font(Fonts.ui(.caption)).foregroundStyle(Palette.muted) }
                }
            }
            Spacer()
            VStack(spacing: 8) {
                Button { Speech.shared.say(entry.word) } label: {
                    Image(systemName: "speaker.wave.2.fill").frame(width: 44, height: 44)
                        .background(Palette.blue.opacity(0.12), in: Circle())
                }
                if let url = entry.audio {
                    Button { Speech.shared.play(url: url) } label: {
                        Image(systemName: "person.wave.2.fill").frame(width: 44, height: 44)
                            .background(Palette.red.opacity(0.12), in: Circle())
                    }
                    .tint(Palette.red)
                    .accessibilityLabel("Native recording")
                }
            }
        }
    }

    private var frenchSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(context == nil ? "Meaning" : "Meaning · tap to choose for the card")
            ForEach(Array(glosses.enumerated()), id: \.offset) { i, g in
                Button {
                    if chosenGlosses.contains(i) { chosenGlosses.remove(i) } else { chosenGlosses.insert(i) }
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(i + 1)").font(Fonts.ui(.caption, weight: .bold))
                            .frame(width: 22, height: 22)
                            .background(chosenGlosses.contains(i) ? Palette.blue : Palette.sunken, in: Circle())
                            .foregroundStyle(chosenGlosses.contains(i) ? Color.white : Palette.muted)
                        Text(g).font(Fonts.ui(.body)).foregroundStyle(Palette.ink).multilineTextAlignment(.leading)
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
                    sectionTitle(glosses.isEmpty ? "Meaning (English)" : "In English")
                    Image(systemName: showEnglish || glosses.isEmpty ? "chevron.up" : "chevron.down").font(.caption2).foregroundStyle(Palette.muted)
                }
            }
            .buttonStyle(.plain)
            if showEnglish || glosses.isEmpty {
                ForEach(entry.english, id: \.self) { g in
                    Text("• " + g).font(Fonts.ui(.subheadline)).foregroundStyle(Palette.ink.opacity(0.85))
                }
            }
        }
    }

    private var pairsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle(entry.aspect == "perfective" ? "Imperfective partner" : "Perfective partner")
            HStack {
                ForEach(entry.pairs, id: \.self) { p in
                    if let e = RussianDictionary.shared.entry(word: p) {
                        NavigationLink(value: e) {
                            Text(p).font(Fonts.reading(18))
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(Palette.surface, in: Capsule())
                        }
                    } else {
                        Text(p).font(Fonts.reading(18))
                    }
                }
            }
        }
    }

    private var examplesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Examples")
            ForEach(entry.examples, id: \.self) { ex in
                VStack(alignment: .leading, spacing: 2) {
                    Text(ex.first ?? "").font(Fonts.reading(17)).foregroundStyle(Palette.ink)
                        .onTapGesture { Speech.shared.say(ex.first ?? "") }
                    if ex.count > 1 { Text(ex[1]).font(Fonts.ui(.footnote)).italic().foregroundStyle(Palette.muted) }
                }
            }
        }
    }

    private func contextSection(_ ctx: WordSelection) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionTitle("In the text")
            Text(ctx.sentence).font(Fonts.reading(17)).foregroundStyle(Palette.ink)
            if !ctx.translation.isEmpty {
                Text(ctx.translation).font(Fonts.ui(.footnote)).italic().foregroundStyle(Palette.muted)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.sunken.opacity(0.6), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                Label(isKnown ? "Marked as known" : "I already know this", systemImage: isKnown ? "checkmark.circle.fill" : "checkmark.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SoftButtonStyle(color: isKnown ? Palette.green : Palette.muted))
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

    private func sectionTitle(_ s: String) -> some View {
        Text(s).font(Fonts.ui(.caption, weight: .semibold)).foregroundStyle(Palette.muted).textCase(.uppercase)
    }
}

/// "Add to cards", or "In your cards" when the word is already there.
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
                Label("In your cards", systemImage: "rectangle.stack.badge.checkmark")
                    .font(Fonts.ui(.headline))
                    .foregroundStyle(Palette.green)
                Spacer()
                Button("Edit") { editing = card }
                    .buttonStyle(SoftButtonStyle(color: Palette.green))
            }
            .padding(12)
            .background(Palette.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .sheet(item: $editing) { CardEditor(card: $0) }
        } else {
            Button {
                let c = CardStore.add(record, in: context)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                _ = c
            } label: {
                Label("Add to cards", systemImage: "plus.rectangle.on.rectangle")
            }
            .buttonStyle(PrimaryButtonStyle(color: Palette.red))
            .disabled(record.french.isEmpty && record.russian.isEmpty)
        }
    }
}

/// Declension or conjugation grid.
struct FormsTable: View {
    let entry: DictEntry
    @Environment(\.dismiss) private var dismiss
    private var forms: [DictForm] { RussianDictionary.shared.forms(of: entry.id) }

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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(entry.word).font(Fonts.display(30)).foregroundStyle(Palette.ink)
                switch entry.pos {
                case "verb": verbTables
                case "adj", "pron", "det", "num": adjectiveTable
                default: nounTable
                }
            }
            .padding(18)
        }
        .background(Palette.paper.ignoresSafeArea())
        .navigationTitle(entry.pos == "verb" ? "Conjugation" : "Declension")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
    }

    private func grid(_ title: String?, columns: [String], rows: [(String, [String])]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title { Text(title).font(Fonts.ui(.caption, weight: .semibold)).foregroundStyle(Palette.muted).textCase(.uppercase) }
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("")
                    ForEach(columns, id: \.self) { Text($0).font(Fonts.ui(.caption2, weight: .semibold)).foregroundStyle(Palette.muted) }
                }
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    GridRow {
                        Text(row.0).font(Fonts.ui(.caption)).foregroundStyle(Palette.muted)
                        ForEach(Array(row.1.enumerated()), id: \.offset) { _, v in
                            Text(v).font(Fonts.reading(16)).foregroundStyle(Palette.ink)
                                .onTapGesture { if v != "—" { Speech.shared.say(v) } }
                        }
                    }
                }
            }
            .padding(14)
            .card(radius: 16)
        }
    }

    private static let caseLabels = ["nom.", "gen.", "dat.", "acc.", "instr.", "prep."]

    private var nounTable: some View {
        grid(nil, columns: ["singular", "plural"], rows: zip(Self.caseLabels, Grammar.cases).map { label, c in
            (label, [cell([c, "singular"]), cell([c, "plural"])])
        })
    }

    private var adjectiveTable: some View {
        VStack(alignment: .leading, spacing: 18) {
            grid(nil, columns: ["masc.", "neut.", "fem.", "plural"], rows: zip(Self.caseLabels, Grammar.cases).map { label, c in
                (label, [cell([c, "masculine"], excluding: ["plural"]), cell([c, "neuter"], excluding: ["plural"]),
                         cell([c, "feminine"], excluding: ["plural"]), cell([c, "plural"])])
            })
            let short = cell(["short-form"])
            if short != "—" { labelled("Short forms", short) }
            let comp = cell(["comparative"])
            if comp != "—" { labelled("Comparative", comp) }
        }
    }

    private var verbTables: some View {
        let tense = entry.aspect == "perfective" ? "future" : "present"
        let persons = [("я", ["first-person", "singular"]), ("ты", ["second-person", "singular"]),
                       ("он/она", ["third-person", "singular"]), ("мы", ["first-person", "plural"]),
                       ("вы", ["second-person", "plural"]), ("они", ["third-person", "plural"])]
        return VStack(alignment: .leading, spacing: 18) {
            grid(tense == "future" ? "Future" : "Present", columns: [""], rows: persons.map { p, tags in
                (p, [cell([tense] + tags, excluding: ["participle"])])
            })
            grid("Past", columns: [""], rows: [
                ("он", [cell(["past", "masculine"], excluding: ["participle"])]),
                ("она", [cell(["past", "feminine"], excluding: ["participle"])]),
                ("оно", [cell(["past", "neuter"], excluding: ["participle"])]),
                ("они", [cell(["past", "plural"], excluding: ["participle"])]),
            ])
            grid("Imperative", columns: [""], rows: [
                ("ты", [cell(["imperative", "singular"])]),
                ("вы", [cell(["imperative", "plural"])]),
            ])
            let participles = forms.filter { $0.tags.contains("participle") }
            if !participles.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Participles").font(Fonts.ui(.caption, weight: .semibold)).foregroundStyle(Palette.muted).textCase(.uppercase)
                    ForEach(participles, id: \.self) { f in
                        HStack {
                            Text(f.word).font(Fonts.reading(16))
                            Spacer()
                            Text(Grammar.describe(f.tags)).font(Fonts.ui(.caption)).foregroundStyle(Palette.muted)
                        }
                    }
                }
                .padding(14)
                .card(radius: 16)
            }
        }
    }

    private func labelled(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(Fonts.ui(.caption, weight: .semibold)).foregroundStyle(Palette.muted).textCase(.uppercase)
            Text(value).font(Fonts.reading(17)).foregroundStyle(Palette.ink)
        }
    }
}
