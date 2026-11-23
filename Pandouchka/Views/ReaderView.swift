import SwiftData
import SwiftUI
import PandouchkaCore

/// A word tapped in a text, with the sentence around it.
struct WordSelection: Identifiable, Hashable {
    let word: String
    let sentence: String
    let translation: String
    let source: String
    var id: String { "\(source)|\(sentence)|\(word)" }
}

/// One wrapped unit in the reader: a word with the punctuation stuck to it.
struct Chunk: Hashable {
    var prefix: String = ""
    var word: Token?
    var suffix: String = ""
    var standalone: String?

    /// Splits a sentence so punctuation never starts a line.
    static func chunks(_ text: String) -> [Chunk] {
        var out: [Chunk] = []
        var pending = ""
        for t in Tokenizer.tokenize(text) {
            if t.isWord {
                out.append(Chunk(prefix: pending, word: t))
                pending = ""
                continue
            }
            let pieces = t.text.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
            if pieces.count == 1 {
                // No space: glue to the previous word, or to the next one at the start.
                if out.isEmpty { pending += pieces[0] } else { out[out.count - 1].suffix += pieces[0] }
                continue
            }
            if !pieces[0].isEmpty {
                if out.isEmpty { pending += pieces[0] } else { out[out.count - 1].suffix += pieces[0] }
            }
            for middle in pieces.dropFirst().dropLast() where !middle.isEmpty {
                out.append(Chunk(standalone: middle))
            }
            pending += pieces.last ?? ""
        }
        if !pending.isEmpty {
            if out.isEmpty { out.append(Chunk(standalone: pending)) } else { out[out.count - 1].suffix += pending }
        }
        return out
    }
}

struct ReaderView: View {
    let story: Story

    @Environment(\.modelContext) private var context
    @Query private var cards: [Card]
    @Query private var known: [KnownWord]
    @Query private var progressRows: [StoryProgress]
    @ObservedObject private var speech = Speech.shared
    @AppStorage(Prefs.showStress) private var showStress = true
    @AppStorage(Prefs.readerSize) private var fontSize = 22.0
    @AppStorage(Prefs.showLineTranslation) private var showAllTranslations = false

    @State private var selection: WordSelection?
    @State private var revealed: Set<Int> = []
    @State private var lemma: [String: String] = [:]
    @State private var showQuiz = false
    @State private var showKeywords = true

    private var progress: StoryProgress? { progressRows.first { $0.storyID == story.id } }
    private var cardsByKey: [String: Card] {
        var d: [String: Card] = [:]
        for c in cards where d[c.key] == nil { d[c.key] = c }
        return d
    }
    private var knownKeys: Set<String> { Set(known.map(\.key)) }

    private func lineID(_ i: Int) -> String { "\(story.id)-\(i)" }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    if !story.keywords.isEmpty { keywords }
                    let cardMap = cardsByKey
                    let knownSet = knownKeys
                    ForEach(Array(story.lines.enumerated()), id: \.offset) { i, line in
                        lineView(i, line, cardMap: cardMap, knownSet: knownSet)
                            .id(i)
                            .padding(.top, line.paragraph == true ? 22 : 8)
                    }
                    finishSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 120)
            }
            .onChange(of: speech.speakingID) { _, id in
                guard let id, id.hasPrefix(story.id + "-"), let i = Int(id.dropFirst(story.id.count + 1)) else { return }
                withAnimation(.easeInOut) { proxy.scrollTo(i, anchor: .center) }
            }
        }
        .background(Palette.paper.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .safeAreaInset(edge: .bottom) { controls }
        .sheet(item: $selection) { sel in
            WordSheet(selection: sel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showQuiz) {
            QuizView(story: story) { score in
                finish(score: score)
            }
            .presentationDetents([.large])
        }
        .task { prepare() }
        .onDisappear { speech.stop() }
    }

    private func prepare() {
        if progress == nil {
            context.insert(StoryProgress(storyID: story.id))
            try? context.save()
        }
        var map: [String: String] = [:]
        for key in story.wordKeys {
            map[key] = RussianDictionary.shared.lookup(key).first?.entry.key ?? key
        }
        lemma = map
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                StoryCover(story: story, size: 54)
                VStack(alignment: .leading, spacing: 4) {
                    Chip(text: story.level.rawValue, color: Palette.theme(story.theme))
                    Text("\(story.wordCount) words").font(Fonts.ui(.caption)).foregroundStyle(Palette.muted)
                }
            }
            Text(showStress ? stressedText(story.title) : story.title)
                .font(Fonts.display(32))
                .foregroundStyle(Palette.ink)
            Text(story.titleFr).font(Fonts.ui(.title3)).foregroundStyle(Palette.muted)
            Text(story.summary).font(Fonts.ui(.subheadline)).foregroundStyle(Palette.muted).padding(.top, 2)
        }
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    private func stressedText(_ s: String) -> String {
        Tokenizer.tokenize(s).map { $0.isWord ? RussianDictionary.shared.stressed($0.text) : $0.text }.joined()
    }

    private var keywords: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.snappy) { showKeywords.toggle() }
            } label: {
                HStack {
                    Text("Key words").font(Fonts.ui(.caption, weight: .semibold)).textCase(.uppercase)
                    Image(systemName: showKeywords ? "chevron.up" : "chevron.down").font(.caption2)
                }
                .foregroundStyle(Palette.muted)
            }
            .buttonStyle(.plain)
            if showKeywords {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(story.keywords, id: \.ru) { k in
                            Button {
                                selection = WordSelection(word: k.ru, sentence: "", translation: "", source: story.id)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(showStress ? stressedText(k.ru) : k.ru).font(Fonts.reading(17)).foregroundStyle(Palette.ink)
                                    Text(k.fr).font(Fonts.ui(.caption)).foregroundStyle(Palette.muted)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(.bottom, 10)
    }

    // MARK: Lines

    private func lineView(_ i: Int, _ line: Story.Line, cardMap: [String: Card], knownSet: Set<String>) -> some View {
        let speaking = speech.speakingID == lineID(i)
        let showFr = showAllTranslations || revealed.contains(i)
        return VStack(alignment: .leading, spacing: 6) {
            FlowLayout(spacing: 0, lineSpacing: fontSize * 0.35) {
                ForEach(Array(Chunk.chunks(line.ru).enumerated()), id: \.offset) { _, chunk in
                    chunkView(chunk, line: line, speaking: speaking, cardMap: cardMap, knownSet: knownSet)
                }
                lineButtons(i, line)
            }
            if showFr {
                Text(line.fr)
                    .font(Fonts.ui(.callout))
                    .italic()
                    .foregroundStyle(Palette.muted)
                    .padding(.leading, 10)
                    .overlay(alignment: .leading) { Tricolor(axis: .french).frame(width: 3) }
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(speaking ? Palette.amber.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, -8)
    }

    private func chunkView(_ chunk: Chunk, line: Story.Line, speaking: Bool, cardMap: [String: Card], knownSet: Set<String>) -> some View {
        HStack(spacing: 0) {
            if !chunk.prefix.isEmpty { plain(chunk.prefix) }
            if let w = chunk.word {
                wordView(w, line: line, speaking: speaking, cardMap: cardMap, knownSet: knownSet)
            }
            if let s = chunk.standalone { plain(s) }
            if !chunk.suffix.isEmpty { plain(chunk.suffix) }
            Text(" ").font(Fonts.reading(fontSize))
        }
    }

    private func plain(_ s: String) -> some View {
        Text(s).font(Fonts.reading(fontSize)).foregroundStyle(Palette.ink)
    }

    private func wordView(_ t: Token, line: Story.Line, speaking: Bool, cardMap: [String: Card], knownSet: Set<String>) -> some View {
        let k = RussianText.key(t.text)
        let lk = lemma[k] ?? k
        let card = cardMap[lk] ?? cardMap[k]
        let isKnown = knownSet.contains(lk) || knownSet.contains(k)
        let selected = selection?.word == t.text && selection?.sentence == line.ru
        var spoken = false
        if speaking, let r = speech.spokenRange {
            spoken = r.location < t.utf16Offset + t.utf16Length && r.location + r.length > t.utf16Offset
        }
        let shown = showStress ? RussianDictionary.shared.stressed(t.text) : t.text
        let memory = card?.retrievability
        let underline: Color? = card.map { _ in memory.map(Palette.memory) ?? Palette.red.opacity(0.7) }

        return Text(shown)
            .font(Fonts.reading(fontSize))
            .foregroundStyle(isKnown ? Palette.ink.opacity(0.75) : Palette.ink)
            .underline(underline != nil, color: underline ?? .clear)
            .padding(.horizontal, 2)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(selected ? Palette.blue.opacity(0.18) : spoken ? Palette.amber.opacity(0.35) : Color.clear)
            )
            .padding(.horizontal, -2)
            .contentShape(Rectangle())
            .onTapGesture {
                selection = WordSelection(word: t.text, sentence: line.ru, translation: line.fr, source: story.id)
            }
            .onLongPressGesture(minimumDuration: 0.35) {
                Speech.shared.say(t.text, slow: true)
            }
            .accessibilityAddTraits(.isButton)
    }

    private func lineButtons(_ i: Int, _ line: Story.Line) -> some View {
        HStack(spacing: 4) {
            Button {
                Speech.shared.say(line.ru, id: lineID(i))
            } label: {
                Image(systemName: "speaker.wave.2").font(.system(size: 12, weight: .semibold))
                    .frame(width: 26, height: 22)
                    .background(Palette.sunken, in: Capsule())
            }
            if !showAllTranslations {
                Button {
                    withAnimation(.snappy) {
                        if revealed.contains(i) { revealed.remove(i) } else { revealed.insert(i) }
                    }
                } label: {
                    Text("FR").font(.system(size: 11, weight: .bold, design: .rounded))
                        .frame(width: 26, height: 22)
                        .background(revealed.contains(i) ? Palette.blue.opacity(0.2) : Palette.sunken, in: Capsule())
                }
            }
        }
        .foregroundStyle(Palette.muted)
        .buttonStyle(.plain)
        .padding(.top, fontSize * 0.15)
    }

    // MARK: End of story

    private var finishSection: some View {
        VStack(spacing: 14) {
            Divider().padding(.vertical, 20)
            if let done = progress?.completedAt {
                Label("Finished \(done.formatted(date: .abbreviated, time: .omitted))", systemImage: "checkmark.seal.fill")
                    .font(Fonts.ui(.headline))
                    .foregroundStyle(Palette.green)
                if let score = progress?.quizScore {
                    Text("Quiz: \(score)/\(story.questions.count)").font(Fonts.ui(.subheadline)).foregroundStyle(Palette.muted)
                }
            }
            if !story.questions.isEmpty {
                Button { showQuiz = true } label: {
                    Label(progress?.completedAt == nil ? "Check your understanding" : "Retake the quiz", systemImage: "questionmark.bubble")
                }
                .buttonStyle(PrimaryButtonStyle(color: Palette.theme(story.theme)))
            }
            if progress?.completedAt == nil {
                Button("Mark as read") { finish(score: nil) }
                    .buttonStyle(SoftButtonStyle())
            }
        }
    }

    private func finish(score: Int?) {
        let p = progress ?? {
            let p = StoryProgress(storyID: story.id)
            context.insert(p)
            return p
        }()
        p.completedAt = p.completedAt ?? Date()
        if let score { p.quizScore = score }
        p.furthestLine = story.lines.count
        try? context.save()
    }

    // MARK: Controls

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Toggle("Stress marks", isOn: $showStress)
                Toggle("Show all translations", isOn: $showAllTranslations)
                Section("Text size") {
                    Button("Smaller") { fontSize = max(fontSize - 2, 16) }
                    Button("Larger") { fontSize = min(fontSize + 2, 34) }
                }
            } label: {
                Image(systemName: "textformat.size")
            }
        }
    }

    private var isPlayingStory: Bool {
        speech.speakingID?.hasPrefix(story.id + "-") ?? false
    }

    private var controls: some View {
        HStack(spacing: 16) {
            Button {
                if isPlayingStory {
                    speech.stop()
                } else {
                    speech.sayAll(story.lines.enumerated().map { (id: lineID($0.offset), text: $0.element.ru) })
                }
            } label: {
                Label(isPlayingStory ? "Stop" : "Listen", systemImage: isPlayingStory ? "stop.fill" : "play.fill")
                    .font(Fonts.ui(.subheadline, weight: .semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Palette.ink, in: Capsule())
                    .foregroundStyle(Palette.paper)
            }
            Spacer()
            legend
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private var legend: some View {
        HStack(spacing: 10) {
            legendItem(Palette.red, "new card")
            legendItem(Palette.blue, "solid")
        }
        .font(Fonts.ui(.caption2))
        .foregroundStyle(Palette.muted)
    }

    private func legendItem(_ c: Color, _ label: String) -> some View {
        HStack(spacing: 4) {
            Rectangle().fill(c).frame(width: 12, height: 2)
            Text(label)
        }
    }
}

struct QuizView: View {
    let story: Story
    let onFinish: (Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var answers: [Int: Int] = [:]
    @State private var showFrench: Set<Int> = []

    private var score: Int { story.questions.indices.filter { answers[$0] == story.questions[$0].answer }.count }
    private var complete: Bool { answers.count == story.questions.count }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ForEach(Array(story.questions.enumerated()), id: \.offset) { i, q in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(q.ru).font(Fonts.display(21)).foregroundStyle(Palette.ink)
                                .onTapGesture { Speech.shared.say(q.ru) }
                            Button(showFrench.contains(i) ? q.fr : "Show in French") {
                                showFrench.insert(i)
                            }
                            .font(Fonts.ui(.footnote))
                            .foregroundStyle(Palette.muted)
                            ForEach(Array(q.options.enumerated()), id: \.offset) { j, option in
                                optionButton(i, j, option, q)
                            }
                        }
                        .padding(16)
                        .card()
                    }
                    if complete {
                        VStack(spacing: 10) {
                            Text("\(score) / \(story.questions.count)").font(Fonts.display(40)).foregroundStyle(Palette.ink)
                            Text(score == story.questions.count ? "Отлично! Perfect." : "Хорошо! Re-read the lines you missed.")
                                .font(Fonts.ui(.subheadline)).foregroundStyle(Palette.muted)
                            Button("Done") {
                                onFinish(score)
                                dismiss()
                            }
                            .buttonStyle(PrimaryButtonStyle(color: Palette.green))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(18)
            }
            .background(Palette.paper.ignoresSafeArea())
            .navigationTitle("Quiz")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
    }

    private func optionButton(_ i: Int, _ j: Int, _ option: String, _ q: Story.Question) -> some View {
        let chosen = answers[i]
        let isAnswer = j == q.answer
        let color: Color = chosen == nil ? Palette.ink : isAnswer ? Palette.green : (chosen == j ? Palette.red : Palette.muted)
        return Button {
            guard answers[i] == nil else { return }
            withAnimation(.snappy) { answers[i] = j }
            UIImpactFeedbackGenerator(style: isAnswer ? .light : .rigid).impactOccurred()
        } label: {
            HStack {
                Text(option).font(Fonts.reading(18))
                Spacer()
                if chosen != nil && isAnswer { Image(systemName: "checkmark.circle.fill") }
                if chosen == j && !isAnswer { Image(systemName: "xmark.circle.fill") }
            }
            .foregroundStyle(color)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(color.opacity(chosen == nil ? 0.06 : 0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
