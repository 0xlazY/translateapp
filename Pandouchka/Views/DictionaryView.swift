import SwiftData
import SwiftUI
import PandouchkaCore

struct DictionaryView: View {
    @State private var query = ""
    @State private var russian: [DictEntry] = []
    @State private var french: [DictEntry] = []
    @State private var transliterated: String?
    @State private var machine: String?
    @State private var translating = false
    @State private var path: [DictEntry] = []

    private var trimmed: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isPhrase: Bool { trimmed.split(separator: " ").count > 2 }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if trimmed.isEmpty {
                    intro
                } else {
                    if let t = transliterated, !russian.isEmpty {
                        Section("Russian, from “\(trimmed)” → \(t)") { rows(russian) }
                    } else if !russian.isEmpty {
                        Section("Russian") { rows(russian) }
                    }
                    if !french.isEmpty {
                        Section("French → Russian") { rows(french) }
                    }
                    Section("Apple translation (on device)") { machineRow }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.paper.ignoresSafeArea())
            .navigationTitle("Dictionary")
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "слово, mot, or slovo")
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .onChange(of: query) { search() }
            .navigationDestination(for: DictEntry.self) { WordDetailView(entry: $0) }
        }
    }

    private func rows(_ entries: [DictEntry]) -> some View {
        ForEach(entries.prefix(30)) { e in
            NavigationLink(value: e) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(e.word).font(Fonts.reading(20)).foregroundStyle(Palette.ink)
                        Text(Grammar.partOfSpeech(e.pos)).font(Fonts.ui(.caption)).foregroundStyle(Palette.muted)
                    }
                    Text(e.shortFrench).font(Fonts.ui(.subheadline)).foregroundStyle(Palette.muted).lineLimit(2)
                }
            }
        }
    }

    @ViewBuilder
    private var machineRow: some View {
        if let machine {
            VStack(alignment: .leading, spacing: 6) {
                Text(machine).font(RussianText.containsCyrillic(machine) ? Fonts.reading(20) : Fonts.ui(.body))
                    .textSelection(.enabled)
                HStack {
                    if RussianText.containsCyrillic(machine) {
                        Button { Speech.shared.say(machine) } label: { Label("Listen", systemImage: "speaker.wave.2") }
                    }
                    Spacer()
                    let ru = RussianText.containsCyrillic(trimmed) ? trimmed : machine
                    let fr = RussianText.containsCyrillic(trimmed) ? machine : trimmed
                    AddPhraseButton(russian: ru, french: fr)
                }
                .buttonStyle(.borderless)
                .font(Fonts.ui(.subheadline))
            }
        } else {
            Button {
                Task { await translate() }
            } label: {
                HStack {
                    Label(RussianText.containsCyrillic(trimmed) ? "Translate to French" : "Translate to Russian", systemImage: "translate")
                    if translating { Spacer(); ProgressView() }
                }
            }
        }
    }

    private var intro: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Text("Type in Russian or French.").font(Fonts.ui(.headline))
                Text("No Russian keyboard? Type it in Latin letters: “privet” finds привет, “khorosho” finds хорошо.")
                    .font(Fonts.ui(.subheadline)).foregroundStyle(Palette.muted)
                Text("Whole sentences are translated on your device by Apple. The first time, iOS asks to download the Russian and French languages.")
                    .font(Fonts.ui(.footnote)).foregroundStyle(Palette.muted)
            }
            .padding(.vertical, 6)
        }
    }

    private func search() {
        machine = nil
        let q = trimmed
        guard !q.isEmpty else {
            russian = []; french = []; transliterated = nil
            return
        }
        let dict = RussianDictionary.shared
        if RussianText.containsCyrillic(q) {
            transliterated = nil
            russian = isPhrase ? [] : dict.searchRussian(q)
            french = []
        } else {
            french = isPhrase ? [] : dict.searchFrench(q)
            if Transliteration.isLatinOnly(q), !isPhrase {
                let cyr = Transliteration.toCyrillic(q)
                transliterated = cyr
                russian = dict.searchRussian(cyr, limit: 10)
            } else {
                transliterated = nil
                russian = []
            }
        }
    }

    private func translate() async {
        let q = trimmed
        translating = true
        defer { translating = false }
        let ru = RussianText.containsCyrillic(q)
        machine = try? await Translator.shared.translate(q, from: ru ? .russian : .french, to: ru ? .french : .russian)
        if machine == nil { machine = "Translation unavailable. Check that iOS can download the languages (Settings › Apps › Translate)." }
    }
}

struct AddPhraseButton: View {
    let russian: String
    let french: String
    @Environment(\.modelContext) private var context
    @State private var added = false

    var body: some View {
        Button {
            CardStore.add(CardRecord(russian: russian, french: french, tags: ["phrase"]), in: context)
            added = true
        } label: {
            Label(added ? "Added" : "Add to cards", systemImage: added ? "checkmark" : "plus")
        }
        .disabled(added)
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @AppStorage(Prefs.directions) private var directions = "both"
    @AppStorage(Prefs.newPerDay) private var newPerDay = 10
    @AppStorage(Prefs.retention) private var retention = 0.9
    @AppStorage(Prefs.autoPlay) private var autoPlay = true
    @AppStorage(Prefs.showStress) private var showStress = true
    @AppStorage(Prefs.speechRate) private var speechRate = 0.42
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Directions", selection: $directions) {
                        Text("Russian → French").tag("ru-fr")
                        Text("French → Russian").tag("fr-ru")
                        Text("Both").tag("both")
                    }
                    Stepper("New words per day: \(newPerDay)", value: $newPerDay, in: 0...60, step: 5)
                    VStack(alignment: .leading) {
                        Text("Target memory: \(Int(retention * 100))%")
                        Slider(value: $retention, in: 0.8...0.95, step: 0.01)
                        Text("Higher means more frequent reviews.").font(.caption).foregroundStyle(Palette.muted)
                    }
                } header: {
                    Text("Flashcards")
                } footer: {
                    Text("Scheduling uses FSRS, an open-source spaced-repetition model.")
                }
                Section("Reading & audio") {
                    Toggle("Stress marks (уда́рение)", isOn: $showStress)
                    Toggle("Speak cards automatically", isOn: $autoPlay)
                    VStack(alignment: .leading) {
                        Text("Speech speed")
                        Slider(value: $speechRate, in: 0.25...0.6)
                    }
                    Button("Test voice") { Speech.shared.say("Привет! Как дела?") }
                    Text("For a better voice, download “Milena (Enhanced)” in iOS Settings › Accessibility › Spoken Content › Voices › Russian.")
                        .font(.footnote).foregroundStyle(Palette.muted)
                }
                Section("Data") {
                    Button("Reset all review progress", role: .destructive) { confirmReset = true }
                }
                Section("About") {
                    LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Dictionary: Wiktionary (French and English editions), CC BY-SA 4.0, via kaikki.org / wiktextract.")
                        Text("Word frequencies: FrequencyWords by Hermit Dave, MIT.")
                        Text("Spaced repetition: FSRS-5 by Open Spaced Repetition.")
                        Text("Sentence translation: Apple Translation, on device.")
                    }
                    .font(.footnote)
                    .foregroundStyle(Palette.muted)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .confirmationDialog("Reset progress on every card? Your cards stay.", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Reset", role: .destructive) {
                    for s in (try? context.fetch(FetchDescriptor<CardSchedule>())) ?? [] { s.value = .fresh() }
                    try? context.save()
                }
            }
        }
    }
}
