import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import PandouchkaCore

struct CardsView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var router: AppRouter
    @Query(sort: \Card.createdAt, order: .reverse) private var cards: [Card]
    @AppStorage(Prefs.directions) private var directions = "both"
    @AppStorage(Prefs.newPerDay) private var newPerDay = 10

    @State private var search = ""
    @State private var editing: Card?
    @State private var creating = false
    @State private var importing = false
    @State private var exportDoc: ExportDocument?
    @State private var exportName = "pandouchka-cards"
    @State private var exporting = false
    @State private var message: String?
    @State private var due = 0
    @State private var filter: Filter = .all

    enum Filter: String, CaseIterable, Identifiable {
        case all = "All", new = "New", learning = "Learning", solid = "Solid"
        var id: String { rawValue }
    }

    private func bucket(_ c: Card) -> Filter {
        guard let s = c.schedule(.ruFr) ?? c.schedules.first else { return .new }
        switch s.phase {
        case .new: return .new
        case .learning, .relearning: return .learning
        case .review: return s.stability >= 21 ? .solid : .learning
        }
    }

    private var filtered: [Card] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        let qKey = RussianText.key(q)
        return cards.filter { c in
            (filter == .all || bucket(c) == filter) &&
                (q.isEmpty || c.key.contains(qKey) || c.french.lowercased().contains(q) || c.tagsRaw.lowercased().contains(q))
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    stats
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                Section {
                    Picker("Filter", selection: $filter) {
                        ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
                Section {
                    if cards.isEmpty {
                        emptyState
                    }
                    ForEach(filtered) { card in
                        Button { editing = card } label: { CardRow(card: card) }
                            .buttonStyle(.plain)
                            .swipeActions {
                                Button(role: .destructive) { CardStore.delete(card, in: context) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.paper.ignoresSafeArea())
            .navigationTitle("Cards")
            .searchable(text: $search, prompt: "Search Russian, French or tag")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { creating = true } label: { Image(systemName: "plus") }
                }
                ToolbarItem(placement: .topBarLeading) { transferMenu }
            }
            .sheet(item: $editing) { CardEditor(card: $0) }
            .sheet(isPresented: $creating) { CardEditor(card: nil) }
            .fileImporter(isPresented: $importing,
                          allowedContentTypes: [.commaSeparatedText, .tabSeparatedText, .plainText, .json, .text],
                          allowsMultipleSelection: false) { result in
                handleImport(result)
            }
            .fileExporter(isPresented: $exporting, document: exportDoc, contentType: exportDoc?.contentType ?? .commaSeparatedText,
                          defaultFilename: exportName) { result in
                if case .failure(let e) = result { message = e.localizedDescription }
            }
            .alert("Cards", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(message ?? "")
            }
            .onAppear(perform: refresh)
            .onChange(of: cards.count) { refresh() }
            .onChange(of: router.reviewing) { refresh() }
        }
    }

    private func refresh() {
        due = CardStore.dueCount(in: context, directions: Prefs.enabledDirections(directions), newLimit: newPerDay)
    }

    private var stats: some View {
        let counts = Dictionary(grouping: cards, by: { bucket($0) }).mapValues(\.count)
        return VStack(spacing: 14) {
            HStack(spacing: 10) {
                statTile("\(cards.count)", "words", Palette.ink)
                statTile("\(counts[.new] ?? 0)", "new", Palette.red)
                statTile("\(counts[.learning] ?? 0)", "learning", Palette.amber)
                statTile("\(counts[.solid] ?? 0)", "solid", Palette.blue)
            }
            Button { router.reviewing = true } label: {
                Label(due > 0 ? "Review \(due) now" : "Nothing due", systemImage: "play.fill")
            }
            .buttonStyle(PrimaryButtonStyle(color: due > 0 ? Palette.blue : Palette.muted))
            .disabled(due == 0)
        }
        .padding(.vertical, 6)
    }

    private func statTile(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(Fonts.display(24)).foregroundStyle(color)
            Text(label).font(Fonts.ui(.caption2)).foregroundStyle(Palette.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .card(radius: 16)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "rectangle.stack.badge.plus").font(.largeTitle).foregroundStyle(Palette.muted)
            Text("No cards yet").font(Fonts.ui(.headline))
            Text("Tap any word in a story or the dictionary, then “Add to cards”. You can also import a CSV list.")
                .font(Fonts.ui(.footnote)).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var transferMenu: some View {
        Menu {
            Section("Import") {
                Button { importing = true } label: { Label("Import CSV / backup…", systemImage: "square.and.arrow.down") }
            }
            Section("Export") {
                Button { export(csv: true) } label: { Label("Export CSV (spreadsheet, Anki)", systemImage: "tablecells") }
                Button { export(csv: false) } label: { Label("Export full backup (JSON)", systemImage: "externaldrive") }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down.circle")
        }
    }

    private func export(csv: Bool) {
        let records = cards.map(\.record)
        let stamp = Date().formatted(.iso8601.year().month().day())
        if csv {
            exportDoc = ExportDocument(data: Data(CardCSV.export(records).utf8), contentType: .commaSeparatedText)
            exportName = "pandouchka-cards-\(stamp)"
        } else {
            guard let data = try? Backup(cards: records).encoded() else { return }
            exportDoc = ExportDocument(data: data, contentType: .json)
            exportName = "pandouchka-backup-\(stamp)"
        }
        exporting = true
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let e):
            message = e.localizedDescription
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let r = try CardStore.importFile(url, in: context)
                message = "Imported \(r.added) card\(r.added == 1 ? "" : "s")" + (r.skipped > 0 ? ", skipped \(r.skipped) already in your deck." : ".")
            } catch {
                message = "Could not import: \(error.localizedDescription)"
            }
        }
        refresh()
    }
}

struct CardRow: View {
    let card: Card
    var body: some View {
        HStack(spacing: 12) {
            MemoryBar(value: card.retrievability).frame(width: 4, height: 40)
            VStack(alignment: .leading, spacing: 3) {
                Text(card.russian).font(Fonts.reading(19)).foregroundStyle(Palette.ink)
                Text(card.french).font(Fonts.ui(.subheadline)).foregroundStyle(Palette.muted).lineLimit(1)
            }
            Spacer()
            if let s = card.schedule(.ruFr), s.phase != .new {
                Text(s.due <= Date() ? "due" : IntervalFormat.short(from: Date(), to: s.due))
                    .font(Fonts.ui(.caption))
                    .foregroundStyle(s.due <= Date() ? Palette.red : Palette.muted)
            } else {
                Chip(text: "new", color: Palette.red)
            }
        }
        .contentShape(Rectangle())
    }
}

struct MemoryBar: View {
    var value: Double?
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .bottom) {
                Capsule().fill(Palette.sunken)
                if let v = value {
                    Capsule().fill(Palette.memory(v)).frame(height: g.size.height * v)
                }
            }
        }
    }
}

struct CardEditor: View {
    let card: Card?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var russian = ""
    @State private var french = ""
    @State private var notes = ""
    @State private var example = ""
    @State private var exampleTranslation = ""
    @State private var tags = ""
    @State private var suggestions: [DictEntry] = []
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Russian") {
                    TextField("слово", text: $russian)
                        .font(Fonts.reading(20))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: russian) { suggest() }
                    if card == nil, !suggestions.isEmpty {
                        ForEach(suggestions.prefix(4)) { e in
                            Button {
                                russian = e.word
                                if french.isEmpty { french = e.shortFrench }
                                if notes.isEmpty { notes = e.grammarLine }
                                suggestions = []
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(e.word).font(Fonts.reading(17)).foregroundStyle(Palette.ink)
                                    Text(e.shortFrench).font(Fonts.ui(.caption)).foregroundStyle(Palette.muted).lineLimit(1)
                                }
                            }
                        }
                    }
                    if Transliteration.isLatinOnly(russian) && !russian.isEmpty {
                        Button("Use “\(Transliteration.toCyrillic(russian))”") { russian = Transliteration.toCyrillic(russian) }
                    }
                }
                Section("French") {
                    TextField("mot", text: $french, axis: .vertical)
                }
                Section("Example (optional)") {
                    TextField("Пример", text: $example, axis: .vertical).font(Fonts.reading(17))
                    TextField("Exemple", text: $exampleTranslation, axis: .vertical)
                }
                Section("Notes & tags") {
                    TextField("Notes", text: $notes, axis: .vertical)
                    TextField("Tags, separated by spaces", text: $tags)
                        .textInputAutocapitalization(.never)
                }
                if let card {
                    Section("Progress") {
                        ForEach(Direction.allCases) { d in
                            if let s = card.schedule(d) {
                                LabeledContent(d.label) {
                                    Text(s.phase == .new ? "new" : "\(s.reps) reviews · next \(s.due.formatted(date: .abbreviated, time: .omitted))")
                                }
                            }
                        }
                        Button("Reset progress") {
                            for s in card.schedules { s.value = .fresh() }
                            try? context.save()
                        }
                    }
                    Section {
                        Button("Delete card", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .navigationTitle(card == nil ? "New card" : "Edit card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(russian.trimmingCharacters(in: .whitespaces).isEmpty || french.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .confirmationDialog("Delete this card?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let card { CardStore.delete(card, in: context) }
                    dismiss()
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let card else { return }
        russian = card.russian
        french = card.french
        notes = card.notes
        example = card.example
        exampleTranslation = card.exampleTranslation
        tags = card.tagsRaw
    }

    private func suggest() {
        guard card == nil else { return }
        let q = russian.trimmingCharacters(in: .whitespaces)
        guard q.count >= 2, RussianText.containsCyrillic(q) else { suggestions = []; return }
        suggestions = RussianDictionary.shared.searchRussian(q, limit: 6)
    }

    private func save() {
        let ru = russian.trimmingCharacters(in: .whitespacesAndNewlines)
        let fr = french.trimmingCharacters(in: .whitespacesAndNewlines)
        let tagList = tags.split(separator: " ").map(String.init)
        if let card {
            card.russian = ru
            card.key = Card.key(for: ru)
            card.french = fr
            card.notes = notes
            card.example = example
            card.exampleTranslation = exampleTranslation
            card.tagsRaw = tagList.joined(separator: " ")
            try? context.save()
        } else {
            CardStore.add(CardRecord(russian: ru, french: fr, notes: notes, example: example,
                                     exampleTranslation: exampleTranslation, tags: tagList), in: context)
        }
        dismiss()
    }
}
